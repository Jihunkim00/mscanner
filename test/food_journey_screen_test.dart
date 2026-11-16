import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mscanner/styles/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/services/food_journey_repository.dart';
import 'package:mscanner/features/food_journey/services/food_journey_service.dart';
import 'package:mscanner/features/food_journey/screens/food_journey_screen.dart';
import 'package:mscanner/features/food_journey/widgets/food_journey_sections.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'food_journey_service_test.dart' show TestJourneySource, foodScan;

Widget screenApp(FoodJourneyService service,
        {Locale locale = const Locale('en'),
        double scale = 1,
        bool dark = true}) =>
    MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: FoodJourneyScreen(service: service));

void main() {
  testWidgets(
      'journey reuses the Preset back button and pops on both platforms and RTL',
      (tester) async {
    final service = FoodJourneyService(source: TestJourneySource());
    addTearDown(service.dispose);
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(MaterialApp(
          key: ValueKey('$platform-$locale'),
          theme: AppTheme.light().copyWith(platform: platform),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    FoodJourneyScreen(service: service))),
                        child: const Text('Open journey')),
                  )),
        ));
        await tester.tap(find.text('Open journey'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.title, isNull);
        expect(appBar.preferredSize.height, kToolbarHeight);
        expect(
            Directionality.of(tester.element(find.byType(FoodJourneyScreen))),
            locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr);
        await tester.tap(find.byType(CupertinoNavigationBarBackButton));
        await tester.pumpAndSettle();
        expect(find.byType(FoodJourneyScreen), findsNothing);
        expect(find.text('Open journey'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('journey uses the shared off-white page and white cards',
      (tester) async {
    final service = FoodJourneyService(
        source: TestJourneySource()
          ..answer =
              (_, __) async => FoodJourneyPage([foodScan('a', 'Ramen')]));
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    await tester.pumpWidget(screenApp(service, dark: false));
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.light.background);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.light.background);
    expect(appBar.surfaceTintColor, Colors.transparent);
    for (final surface in find.byType(JourneySectionSurface).evaluate()) {
      final container = tester.widget<Container>(find
          .descendant(
              of: find.byWidget(surface.widget),
              matching: find.byType(Container))
          .first);
      expect((container.decoration! as BoxDecoration).color,
          AppColors.light.surface);
    }
    final stamp =
        tester.widget<Container>(find.byKey(const ValueKey('stamp-JP')));
    expect((stamp.decoration! as BoxDecoration).color, Colors.white);
    expect(service.summary!.percentages.values.single, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'premium pagination is explicit and resize retains records, scroll and account isolation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = TestJourneySource()
      ..answer = (_, after) async => FoodJourneyPage([
            foodScan(
                after == null ? 'a' : 'b', after == null ? 'Ramen' : 'Sushi',
                country: after == null ? 'JP' : 'KR')
          ], cursor: after == null ? 'next' : null, hasMore: after == null);
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: true);
    await service.load();
    await tester.pumpWidget(screenApp(service));
    await tester.pumpAndSettle();
    expect(find.textContaining('more available'), findsOneWidget);
    final passportWide = tester.getTopLeft(find.byType(FoodPassportSection));
    final dnaWide = tester.getTopLeft(find.byType(FoodDnaSection));
    expect(passportWide.dy, dnaWide.dy);
    await tester.scrollUntilVisible(find.text('Load more saved scans'), 300);
    await tester.tap(find.text('Load more saved scans'));
    await tester.pumpAndSettle();
    expect(service.summary!.savedScanCount, 2);
    expect(find.textContaining('more available'), findsNothing);
    expect(find.text('Based on 2 saved scans'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 600);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FoodDnaSection)).dy,
        greaterThan(tester.getTopLeft(find.byType(FoodPassportSection)).dy));
    expect(service.summary!.savedScanCount, 2);
    expect(source.requests, hasLength(2));
    expect(tester.takeException(), isNull);
    service.selectAccount(null, isPremium: false);
    await tester.pumpAndSettle();
    expect(find.byType(FoodPassportSection), findsNothing);
    expect(find.text('No records yet'), findsOneWidget);
  });

  testWidgets(
      'all locales fit narrow expanded text and wide screens; RTL is preserved',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FoodJourneyService(
        source: TestJourneySource()
          ..answer = (_, __) async => FoodJourneyPage(
              [foodScan('a', 'Ramen'), foodScan('b', 'Sushi', country: 'KR')]));
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    for (final dark in [false, true]) {
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
            screenApp(service, locale: locale, scale: 2, dark: dark));
        await tester.pumpAndSettle();
        if (locale.languageCode == 'ar') {
          expect(
              Directionality.of(
                  tester.element(find.byType(FoodPassportSection))),
              TextDirection.rtl);
        }
        expect(tester.takeException(), isNull, reason: locale.toString());
      }
    }
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(service.summary!.savedScanCount, 2);
  });

  testWidgets(
      'unclassifiable scans still show passport and explain insufficient DNA data',
      (tester) async {
    final service = FoodJourneyService(
        source: TestJourneySource()
          ..answer = (_, __) async =>
              FoodJourneyPage([foodScan('a', 'Mystery special')]));
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    await tester.pumpWidget(screenApp(service));
    await tester.pumpAndSettle();
    expect(find.text('0 classified scans'), findsOneWidget);
    expect(
        find.text('Not enough classifiable food records yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('stamp-JP')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Noodles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
