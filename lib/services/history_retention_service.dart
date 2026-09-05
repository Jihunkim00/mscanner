import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/analytics_service.dart';

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

  Future<int> enforce({
    required CollectionReference<Map<String, dynamic>> historyCollection,
    required bool isPremium,
  }) async {
    if (isPremium) return 0;

    try {
      final snapshot =
          await historyCollection.orderBy('timestamp', descending: true).get();
      final documents = policy.documentsToDelete(
        newestFirst: snapshot.docs,
        isPremium: isPremium,
      );
      if (documents.isEmpty) return 0;

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
      return documents.length;
    } catch (error) {
      debugPrint('History retention cleanup failed: $error');
      return 0;
    }
  }
}
