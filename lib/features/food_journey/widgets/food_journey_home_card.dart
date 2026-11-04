import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ad_remove_provider.dart';
import '../../../l10n/gen_l10n/app_localizations.dart';
import '../screens/food_journey_screen.dart';
import '../services/food_journey_service.dart';
import 'food_journey_icons.dart';
import 'food_journey_sections.dart';
import 'food_journey_style.dart';

/// Auth/entitlement wiring stays outside the presentation and aggregation code.
class FoodJourneyEntry extends StatefulWidget {
  const FoodJourneyEntry({super.key});
  @override
  State<FoodJourneyEntry> createState() => _FoodJourneyEntryState();
}

class _FoodJourneyEntryState extends State<FoodJourneyEntry>
    with WidgetsBindingObserver {
  final _service = FoodJourneyService.instance;
  StreamSubscription<User?>? _auth;
  Timer? _timer;
  AdRemoveProvider? _entitlement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = FirebaseAuth.instance.authStateChanges().listen((_) => _sync());
    _timer = Timer.periodic(_service.ttl, (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_service.load());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final entitlement = context.read<AdRemoveProvider>();
    if (_entitlement != entitlement) {
      _entitlement?.removeListener(_sync);
      _entitlement = entitlement;
      entitlement.addListener(_sync);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
  }

  void _sync() {
    if (!mounted) return;
    final entitlement = _entitlement;
    final user = FirebaseAuth.instance.currentUser;
    _service.selectAccount(
        entitlement?.isEntitlementLoaded == true ? user?.uid : null,
        isPremium: entitlement?.isSubscribed == true &&
            entitlement?.isEntitlementLoaded == true);
    unawaited(_service.load());
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entitlement?.removeListener(_sync);
    _auth?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A newly mounted home can precede the first auth/entitlement callback.
    if (_entitlement?.isEntitlementLoaded != true ||
        _service.uid != FirebaseAuth.instance.currentUser?.uid) {
      return JourneySectionSurface(
          child: JourneySectionHeading(
              icon: FoodJourneyIconType.passport,
              title: AppLocalizations.of(context)!.journeyLoading));
    }
    return FoodJourneyHomeCard(service: _service);
  }
}

class FoodJourneyHomeCard extends StatelessWidget {
  const FoodJourneyHomeCard({super.key, required this.service});
  final FoodJourneyService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final style = FoodJourneyStyle.of(context);
    return AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final summary = service.summary;
          return Card(
            key: const ValueKey('food-journey-home-card'),
            margin: EdgeInsets.zero,
            elevation: 0,
            color: style.card,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: FoodJourneyStyle.radius,
                side: BorderSide(color: style.border)),
            clipBehavior: Clip.antiAlias,
            child: DefaultTextStyle.merge(
                style: TextStyle(color: style.primary),
                child: InkWell(
                  splashColor: style.accent.withValues(alpha: 0.12),
                  highlightColor: style.accent.withValues(alpha: 0.06),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => FoodJourneyScreen(service: service))),
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const FoodJourneyIcon(
                                  type: FoodJourneyIconType.passport, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(l10n.journeyTitle,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              color: style.primary,
                                              fontWeight: FontWeight.w700))),
                              const SizedBox(width: 8),
                              Icon(
                                  Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? Icons.chevron_left
                                      : Icons.chevron_right,
                                  size: 20,
                                  color: style.emphasis),
                            ]),
                            const SizedBox(height: 10),
                            if (service.loading && summary == null) ...[
                              LinearProgressIndicator(
                                  color: style.accent,
                                  backgroundColor: style.soft,
                                  semanticsLabel: l10n.journeyLoading),
                              const SizedBox(height: 8),
                              Text(l10n.journeyLoading),
                            ] else if (summary != null &&
                                summary.savedScanCount > 0)
                              LayoutBuilder(builder: (context, constraints) {
                                final passport = _HomeJourneyMetric(
                                    icon: FoodJourneyIconType.globe,
                                    label: l10n.journeyPassport,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              l10n.journeyCountries(
                                                  summary.stamps.length),
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                      color: style.primary,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                          if (summary.stamps.isNotEmpty)
                                            Semantics(
                                                excludeSemantics: true,
                                                label: l10n.journeyOpenPassport,
                                                child: Text(summary.stamps
                                                    .take(3)
                                                    .map((stamp) => stamp.flag)
                                                    .join(' '))),
                                        ]));
                                final top =
                                    summary.rankedCategories.firstOrNull;
                                final dna = _HomeJourneyMetric(
                                    icon: top == null
                                        ? FoodJourneyIconType.dna
                                        : FoodJourneyIconType.forCategory(top),
                                    label: l10n.journeyDna,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (top == null)
                                            Text(l10n.journeyInsufficient)
                                          else ...[
                                            Text(foodCategoryLabel(top, l10n),
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                        color: style.primary,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                            Text(
                                                l10n.journeyShare(
                                                    summary.percentages[top]!),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                        color: style.emphasis,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                          ],
                                        ]));
                                final scale =
                                    MediaQuery.textScalerOf(context).scale(14) /
                                        14;
                                if (constraints.maxWidth < 280 * scale) {
                                  return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        passport,
                                        Divider(
                                            height: 17, color: style.border),
                                        dna
                                      ]);
                                }
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: passport),
                                      Container(
                                          width: 1,
                                          height: 52,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          color: style.border),
                                      Expanded(child: dna)
                                    ]);
                              })
                            else if (!service.hasError) ...[
                              Text(l10n.journeyEmpty,
                                  style: theme.textTheme.titleSmall),
                              Text(l10n.journeyStart,
                                  style: theme.textTheme.bodySmall),
                            ],
                            if (summary != null &&
                                summary.savedScanCount > 0) ...[
                              const SizedBox(height: 8),
                              Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: JourneyScopePill(
                                      label: service.hasMore
                                          ? l10n.journeyPartialScope(
                                              summary.savedScanCount)
                                          : l10n.journeyScope(
                                              summary.savedScanCount))),
                            ],
                            if (service.hasError) ...[
                              Text(service.showingCachedData
                                  ? l10n.journeyCached
                                  : l10n.journeyError),
                              Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton(
                                      style: TextButton.styleFrom(
                                          foregroundColor: style.emphasis),
                                      onPressed: service.loading
                                          ? null
                                          : () => service.load(refresh: true),
                                      child: Text(l10n.journeyRetry))),
                            ],
                          ])),
                )),
          );
        });
  }
}

class _HomeJourneyMetric extends StatelessWidget {
  const _HomeJourneyMetric({
    required this.icon,
    required this.label,
    required this.child,
  });

  final FoodJourneyIconType icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FoodJourneyIcon(type: icon, size: 18),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: FoodJourneyStyle.of(context).secondary))),
          ]),
          const SizedBox(height: 2),
          child,
        ],
      );
}
