import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/models/food_journey_summary.dart';
import 'package:mscanner/features/food_journey/services/food_journey_repository.dart';

void main() {
  test('free reads only the retained 20 from user_rating and never pages',
      () async {
    var reads = 0;
    final repository = FoodJourneyRepository(
        reader: ({required collectionPath, required limit, after}) async {
      reads++;
      expect(collectionPath, 'user_rating/alice/data');
      expect(limit, 20);
      expect(after, isNull);
      return FoodJourneyPage(List.generate(25, (i) => SavedFoodScan('$i', {})),
          cursor: 'cursor');
    });
    final page = await repository.readPage(uid: 'alice', isPremium: false);
    expect(page.scans, hasLength(20));
    expect(page.hasMore, isFalse);
    expect(
        (await repository.readPage(
                uid: 'alice', isPremium: false, after: page.cursor))
            .scans,
        isEmpty);
    expect(reads, 1);
  });

  test('premium reads bounded pages and forwards the previous cursor',
      () async {
    final cursor = Object();
    var reads = 0;
    final repository = FoodJourneyRepository(
        reader: ({required collectionPath, required limit, after}) async {
      expect(collectionPath, 'user_rating/bob/data');
      expect(limit, 51);
      expect(after, reads++ == 0 ? isNull : same(cursor));
      return after == null
          ? FoodJourneyPage(List.generate(51, (i) => SavedFoodScan('$i', {})),
              cursor: cursor)
          : const FoodJourneyPage([]);
    });
    final first = await repository.readPage(uid: 'bob', isPremium: true);
    expect(first.hasMore, isTrue);
    expect(first.scans, hasLength(50));
    expect(first.scans.last.id, '49');
    final last = await repository.readPage(
        uid: 'bob', isPremium: true, after: first.cursor);
    expect(last.hasMore, isFalse);
    expect(last.scans, isEmpty);
    expect(reads, 2);
  });

  test('missing UID does not issue a read', () async {
    final repository = FoodJourneyRepository(
        reader: ({required collectionPath, required limit, after}) async {
      fail('must not read');
    });
    expect(
        (await repository.readPage(uid: '', isPremium: true)).scans, isEmpty);
  });

  test('exactly 50 premium records do not claim another page exists', () async {
    final repository = FoodJourneyRepository(
        reader: ({required collectionPath, required limit, after}) async =>
            FoodJourneyPage(List.generate(50, (i) => SavedFoodScan('$i', {}))));
    final page = await repository.readPage(uid: 'alice', isPremium: true);
    expect(page.scans, hasLength(50));
    expect(page.hasMore, isFalse);
  });
}
