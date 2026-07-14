import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final detailColor = isDarkMode ? Colors.white54 : const Color(0xFF8A8A8A);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : const Color(0xFFFFF3ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : const Color(0xFFFFD9C7),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: onCardTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white12
                              : const Color(0xFFFFE2D5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFFE35D2F),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppLocalizations.of(context)?.howto_title ??
                            'How to use Mscanner',
                        style: TextStyle(
                          fontFamily: 'SFProDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HowToStep(
                          icon: PhosphorIconsRegular.camera,
                          step: AppLocalizations.of(context)?.howto_step1 ??
                              '1. SCAN',
                          desc: AppLocalizations.of(context)?.howto_desc1 ??
                              'Menu or Dish',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      Expanded(
                        child: _HowToStep(
                          icon: PhosphorIconsRegular.sparkle,
                          step: AppLocalizations.of(context)?.howto_step2 ??
                              '2. ANALYZE',
                          desc: AppLocalizations.of(context)?.howto_desc2 ??
                              'AI identifies\nitems',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      Expanded(
                        child: _HowToStep(
                          icon: PhosphorIconsRegular.forkKnife,
                          step: AppLocalizations.of(context)?.howto_step3 ??
                              '3. ENJOY',
                          desc: AppLocalizations.of(context)?.howto_desc3 ??
                              'Discover\nfavorites',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 12, right: 12),
            child: Center(
              child: GestureDetector(
                onTap: _open,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  AppLocalizations.of(context)?.howto_detail_link ??
                      'See more details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SFProText',
                    fontSize: 13,
                    color: detailColor,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  final IconData icon;
  final String step;
  final String desc;
  final bool isDarkMode;

  const _HowToStep({
    required this.icon,
    required this.step,
    required this.desc,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white12 : const Color(0xFFFF7A45),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 18,
          child: Center(
            child: Text(
              step,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          textAlign: TextAlign.center,
          softWrap: true,
          style: TextStyle(
            fontFamily: 'SFProText',
            fontSize: 11,
            height: 1.2,
            color: isDarkMode ? Colors.white70 : const Color(0xFF6B6B6B),
          ),
        ),
      ],
    );
  }
}
