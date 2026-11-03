import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ad_remove_provider.dart';
import '../../../l10n/gen_l10n/app_localizations.dart';
import '../screens/food_journey_screen.dart';
import '../services/food_journey_service.dart';
import 'food_journey_sections.dart';

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
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context)!.journeyLoading)));
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
    return AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final summary = service.summary;
          return Card(
            key: const ValueKey('food-journey-home-card'),
            margin: EdgeInsets.zero,
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.colorScheme.outlineVariant)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => FoodJourneyScreen(service: service))),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(l10n.journeyTitle,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700))),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 20),
                        ]),
                        const SizedBox(height: 10),
                        if (service.loading && summary == null) ...[
                          LinearProgressIndicator(
                              semanticsLabel: l10n.journeyLoading),
                          const SizedBox(height: 8),
                          Text(l10n.journeyLoading),
                        ] else if (summary != null &&
                            summary.savedScanCount > 0)
                          LayoutBuilder(builder: (context, constraints) {
                            final passport = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.journeyPassport,
                                      style: theme.textTheme.labelMedium),
                                  Text(
                                      l10n.journeyCountries(
                                          summary.stamps.length),
                                      style: theme.textTheme.titleMedium),
                                  if (summary.stamps.isNotEmpty)
                                    Semantics(
                                        excludeSemantics: true,
                                        label: l10n.journeyOpenPassport,
                                        child: Text(summary.stamps
                                            .take(3)
                                            .map((stamp) => stamp.flag)
                                            .join(' '))),
                                ]);
                            final top = summary.rankedCategories.firstOrNull;
                            final dna = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.journeyDna,
                                      style: theme.textTheme.labelMedium),
                                  if (top == null)
                                    Text(l10n.journeyInsufficient)
                                  else ...[
                                    Text(foodCategoryLabel(top, l10n),
                                        style: theme.textTheme.titleMedium),
                                    Text(
                                        l10n.journeyShare(
                                            summary.percentages[top]!),
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ]);
                            final scale =
                                MediaQuery.textScalerOf(context).scale(14) / 14;
                            if (constraints.maxWidth < 260 * scale) {
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    passport,
                                    const SizedBox(height: 12),
                                    dna
                                  ]);
                            }
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: passport),
                                  const SizedBox(width: 16),
                                  Expanded(child: dna)
                                ]);
                          })
                        else if (!service.hasError) ...[
                          Text(l10n.journeyEmpty,
                              style: theme.textTheme.titleSmall),
                          Text(l10n.journeyStart,
                              style: theme.textTheme.bodySmall),
                        ],
                        if (summary != null && summary.savedScanCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                              service.hasMore
                                  ? l10n.journeyPartialScope(
                                      summary.savedScanCount)
                                  : l10n.journeyScope(summary.savedScanCount),
                              style: theme.textTheme.labelSmall),
                        ],
                        if (service.hasError) ...[
                          Text(service.showingCachedData
                              ? l10n.journeyCached
                              : l10n.journeyError),
                          Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                  onPressed: service.loading
                                      ? null
                                      : () => service.load(refresh: true),
                                  child: Text(l10n.journeyRetry))),
                        ],
                      ])),
            ),
          );
        });
  }
}
