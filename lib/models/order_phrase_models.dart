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
    required this.languageCode,
    required this.menuName,
    required this.scenario,
    this.modifiers = const <OrderModifier>[],
    this.allergies = const <AllergyType>[],
  });

  final SupportedLanguage languageCode;
  final String menuName;
  final OrderScenario scenario;
  final List<OrderModifier> modifiers;
  final List<AllergyType> allergies;

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode.code,
    'menuName': menuName,
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
    required this.languageCode,
    required this.localText,
    required this.koText,
    required this.enText,
    required this.ttsText,
    required this.tags,
  });

  final bool success;
  final SupportedLanguage languageCode;
  final String localText;
  final String koText;
  final String enText;
  final String ttsText;
  final List<String> tags;

  factory GenerateOrderPhraseResponse.fromJson(Map<String, dynamic> json) {
    return GenerateOrderPhraseResponse(
      success: json['success'] == true,
      languageCode: SupportedLanguage.fromCode(
        (json['languageCode'] ?? 'ko').toString(),
      ),
      localText: (json['localText'] ?? '').toString(),
      koText: (json['koText'] ?? '').toString(),
      enText: (json['enText'] ?? '').toString(),
      ttsText: (json['ttsText'] ?? '').toString(),
      tags: ((json['tags'] ?? const <dynamic>[]) as List)
          .map((e) => e.toString())
          .toList(),
    );
  }
}