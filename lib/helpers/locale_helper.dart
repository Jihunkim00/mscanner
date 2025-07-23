// helpers/locale_helper.dart

import 'package:flutter/material.dart';

/// Parses a locale string and returns a [Locale] object.
///
/// The [localeString] should be in the format:
/// - 'en'
/// - 'pt_BR'
/// - 'zh_Hant'
/// - 'zh_Hans'
///
/// Returns null if the [localeString] is null or empty.
Locale? parseLocale(String? localeString) {
  if (localeString == null || localeString.isEmpty) return null;

  final parts = localeString.split('_');

  if (parts.length == 1) {
    // 언어 코드만 있는 경우
    return Locale(parts[0]);
  } else if (parts.length == 2) {
    // 언어 코드와 국가 코드 또는 스크립트 코드가 있는 경우
    final languageCode = parts[0];
    final secondPart = parts[1];

    // 스크립트 코드인지 국가 코드인지 확인
    if (secondPart.length == 4) { // 스크립트 코드는 보통 4글자
      return Locale.fromSubtags(
        languageCode: languageCode,
        scriptCode: secondPart,
      );
    } else {
      return Locale(languageCode, secondPart);
    }
  } else if (parts.length == 3) {
    // 언어 코드, 스크립트 코드, 국가 코드가 있는 경우
    return Locale.fromSubtags(
      languageCode: parts[0],
      scriptCode: parts[1],
      countryCode: parts[2],
    );
  } else {
    // 지원하지 않는 형식
    return null;
  }
}
