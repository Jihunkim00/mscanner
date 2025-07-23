// file_thumbnail.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FileThumbnail extends StatelessWidget {
  final File file;
  final double size;
  final int cacheSize;

  const FileThumbnail({
    Key? key,
    required this.file,
    required this.size,
    required this.cacheSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // FileImage를 ResizeImage로 감싸서 cacheSize만큼만 디코딩하도록 합니다.
    final provider = ResizeImage(
      FileImage(file),
      width: cacheSize,
      height: cacheSize,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (ctx, child, frame, _) {
          if (frame != null) {

                  return child;
                }

          return Container(
            width: size,
            height: size,
            color: Theme.of(ctx).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(child: CupertinoActivityIndicator(radius: 10)),
          );
        },
        errorBuilder: (ctx, _, __) => Container(
          width: size,
          height: size,
          color: Colors.grey,
          child: Icon(Icons.error, color: Colors.red),
        ),
      ),
    );
  }
}
