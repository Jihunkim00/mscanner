import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

/// 어떤 포인트 컬러로 칩/버튼을 칠할지 선택
enum MScannerAccent { blue, orange }

class MScannerSearchUi {
  static bool isDark(BuildContext context) =>
      AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

  // ✅ iOS System Blue 톤
  static Color primaryBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

  // ✅ iOS System Orange 톤 (How to use 카드 느낌)
  static Color accentOrange(BuildContext context) =>
      isDark(context) ? const Color(0xFF6D311C) : const Color(0xFFE35D2F);

  static Color accent(BuildContext context, {MScannerAccent scheme = MScannerAccent.blue}) {
    switch (scheme) {
      case MScannerAccent.orange:
        return accentOrange(context);
      case MScannerAccent.blue:
      default:
        return primaryBlue(context);
    }
  }

  static Color searchBg(BuildContext context) {
    final dark = isDark(context);
    return dark
        ? CupertinoColors.systemGrey5.withOpacity(0.25)
        : CupertinoColors.systemGrey6;
  }

  /// Pill/Chip 배경
  static Color chipBg(
      BuildContext context, {
        required bool selected,
        MScannerAccent scheme = MScannerAccent.blue,
      }) {
    final p = accent(context, scheme: scheme);
    if (selected) return p;

    // unselected는 tint 느낌
    if (scheme == MScannerAccent.orange) {
      return isDark(context) ? p.withOpacity(0.18) : p.withOpacity(0.12);
    }
    return isDark(context) ? p.withOpacity(0.28) : p.withOpacity(0.22);
  }

  /// Pill/Chip 텍스트/아이콘 색
  static Color chipFg(
      BuildContext context, {
        required bool selected,
        MScannerAccent scheme = MScannerAccent.blue,
      }) {
    if (selected) return Colors.white;

    // unselected는 accent 색 또는 다크에서 화이트 톤
    final p = accent(context, scheme: scheme);
    return isDark(context) ? Colors.white.withOpacity(0.92) : p.withOpacity(0.92);
  }

  /// Pill/Chip 테두리 색
  static Color chipBorder(
      BuildContext context, {
        required bool selected,
      }) {
    if (selected) return Colors.white.withOpacity(0.14);
    return isDark(context) ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
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
    final dark = MScannerSearchUi.isDark(context);

    return CupertinoSearchTextField(
      controller: controller,
      placeholder: placeholder,
      backgroundColor: MScannerSearchUi.searchBg(context),
      style: TextStyle(
        color: dark ? Colors.white : Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      placeholderStyle: TextStyle(
        color: dark ? Colors.white54 : Colors.black38,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MScannerSearchUi.chipBg(
                context,
                selected: selected,
                scheme: scheme,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MScannerSearchUi.chipBorder(context, selected: selected),
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
                  style: TextStyle(
                    color: MScannerSearchUi.chipFg(
                      context,
                      selected: selected,
                      scheme: scheme,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ],
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
          child: const Icon(
            Icons.tune, // 기본값(원하면 외부에서 icon 변경)
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}