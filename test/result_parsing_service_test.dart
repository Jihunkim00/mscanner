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
}
