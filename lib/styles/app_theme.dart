import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'Text_Styles.dart';

/// Clean & Airy palette shared by Material, Cupertino and existing UI helpers.
class AppColors {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.text,
    required this.secondaryText,
    required this.subtleSurface,
    required this.border,
  });

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color text;
  final Color secondaryText;
  final Color subtleSurface;
  final Color border;

  static const light = AppColors(
    primary: Color(0xFFB84928),
    onPrimary: Colors.white,
    background: Color(0xFFFAF8F5),
    surface: Colors.white,
    text: Color(0xFF222622),
    secondaryText: Color(0xFF69716C),
    subtleSurface: Color(0xFFF4EEE9),
    border: Color(0xFFEAE5DF),
  );

  static const dark = AppColors(
    primary: Color(0xFFFFB599),
    onPrimary: Color(0xFF54200E),
    background: Color(0xFF181A18),
    surface: Color(0xFF232623),
    text: Color(0xFFF1F3EF),
    secondaryText: Color(0xFFB1B9B2),
    subtleSurface: Color(0xFF303530),
    border: Color(0xFF424942),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  static const cardRadius = BorderRadius.all(Radius.circular(16));
  static const controlRadius = BorderRadius.all(Radius.circular(12));
  static const pagePadding = 16.0;
  static const sectionGap = 16.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors =
        brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.light.primary,
      brightness: brightness,
    ).copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.primary,
      onSecondary: colors.onPrimary,
      primaryContainer: colors.subtleSurface,
      onPrimaryContainer: colors.primary,
      secondaryContainer: colors.subtleSurface,
      onSecondaryContainer: colors.primary,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.secondaryText,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.subtleSurface,
      surfaceContainer: colors.subtleSurface,
      outline: colors.border,
      outlineVariant: colors.border,
    );
    final textTheme = AppTextStyles.theme.apply(
      fontFamily: 'SFPro',
      bodyColor: colors.text,
      displayColor: colors.text,
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'SFPro',
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.background,
      dividerColor: colors.border,
      disabledColor: colors.secondaryText,
      iconTheme: IconThemeData(color: colors.secondaryText, size: 24),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.primary,
        scaffoldBackgroundColor: colors.background,
        barBackgroundColor: colors.background,
        textTheme: CupertinoTextThemeData(
          primaryColor: colors.primary,
          textStyle: textTheme.bodyMedium!,
          navTitleTextStyle: textTheme.titleLarge!,
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.text, size: 24),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.subtleSurface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
        border: const OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colors.onPrimary,
          backgroundColor: colors.primary,
          elevation: 0,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colors.border),
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.subtleSurface,
        selectedColor: colors.primary,
        labelStyle: textTheme.labelLarge,
        side: BorderSide(color: colors.border),
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.secondaryText,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
