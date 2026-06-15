import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';

void main() {
  test('parses multi scan JSON with photo analyses and merged result', () {
    final response = jsonEncode({
      'isMenu': true,
      'scanMode': 'multi',
      'outputLanguage': 'en',
      'recommended': [],
      'fullMenu': {
        'items': {
          'main': [],
          'side': [],
          'meal': [],
          'drink': [],
          'beverage': [],
          'unknown': []
        },
        'summary': '',
        'truncated': false,
      },
      'photoAnalyses': [
        {
          'photoIndex': 1,
          'detectedSections': ['main'],
          'itemCount': 8,
          'readableItemCount': 8,
          'unclearItemCount': 0,
          'items': [],
        },
        {
          'photoIndex': 2,
          'detectedSections': ['drinks'],
          'itemCount': 5,
          'readableItemCount': 3,
          'unclearItemCount': 2,
          'items': [],
        },
      ],
      'mergedResult': {
        'totalPhotoCount': 2,
        'totalItemCount': 13,
        'uniqueItemCount': 12,
        'duplicateItemCount': 1,
        'recommendedItems': [],
        'signatureItems': [],
        'popularItems': [],
        'localInsights': [],
      },
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [response],
      imageCount: 2,
    );

    expect(parsed.aiJson?['scanMode'], 'multi');
    expect(ResultParsingService.getPhotoAnalyses(parsed.aiJson), hasLength(2));
    final merged = ResultParsingService.getMergedResult(
      parsed.aiJson,
      fallbackPhotoCount: 2,
    );
    expect(merged['totalItemCount'], 13);
    expect(merged['uniqueItemCount'], 12);
    expect(merged['duplicateItemCount'], 1);
  });

  test('legacy multi response without photoAnalyses does not crash', () {
    final response = jsonEncode({
      'isMenu': true,
      'outputLanguage': 'en',
      'recommended': [
        {'id': 'm1', 'nameOriginal': 'Taco', 'name': 'Taco'}
      ],
      'fullMenu': {
        'items': {
          'main': [
            {'id': 'm2', 'nameOriginal': 'Burrito', 'name': 'Burrito'}
          ],
          'side': [],
          'meal': [],
          'drink': [],
          'beverage': [],
          'unknown': []
        },
        'summary': '',
        'truncated': false,
      },
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [response],
      imageCount: 3,
    );

    expect(parsed.aiJson?['scanMode'], 'multi');
    expect(ResultParsingService.getPhotoAnalyses(parsed.aiJson), isEmpty);
    final merged = ResultParsingService.getMergedResult(
      parsed.aiJson,
      fallbackPhotoCount: 3,
    );
    expect(merged['totalPhotoCount'], 3);
    expect(merged['uniqueItemCount'], 2);
  });

  test('uses mergedResult recommendedItems when top-level recommended is empty', () {
    final response = jsonEncode({
      'isMenu': true,
      'scanMode': 'multi',
      'outputLanguage': 'ko',
      'recommended': [],
      'photoAnalyses': [],
      'mergedResult': {
        'totalPhotoCount': 2,
        'recommendedItems': [
          {
            'originalName': '豚骨ラーメン',
            'translatedName': '돈코츠 라멘',
            'description': '돼지뼈 육수 기반 라멘',
            'price': '980円',
            'reason': '대표 메뉴',
          }
        ],
      },
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [response],
      imageCount: 2,
    );

    final recommended = ResultParsingService.getRecommendedItems(parsed.aiJson);
    expect(recommended, isNotEmpty);
    expect(recommended.first['nameOriginal'], '豚骨ラーメン');
    expect(recommended.first['name'], '돈코츠 라멘');
    expect(recommended.first['shortDesc'], '돼지뼈 육수 기반 라멘');
  });

  test('photo analysis itemCount falls back to items length', () {
    final response = jsonEncode({
      'isMenu': true,
      'scanMode': 'multi',
      'photoAnalyses': [
        {
          'photoIndex': 1,
          'itemCount': 0,
          'readableItemCount': 0,
          'unclearItemCount': 0,
          'items': [
            {'originalName': 'Ramen', 'translatedName': '라멘'},
            {'originalName': 'Gyoza', 'translatedName': '교자'},
          ],
        }
      ],
      'mergedResult': {'totalPhotoCount': 1},
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [response],
      imageCount: 1,
    );

    final analyses = ResultParsingService.getPhotoAnalyses(parsed.aiJson);
    expect(analyses, hasLength(1));
    expect(analyses.first['itemCount'], 2);
    expect(analyses.first['readableItemCount'], 2);
  });

  test('readableItemCount falls back to itemCount minus unclearItemCount', () {
    final response = jsonEncode({
      'isMenu': true,
      'scanMode': 'multi',
      'photoAnalyses': [
        {
          'photoIndex': 1,
          'itemCount': 3,
          'unclearItemCount': 1,
          'items': [
            {'originalName': 'A'},
            {'originalName': 'B'},
            {'originalName': 'C'},
          ],
        }
      ],
      'mergedResult': {'totalPhotoCount': 1},
    });

    final parsed = ResultParsingService.parseAiJson(
      responses: [response],
      imageCount: 1,
    );

    final analyses = ResultParsingService.getPhotoAnalyses(parsed.aiJson);
    expect(analyses.first['itemCount'], 3);
    expect(analyses.first['unclearItemCount'], 1);
    expect(analyses.first['readableItemCount'], 2);
  });

}
