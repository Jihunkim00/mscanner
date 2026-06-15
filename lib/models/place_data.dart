// models/place_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PlaceData {
  final String id;
  final double lat;
  final double lng;
  final String imageUrl;
  final DateTime timestamp;

  PlaceData({
    required this.id,
    required this.lat,
    required this.lng,
    required this.imageUrl,
    required this.timestamp,
  });

  /// Firestore 문서에서 안전하게 읽어오는 생성자
  factory PlaceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // gps 필드는 GeoPoint 타입으로 들어옵니다.
    final GeoPoint? geo = data['gps'] as GeoPoint?;
    final lat = geo?.latitude ?? 0.0;
    final lng = geo?.longitude ?? 0.0;

    // image_url 필드
    final imageUrl = (data['image_url'] as String?) ?? '';

    // timestamp 필드는 String으로 저장했다 가정
    final tsString = (data['timestamp'] as String?) ?? '';
    final timestamp = tsString.isNotEmpty
        ? DateTime.tryParse(tsString) ?? DateTime.now()
        : DateTime.now();

    // 디버그 로그
    debugPrint('📄 [PlaceData.fromFirestore] docId=${doc.id}');
    debugPrint('   ↪ gps -> lat=$lat, lng=$lng');
    debugPrint('   ↪ image_url="$imageUrl"');
    debugPrint('   ↪ timestamp=$timestamp');

    return PlaceData(
      id: doc.id,
      lat: lat,
      lng: lng,
      imageUrl: imageUrl,
      timestamp: timestamp,
    );
  }

  @override
  String toString() {
    return 'PlaceData('
        'id: $id, lat: $lat, lng: $lng, '
        'imageUrl: $imageUrl, timestamp: $timestamp'
        ')';
  }
}
