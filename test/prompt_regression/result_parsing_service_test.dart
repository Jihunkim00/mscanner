import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/core/prompt/scan_prompt_builder.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';

void main() {
  test('parses extended foodStyle response fields', () {
    final response = jsonEncode({
      'presetVersion': 'v1',
      'scanPreset': 'premiumDetailed',
      'detailLevel': 'premium',
      'targetLanguage': 'ko',
      'selectedFoodStyle': 'muslimFriendly',
      'foodStyleApplied': true,
      'foodStyleSummary': {
        'styleId': 'muslimFriendly',
        'matchedItemCount': 1,
        'cautionItemCount': 0,
        'notRecommendedItemCount': 0,
        'topRecommendedItemIndexes': [0],
        'confidence': 0.8,
        'reason': 'reason',
        'disclaimer': 'staff check',
      },
      'items': [
        {
          'originalName': '海鮮丼',
          'translatedName': '해산물 덮밥',
          'description': '설명',
          'foodStyleFit': 'recommended',
          'styleMatched': true,
          'styleFitScore': 0.82,
          'recommendationRank': 1,
          'cautionReason': '매장 확인 필요',
          'dietaryWarnings': ['halal_not_certified'],
          'sourceImageIndexes': [0],
        },
      ],
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [response],
      imageCount: 1,
    ).aiJson!;
    final item = (parsed['items'] as List).first as Map;

    expect(parsed['foodStyleSummary'], isA<Map>());
    expect(item['foodStyleFit'], 'recommended');
    expect(item['styleMatched'], isTrue);
    expect(item['styleFitScore'], 0.82);
    expect(item['cautionReason'], '매장 확인 필요');
    expect(item['dietaryWarnings'], ['halal_not_certified']);
    expect(item['nameOriginal'], '海鮮丼');
    expect(item['name'], '해산물 덮밥');
    expect(parsed['recommended'], isEmpty);
    expect(ResultParsingService.getDisplayItems(parsed), hasLength(1));
  });

  test('display items prefer recommended over top-level items', () {
    final parsed = ResultParsingService.parseAiJson(
      responses: [
        jsonEncode({
          'recommended': [
            {
              'nameOriginal': 'Recommended',
              'name': '추천',
            },
          ],
          'items': [
            {
              'originalName': 'Fallback',
              'translatedName': '대체',
            },
          ],
        }),
      ],
      imageCount: 1,
    ).aiJson!;

    final displayItems = ResultParsingService.getDisplayItems(parsed);
    expect(displayItems, hasLength(1));
    expect(displayItems.single['nameOriginal'], 'Recommended');
  });

  test('display items fall back to top-level items when recommended is empty',
      () {
    final parsed = ResultParsingService.parseAiJson(
      responses: [
        jsonEncode({
          'recommended': [],
          'items': [
            {
              'originalName': '海鮮丼',
              'translatedName': '해산물 덮밥',
            },
          ],
        }),
      ],
      imageCount: 1,
    ).aiJson!;

    expect(ResultParsingService.getRecommendedItems(parsed), isEmpty);
    final displayItems = ResultParsingService.getDisplayItems(parsed);
    expect(displayItems, hasLength(1));
    expect(displayItems.single['nameOriginal'], '海鮮丼');
  });

  test('final stream payload normalizes items, recommended, and fullMenu', () {
    final fullText = jsonEncode({
      'selectedFoodStyle': 'muslimFriendly',
      'recommended': [],
      'items': [
        {
          'originalName': 'Grilled Fish',
          'translatedName': '구운 생선',
        },
      ],
      'fullMenu': {
        'items': {
          'main': [
            {
              'originalName': 'Grilled Fish',
              'translatedName': '구운 생선',
            },
          ],
        },
      },
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [fullText],
      imageCount: 2,
    ).aiJson!;

    expect(ResultParsingService.getItems(parsed), hasLength(1));
    expect(ResultParsingService.getRecommendedItems(parsed), isEmpty);
    expect(ResultParsingService.getDisplayItems(parsed), hasLength(1));
    expect(ResultParsingService.fullMenuItemCount(parsed), 1);

    final fullMenu = Map<String, dynamic>.from(parsed['fullMenu'] as Map);
    final categories = Map<String, dynamic>.from(fullMenu['items'] as Map);
    expect(categories['main'], hasLength(1));
    expect(categories.keys.toList(), ScanPromptBuilder.fullMenuCategories);
  });

  test('missing fullMenu and main category normalize to canonical empty lists',
      () {
    final parsedWithoutFullMenu = ResultParsingService.parseAiJson(
      responses: [
        jsonEncode({
          'items': [
            {
              'originalName': 'Salad',
              'translatedName': '샐러드',
              'category': 'side',
            },
          ],
        }),
      ],
      imageCount: 1,
    ).aiJson!;

    final fullMenu =
        Map<String, dynamic>.from(parsedWithoutFullMenu['fullMenu'] as Map);
    final categories = Map<String, dynamic>.from(fullMenu['items'] as Map);
    expect(
      categories.keys.toList(),
      ScanPromptBuilder.fullMenuCategories,
    );
    expect(categories['main'], isEmpty);

    final parsedWithoutMain = ResultParsingService.parseAiJson(
      responses: [
        jsonEncode({
          'fullMenu': {
            'items': {
              'side': [
                {
                  'nameOriginal': 'Side dish',
                  'name': '사이드',
                },
              ],
            },
          },
        }),
      ],
      imageCount: 1,
    ).aiJson!;
    final normalizedCategories = Map<String, dynamic>.from(
      (parsedWithoutMain['fullMenu'] as Map)['items'] as Map,
    );
    expect(normalizedCategories['main'], isEmpty);
    expect(normalizedCategories['side'], hasLength(1));
  });

  test('keeps legacy recommended/fullMenu JSON compatible', () {
    final legacy = jsonEncode({
      'isMenu': true,
      'outputLanguage': 'en',
      'recommended': [
        {
          'id': 'm1',
          'nameOriginal': 'Ramen',
          'name': 'Ramen',
          'shortDesc': 'Noodle soup',
          'prices': {'single': 900, 'currency': 'JPY'},
        },
      ],
      'fullMenu': {
        'items': {
          'main': [],
          'side': [],
          'meal': [],
          'drink': [],
          'beverage': [],
          'unknown': [],
        },
        'summary': '',
        'truncated': false,
      },
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [legacy],
      imageCount: 1,
    ).aiJson!;
    final item = (parsed['items'] as List).first as Map;

    expect(parsed['isMenu'], isTrue);
    expect(parsed['recommended'], hasLength(1));
    expect(item['originalName'], 'Ramen');
    expect(item['translatedName'], 'Ramen');
    expect(item['foodStyleFit'], 'unknown');
    expect(item['sourceImageIndexes'], [0]);
  });

  test('merges multi scan duplicates and source image indexes', () {
    String response(int imageIndex, String menuType) => jsonEncode({
          'selectedFoodStyle': 'seafood',
          'imageLevelDetections': [
            {
              'imageIndex': imageIndex,
              'detectedMenuType': menuType,
              'confidence': 0.9,
            },
          ],
          'items': [
            {
              'originalName': 'Grilled Fish',
              'translatedName': '구운 생선',
              'foodStyleFit': 'recommended',
              'styleMatched': true,
              'styleFitScore': 0.9,
              'recommendationRank': 1,
              'sourceImageIndexes': [imageIndex],
            },
          ],
          'warnings': [],
        });

    final parsed = ResultParsingService.parseAiJson(
      responses: [
        response(0, 'restaurant_menu'),
        response(1, 'restaurant_menu'),
      ],
      imageCount: 2,
    ).aiJson!;
    final items = parsed['items'] as List;
    final item = items.first as Map;

    expect(items, hasLength(1));
    expect(item['sourceImageIndexes'], [0, 1]);
    expect(parsed['imageLevelDetections'], hasLength(2));
    expect(
      (parsed['foodStyleSummary'] as Map)['matchedItemCount'],
      1,
    );
  });

  test('typed parser exposes extended response model', () {
    final response = jsonEncode({
      'selectedFoodStyle': 'lowSalt',
      'items': [
        {
          'originalName': 'Salad',
          'translatedName': '샐러드',
          'foodStyleFit': 'caution',
          'styleFitScore': 0.5,
          'dietaryWarnings': ['sauce_may_be_salty'],
        },
      ],
    });

    final typed = ResultParsingService.parseVisionResponse(
      responses: [response],
      imageCount: 1,
    )!;

    expect(typed.selectedFoodStyle, 'lowSalt');
    expect(typed.items.single.originalName, 'Salad');
    expect(typed.items.single.dietaryWarnings, ['sauce_may_be_salty']);
  });
}
