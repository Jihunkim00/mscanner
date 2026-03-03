import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MenuTagRegistry {
  static const String vegan = 'vegan';
  static const String vegetarian = 'vegetarian';
  static const String glutenFree = 'gluten_free';
  static const String dairyFree = 'dairy_free';
  static const String nutAllergy = 'nut_allergy';
  static const String halal = 'halal';
  static const String pescatarian = 'pescatarian';

  static const String spicy = 'spicy';
  static const String grill = 'grill';
  static const String stew = 'stew';

  static const String recommended = 'recommended';
  static const String signature = 'signature';
  static const String popular = 'popular';

  static const String egg = 'egg';
  static const String seafood = 'seafood';

  static const Map<String, String> aliasMap = {
    // EN
    'vegan': vegan,
    'vegetarian': vegetarian,
    'gluten-free': glutenFree,
    'gluten free': glutenFree,
    'dairy-free': dairyFree,
    'dairy free': dairyFree,
    'nut allergy': nutAllergy,
    'halal': halal,
    'pescatarian': pescatarian,
    'spicy': spicy,
    'grill': grill,
    'stew': stew,
    'recommended': recommended,
    'signature': signature,
    'popular': popular,
    'egg': egg,
    'eggs': egg,
    'seafood': seafood,
    'sea food': seafood,

    // JA
    'ベジタリアン': vegetarian,
    'ヴィーガン': vegan,
    'グルテンフリー': glutenFree,
    '乳製品不使用': dairyFree,
    'ナッツアレルギー': nutAllergy,
    'ハラール': halal,
    'ペスカタリアン': pescatarian,
    '辛い': spicy,
    'グリル': grill,
    '煮込み': stew,
    'おすすめ': recommended,
    '人気': popular,
    '名物': signature,
    '卵': egg,
    'たまご': egg,
    '玉子': egg,
    'シーフード': seafood,
    '海鮮': seafood,


    // KO
    '비건': vegan,
    '채식': vegetarian,
    '글루텐프리': glutenFree,
    '유제품 없음': dairyFree,
    '견과 알레르기': nutAllergy,
    '할랄': halal,
    '페스카테리언': pescatarian,
    '매운맛': spicy,
    '그릴': grill,
    '조림': stew,
    '추천': recommended,
    '시그니처': signature,
    '인기': popular,
    '계란': egg,
    '달걀': egg,
    '해산물': seafood,
    '생선': seafood,

  };

  static String normalizeCode(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    final lower = t.toLowerCase();
    return aliasMap[lower] ?? aliasMap[t] ?? lower;
  }

  // ✅ 2.1.0에서 이름 확실한 아이콘들로만 구성 (보수적)
  static IconData iconForCode(String code) {
    switch (code) {
      case vegan:
        return PhosphorIcons.leaf();
      case vegetarian:
        return PhosphorIcons.plant();

      case glutenFree:
        return PhosphorIcons.grainsSlash(); // (대체) 금지/제한 느낌
      case dairyFree:
        return PhosphorIcons.drop(); // (대체) 유제품/라떼 느낌 대신 드롭
      case nutAllergy:
        return PhosphorIcons.warning(); // (대체) 알러지 경고

      case halal:
        return PhosphorIcons.moon();
      case pescatarian:
        return PhosphorIcons.fish();

      case spicy:
        return PhosphorIcons.fire();
      case grill:
        return PhosphorIcons.flame();
      case stew:
        return PhosphorIcons.cookingPot();

      case recommended:
        return PhosphorIcons.star();
      case signature:
        return PhosphorIcons.medal();
      case popular:
        return PhosphorIcons.trendUp();

      case egg:
      // ✅ 1차 시도 (있으면 이게 베스트)
      // return PhosphorIcons.egg();

      // ✅ 2.1.0에서 egg()가 없으면 아래처럼 대체(컴파일 100% 보장)
        return PhosphorIcons.egg();

      case seafood:
        return PhosphorIcons.fish();

      default:
        return PhosphorIcons.tag();
    }
  }

  static Color backgroundForCode(String code) {
    switch (code) {
      case vegan:
      case vegetarian:
        return const Color(0xFFDDF3E1);
      case glutenFree:
      case dairyFree:
        return const Color(0xFFF8E9C8);
      case nutAllergy:
        return const Color(0xFFEAD7F7);
      case halal:
        return const Color(0xFFD7E9FF);
      case pescatarian:
        return const Color(0xFFF6D6D6);
      case spicy:
        return const Color(0xFFFFE0E0);
      case grill:
        return const Color(0xFFFFE7D6);
      case stew:
        return const Color(0xFFE7E0D9);

      case egg:
        return const Color(0xFFFFF2CC); // 연한 크림/옐로

      case seafood:
        return const Color(0xFFD7E9FF); // 연한 바다색(블루 계열)
      case recommended:
      case signature:
      case popular:
        return const Color(0xFFE3ECFF);
      default:
        return const Color(0xFFF0F0F0);
    }
  }

  static bool isCheckTag(String code) {
    switch (code) {
      case recommended:
      case signature:
      case popular:
        return true;
      default:
        return false;
    }
  }
}