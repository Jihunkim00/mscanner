import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/models/food_journey_summary.dart';
import 'package:mscanner/features/food_journey/services/country_names.dart';
import 'package:mscanner/features/food_journey/services/food_passport_service.dart';

void main() {
  const service = FoodPassportService();
  test('normalizes multilingual country names, aliases and ISO codes', () {
    for (final name in [
      'Japan',
      ' 일본 ',
      '日本',
      'Japon',
      'ญี่ปุ่น',
      'اليابان',
      'जापान',
      'jp'
    ]) {
      expect(service.normalizeCountry(name), 'JP', reason: name);
    }
    for (final name in ['Korea', '대한민국', 'South Korea', '한국', '韓国', 'KR']) {
      expect(service.normalizeCountry(name), 'KR', reason: name);
    }
    expect(service.normalizeCountry('태국'), 'TH');
    expect(service.normalizeCountry('Viet Nam'), 'VN');
    for (final value in [
      '',
      'Unknown Country',
      'Unknown',
      'XX',
      'Europe',
      null,
      12
    ]) {
      expect(service.normalizeCountry(value), isNull);
    }
    expect(foodJourneyCountryNames, hasLength(249));
    for (final names in foodJourneyCountryNames.values) {
      expect(names, hasLength(foodJourneyCountryLocales.length));
    }
  });

  test('only saved country descriptions are evidence, never GPS/geohash/locale',
      () {
    expect(
        service.countryFor({
          'gps': const GeoPoint(35.68, 139.69),
          'geohash': 'xn76',
          'locale': 'ja',
          'city': 'Tokyo'
        }),
        isNull);
    expect(
        service.countryFor(
            {'country': 'Unknown Country', 'other': 'Tokyo, Japan'}),
        'JP');
    expect(service.countryFor({'country': '', 'city': 'CA', 'other': 'IN'}),
        isNull);
    expect(
        service
            .countryFor({'country': '', 'city': 'Japan', 'other': 'Thailand'}),
        isNull);
    expect(service.countryFor({'country': 'KR', 'other': 'Japan'}), 'KR');
  });

  test(
      'one stamp per country and document, with reliable first/last scan dates',
      () {
    final records = [
      SavedFoodScan(
          'a', {'country': 'Japan', 'timestamp': '2024-02-03T00:00:00Z'}),
      SavedFoodScan('b', {
        'country': '日本',
        'timestamp': Timestamp.fromDate(DateTime.utc(2025, 3, 4))
      }),
      SavedFoodScan('c', {'country': 'JP', 'timestamp': 'invalid'}),
      SavedFoodScan('a', {'country': 'Japan', 'timestamp': '2020-01-01'}),
      const SavedFoodScan('d', {'country': 'Unknown Country'}),
    ];
    final stamps = service.stamps(records);
    expect(stamps, hasLength(1));
    expect(stamps.single.savedScanCount, 3);
    expect(stamps.single.firstScanDate, DateTime.utc(2024, 2, 3));
    expect(stamps.single.lastScanDate, DateTime.utc(2025, 3, 4));
    expect(stamps.single.flag, '🇯🇵');
    expect(FoodPassportService.displayName(stamps.single, 'ko'), '일본');
    expect(service.stamps([]), isEmpty);
  });
}
