import 'package:dart_geohash/dart_geohash.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeohashService {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static const List<int> _bits = [16, 8, 4, 2, 1];

  final GeoHasher _geoHasher = GeoHasher();

  Future<String> getCurrentGeohash() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final latitude = position.latitude;
    final longitude = position.longitude;
    debugPrint('현재 위치: lat=${position.latitude}, lon=${position.longitude}');

    // ✅ 오류 방지: 좌표 유효성 검사
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw RangeError("Invalid GPS: lat=$latitude, lon=$longitude");
    }

    return _geoHasher.encode(latitude, longitude, precision: 8);
  }

  /// ✅ 홈화면 CommentSection 전용: 현재 위치 기반 5자리 geohash 계산
  Future<String?> getCurrentGeohash5() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latitude = position.latitude;
      final longitude = position.longitude;
      final geohash =
          generateGeohash(latitude, longitude, precision: 5); // 5자리로 지정

      debugPrint('🏷️ 5자리 geohash (HomeScreen용): $geohash');
      return geohash;
    } catch (e) {
      debugPrint('5자리 geohash 계산 중 오류: $e');
      return null;
    }
  }

  String generateGeohash(double latitude, double longitude,
      {int precision = 8}) {
    final latInterval = [-90.0, 90.0];
    final lonInterval = [-180.0, 180.0];
    final hash = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (hash.length < precision) {
      double mid;
      if (isEven) {
        mid = (lonInterval[0] + lonInterval[1]) / 2;
        if (longitude > mid) {
          ch |= _bits[bit];
          lonInterval[0] = mid;
        } else {
          lonInterval[1] = mid;
        }
      } else {
        mid = (latInterval[0] + latInterval[1]) / 2;
        if (latitude > mid) {
          ch |= _bits[bit];
          latInterval[0] = mid;
        } else {
          latInterval[1] = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        hash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return hash.toString();
  }

  /// 위치 객체로부터 geohash 계산
  Future<String?> getGeohashFromPosition(Position position) async {
    try {
      double lat = position.latitude;
      double lon = position.longitude;
      debugPrint("정확한 위도: $lat, 경도: $lon");
      final hash = generateGeohash(lat, lon); // 직접 구현한 메서드

      debugPrint("생성된 geohash: $hash");
      return hash;
    } catch (e) {
      debugPrint('Geohash 계산 중 오류: $e');
      return null;
    }
  }

  List<String> getNeighborGeohashes(String centerHash) {
    final neighborsMap = _geoHasher.neighbors(centerHash);
    final neighbors = neighborsMap.values.toList();
    return [centerHash, ...neighbors];
  }
}
