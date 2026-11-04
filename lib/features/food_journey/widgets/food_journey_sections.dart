import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/gen_l10n/app_localizations.dart';
import '../models/food_journey_summary.dart';
import '../services/food_passport_service.dart';
import 'food_journey_icons.dart';
import 'food_journey_style.dart';

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

class FoodPassportSection extends StatelessWidget {
  const FoodPassportSection({super.key, required this.summary});
  final FoodJourneySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final style = FoodJourneyStyle.of(context);
    return JourneySectionSurface(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionHeading(
            icon: FoodJourneyIconType.passport, title: l10n.journeyPassport),
        const SizedBox(height: 8),
        _JourneyIconLabel(
            icon: FoodJourneyIconType.globe,
            label: l10n.journeyCountries(summary.stamps.length),
            textStyle: theme.textTheme.titleSmall
                ?.copyWith(color: style.emphasis, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: style.border),
                      color: style.inner,
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                    excludeSemantics: true,
                                    label: FoodPassportService.displayName(
                                        stamp, l10n.localeName),
                                    child: Text(stamp.flag,
                                        style: const TextStyle(fontSize: 32))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        FoodPassportService.displayName(
                                            stamp, l10n.localeName),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                color: style.primary,
                                                fontWeight: FontWeight.w700)),
                                    Text(
                                        l10n.journeyRecords(
                                            stamp.savedScanCount),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: style.emphasis,
                                                fontWeight: FontWeight.w600)),
                                  ],
                                )),
                              ]),
                          const SizedBox(height: 8),
                          if (stamp.firstScanDate != null)
                            _JourneyIconLabel(
                                icon: FoodJourneyIconType.calendar,
                                label: l10n.journeyFirst(
                                    DateFormat.yMMMd(l10n.localeName).format(
                                        stamp.firstScanDate!.toLocal())),
                                textStyle: theme.textTheme.bodySmall
                                    ?.copyWith(color: style.secondary)),
                          if (stamp.lastScanDate != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _JourneyIconLabel(
                                    icon: FoodJourneyIconType.calendar,
                                    label: l10n.journeyLast(DateFormat.yMMMd(
                                            l10n.localeName)
                                        .format(stamp.lastScanDate!.toLocal())),
                                    textStyle: theme.textTheme.bodySmall
                                        ?.copyWith(color: style.secondary))),
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
    final style = FoodJourneyStyle.of(context);
    final percentages = summary.percentages;
    return JourneySectionSurface(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionHeading(
            icon: FoodJourneyIconType.dna, title: l10n.journeyDna),
        const SizedBox(height: 8),
        Text(l10n.journeyDescription,
            style: theme.textTheme.bodySmall?.copyWith(color: style.secondary)),
        const SizedBox(height: 8),
        _JourneyIconLabel(
            icon: FoodJourneyIconType.chart,
            label: l10n.journeyClassified(summary.classifiedScanCount),
            textStyle:
                theme.textTheme.bodySmall?.copyWith(color: style.secondary)),
        const SizedBox(height: 12),
        if (summary.classifiedScanCount == 0)
          Text(l10n.journeyInsufficient)
        else ...[
          Text(l10n.journeyTopTypes,
              style: theme.textTheme.labelLarge?.copyWith(
                  color: style.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final category in summary.rankedCategories.take(3))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: style.soft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: style.border)),
                child: _JourneyIconLabel(
                    icon: FoodJourneyIconType.forCategory(category),
                    compact: true,
                    label:
                        '${foodCategoryLabel(category, l10n)} · ${l10n.journeyShare(percentages[category]!)}',
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                        color: style.emphasis, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 12),
        ],
        // Every class is present; unknown is a count, never part of the chart denominator.
        for (final category
            in FoodCategory.values.where((c) => c != FoodCategory.unknown))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
                              _JourneyIconLabel(
                                  icon:
                                      FoodJourneyIconType.forCategory(category),
                                  label: foodCategoryLabel(category, l10n),
                                  compact: true),
                              Text(
                                  l10n.journeyShare(percentages[category] ?? 0),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: style.emphasis,
                                      fontWeight: FontWeight.w600))
                            ]),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (percentages[category] ?? 0) / 100,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                          color: style.accent,
                          backgroundColor: style.soft,
                        ),
                      ]))),
        const SizedBox(height: 8),
        Text(
            '${l10n.journeyUnknown} · ${l10n.journeyRecords(summary.counts[FoodCategory.unknown] ?? 0)}',
            style: theme.textTheme.bodySmall?.copyWith(color: style.secondary)),
      ],
    ));
  }
}

class JourneySectionSurface extends StatelessWidget {
  const JourneySectionSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final style = FoodJourneyStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: style.card,
          borderRadius: FoodJourneyStyle.radius,
          border: Border.all(color: style.border)),
      child: DefaultTextStyle.merge(
          style: TextStyle(color: style.primary), child: child),
    );
  }
}

class JourneySectionHeading extends StatelessWidget {
  const JourneySectionHeading(
      {super.key, required this.icon, required this.title});
  final FoodJourneyIconType icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodJourneyIcon(type: icon),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FoodJourneyStyle.of(context).primary,
                      fontWeight: FontWeight.w700))),
        ],
      );
}

class JourneyScopePill extends StatelessWidget {
  const JourneyScopePill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: FoodJourneyStyle.of(context).soft,
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: FoodJourneyStyle.of(context).secondary)),
      );
}

class _JourneyIconLabel extends StatelessWidget {
  const _JourneyIconLabel({
    required this.icon,
    required this.label,
    this.textStyle,
    this.compact = false,
  });
  final FoodJourneyIconType icon;
  final String label;
  final TextStyle? textStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodJourneyIcon(type: icon, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: textStyle)),
        ],
      );
}
