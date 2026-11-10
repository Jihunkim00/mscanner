import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/widgets/result/result_decision_skeleton.dart';

void main() {
  testWidgets('light and dark skeleton shimmer change rendered frames',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final boundaryKey = UniqueKey();
      final isDark = brightness == Brightness.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            backgroundColor: isDark ? Colors.black : const Color(0xFFF5F6F8),
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 340,
                  child: ResultDecisionSkeletonCard(
                    isDarkMode: isDark,
                    showResultListSkeleton: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final firstFrame = await _snapshot(tester, boundaryKey);
      await tester.pump(const Duration(milliseconds: 450));
      final secondFrame = await _snapshot(tester, boundaryKey);

      var largestPixelChange = 0;
      for (var index = 0; index < firstFrame.length; index++) {
        final delta = (firstFrame[index] - secondFrame[index]).abs();
        if (delta > largestPixelChange) largestPixelChange = delta;
      }
      expect(
        largestPixelChange,
        greaterThan(8),
        reason: '$brightness shimmer should visibly change between frames',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
  });
}

Future<List<int>> _snapshot(WidgetTester tester, Key boundaryKey) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: 1),
  );
  try {
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    return data!.buffer.asUint8List().toList(growable: false);
  } finally {
    image!.dispose();
  }
}
