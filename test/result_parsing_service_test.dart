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
  });
}
