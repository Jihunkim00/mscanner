import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/models/food_journey_summary.dart';
import 'package:mscanner/features/food_journey/services/food_journey_repository.dart';
import 'package:mscanner/features/food_journey/services/food_journey_service.dart';

class TestJourneySource implements FoodJourneySource {
  final requests = <({String uid, bool premium, Object? after})>[];
  Future<FoodJourneyPage> Function(String uid, Object? after)? answer;
  @override
  Future<FoodJourneyPage> readPage(
      {required String uid, required bool isPremium, Object? after}) {
    requests.add((uid: uid, premium: isPremium, after: after));
    return answer?.call(uid, after) ?? Future.value(const FoodJourneyPage([]));
  }
}

SavedFoodScan foodScan(String id, String name, {String country = 'JP'}) =>
    SavedFoodScan(id, {
      'primary_menu': name,
      'country': country,
      'timestamp': '2026-01-01T00:00:00Z'
    });

void main() {
  test(
      'large histories aggregate deterministically without counting duplicate IDs',
      () {
    final records = List.generate(
        2500, (i) => foodScan('$i', i.isEven ? 'Ramen' : 'Sushi'));
    final summary = summarizeFoodJourney([...records, ...records]);
    expect(summary.savedScanCount, 2500);
    expect(summary.classifiedScanCount, 2500);
    expect(summary.stamps.single.savedScanCount, 2500);
    expect(summary.percentages,
        {FoodCategory.noodles: 50, FoodCategory.seafood: 50});
  });

  test(
      'failed pagination retries that page; a failed refresh retries from newest',
      () async {
    var failReads = false;
    final source = TestJourneySource()
      ..answer = (_, after) async {
        if (failReads) throw StateError('offline');
        return FoodJourneyPage([foodScan(after == null ? 'a' : 'b', 'Ramen')],
            cursor: after == null ? 'next' : null, hasMore: after == null);
      };
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: true);
    await service.load();
    failReads = true;
    await service.load(more: true);
    expect(service.showingCachedData, isTrue);
    failReads = false;
    await service.retry();
    expect(source.requests.last.after, 'next');
    expect(service.summary!.savedScanCount, 2);
    failReads = true;
    await service.load(refresh: true);
    failReads = false;
    await service.retry();
    expect(source.requests.last.after, isNull);
    expect(service.summary!.savedScanCount, 1);
  });
  test(
      'multi-scan and duplicate documents give at most one point; unknown excluded',
      () {
    final summary = summarizeFoodJourney([
      const SavedFoodScan('multi', {
        'responses': [
          '{"recommended":[{"name":"Ramen"},{"name":"Steak"}]}',
          '{"recommended":[{"name":"Ramen"},{"name":"Sushi"}]}'
        ]
      }),
      foodScan('multi', 'Steak'),
      foodScan('b', 'Risotto'),
      foodScan('c', 'Sushi'),
      foodScan('d', 'Mystery special'),
    ]);
    expect(summary.savedScanCount, 4);
    expect(summary.classifiedScanCount, 3);
    expect(summary.counts[FoodCategory.noodles], 1);
    expect(summary.counts[FoodCategory.meat], isNull);
    expect(summary.percentages.values.reduce((a, b) => a + b), 100);
    expect(summary.percentages[FoodCategory.noodles], 34);
    expect(summary.percentages[FoodCategory.unknown], isNull);
    expect(summarizeFoodJourney([]).percentages, isEmpty);
    expect(summarizeFoodJourney([foodScan('a', '???')]).classifiedScanCount, 0);
  });

  test('example DNA distribution and small records', () {
    final scans = <SavedFoodScan>[];
    for (final entry
        in {'Ramen': 8, 'Rice': 5, 'Sushi': 4, 'Tiramisu': 3}.entries) {
      for (var i = 0; i < entry.value; i++) {
        scans.add(foodScan('${entry.key}$i', entry.key));
      }
    }
    expect(summarizeFoodJourney(scans).percentages, {
      FoodCategory.noodles: 40,
      FoodCategory.rice: 25,
      FoodCategory.seafood: 20,
      FoodCategory.dessert: 15
    });
    expect(summarizeFoodJourney([foodScan('a', 'Ramen')]).percentages,
        {FoodCategory.noodles: 100});
  });

  test(
      'coalesces in-flight requests, uses TTL, refreshes and keeps offline cache',
      () async {
    var now = DateTime(2026);
    final source = TestJourneySource();
    var deferred = Completer<FoodJourneyPage>();
    source.answer = (_, __) => deferred.future;
    final service = FoodJourneyService(source: source, now: () => now);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    final a = service.load();
    final b = service.load();
    expect(identical(a, b), isTrue);
    deferred.complete(FoodJourneyPage([foodScan('a', 'Ramen')]));
    await a;
    await service.load();
    expect(source.requests, hasLength(1));
    now = now.add(const Duration(minutes: 6));
    source.answer = (_, __) async => throw StateError('offline');
    await service.load();
    expect(service.hasError, isTrue);
    expect(service.showingCachedData, isTrue);
    expect(service.summary!.classifiedScanCount, 1);
    source.answer = (_, __) async => FoodJourneyPage([foodScan('b', 'Sushi')]);
    await service.load(refresh: true);
    expect(service.hasError, isFalse);
    expect(service.summary!.counts[FoodCategory.seafood], 1);
  });

  test(
      'late requests cannot leak records across accounts, logout or entitlement',
      () async {
    final source = TestJourneySource();
    final old = Completer<FoodJourneyPage>();
    source.answer = (uid, _) => uid == 'alice'
        ? old.future
        : Future.value(FoodJourneyPage([foodScan('b', 'Rice')]));
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: true);
    final first = service.load();
    service.selectAccount('bob', isPremium: false);
    expect(service.summary, isNull);
    await service.load();
    old.complete(FoodJourneyPage([foodScan('a', 'Steak')]));
    await first;
    expect(service.summary!.counts[FoodCategory.meat], isNull);
    service.selectAccount(null, isPremium: false);
    expect(service.summary, isNull);
    service.selectAccount('bob', isPremium: false);
    expect(service.summary, isNull);
  });

  test('free defense limits data to 20; premium adds one page only on demand',
      () async {
    final source = TestJourneySource();
    source.answer = (_, after) async => FoodJourneyPage(
        List.generate(50, (i) => foodScan('${after ?? 0}-$i', 'Ramen')),
        cursor: after == null ? 'next' : null,
        hasMore: after == null);
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    await service.load(more: true);
    expect(service.summary!.savedScanCount, 20);
    expect(source.requests, hasLength(1));
    service.selectAccount('alice', isPremium: true);
    expect(service.summary, isNull);
    await service.load();
    expect(service.summary!.savedScanCount, 50);
    expect(service.hasMore, isTrue);
    await service.load(more: true);
    expect(service.summary!.savedScanCount, 100);
    expect(service.hasMore, isFalse);
    expect(source.requests.last.after, 'next');
    service.selectAccount('alice', isPremium: false);
    expect(service.summary!.savedScanCount, 20);
  });

  test(
      'successful history mutation discards deleted data and rejects late old response',
      () async {
    final source = TestJourneySource();
    source.answer = (_, __) async => FoodJourneyPage([foodScan('a', 'Ramen')]);
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    final late = Completer<FoodJourneyPage>();
    source.answer = (_, __) => late.future;
    final pending = service.load(refresh: true);
    source.answer = (_, __) async => const FoodJourneyPage([]);
    service.invalidate('alice');
    await service.load();
    late.complete(FoodJourneyPage([foodScan('a', 'Ramen')]));
    await pending;
    expect(service.summary!.savedScanCount, 0);
    service.selectAccount('alice', isPremium: true);
    expect(service.summary, isNull);
  });
}
