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
    Key? key,
    required this.images,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine grid layout
    final count = images.length;
    final columns = count < 4 ? count : 4;
    final totalPad = 16.0 * 2;
    final spacing = 8.0 * (columns - 1);
    final itemWidth = (MediaQuery.of(context).size.width - totalPad - spacing) / columns;

    // Calculate cache size based on devicePixelRatio
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (itemWidth * dpr).round();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(images.length, (i) {
        return GestureDetector(
          onTap: () => onTap(i),
          child: FileThumbnail(
            file: images[i],
            size: itemWidth,
            cacheSize: cacheSize,
          ),
        );
      }),
    );
  }
}
