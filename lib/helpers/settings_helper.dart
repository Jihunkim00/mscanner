import 'package:shared_preferences/shared_preferences.dart';

class SettingsHelper {
  static const String _questionKey = 'gpt_question';
  static const String _presetKey = 'preset';
  static const String _engineKey = 'selected_engine';
  static const String _customPresetDescriptionKey = 'custom_preset_description';

  // Save the question text
  static Future<void> saveQuestion(String question) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_questionKey, question);
  }

  // Get the saved question text
  static Future<String> getQuestion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_questionKey) ?? 'Enter Question';
  }

  // Save the preset id
  static Future<void> savePreset(int presetId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_presetKey, presetId);
  }

  // Get the saved preset id
  static Future<int> getPreset() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_presetKey) ?? 1;
  }

  // Save the custom preset description
  static Future<void> saveCustomPresetDescription(String description) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPresetDescriptionKey, description);
  }

  // Get the saved custom preset description
  static Future<String> getCustomPresetDescription() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPresetDescriptionKey) ?? 'No description available';
  }

  // Get question by preset id
  static Future<String> getQuestionByPreset(int presetId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String customPresetDescription = await getCustomPresetDescription();

    switch (presetId) {
      case 1:
        return customPresetDescription; // 사용자 정의 프리셋 설명 사용
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
        return 'explain brief food menu'; // 기본 질문
    }
  }

  // Save the selected engine
  static Future<void> saveSelectedEngine(String engine) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine);
  }

  // Get the saved selected engine
  static Future<String?> getSelectedEngine() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_engineKey);
  }

  // ✅ 여기에 추가
  static const String _languageCodeKey = 'language_code';

  static Future<void> setLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
  }

  static Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageCodeKey) ?? 'en'; // 기본값 영어
  }

}
