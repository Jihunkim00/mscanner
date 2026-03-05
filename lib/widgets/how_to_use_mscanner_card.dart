import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

/// "How to use Mscanner" 카드 (스샷 스타일)
/// - 카드 전체 탭 시 [url]을 외부 브라우저로 오픈
/// - Phosphor 아이콘 사용 (프로젝트에 phosphor_flutter가 이미 적용되어 있다는 전제)
class HowToUseMscannerCard extends StatelessWidget {
  final String url;

  const HowToUseMscannerCard({
    super.key,
    this.url = 'https://mscanner.net/how-to-use/',
  });

  Future<void> _open() async {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _open,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white10 : const Color(0xFFFFF3ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode ? Colors.white12 : const Color(0xFFFFD9C7),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white12 : const Color(0xFFFFE2D5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: isDarkMode ? Colors.white70 : const Color(0xFFE35D2F),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)?.howto_title ?? 'How to use Mscanner',
                  style: TextStyle(
                    fontFamily: 'SFProDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // ✅ 위 기준 정렬
              children: [
                Expanded(
                  child: _HowToStep(
                    icon: PhosphorIconsRegular.camera,
                    step: AppLocalizations.of(context)?.howto_step1 ?? '1. SCAN',
                    desc: AppLocalizations.of(context)?.howto_desc1 ?? 'Menu or Dish',
                    isDarkMode: isDarkMode,
                  ),
                ),
                Expanded(
                  child: _HowToStep(
                    icon: PhosphorIconsRegular.sparkle,
                    step: AppLocalizations.of(context)?.howto_step2 ?? '2. ANALYZE',
                    desc: AppLocalizations.of(context)?.howto_desc2 ?? 'AI identifies\nitems',
                    isDarkMode: isDarkMode,
                  ),
                ),
                Expanded(
                  child: _HowToStep(
                    icon: PhosphorIconsRegular.forkKnife,
                    step: AppLocalizations.of(context)?.howto_step3 ?? '3. EAT',
                    desc: AppLocalizations.of(context)?.howto_desc3 ?? 'Discover\nfavorites',
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            )
          ],
        ),
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

        // ✅ step 영역은 고정 높이 (짧아서 흔들리면 안 됨)
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

        // ✅ desc는 ellipsis 없이 "전부" 보여주기
        // ✅ 대신 Row 전체 높이가 가장 긴 desc에 맞춰 커지도록 설계됨
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