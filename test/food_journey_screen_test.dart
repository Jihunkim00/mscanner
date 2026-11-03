import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/services/food_journey_repository.dart';
import 'package:mscanner/features/food_journey/services/food_journey_service.dart';
import 'package:mscanner/features/food_journey/screens/food_journey_screen.dart';
import 'package:mscanner/features/food_journey/widgets/food_journey_sections.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'food_journey_service_test.dart' show TestJourneySource, foodScan;

Widget screenApp(FoodJourneyService service,
        {Locale locale = const Locale('en'), double scale = 1}) =>
    MaterialApp(
        theme: ThemeData.dark(),
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
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(screenApp(service, locale: locale, scale: 2));
      await tester.pumpAndSettle();
      if (locale.languageCode == 'ar') {
        expect(
            Directionality.of(tester.element(find.byType(FoodPassportSection))),
            TextDirection.rtl);
      }
      expect(tester.takeException(), isNull, reason: locale.toString());
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
    expect(find.byType(LinearProgressIndicator), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });
}
