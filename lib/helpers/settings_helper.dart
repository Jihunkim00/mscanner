import 'package:shared_preferences/shared_preferences.dart';

import '../core/prompt/food_style_prompt_rules.dart';
import '../core/prompt/scan_prompt_builder.dart';
import '../core/prompt/scan_prompt_preset.dart';
import '../l10n/gen_l10n/app_localizations.dart';

class SettingsHelper {
  static const String _questionKey = 'gpt_question';
  static const String _presetKey = 'preset';
  static const String _engineKey = 'selected_engine';
  static const String _customPresetDescriptionKey = 'custom_preset_description';
  static const String selectedLanguageCodeKey = 'selectedLanguageCode';
  static const String selectedFoodStyleKey = 'selectedFoodStyle';
  static const String selectedFoodStyleIdKey = 'selectedFoodStyleId';
  static const String selectedFoodStyleLabelKey = 'selectedFoodStyleLabel';
  static const String selectedMenuNumberKey = 'selectedMenuNumber';
  static const String _languageCodeKey = 'language_code';

  static Future<void> saveQuestion(String question) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_questionKey, question);
  }

  static Future<String> getQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_questionKey) ?? 'Enter Question';
  }

  static Future<void> savePreset(int presetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_presetKey, presetId);
  }

  static Future<int> getPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_presetKey) ?? 1;
  }

  static Future<void> saveCustomPresetDescription(String description) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPresetDescriptionKey, description);
  }

  static Future<String> getCustomPresetDescription() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPresetDescriptionKey) ??
        'No description available';
  }

  static Future<String> getQuestionByPreset(int presetId) async {
    final customPresetDescription = await getCustomPresetDescription();
    switch (presetId) {
      case 1:
        return customPresetDescription;
      case 2:
        return '메뉴 전체를 개요 50자로 설명하고, 사진에 포함된 음식 메뉴 중 다이어트에 좋은 추천 순서로 1-10가지 메뉴를 선택하여 음식 이름을 원어와 한글 발음으로 제공하고 내용을 검색 요약하여 1000자 내로 설명합니다. 제공된 사진 외의 추측성 메뉴와 설명은 하지 않으며, 음식메뉴판이 아닌 경우 아니라고 표시';
      case 3:
        return '메뉴 전체를 개요 20자로 설명하고, 사용자의 오늘 기분은 슬픔입니다. 사진에 포함된 음식 메뉴 중 AI 추천 순서로 1-5가지 메뉴를 선택하여 음식 이름을 원어와 한글 발음으로 제공하고 내용을 검색 요약하여 130자 내로 설명합니다. 제공된 사진 외의 추측성 메뉴와 설명은 하지 않으며, 음식메뉴판이 아닌 경우 아니라고 표시';
      case 4:
        return '약이나 영양제 에대해서 부작용과 장점과 대략적 가격을 설명해줘 설명은 500자 내외로 해주고 대답해줄 때 상품명(원문) : 설명 으로 말해줘 약이나 영양제 사진이 아닌 경우 아니라고 설명해줘';
      case 5:
        return '여행할 때 표지판 사진인데 간략하게 번역해주고 지명의 경우 원문과 같이 알려줘';
      case 6:
        return '여행 관련 사진인데 사진에 대한 걸 설명해줘';
      default:
        return 'explain brief food menu';
    }
  }

  static String buildPresetDescription({
    required String selectedLanguageCode,
    required String selectedFoodStyle,
    required String selectedMenuNumber,
  }) {
    final style = resolveFoodStyle(selectedFoodStyle);
    return ScanPromptBuilder(
      scanPreset: ScanPromptPreset.defaultFoodScan,
      targetLanguage: selectedLanguageCode,
      isMultiScan: false,
      includeCurrency: true,
      includeRagContext: false,
      selectedFoodStyle: style,
      selectedFoodStyleLabel: selectedFoodStyle == style.id
          ? style.defaultLabel
          : selectedFoodStyle,
      scanMode: 'single',
      menuCountHint: selectedMenuNumber,
    ).build();
  }

  static Future<void> refreshCustomPresetDescriptionFromSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLanguageCode =
        prefs.getString(selectedLanguageCodeKey) ?? 'en';
    final selectedFoodStyle = prefs.getString(selectedFoodStyleIdKey) ??
        prefs.getString(selectedFoodStyleKey) ??
        FoodStyle.aiRecommend.id;
    final selectedMenuNumber = prefs.getString(selectedMenuNumberKey) ?? '1-5';

    final presetDescription = buildPresetDescription(
      selectedLanguageCode: selectedLanguageCode,
      selectedFoodStyle: selectedFoodStyle,
      selectedMenuNumber: selectedMenuNumber,
    );
    await saveCustomPresetDescription(presetDescription);
  }

  static Future<void> saveSelectedEngine(String engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine);
  }

  static Future<String?> getSelectedEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_engineKey);
  }

  static Future<void> setLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
  }

  static Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedLanguageCodeKey) ??
        prefs.getString(_languageCodeKey) ??
        'en';
  }

  static Future<FoodStyle> getSelectedFoodStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(selectedFoodStyleIdKey);
    if (storedId != null && storedId.trim().isNotEmpty) {
      return resolveFoodStyle(storedId);
    }
    return resolveFoodStyle(prefs.getString(selectedFoodStyleKey));
  }

  static FoodStyle resolveFoodStyle(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return FoodStyle.aiRecommend;

    for (final locale in AppLocalizations.supportedLocales) {
      final localizations = lookupAppLocalizations(locale);
      final localizedValues = <String, FoodStyle>{
        localizations.foodStyleAIRecommend: FoodStyle.aiRecommend,
        localizations.foodStyleLowFat: FoodStyle.lowFat,
        localizations.foodStyleLowSalt: FoodStyle.lowSalt,
        localizations.foodStyleNutFree: FoodStyle.nutFree,
        localizations.foodStyleSeafood: FoodStyle.seafood,
        localizations.foodStyleMeat: FoodStyle.meat,
        localizations.foodStyleMuslim: FoodStyle.muslimFriendly,
      };
      final matched = localizedValues[raw];
      if (matched != null) return matched;
    }
    return FoodStyle.fromStoredValue(raw);
  }

  static Future<String> getSelectedFoodStyleLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final explicit = prefs.getString(selectedFoodStyleLabelKey)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final legacy = prefs.getString(selectedFoodStyleKey)?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return (await getSelectedFoodStyle()).defaultLabel;
  }

  static Future<String> getSelectedMenuNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedMenuNumberKey) ?? '1-5';
  }
}
