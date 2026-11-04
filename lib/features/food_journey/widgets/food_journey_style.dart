import 'package:flutter/material.dart';

/// Local tokens keep Dynamic Color out of the journey without changing the app theme.
class FoodJourneyStyle {
  FoodJourneyStyle.of(BuildContext context)
      : isDark = Theme.of(context).brightness == Brightness.dark,
        _theme = Theme.of(context);

  final bool isDark;
  final ThemeData _theme;

  static const radius = BorderRadius.all(Radius.circular(20));
  static const accentOrange = Color(0xFFFF7A45);
  static const accentOrangeDark = Color(0xFFE35D2F);

  Color get page =>
      isDark ? _theme.scaffoldBackgroundColor : const Color(0xFFEFEFF4);
  Color get card => isDark ? const Color(0xFF252220) : const Color(0xFFFFF9F6);
  Color get soft => isDark ? const Color(0xFF382A24) : const Color(0xFFFFF3ED);
  Color get inner => isDark ? const Color(0xFF201E1D) : Colors.white;
  Color get border =>
      isDark ? const Color(0xFF694936) : const Color(0xFFFFD9C7);
  Color get accent => isDark ? const Color(0xFFFFA477) : accentOrange;
  Color get emphasis => isDark ? const Color(0xFFFFA477) : accentOrangeDark;
  Color get primary =>
      isDark ? const Color(0xFFF4EEEA) : const Color(0xFF1E1E1E);
  Color get secondary =>
      isDark ? const Color(0xFFC3B7AF) : const Color(0xFF6B6B6B);
}
