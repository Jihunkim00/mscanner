import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/widgets/adaptive_scan_panels.dart';

ui.DisplayFeature fold(Rect bounds) => ui.DisplayFeature(
      bounds: bounds,
      type: ui.DisplayFeatureType.fold,
      state: ui.DisplayFeatureState.postureHalfOpened,
    );

void main() {
  testWidgets('image scroll is restored when its independent viewport returns',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = ScanCaptureController();
    Widget screen(Size size) {
      tester.view.physicalSize = size;
      return MaterialApp(
          home: Scaffold(
              body: AdaptiveScanPanels(
        capture: capture,
        primary: const Column(children: [
          SizedBox(height: 1000),
          Text('photo tail'),
        ]),
        results: const SizedBox(height: 1500, child: Text('result body')),
      )));
    }

    ScrollPosition imagePosition() =>
        Scrollable.of(tester.element(find.text('photo tail'))).position;
    await tester.pumpWidget(screen(const Size(1000, 600)));
    await tester.pump();
    imagePosition().jumpTo(300);
    await tester.pump();
    await tester.pumpWidget(screen(const Size(390, 844)));
    await tester.pump();
    await tester.pumpWidget(screen(const Size(1000, 600)));
    await tester.pump();
    expect(imagePosition().pixels, 300);
    expect(tester.takeException(), isNull);
  });

  test('geometry uses usable dimensions, scaling and supplied fold bounds', () {
    ScanPanelGeometry layout(
      Size size, {
      List<ui.DisplayFeature> features = const [],
      double scale = 1,
    }) =>
        ScanPanelGeometry.resolve(
          bounds: Offset.zero & size,
          media: MediaQueryData(
            size: size,
            displayFeatures: features,
            textScaler: TextScaler.linear(scale),
          ),
        );
    expect(layout(const Size(390, 844)).mode, ScanPanelMode.stacked);
    expect(layout(const Size(1100, 800)).mode, ScanPanelMode.sideBySide);
    expect(layout(const Size(1000, 200)).mode, ScanPanelMode.stacked);
    expect(layout(const Size(650, 900)).mode, ScanPanelMode.stacked);
    expect(layout(const Size(850, 600), scale: 2).mode, ScanPanelMode.stacked);
    final vertical = layout(
      const Size(1100, 800),
      features: [fold(const Rect.fromLTWH(540, 0, 20, 800))],
    );
    expect(vertical.mode, ScanPanelMode.sideBySide);
    expect(vertical.primary.right, 540);
    expect(vertical.results!.left, 560);
    final horizontal = layout(
      const Size(390, 844),
      features: [fold(const Rect.fromLTWH(0, 410, 390, 24))],
    );
    expect(horizontal.mode, ScanPanelMode.horizontalFold);
    expect(horizontal.primary.bottom, 410);
    expect(horizontal.results!.top, 434);
    final tooSmall = layout(
      const Size(650, 900),
      features: [fold(const Rect.fromLTWH(310, 0, 30, 900))],
    );
    expect(tooSmall.mode, ScanPanelMode.stacked);
    expect(
      tooSmall.primary.overlaps(const Rect.fromLTWH(310, 0, 30, 900)),
      false,
    );
    // A zero-width flat crease is not an obstruction; posture half-open is.
    final flat = ui.DisplayFeature(
      bounds: const Rect.fromLTWH(550, 0, 0, 800),
      type: ui.DisplayFeatureType.fold,
      state: ui.DisplayFeatureState.postureFlat,
    );
    expect(
      layout(const Size(1100, 800), features: [flat]).results!.left,
      lessThan(550),
    );
  });

  testWidgets(
    'same result controls, selection and scroll survive consecutive transitions',
    (tester) async {
      final capture = ScanCaptureController();
      final editorKey = GlobalKey<_EditorState>();
      var starts = 0;
      Widget screen(
        Size size, {
        List<ui.DisplayFeature> features = const [],
        double scale = 1,
        TextDirection direction = TextDirection.ltr,
        EdgeInsets insets = EdgeInsets.zero,
      }) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        return MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              displayFeatures: features,
              textScaler: TextScaler.linear(scale),
              viewInsets: insets,
              padding: const EdgeInsets.only(left: 12, right: 18),
            ),
            child: Directionality(textDirection: direction, child: child!),
          ),
          home: Scaffold(
            appBar: AppBar(),
            body: AdaptiveScanPanels(
              capture: capture,
              primary: const SizedBox(height: 130, child: Text('menu photo')),
              results: _Editor(key: editorKey, onStart: () => starts++),
            ),
          ),
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen(const Size(390, 844)));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'keep this review');
      editorKey.currentState!.setSelected(3);
      await tester.pump();
      final original = editorKey.currentState;
      ScrollPosition position() =>
          Scrollable.of(tester.element(find.byType(TextField))).position;
      position().jumpTo(100);
      await tester.pump();
      final transitions = [
        (const Size(1100, 800), <ui.DisplayFeature>[]),
        (const Size(960, 320), <ui.DisplayFeature>[]),
        (const Size(320, 700), <ui.DisplayFeature>[]),
        (const Size(1100, 800), [fold(const Rect.fromLTWH(540, 0, 20, 800))]),
        (const Size(390, 844), [fold(const Rect.fromLTWH(0, 410, 390, 24))]),
        (const Size(390, 844), <ui.DisplayFeature>[]),
      ];
      for (final (size, features) in transitions) {
        await tester.pumpWidget(screen(size, features: features));
        await tester.pump();
        expect(editorKey.currentState, same(original));
        expect(editorKey.currentState!.controller.text, 'keep this review');
        expect(editorKey.currentState!.selected, 3);
        expect(position().pixels, 100);
        expect(starts, 1);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        screen(
          const Size(390, 500),
          scale: 2,
          direction: TextDirection.rtl,
          insets: const EdgeInsets.only(bottom: 180),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Save review'));
      await tester.tap(find.text('Save review'));
      expect(original!.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'both panels stay clear of hinges including AppBar and safe offsets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final capture = ScanCaptureController();
      const image = ValueKey('image');
      const result = ValueKey('result');
      for (final (size, feature) in [
        (const Size(1100, 800), fold(const Rect.fromLTWH(540, 0, 20, 800))),
        (const Size(390, 844), fold(const Rect.fromLTWH(0, 410, 390, 24))),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.fromLTRB(12, 30, 18, 20),
                displayFeatures: [feature],
              ),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(),
              body: AdaptiveScanPanels(
                capture: capture,
                primary: const SizedBox(
                  key: image,
                  height: 100,
                  child: Text('image'),
                ),
                results: const SizedBox(
                  key: result,
                  height: 100,
                  child: Text('result'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.getRect(find.byKey(image)).overlaps(feature.bounds),
          false,
        );
        expect(
          tester.getRect(find.byKey(result)).overlaps(feature.bounds),
          false,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'share bitmap contains offscreen bottom content from both panels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final capture = ScanCaptureController();
      for (final size in [const Size(390, 400), const Size(1100, 600)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdaptiveScanPanels(
                capture: capture,
                primary: const SizedBox(
                  height: 200,
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
                results: const Column(
                  children: [
                    SizedBox(
                      height: 1400,
                      child: ColoredBox(color: Colors.green),
                    ),
                    SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: ColoredBox(color: Color(0xFF0000FF)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final future = capture.capture(pixelRatio: 1);
        await tester.pump();
        final image = await tester.runAsync(() => future);
        expect(image, isNotNull);
        expect(image!.height, 1716);
        final data = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final bytes = data!.buffer.asUint8List();
        List<int> pixel(int x, int y) => bytes.sublist(
              (y * image.width + x) * 4,
              (y * image.width + x) * 4 + 4,
            );
        expect(pixel(10, 10), [255, 0, 0, 255]);
        expect(pixel(10, image.height - 10), [0, 0, 255, 255]);
        image.dispose();
        expect(tester.takeException(), isNull);
      }
    },
  );
}

class _Editor extends StatefulWidget {
  const _Editor({super.key, required this.onStart});
  final VoidCallback onStart;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final controller = TextEditingController();
  var selected = 1;
  var saves = 0;
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  void setSelected(int value) => setState(() => selected = value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('Selected menu $selected'),
          TextField(controller: controller),
          const SizedBox(height: 1000),
          ElevatedButton(
            onPressed: () => saves++,
            child: const Text('Save review'),
          ),
        ],
      );
}
