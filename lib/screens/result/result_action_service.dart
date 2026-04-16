import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResultActionService {
  static String buildSearchedMenuDocId({
    required String lang,
    required String geohash,
    required String menuKey,
  }) {
    final geoPrefix = _safePrefix(geohash.trim(), 6).toLowerCase();
    final normalizedLang = lang.trim().toLowerCase();
    final normalizedMenuKey = menuKey.trim().toLowerCase();

    final raw = '${normalizedLang}_${geoPrefix}_$normalizedMenuKey';

    return raw
        .replaceAll(RegExp(r'[^a-z0-9가-힣_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static List<String> buildSearchKeywords({
    required String original,
    required String translated,
    String? display,
    List<String> tags = const [],
    List<String> recommendedMenus = const [],
    List<String> recommendedChipLabels = const [],
    List<String> recommendedTags = const [],
  }) {
    final set = <String>{};

    void addValue(String v) {
      final s = v.trim().toLowerCase();
      if (s.isNotEmpty) set.add(s);
    }

    addValue(original);
    addValue(translated);
    addValue(display ?? '');

    for (final menu in recommendedMenus) {
      addValue(menu);
    }
    for (final label in recommendedChipLabels) {
      addValue(label);
    }
    for (final tag in recommendedTags) {
      addValue(tag);
    }
    for (final tag in tags) {
      addValue(tag);
    }

    return set.toList();
  }

  static Future<void> checkAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    int usageCount = prefs.getInt('usageCount') ?? 0;
    usageCount++;
    await prefs.setInt('usageCount', usageCount);

    final hasReviewed = prefs.getBool('hasReviewed') ?? false;
    if (hasReviewed) return;

    final inAppReview = InAppReview.instance;

    if (usageCount == 5) {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setBool('hasReviewed', true);
      }
      return;
    }

    if (usageCount > 5 && (usageCount - 5) % 30 == 0) {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
  }

  static String _safePrefix(String geohash, int len) {
    if (geohash.isEmpty) return geohash;
    if (len <= 0) return geohash;
    return geohash.substring(0, geohash.length < len ? geohash.length : len);
  }
}