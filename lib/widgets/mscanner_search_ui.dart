import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// Legacy names remain compatible; both use the shared brand accent.
enum MScannerAccent { blue, orange }

class MScannerSearchUi {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryBlue(BuildContext context) =>
      AppColors.of(context).primary;

  static Color accentOrange(BuildContext context) =>
      AppColors.of(context).primary;

  static Color accent(BuildContext context,
      {MScannerAccent scheme = MScannerAccent.blue}) {
    switch (scheme) {
      case MScannerAccent.orange:
        return accentOrange(context);
      case MScannerAccent.blue:
        return primaryBlue(context);
    }
  }

  static Color searchBg(BuildContext context) {
    return AppColors.of(context).subtleSurface;
  }

  /// Pill/Chip 배경
  static Color chipBg(
    BuildContext context, {
    required bool selected,
    MScannerAccent scheme = MScannerAccent.blue,
  }) {
    final p = accent(context, scheme: scheme);
    if (selected) return p;

    return AppColors.of(context).surface;
  }

  /// Pill/Chip 텍스트/아이콘 색
  static Color chipFg(
    BuildContext context, {
    required bool selected,
    MScannerAccent scheme = MScannerAccent.blue,
  }) {
    final colors = AppColors.of(context);
    return selected ? colors.onPrimary : colors.secondaryText;
  }

  /// Pill/Chip 테두리 색
  static Color chipBorder(
    BuildContext context, {
    required bool selected,
  }) {
    final colors = AppColors.of(context);
    return selected ? colors.primary : colors.border;
  }
}

class MScannerSearchField extends StatelessWidget {
  const MScannerSearchField({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.controller,
  });

  final String placeholder;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return CupertinoSearchTextField(
      controller: controller,
      placeholder: placeholder,
      backgroundColor: MScannerSearchUi.searchBg(context),
      style: textTheme.bodyMedium?.copyWith(color: colors.text),
      placeholderStyle:
          textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
      borderRadius: AppTheme.controlRadius,
      onChanged: onChanged,
    );
  }
}

/// ✅ 기본 Pill Chip (정렬/필터 버튼에 그대로 사용 가능)
/// - scheme: blue(기본) / orange(How-to 스타일)
/// - leading: 아이콘 필요하면 넣기
class MScannerPillChip extends StatelessWidget {
  const MScannerPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.scheme = MScannerAccent.blue,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MScannerAccent scheme;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTheme.controlRadius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MScannerSearchUi.chipBg(
                  context,
                  selected: selected,
                  scheme: scheme,
                ),
                borderRadius: AppTheme.controlRadius,
                border: Border.all(
                  color:
                      MScannerSearchUi.chipBorder(context, selected: selected),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    Icon(
                      leading,
                      size: 14,
                      color: MScannerSearchUi.chipFg(
                        context,
                        selected: selected,
                        scheme: scheme,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: MScannerSearchUi.chipFg(
                            context,
                            selected: selected,
                            scheme: scheme,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ How-to 카드 같은 “오렌지 원형 아이콘 버튼”
/// (정렬/필터 아이콘을 원형으로 강조하고 싶을 때)
class MScannerCircleIconButton extends StatelessWidget {
  const MScannerCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.scheme = MScannerAccent.orange,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final MScannerAccent scheme;

  @override
  Widget build(BuildContext context) {
    final bg = MScannerSearchUi.accent(context, scheme: scheme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.of(context).onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
