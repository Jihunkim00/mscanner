import 'dart:io';
import 'package:flutter/material.dart';

/// Bounds the menu preview while leaving the original file available to the viewer.
class ScanImagePreview extends StatelessWidget {
  const ScanImagePreview({super.key, required this.image});
  final File image;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final window = MediaQuery.sizeOf(context);
          final isLargePanel =
              window.shortestSide >= 600 && constraints.maxWidth >= 360;
          final height = isLargePanel
              ? (window.height * 0.4).clamp(240.0, 360.0)
              : (window.height * 0.3).clamp(180.0, 260.0);
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child:
                  Image.file(image, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          );
        },
      );
}
