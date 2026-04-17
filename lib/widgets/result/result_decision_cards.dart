import 'package:flutter/material.dart';
import 'package:mscanner/widgets/menu_tag_registry.dart';

const Set<String> _quickDecisionRegistryCodes = <String>{
  MenuTagRegistry.recommended,
  MenuTagRegistry.signature,
  MenuTagRegistry.popular,
  MenuTagRegistry.spicy,
  MenuTagRegistry.seafood,
  MenuTagRegistry.egg,
  MenuTagRegistry.vegan,
  MenuTagRegistry.vegetarian,
  MenuTagRegistry.halal,
  MenuTagRegistry.glutenFree,
  MenuTagRegistry.dairyFree,
  MenuTagRegistry.nutAllergy,
  MenuTagRegistry.pescatarian,
  MenuTagRegistry.grill,
  MenuTagRegistry.stew,
};

String quickDecisionTagLabel(String code) {
  switch (code) {
    case MenuTagRegistry.recommended:
      return 'Recommended';
    case MenuTagRegistry.signature:
      return 'Signature';
    case MenuTagRegistry.popular:
      return 'Popular';
    case MenuTagRegistry.spicy:
      return 'Spicy';
    case MenuTagRegistry.seafood:
      return 'Seafood';
    case MenuTagRegistry.egg:
      return 'Egg';
    case MenuTagRegistry.vegan:
      return 'Vegan';
    case MenuTagRegistry.vegetarian:
      return 'Vegetarian';
    case MenuTagRegistry.halal:
      return 'Halal';
    case MenuTagRegistry.glutenFree:
      return 'Gluten Free';
    case MenuTagRegistry.dairyFree:
      return 'Dairy Free';
    case MenuTagRegistry.nutAllergy:
      return 'Nut Allergy';
    case MenuTagRegistry.pescatarian:
      return 'Pescatarian';
    case MenuTagRegistry.grill:
      return 'Grill';
    case MenuTagRegistry.stew:
      return 'Stew';
    default:
      final pretty = code.trim().replaceAll('_', ' ');
      if (pretty.isEmpty) return '';
      return pretty[0].toUpperCase() + pretty.substring(1);
  }
}

String _plainQuickTagLabel(String raw) {
  final pretty = raw.trim().replaceAll('_', ' ');
  if (pretty.isEmpty) return '';
  return pretty[0].toUpperCase() + pretty.substring(1);
}


class ResultDecisionCards extends StatelessWidget {
  const ResultDecisionCards({
    super.key,
    required this.isDarkMode,
    required this.title,
    this.originalTitle,
    this.subtitle,
    this.priceLabel,
    this.tags = const <String>[],
    this.localInsights = const <String>[],
    this.decisionReason,
    this.onPriceTap,
    this.onLocalInsightTap,
  });

  final bool isDarkMode;
  final String title;
  final String? originalTitle;
  final String? subtitle;
  final String? priceLabel;
  final List<String> tags;
  final List<String> localInsights;
  final String? decisionReason;
  final VoidCallback? onPriceTap;
  final VoidCallback? onLocalInsightTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
    isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);
    final cardColor = isDarkMode ? const Color(0xFF1F1F22) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final subTextColor =
    isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

    final hasReason = (decisionReason ?? '').trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Quick decision',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              fontSize: 20,
              height: 1.15,
            ),
          ),
          if ((originalTitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              originalTitle!.trim(),
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ],
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!.trim(),
              style: TextStyle(
                color: subTextColor,
                fontSize: 13,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (hasReason) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                decisionReason!.trim(),
                style: TextStyle(
                  color: textColor.withOpacity(0.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if ((priceLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _tapWrap(
              onTap: onPriceTap,
              child: Text(
                priceLabel!.trim(),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(2).map((tag) {
                final normalized = MenuTagRegistry.normalizeCode(tag).trim();
                final isRegistryTag =
                _quickDecisionRegistryCodes.contains(normalized);
                final label = isRegistryTag
                    ? quickDecisionTagLabel(normalized)
                    : _plainQuickTagLabel(tag);
                if (label.isEmpty) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.06)
                        : const Color(0xFFF3F4F6),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.10)
                          : const Color(0xFFE5E7EB),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRegistryTag) ...[
                        Icon(
                          MenuTagRegistry.iconForCode(normalized),
                          size: 11.5,
                          color: textColor.withOpacity(0.72),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: textColor.withOpacity(0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (localInsights.isNotEmpty) ...[
            const SizedBox(height: 12),
            _tapWrap(
              onTap: onLocalInsightTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: localInsights.take(2).map((line) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $line',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tapWrap({
    required Widget child,
    VoidCallback? onTap,
  }) {
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }
}

class ResultRecommendationCompactCard extends StatelessWidget {
  const ResultRecommendationCompactCard({
    super.key,
    required this.isDarkMode,
    required this.primaryName,
    this.secondaryName,
    this.summary,
    this.priceLabel,
    this.tags = const <String>[],
    this.trailing,
    this.onPriceTap,
  });

  final bool isDarkMode;
  final String primaryName;
  final String? secondaryName;
  final String? summary;
  final String? priceLabel;
  final List<String> tags;
  final Widget? trailing;
  final VoidCallback? onPriceTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
    isDarkMode ? Colors.white.withOpacity(0.07) : const Color(0xFFE5E7EB);
    final cardColor =
    isDarkMode ? const Color(0xFF252529) : const Color(0xFFFBFCFE);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final subTextColor =
    isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                if ((secondaryName ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      secondaryName!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if ((priceLabel ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onPriceTap,
                      child: Text(
                        priceLabel!.trim(),
                        style: TextStyle(
                          color: textColor.withOpacity(0.92),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if ((summary ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      summary!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.07)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: textColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}