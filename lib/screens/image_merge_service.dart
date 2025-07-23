import 'dart:typed_data';
import 'package:image/image.dart';

class ImageMergeService {
  static Future<Uint8List> mergeAndCompress(List<Uint8List> imageBytesList) async {
    final images = imageBytesList.map((bytes) => decodeImage(bytes)!).toList();
    final count = images.length;

    if (count == 1) {
      return imageBytesList[0];
    }

    if (count == 2) {
      final width = images.map((i) => i.width).reduce((a, b) => a > b ? a : b);
      final height = images.fold(0, (sum, i) => sum + i.height);
      final merged = Image(width: width, height: height);

      int yOffset = 0;
      for (final img in images) {
        compositeImage(merged, img, dstY: yOffset);
        yOffset += img.height;
      }
      return Uint8List.fromList(encodeJpg(merged, quality: 50));
    }

    // 3장 또는 4장: 2x2 격자
    final cellW = images.map((i) => i.width).reduce((a, b) => a > b ? a : b);
    final cellH = images.map((i) => i.height).reduce((a, b) => a > b ? a : b);
    final merged = Image(width: cellW * 2, height: cellH * 2);

    for (int i = 0; i < count; i++) {
      final x = (i % 2) * cellW;
      final y = (i ~/ 2) * cellH;
      compositeImage(merged, images[i], dstX: x, dstY: y);
    }

    // count == 3일 때엔 빈 공간을 따로 채우지 않고 그대로 둠

    return Uint8List.fromList(encodeJpg(merged, quality: 50));
  }
}
