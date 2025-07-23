import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageHelper {
  static const String _languageCodeKey = 'languageCode';
  static const String _countryCodeKey = 'countryCode';

  /// 사용자 선택 언어를 저장합니다.
  static Future<void> saveLanguageCode(Locale locale) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, locale.languageCode);
    if (locale.countryCode != null) {
      await prefs.setString(_countryCodeKey, locale.countryCode!);
    } else {
      await prefs.remove(_countryCodeKey);
    }
  }

  /// 저장된 언어를 불러옵니다. 없으면 null을 반환합니다.
  static Future<Locale?> getSavedLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString(_languageCodeKey);
    if (languageCode == null) {
      return null;
    }
    String? countryCode = prefs.getString(_countryCodeKey);
    return Locale(languageCode, countryCode);
  }

  /// 언어 코드를 Locale 객체로 변환합니다.
  static Locale localeFromString(String localeString) {
    if (localeString.contains('_')) {
      var parts = localeString.split('_');
      return Locale(parts[0], parts[1]);
    } else {
      return Locale(localeString);
    }
  }

  /// Locale 객체를 언어 코드 문자열로 변환합니다.
  static String localeToString(Locale locale) {
    return locale.countryCode != null && locale.countryCode!.isNotEmpty
        ? locale.toString()
        : locale.languageCode;
  }
}
