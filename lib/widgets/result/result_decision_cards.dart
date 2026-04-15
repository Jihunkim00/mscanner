import 'package:flutter/material.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick decision',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          _section(
            textColor: textColor,
            subTextColor: subTextColor,
            label: 'Menu',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: 15,
                  ),
                ),
                if ((originalTitle ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      originalTitle!.trim(),
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ),
                if ((subtitle ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!.trim(),
                      style: TextStyle(color: subTextColor, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if ((priceLabel ?? '').trim().isNotEmpty)
            _section(
              textColor: textColor,
              subTextColor: subTextColor,
              label: 'Price',
              onTap: onPriceTap,
              child: Text(
                priceLabel!.trim(),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (tags.isNotEmpty)
            _section(
              textColor: textColor,
              subTextColor: subTextColor,
              label: 'Tags',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .take(5)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 11, color: textColor),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (localInsights.isNotEmpty)
            _section(
              textColor: textColor,
              subTextColor: subTextColor,
              label: 'Local insight',
              onTap: onLocalInsightTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: localInsights
                    .take(3)
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $line',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required String label,
    required Widget child,
    required Color textColor,
    required Color subTextColor,
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: subTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      ),
    );
  }
}
