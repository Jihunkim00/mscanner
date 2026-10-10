import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/widgets/adaptive_window.dart';
import 'package:mscanner/widgets/file_thumbnail.dart';
import 'package:mscanner/widgets/image_grid_viewer.dart';
import 'package:mscanner/widgets/result/result_decision_cards.dart';

void main() {
  testWidgets(
      'product action wraps with text scale and still calls only the payment double',
      (tester) async {
    var payments = 0;
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [700.0, 260.0, 360.0]) {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(900, 500), textScaler: TextScaler.linear(2)),
            child: Directionality(
                textDirection: TextDirection.rtl, child: child!)),
        home: Scaffold(
            body: Center(
                child: SizedBox(
          width: width,
          child: SingleChildScrollView(
              child: AdaptiveActionRow(
            content: const Text('Premium subscription and product description'),
            action: ElevatedButton(
                onPressed: () => payments++,
                child: const Text('1,234.56 USD / month')),
          )),
        ))),
      ));
      await tester.tap(find.byType(ElevatedButton));
      expect(tester.takeException(), isNull);
    }
    expect(payments, 3);
  });

  testWidgets(
      'multi-scan grid measures its pane and all selections remain reachable',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files =
        List.generate(4, (i) => File('test-missing-thumbnail-$i.png'));
    var selected = -1;
    for (final width in [240.0, 600.0, 320.0]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
        child: SizedBox(
            width: width,
            child: ImageGridViewer(
                images: files, onTap: (index) => selected = index)),
      ))));
      final grid = tester.getRect(find.byType(ImageGridViewer));
      for (final element in find.byType(FileThumbnail).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.width, greaterThan(0));
        expect(rect.left, greaterThanOrEqualTo(grid.left));
        expect(rect.right, lessThanOrEqualTo(grid.right + 0.01));
      }
      await tester.tap(find.byType(FileThumbnail).last);
      expect(selected, 3);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'real result summary exposes price and local insight actions at large RTL scale',
      (tester) async {
    var prices = 0;
    var insights = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 300), textScaler: TextScaler.linear(2)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: ResultDecisionCards(
        isDarkMode: false,
        title: 'Menu translation',
        originalTitle: 'Original menu',
        priceLabel: '1,234.56 USD',
        tags: const ['vegetarian', 'gluten_free'],
        localInsights: const ['Nearby food review'],
        decisionReason: 'Suitable menu',
        onPriceTap: () => prices++,
        onLocalInsightTap: () => insights++,
      ))),
    ));
    await tester.ensureVisible(find.text('1,234.56 USD'));
    await tester.tap(find.text('1,234.56 USD'));
    await tester.ensureVisible(find.text('• Nearby food review'));
    await tester.tap(find.text('• Nearby food review'));
    expect(prices, 1);
    expect(insights, 1);
    expect(tester.takeException(), isNull);
  });
}
