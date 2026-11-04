import 'package:flutter/material.dart';
import '../../../l10n/gen_l10n/app_localizations.dart';
import '../../../widgets/adaptive_window.dart';
import '../services/food_journey_service.dart';
import '../widgets/food_journey_icons.dart';
import '../widgets/food_journey_sections.dart';
import '../widgets/food_journey_style.dart';

class FoodJourneyScreen extends StatelessWidget {
  const FoodJourneyScreen({super.key, required this.service});
  final FoodJourneyService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = FoodJourneyStyle.of(context);
    return AdaptivePage(
        child: Scaffold(
      backgroundColor: style.page,
      appBar: AppBar(
          backgroundColor: style.page,
          surfaceTintColor: Colors.transparent,
          foregroundColor: style.primary,
          title: Text(l10n.journeyTitle)),
      body: AdaptiveContent(
          child: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final summary = service.summary;
          return RefreshIndicator(
            color: style.accent,
            backgroundColor: style.card,
            onRefresh: () => service.load(refresh: true),
            child: SingleChildScrollView(
              key: const PageStorageKey('food-journey-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (service.loading) ...[
                      JourneySectionSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            JourneySectionHeading(
                                icon: FoodJourneyIconType.passport,
                                title: l10n.journeyLoading),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                                color: style.accent,
                                backgroundColor: style.soft,
                                semanticsLabel: l10n.journeyLoading),
                          ])),
                      const SizedBox(height: 12),
                    ],
                    if (service.hasError) ...[
                      JourneySectionSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            Text(service.showingCachedData
                                ? l10n.journeyCached
                                : l10n.journeyError),
                            Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: style.emphasis),
                                    onPressed:
                                        service.loading ? null : service.retry,
                                    child: Text(l10n.journeyRetry))),
                          ])),
                      const SizedBox(height: 12),
                    ],
                    if ((summary == null &&
                            !service.loading &&
                            !service.hasError) ||
                        summary?.savedScanCount == 0) ...[
                      JourneySectionSurface(
                          child: Column(children: [
                        const FoodJourneyIcon(
                            type: FoodJourneyIconType.globe, size: 36),
                        const SizedBox(height: 12),
                        Text(l10n.journeyEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: style.primary,
                                    fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(l10n.journeyStart,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: style.secondary)),
                      ])),
                    ],
                    if (summary != null && summary.savedScanCount > 0) ...[
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: JourneyScopePill(
                              label: service.hasMore
                                  ? l10n.journeyPartialScope(
                                      summary.savedScanCount)
                                  : l10n.journeyScope(summary.savedScanCount),
                              key: const ValueKey('journey-scope'))),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        final scale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        final passport = FoodPassportSection(summary: summary);
                        final dna = FoodDnaSection(summary: summary);
                        if (constraints.maxWidth >= 800 * scale) {
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: passport),
                                const SizedBox(width: 16),
                                Expanded(child: dna)
                              ]);
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              passport,
                              const SizedBox(height: 16),
                              dna
                            ]);
                      }),
                      if (service.hasMore)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: style.emphasis,
                                    side: BorderSide(color: style.border)),
                                onPressed: service.loading
                                    ? null
                                    : () => service.load(more: true),
                                child: Text(l10n.journeyLoadMore))),
                    ],
                  ]),
            ),
          );
        },
      )),
    ));
  }
}
