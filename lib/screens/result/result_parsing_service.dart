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
  }) {
    Map<String, dynamic>? firstJson;
    final List<Map<String, dynamic>> jsonList = [];
    String? aiJsonError;

    for (final r in responses) {
      final raw = r.trim();
      final s = extractJsonObjectFromText(raw);
      if (s == null) continue;

      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          firstJson ??= m;
          jsonList.add(m);
        }
      } catch (e) {
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

    return ResultParsingOutput(aiJson: merged, aiJsonError: null);
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
}