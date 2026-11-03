import 'package:flutter/material.dart';
import '../../../l10n/gen_l10n/app_localizations.dart';
import '../../../widgets/adaptive_window.dart';
import '../services/food_journey_service.dart';
import '../widgets/food_journey_sections.dart';

class FoodJourneyScreen extends StatelessWidget {
  const FoodJourneyScreen({super.key, required this.service});
  final FoodJourneyService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdaptivePage(
        child: Scaffold(
      appBar: AppBar(title: Text(l10n.journeyTitle)),
      body: AdaptiveContent(
          child: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final summary = service.summary;
          return RefreshIndicator(
            onRefresh: () => service.load(refresh: true),
            child: SingleChildScrollView(
              key: const PageStorageKey('food-journey-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (service.loading) ...[
                      LinearProgressIndicator(
                          semanticsLabel: l10n.journeyLoading),
                      const SizedBox(height: 12),
                    ],
                    if (service.hasError) ...[
                      Text(service.showingCachedData
                          ? l10n.journeyCached
                          : l10n.journeyError),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                              onPressed: service.loading ? null : service.retry,
                              child: Text(l10n.journeyRetry))),
                      const SizedBox(height: 12),
                    ],
                    if (summary == null && service.loading)
                      Text(l10n.journeyLoading),
                    if ((summary == null &&
                            !service.loading &&
                            !service.hasError) ||
                        summary?.savedScanCount == 0) ...[
                      const Icon(Icons.travel_explore, size: 48),
                      const SizedBox(height: 16),
                      Text(l10n.journeyEmpty, textAlign: TextAlign.center),
                      Text(l10n.journeyStart, textAlign: TextAlign.center),
                    ],
                    if (summary != null && summary.savedScanCount > 0) ...[
                      Text(
                          service.hasMore
                              ? l10n.journeyPartialScope(summary.savedScanCount)
                              : l10n.journeyScope(summary.savedScanCount),
                          key: const ValueKey('journey-scope'),
                          style: Theme.of(context).textTheme.bodySmall),
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
