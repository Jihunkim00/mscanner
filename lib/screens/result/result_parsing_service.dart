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
  static void _logParseFailure({
    required String raw,
    required Object exception,
    String? scanMode,
    int? photoCount,
  }) {
    final first = raw.substring(0, raw.length > 500 ? 500 : raw.length);
    final last = raw.length > 500 ? raw.substring(raw.length - 500) : raw;
    print(
      '❌ [ResultParsing] JSON parse failed '
      'responseLength=${raw.length} '
      'scanMode=${scanMode ?? 'unknown'} '
      'photoCount=${photoCount ?? 'unknown'} '
      'exception=$exception\n'
      'first500=$first\n'
      'last500=$last',
    );
  }

  static String? extractCurrencyCodeFromText(String text) {
    final s = text.toLowerCase();

    if (s.contains('krw') || s.contains('₩') || s.contains('원')) return 'KRW';
    if (s.contains('jpy') || s.contains('¥') || s.contains('엔화') || s.contains('엔')) return 'JPY';
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
    String? scanMode,
    int? photoCount,
  }) {
    Map<String, dynamic>? firstJson;
    final List<Map<String, dynamic>> jsonList = [];
    String? aiJsonError;

    for (final r in responses) {
      final raw = r.trim();
      final s = extractJsonObjectFromText(raw);
      if (s == null) {
        _logParseFailure(
          raw: raw,
          exception: 'No JSON object found in response',
          scanMode: scanMode,
          photoCount: photoCount ?? imageCount,
        );
        aiJsonError ??= 'No JSON object found in response';
        continue;
      }

      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          firstJson ??= m;
          jsonList.add(m);
        }
      } catch (e) {
        _logParseFailure(
          raw: raw,
          exception: e,
          scanMode: scanMode,
          photoCount: photoCount ?? imageCount,
        );
        aiJsonError =
            'jsonDecode failed: $e\nrawHead=${raw.substring(0, raw.length > 120 ? 120 : raw.length)}';
      }
    }

    if (firstJson == null) {
      return ResultParsingOutput(aiJson: null, aiJsonError: aiJsonError);
    }

    final isMulti = imageCount > 1 || jsonList.length > 1;

    if (!isMulti) {
      final normalized = Map<String, dynamic>.from(firstJson);
      normalized['result_type'] =
          (normalized['result_type'] ?? 'menu').toString().trim().toLowerCase();
      normalized['user_message'] =
          (normalized['user_message'] ?? '').toString().trim();
      if ((normalized['scanMode'] ?? '').toString().toLowerCase() == 'multi') {
        return ResultParsingOutput(
          aiJson: normalizeMultiScanFields(normalized, imageCount: imageCount),
          aiJsonError: null,
        );
      }
      normalized['scanMode'] = (normalized['scanMode'] ?? 'single').toString();
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

    for (final j in jsonList) {
      final rec = j['recommended'];
      if (rec is List) {
        for (final e in rec) {
          if (e is Map) recommendedAll.add(Map<String, dynamic>.from(e));
        }
      }

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

    merged['recommended'] = _dedupList(recommendedAll);
    merged['fullMenu'] = {
      'items': {for (final k in fullMenuAll.keys) k: _dedupList(fullMenuAll[k]!)},
      'summary': (firstJson['fullMenu'] is Map)
          ? ((firstJson['fullMenu']['summary'] ?? '').toString())
          : '',
      'truncated':
      (firstJson['fullMenu'] is Map) ? (firstJson['fullMenu']['truncated'] == true) : false,
    };

    merged['result_type'] =
        (merged['result_type'] ?? 'menu').toString().trim().toLowerCase();
    merged['user_message'] = (merged['user_message'] ?? '').toString().trim();

    return ResultParsingOutput(
      aiJson: normalizeMultiScanFields(merged, imageCount: imageCount),
      aiJsonError: null,
    );
  }

  static List<Map<String, dynamic>> getRecommendedItems(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return const [];
    final rec = aiJson['recommended'];
    if (rec is List) {
      return rec
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  static String aiResultType(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return 'unknown';
    return (aiJson['result_type'] ?? '').toString().trim().toLowerCase();
  }

  static String aiUserMessage(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return '';
    return (aiJson['user_message'] ?? '').toString().trim();
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

  static List<Map<String, dynamic>> _dedupList(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final it in items) {
      final no = (it['nameOriginal'] ?? '').toString().trim().toLowerCase();
      final nt = (it['name'] ?? '').toString().trim().toLowerCase();
      final key = (no.isNotEmpty ? no : nt).trim();
      final dedupKey = key.isNotEmpty ? key : it.toString();
      if (seen.add(dedupKey)) out.add(it);
    }
    return out;
  }
  static Map<String, dynamic> normalizeMultiScanFields(
    Map<String, dynamic> input, {
    required int imageCount,
  }) {
    final normalized = Map<String, dynamic>.from(input);
    final photoAnalyses = _safePhotoAnalyses(normalized['photoAnalyses']);
    final mergedResult = _safeMergedResult(
      normalized['mergedResult'],
      photoAnalyses: photoAnalyses,
      fallbackPhotoCount: imageCount,
      fallbackUniqueCount: _countLegacyMenuItems(normalized),
    );

    final hadLegacyMenuItems = _countLegacyMenuItems(normalized) > 0;

    normalized['scanMode'] = 'multi';
    normalized['photoAnalyses'] = photoAnalyses;
    normalized['mergedResult'] = mergedResult;
    _applyRecommendedItemsFallback(normalized, mergedResult);
    if (!hadLegacyMenuItems && photoAnalyses.isNotEmpty) {
      normalized['fullMenu'] = {
        'items': {
          'main': <Map<String, dynamic>>[],
          'side': <Map<String, dynamic>>[],
          'meal': <Map<String, dynamic>>[],
          'drink': <Map<String, dynamic>>[],
          'beverage': <Map<String, dynamic>>[],
          'unknown': _itemsFromPhotoAnalyses(photoAnalyses),
        },
        'summary': '',
        'truncated': false,
      };
    }

    return normalized;
  }

  static List<Map<String, dynamic>> getPhotoAnalyses(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return const [];
    return _safePhotoAnalyses(aiJson['photoAnalyses']);
  }

  static Map<String, dynamic> getMergedResult(
    Map<String, dynamic>? aiJson, {
    required int fallbackPhotoCount,
  }) {
    if (aiJson == null) {
      return _safeMergedResult(
        null,
        photoAnalyses: const [],
        fallbackPhotoCount: fallbackPhotoCount,
        fallbackUniqueCount: 0,
      );
    }
    final photoAnalyses = _safePhotoAnalyses(aiJson['photoAnalyses']);
    return _safeMergedResult(
      aiJson['mergedResult'],
      photoAnalyses: photoAnalyses,
      fallbackPhotoCount: fallbackPhotoCount,
      fallbackUniqueCount: _countLegacyMenuItems(aiJson),
    );
  }

  static List<Map<String, dynamic>> _safePhotoAnalyses(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      m['photoIndex'] = _intValue(m['photoIndex']);
      m['detectedSections'] = (m['detectedSections'] is List)
          ? List<dynamic>.from(m['detectedSections'] as List)
          : <dynamic>[];
      final items = (m['items'] is List)
          ? List<dynamic>.from(m['items'] as List)
          : <dynamic>[];
      final rawItemCount = _intValue(m['itemCount']);
      final rawUnclearCount = _intValue(m['unclearItemCount']);
      final fallbackItemCount = items.whereType<Map>().length;
      final itemCount = rawItemCount > 0 ? rawItemCount : fallbackItemCount;
      final unclearCount = rawUnclearCount;
      final rawReadableCount = _intValue(m['readableItemCount']);
      final fallbackReadableCount = itemCount - unclearCount;
      final readableCount = rawReadableCount > 0
          ? rawReadableCount
          : fallbackReadableCount.clamp(0, itemCount).toInt();

      m['items'] = items;
      m['itemCount'] = itemCount;
      m['unclearItemCount'] = unclearCount;
      m['readableItemCount'] = readableCount;
      return m;
    }).toList();
  }

  static Map<String, dynamic> _safeMergedResult(
    dynamic raw, {
    required List<Map<String, dynamic>> photoAnalyses,
    required int fallbackPhotoCount,
    required int fallbackUniqueCount,
  }) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final totalFromPhotos = photoAnalyses.fold<int>(0, (sum, e) => sum + _intValue(e['itemCount']));
    final unique = _intValue(m['uniqueItemCount']) > 0
        ? _intValue(m['uniqueItemCount'])
        : (fallbackUniqueCount > 0 ? fallbackUniqueCount : totalFromPhotos);
    final total = _intValue(m['totalItemCount']) > 0
        ? _intValue(m['totalItemCount'])
        : (totalFromPhotos > 0 ? totalFromPhotos : fallbackUniqueCount);
    final duplicates = _intValue(m['duplicateItemCount']) > 0
        ? _intValue(m['duplicateItemCount'])
        : (total > unique ? total - unique : 0);

    return {
      ...m,
      'totalPhotoCount': _intValue(m['totalPhotoCount']) > 0
          ? _intValue(m['totalPhotoCount'])
          : fallbackPhotoCount,
      'totalItemCount': total,
      'uniqueItemCount': unique,
      'duplicateItemCount': duplicates,
      'recommendedItems': m['recommendedItems'] is List ? m['recommendedItems'] : <dynamic>[],
      'signatureItems': m['signatureItems'] is List ? m['signatureItems'] : <dynamic>[],
      'popularItems': m['popularItems'] is List ? m['popularItems'] : <dynamic>[],
      'localInsights': m['localInsights'] is List ? m['localInsights'] : <dynamic>[],
    };
  }



  static void _applyRecommendedItemsFallback(
    Map<String, dynamic> normalized,
    Map<String, dynamic> mergedResult,
  ) {
    final existing = normalized['recommended'];
    if (existing is List && existing.isNotEmpty) return;

    final rawRecommendedItems = mergedResult['recommendedItems'];
    if (rawRecommendedItems is! List || rawRecommendedItems.isEmpty) return;

    var id = 1;
    final mapped = <Map<String, dynamic>>[];
    for (final item in rawRecommendedItems.whereType<Map>()) {
      final m = Map<String, dynamic>.from(item);
      final original = (m['originalName'] ?? m['nameOriginal'] ?? '').toString();
      final name = (m['translatedName'] ?? m['name'] ?? original).toString();
      if (original.trim().isEmpty && name.trim().isEmpty) continue;

      mapped.add({
        'id': (m['id'] ?? 'mr${id++}').toString(),
        'nameOriginal': original,
        'name': name.trim().isNotEmpty ? name : original,
        'shortDesc': (m['description'] ?? m['shortDesc'] ?? '').toString(),
        'price': (m['price'] ?? '').toString(),
        'reason': (m['reason'] ?? '').toString(),
        'tags': m['tags'] is List ? List<dynamic>.from(m['tags'] as List) : <dynamic>[],
      });
    }

    if (mapped.isNotEmpty) {
      normalized['recommended'] = mapped;
    }
  }
  static List<Map<String, dynamic>> _itemsFromPhotoAnalyses(
    List<Map<String, dynamic>> photoAnalyses,
  ) {
    final out = <Map<String, dynamic>>[];
    var id = 1;
    for (final analysis in photoAnalyses) {
      final items = analysis['items'];
      if (items is! List) continue;
      for (final item in items.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final original = (m['originalName'] ?? m['nameOriginal'] ?? '').toString();
        final translated = (m['translatedName'] ?? m['name'] ?? original).toString();
        if (original.trim().isEmpty && translated.trim().isEmpty) continue;
        out.add({
          'id': 'p${analysis['photoIndex']}_${id++}',
          'nameOriginal': original,
          'name': translated.trim().isNotEmpty ? translated : original,
          'shortDesc': (m['description'] ?? m['shortDesc'] ?? '').toString(),
          'price': (m['price'] ?? '').toString(),
          'tags': <String>[],
          'category': 'unknown',
          'confidence': m['confidence'] ?? 0.0,
          'isUnclear': m['isUnclear'] == true,
        });
      }
    }
    return _dedupList(out);
  }
  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static int _countLegacyMenuItems(Map<String, dynamic> aiJson) {
    var count = 0;
    final rec = aiJson['recommended'];
    if (rec is List) count += rec.whereType<Map>().length;

    final fm = aiJson['fullMenu'] ?? aiJson['full_menu'] ?? aiJson['menu'] ?? aiJson['menus'];
    if (fm is Map) {
      final src = (fm['items'] is Map)
          ? Map<String, dynamic>.from(fm['items'] as Map)
          : Map<String, dynamic>.from(fm);
      for (final v in src.values) {
        if (v is List) count += v.whereType<Map>().length;
      }
    }
    return count;
  }

}