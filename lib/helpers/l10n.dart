import 'package:flutter/material.dart';

class L10n {
  static final all = [
    const Locale('en'), // English
    const Locale('ko'), // Korean
    const Locale('ja'), // Japanese
    const Locale('zh'), // Chinese (General)
    const Locale('zh', 'Hans'), // Chinese (Simplified)
    const Locale('zh', 'Hant'), // Chinese (Traditional)
    const Locale('hi'), // Hindi
    const Locale('es'), // Spanish
    const Locale('fr'), // French
    const Locale('vi'), // Vietnamese
    const Locale('th'), // Thai
    const Locale('ar'), // Arabic
    const Locale('bn'), // Bengali
    const Locale('ru'), // Russian
    const Locale('pt'), // Portuguese
    const Locale('pt', 'BR'), // Portuguese (Brazil)
    const Locale('ur'), // Urdu
    const Locale('id'), // Indonesian
    const Locale('de'), // German
    const Locale('mr'), // Marathi
    const Locale('te'), // Telugu
    const Locale('tr'), // Turkish
  ];

  static String getFlag(String code) {
    switch (code) {
      case 'en':
        return '🇺🇸'; // English
      case 'ko':
        return '🇰🇷'; // Korean
      case 'ja':
        return '🇯🇵'; // Japanese
      case 'zh':
        return '🇨🇳'; // Chinese (General)
      case 'hi':
        return '🇮🇳'; // Hindi
      case 'es':
        return '🇪🇸'; // Spanish
      case 'fr':
        return '🇫🇷'; // French
      case 'vi':
        return '🇻🇳'; // Vietnamese
      case 'th':
        return '🇹🇭'; // Thai
      case 'ar':
        return '🇸🇦'; // Arabic
      case 'bn':
        return '🇧🇩'; // Bengali
      case 'ru':
        return '🇷🇺'; // Russian
      case 'pt':
        return '🇵🇹'; // Portuguese
      case 'pt_BR':
        return '🇧🇷'; // Portuguese (Brazil)
      case 'ur':
        return '🇵🇰'; // Urdu
      case 'id':
        return '🇮🇩'; // Indonesian
      case 'de':
        return '🇩🇪'; // German
      case 'mr':
        return '🇮🇳'; // Marathi
      case 'te':
        return '🇮🇳'; // Telugu
      case 'tr':
        return '🇹🇷'; // Turkish
      default:
        return '🌐';
    }
  }
}
