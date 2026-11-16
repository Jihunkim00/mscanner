import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import '../styles/app_theme.dart';

class HowToUseMscannerCard extends StatelessWidget {
  final String url;
  final VoidCallback onCardTap;

  const HowToUseMscannerCard({
    super.key,
    required this.onCardTap,
    this.url = 'https://mscanner.net/how-to-use/',
  });

  Future<void> _open() async {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.cardRadius,
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onCardTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lightbulb_outline,
                        size: 22, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(l10n?.howto_title ?? 'How to use Mscanner',
                            style: textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final stacked = constraints.maxWidth < 360 * scale;
                    final steps = [
                      _HowToStep(
                          icon: PhosphorIconsRegular.camera,
                          step: l10n?.howto_step1 ?? '1. SCAN',
                          desc: l10n?.howto_desc1 ?? 'Menu or Dish',
                          horizontal: stacked),
                      _HowToStep(
                          icon: PhosphorIconsRegular.sparkle,
                          step: l10n?.howto_step2 ?? '2. ANALYZE',
                          desc: l10n?.howto_desc2 ?? 'AI identifies\nitems',
                          horizontal: stacked),
                      _HowToStep(
                          icon: PhosphorIconsRegular.forkKnife,
                          step: l10n?.howto_step3 ?? '3. ENJOY',
                          desc: l10n?.howto_desc3 ?? 'Discover\nfavorites',
                          horizontal: stacked),
                    ];
                    if (stacked) {
                      return Column(children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          steps[i],
                        ],
                      ]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < steps.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: steps[i]),
                          ],
                        ]);
                  }),
                ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextButton(
            onPressed: _open,
            child: Text(l10n?.howto_detail_link ?? 'See more details',
                textAlign: TextAlign.center,
                style: textTheme.labelMedium
                    ?.copyWith(color: colors.secondaryText)),
          ),
        ),
      ]),
    );
  }
}

class _HowToStep extends StatelessWidget {
  const _HowToStep(
      {required this.icon,
      required this.step,
      required this.desc,
      required this.horizontal});

  final IconData icon;
  final String step;
  final String desc;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final symbol = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: colors.subtleSurface, borderRadius: AppTheme.controlRadius),
      child: PhosphorIcon(icon, size: 22, color: colors.primary),
    );
    final labels = Column(
      crossAxisAlignment:
          horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(step,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(desc,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: colors.secondaryText)),
      ],
    );
    if (horizontal) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        symbol,
        const SizedBox(width: 12),
        Expanded(child: labels)
      ]);
    }
    return Column(children: [symbol, const SizedBox(height: 8), labels]);
  }
}
