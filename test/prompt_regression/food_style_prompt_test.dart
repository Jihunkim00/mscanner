import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/helpers/settings_helper.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';

String _promptFor(
  String styleId, {
  String label = 'Test label',
  String menuCount = '1-5',
}) {
  return SettingsHelper.buildPresetDescription(
    selectedLanguageCode: 'en',
    selectedFoodStyle: styleId,
    selectedFoodStyleLabel: label,
    selectedMenuNumber: menuCount,
  );
}

void main() {
  group('food style prompt regression', () {
    const styles = {
      SettingsHelper.foodStyleAiRecommend: 'AI recommend',
      SettingsHelper.foodStyleLowFat: 'Low Fat',
      SettingsHelper.foodStyleLowSalt: 'Low salt',
      SettingsHelper.foodStyleNutFree: 'Nut-free',
      SettingsHelper.foodStyleSeafood: 'Seafood',
      SettingsHelper.foodStyleMeat: 'Meat',
      SettingsHelper.foodStyleMuslimFriendly: 'Muslim friendly',
    };

    for (final entry in styles.entries) {
      test('${entry.key} includes id, label, and foodStyle schema', () {
        final prompt = _promptFor(entry.key, label: entry.value);

        expect(prompt, contains('selectedFoodStyle id: "${entry.key}"'));
        expect(prompt, contains('selectedFoodStyle label: "${entry.value}"'));
        expect(prompt, contains('"selectedFoodStyle": "${entry.key}"'));
        expect(prompt, contains('"selectedFoodStyleLabel": "${entry.value}"'));
        expect(prompt, contains('"foodStyleSummary"'));
        expect(prompt, contains('"foodStyleFit"'));
        expect(prompt, contains('"styleFitScore"'));
        expect(prompt, contains('"recommendationRank"'));
        expect(prompt, contains('"recommendationReason"'));
        expect(prompt, contains('"matchedEvidence"'));
        expect(prompt, contains('"cautionReason"'));
        expect(prompt, contains('"dietaryWarnings"'));
        expect(prompt, contains('"allergyHints"'));
        expect(prompt, contains('"requiresStaffCheck"'));
        expect(prompt, contains('"sourceImageIndexes"'));
      });
    }

    test('legacy food style label normalizes to stable id', () {
      final prompt = _promptFor('Low salt', label: 'Low salt');

      expect(prompt, contains('selectedFoodStyle id: "lowSalt"'));
      expect(prompt, contains('"selectedFoodStyle": "lowSalt"'));
      expect(prompt, contains('"selectedFoodStyleLabel": "Low salt"'));
    });

    test('legacy Korean food style label normalizes to stable id', () {
      final prompt = _promptFor('저지방', label: '저지방');

      expect(prompt, contains('selectedFoodStyle id: "lowFat"'));
      expect(prompt, contains('"selectedFoodStyle": "lowFat"'));
      expect(prompt, contains('"selectedFoodStyleLabel": "저지방"'));
    });

    test('nutFree prompt contains safety and staff-check language', () {
      final prompt = _promptFor(
        SettingsHelper.foodStyleNutFree,
        label: 'Nut-free',
      ).toLowerCase();

      expect(prompt, contains('staff check'));
      expect(prompt, contains('no guarantee'));
      expect(prompt, contains('cross-contamination'));
      expect(prompt, contains('requiresstaffcheck=true'));
    });

    test('muslimFriendly prompt avoids halal certification claims', () {
      final prompt = _promptFor(
        SettingsHelper.foodStyleMuslimFriendly,
        label: 'Muslim friendly',
      ).toLowerCase();

      expect(prompt, contains('staff check'));
      expect(prompt, contains('no guarantee'));
      expect(prompt, contains('never claim halal certification'));
      expect(prompt, contains('no halal certification claim'));
      expect(prompt, contains('requiresstaffcheck=true'));
    });

    test('compact recommendation modes do not require fullMenu', () {
      final prompt = _promptFor(
        SettingsHelper.foodStyleAiRecommend,
        label: 'AI recommend',
        menuCount: '1-5',
      );

      expect(prompt, contains('menuCountHint="1-5"'));
      expect(prompt, contains('Compact fullMenu rule'));
      expect(prompt, contains('Omit fullMenu'));
      expect(prompt, isNot(contains('fullMenu is REQUIRED')));
      expect(
        prompt,
        isNot(contains('fullMenu.items.main/side/meal/drink/beverage/unknown')),
      );
    });

    test('all mode includes fullMenu schema', () {
      final prompt = _promptFor(
        SettingsHelper.foodStyleAiRecommend,
        label: 'AI recommend',
        menuCount: 'all',
      );

      expect(prompt, contains('menuCountHint="all"'));
      expect(prompt, contains('fullMenu is REQUIRED'));
      expect(prompt, contains('"main": []'));
      expect(
        prompt,
        contains('fullMenu.items.main/side/meal/drink/beverage/unknown'),
      );
    });
  });

  group('result parser backward compatibility', () {
    test('uses items as fallback when recommended is empty', () {
      final raw = jsonEncode({
        'isMenu': true,
        'outputLanguage': 'en',
        'recommended': [],
        'items': [
          {
            'id': 'm1',
            'nameOriginal': 'Bibimbap',
            'name': 'Bibimbap',
          },
        ],
      });

      final parsed = ResultParsingService.parseAiJson(
        responses: [raw],
        imageCount: 1,
      );
      final items = ResultParsingService.getRecommendedItems(parsed.aiJson);

      expect(items, hasLength(1));
      expect(items.first['nameOriginal'], 'Bibimbap');
    });

    test('uses fullMenu categories as fallback when recommended is missing',
        () {
      final raw = jsonEncode({
        'isMenu': true,
        'outputLanguage': 'en',
        'fullMenu': {
          'items': {
            'main': [
              {
                'id': 'm1',
                'nameOriginal': 'Tonkatsu',
                'name': 'Pork cutlet',
              },
            ],
          },
        },
      });

      final parsed = ResultParsingService.parseAiJson(
        responses: [raw],
        imageCount: 1,
      );
      final items = ResultParsingService.getRecommendedItems(parsed.aiJson);

      expect(items, hasLength(1));
      expect(items.first['name'], 'Pork cutlet');
    });
  });
}
