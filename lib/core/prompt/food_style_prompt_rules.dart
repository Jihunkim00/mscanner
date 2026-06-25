enum FoodStyle {
  aiRecommend,
  lowFat,
  lowSalt,
  nutFree,
  seafood,
  meat,
  muslimFriendly;

  String get id => name;

  String get defaultLabel {
    switch (this) {
      case FoodStyle.aiRecommend:
        return 'AI recommend';
      case FoodStyle.lowFat:
        return 'Low Fat';
      case FoodStyle.lowSalt:
        return 'Low salt';
      case FoodStyle.nutFree:
        return 'Nut-free';
      case FoodStyle.seafood:
        return 'Seafood';
      case FoodStyle.meat:
        return 'Meat';
      case FoodStyle.muslimFriendly:
        return 'Muslim-friendly';
    }
  }

  static FoodStyle fromStoredValue(
    String? value, {
    FoodStyle fallback = FoodStyle.aiRecommend,
  }) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return fallback;

    for (final style in FoodStyle.values) {
      if (style.id == raw) return style;
    }

    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]+'), '')
        .replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

    const aliases = <String, FoodStyle>{
      'airecommend': FoodStyle.aiRecommend,
      'airecommended': FoodStyle.aiRecommend,
      'ai추천': FoodStyle.aiRecommend,
      '추천': FoodStyle.aiRecommend,
      'lowfat': FoodStyle.lowFat,
      '저지방': FoodStyle.lowFat,
      'lowsalt': FoodStyle.lowSalt,
      '저염': FoodStyle.lowSalt,
      'nutfree': FoodStyle.nutFree,
      '견과류제외': FoodStyle.nutFree,
      '견과류없음': FoodStyle.nutFree,
      'seafood': FoodStyle.seafood,
      '해산물': FoodStyle.seafood,
      'meat': FoodStyle.meat,
      '고기': FoodStyle.meat,
      'muslim': FoodStyle.muslimFriendly,
      'muslimfriendly': FoodStyle.muslimFriendly,
      'halal': FoodStyle.muslimFriendly,
      '무슬림': FoodStyle.muslimFriendly,
      '할랄': FoodStyle.muslimFriendly,
    };

    return aliases[normalized] ?? fallback;
  }
}

abstract final class FoodStylePromptRules {
  static String forStyle(FoodStyle style) {
    switch (style) {
      case FoodStyle.aiRecommend:
        return '''
Food style rule: aiRecommend
- Recommend representative choices from the real extracted menu.
- Consider visible price, menu name, description, likely local popularity, broad appeal, traveler friendliness, and cooking-method evidence.
- Do not overstate conclusions when evidence is weak.
- Provide recommendationRank, recommendationReason, and styleFitScore for every item.''';
      case FoodStyle.lowFat:
        return '''
Food style rule: lowFat
- Treat fried, deep-fried, cream, butter, cheese, fatty meat, and rich-sauce dishes as lower fit.
- Treat grilled, steamed, boiled, broth-light, salad, fish, and vegetable-centered dishes as relatively higher fit.
- Image/menu evidence cannot establish actual fat content. State that the assessment is an estimate in cautionReason.
- Never make definitive medical or nutritional claims.''';
      case FoodStyle.lowSalt:
        return '''
Food style rule: lowSalt
- Treat ramen, soup-heavy dishes, pickles, salted seafood, soy/miso/strong-sauce dishes, processed meat, and salty seasoning as lower fit.
- Treat dishes where sauce can be requested separately, raw dishes, salads, and simply grilled dishes as relatively higher fit.
- Never claim actual sodium content when it is not visible.
- Use cautionReason such as "may be salty because of sauce, broth, or seasoning" when appropriate.''';
      case FoodStyle.nutFree:
        return '''
Food style rule: nutFree
- Mark visible nuts in names or descriptions as not recommended or caution.
- Check for peanut, almond, cashew, walnut, sesame, nut paste, satay, pesto, and related cross-contact clues.
- Never guarantee allergy safety from an image or menu alone.
- cautionReason or allergyDisclaimer MUST say that restaurant staff confirmation is required.
- nutFree means assessing caution needs, not certifying safety.''';
      case FoodStyle.seafood:
        return '''
Food style rule: seafood
- Prefer fish, shrimp, crab, shellfish, squid, octopus, seafood broth, and seafood platter items.
- Keep non-seafood items in the extraction but give them a lower styleFitScore.
- Put visible seafood evidence in matchedEvidence.''';
      case FoodStyle.meat:
        return '''
Food style rule: meat
- Prefer beef, pork, chicken, lamb, grilled meat, steak, ham, sausage, and meat-broth dishes.
- Give vegetarian, dessert, and beverage items a lower styleFitScore.
- If meat is not clear, use unknown evidence or low confidence instead of guessing.''';
      case FoodStyle.muslimFriendly:
        return '''
Food style rule: muslimFriendly
- Never claim or imply halal certification.
- Flag pork, bacon, ham, sausage, lard, alcohol, mirin, sake, and wine sauce as possible incompatibilities.
- Even seafood, vegetables, chicken, or beef require requiresStaffCheck=true when halal status or preparation is unknown.
- If pork or alcohol may be present, use styleMatched=false or foodStyleFit="caution"/"notRecommended".
- The disclaimer MUST say halal certification must be confirmed with restaurant staff.
- Never output "halal certified" unless that exact certification is visibly present, and even then describe only the visible claim.''';
    }
  }
}
