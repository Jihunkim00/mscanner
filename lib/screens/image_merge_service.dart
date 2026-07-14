import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart';

class ImageMergeService {
  static Future<Uint8List> mergeAndCompress(
      List<Uint8List> imageBytesList) async {
    // 1) 바이트 리스트를 Image 객체로 디코딩
    final images = imageBytesList.map((b) => decodeImage(b)!).toList();
    final count = images.length;

    // 1장뿐이면 그대로 반환
    if (count == 1) return imageBytesList[0];

    // 2) 셀 크기 결정: 최대 너비 × 최대 높이
    final cellW = images.map((i) => i.width).reduce(max);
    final cellH = images.map((i) => i.height).reduce(max);

    // 3) 비율 유지 중앙 크롭
    final fitted = images.map((src) => _fitAndCrop(src, cellW, cellH)).toList();

    // 4) 그리드(column, row) 계산
    final cols = (count == 2) ? 1 : 2;
    final rows = (count == 2) ? 2 : ((count + 1) ~/ 2);

    // 5) 빈 캔버스 생성 (named parameters)
    final merged = Image(width: cellW * cols, height: cellH * rows);

    // 6) 각 셀에 compositeImage 로 붙여넣기
    for (int i = 0; i < count; i++) {
      final x = (i % cols) * cellW;
      final y = (i ~/ cols) * cellH;
      compositeImage(merged, fitted[i], dstX: x, dstY: y);
    }

    // 7) JPEG 압축 후 반환
    return Uint8List.fromList(encodeJpg(merged, quality: 50));
  }

  /// 비율 유지(resize) → 중앙 크롭(crop)
  static Image _fitAndCrop(Image src, int targetW, int targetH) {
    // a) 필요한 축을 모두 덮도록 스케일 계산
    final scale = max(targetW / src.width, targetH / src.height);

    // b) copyResize: named width/height
    final resized = copyResize(
      src,
      width: (src.width * scale).round(),
      height: (src.height * scale).round(),
    );

    // c) copyCrop: named x/y/width/height
    final offsetX = (resized.width - targetW) ~/ 2;
    final offsetY = (resized.height - targetH) ~/ 2;
    return copyCrop(
      resized,
      x: offsetX,
      y: offsetY,
      width: targetW,
      height: targetH,
    );
  }
}
