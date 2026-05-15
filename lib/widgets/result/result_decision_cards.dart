import 'package:flutter/material.dart';
import 'package:mscanner/widgets/menu_tag_registry.dart';
import 'package:mscanner/widgets/result/result_ui_copy.dart';

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

String _quickDecisionBadgeLabel(BuildContext context) {
  return ResultUiCopy.text(context, ResultUiCopy.quickPickBadge);
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.07)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _quickDecisionBadgeLabel(context),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.85),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              fontSize: 19,
              height: 1.2,
            ),
          ),
          if ((originalTitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              originalTitle!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ],
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              subtitle!.trim(),
              style: TextStyle(
                color: subTextColor,
                fontSize: 12.5,
                height: 1.35,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if ((priceLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _tapWrap(
              onTap: onPriceTap,
              child: Text(
                priceLabel!.trim(),
                style: TextStyle(
                  color: textColor.withOpacity(0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
          if (hasReason) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.045)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                decisionReason!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withOpacity(0.78),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
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
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.045)
                        : const Color(0xFFF7F8FA),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFE8EBF0),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRegistryTag) ...[
                        Icon(
                          MenuTagRegistry.iconForCode(normalized),
                          size: 10.5,
                          color: textColor.withOpacity(0.6),
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withOpacity(0.74),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
                        fontSize: 11.5,
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
                          color: textColor.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                if ((summary ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      summary!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
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
                              fontSize: 9.5,
                              color: textColor.withOpacity(0.85),
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