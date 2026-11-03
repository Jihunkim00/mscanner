import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/gen_l10n/app_localizations.dart';
import '../models/food_journey_summary.dart';
import '../services/food_passport_service.dart';

String foodCategoryLabel(FoodCategory category, AppLocalizations l10n) =>
    switch (category) {
      FoodCategory.noodles => l10n.journeyNoodles,
      FoodCategory.rice => l10n.journeyRice,
      FoodCategory.meat => l10n.journeyMeat,
      FoodCategory.seafood => l10n.journeySeafood,
      FoodCategory.soup => l10n.journeySoup,
      FoodCategory.vegetables => l10n.journeyVegetables,
      FoodCategory.dessert => l10n.journeyDessert,
      FoodCategory.drinks => l10n.journeyDrinks,
      FoodCategory.unknown => l10n.journeyUnknown,
    };

const _categoryColors = <FoodCategory, Color>{
  FoodCategory.noodles: Color(0xffd69a49),
  FoodCategory.rice: Color(0xffb09b69),
  FoodCategory.meat: Color(0xffca756a),
  FoodCategory.seafood: Color(0xff529eaa),
  FoodCategory.soup: Color(0xffb98451),
  FoodCategory.vegetables: Color(0xff75a482),
  FoodCategory.dessert: Color(0xffac86b4),
  FoodCategory.drinks: Color(0xff7095bd),
};

class FoodPassportSection extends StatelessWidget {
  const FoodPassportSection({super.key, required this.summary});
  final FoodJourneySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return JourneySectionSurface(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.journeyPassport, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.journeyCountries(summary.stamps.length),
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        if (summary.stamps.isEmpty) Text(l10n.journeyNoCountries),
        LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = constraints.maxWidth >= 520 * scale ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final stamp in summary.stamps)
              SizedBox(
                  width: width,
                  child: Container(
                    key: ValueKey('stamp-${stamp.countryCode}'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      color: theme.colorScheme.surfaceContainerLow,
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                              excludeSemantics: true,
                              label: FoodPassportService.displayName(
                                  stamp, l10n.localeName),
                              child: Text(stamp.flag,
                                  style: const TextStyle(fontSize: 32))),
                          const SizedBox(height: 8),
                          Text(
                              FoodPassportService.displayName(
                                  stamp, l10n.localeName),
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(l10n.journeyRecords(stamp.savedScanCount)),
                          const SizedBox(height: 10),
                          if (stamp.firstScanDate != null)
                            Text(
                                l10n.journeyFirst(
                                    DateFormat.yMMMd(l10n.localeName).format(
                                        stamp.firstScanDate!.toLocal())),
                                style: theme.textTheme.bodySmall),
                          if (stamp.lastScanDate != null)
                            Text(
                                l10n.journeyLast(
                                    DateFormat.yMMMd(l10n.localeName)
                                        .format(stamp.lastScanDate!.toLocal())),
                                style: theme.textTheme.bodySmall),
                        ]),
                  )),
          ]);
        }),
      ],
    ));
  }
}

class FoodDnaSection extends StatelessWidget {
  const FoodDnaSection({super.key, required this.summary});
  final FoodJourneySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final percentages = summary.percentages;
    return JourneySectionSurface(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.journeyDna, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.journeyDescription),
        const SizedBox(height: 8),
        Text(l10n.journeyClassified(summary.classifiedScanCount),
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        if (summary.classifiedScanCount == 0)
          Text(l10n.journeyInsufficient)
        else ...[
          Text(l10n.journeyTopTypes, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final category in summary.rankedCategories.take(3))
              Chip(
                label: Text(
                    '${foodCategoryLabel(category, l10n)} · ${l10n.journeyShare(percentages[category]!)}'),
                backgroundColor:
                    _categoryColors[category]!.withValues(alpha: 0.15),
              ),
          ]),
          const SizedBox(height: 12),
        ],
        // Every class is present; unknown is a count, never part of the chart denominator.
        for (final category
            in FoodCategory.values.where((c) => c != FoodCategory.unknown))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                  label: '${foodCategoryLabel(category, l10n)}, '
                      '${l10n.journeyRecords(summary.counts[category] ?? 0)}, '
                      '${l10n.journeyShare(percentages[category] ?? 0)}',
                  excludeSemantics: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(foodCategoryLabel(category, l10n)),
                              Text(
                                  l10n.journeyShare(percentages[category] ?? 0))
                            ]),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (percentages[category] ?? 0) / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: _categoryColors[category],
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ]))),
        const SizedBox(height: 8),
        Text(
            '${l10n.journeyUnknown} · ${l10n.journeyRecords(summary.counts[FoodCategory.unknown] ?? 0)}',
            style: theme.textTheme.bodySmall),
      ],
    ));
  }
}

class JourneySectionSurface extends StatelessWidget {
  const JourneySectionSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: child,
      );
}
