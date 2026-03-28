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
- Extract menu items from the provided image/OCR text.
- Produce results for the app UI: "Recommended Dishes" chips + optional "Full Menu" preview.

Hard rules:
1) Output language rule:
   - shortDesc, tags MUST be written in outputLanguage = "$outputLang".
   - nameOriginal MUST be the EXACT original text extracted from the image/OCR (do NOT translate).
   - originLanguageCode MUST be the language of nameOriginal (ISO code like ko, en, ja, zh, th...).
- nameOriginal MUST be only the dish/menu item text itself from the image/OCR (do NOT translate).
- Exclude prices, item numbers, bullets, option markers, and surrounding category/header text from nameOriginal.
- originLanguageCode MUST be the language of nameOriginal (ISO code like ko, en, ja, zh, th...).

- nameOriginalReading is for TTS only. Keep it separate from display text.
- nameOriginalReading MUST contain only the pronunciation of the dish name itself.
- NEVER include prices, item numbers, sizes, option markers, punctuation-only tokens, category labels, or translated text in nameOriginalReading.
- For Japanese, prefer hiragana reading in nameOriginalReading when confident.
- Do NOT output Korean pronunciation for Japanese items.
- Do NOT output romaji unless the original itself is already written in romaji.
- If reading is uncertain, set nameOriginalReading="".
- NEVER replace nameOriginal with reading text.

- name MUST be the translated name in outputLanguage. If translation is identical or uncertain, set name = nameOriginal.
2) Never invent items not visible in the image/OCR.
3) If the image is NOT a food menu, return isMenu=false with a short reason and a short userMessage for display.
4) Keep shortDesc to 1–2 sentences max.
5) Use styleHint="$styleHint" only as ranking preference (do NOT hallucinate dietary tags).
6) menuCountHint="$menuCountHint" controls the response compression strategy:
   - "1": return exactly 1 recommended item.
   - "1-3": return up to 3 recommended items.
   - "1-5": return up to 5 recommended items.
   - "all": DO NOT try to return all dishes as detailed structured items.
            For "all", return only 6 recommended items in "recommended",
            and cover the rest mainly in fullMenu.summary.

7) TOKEN SAFETY (VERY IMPORTANT):
   - Keep the entire JSON compact.
   - If the menu is long, DO NOT output every item as structured arrays.
   - Prefer: recommended (structured, detailed) + fullMenu summary (structured text).
   - You must stay within the output limit; if needed, set fullMenu.truncated=true and summarize the rest.
   - If menuCountHint="all", prioritize reliability over completeness.
   - If menuCountHint="all", keep "recommended" very small and move the rest into fullMenu.summary.
   - If menuCountHint="all", fullMenu.items may be sparse or empty; summary coverage is preferred.

8) Tags limit:
   - "tags" MUST contain at most 4 strings per item. (0–4)

9) ID format:
   - "id" MUST be short and unique within this response.
   - Use simple IDs like "m1", "m2", "m3"... (no long UUIDs)

10) Detail quality (IMPORTANT):
   - For EACH recommended item, shortDesc MUST mention:
     (a) ingredients OR cooking method AND (b) flavor profile (e.g., spicy/savory) in 1–2 sentences.
   - Avoid generic phrases like "delicious". Be concrete.

11) FullMenu preview detail rule:
   - In fullMenu.items, for each category include at most 1 item with non-empty shortDesc.
   - All other preview items must set shortDesc="".
   - If menuCountHint="all", you may leave many categories empty and rely on fullMenu.summary instead.

12) FullMenu summary formatting rule (VERY IMPORTANT):
   - fullMenu.summary MUST use this structure in outputLanguage:
     "Main highlights: <A> — <note>; <B> — <note>. Other mains: <list up to 8>.
      Sides highlights: <A> — <note>; <B> — <note>. Other sides: <list up to 8>.
      Drinks highlights: <A> — <note>. Other drinks: <list up to 8>."
   - Each <note> must be 6–14 words describing ingredients/method/flavor (concrete).
   - Do NOT output a plain list only.

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
      "prices": { "small": null, "medium": null, "large": null, "single": null, "currency": "ISO 4217 code like KRW, JPY, USD, EUR, etc. or null" },
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

Full menu output rule:
- Always fill "recommended" as the most reliable top items only.
- Do NOT try to represent the whole menu as structured arrays.
- For fullMenu.items:
  - If the menu is short, you MAY include a small preview.
  - If the menu is long, include only a tiny preview (max 6 items total across all categories).
- If menuCountHint="all", prefer summary coverage over item-by-item structured output.
- Put the rest into fullMenu.summary using the required formatting rule.
- If you omit any items due to length, set fullMenu.truncated=true; otherwise false.

If isMenu=false, return EXACTLY:
{
  "isMenu": false,
  "userMessage": "short display message in outputLanguage",
  "outputLanguage": "$outputLang",
  "reason": "short string"
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
