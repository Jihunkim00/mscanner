enum FoodCategory {
  noodles,
  rice,
  meat,
  seafood,
  soup,
  vegetables,
  dessert,
  drinks,
  unknown;
}

class SavedFoodScan {
  const SavedFoodScan(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class CountryStamp {
  const CountryStamp(
      {required this.countryCode,
      required this.countryName,
      required this.savedScanCount,
      this.firstScanDate,
      this.lastScanDate});
  final String countryCode;
  final String countryName;
  final int savedScanCount;
  final DateTime? firstScanDate;
  final DateTime? lastScanDate;

  String get flag =>
      String.fromCharCodes(countryCode.codeUnits.map((unit) => unit + 127397));
}

class FoodJourneySummary {
  FoodJourneySummary(
      {required this.savedScanCount,
      required List<CountryStamp> stamps,
      required Map<FoodCategory, int> counts})
      : stamps = List.unmodifiable(stamps),
        counts = Map.unmodifiable(counts);

  final int savedScanCount;
  final List<CountryStamp> stamps;
  final Map<FoodCategory, int> counts;
  int get classifiedScanCount => counts.entries
      .where((entry) => entry.key != FoodCategory.unknown)
      .fold(0, (total, entry) => total + entry.value);

  List<FoodCategory> get rankedCategories => FoodCategory.values
      .where((category) =>
          category != FoodCategory.unknown && (counts[category] ?? 0) > 0)
      .toList()
    ..sort((a, b) {
      final order = counts[b]!.compareTo(counts[a]!);
      return order == 0 ? a.index.compareTo(b.index) : order;
    });

  /// Largest remainders keep displayed integer percentages at exactly 100.
  Map<FoodCategory, int> get percentages {
    final total = classifiedScanCount;
    if (total == 0) return const {};
    final ranked = rankedCategories;
    final result = {
      for (final category in ranked) category: counts[category]! * 100 ~/ total
    };
    final remainderOrder = [...ranked]..sort((a, b) {
        final order =
            (counts[b]! * 100 % total).compareTo(counts[a]! * 100 % total);
        return order == 0 ? a.index.compareTo(b.index) : order;
      });
    final missing = 100 - result.values.fold(0, (a, b) => a + b);
    for (var index = 0; index < missing; index++) {
      result[remainderOrder[index]] = result[remainderOrder[index]]! + 1;
    }
    return result;
  }
}
