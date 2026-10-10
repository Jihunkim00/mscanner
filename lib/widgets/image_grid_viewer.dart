// lib/widgets/image_grid_viewer.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'file_thumbnail.dart';

/// A reusable grid widget that displays image thumbnails and handles taps.
class ImageGridViewer extends StatelessWidget {
  /// List of image files to display.
  final List<File> images;

  /// Callback when a thumbnail is tapped. Provides the index.
  final void Function(int index) onTap;

  const ImageGridViewer({
    super.key,
    required this.images,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final columns =
          (constraints.maxWidth / 100).floor().clamp(1, images.length);
      final spacing = 8.0 * (columns - 1);
      final itemWidth = (constraints.maxWidth - spacing) / columns;
      final cacheSize =
          (itemWidth * MediaQuery.devicePixelRatioOf(context)).round();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
            images.length,
            (index) => GestureDetector(
                  onTap: () => onTap(index),
                  child: FileThumbnail(
                      file: images[index],
                      size: itemWidth,
                      cacheSize: cacheSize),
                )),
      );
    });
  }
}
