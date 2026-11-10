import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Bounds the menu preview while leaving the original file available to the viewer.
class ScanImagePreview extends StatelessWidget {
  const ScanImagePreview({super.key, required this.image, this.overlay});
  final File image;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final window = MediaQuery.sizeOf(context);
          final height = (window.height * 0.48).clamp(220.0, 520.0);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF121215) : const Color(0xFFE6E8EB);
          return SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: backgroundColor),
                RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Transform.scale(
                      scale: 1.12,
                      child: Image.file(
                        image,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                ColoredBox(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
                ),
                Center(
                  child: Image.file(
                    key: const ValueKey('scan-image-preview-original'),
                    image,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 112,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99000000),
                            Color(0x44000000),
                            Color(0x00000000),
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                if (overlay != null) Positioned.fill(child: overlay!),
              ],
            ),
          );
        },
      );
}
