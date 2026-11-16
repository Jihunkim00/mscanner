import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/screens/food_journey_screen.dart';
import 'package:mscanner/features/food_journey/services/food_journey_repository.dart';
import 'package:mscanner/features/food_journey/services/food_journey_service.dart';
import 'package:mscanner/features/food_journey/widgets/food_journey_home_card.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/History_Screen.dart';
import 'package:mscanner/screens/favorite_list_screen.dart';
import 'package:mscanner/screens/home_screen.dart';
import 'package:mscanner/screens/map_screen.dart';
import 'package:mscanner/styles/app_theme.dart';
import 'package:mscanner/widgets/how_to_use_mscanner_card.dart';
import 'package:mscanner/widgets/mscanner_search_ui.dart';
import 'food_journey_service_test.dart' show TestJourneySource, foodScan;
import 'support/app_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Use the shipped fonts rather than the test framework's Ahem placeholders.
  setUpAll(loadAppTestFonts);

  for (final dark in [false, true]) {
    for (final view in ['home_cards', 'history_cards', 'journey']) {
      testWidgets('$view ${dark ? 'dark' : 'light'} visual baseline',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = TestJourneySource()
          ..answer = (_, __) async => FoodJourneyPage([
                foodScan('1', 'Ramen'),
                foodScan('2', 'Sushi'),
                foodScan('3', 'Bibimbap', country: 'KR'),
              ]);
        final service = FoodJourneyService(source: source);
        addTearDown(service.dispose);
        service.selectAccount('visual-fixture', isPremium: false);
        await service.load();
        await tester.pumpWidget(MaterialApp(
          theme: (dark ? AppTheme.dark() : AppTheme.light())
              .copyWith(platform: TargetPlatform.android),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepaintBoundary(
            key: const ValueKey('visual-surface'),
            child: view == 'journey'
                ? FoodJourneyScreen(service: service)
                : Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (view == 'home_cards') ...[
                              FoodJourneyHomeCard(service: service),
                              const SizedBox(height: 16),
                              HowToUseMscannerCard(onCardTap: () {}),
                            ] else ...[
                              HistoryViewSwitcher(
                                  value: 'Saved', onChanged: (_) {}),
                              const SizedBox(height: 12),
                              MScannerSearchField(
                                  placeholder: 'Search history',
                                  onChanged: (_) {}),
                              const SizedBox(height: 10),
                              Row(children: [
                                MScannerPillChip(
                                    label: 'All', selected: true, onTap: () {}),
                                MScannerPillChip(
                                    label: 'Recent',
                                    selected: false,
                                    onTap: () {}),
                                MScannerPillChip(
                                    label: 'Top rated',
                                    selected: false,
                                    onTap: () {}),
                              ]),
                              const SizedBox(height: 12),
                              SavedHistoryCard(
                                  menuName: 'Tonkotsu ramen',
                                  restaurant: 'Tokyo Kitchen',
                                  rating: 4.5,
                                  dateText: 'Nov 14, 8:00 PM',
                                  imageUrl: '',
                                  isSelected: false,
                                  onTap: () {},
                                  onImageTap: () {},
                                  onSelected: (_) {}),
                              SavedHistoryCard(
                                  menuName: 'Bibimbap',
                                  restaurant: 'Seoul Table',
                                  rating: 5,
                                  dateText: 'Nov 12, 1:00 PM',
                                  imageUrl: '',
                                  isSelected: true,
                                  onTap: () {},
                                  onImageTap: () {},
                                  onSelected: (_) {}),
                              const SizedBox(height: 16),
                              SizedBox(
                                  height: 108,
                                  child: MapHistoryCard(data: const {
                                    '__menuTitle': 'Tonkotsu ramen',
                                    'restaurantName': 'Tokyo Kitchen',
                                    'rate': 4.5,
                                    'timestamp': '2026-11-14T20:00:00',
                                  }, selected: true, onTap: () {})),
                            ],
                          ]),
                    ),
                    bottomNavigationBar: MscannerBottomNavigation(
                        selectedIndex: view == 'home_cards' ? 0 : 3,
                        onTap: (_) {}),
                  ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
            find.byKey(const ValueKey('visual-surface')),
            matchesGoldenFile(
                'goldens/${view}_${dark ? 'dark' : 'light'}.png'));
        if (view == 'journey') {
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
          await expectLater(
              find.byKey(const ValueKey('visual-surface')),
              matchesGoldenFile(
                  'goldens/journey_dna_${dark ? 'dark' : 'light'}.png'));
        }
      });
    }
  }
}
