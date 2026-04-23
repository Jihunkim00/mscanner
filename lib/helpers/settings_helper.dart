import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SettingsHelper {
  static const String _questionKey = 'gpt_question';
  static const String _presetKey = 'preset';
  static const String _engineKey = 'selected_engine';
  static const String _customPresetDescriptionKey = 'custom_preset_description';
  static const String selectedLanguageCodeKey = 'selectedLanguageCode';
  static const String selectedFoodStyleKey = 'selectedFoodStyle';
  static const String selectedMenuNumberKey = 'selectedMenuNumber';

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


  static String buildPresetDescription({
    required String selectedLanguageCode,
    required String selectedFoodStyle,
    required String selectedMenuNumber,
  }) {
    debugPrint('Creating preset description for language code: $selectedLanguageCode');

    final outputLang = selectedLanguageCode;
    final styleHint = selectedFoodStyle;
    final rawMenuCountHint = selectedMenuNumber.trim();
    final menuCountHint = rawMenuCountHint;


    // ✅ 공통 베이스(스키마/규칙) — 영어로 고정해도 outputLanguage로 결과 언어는 맞춰짐
    final base = '''
You MUST output ONLY valid JSON (no extra text, markdown, code fences, explanations, or RECOMMEND line).

Goal:
- Extract visible food menu items from the image/OCR.
- Return detailed recommended items and brief remaining menu items for the app UI.

Rules:
1) Output language:
- shortDesc, tags, userMessage, reason, fullMenu.summary must be in outputLanguage = "$outputLang".
- nameOriginal must be the exact original menu text from image/OCR only.
- nameOriginal must exclude prices, numbers, bullets, option markers, and category/header text.
- originLanguageCode must match the language of nameOriginal.
- name must be the translated menu name in outputLanguage. If uncertain or same, use nameOriginal.

2) nameOriginalReading:
- nameOriginalReading is pronunciation only for the dish name itself.
- Never replace nameOriginal with reading text.
- Exclude prices, numbers, category labels, and translated text.
- For Japanese, prefer hiragana when confident.
- If uncertain, use "".

3) Only use items visible in the image/OCR. Never invent menu items.

4) If this is not a food menu, return:
{
  "isMenu": false,
  "userMessage": "short display message in outputLanguage",
  "outputLanguage": "$outputLang",
  "reason": "short string"
}

5) styleHint="$styleHint" is ranking preference only. Do not hallucinate dietary facts.

6) menuCountHint="$menuCountHint" controls recommended count only:
- "1": exactly 1 recommended item. fullMenu should be empty or minimal.
- "1-3": up to 3 recommended items. fullMenu should be empty or minimal.
- "1-5": up to 5 recommended items. fullMenu should be empty or minimal.
- "all": recommended may be 1-4 items only. Use most remaining tokens for fullMenu.items.
- For difficult menus, it is better to return fewer recommended items and more fullMenu items.

7) Recommended items:
- recommended must contain only the most reliable top items.
- For difficult menus, recommended may be empty.
- shortDesc should be 0-1 short sentence.
- If details are unclear, set shortDesc="".
- If price is unclear, all prices may be null.
- If tags are unclear, use [].
- If confidence is unclear, use a rough value like 0.35 to 0.6.
- Do NOT infer ingredients, cooking style, or flavor unless clearly readable.
- Avoid generic phrases like "delicious".

8) Full menu:
- fullMenu is the main output area for menuCountHint="all".
- If menuCountHint is not "all", fullMenu.items should be empty or minimal.
- fullMenu.items must contain only remaining non-recommended menu items.
- Never repeat any recommended item in fullMenu.items.
- Merge obvious duplicates caused by OCR, repeated headers, numbering, prices, spacing, or punctuation.
- For difficult menus (handwritten, vertical, dense, low-contrast, partially occluded), prioritize extracting as many readable item names as possible.
- It is acceptable for many fullMenu items to have:
  shortDesc="",
  tags=[],
  prices with all null values,
  name=nameOriginal,
  rough category="unknown",
  rough confidence like 0.3 to 0.5.
- If some items are only partially readable, include the readable portion instead of omitting the item entirely.
- If vertical or rotated text is present, mentally normalize reading direction before extraction.
- For Japanese vertical menu text, prioritize item name extraction over pronunciation/detail quality.
- fullMenu.summary should be very short or empty. Prefer item coverage over prose.

9) Token safety:
- Keep the JSON compact.
- Use short ids like "m1", "m2", "m3".
- tags: 0 to 2 items max.
- If menuCountHint is not "all", spend tokens on recommended items, not fullMenu.
- If menuCountHint is "all", spend most tokens on fullMenu.items, not on descriptions.
- If not all items fit, set fullMenu.truncated=true.
- Keep nulls where schema requires them, but avoid verbose text.
- For difficult or very long menus, prefer many readable names with empty shortDesc and null prices over rich prose.
- Do not spend many tokens trying to explain uncertain items.
- It is better to return minimal valid item objects than to fail the whole JSON.

- If the menu is difficult, dense, handwritten, vertical, or partially occluded, prioritize extraction reliability over completeness, translation quality, and description quality.

Return JSON with EXACT schema:

{
  "isMenu": true,
  "userMessage": "string",
  "outputLanguage": "$outputLang",
  "place": { "name": null, "address": null, "city": null },
  "recommended": [
    {
      "id": "string",
      "nameOriginal": "string",
      "name": "string",
      "originLanguageCode": "string",
      "nameOriginalReading": "string",
      "shortDesc": "string",
      "prices": {
        "small": null,
        "medium": null,
        "large": null,
        "single": null,
        "currency": "ISO 4217 code or null"
      },
      "tags": ["string"],
      "category": "main|side|meal|drink|beverage|unknown",
      "confidence": 0.0
    }
  ],
  "fullMenu": {
    "items": {
      "main": [],
      "side": [],
      "meal": [],
      "drink": [],
      "beverage": [],
      "unknown": []
    },
    "summary": "string",
    "truncated": true
  }
}
''';

    // ✅ 언어별 “한 줄 안내”만 유지 (지원 언어 전부 유지)
    String intro;
    switch (selectedLanguageCode) {
      case 'ko':
        intro = '아래 규칙을 따르고, 반드시 JSON만 출력해. 설명 문단은 절대 쓰지 마.\n';
        break;
      case 'ja':
        intro = '必ずJSONのみを出力してください。説明文は出力しないでください。\n';
        break;
      case 'zh':
      case 'zh-Hans':
        intro = '请只输出JSON，不要输出任何解释性文字。\n';
        break;
      case 'zh-Hant':
        intro = '請只輸出JSON，不要輸出任何說明文字。\n';
        break;
      case 'hi':
        intro = 'केवल JSON आउटपुट करें। कोई व्याख्यात्मक पाठ न लिखें।\n';
        break;
      case 'es':
        intro = 'Devuelve SOLO JSON. No escribas texto explicativo.\n';
        break;
      case 'fr':
        intro = 'Retourne UNIQUEMENT du JSON. Aucun texte explicatif.\n';
        break;
      case 'vi':
        intro = 'Chỉ trả về JSON. Không viết đoạn giải thích.\n';
        break;
      case 'th':
        intro = 'โปรดส่งออกเป็น JSON เท่านั้น ห้ามมีข้อความอธิบาย\n';
        break;
      case 'ar':
        intro = 'أخرج JSON فقط دون أي نص إضافي.\n';
        break;
      case 'bn':
        intro = 'শুধুমাত্র JSON আউটপুট দিন। কোনো ব্যাখ্যামূলক লেখা নয়।\n';
        break;
      case 'ru':
        intro = 'Выводи ТОЛЬКО JSON. Без пояснительного текста.\n';
        break;
      case 'pt':
      case 'pt-BR':
        intro = 'Retorne SOMENTE JSON. Sem texto explicativo.\n';
        break;
      case 'ur':
        intro = 'صرف JSON آؤٹ پٹ کریں، کوئی اضافی متن نہیں۔\n';
        break;
      case 'id':
        intro = 'Keluarkan HANYA JSON. Jangan tulis teks penjelasan.\n';
        break;
      case 'de':
        intro = 'Gib NUR JSON aus. Kein erklärender Text.\n';
        break;
      case 'mr':
        intro = 'फक्त JSON आउटपुट करा. स्पष्टीकरणात्मक मजकूर नको.\n';
        break;
      case 'te':
        intro = 'JSON మాత్రమే ఇవ్వండి. వివరణాత్మక వచనం రాయకండి.\n';
        break;
      case 'tr':
        intro = 'Yalnızca JSON döndür. Açıklama metni yazma.\n';
        break;
      default:
        intro = 'Output ONLY JSON. No explanatory text.\n';
    }

    return intro + base;
  }



  static Future<void> refreshCustomPresetDescriptionFromSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLanguageCode =
        prefs.getString(selectedLanguageCodeKey) ?? 'en';
    final selectedFoodStyle =
        prefs.getString(selectedFoodStyleKey) ?? 'AI recommend';
    final selectedMenuNumber =
        prefs.getString(selectedMenuNumberKey) ?? '1-5';

    final presetDescription = buildPresetDescription(
      selectedLanguageCode: selectedLanguageCode,
      selectedFoodStyle: selectedFoodStyle,
      selectedMenuNumber: selectedMenuNumber,
    );

    await saveCustomPresetDescription(presetDescription);
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
