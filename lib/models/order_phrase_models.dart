import 'package:flutter/foundation.dart';

enum SupportedLanguage {
  ko('ko'),
  en('en'),
  ja('ja');

  const SupportedLanguage(this.code);
  final String code;

  static SupportedLanguage fromCode(String code) {
    return SupportedLanguage.values.firstWhere(
      (v) => v.code == code,
      orElse: () => SupportedLanguage.ko,
    );
  }
}

enum OrderScenario {
  basicOrder('basic_order'),
  customizeOrder('customize_order'),
  allergyCheck('allergy_check'),
  recommendationAsk('recommendation_ask');

  const OrderScenario(this.value);
  final String value;

  static OrderScenario fromValue(String value) {
    return OrderScenario.values.firstWhere(
      (v) => v.value == value,
      orElse: () => OrderScenario.basicOrder,
    );
  }

  String get labelKo {
    switch (this) {
      case OrderScenario.basicOrder:
        return '기본 주문';
      case OrderScenario.customizeOrder:
        return '옵션 요청';
      case OrderScenario.allergyCheck:
        return '알레르기 확인';
      case OrderScenario.recommendationAsk:
        return '추천 요청';
    }
  }
}

enum OrderModifier {
  noCilantro('no_cilantro'),
  noOnion('no_onion'),
  lessSpicy('less_spicy'),
  lessSalty('less_salty');

  const OrderModifier(this.value);
  final String value;

  String get labelKo {
    switch (this) {
      case OrderModifier.lessSpicy:
        return '덜 맵게';
      case OrderModifier.lessSalty:
        return '덜 짜게';
      case OrderModifier.noCilantro:
        return '고수 빼고';
      case OrderModifier.noOnion:
        return '양파 빼고';
    }
  }
}

enum AllergyType {
  peanut('peanut'),
  milk('milk'),
  shrimp('shrimp'),
  egg('egg');

  const AllergyType(this.value);
  final String value;

  String get labelKo {
    switch (this) {
      case AllergyType.peanut:
        return '땅콩';
      case AllergyType.milk:
        return '우유';
      case AllergyType.shrimp:
        return '새우';
      case AllergyType.egg:
        return '계란';
    }
  }
}

@immutable
class GenerateOrderPhraseRequest {
  const GenerateOrderPhraseRequest({
    required this.menuName,
    required this.menuOriginal,
    this.menuOriginalReading,
    required this.originLanguageCode,
    required this.targetLanguageCode,
    required this.scenario,
    this.modifiers = const <OrderModifier>[],
    this.allergies = const <AllergyType>[],
  });

  final String menuName;
  final String menuOriginal;
  final String? menuOriginalReading;
  final SupportedLanguage originLanguageCode;
  final SupportedLanguage targetLanguageCode;
  final OrderScenario scenario;
  final List<OrderModifier> modifiers;
  final List<AllergyType> allergies;

  Map<String, dynamic> toJson() => {
        'menuName': menuName,
        'menuOriginal': menuOriginal,
        if ((menuOriginalReading ?? '').trim().isNotEmpty)
          'menuOriginalReading': menuOriginalReading!.trim(),
        'originLanguageCode': originLanguageCode.code,
        'targetLanguageCode': targetLanguageCode.code,
        // legacy compatibility for older backends
        'languageCode': targetLanguageCode.code,
        'scenario': scenario.value,
        if (modifiers.isNotEmpty)
          'modifiers': modifiers.map((m) => m.value).toList(),
        if (allergies.isNotEmpty)
          'allergies': allergies.map((a) => a.value).toList(),
      };
}

@immutable
class GenerateOrderPhraseResponse {
  const GenerateOrderPhraseResponse({
    required this.success,
    required this.originLanguageCode,
    required this.targetLanguageCode,
    required this.localText,
    required this.targetText,
    required this.ttsText,
    required this.tags,
  });

  final bool success;
  final SupportedLanguage originLanguageCode;
  final SupportedLanguage targetLanguageCode;
  final String localText;
  final String targetText;
  final String ttsText;
  final List<String> tags;

  factory GenerateOrderPhraseResponse.fromJson(Map<String, dynamic> json) {
    final originCode =
        (json['originLanguageCode'] ?? json['languageCode'] ?? 'ko').toString();
    final targetCode =
        (json['targetLanguageCode'] ?? json['languageCode'] ?? 'ko').toString();
    final targetLang = SupportedLanguage.fromCode(targetCode);
    final fallbackTargetText = () {
      if (targetLang == SupportedLanguage.ko) {
        return (json['koText'] ?? '').toString();
      }
      if (targetLang == SupportedLanguage.en) {
        return (json['enText'] ?? '').toString();
      }
      if (targetLang == SupportedLanguage.ja) {
        return (json['jaText'] ?? '').toString();
      }
      return '';
    }();

    return GenerateOrderPhraseResponse(
      success: json['success'] == true,
      originLanguageCode: SupportedLanguage.fromCode(originCode),
      targetLanguageCode: targetLang,
      localText: (json['localText'] ?? '').toString(),
      targetText: (json['targetText'] ?? fallbackTargetText).toString(),
      ttsText: (json['ttsText'] ?? json['localText'] ?? '').toString(),
      tags: ((json['tags'] ?? const <dynamic>[]) as List)
          .map((e) => e.toString())
          .toList(),
    );
  }
}
