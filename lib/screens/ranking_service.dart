import 'package:cloud_firestore/cloud_firestore.dart';

/// 1) 랭킹 모델
class RankingData {
  final String documentId;
  final String country;
  final String geohash;
  final int rating;
  final String restaurantName;
  final Timestamp timestamp;
  final int duplicateCount;

  RankingData({
    required this.documentId,
    required this.country,
    required this.geohash,
    required this.rating,
    required this.restaurantName,
    required this.timestamp,
    this.duplicateCount = 1,
  });

  RankingData copyWith({int? duplicateCount}) {
    return RankingData(
      documentId: documentId,
      country: country,
      geohash: geohash,
      rating: rating,
      restaurantName: restaurantName,
      timestamp: timestamp,
      duplicateCount: duplicateCount ?? this.duplicateCount,
    );
  }

  factory RankingData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return RankingData(
      documentId: doc.id,
      country: (data['country'] ?? '알 수 없음').toString().trim(),
      geohash: data['geohash'] ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      restaurantName: data['restaurantName'] ?? '알 수 없음',
      timestamp:
      data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : Timestamp.now(),
    );
  }
}

/// 2) 랭킹 로직
/// - Firestore에서 'ranking_data' 컬렉션 읽기
/// - 평점 높은 순 정렬
/// - 같은 geohash 중복 제거(가장 높은 평점만)
/// - 최종 정렬 후 '상위 1개'(최고)만 반환
/// - 필요하면 국가 필터 로직도 추가 가능
class RankingService {
  /// 상위 1개(최고 랭킹)만 가져오는 예시
  Future<RankingData?> fetchTopRanking({String? selectedCountry}) async {
    try {
      // 1) 평점 높은 순으로 정렬
      Query query = FirebaseFirestore.instance
          .collection('ranking_data')
          .orderBy('rating', descending: true);

      // [옵션] 국가 필터 예시
      if (selectedCountry != null && selectedCountry != "전체") {
        query = query.where('country', isEqualTo: selectedCountry);
      }

      QuerySnapshot rankingSnapshot = await query.get();
      if (rankingSnapshot.docs.isEmpty) {
        print("⚠️ 랭킹 데이터가 없습니다. (country=$selectedCountry)");
        return null;
      }

      // 2) Firestore → RankingData 모델 변환
      List<RankingData> rankings = rankingSnapshot.docs.map((doc) {
        return RankingData.fromFirestore(doc);
      }).toList();

      // 3) geohash 중복 개수 계산
      Map<String, int> geohashCounts = {};
      for (var r in rankings) {
        geohashCounts[r.geohash] = (geohashCounts[r.geohash] ?? 0) + 1;
      }

      // 4) 같은 geohash 내 중복 제거 → 평점이 가장 높은 것만 유지
      Map<String, RankingData> uniqueRankings = {};
      for (var r in rankings) {
        if (!uniqueRankings.containsKey(r.geohash) ||
            r.rating > uniqueRankings[r.geohash]!.rating) {
          uniqueRankings[r.geohash] = r;
        }
      }

      // 5) 최종 정렬 (평점 높은 순 → geohash 중복 많은 순 → 최신 등록 순)
      List<RankingData> finalRankings = uniqueRankings.values.toList();
      finalRankings.sort((a, b) {
        // 평점 높은 순
        if (b.rating != a.rating) {
          return b.rating.compareTo(a.rating);
        }
        // 중복 많은 순
        if ((geohashCounts[b.geohash] ?? 0) != (geohashCounts[a.geohash] ?? 0)) {
          return (geohashCounts[b.geohash] ?? 0)
              .compareTo(geohashCounts[a.geohash] ?? 0);
        }
        // 최신 등록 순
        return b.timestamp.compareTo(a.timestamp);
      });

      // 6) duplicateCount 세팅
      finalRankings = finalRankings.map((r) {
        return r.copyWith(duplicateCount: geohashCounts[r.geohash] ?? 1);
      }).toList();

      // 7) "최고 1개"만 반환
      if (finalRankings.isEmpty) {
        return null;
      }
      return finalRankings.first;

    } catch (e) {
      print("❌ Firestore 데이터 가져오기 오류: $e");
      return null;
    }
  }
}
