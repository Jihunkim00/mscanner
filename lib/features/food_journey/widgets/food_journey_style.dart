import 'package:flutter/material.dart';
import '../../../styles/app_theme.dart';

/// Keeps existing journey widgets on the app's shared design tokens.
class FoodJourneyStyle {
  FoodJourneyStyle.of(BuildContext context)
      : isDark = Theme.of(context).brightness == Brightness.dark,
        _colors = AppColors.of(context);

  final bool isDark;
  final AppColors _colors;

  static const radius = AppTheme.cardRadius;

  Color get page => _colors.background;
  Color get card => _colors.surface;
  Color get soft => _colors.subtleSurface;
  Color get inner => _colors.surface;
  Color get border => _colors.border;
  Color get accent => _colors.primary;
  Color get emphasis => _colors.primary;
  Color get primary => _colors.text;
  Color get secondary => _colors.secondaryText;
}
