import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/Loading_Screen.dart';

void main() {
  testWidgets(
    'resizing actual loading screen preserves progress and starts one analysis',
    (tester) async {
      final pending = Completer<void>();
      var requests = 0;
      final key = GlobalKey();
      Future<void> request() {
        requests++;
        return pending.future;
      }

      Widget screen(
        Size size, {
        List<ui.DisplayFeature> features = const [],
        double scale = 1,
      }) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              displayFeatures: features,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: LoadingScreen(
            key: key,
            image: File('unused-test-image'),
            captureTime: DateTime(2026),
            analysisTask: request,
          ),
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen(const Size(390, 844)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));
      final original = key.currentState;
      final loc = AppLocalizations.of(
        tester.element(find.byType(LoadingScreen)),
      )!;
      expect(find.text(loc.loadingAnalyzing), findsOneWidget);
      for (final (size, features) in [
        (const Size(1100, 800), <ui.DisplayFeature>[]),
        (const Size(844, 260), <ui.DisplayFeature>[]),
        (const Size(320, 700), <ui.DisplayFeature>[]),
        (
          const Size(1100, 800),
          [
            ui.DisplayFeature(
              bounds: const Rect.fromLTWH(540, 0, 20, 800),
              type: ui.DisplayFeatureType.hinge,
              state: ui.DisplayFeatureState.unknown,
            ),
          ],
        ),
        (
          const Size(390, 844),
          [
            ui.DisplayFeature(
              bounds: const Rect.fromLTWH(0, 410, 390, 0),
              type: ui.DisplayFeatureType.fold,
              state: ui.DisplayFeatureState.postureHalfOpened,
            ),
          ],
        ),
      ]) {
        await tester.pumpWidget(screen(size, features: features, scale: 2));
        await tester.pump();
        expect(key.currentState, same(original));
        expect(requests, 1);
        expect(find.text(loc.loadingAnalyzing), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      pending.complete();
      await tester.pump();
      expect(requests, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
