import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../services/history_retention_service.dart';
import '../models/food_journey_summary.dart';
import 'food_dna_classifier.dart';
import 'food_journey_repository.dart';
import 'food_passport_service.dart';

FoodJourneySummary summarizeFoodJourney(Iterable<SavedFoodScan> scans) {
  final unique = <String, SavedFoodScan>{};
  for (final scan in scans) {
    unique.putIfAbsent(scan.id, () => scan);
  }
  final counts = <FoodCategory, int>{};
  for (final scan in unique.values) {
    final category = const FoodCategoryClassifier()
        .classify(const FoodJourneyMenuParser().representative(scan.data));
    counts[category] = (counts[category] ?? 0) + 1;
  }
  return FoodJourneySummary(
      savedScanCount: unique.length,
      stamps: const FoodPassportService().stamps(unique.values),
      counts: counts);
}

class _JourneyCache {
  _JourneyCache(this.scans, this.cursor, this.hasMore, this.fetchedAt);
  final Map<String, SavedFoodScan> scans;
  final Object? cursor;
  final bool hasMore;
  final DateTime fetchedAt;
}

/// Session-only, versioned UID + entitlement cache. Late requests cannot cross
/// account, entitlement or history-invalidation boundaries.
class FoodJourneyService extends ChangeNotifier {
  FoodJourneyService(
      {required FoodJourneySource source,
      DateTime Function()? now,
      this.ttl = const Duration(minutes: 5)})
      : _source = source,
        _now = now ?? DateTime.now;
  static final instance = _productionService();
  static FoodJourneyService _productionService() {
    final service = FoodJourneyService(source: FoodJourneyRepository());
    // Outlives the home tab so logout also clears an open detail route.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (service.uid != user?.uid) {
        service.selectAccount(null, isPremium: false);
      }
    });
    return service;
  }

  static const cacheVersion = 1;
  final FoodJourneySource _source;
  final DateTime Function() _now;
  final Duration ttl;
  final Map<String, _JourneyCache> _cache = {};
  String? _uid;
  bool _isPremium = false;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _pending;
  bool loading = false;
  bool hasError = false;
  bool showingCachedData = false;
  bool _retryMore = false;
  FoodJourneySummary? summary;
  String? get uid => _uid;
  bool get hasMore => _isPremium && (_entry?.hasMore ?? false);
  String get _key => '$cacheVersion:$_uid:$_isPremium';
  _JourneyCache? get _entry => _cache[_key];

  void selectAccount(String? uid, {required bool isPremium}) {
    if (_uid == uid && _isPremium == isPremium) return;
    // Erase the former account on logout/account switch, including raw responses.
    if (_uid != uid) _cache.clear();
    _uid = uid;
    _isPremium = isPremium;
    _generation++;
    _pending = null;
    loading = false;
    hasError = false;
    showingCachedData = false;
    final entry = _entry;
    summary = entry == null ? null : summarizeFoodJourney(entry.scans.values);
    notifyListeners();
  }

  Future<void> load({bool refresh = false, bool more = false}) {
    if (_uid == null || _disposed) return Future.value();
    if (_pending != null) return _pending!;
    final cached = _entry;
    if (!refresh &&
        !more &&
        cached != null &&
        _now().difference(cached.fetchedAt) < ttl) {
      return Future.value();
    }
    if (more && (!hasMore || cached?.cursor == null)) return Future.value();
    final generation = _generation;
    final uid = _uid!;
    final premium = _isPremium;
    final key = _key;
    loading = true;
    hasError = false;
    _retryMore = more;
    notifyListeners();
    final request = _read(uid, premium, key, generation, more ? cached : null);
    _pending = request;
    return request;
  }

  Future<void> retry() => load(more: _retryMore, refresh: !_retryMore);

  Future<void> _read(String uid, bool premium, String key, int generation,
      _JourneyCache? previous) async {
    try {
      final page = await _source.readPage(
          uid: uid, isPremium: premium, after: previous?.cursor);
      if (_disposed || generation != _generation) return;
      final scans = <String, SavedFoodScan>{...?previous?.scans};
      final incoming = premium
          ? page.scans
          : page.scans.take(HistoryRetentionPolicy.freeHistoryLimit);
      for (final scan in incoming) {
        scans[scan.id] = scan;
      }
      final entry = _JourneyCache(scans, page.cursor, premium && page.hasMore,
          previous?.fetchedAt ?? _now());
      _cache[key] = entry;
      summary = summarizeFoodJourney(scans.values);
      showingCachedData = false;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      hasError = true;
      showingCachedData = summary != null;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _pending = null;
        notifyListeners();
      }
    }
  }

  /// Called only after a successful history save/delete. Never keeps deleted
  /// records visible as an offline fallback after a known local mutation.
  void invalidate(String uid) {
    _cache.removeWhere((key, _) => key.startsWith('$cacheVersion:$uid:'));
    if (_uid != uid) return;
    _generation++;
    _pending = null;
    loading = false;
    summary = null;
    hasError = false;
    showingCachedData = false;
    notifyListeners();
    unawaited(load());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cache.clear();
    super.dispose();
  }
}
