import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';

void main() {
  group('ResultParsingService decision summary policy', () {
    test('shows for a normal menu with a named recommended item', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'resultType': 'menu',
            'recommended': [
              {
                'nameOriginal': 'Bibimbap',
                'name': 'Bibimbap',
              },
            ],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isTrue);
    });

    test('hides for a general non-menu photo', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'resultType': 'not_menu',
            'recommended': [],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('hides for unclear images', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'resultType': 'unclear',
            'recommended': [],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('shows when resultType is missing but recommended has a menu name',
        () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'recommended': [
              {'nameOriginal': 'Kimchi jjigae'},
            ],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isTrue);
    });

    test('hides for empty recommended objects', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'resultType': 'menu',
            'recommended': [
              {'name': '', 'nameOriginal': ''},
            ],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('prefers explicit non-menu resultType over fallback recommendations',
        () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'resultType': 'not-menu',
            'recommended': [
              {'name': 'AI answer'},
            ],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.aiResultType(parsed.aiJson), 'not_menu');
      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('hides non-menu results regardless of localized userMessage text', () {
      final english = {
        'resultType': 'not_menu',
        'userMessage': 'This does not look like a food menu.',
      };
      final japanese = {
        'resultType': 'not_menu',
        'userMessage': 'これは飲食店のメニューではないようです。',
      };

      expect(ResultParsingService.shouldShowDecisionSummary(english), isFalse);
      expect(ResultParsingService.shouldShowDecisionSummary(japanese), isFalse);
    });

    test('does not treat fullMenu fallback items as decision recommendations',
        () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'resultType': 'menu',
            'fullMenu': {
              'items': {
                'main': [
                  {
                    'nameOriginal': 'Tonkatsu',
                    'name': 'Pork cutlet',
                  },
                ],
              },
            },
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.getRecommendedItems(parsed.aiJson),
          hasLength(1));
      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('maps structured V2 items to the existing recommendation UI shape',
        () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'items': [
              {
                'id': 'm1',
                'nameOriginal': 'Bibimbap',
                'name': 'Bibimbap',
                'shortDesc': 'Rice with vegetables.',
                'prices': {'single': 12, 'currency': 'USD'},
                'tags': ['rice'],
              },
            ],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.getRecommendedItems(parsed.aiJson),
          hasLength(1));
      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isTrue);
    });

    test('infers non-menu result type from structured V2 isMenu=false', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': false,
            'userMessage': 'This is not a menu.',
            'outputLanguage': 'en',
            'items': [],
          }),
        ],
        imageCount: 1,
      );

      expect(ResultParsingService.aiResultType(parsed.aiJson), 'not_menu');
      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('does not promote multi-scan recommendations into full menu', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'items': [
              {
                'id': 'm1',
                'nameOriginal': 'Bibimbap',
                'name': 'Bibimbap',
                'category': 'main',
              },
              {
                'id': 's1',
                'nameOriginal': 'Kimchi',
                'name': 'Kimchi',
                'category': 'side',
              },
            ],
          }),
        ],
        imageCount: 4,
      );

      final fullMenu =
          Map<String, dynamic>.from(parsed.aiJson!['fullMenu'] as Map);
      final items = Map<String, dynamic>.from(fullMenu['items'] as Map);

      expect((items['main'] as List), isEmpty);
      expect((items['side'] as List), isEmpty);
      expect(fullMenu['summary'], isEmpty);
      expect(ResultParsingService.getRecommendedItems(parsed.aiJson),
          hasLength(2));
      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isTrue);
    });

    test('treats summary-only full menu as unusable', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [],
            'fullMenu': {
              'summary': 'A menu summary without item records.',
              'truncated': true,
            },
          }),
        ],
        imageCount: 4,
      );

      expect(
        ResultParsingService.hasUsableFullMenu(parsed.aiJson),
        isFalse,
      );
    });

    test('treats a full menu with item records as usable', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [],
            'fullMenu': {
              'items': {
                'main': [
                  {
                    'nameOriginal': 'Bibimbap',
                    'name': 'Bibimbap',
                  },
                ],
              },
              'summary': '',
              'truncated': false,
            },
          }),
        ],
        imageCount: 4,
      );

      expect(
        ResultParsingService.hasUsableFullMenu(parsed.aiJson),
        isTrue,
      );
    });

    test('preserves multi-scan recommendation source indexes', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [
              {
                'nameOriginal': 'Dish 1',
                'name': 'Dish 1',
                'sourceImageIndexes': [1],
              },
              {
                'nameOriginal': 'Dish 2',
                'name': 'Dish 2',
                'sourceImageIndexes': [2],
              },
              {
                'nameOriginal': 'Dish 3',
                'name': 'Dish 3',
                'sourceImageIndexes': [3],
              },
              {
                'nameOriginal': 'Dish 4',
                'name': 'Dish 4',
                'sourceImageIndexes': [4],
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
          }),
        ],
        imageCount: 4,
      );

      final items = ResultParsingService.getRecommendedItems(parsed.aiJson);
      final coverage = items
          .expand((item) => (item['sourceImageIndexes'] as List).cast<int>())
          .toSet();

      expect(items, hasLength(4));
      expect(coverage, {1, 2, 3, 4});
    });

    test('merges source indexes when duplicate recommendations are deduped',
        () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [
              {
                'nameOriginal': 'Same dish',
                'name': 'Same dish',
                'sourceImageIndexes': [1],
              },
            ],
            'fullMenu': {
              'items': {
                'main': [],
              },
            },
          }),
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [
              {
                'nameOriginal': 'Same dish',
                'name': 'Same dish',
                'sourceImageIndexes': [2],
              },
            ],
            'fullMenu': {
              'items': {
                'main': [],
              },
            },
          }),
        ],
        imageCount: 2,
      );

      final item =
          ResultParsingService.getRecommendedItems(parsed.aiJson).single;
      expect(item['sourceImageIndexes'], [1, 2]);
    });

    test('does not force recommendations for a non-menu multi scan', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': false,
            'userMessage': 'No readable food menu.',
            'outputLanguage': 'en',
            'recommended': [],
            'fullMenu': null,
          }),
        ],
        imageCount: 4,
      );

      expect(ResultParsingService.getRecommendedItems(parsed.aiJson), isEmpty);
      expect(ResultParsingService.shouldShowDecisionSummary(parsed.aiJson),
          isFalse);
    });

    test('keeps an existing multi-scan full menu separate from recommendations',
        () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'items': [
              {
                'id': 'r1',
                'nameOriginal': 'Recommended dish',
                'name': 'Recommended dish',
                'category': 'main',
              },
            ],
            'fullMenu': {
              'items': {
                'main': [
                  {
                    'id': 'f1',
                    'nameOriginal': 'Full menu dish',
                    'name': 'Full menu dish',
                    'category': 'main',
                  },
                ],
              },
              'summary': 'Complete menu',
            },
          }),
        ],
        imageCount: 4,
      );

      final fullMenu =
          Map<String, dynamic>.from(parsed.aiJson!['fullMenu'] as Map);
      final items = Map<String, dynamic>.from(fullMenu['items'] as Map);
      final mainItems = items['main'] as List;

      expect(mainItems, hasLength(1));
      expect((mainItems.single as Map)['nameOriginal'], 'Full menu dish');
      expect(fullMenu['summary'], 'Complete menu');
      expect(ResultParsingService.getRecommendedItems(parsed.aiJson),
          hasLength(1));
      expect(
        (ResultParsingService.getRecommendedItems(parsed.aiJson)
            .single)['nameOriginal'],
        'Recommended dish',
      );
    });

    test('deduplicates full-menu items across categories and pages', () {
      final item = {
        'id': 'm1',
        'nameOriginal': 'Bibimbap',
        'name': 'Bibimbap',
        'category': 'main',
      };
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [],
            'fullMenu': {
              'items': {
                'main': [item],
                'side': [],
              },
              'summary': '',
              'truncated': false,
            },
          }),
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [],
            'fullMenu': {
              'items': {
                'main': [item],
                'side': [
                  Map<String, dynamic>.from(item)..['category'] = 'side'
                ],
              },
              'summary': '',
              'truncated': false,
            },
          }),
        ],
        imageCount: 4,
      );

      final fullMenu =
          Map<String, dynamic>.from(parsed.aiJson!['fullMenu'] as Map);
      final categories = Map<String, dynamic>.from(fullMenu['items'] as Map);
      final itemCount = categories.values
          .whereType<List>()
          .fold<int>(0, (sum, items) => sum + items.length);

      expect(itemCount, 1);
    });

    test('keeps server-aggregated full menu separate from recommendations', () {
      final parsed = ResultParsingService.parseAiJson(
        responses: [
          jsonEncode({
            'isMenu': true,
            'userMessage': '',
            'outputLanguage': 'en',
            'recommended': [
              {
                'nameOriginal': 'Recommended dish',
                'name': 'Recommended dish',
                'sourceImageIndexes': [1],
              },
            ],
            'fullMenu': {
              'items': {
                'main': [
                  {
                    'nameOriginal': 'Other dish',
                    'name': 'Other dish',
                    'sourceImageIndexes': [1],
                  },
                ],
              },
              'summary': '',
              'truncated': false,
            },
          }),
        ],
        imageCount: 4,
      );

      final fullMenu =
          Map<String, dynamic>.from(parsed.aiJson!['fullMenu'] as Map);
      final categories = Map<String, dynamic>.from(fullMenu['items'] as Map);
      final mainItems = categories['main'] as List;
      expect(mainItems, hasLength(1));
      expect((mainItems.single as Map)['nameOriginal'], 'Other dish');
      expect(
        ResultParsingService.getRecommendedItems(parsed.aiJson)
            .single['nameOriginal'],
        'Recommended dish',
      );
      expect(ResultParsingService.hasUsableFullMenu(parsed.aiJson), isTrue);
    });
  });
}
