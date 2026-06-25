import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/core/prompt/food_style_prompt_rules.dart';
import 'package:mscanner/core/prompt/scan_prompt_builder.dart';
import 'package:mscanner/core/prompt/scan_prompt_preset.dart';
import 'package:mscanner/helpers/settings_helper.dart';

void main() {
  String build({
    ScanPromptPreset preset = ScanPromptPreset.defaultFoodScan,
    FoodStyle style = FoodStyle.aiRecommend,
    bool multi = false,
  }) {
    return ScanPromptBuilder(
      scanPreset: preset,
      targetLanguage: 'ko',
      isMultiScan: multi,
      includeCurrency: true,
      includeRagContext: false,
      selectedFoodStyle: style,
      isPremiumUser: preset.isPremium,
      scanMode: multi ? 'multi' : 'single',
    ).build();
  }

  test('all scan presets generate versioned strict JSON prompts', () {
    for (final preset in ScanPromptPreset.values) {
      final prompt = build(preset: preset);
      expect(prompt, contains('scanPreset: "${preset.id}"'));
      expect(prompt, contains('presetVersion: "v1"'));
      expect(prompt, contains('Return strict JSON only'));
      expect(prompt, contains('No markdown'));
    }
  });

  test('target language and stable foodStyle id are included', () {
    final prompt = build(style: FoodStyle.lowFat);
    expect(prompt, contains('targetLanguage: "ko"'));
    expect(prompt, contains('selectedFoodStyle: "lowFat"'));
  });

  test('every foodStyle contributes its concrete rule', () {
    final requiredRuleFragments = <FoodStyle, String>{
      FoodStyle.aiRecommend: 'recommendationRank',
      FoodStyle.lowFat: 'deep-fried',
      FoodStyle.lowSalt: 'actual sodium content',
      FoodStyle.nutFree: 'Never guarantee allergy safety',
      FoodStyle.seafood: 'seafood broth',
      FoodStyle.meat: 'meat-broth',
      FoodStyle.muslimFriendly: 'Never claim or imply halal certification',
    };

    for (final entry in requiredRuleFragments.entries) {
      expect(build(style: entry.key), contains(entry.value));
    }
  });

  test('every foodStyle uses the same nested fullMenu schema', () {
    const expectedCategoryKeys = ScanPromptBuilder.fullMenuCategories;

    for (final style in FoodStyle.values) {
      final prompt = build(
        preset: ScanPromptPreset.premiumDetailed,
        style: style,
        multi: true,
      );
      final schema = _extractSchemaExample(prompt);
      final fullMenu = schema['fullMenu'];

      expect(
        fullMenu,
        isA<Map<String, dynamic>>(),
        reason: '${style.id} must include a fullMenu object.',
      );
      final fullMenuMap = fullMenu as Map<String, dynamic>;
      expect(
        fullMenuMap.keys.toSet(),
        {'items', 'summary', 'truncated'},
        reason: '${style.id} must not flatten menu categories into fullMenu.',
      );
      expect(
        fullMenuMap['items'],
        isA<Map<String, dynamic>>(),
        reason: '${style.id} must nest categories under fullMenu.items.',
      );
      expect(
        (fullMenuMap['items'] as Map<String, dynamic>).keys.toList(),
        expectedCategoryKeys,
        reason: '${style.id} must use the canonical menu categories.',
      );
      expect(
        (fullMenuMap['items'] as Map<String, dynamic>).containsKey('main'),
        isTrue,
        reason: '${style.id} must include fullMenu.items.main.',
      );
      for (final category in expectedCategoryKeys) {
        expect(
          (fullMenuMap['items'] as Map<String, dynamic>)[category],
          isEmpty,
          reason: '${style.id} must initialize $category as an empty array.',
        );
      }
      expect(fullMenuMap['summary'], 'very short string');
      expect(fullMenuMap['truncated'], isFalse);
    }
  });

  test('hallucination prevention rules are present', () {
    final prompt = build();
    expect(
      prompt,
      contains('Never invent menu items to satisfy the selected foodStyle'),
    );
    expect(prompt, contains('must not remove real menu items'));
    expect(prompt, contains('If price is not visible, return null'));
  });

  test('nutFree requires staff check and rejects safety guarantees', () {
    final prompt = build(style: FoodStyle.nutFree);
    expect(prompt, contains('Never guarantee allergy safety'));
    expect(prompt, contains('restaurant staff confirmation is required'));
  });

  test('muslimFriendly rejects certification and flags pork/alcohol', () {
    final prompt = build(style: FoodStyle.muslimFriendly);
    expect(prompt, contains('Never claim or imply halal certification'));
    expect(prompt, contains('pork'));
    expect(prompt, contains('alcohol'));
    expect(prompt, contains('requiresStaffCheck=true'));
  });

  test('multi scan requires detections, source indexes, and deduplication', () {
    final prompt = ScanPromptBuilder(
      scanPreset: ScanPromptPreset.multiImageMerge,
      targetLanguage: 'ko',
      isMultiScan: true,
      includeCurrency: true,
      includeRagContext: false,
      selectedFoodStyle: FoodStyle.aiRecommend,
      isPremiumUser: true,
      scanMode: 'multi',
      sourceImageCount: 3,
    ).build();
    expect(prompt, contains('imageLevelDetections'));
    expect(prompt, contains('sourceImageIndexes'));
    expect(prompt, contains('Merge obvious duplicates'));
    expect(prompt, contains('sourceImageCount: 3'));
    expect(prompt, contains('row-major order'));
  });

  test('legacy localized labels migrate to stable ids', () {
    expect(
      SettingsHelper.resolveFoodStyle('Wenig Fett'),
      FoodStyle.lowFat,
    );
    expect(
      SettingsHelper.resolveFoodStyle('低盐'),
      FoodStyle.lowSalt,
    );
  });
}

Map<String, dynamic> _extractSchemaExample(String prompt) {
  const marker =
      'Return one JSON object using this backward-compatible schema:';
  const endMarker = '\n\nSchema rules:';
  final markerIndex = prompt.indexOf(marker);
  expect(markerIndex, isNonNegative);

  final jsonStart = prompt.indexOf('{', markerIndex + marker.length);
  final jsonEnd = prompt.indexOf(endMarker, jsonStart);
  expect(jsonStart, isNonNegative);
  expect(jsonEnd, greaterThan(jsonStart));

  return Map<String, dynamic>.from(
    jsonDecode(prompt.substring(jsonStart, jsonEnd)) as Map,
  );
}
