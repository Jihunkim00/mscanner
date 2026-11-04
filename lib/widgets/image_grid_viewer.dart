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

  /// Result previews opt in; the default wrapping grid stays unchanged.
  final bool compact;
  final int? selectedIndex;

  const ImageGridViewer({
    super.key,
    required this.images,
    required this.onTap,
    this.compact = false,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    if (compact) {
      if (images.length == 1) return const SizedBox.shrink();
      const size = 72.0;
      final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return SizedBox(
        height: size,
        child: ListView.separated(
          primary: false,
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => Semantics(
            button: true,
            selected: selectedIndex == index,
            // Index and count remain language-independent for the thumbnail control.
            label: '${index + 1} / ${images.length}',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(index),
                child: Container(
                  key: ValueKey('scan-thumbnail-$index'),
                  width: size,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selectedIndex == index
                            ? const Color(0xFFFF7A45)
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: ExcludeSemantics(
                    child: FileThumbnail(
                        file: images[index], size: size, cacheSize: cacheSize),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
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
