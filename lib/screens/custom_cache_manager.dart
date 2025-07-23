// lib/custom_cache_manager.dart

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager extends CacheManager {
  static const key = 'customCache';

  static final CustomCacheManager _instance = CustomCacheManager._internal();

  factory CustomCacheManager() {
    return _instance;
  }

  CustomCacheManager._internal()
      : super(
    Config(
      key,
      stalePeriod: Duration(days: 30), // 캐시 만료 기간을 30일로 설정
      maxNrOfCacheObjects: 200, // 최대 캐시 객체 수를 200으로 설정
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
      // 추가적인 설정 가능
    ),
  );
}
