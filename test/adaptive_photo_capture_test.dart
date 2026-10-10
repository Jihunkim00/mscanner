import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mscanner/widgets/photo_capture_widget.dart';

void main() {
  for (final multi in [false, true]) {
    testWidgets(
      'system ${multi ? 'gallery' : 'camera'} opens once across resize and app return',
      (tester) async {
        final picker = _Picker();
        final key = GlobalKey();
        var captures = 0;
        var cancels = 0;
        List<File>? selected;
        Widget screen(Size size) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          return MaterialApp(
            home: Scaffold(
              body: PhotoCaptureWidget(
                key: key,
                isMulti: multi,
                picker: picker,
                onCaptured: (files) {
                  captures++;
                  selected = files;
                },
                onCancel: () => cancels++,
              ),
            ),
          );
        }

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(screen(const Size(390, 844)));
        final original = key.currentState;
        for (final size in [
          const Size(1100, 800),
          const Size(844, 300),
          const Size(320, 700),
        ]) {
          await tester.pumpWidget(screen(size));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(key.currentState, same(original));
          expect(picker.calls, 1);
        }
        final dir = Directory.systemTemp.createTempSync('pr18-picker-');
        addTearDown(() {
          for (final entry in dir.listSync()) {
            entry.deleteSync();
          }
          dir.deleteSync();
        });
        final file = File('${dir.path}/photo.png')
          ..writeAsBytesSync(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jfusAAAAASUVORK5CYII=',
            ),
          );
        if (multi) {
          picker.multiple.complete([XFile(file.path), XFile(file.path)]);
        } else {
          picker.single.complete(XFile(file.path));
        }
        await tester.pump();
        expect(captures, 1);
        expect(cancels, 0);
        expect(selected, hasLength(multi ? 2 : 1));
        await tester.pumpWidget(screen(const Size(1100, 800)));
        await tester.pump();
        expect(picker.calls, 1);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a picker result after leaving the screen cannot navigate', (
    tester,
  ) async {
    final picker = _Picker();
    var callbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoCaptureWidget(
            picker: picker,
            onCaptured: (_) => callbacks++,
            onCancel: () => callbacks++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    picker.single.complete(null);
    await tester.pump();
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });
}

class _Picker extends ImagePicker {
  var calls = 0;
  final single = Completer<XFile?>();
  final multiple = Completer<List<XFile>>();
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls++;
    return single.future;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) {
    calls++;
    return multiple.future;
  }
}
