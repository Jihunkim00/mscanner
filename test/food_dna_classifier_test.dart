import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/models/food_journey_summary.dart';
import 'package:mscanner/features/food_journey/services/food_dna_classifier.dart';

void main() {
  const classifier = FoodCategoryClassifier();
  const parser = FoodJourneyMenuParser();
  test('multiple JSON blocks and legacy item names stay one representative',
      () {
    final first = jsonEncode({
      'recommended': [
        {'name': 'Ramen', 'shortDesc': 'A {warm} bowl'}
      ]
    });
    final second = jsonEncode({
      'recommended': [
        {'name': 'Sushi'}
      ]
    });
    expect(
        parser.representative({
          'responses': ['```json\n$first\n```\n```json\n$second\n```']
        })?['name'],
        'Ramen');
    expect(parser.representative({'response': '{invalid}\n$second'})?['name'],
        'Sushi');
    expect(
        parser.representative({
          'response': jsonEncode({
            'items': [
              {'original': 'Steak'}
            ]
          })
        })?['name'],
        'Steak');
  });
  test('multilingual dish dictionary and compound dish priorities', () {
    final cases = {
      '돈코츠 라멘': FoodCategory.noodles,
      '豚骨ラーメン': FoodCategory.noodles,
      'Pad Thai': FoodCategory.noodles,
      'Phở bò': FoodCategory.noodles,
      'Seafood ramen soup': FoodCategory.noodles,
      'Chicken fried rice': FoodCategory.rice,
      'Risotto': FoodCategory.rice,
      'Steak': FoodCategory.meat,
      'Sushi rice': FoodCategory.seafood,
      'Tiramisu': FoodCategory.dessert,
      'Cappuccino': FoodCategory.drinks,
      'شاي': FoodCategory.drinks,
      'बिरयानी': FoodCategory.rice,
      'চা': FoodCategory.drinks,
      'కాఫీ': FoodCategory.drinks,
      'समुद्री अज्ञात': FoodCategory.unknown,
      'Mystery special': FoodCategory.unknown,
    };
    for (final entry in cases.entries) {
      expect(classifier.classify({'nameOriginal': entry.key}), entry.value,
          reason: entry.key);
    }
    expect(
        classifier.classify(
            {'name': 'Steak', 'shortDesc': 'Served with noodles and tea'}),
        FoodCategory.meat);
    expect(
        classifier.classify({
          'name': 'House special',
          'tags': ['noodles', 'spicy']
        }),
        FoodCategory.noodles);
    expect(
        classifier
            .classify({'name': 'Special', 'category': 'beverage', 'rating': 5}),
        FoodCategory.unknown);
    expect(classifier.classify({'name': 'Steakhouse special'}),
        FoodCategory.unknown);
  });

  test(
      'recommended first, primary menu second, legacy explicit first dish third',
      () {
    final json = jsonEncode({
      'recommended': [
        {'nameOriginal': 'Sushi', 'name': '초밥'},
        {'name': 'Steak'}
      ]
    });
    expect(
        parser.representative({
          'responses': ['```json\n$json\n```', json],
          'primary_menu': 'Rice'
        })?['nameOriginal'],
        'Sushi');
    expect(parser.representative({'response': json})?['name'], '초밥');
    expect(
        parser.representative({
          'responses': ['bad json'],
          'primary_menu': 'Risotto'
        })?['name'],
        'Risotto');
    expect(
        parser.representative({
          'responses': [
            jsonEncode({
              'items': [
                {'name': 'Steak'}
              ]
            })
          ],
          'primary_menu': 'Risotto'
        })?['name'],
        'Risotto');
    expect(
        parser.representative({
          'response': 'Recommendations\n1. Pad Thai - spicy\n2. Steak'
        })?['name'],
        'Pad Thai');
    expect(
        parser.representative({
          'responses': ['', '{broken}', 'ordinary text', 7, null]
        }),
        isNull);
    expect(parser.representative({'responses': [], 'response': json})?['name'],
        '초밥');
    expect(
        parser.representative({
          'responses': [
            jsonEncode({
              'isMenu': false,
              'recommended': [
                {'name': 'Steak'}
              ]
            })
          ]
        }),
        isNull);
  });
}
