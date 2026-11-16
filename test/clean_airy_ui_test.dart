import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/History_Screen.dart';
import 'package:mscanner/screens/favorite_list_screen.dart';
import 'package:mscanner/screens/home_screen.dart';
import 'package:mscanner/screens/map_screen.dart';
import 'package:mscanner/styles/app_theme.dart';
import 'package:mscanner/widgets/how_to_use_mscanner_card.dart';
import 'package:mscanner/widgets/mscanner_search_ui.dart';
import 'support/app_test_fonts.dart';

Widget uiApp(
  Widget Function(BuildContext) builder, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.android,
}) =>
    MaterialApp(
      theme: (dark ? AppTheme.dark() : AppTheme.light())
          .copyWith(platform: platform),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(builder: builder),
    );

void main() {
  setUpAll(loadAppTestFonts);

  test('text and primary controls retain readable contrast in both themes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final colors in [AppColors.light, AppColors.dark]) {
      expect(contrast(colors.text, colors.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(colors.secondaryText, colors.background),
          greaterThanOrEqualTo(4.5));
      expect(contrast(colors.onPrimary, colors.primary),
          greaterThanOrEqualTo(4.5));
    }
    expect(AppTheme.light().textTheme.bodyMedium!.fontFamily, 'SFPro');
  });

  testWidgets(
      'saved record keeps image toggle, selection and detail actions without duplicate text',
      (tester) async {
    var detailTaps = 0;
    var imageTaps = 0;
    var selected = false;
    await tester.pumpWidget(uiApp((context) => Scaffold(
          body: StatefulBuilder(
              builder: (context, setState) => SavedHistoryCard(
                    menuName: 'Ramen',
                    restaurant: ' Ramen ',
                    rating: 4.5,
                    dateText: 'Nov 14, 8:00 PM',
                    imageUrl: '',
                    isSelected: selected,
                    onTap: () => detailTaps++,
                    onImageTap: () => imageTaps++,
                    onSelected: (value) => setState(() => selected = value!),
                  )),
        )));
    expect(find.text('Ramen'), findsOneWidget);
    expect(find.text(' Ramen '), findsNothing);
    await tester.tap(find.byType(ClipRRect));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(imageTaps, 1);
    expect(selected, isTrue);
    expect(detailTaps, 0);
    await tester.tap(find.text('Ramen'));
    expect(detailTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search, filter and saved/map switch keep their callbacks and selection',
      (tester) async {
    var query = '';
    var filtered = false;
    var segment = 'Saved';
    await tester.pumpWidget(uiApp((context) => Scaffold(
          body: StatefulBuilder(
              builder: (context, setState) => Column(children: [
                    HistoryViewSwitcher(
                        value: segment,
                        onChanged: (value) => setState(() => segment = value!)),
                    MScannerSearchField(
                        placeholder: 'Search history',
                        onChanged: (value) => query = value),
                    MScannerPillChip(
                        label: 'Recent',
                        selected: filtered,
                        onTap: () => setState(() => filtered = !filtered)),
                  ])),
        )));
    await tester.enterText(find.byType(CupertinoSearchTextField), 'ramen');
    await tester.pump(const Duration(milliseconds: 400));
    expect(query, 'ramen');
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<MScannerPillChip>(find.byType(MScannerPillChip)).selected,
        isTrue);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(segment, 'Map');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(segment, 'Saved');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'map card retains focus action and avoids repeating its fallback restaurant',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(uiApp((context) => Scaffold(
            body: SizedBox(
          height: 132,
          child: MapHistoryCard(data: const {
            '__menuTitle': 'Ramen',
            'restaurantName': 'Ramen',
            'timestamp': '2026-11-14T20:00:00',
            'rate': 4.5,
          }, selected: true, onTap: () => taps++),
        ))));
    expect(find.text('Ramen'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    await tester.tap(find.text('Ramen'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all five bottom destinations remain selectable above the system inset',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    var selected = 0;
    await tester.pumpWidget(uiApp((context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: MscannerBottomNavigation(
                selectedIndex: selected,
                onTap: (value) => setState(() => selected = value)),
          ),
        )));
    final icons = [
      Icons.home,
      Icons.camera,
      Icons.photo_library,
      Icons.history,
      Icons.settings
    ];
    for (var i = 0; i < icons.length; i++) {
      await tester.tap(find.byIcon(icons[i]));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          i);
      expect(tester.getBottomLeft(find.byIcon(icons[i])).dy,
          lessThanOrEqualTo(576));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shared controls and cards fit 280px, 200% text and RTL on Android and iOS',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final dark in [false, true]) {
        for (final locale in AppLocalizations.supportedLocales) {
          await tester.pumpWidget(uiApp((context) {
            final l10n = AppLocalizations.of(context)!;
            final title = '${l10n.journeyTitle} · ${l10n.journeyPassport}';
            return Scaffold(
              body: SafeArea(
                  child: SingleChildScrollView(
                      child: Column(children: [
                HistoryViewSwitcher(value: 'Saved', onChanged: (_) {}),
                MScannerSearchField(
                    placeholder: l10n.map_searchHistory, onChanged: (_) {}),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      MScannerPillChip(
                          label: l10n.map_recent, selected: true, onTap: () {}),
                      MScannerPillChip(
                          label: l10n.map_topRated,
                          selected: false,
                          onTap: () {}),
                    ])),
                SavedHistoryCard(
                    menuName: title,
                    restaurant: l10n.journeyDna,
                    rating: 4.5,
                    dateText: l10n.journeyFirst('2026.11.14'),
                    imageUrl: '',
                    isSelected: false,
                    onTap: () {},
                    onImageTap: () {},
                    onSelected: (_) {}),
                SizedBox(
                    height: 180,
                    child: MapHistoryCard(data: {
                      '__menuTitle': title,
                      'restaurantName': l10n.journeyDna,
                      'timestamp': '2026-11-14T20:00:00',
                      'rate': 4.5
                    }, selected: true, onTap: () {})),
                HowToUseMscannerCard(onCardTap: () {}),
              ]))),
              bottomNavigationBar:
                  MscannerBottomNavigation(selectedIndex: 3, onTap: (_) {}),
            );
          }, locale: locale, dark: dark, scale: 2, platform: platform));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$platform $locale dark=$dark');
          if (locale.languageCode == 'ar') {
            expect(
                Directionality.of(
                    tester.element(find.byType(HistoryViewSwitcher))),
                TextDirection.rtl);
          }
        }
      }
    }
  });
}
