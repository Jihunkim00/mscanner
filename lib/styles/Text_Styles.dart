import 'package:flutter/material.dart';

class AppTextStyles {
  static const theme = TextTheme(
    headlineSmall:
        TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
    titleLarge:
        TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium:
        TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
    titleSmall:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall:
        TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
    labelMedium:
        TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
    labelSmall:
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.35),
  );

  static const TextStyle regular = TextStyle(
    fontFamily: 'SFPro',
    fontSize: 16,
  );

  static const TextStyle bold = TextStyle(
    fontFamily: 'SFPro',
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle italic = TextStyle(
    fontFamily: 'SFPro',
    fontSize: 16,
    fontStyle: FontStyle.italic,
  );

// 다른 스타일들을 여기에 추가할 수 있습니다.
}
