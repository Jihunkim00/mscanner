import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/features/food_journey/services/food_journey_repository.dart';
import 'package:mscanner/features/food_journey/services/food_journey_service.dart';
import 'package:mscanner/features/food_journey/widgets/food_journey_home_card.dart';
import 'package:mscanner/features/food_journey/screens/food_journey_screen.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'food_journey_service_test.dart' show TestJourneySource, foodScan;

Widget journeyApp(Widget child,
        {Locale locale = const Locale('en'),
        bool dark = false,
        double textScale = 1}) =>
    MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('one compact home card opens the passport and DNA detail route',
      (tester) async {
    final source = TestJourneySource()
      ..answer = (_, __) async => FoodJourneyPage([
            foodScan('a', 'Ramen'),
            foodScan('b', 'Sushi', country: 'KR'),
            foodScan('c', 'Rice', country: 'TH'),
            foodScan('d', 'Tea', country: 'VN')
          ]);
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    await tester.pumpWidget(journeyApp(FoodJourneyHomeCard(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('My Food Journey'), findsOneWidget);
    expect(find.text('4 countries'), findsOneWidget);
    final flagText = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.data?.contains('🇯🇵') ?? false)
        .single
        .data!;
    expect(flagText.contains('🇻🇳'), isFalse);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('food-journey-home-card')))
            .height,
        lessThanOrEqualTo(155));
    await tester.tap(find.text('My Food Journey'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodJourneyScreen), findsOneWidget);
    expect(find.text('My Food Passport'), findsOneWidget);
    expect(find.text('My Food DNA'), findsOneWidget);
    expect(source.requests, hasLength(1));
  });

  testWidgets('loading, initial error, retry and empty state', (tester) async {
    final completer = Completer<FoodJourneyPage>();
    final source = TestJourneySource()..answer = (_, __) => completer.future;
    final service = FoodJourneyService(source: source);
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    final request = service.load();
    await tester.pumpWidget(journeyApp(FoodJourneyHomeCard(service: service)));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    completer.completeError(StateError('offline'));
    await request;
    await tester.pumpAndSettle();
    expect(find.text('Could not load your journey'), findsOneWidget);
    source.answer = (_, __) async => const FoodJourneyPage([]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No records yet'), findsOneWidget);
    expect(find.text('Scan your first menu to begin your journey'),
        findsOneWidget);
    expect(source.requests, hasLength(2));
  });

  testWidgets(
      'home card supports every UI locale, dark mode, large text and narrow width',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = FoodJourneyService(
        source: TestJourneySource()
          ..answer =
              (_, __) async => FoodJourneyPage([foodScan('a', 'Ramen')]));
    addTearDown(service.dispose);
    service.selectAccount('alice', isPremium: false);
    await service.load();
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(journeyApp(FoodJourneyHomeCard(service: service),
          locale: locale, dark: true, textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: locale.toString());
    }
  });
}
