import 'package:flutter/material.dart';

class PremiumAdOverlay extends StatelessWidget {
  final ImageProvider image;
  final Locale locale;
  final String adFreePrice;
  final String premiumMonthlyPrice;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onClose;
  final EdgeInsets padding;
  final double rightPanelWidthRatio;
  final double minPanelWidth;

  final BoxFit imageFit;                // 이미지 채우기 방식 (cover / contain …)
  final Alignment imageAlignment;       // 이미지 앵커 위치
  final double panelOffsetY;            // 패널을 위/아래로 미세 이동 (음수=위로)

  const PremiumAdOverlay({
    Key? key,
    required this.image,
    required this.locale,
    required this.adFreePrice,
    required this.premiumMonthlyPrice,
    this.onPrimaryTap,
    this.onClose,
    this.padding = const EdgeInsets.all(16),
    this.rightPanelWidthRatio = 0.38,
    this.minPanelWidth = 280,
    // ⬇️ 기본값
    this.imageFit = BoxFit.contain,
    this.imageAlignment = Alignment.topLeft,
    this.panelOffsetY = -50,             // 기본은 이동 없음
  }) : super(key: key);

  static const _rtlLangs = {'ar', 'ur'};
  static bool _isRTL(Locale l) => _rtlLangs.contains(l.languageCode.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final strings = _Strings.of(locale);
    final safeTop = MediaQuery.of(context).padding.top; // 👈 상단 노치/상태바 높이
    return Directionality(
      textDirection: _isRTL(locale) ? TextDirection.rtl : TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          final panelWidth = isNarrow
              ? constraints.maxWidth
              : (constraints.maxWidth * rightPanelWidthRatio).clamp(minPanelWidth, constraints.maxWidth * 0.6);

          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image(
                    image: image,
                    fit: imageFit,              // ✅ 전달받은 옵션 적용
                    alignment: imageAlignment,  // ✅ 전달받은 옵션 적용
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: isNarrow
                            ? const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        )
                            : const LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: isNarrow ? Alignment.bottomCenter : Alignment.centerRight,
                  child: Transform.translate(        // ✅ 패널 위치 조정
                    offset: Offset(0, panelOffsetY), // 음수면 위로
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: panelWidth),
                      child: Padding(
                        padding: isNarrow
                            ? padding.copyWith(top: 12)
                            : padding.copyWith(top: 24, bottom: 24, left: 24),
                        child: _Panel(
                          strings: strings,
                          adFreePrice: adFreePrice,
                          premiumMonthlyPrice: premiumMonthlyPrice,
                          isNarrow: isNarrow,
                          onPrimaryTap: onPrimaryTap,
                        ),
                      ),
                    ),
                  ),
                ),
                if (onClose != null)
                  PositionedDirectional(
                    // ✅ 기기 상단 안전영역 + 여백
                    top: safeTop + 8,
                    start: 10,
                    child: _CloseButton(onClose: onClose!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final _Strings strings;
  final String adFreePrice;
  final String premiumMonthlyPrice;
  final bool isNarrow;
  final VoidCallback? onPrimaryTap;

  const _Panel({
    required this.strings,
    required this.adFreePrice,
    required this.premiumMonthlyPrice,
    required this.isNarrow,
    this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontFamily: 'SFPro',
      fontSize: 20,   // 👈 원하는 크기로 고정
      color: Colors.white70,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );

    return DefaultTextStyle.merge(
        style: const TextStyle(
        decoration: TextDecoration.none,      // ✅ 밑줄 제거
        decorationColor: Colors.transparent,  // ✅ 혹시 모를 데코 색도 무시
    ),
    child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
        // 브랜드 텍스트 (불필요하다면 제거 가능)
        // Text("Mscanner", style: TextStyle(fontFamily: 'SFPro', color: Colors.white70, fontSize: 13, letterSpacing: 0.5)),
        SizedBox(height: isNarrow ? 6 : 10),
        Text(strings.title, style: titleStyle, maxLines: 2),
        SizedBox(height: isNarrow ? 8 : 12),
        _PriceRow(icon: Icons.block, label: strings.adFree, price: adFreePrice),
        const SizedBox(height: 6),
        _PriceRow(icon: Icons.star_rounded, label: strings.premiumMonthly, price: premiumMonthlyPrice, trailing: strings.freeTrial),
        SizedBox(height: isNarrow ? 10 : 14),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white70,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: onPrimaryTap,
            child: Text(strings.cta, style: const TextStyle(fontFamily: 'SFPro', fontSize: 18, decoration: TextDecoration.none, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        Text(strings.disclaimer,
            style: const TextStyle(fontFamily: 'SFPro', color: Colors.white30, fontSize: 15, decoration: TextDecoration.none,      // ✅ 안전장치)),
            )      )],
    ));
  }
}

class _PriceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String price;
  final String? trailing;

  const _PriceRow({
    required this.icon,
    required this.label,
    required this.price,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'SFPro',fontSize: 18, decoration: TextDecoration.none,    color: Colors.white70))),
        const SizedBox(width: 8),
        Text(price,
            style: const TextStyle(fontFamily: 'SFPro', fontSize: 16, decoration: TextDecoration.none,    color: Colors.white70, fontWeight: FontWeight.w700)),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
            child: Text(trailing!,
                style: const TextStyle(fontFamily: 'SFPro', color: Colors.white70, fontSize: 15)),
          ),
        ],
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;
  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,  // 투명 영역까지 탭 감지
      onTap: onClose,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white70,
          size: 22,
        ),
      ),
    );
  }
}



/// -------------------------
/// Strings & Localizations
/// -------------------------
class _Strings {
  final String title;
  final String adFree;
  final String premiumMonthly;
  final String freeTrial;
  final String cta;
  final String disclaimer;

  const _Strings({
    required this.title,
    required this.adFree,
    required this.premiumMonthly,
    required this.freeTrial,
    required this.cta,
    required this.disclaimer,
  });

  static _Strings of(Locale locale) {
    final lc = locale.languageCode.toLowerCase();
    switch (lc) {
      case 'ko':
        return const _Strings(
          title: '프리미엄으로 더 쾌적하게',
          adFree: '광고 제거',
          premiumMonthly: '프리미엄(월 구독)',
          freeTrial: '첫 달 무료',
          cta: '프리미엄 이용하기',
          disclaimer: '가격은 지역/스토어에 따라 달라질 수 있어요.',
        );
      case 'ja':
        return const _Strings(
          title: 'プレミアムでもっと快適に',
          adFree: '広告なし',
          premiumMonthly: 'プレミアム（月額）',
          freeTrial: '初月無料',
          cta: 'プレミアムにアップグレード',
          disclaimer: '価格は地域/ストアにより異なります。',
        );
      case 'ur':
        return const _Strings(
          title: 'پریمیم کے ساتھ مزید بہتر',
          adFree: 'بغیر اشتہارات',
          premiumMonthly: 'پریمیم (ماہانہ)',
          freeTrial: 'پہلا مہینہ مفت',
          cta: 'پریمیم حاصل کریں',
          disclaimer: 'قیمت خطے/اسٹور کے مطابق مختلف ہوسکتی ہے۔',
        );
      case 'zh':
      case 'zh-hans':
        return const _Strings(
          title: '升级尊享，更加顺畅',
          adFree: '无广告',
          premiumMonthly: '高级版（月度）',
          freeTrial: '首月免费',
          cta: '升级高级版',
          disclaimer: '价格可能因地区/商店而异。',
        );
      case 'zh-hant':
        return const _Strings(
          title: '升級尊享，更加順暢',
          adFree: '無廣告',
          premiumMonthly: '高級版（每月）',
          freeTrial: '首月免費',
          cta: '升級高級版',
          disclaimer: '價格可能因地區/商店而異。',
        );
      case 'hi':
        return const _Strings(
          title: 'प्रीमियम के साथ और बेहतर',
          adFree: 'बिना विज्ञापन',
          premiumMonthly: 'प्रिमियम (मासिक)',
          freeTrial: 'पहला महीना मुफ़्त',
          cta: 'प्रीमियम लें',
          disclaimer: 'कीमत क्षेत्र/स्टोर के अनुसार बदल सकती है।',
        );
      case 'es':
        return const _Strings(
          title: 'Más cómodo con Premium',
          adFree: 'Sin anuncios',
          premiumMonthly: 'Premium mensual',
          freeTrial: '1.º mes gratis',
          cta: 'Hazte Premium',
          disclaimer: 'El precio puede variar según la región/tienda.',
        );
      case 'fr':
        return const _Strings(
          title: 'Encore mieux avec Premium',
          adFree: 'Sans publicité',
          premiumMonthly: 'Premium mensuel',
          freeTrial: '1er mois offert',
          cta: 'Passer en Premium',
          disclaimer: 'Le prix peut varier selon la région/la boutique.',
        );
      case 'vi':
        return const _Strings(
          title: 'Trải nghiệm tốt hơn với Premium',
          adFree: 'Không quảng cáo',
          premiumMonthly: 'Premium theo tháng',
          freeTrial: 'Miễn phí tháng đầu',
          cta: 'Nâng cấp Premium',
          disclaimer: 'Giá có thể thay đổi theo khu vực/cửa hàng.',
        );
      case 'th':
        return const _Strings(
          title: 'สะดวกขึ้นด้วยพรีเมียม',
          adFree: 'ไม่มีโฆษณา',
          premiumMonthly: 'พรีเมียมรายเดือน',
          freeTrial: 'ฟรีเดือนแรก',
          cta: 'อัปเกรดเป็นพรีเมียม',
          disclaimer: 'ราคาอาจแตกต่างตามภูมิภาค/สโตร์',
        );
      case 'ar':
        return const _Strings(
          title: 'أفضل مع البريميوم',
          adFree: 'بدون إعلانات',
          premiumMonthly: 'بريميوم شهري',
          freeTrial: 'الشهر الأول مجانًا',
          cta: 'الترقية إلى بريميوم',
          disclaimer: 'قد يختلف السعر حسب المنطقة/المتجر.',
        );
      case 'bn':
        return const _Strings(
          title: 'প্রিমিয়ামে আরও ভালো',
          adFree: 'বিজ্ঞাপন মুক্ত',
          premiumMonthly: 'প্রিমিয়াম (মাসিক)',
          freeTrial: 'প্রথম মাস ফ্রি',
          cta: 'প্রিমিয়াম নিন',
          disclaimer: 'মূল্য অঞ্চল/স্টোর অনুযায়ী ভিন্ন হতে পারে।',
        );
      case 'ru':
        return const _Strings(
          title: 'Ещё лучше с Premium',
          adFree: 'Без рекламы',
          premiumMonthly: 'Premium (ежемесячно)',
          freeTrial: '1-й месяц бесплатно',
          cta: 'Перейти на Premium',
          disclaimer: 'Цена может отличаться в зависимости от региона/магазина.',
        );
      case 'pt':
      case 'pt-br':
        return const _Strings(
          title: 'Ainda melhor com Premium',
          adFree: 'Sem anúncios',
          premiumMonthly: 'Premium mensal',
          freeTrial: '1º mês grátis',
          cta: 'Virar Premium',
          disclaimer: 'O preço pode variar por região/loja.',
        );
      case 'id':
        return const _Strings(
          title: 'Lebih nyaman dengan Premium',
          adFree: 'Tanpa iklan',
          premiumMonthly: 'Premium bulanan',
          freeTrial: 'Gratis 1 bulan',
          cta: 'Tingkatkan ke Premium',
          disclaimer: 'Harga dapat berbeda menurut wilayah/toko.',
        );
      case 'de':
        return const _Strings(
          title: 'Noch besser mit Premium',
          adFree: 'Ohne Werbung',
          premiumMonthly: 'Premium monatlich',
          freeTrial: '1. Monat gratis',
          cta: 'Zu Premium wechseln',
          disclaimer: 'Der Preis kann je nach Region/Store variieren.',
        );
      case 'mr':
        return const _Strings(
          title: 'प्रीमियमसोबत अधिक चांगले',
          adFree: 'जाहिरात-मुक्त',
          premiumMonthly: 'प्रीमियम (मासिक)',
          freeTrial: 'पहिला महिना मोफत',
          cta: 'प्रीमियम घ्या',
          disclaimer: 'किंमत प्रदेश/स्टोअरनुसार बदलू शकते.',
        );
      case 'te':
        return const _Strings(
          title: 'ప్రీమియంతో ఇంకా మెరుగ్గా',
          adFree: 'జాహీరు లేవు',
          premiumMonthly: 'ప్రిమియం (నెలవారి)',
          freeTrial: 'మొదటి నెల ఉచితం',
          cta: 'ప్రీమియంకు అప్‌గ్రేడ్ చేయండి',
          disclaimer: 'ధర ప్రాంతం/స్టోర్‌పై ఆధారపడి మారవచ్చు.',
        );
      case 'tr':
        return const _Strings(
          title: 'Premium ile daha iyi',
          adFree: 'Reklamsız',
          premiumMonthly: 'Aylık Premium',
          freeTrial: 'İlk ay ücretsiz',
          cta: 'Premium’a geç',
          disclaimer: 'Fiyat bölge/mağazaya göre değişebilir.',
        );
      case 'en':
      default:
        return const _Strings(
          title: 'Better with Premium',
          adFree: 'AD Free',
          premiumMonthly: 'Premium monthly',
          freeTrial: '1st month free',
          cta: 'Go Premium',
          disclaimer: 'Price may vary by region/store.',
        );
    }
  }
}

/// ----------------------------------------------
/// Locale 유틸: BCP-47 언어 태그를 Locale로
/// 예) "pt-BR" → Locale('pt','BR')
Locale localeFromTag(String tag) {
  final parts = tag.split(RegExp('[-_]'));
  if (parts.length == 1) return Locale(parts[0]);
  if (parts.length == 2) return Locale(parts[0], parts[1]);
  return Locale(parts[0], parts[1]);
}

/// ----------------------------------------------
/// 단순 가격 매퍼 (요청 규칙)
/// - 미국/기본: USD 0.49
/// - 유럽권 언어(de, fr, es, it, pt, nl, pl, sv, da, fi, el, cs, hu, ro, sk, sl, hr, bg, et, lv, lt): EUR 0.69
/// - 일본어: JPY 100
/// - 한국어: KRW 900
/// - 그 외: USD 0.49
String simpleLocalizedPrice(Locale locale) {
  final lang = locale.languageCode.toLowerCase();

  if (lang == 'ja') return '¥100';
  if (lang == 'ko') return '₩900';

  const euLangs = {
    'de','fr','es','it','pt','nl','pl','sv','da','fi','el','cs','hu','ro','sk','sl','hr','bg','et','lv','lt'
  };
  if (euLangs.contains(lang)) return '€0.69';

  return r'$0.49'; // 기본 USD
}

/// ----------------------------------------------
/// 사용 예시
/// ----------------------------------------------
///
/// PremiumAdOverlay(
///   image: const AssetImage('assets/images/admscanner.png'), // 1032x1032
///   locale: localeFromTag('fr'),
///   adFreePrice: simpleLocalizedPrice(localeFromTag('fr')),
///   premiumMonthlyPrice: simpleLocalizedPrice(localeFromTag('fr')),
///   onPrimaryTap: () { /* 구매 플로우 진입 */ },
///   onClose: () { /* 닫기 처리 */ },
/// )
