import 'dart:convert';

import 'food_style_prompt_rules.dart';
import 'scan_prompt_preset.dart';
import 'scan_prompt_version.dart';

class ScanPromptBuilder {
  static const List<String> fullMenuCategories = [
    'main',
    'side',
    'meal',
    'drink',
    'beverage',
    'unknown',
  ];

  const ScanPromptBuilder({
    required this.scanPreset,
    required this.targetLanguage,
    required this.isMultiScan,
    required this.includeCurrency,
    required this.includeRagContext,
    required this.selectedFoodStyle,
    required this.scanMode,
    this.selectedFoodStyleLabel,
    this.isPremiumUser = false,
    this.detailLevel,
    this.menuCountHint = '1-5',
    this.ragContext,
    this.sourceImageCount = 1,
  });

  final ScanPromptPreset scanPreset;
  final String targetLanguage;
  final bool isMultiScan;
  final bool includeCurrency;
  final bool includeRagContext;
  final FoodStyle selectedFoodStyle;
  final String? selectedFoodStyleLabel;
  final bool isPremiumUser;
  final String? detailLevel;
  final String scanMode;
  final String menuCountHint;
  final String? ragContext;
  final int sourceImageCount;

  String build() {
    final resolvedDetailLevel = detailLevel?.trim().isNotEmpty == true
        ? detailLevel!.trim()
        : (isPremiumUser || scanPreset.isPremium ? 'premium' : 'basic');
    final styleLabel = selectedFoodStyleLabel?.trim().isNotEmpty == true
        ? selectedFoodStyleLabel!.trim()
        : selectedFoodStyle.defaultLabel;
    final safeContext = _safeRagContext();
    final responseSchema = _buildResponseSchemaExample(
      resolvedDetailLevel: resolvedDetailLevel,
      styleLabel: styleLabel,
    );

    return '''
You are a Vision AI menu extraction, translation, and recommendation engine.
Return strict JSON only. No markdown, no code fences, and no explanation outside JSON.

Request metadata:
- presetVersion: "${ScanPromptVersion.current}"
- scanPreset: "${scanPreset.id}"
- detailLevel: "$resolvedDetailLevel"
- targetLanguage: "$targetLanguage"
- isMultiScan: $isMultiScan
- scanMode: "$scanMode"
- includeCurrency: $includeCurrency
- includeRagContext: $includeRagContext
- selectedFoodStyle: "${selectedFoodStyle.id}"
- selectedFoodStyleLabel: "$styleLabel"
- menuCountHint: "$menuCountHint"
- sourceImageCount: $sourceImageCount

Food style semantics:
- foodStyle is a recommendation bias and suitability validation rule, not a food-type classifier and not a hard filter.
- Extract every visible menu item first. Then evaluate each real item against selectedFoodStyle.
- Keep visible items even when they do not match the selected style.

${FoodStylePromptRules.forStyle(selectedFoodStyle)}

Hallucination prevention rules:
- Never invent menu items to satisfy the selected foodStyle.
- The selected foodStyle should influence recommendation, ranking, caution, and explanation, but must not remove real menu items.
- Extract all visible menu items first, then evaluate each item against the selected foodStyle.
- If price is not visible, return null instead of guessing.
- If ingredients are not visible, return null. Only premium detail may provide a clearly labeled low-confidence ingredientsGuess.
- Do not guarantee low-fat, low-salt, nut-free, or halal safety from image/menu text alone.
- For nutFree and muslimFriendly, include staff-check caution when appropriate.
- Preserve original script exactly in originalName/nameOriginal. Do not include price, numbering, or category headers in the name.
- If a reading is uncertain, return an empty nameOriginalReading.
- Return strict JSON only. No markdown, no explanation outside JSON.

Currency rules:
${includeCurrency ? '- Extract only visible price text and infer currencyCode only from reliable symbols, codes, or location evidence.\n- Keep convertedPrice=null unless a trusted conversion value is explicitly supplied in context.' : '- Return price, currencyCode, convertedPrice, and prices values as null.'}

Preset behavior:
${_presetRules(resolvedDetailLevel)}

Multi-image behavior:
${_multiScanRules()}

RAG/location context:
${safeContext.isEmpty ? '(none; do not invent local context)' : safeContext}

Return one JSON object using this backward-compatible schema:
$responseSchema

Schema rules:
- "items" contains every extracted item exactly once.
- "recommended" contains up to the count requested by menuCountHint and uses the same item object fields.
- fullMenu.items contains remaining non-recommended items grouped by category. Never duplicate recommended items there.
- recommendationRank is 1-based for recommended items and null otherwise.
- styleFitScore and confidence are numbers from 0.0 to 1.0.
- topRecommendedItemIndexes uses zero-based indexes into the top-level items array.
- Count foodStyleSummary from the final deduplicated items array.
- Keep warnings as an array of short machine-readable or target-language strings.
- If isMenu=false, still include request metadata, selectedFoodStyle, foodStyleApplied=false, an empty items array, an empty recommended array, an empty fullMenu, foodStyleSummary with zero counts, and a short userMessage/reason.
''';
  }

  String _buildResponseSchemaExample({
    required String resolvedDetailLevel,
    required String styleLabel,
  }) {
    final schema = <String, dynamic>{
      'presetVersion': ScanPromptVersion.current,
      'scanPreset': scanPreset.id,
      'detailLevel': resolvedDetailLevel,
      'targetLanguage': targetLanguage,
      'isMultiScan': isMultiScan,
      'selectedFoodStyle': selectedFoodStyle.id,
      'selectedFoodStyleLabel': styleLabel,
      'foodStyleApplied': true,
      'foodStyleSummary': {
        'styleId': selectedFoodStyle.id,
        'matchedItemCount': 0,
        'cautionItemCount': 0,
        'notRecommendedItemCount': 0,
        'topRecommendedItemIndexes': <int>[],
        'confidence': 0.0,
        'reason': 'string in targetLanguage',
        'disclaimer': 'string in targetLanguage',
      },
      'isMenu': true,
      'userMessage': 'string in targetLanguage',
      'outputLanguage': targetLanguage,
      'place': {
        'name': null,
        'address': null,
        'city': null,
      },
      'imageLevelDetections': [
        {
          'imageIndex': 0,
          'detectedMenuType': 'restaurant_menu|food_photo|not_menu|unknown',
          'detectedCuisineType': 'string or null',
          'confidence': 0.0,
        },
      ],
      'items': [
        {
          'id': 'm1',
          'originalName': 'exact visible menu name',
          'translatedName': 'translation in targetLanguage',
          'description': 'short description in targetLanguage',
          'nameOriginal': 'same as originalName for existing app compatibility',
          'name': 'same as translatedName for existing app compatibility',
          'originLanguageCode': 'ISO language code',
          'nameOriginalReading': 'pronunciation only or empty string',
          'shortDesc': 'same as description for existing app compatibility',
          'price': 'visible original price text or null',
          'currencyCode': 'ISO 4217 code or null',
          'convertedPrice': null,
          'prices': {
            'small': null,
            'medium': null,
            'large': null,
            'single': null,
            'currency': 'ISO 4217 code or null',
          },
          'tags': <String>[],
          'category': 'main|side|meal|drink|beverage|unknown',
          'foodStyleFit': 'recommended|caution|notRecommended|unknown',
          'styleMatched': false,
          'styleFitScore': 0.0,
          'recommendationRank': null,
          'recommendationReason': 'string or null',
          'matchedEvidence': <String>[],
          'cautionReason': 'string or null',
          'ingredientsGuess': null,
          'tasteProfile': null,
          'localContextReason': null,
          'dietaryWarnings': <String>[],
          'allergyHints': <String>[],
          'allergyDisclaimer': null,
          'requiresStaffCheck': false,
          'confidence': 0.0,
          'sourceImageIndexes': [0],
        },
      ],
      'recommended': <dynamic>[],
      'fullMenu': {
        'items': {
          for (final category in fullMenuCategories) category: <dynamic>[],
        },
        'summary': 'very short string',
        'truncated': false,
      },
      'warnings': <String>[],
    };
    return const JsonEncoder.withIndent('  ').convert(schema);
  }

  String _safeRagContext() {
    if (!includeRagContext) return '';
    final value = ragContext?.trim() ?? '';
    if (value.length <= 3000) return value;
    return value.substring(0, 3000);
  }

  String _presetRules(String resolvedDetailLevel) {
    switch (scanPreset) {
      case ScanPromptPreset.defaultFoodScan:
        return '''
- Extract reliable menu names, translations, visible prices, concise descriptions, and foodStyleFit.
- Keep descriptions compact. detailLevel="$resolvedDetailLevel".''';
      case ScanPromptPreset.conciseTranslation:
        return '''
- Prioritize exact extraction and concise translation.
- Keep description, recommendationReason, and cautionReason to one short sentence when present.
- Do not add speculative ingredient or local-context detail.''';
      case ScanPromptPreset.premiumDetailed:
        return '''
- Provide careful detail for ingredientsGuess, allergyHints, tasteProfile, dietaryWarnings, recommendationReason, cautionReason, and localContextReason.
- Uncertain details must be null or explicitly low confidence; never present guesses as facts.''';
      case ScanPromptPreset.multiImageMerge:
        return '''
- Apply premium detail where evidence supports it.
- Merge all supplied image regions into one deduplicated menu result.
- Preserve sourceImageIndexes and imageLevelDetections.''';
    }
  }

  String _multiScanRules() {
    if (!isMultiScan) {
      return '''
- Use sourceImageIndexes=[0] for extracted items.
- Include one imageLevelDetections entry when possible.''';
    }
    return '''
- Inspect all source images/regions before ranking.
- The merged image contains $sourceImageCount source image(s). Grid cells are in zero-based row-major order: top-left is image 0, then move right, then down. Two-image scans use one column.
- Merge obvious duplicates caused by overlap, OCR spacing, punctuation, repeated headers, or repeated prices.
- sourceImageIndexes must list every zero-based image index where the item appears.
- imageLevelDetections must contain one entry per source image when image boundaries are available.
- foodStyleSummary must be calculated from the final merged and deduplicated items.
- If images appear to contain different menu types, record that in warnings.''';
  }
}
