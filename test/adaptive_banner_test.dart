import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mscanner/widgets/adaptive_banner.dart';

void main() {
  testWidgets(
    'safe content width and orientation are debounced on one mounted banner',
    (tester) async {
      final factory = _Factory();
      Widget screen(Size size, {bool enabled = true}) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        return MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(left: 20, right: 30),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: AdaptiveBanner(
                  enabled: enabled,
                  adUnitId: 'test-only',
                  factory: factory,
                ),
              ),
            ),
          ),
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen(const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(factory.specs, [const BannerSpec(320, Orientation.portrait)]);
      final first = factory.handles.single;
      first.loaded.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('banner 0'), findsOneWidget);
      for (final width in [600.0, 700.0, 800.0]) {
        await tester.pumpWidget(screen(Size(width, 390)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(factory.specs, hasLength(1));
      expect(first.disposals, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(factory.specs.last, const BannerSpec(730, Orientation.landscape));
      expect(factory.handles, hasLength(2));
      factory.handles.last.loaded.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('banner 1'), findsOneWidget);
      // Entitlement change immediately removes and disposes the banner.
      await tester.pumpWidget(screen(const Size(800, 390), enabled: false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('banner 1'), findsNothing);
      expect(factory.handles.last.disposals, 1);
      expect(factory.specs, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late load/failure and dispose cannot overwrite a newer request',
    (tester) async {
      final factory = _Factory();
      Widget banner(double width) => MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                child: AdaptiveBanner(
                  enabled: true,
                  adUnitId: 'test-only',
                  factory: factory,
                ),
              ),
            ),
          );
      await tester.pumpWidget(banner(300));
      await tester.pump(const Duration(milliseconds: 400));
      final stale = factory.handles.single;
      await tester.pumpWidget(banner(500));
      await tester.pump(const Duration(milliseconds: 400));
      final fresh = factory.handles.last;
      expect(stale.disposals, 1);
      fresh.loaded.complete();
      await tester.pump();
      stale.loaded.complete();
      await tester.pump();
      expect(find.text('banner 1'), findsOneWidget);
      expect(find.text('banner 0'), findsNothing);
      expect(stale.disposals, 1);
      await tester.pumpWidget(banner(600));
      await tester.pump(const Duration(milliseconds: 400));
      final removed = factory.handles.last;
      await tester.pumpWidget(const SizedBox());
      removed.loaded.completeError(StateError('late SDK callback'));
      await tester.pump();
      expect(removed.disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an obsolete size future never creates an ad', (tester) async {
    final factory = _Factory()..delayedSize = Completer<AdSize?>();
    Widget banner(double width) => MaterialApp(
          home: SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: AdaptiveBanner(
                  enabled: true,
                  adUnitId: 'test-only',
                  factory: factory,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(banner(300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(banner(500));
    factory.delayedSize!.complete(const AdSize(width: 300, height: 50));
    await tester.pump();
    expect(factory.handles, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

class _Factory implements AdaptiveBannerFactory {
  final specs = <BannerSpec>[];
  final handles = <_Handle>[];
  Completer<AdSize?>? delayedSize;
  @override
  Future<AdSize?> sizeFor(BannerSpec spec) {
    specs.add(spec);
    return delayedSize?.future ??
        Future.value(AdSize(width: spec.width, height: 50));
  }

  @override
  AdaptiveBannerHandle create(AdSize size, String adUnitId) {
    final handle = _Handle(size, handles.length);
    handles.add(handle);
    return handle;
  }
}

class _Handle implements AdaptiveBannerHandle {
  _Handle(this.size, this.id);
  @override
  final AdSize size;
  final int id;
  final loaded = Completer<void>();
  var disposals = 0;
  @override
  Widget get view => Text('banner $id');
  @override
  Future<void> load() => loaded.future;
  @override
  void dispose() => disposals++;
}
