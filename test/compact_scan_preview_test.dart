import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mscanner/widgets/adaptive_scan_panels.dart';
import 'package:mscanner/widgets/file_thumbnail.dart';
import 'package:mscanner/widgets/image_grid_viewer.dart';
import 'package:mscanner/widgets/result/scan_image_preview.dart';

void main() {
  late Directory directory;
  late List<File> files;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('mscanner-preview-');
    files = List.generate(12, (index) {
      final image = img.Image(
          width: index.isEven ? 60 : 200, height: index.isEven ? 200 : 60);
      img.fill(image, color: img.ColorRgb8(255, index * 15, 0));
      return File('${directory.path}/menu-$index.png')
        ..writeAsBytesSync(img.encodePng(image));
    });
  });
  tearDown(() {
    for (final file in files) {
      file.deleteSync();
    }
    directory.deleteSync();
  });

  Future<void> loadImages(WidgetTester tester) async {
    // Warm file providers outside the fake clock before any Image starts an I/O load.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    await tester.runAsync(() async {
      await Future.wait([
        for (final file in files) ...[
          precacheImage(FileImage(file), context),
          precacheImage(
              ResizeImage(FileImage(file), width: 72, height: 72), context),
        ],
      ]).timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('portrait and landscape menu previews remain bounded on resize',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await loadImages(tester);
    for (final (size, expectedHeight) in [
      (const Size(320, 568), 180.0),
      (const Size(390, 844), 253.2),
      (const Size(430, 932), 260.0),
      (const Size(1100, 800), 320.0),
      (const Size(844, 390), 180.0),
    ]) {
      tester.view.physicalSize = size;
      for (final file in files.take(2)) {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: AdaptiveScanPanels(
                    capture: ScanCaptureController(),
                    primary: ScanImagePreview(image: file),
                    results: const Text('First recommendation')))));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(ScanImagePreview)).height,
            closeTo(expectedHeight, 0.01));
        final image = tester.widget<Image>(find.descendant(
            of: find.byType(ScanImagePreview), matching: find.byType(Image)));
        expect(image.fit, BoxFit.contain);
        expect(tester.getBottomLeft(find.text('First recommendation')).dy,
            lessThan(size.height));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('one thumbnail row scrolls, selects and exports both panels',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await loadImages(tester);
    final capture = ScanCaptureController();
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      return AdaptiveScanPanels(
          capture: capture,
          primary: Column(children: [
            ScanImagePreview(image: files[selected]),
            const SizedBox(height: 8),
            ImageGridViewer(
                images: files,
                compact: true,
                selectedIndex: selected,
                onTap: (index) => setState(() => selected = index)),
          ]),
          results: const Column(children: [
            Text('First recommendation'),
            SizedBox(height: 1200),
            SizedBox(
                height: 50,
                width: double.infinity,
                child: ColoredBox(color: Color(0xFF0000FF))),
          ]));
    }))));
    await tester.pumpAndSettle();
    final strip = find.byType(ImageGridViewer);
    expect(tester.getSize(strip).height, 72);
    expect(tester.getBottomLeft(find.text('First recommendation')).dy,
        lessThan(844));
    final first =
        tester.getRect(find.byKey(const ValueKey('scan-thumbnail-0')));
    final second =
        tester.getRect(find.byKey(const ValueKey('scan-thumbnail-1')));
    expect(first.size, const Size(72, 72));
    expect(second.top, first.top);
    expect(second.left - first.right, 8);
    final horizontal =
        find.descendant(of: strip, matching: find.byType(ListView));
    await tester.drag(horizontal, const Offset(-500, 0));
    await tester.pumpAndSettle();
    final reachable = find.byType(FileThumbnail).hitTestable().last;
    await tester.tap(reachable);
    await tester.pumpAndSettle();
    expect(selected, greaterThan(0));
    final preview =
        tester.widget<ScanImagePreview>(find.byType(ScanImagePreview));
    expect(preview.image.path, files[selected].path);
    final selectedBox = tester
        .widget<Container>(find.byKey(ValueKey('scan-thumbnail-$selected')));
    final border =
        (selectedBox.foregroundDecoration! as BoxDecoration).border! as Border;
    expect(border.top.color, const Color(0xFFFF7A45));

    final future = capture.capture(pixelRatio: 1);
    await tester.pump();
    final bitmap = await tester.runAsync(() => future);
    expect(bitmap, isNotNull);
    expect(bitmap!.height, greaterThan(1500));
    final data = await tester
        .runAsync(() => bitmap.toByteData(format: ui.ImageByteFormat.rawRgba));
    final bytes = data!.buffer.asUint8List();
    final offset = ((bitmap.height - 10) * bitmap.width + 10) * 4;
    expect(bytes.sublist(offset, offset + 4), [0, 0, 255, 255]);
    bitmap.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact strip hides a single image in RTL with enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await loadImages(tester);
    var selected = -1;
    Widget strip(List<File> images) => MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: Directionality(
                textDirection: TextDirection.rtl, child: child!)),
        home: Scaffold(
            body: ImageGridViewer(
                images: images,
                compact: true,
                onTap: (index) => selected = index)));
    await tester.pumpWidget(strip(files.take(1).toList()));
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(FileThumbnail), findsNothing);
    await tester.pumpWidget(strip(files));
    await tester.pump();
    final first = find.byKey(const ValueKey('scan-thumbnail-0'));
    expect(tester.getRect(first).right, 280);
    await tester.tap(first);
    expect(selected, 0);
    expect(tester.takeException(), isNull);
  });
}
