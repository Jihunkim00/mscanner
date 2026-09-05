import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/analytics_service.dart';

class HistoryRetentionResult {
  const HistoryRetentionResult({
    required this.deletedCount,
  });

  const HistoryRetentionResult.none() : deletedCount = 0;

  final int deletedCount;

  bool get historyLimitReached => deletedCount > 0;
  bool get oldestHistoryRemoved => deletedCount > 0;
}

class HistoryLimitNoticePolicy {
  static const String noticeDatePrefsKey = 'historyLimitNoticeDate';

  const HistoryLimitNoticePolicy();

  String dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  bool shouldShow({
    required String? lastShownDate,
    required DateTime now,
  }) {
    return lastShownDate != dateKey(now);
  }
}

class HistoryLimitNoticeService {
  HistoryLimitNoticeService({
    Future<SharedPreferences> Function()? preferencesProvider,
    HistoryLimitNoticePolicy policy = const HistoryLimitNoticePolicy(),
  })  : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance,
        _policy = policy;

  final Future<SharedPreferences> Function() _preferencesProvider;
  final HistoryLimitNoticePolicy _policy;

  Future<bool> claimForToday({DateTime? now}) async {
    try {
      final current = now ?? DateTime.now();
      final prefs = await _preferencesProvider();
      final lastShownDate =
          prefs.getString(HistoryLimitNoticePolicy.noticeDatePrefsKey);
      if (!_policy.shouldShow(
        lastShownDate: lastShownDate,
        now: current,
      )) {
        return false;
      }

      return await prefs.setString(
        HistoryLimitNoticePolicy.noticeDatePrefsKey,
        _policy.dateKey(current),
      );
    } catch (error) {
      debugPrint('History limit notice state failed: $error');
      return false;
    }
  }
}

class HistoryRetentionPolicy {
  static const int freeHistoryLimit = 20;

  const HistoryRetentionPolicy();

  List<T> documentsToDelete<T>({
    required List<T> newestFirst,
    required bool isPremium,
  }) {
    if (isPremium || newestFirst.length <= freeHistoryLimit) {
      return <T>[];
    }
    return newestFirst.skip(freeHistoryLimit).toList(growable: false);
  }
}

class HistoryRetentionService {
  const HistoryRetentionService({
    this.policy = const HistoryRetentionPolicy(),
  });

  final HistoryRetentionPolicy policy;

  Future<HistoryRetentionResult> enforce({
    required CollectionReference<Map<String, dynamic>> historyCollection,
    required bool isPremium,
  }) async {
    if (isPremium) return const HistoryRetentionResult.none();

    try {
      final snapshot =
          await historyCollection.orderBy('timestamp', descending: true).get();
      final documents = policy.documentsToDelete(
        newestFirst: snapshot.docs,
        isPremium: isPremium,
      );
      if (documents.isEmpty) return const HistoryRetentionResult.none();

      // Firestore batches are limited to 500 operations.
      for (var offset = 0; offset < documents.length; offset += 450) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (offset + 450).clamp(0, documents.length).toInt();
        for (final document in documents.sublist(offset, end)) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }

      try {
        await AnalyticsService.instance.logEvent(
          'history_free_limit_reached',
          params: {
            'limit': HistoryRetentionPolicy.freeHistoryLimit,
            'deleted_count': documents.length,
          },
        );
      } catch (error) {
        debugPrint('History retention analytics failed: $error');
      }
      return HistoryRetentionResult(deletedCount: documents.length);
    } catch (error) {
      debugPrint('History retention cleanup failed: $error');
      return const HistoryRetentionResult.none();
    }
  }
}
