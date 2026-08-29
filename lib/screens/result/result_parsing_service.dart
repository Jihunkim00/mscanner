import 'dart:convert';

class ResultParsingOutput {
  const ResultParsingOutput({
    required this.aiJson,
    required this.aiJsonError,
  });

  final Map<String, dynamic>? aiJson;
  final String? aiJsonError;
}

class ResultParsingService {
  static const String _directRecommendedMenuMarkerKey =
      '_has_direct_recommended_menu';

  static const Set<String> _nonMenuResultTypes = <String>{
    'not_menu',
    'non_menu',
    'notmenu',
    'no_menu',
    'nomenu',
    'not_food_menu',
    'invalid_image',
    'unclear',
    'unrecognized',
    'uncertain',
  };
  static String? extractCurrencyCodeFromText(String text) {
    final s = text.toLowerCase();

    if (s.contains('krw') || s.contains('₩') || s.contains('원')) {
      return 'KRW';
    }
    if (s.contains('jpy') ||
        s.contains('¥') ||
        s.contains('엔화') ||
        s.contains('엔')) {
      return 'JPY';
    }
    if (s.contains('usd') || s.contains(r'$') || s.contains('달러')) return 'USD';
    if (s.contains('eur') || s.contains('€') || s.contains('유로')) return 'EUR';
    if (s.contains('cny') || s.contains('元') || s.contains('위안')) return 'CNY';

    return null;
  }

  static double? extractAmountFromText(String text) {
    final cleaned = text.replaceAll(',', ' ').replaceAll('\u00A0', ' ');
    final regex = RegExp(r'(\d+[\s\d]*\.?\d*)');
    final m = regex.firstMatch(cleaned);
    if (m == null) return null;
    final numStr = m.group(1)!.replaceAll(' ', '');
    return double.tryParse(numStr);
  }

  static String? extractCurrencySymbolFromText(String text) {
    const symbols = ['₩', '€', '£', '₫', '₱', '฿', '₹', '¥', r'$'];
    for (final s in symbols) {
      if (text.contains(s)) return s;
    }
    return null;
  }

  static String? extractJsonObjectFromText(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
      s = s.replaceAll(RegExp(r'\s*```$'), '');
      s = s.trim();
    }

    final start = s.indexOf('{');
    if (start < 0) return null;

    final end = s.lastIndexOf('}');
    if (end < 0 || end <= start) return null;

    final candidate = s.substring(start, end + 1).trim();
    if (!candidate.startsWith('{') || !candidate.endsWith('}')) return null;

    return candidate;
  }

  static ResultParsingOutput parseAiJson({
    required List<String> responses,
    required int imageCount,
  }) {
    Map<String, dynamic>? firstJson;
    final List<Map<String, dynamic>> jsonList = [];
    String? aiJsonError;

    for (final r in responses) {
      final raw = r.trim();
      if (raw.isEmpty) {
        aiJsonError ??= 'empty_response';
        continue;
      }
      final s = extractJsonObjectFromText(raw);
      if (s == null) {
        aiJsonError ??= 'invalid_json';
        continue;
      }

      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          firstJson ??= m;
          jsonList.add(m);
        } else {
          aiJsonError ??= 'root_not_map';
        }
      } catch (_) {
        aiJsonError ??= 'invalid_json';
      }
    }

    if (firstJson == null) {
      return ResultParsingOutput(aiJson: null, aiJsonError: aiJsonError);
    }

    final isMulti = imageCount > 1 || jsonList.length > 1;

    if (!isMulti) {
      final normalized = Map<String, dynamic>.from(firstJson);
      final hasDirectRecommended =
          _hasValidMenuItems(_mapList(normalized['recommended'])) ||
              _hasValidMenuItems(_mapList(normalized['items']));
      final fallbackRecommended = _recommendedItemsFromJson(normalized);
      if (fallbackRecommended.isNotEmpty) {
        normalized['recommended'] = fallbackRecommended;
      }
      if (normalized.containsKey('fullMenu') ||
          normalized.containsKey('full_menu')) {
        final fullMenuKey = normalized.containsKey('fullMenu')
            ? 'fullMenu'
            : 'full_menu';
        normalized[fullMenuKey] = _removeRecommendedOverlap(
          normalized[fullMenuKey],
          fallbackRecommended,
        );
      }
      normalized[_directRecommendedMenuMarkerKey] = hasDirectRecommended;
      final inferredResultType =
          normalized['isMenu'] == false ? 'not_menu' : 'menu';
      normalized['result_type'] = normalizeResultType(
        (normalized['result_type'] ??
                normalized['resultType'] ??
                inferredResultType)
            .toString(),
      );
      normalized['user_message'] =
          (normalized['user_message'] ?? normalized['userMessage'] ?? '')
              .toString()
              .trim();
      return ResultParsingOutput(aiJson: normalized, aiJsonError: null);
    }

    final merged = Map<String, dynamic>.from(firstJson);
    final List<Map<String, dynamic>> recommendedAll = [];
    final Map<String, List<Map<String, dynamic>>> fullMenuAll = {
      'main': <Map<String, dynamic>>[],
      'side': <Map<String, dynamic>>[],
      'meal': <Map<String, dynamic>>[],
      'drink': <Map<String, dynamic>>[],
      'beverage': <Map<String, dynamic>>[],
      'unknown': <Map<String, dynamic>>[],
    };

    bool hasDirectRecommended = false;

    for (final j in jsonList) {
      hasDirectRecommended = hasDirectRecommended ||
          _hasValidMenuItems(_mapList(j['recommended'])) ||
          _hasValidMenuItems(_mapList(j['items']));
      recommendedAll.addAll(_directRecommendedItemsFromJson(j));

      final fm = j['fullMenu'] ?? j['full_menu'] ?? j['menu'] ?? j['menus'];
      if (fm is Map) {
        final src = (fm['items'] is Map)
            ? Map<String, dynamic>.from(fm['items'] as Map)
            : Map<String, dynamic>.from(fm);

        for (final k in fullMenuAll.keys) {
          final v = src[k];
          if (v is List) {
            for (final e in v) {
              if (e is Map) fullMenuAll[k]!.add(Map<String, dynamic>.from(e));
            }
          }
        }
      }
    }

    final firstFullMenu = firstJson['fullMenu'] ??
        firstJson['full_menu'] ??
        firstJson['menu'] ??
        firstJson['menus'];
    final firstFullMenuMap =
        firstFullMenu is Map ? Map<String, dynamic>.from(firstFullMenu) : null;

    merged[_directRecommendedMenuMarkerKey] = hasDirectRecommended;
    merged['recommended'] = _dedupList(recommendedAll);
    merged['fullMenu'] = {
      'items': _dedupCategoryMap(fullMenuAll),
      'summary': firstFullMenuMap != null
          ? ((firstFullMenuMap['summary'] ?? '').toString())
          : '',
      'truncated': firstFullMenuMap != null
          ? (firstFullMenuMap['truncated'] == true)
          : false,
    };

    final inferredResultType = merged['isMenu'] == false ? 'not_menu' : 'menu';
    merged['result_type'] = normalizeResultType(
      (merged['result_type'] ?? merged['resultType'] ?? inferredResultType)
          .toString(),
    );
    merged['user_message'] =
        (merged['user_message'] ?? merged['userMessage'] ?? '')
            .toString()
            .trim();

    return ResultParsingOutput(aiJson: merged, aiJsonError: null);
  }

  static List<Map<String, dynamic>> getRecommendedItems(
      Map<String, dynamic>? aiJson) {
    if (aiJson == null) return const [];
    return _recommendedItemsFromJson(aiJson);
  }

  static String aiResultType(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return 'unknown';
    return normalizeResultType(
      (aiJson['result_type'] ?? aiJson['resultType'] ?? '').toString(),
    );
  }

  static String normalizeResultType(String value) {
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(
          RegExp(r'\s+'),
          '_',
        );
  }

  static bool isNonMenuResultType(String value) {
    return _nonMenuResultTypes.contains(normalizeResultType(value));
  }

  static bool hasValidRecommendedMenu(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return false;
    if (isNonMenuResultType(aiResultType(aiJson))) return false;

    final marker = aiJson[_directRecommendedMenuMarkerKey];
    if (marker is bool) return marker;

    return _hasValidMenuItems(_mapList(aiJson['recommended']));
  }

  static bool shouldShowDecisionSummary(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return false;
    if (isNonMenuResultType(aiResultType(aiJson))) return false;
    return hasValidRecommendedMenu(aiJson);
  }

  static bool hasUsableFullMenu(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return false;

    final rawFullMenu = aiJson['fullMenu'] ??
        aiJson['full_menu'] ??
        aiJson['menu'] ??
        aiJson['menus'];
    if (rawFullMenu is! Map) return false;

    final items = rawFullMenu['items'];
    final itemsMap = items is Map ? items : rawFullMenu;
    return itemsMap.values.any((value) => value is List && value.isNotEmpty);
  }

  static String aiUserMessage(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return '';
    return (aiJson['user_message'] ?? aiJson['userMessage'] ?? '')
        .toString()
        .trim();
  }

  static String normalizeMenuText(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9가-힣\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String sanitizeMenuName(String raw) {
    var s = raw.replaceAll('\r', '').trim();
    if (s.isEmpty) return s;

    final nextItem = RegExp(r'\s*[2-9]\s*[\.\)\]\:\-]\.??\s*');
    final cut = nextItem.firstMatch(s);
    if (cut != null && cut.start > 0) {
      s = s.substring(0, cut.start).trim();
    }

    const cutTokens = <String>[' - ', ' – ', ' — ', ': ', '(', '[', '|'];
    for (final t in cutTokens) {
      final idx = s.indexOf(t);
      if (idx > 0) s = s.substring(0, idx).trim();
    }

    s = s.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();
    return s;
  }

  static String safePrefix(String geohash, int len) {
    if (geohash.isEmpty) return geohash;
    if (len <= 0) return geohash;
    return geohash.substring(0, geohash.length < len ? geohash.length : len);
  }

  static bool _hasValidMenuItems(List<Map<String, dynamic>> items) {
    return items.any((item) {
      final original = (item['nameOriginal'] ??
              item['original'] ??
              item['menuOriginal'] ??
              '')
          .toString()
          .trim();
      final translated = (item['name'] ??
              item['nameTranslated'] ??
              item['translated'] ??
              item['menuName'] ??
              '')
          .toString()
          .trim();

      return original.isNotEmpty || translated.isNotEmpty;
    });
  }

  static List<Map<String, dynamic>> _dedupList(
      List<Map<String, dynamic>> items) {
    final indexesByKey = <String, int>{};
    final out = <Map<String, dynamic>>[];
    for (final it in items) {
      final key = _menuItemKey(it);
      final existingIndex = indexesByKey[key];
      if (existingIndex == null) {
        indexesByKey[key] = out.length;
        out.add(it);
      } else {
        _mergeSourceImageIndexes(out[existingIndex], it);
      }
    }
    return out;
  }

  static String _menuItemKey(Map<String, dynamic> item) {
    final original =
        _stableMenuText((item['nameOriginal'] ?? '').toString());
    final translated = _stableMenuText((item['name'] ?? '').toString());
    final name = original.isNotEmpty ? original : translated;
    return name.isNotEmpty ? name : item.toString();
  }

  static String _stableMenuText(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<String, dynamic>? _removeRecommendedOverlap(
    dynamic rawFullMenu,
    List<Map<String, dynamic>> recommended,
  ) {
    if (rawFullMenu == null) return null;
    if (rawFullMenu is! Map) return null;

    final fullMenu = Map<String, dynamic>.from(rawFullMenu);
    final recommendedKeys = recommended.map(_menuItemKey).toSet();
    final rawItems = fullMenu['items'];
    final source = rawItems is Map
        ? Map<String, dynamic>.from(rawItems)
        : Map<String, dynamic>.from(fullMenu);
    final filtered = <String, dynamic>{};

    for (final entry in source.entries) {
      final value = entry.value;
      if (value is! List) {
        filtered[entry.key] = value;
        continue;
      }
      filtered[entry.key] = value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => !recommendedKeys.contains(_menuItemKey(item)))
          .toList();
    }

    if (rawItems is Map) {
      fullMenu['items'] = filtered;
    } else {
      fullMenu
        ..clear()
        ..addAll(filtered);
    }
    return fullMenu;
  }

  static Map<String, List<Map<String, dynamic>>> _dedupCategoryMap(
      Map<String, List<Map<String, dynamic>>> categories) {
    final indexesByKey = <String, Map<String, dynamic>>{};
    final output = <String, List<Map<String, dynamic>>>{
      for (final key in categories.keys) key: <Map<String, dynamic>>[],
    };

    for (final key in categories.keys) {
      for (final item in categories[key]!) {
        final itemKey = _menuItemKey(item);
        final existing = indexesByKey[itemKey];
        if (existing == null) {
          indexesByKey[itemKey] = item;
          output[key]!.add(item);
        } else {
          _mergeSourceImageIndexes(existing, item);
        }
      }
    }
    return output;
  }

  static void _mergeSourceImageIndexes(
      Map<String, dynamic> target, Map<String, dynamic> source) {
    final merged = <int>{};
    for (final item in [target, source]) {
      final indexes = item['sourceImageIndexes'];
      if (indexes is List) {
        merged.addAll(indexes.whereType<int>().where((index) => index >= 1));
      }
    }
    if (merged.isNotEmpty) {
      target['sourceImageIndexes'] = merged.toList()..sort();
    }
  }

  static List<Map<String, dynamic>> _directRecommendedItemsFromJson(
      Map<String, dynamic> aiJson) {
    final recommended = _mapList(aiJson['recommended']);
    if (recommended.isNotEmpty) return _dedupList(recommended);
    return _dedupList(_mapList(aiJson['items']));
  }

  static List<Map<String, dynamic>> _recommendedItemsFromJson(
    Map<String, dynamic> aiJson,
  ) {
    final recItems = _mapList(aiJson['recommended']);
    if (recItems.isNotEmpty) return _dedupList(recItems);

    final directItems = _mapList(aiJson['items']);
    if (directItems.isNotEmpty) return _dedupList(directItems);

    final rawFm = aiJson['fullMenu'] ??
        aiJson['full_menu'] ??
        aiJson['menu'] ??
        aiJson['menus'];
    if (rawFm is! Map) return const [];

    final fm = Map<String, dynamic>.from(rawFm);
    final nestedItems = fm['items'];
    final fromNestedList = _mapList(nestedItems);
    if (fromNestedList.isNotEmpty) return _dedupList(fromNestedList);

    if (nestedItems is Map) {
      return _dedupList(
          _categoryMapItems(Map<String, dynamic>.from(nestedItems)));
    }

    return _dedupList(_categoryMapItems(fm));
  }

  static List<Map<String, dynamic>> _categoryMapItems(
      Map<String, dynamic> source) {
    final out = <Map<String, dynamic>>[];
    for (final k in const [
      'main',
      'side',
      'meal',
      'drink',
      'beverage',
      'unknown'
    ]) {
      out.addAll(_mapList(source[k]));
    }
    return out;
  }

  static List<Map<String, dynamic>> _mapList(dynamic source) {
    if (source is! List) return const [];
    return source
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
