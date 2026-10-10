import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/widgets/adaptive_window.dart';
import 'package:mscanner/widgets/premium_ad_overlay.dart';

void main() {
  testWidgets(
    'premium CTA and close remain accessible in short RTL and folded windows',
    (tester) async {
      final image = MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jfusAAAAASUVORK5CYII=',
        ),
      );
      var purchaseRequests = 0; // Payment test double, no store request.
      var closes = 0;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (size, features) in [
        (const Size(650, 250), <ui.DisplayFeature>[]),
        (const Size(320, 500), <ui.DisplayFeature>[]),
        (
          const Size(390, 844),
          [
            ui.DisplayFeature(
              bounds: const Rect.fromLTWH(0, 410, 390, 24),
              type: ui.DisplayFeatureType.fold,
              state: ui.DisplayFeatureState.postureHalfOpened,
            ),
          ],
        ),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                displayFeatures: features,
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: AdaptivePage(
              child: Scaffold(
                body: SafeArea(
                  child: PremiumAdOverlay(
                    image: image,
                    locale: const Locale('ar'),
                    adFreePrice: '0.49',
                    premiumMonthlyPrice: '0.49',
                    onPrimaryTap: () => purchaseRequests++,
                    onClose: () => closes++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.ensureVisible(find.byType(ElevatedButton));
        await tester.tap(find.byType(ElevatedButton));
        await tester.tap(find.byIcon(Icons.close));
        expect(tester.takeException(), isNull);
      }
      expect(purchaseRequests, 3);
      expect(closes, 3);
    },
  );

  testWidgets(
    'popup button scrolls above keyboard inside selected fold region',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const hinge = Rect.fromLTWH(0, 410, 390, 24);
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              viewInsets: const EdgeInsets.only(bottom: 160),
              displayFeatures: [
                ui.DisplayFeature(
                  bounds: hinge,
                  type: ui.DisplayFeatureType.fold,
                  state: ui.DisplayFeatureState.postureHalfOpened,
                ),
              ],
            ),
            child: child!,
          ),
          home: Material(
            child: AdaptiveModalSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 700, child: Text('popup explanation')),
                  ElevatedButton(
                    onPressed: () => presses++,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Continue'));
      expect(tester.getRect(find.text('Continue')).overlaps(hinge), false);
      expect(
        tester.getRect(find.text('Continue')).bottom,
        lessThanOrEqualTo(684),
      );
      await tester.tap(find.text('Continue'));
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
