import 'dart:convert';

import '../../core/logging/vision_scan_logger.dart';
import '../../core/prompt/scan_prompt_builder.dart';
import '../../models/vision_scan_response.dart';

class ResultParsingOutput {
  const ResultParsingOutput({
    required this.aiJson,
    required this.aiJsonError,
  });

  final Map<String, dynamic>? aiJson;
  final String? aiJsonError;
}

class ResultParsingService {
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
    if (s.contains('usd') || s.contains(r'$') || s.contains('달러')) {
      return 'USD';
    }
    if (s.contains('eur') || s.contains('€') || s.contains('유로')) {
      return 'EUR';
    }
    if (s.contains('cny') || s.contains('元') || s.contains('위안')) {
      return 'CNY';
    }

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
    var hadNonEmptyResponse = false;

    for (final r in responses) {
      final raw = r.trim();
      if (raw.isNotEmpty) hadNonEmptyResponse = true;
      final s = extractJsonObjectFromText(raw);
      if (s == null) {
        if (raw.isNotEmpty) {
          aiJsonError = 'No JSON object found in response';
          visionScanDebugPrint('[VisionScan] parse failed=$aiJsonError');
          visionScanDebugPrint(
            '[VisionScan] raw response preview=${_rawPreview(raw)}',
          );
        }
        continue;
      }

      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final m = _normalizeResponse(
            Map<String, dynamic>.from(decoded),
            sourceImageIndex: jsonList.length,
          );
          firstJson ??= m;
          jsonList.add(m);
        }
      } catch (e, stackTrace) {
        aiJsonError =
            'jsonDecode failed: $e\nrawHead=${raw.substring(0, raw.length > 120 ? 120 : raw.length)}';
        visionScanDebugPrint('[VisionScan] parse failed=$e');
        visionScanDebugPrint(
          '[VisionScan] raw response preview=${_rawPreview(raw)}',
        );
        visionScanDebugPrintStack(
          label: '[VisionScan] parse stack',
          stackTrace: stackTrace,
        );
      }
    }

    if (firstJson == null) {
      if (hadNonEmptyResponse) {
        visionScanDebugPrint(
          '[VisionScan] parse failed=${aiJsonError ?? 'No parseable JSON response'}',
        );
      }
      return ResultParsingOutput(aiJson: null, aiJsonError: aiJsonError);
    }

    final isMulti = imageCount > 1 || jsonList.length > 1;

    if (!isMulti) {
      final normalized = Map<String, dynamic>.from(firstJson);
      normalized['result_type'] =
          (normalized['result_type'] ?? 'menu').toString().trim().toLowerCase();
      normalized['user_message'] =
          (normalized['user_message'] ?? '').toString().trim();
      _logParsedResult(normalized);
      return ResultParsingOutput(aiJson: normalized, aiJsonError: null);
    }

    final merged = Map<String, dynamic>.from(firstJson);
    final List<Map<String, dynamic>> recommendedAll = [];
    final List<Map<String, dynamic>> itemsAll = [];
    final List<Map<String, dynamic>> imageLevelDetections = [];
    final List<String> warnings = [];
    final Map<String, List<Map<String, dynamic>>> fullMenuAll = {
      for (final category in ScanPromptBuilder.fullMenuCategories)
        category: <Map<String, dynamic>>[],
    };

    for (final j in jsonList) {
      final items = j['items'];
      if (items is List) {
        for (final e in items) {
          if (e is Map) itemsAll.add(Map<String, dynamic>.from(e));
        }
      }

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

      final detections = j['imageLevelDetections'];
      if (detections is List) {
        for (final e in detections) {
          if (e is Map) {
            imageLevelDetections.add(Map<String, dynamic>.from(e));
          }
        }
      }

      final responseWarnings = j['warnings'];
      if (responseWarnings is List) {
        warnings.addAll(
          responseWarnings
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty),
        );
      }
    }

    final mergedRecommended = _dedupList(recommendedAll);
    final mergedItems = _dedupList(
      itemsAll.isNotEmpty
          ? itemsAll
          : [
              ...recommendedAll,
              for (final values in fullMenuAll.values) ...values,
            ],
    );

    merged['isMultiScan'] = true;
    merged['recommended'] = mergedRecommended;
    merged['items'] = mergedItems;
    merged['fullMenu'] = {
      'items': {
        for (final k in fullMenuAll.keys) k: _dedupList(fullMenuAll[k]!)
      },
      'summary': (firstJson['fullMenu'] is Map)
          ? ((firstJson['fullMenu']['summary'] ?? '').toString())
          : '',
      'truncated': (firstJson['fullMenu'] is Map)
          ? (firstJson['fullMenu']['truncated'] == true)
          : false,
    };
    merged['imageLevelDetections'] =
        _dedupImageLevelDetections(imageLevelDetections);
    final detectedMenuTypes = imageLevelDetections
        .map((item) => (item['detectedMenuType'] ?? '').toString().trim())
        .where((item) => item.isNotEmpty && item != 'unknown')
        .toSet();
    if (detectedMenuTypes.length > 1) {
      warnings.add('mixed_menu_types_across_images');
    }
    merged['warnings'] = warnings.toSet().toList(growable: false);
    merged['foodStyleSummary'] = _mergeFoodStyleSummary(firstJson, mergedItems);

    merged['result_type'] =
        (merged['result_type'] ?? 'menu').toString().trim().toLowerCase();
    merged['user_message'] = (merged['user_message'] ?? '').toString().trim();

    _logParsedResult(merged);
    return ResultParsingOutput(aiJson: merged, aiJsonError: null);
  }

  static VisionScanResponse? parseVisionResponse({
    required List<String> responses,
    required int imageCount,
  }) {
    final parsed = parseAiJson(
      responses: responses,
      imageCount: imageCount,
    );
    final json = parsed.aiJson;
    return json == null ? null : VisionScanResponse.fromJson(json);
  }

  static List<Map<String, dynamic>> getRecommendedItems(
      Map<String, dynamic>? aiJson) {
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

  static List<Map<String, dynamic>> getItems(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return const [];
    return _mapItems(aiJson['items']);
  }

  static List<Map<String, dynamic>> getDisplayItems(
      Map<String, dynamic>? aiJson) {
    final recommended = getRecommendedItems(aiJson);
    if (recommended.isNotEmpty) return recommended;
    return getItems(aiJson);
  }

  static int fullMenuItemCount(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return 0;
    final fullMenu = aiJson['fullMenu'];
    if (fullMenu is! Map) return 0;
    final items = fullMenu['items'];
    if (items is! Map) return 0;

    var count = 0;
    for (final category in ScanPromptBuilder.fullMenuCategories) {
      final value = items[category];
      if (value is List) count += value.length;
    }
    return count;
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

  static List<Map<String, dynamic>> _dedupList(
      List<Map<String, dynamic>> items) {
    final indexesByKey = <String, int>{};
    final out = <Map<String, dynamic>>[];
    for (final it in items) {
      final no = (it['originalName'] ?? it['nameOriginal'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final nt = (it['translatedName'] ?? it['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final key = (no.isNotEmpty ? no : nt).trim();
      final dedupKey = key.isNotEmpty ? key : it.toString();
      final existingIndex = indexesByKey[dedupKey];
      if (existingIndex == null) {
        indexesByKey[dedupKey] = out.length;
        out.add(Map<String, dynamic>.from(it));
        continue;
      }

      final existing = out[existingIndex];
      final mergedSources = <int>{
        ..._intValues(existing['sourceImageIndexes']),
        ..._intValues(it['sourceImageIndexes']),
      }.toList()
        ..sort();
      existing['sourceImageIndexes'] = mergedSources;

      if ((existing['description'] ?? existing['shortDesc'] ?? '')
              .toString()
              .trim()
              .isEmpty &&
          (it['description'] ?? it['shortDesc'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) {
        existing['description'] = it['description'] ?? it['shortDesc'];
        existing['shortDesc'] = it['shortDesc'] ?? it['description'];
      }
    }
    return out;
  }

  static Map<String, dynamic> _normalizeResponse(
    Map<String, dynamic> input, {
    required int sourceImageIndex,
  }) {
    final normalized = Map<String, dynamic>.from(input);
    final recommended = _normalizeItemList(
      normalized['recommended'],
      sourceImageIndex: sourceImageIndex,
    );

    final fullMenuSource = normalized['fullMenu'] ??
        normalized['full_menu'] ??
        normalized['menu'] ??
        normalized['menus'];
    final fullMenuMap = fullMenuSource is Map
        ? Map<String, dynamic>.from(fullMenuSource)
        : <String, dynamic>{};
    final categoriesSource = fullMenuMap['items'] is Map
        ? Map<String, dynamic>.from(fullMenuMap['items'] as Map)
        : fullMenuMap;
    final categories = <String, List<Map<String, dynamic>>>{
      for (final category in ScanPromptBuilder.fullMenuCategories)
        category: _normalizeItemList(
          categoriesSource[category],
          sourceImageIndex: sourceImageIndex,
        ),
    };

    var items = _normalizeItemList(
      normalized['items'],
      sourceImageIndex: sourceImageIndex,
    );
    if (items.isEmpty) {
      items = _dedupList([
        ...recommended,
        for (final values in categories.values) ...values,
      ]);
    }

    final resolvedRecommended = recommended;

    normalized['targetLanguage'] =
        (normalized['targetLanguage'] ?? normalized['outputLanguage'] ?? '')
            .toString();
    normalized['outputLanguage'] =
        (normalized['outputLanguage'] ?? normalized['targetLanguage'] ?? '')
            .toString();
    normalized['presetVersion'] =
        (normalized['presetVersion'] ?? '').toString();
    normalized['scanPreset'] = (normalized['scanPreset'] ?? '').toString();
    normalized['detailLevel'] = (normalized['detailLevel'] ?? '').toString();
    normalized['isMultiScan'] = normalized['isMultiScan'] == true;
    normalized['selectedFoodStyle'] =
        (normalized['selectedFoodStyle'] ?? '').toString();
    normalized['selectedFoodStyleLabel'] =
        (normalized['selectedFoodStyleLabel'] ?? '').toString();
    normalized['foodStyleApplied'] = normalized['foodStyleApplied'] == true;
    normalized['foodStyleSummary'] = _normalizedFoodStyleSummary(
      normalized['foodStyleSummary'],
      selectedFoodStyle: normalized['selectedFoodStyle'].toString(),
      items: items,
    );
    normalized['imageLevelDetections'] =
        _normalizeMapList(normalized['imageLevelDetections']);
    normalized['warnings'] = normalized['warnings'] is List
        ? List<dynamic>.from(normalized['warnings'] as List)
        : <dynamic>[];
    normalized['items'] = items;
    normalized['recommended'] = resolvedRecommended;
    normalized['fullMenu'] = {
      'items': categories,
      'summary': (fullMenuMap['summary'] ?? '').toString(),
      'truncated': fullMenuMap['truncated'] == true,
    };
    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeItemList(
    dynamic value, {
    required int sourceImageIndex,
  }) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(
          (item) => _normalizeItem(
            Map<String, dynamic>.from(item),
            sourceImageIndex: sourceImageIndex,
          ),
        )
        .toList();
  }

  static Map<String, dynamic> _normalizeItem(
    Map<String, dynamic> item, {
    required int sourceImageIndex,
  }) {
    final normalized = Map<String, dynamic>.from(item);
    final originalName =
        (normalized['originalName'] ?? normalized['nameOriginal'] ?? '')
            .toString()
            .trim();
    final translatedName =
        (normalized['translatedName'] ?? normalized['name'] ?? '')
            .toString()
            .trim();
    final description =
        (normalized['description'] ?? normalized['shortDesc'] ?? '')
            .toString()
            .trim();
    final prices = normalized['prices'] is Map
        ? Map<String, dynamic>.from(normalized['prices'] as Map)
        : <String, dynamic>{};
    final price = normalized.containsKey('price')
        ? normalized['price']
        : prices['single'];
    final currencyCode = normalized['currencyCode'] ?? prices['currency'];
    final sourceIndexes = _intValues(normalized['sourceImageIndexes']);

    normalized['originalName'] = originalName;
    normalized['translatedName'] = translatedName;
    normalized['description'] = description;
    normalized['nameOriginal'] = originalName;
    normalized['name'] =
        translatedName.isNotEmpty ? translatedName : originalName;
    normalized['shortDesc'] = description;
    normalized['price'] = price;
    normalized['currencyCode'] = currencyCode;
    normalized['convertedPrice'] = normalized['convertedPrice'];
    normalized['prices'] = {
      'small': prices['small'],
      'medium': prices['medium'],
      'large': prices['large'],
      'single': prices.containsKey('single') ? prices['single'] : price,
      'currency':
          prices.containsKey('currency') ? prices['currency'] : currencyCode,
    };
    normalized['foodStyleFit'] =
        (normalized['foodStyleFit'] ?? 'unknown').toString();
    normalized['styleMatched'] =
        normalized['styleMatched'] is bool ? normalized['styleMatched'] : null;
    normalized['styleFitScore'] = _decimal(normalized['styleFitScore']);
    normalized['recommendationRank'] =
        _nullableInt(normalized['recommendationRank']);
    normalized['recommendationReason'] =
        _nullableString(normalized['recommendationReason']);
    normalized['matchedEvidence'] =
        _stringValues(normalized['matchedEvidence']);
    normalized['cautionReason'] = _nullableString(normalized['cautionReason']);
    normalized['dietaryWarnings'] =
        _stringValues(normalized['dietaryWarnings']);
    normalized['allergyHints'] = _stringValues(normalized['allergyHints']);
    normalized['requiresStaffCheck'] = normalized['requiresStaffCheck'] == true;
    normalized['confidence'] = _decimal(normalized['confidence']);
    normalized['sourceImageIndexes'] =
        sourceIndexes.isEmpty ? [sourceImageIndex] : sourceIndexes;
    return normalized;
  }

  static Map<String, dynamic> _normalizedFoodStyleSummary(
    dynamic value, {
    required String selectedFoodStyle,
    required List<Map<String, dynamic>> items,
  }) {
    final source =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    final calculated = _calculateFoodStyleCounts(items);
    return {
      'styleId': (source['styleId'] ?? selectedFoodStyle).toString(),
      'matchedItemCount':
          _nullableInt(source['matchedItemCount']) ?? calculated.$1,
      'cautionItemCount':
          _nullableInt(source['cautionItemCount']) ?? calculated.$2,
      'notRecommendedItemCount':
          _nullableInt(source['notRecommendedItemCount']) ?? calculated.$3,
      'topRecommendedItemIndexes':
          _intValues(source['topRecommendedItemIndexes']),
      'confidence': _decimal(source['confidence']),
      'reason': (source['reason'] ?? '').toString(),
      'disclaimer': (source['disclaimer'] ?? '').toString(),
    };
  }

  static Map<String, dynamic> _mergeFoodStyleSummary(
    Map<String, dynamic> firstJson,
    List<Map<String, dynamic>> items,
  ) {
    final firstSummary = firstJson['foodStyleSummary'] is Map
        ? Map<String, dynamic>.from(firstJson['foodStyleSummary'] as Map)
        : <String, dynamic>{};
    final counts = _calculateFoodStyleCounts(items);
    final rankedIndexes = <(int, int)>[];
    for (var index = 0; index < items.length; index++) {
      final rank = _nullableInt(items[index]['recommendationRank']);
      if (rank != null) rankedIndexes.add((rank, index));
    }
    rankedIndexes.sort((a, b) => a.$1.compareTo(b.$1));

    return {
      'styleId':
          (firstSummary['styleId'] ?? firstJson['selectedFoodStyle'] ?? '')
              .toString(),
      'matchedItemCount': counts.$1,
      'cautionItemCount': counts.$2,
      'notRecommendedItemCount': counts.$3,
      'topRecommendedItemIndexes':
          rankedIndexes.map((entry) => entry.$2).take(5).toList(),
      'confidence': _decimal(firstSummary['confidence']),
      'reason': (firstSummary['reason'] ?? '').toString(),
      'disclaimer': (firstSummary['disclaimer'] ?? '').toString(),
    };
  }

  static (int, int, int) _calculateFoodStyleCounts(
    List<Map<String, dynamic>> items,
  ) {
    var matched = 0;
    var caution = 0;
    var notRecommended = 0;
    for (final item in items) {
      final fit = (item['foodStyleFit'] ?? '').toString().toLowerCase();
      if (fit == 'recommended' || item['styleMatched'] == true) {
        matched++;
      } else if (fit == 'caution') {
        caution++;
      } else if (fit == 'notrecommended' ||
          fit == 'not_recommended' ||
          item['styleMatched'] == false) {
        notRecommended++;
      }
    }
    return (matched, caution, notRecommended);
  }

  static List<Map<String, dynamic>> _dedupImageLevelDetections(
    List<Map<String, dynamic>> detections,
  ) {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final detection in detections) {
      final index = _nullableInt(detection['imageIndex']) ?? result.length;
      if (!seen.add(index)) continue;
      result.add({...detection, 'imageIndex': index});
    }
    return result;
  }

  static List<Map<String, dynamic>> _normalizeMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _mapItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static void _logParsedResult(Map<String, dynamic> parsed) {
    final itemsCount = getItems(parsed).length;
    final recommendedCount = getRecommendedItems(parsed).length;
    final fullMenuCount = fullMenuItemCount(parsed);
    final displayCount = getDisplayItems(parsed).length;

    visionScanDebugPrint('[VisionScan] parse success items=$itemsCount');
    visionScanDebugPrint('[VisionScan] recommended=$recommendedCount');
    visionScanDebugPrint('[VisionScan] fullMenuCount=$fullMenuCount');
    visionScanDebugPrint(
      '[VisionScan] selectedFoodStyle=${parsed['selectedFoodStyle'] ?? ''}',
    );
    visionScanDebugPrint(
      '[VisionScan] foodStyleApplied=${parsed['foodStyleApplied'] == true}',
    );
    visionScanDebugPrint('[VisionScan] displayItems=$displayCount');
  }

  static String _rawPreview(String value, {int maxLength = 1200}) {
    final normalized = value
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  static List<int> _intValues(dynamic value) {
    if (value is! List) return const [];
    return value.map(_nullableInt).whereType<int>().toList(growable: false);
  }

  static List<String> _stringValues(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _nullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _decimal(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
