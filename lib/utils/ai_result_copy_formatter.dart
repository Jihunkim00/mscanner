import 'dart:convert';

class AiResultCopyFormatterLabels {
  final String recommendedTitle;
  final String summaryTitle;
  final String priceLabel;
  final String tagsLabel;
  final String noContentFallback;

  const AiResultCopyFormatterLabels({
    this.recommendedTitle = 'Recommended Dishes',
    this.summaryTitle = 'Summary',
    this.priceLabel = 'Price',
    this.tagsLabel = 'Tags',
    this.noContentFallback = 'No content available',
  });
}

class AiResultCopyFormatter {
  const AiResultCopyFormatter._();

  static String buildReadableText({
    required Map<String, dynamic>? aiJson,
    List<String> fallbackResponses = const [],
    String fallbackStreamText = '',
    String? Function(Map<String, dynamic> item)? priceLabelBuilder,
    AiResultCopyFormatterLabels labels = const AiResultCopyFormatterLabels(),
  }) {
    final rec = _getRecommendedItems(aiJson);

    if (rec.isEmpty) {
      final fallback = _buildFallbackText(
        fallbackResponses: fallbackResponses,
        fallbackStreamText: fallbackStreamText,
      );
      return fallback.isNotEmpty ? fallback : labels.noContentFallback;
    }

    final buffer = StringBuffer();

    buffer.writeln(labels.recommendedTitle);
    buffer.writeln();

    int visibleIndex = 1;
    for (final item in rec) {
      final name = _menuDisplayName(item);
      if (name.isEmpty) continue;

      final desc = (item['shortDesc'] ?? '').toString().trim();
      final price = priceLabelBuilder?.call(item)?.trim() ?? '';
      final tags = _extractTags(item);

      buffer.writeln('$visibleIndex. $name');
      visibleIndex++;

      if (desc.isNotEmpty) {
        buffer.writeln('- $desc');
      }

      if (price.isNotEmpty) {
        buffer.writeln('- ${labels.priceLabel}: $price');
      }

      if (tags.isNotEmpty) {
        buffer.writeln('- ${labels.tagsLabel}: ${tags.join(', ')}');
      }

      buffer.writeln();
    }

    final summary = _extractSummary(aiJson);
    if (summary.isNotEmpty) {
      buffer.writeln(labels.summaryTitle);
      buffer.writeln(summary);
      buffer.writeln();
    }

    final result = buffer.toString().trim();
    return result.isNotEmpty ? result : labels.noContentFallback;
  }

  static String buildRawText({
    required Map<String, dynamic>? aiJson,
    List<String> fallbackResponses = const [],
    String fallbackStreamText = '',
  }) {
    if (aiJson != null) {
      try {
        return const JsonEncoder.withIndent('  ').convert(aiJson);
      } catch (_) {}
    }

    final fallback = _buildFallbackText(
      fallbackResponses: fallbackResponses,
      fallbackStreamText: fallbackStreamText,
    );
    return fallback;
  }

  static List<Map<String, dynamic>> _getRecommendedItems(
    Map<String, dynamic>? aiJson,
  ) {
    if (aiJson == null) return const [];

    final rec = aiJson['recommended'];
    if (rec is List) {
      final recommended = rec
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (recommended.isNotEmpty) return recommended;
    }

    final items = aiJson['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  static String _menuDisplayName(Map<String, dynamic> item) {
    final o =
        (item['nameOriginal'] ?? item['original'] ?? '').toString().trim();
    final t =
        (item['name'] ?? item['nameTranslated'] ?? item['translated'] ?? '')
            .toString()
            .trim();

    if (o.isNotEmpty && t.isNotEmpty && o.toLowerCase() != t.toLowerCase()) {
      return '$o ($t)';
    }
    return o.isNotEmpty ? o : t;
  }

  static List<String> _extractTags(Map<String, dynamic> item) {
    final tags = item['tags'];
    if (tags is! List) return const [];

    return tags
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _extractSummary(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return '';

    final rawFm = aiJson['fullMenu'] ??
        aiJson['full_menu'] ??
        aiJson['menu'] ??
        aiJson['menus'];

    if (rawFm is Map) {
      return (rawFm['summary'] ?? '').toString().trim();
    }
    return '';
  }

  static String _buildFallbackText({
    List<String> fallbackResponses = const [],
    String fallbackStreamText = '',
  }) {
    final joined = fallbackResponses
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n\n')
        .trim();

    if (joined.isNotEmpty) return joined;
    return fallbackStreamText.trim();
  }
}
