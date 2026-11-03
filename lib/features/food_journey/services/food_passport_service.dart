import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_journey_summary.dart';
import 'country_names.dart';

class FoodPassportService {
  const FoodPassportService();

  static String _key(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.\u2019\u0027]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  static final Map<String, String> _aliases = _buildAliases();
  static Map<String, String> _buildAliases() {
    final aliases = <String, String>{};
    final ambiguous = <String>{};
    for (final entry in foodJourneyCountryNames.entries) {
      for (final name in [entry.key, ...entry.value]) {
        final key = _key(name);
        if (aliases.containsKey(key) && aliases[key] != entry.key) {
          ambiguous.add(key);
        } else {
          aliases[key] = entry.key;
        }
      }
    }
    for (final key in ambiguous) {
      aliases.remove(key);
    }
    aliases.addAll({
      'japan': 'JP',
      'korea': 'KR',
      'south korea': 'KR',
      'republic of korea': 'KR',
      '대한민국': 'KR',
      '한국': 'KR',
      '大韓民国': 'KR',
      '韩国': 'KR',
      '韓國': 'KR',
      'vietnam': 'VN',
      'viet nam': 'VN',
      'việt nam': 'VN',
      'usa': 'US',
      'united states of america': 'US',
      'uk': 'GB',
      'great britain': 'GB',
      'российская федерация': 'RU',
      'russian federation': 'RU',
      'uae': 'AE',
      'czech republic': 'CZ',
      'turkey': 'TR',
      'türkiye': 'TR',
    });
    return aliases;
  }

  String? normalizeCountry(Object? value) =>
      value is String ? _aliases[_key(value)] : null;

  String? countryFor(Map<String, dynamic> data) {
    final direct = normalizeCountry(data['country']);
    if (direct != null) return direct;
    // Only explicit country names in saved location descriptions. A city name,
    // GPS point or geohash cannot by itself establish a historical country.
    final candidates = <String>{};
    for (final field in ['city', 'other']) {
      final text = data[field];
      if (text is! String) continue;
      for (final part in text.split(RegExp(r'[,;\n]'))) {
        // Short codes in free text could be cities/states (e.g. CA or IN).
        if (part.trim().length <= 2) continue;
        final code = normalizeCountry(part);
        if (code != null) candidates.add(code);
      }
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  static DateTime? scanDate(Object? timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate().toUtc();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) return DateTime.tryParse(timestamp);
    return null;
  }

  List<CountryStamp> stamps(Iterable<SavedFoodScan> scans) {
    final groups = <String, List<SavedFoodScan>>{};
    final seen = <String>{};
    for (final scan in scans) {
      if (!seen.add(scan.id)) continue;
      final code = countryFor(scan.data);
      if (code != null) groups.putIfAbsent(code, () => []).add(scan);
    }
    final result = <CountryStamp>[];
    for (final entry in groups.entries) {
      final dates = entry.value
          .map((scan) => scanDate(scan.data['timestamp']))
          .whereType<DateTime>()
          .toList()
        ..sort();
      result.add(CountryStamp(
          countryCode: entry.key,
          countryName: foodJourneyCountryNames[entry.key]!.first,
          savedScanCount: entry.value.length,
          firstScanDate: dates.firstOrNull,
          lastScanDate: dates.lastOrNull));
    }
    result.sort((a, b) {
      final order = (b.lastScanDate ?? DateTime(0))
          .compareTo(a.lastScanDate ?? DateTime(0));
      return order == 0 ? a.countryCode.compareTo(b.countryCode) : order;
    });
    return result;
  }

  static String displayName(CountryStamp stamp, String localeName) {
    var index = foodJourneyCountryLocales.indexOf(localeName);
    if (index < 0) {
      index = foodJourneyCountryLocales.indexOf(localeName.split('_').first);
    }
    return foodJourneyCountryNames[stamp.countryCode]?[index < 0 ? 0 : index] ??
        stamp.countryName;
  }
}
