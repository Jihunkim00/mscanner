import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/history_retention_service.dart';
import '../models/food_journey_summary.dart';

class FoodJourneyPage {
  const FoodJourneyPage(this.scans, {this.cursor, this.hasMore = false});
  final List<SavedFoodScan> scans;
  final Object? cursor;
  final bool hasMore;
}

abstract interface class FoodJourneySource {
  Future<FoodJourneyPage> readPage(
      {required String uid, required bool isPremium, Object? after});
}

typedef FoodJourneyPageReader = Future<FoodJourneyPage> Function(
    {required String collectionPath, required int limit, Object? after});

/// Reads only the same retained history used by FavoriteListScreen.
/// No writes, retention cleanup, image requests or secondary collections.
class FoodJourneyRepository implements FoodJourneySource {
  FoodJourneyRepository(
      {FirebaseFirestore? firestore, FoodJourneyPageReader? reader})
      : _firestore = firestore,
        _reader = reader;
  final FirebaseFirestore? _firestore;
  final FoodJourneyPageReader? _reader;
  static const premiumPageSize = 50;
  static int pageSize(bool isPremium) =>
      isPremium ? premiumPageSize : HistoryRetentionPolicy.freeHistoryLimit;

  @override
  Future<FoodJourneyPage> readPage(
      {required String uid, required bool isPremium, Object? after}) async {
    if (uid.isEmpty || (!isPremium && after != null)) {
      return const FoodJourneyPage([]);
    }
    final limit = pageSize(isPremium);
    final page = await (_reader ?? _readFirestore)(
        collectionPath: 'user_rating/$uid/data',
        limit: isPremium ? limit + 1 : limit,
        after: after);
    return FoodJourneyPage(page.scans.take(limit).toList(),
        cursor: page.cursor, hasMore: isPremium && page.scans.length > limit);
  }

  Future<FoodJourneyPage> _readFirestore(
      {required String collectionPath,
      required int limit,
      Object? after}) async {
    Query<Map<String, dynamic>> query =
        (_firestore ?? FirebaseFirestore.instance)
            .collection(collectionPath)
            .orderBy('timestamp', descending: true)
            .orderBy(FieldPath.documentId, descending: true)
            .limit(limit);
    if (after is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(after);
    }
    // An offline response is handled explicitly by the service's UID cache.
    final snapshot = await query.get(const GetOptions(source: Source.server));
    return FoodJourneyPage([
      for (final doc in snapshot.docs) SavedFoodScan(doc.id, doc.data()),
    ],
        cursor: snapshot.docs.length > premiumPageSize
            ? snapshot.docs[premiumPageSize - 1]
            : snapshot.docs.lastOrNull);
  }
}
