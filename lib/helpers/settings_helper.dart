import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SettingsHelper {
  static const String _questionKey = 'gpt_question';
  static const String _presetKey = 'preset';
  static const String _engineKey = 'selected_engine';
  static const String _customPresetDescriptionKey = 'custom_preset_description';
  static const String presetKey = _presetKey;
  static const String customPresetDescriptionKey = _customPresetDescriptionKey;
  static const String selectedLanguageCodeKey = 'selectedLanguageCode';
  static const String selectedFoodStyleKey = 'selectedFoodStyle';
  static const String selectedMenuNumberKey = 'selectedMenuNumber';

  static const String foodStyleAiRecommend = 'aiRecommend';
  static const String foodStyleLowFat = 'lowFat';
  static const String foodStyleLowSalt = 'lowSalt';
  static const String foodStyleNutFree = 'nutFree';
  static const String foodStyleSeafood = 'seafood';
  static const String foodStyleMeat = 'meat';
  static const String foodStyleMuslimFriendly = 'muslimFriendly';

  static const List<String> supportedFoodStyleIds = [
    foodStyleAiRecommend,
    foodStyleLowFat,
    foodStyleLowSalt,
    foodStyleNutFree,
    foodStyleSeafood,
    foodStyleMeat,
    foodStyleMuslimFriendly,
  ];

  static String? tryNormalizeFoodStyleId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (supportedFoodStyleIds.contains(trimmed)) return trimmed;

    final labelKey = trimmed.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    switch (labelKey) {
      case 'ai추천':
      case 'ai推荐':
      case 'ai推薦':
      case 'aiのおすすめ':
        return foodStyleAiRecommend;
      case '저지방':
      case '低脂':
      case '低脂肪':
        return foodStyleLowFat;
      case '저염':
      case '低盐':
      case '低鹽':
      case '低塩':
        return foodStyleLowSalt;
      case '견과류제외':
      case '无坚果':
      case '無堅果':
      case 'ナッツフリー':
        return foodStyleNutFree;
      case '해산물':
      case '海鲜':
      case '海鮮':
      case 'シーフード':
        return foodStyleSeafood;
      case '고기':
      case '肉':
      case '肉类':
      case '肉類':
        return foodStyleMeat;
      case '무슬림':
      case '穆斯林':
      case 'ハラル':
      case 'حلال':
        return foodStyleMuslimFriendly;
    }

    final key = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    switch (key) {
      case 'ai':
      case 'airecommend':
      case 'airecommends':
      case 'airecommended':
      case 'recommended':
      case 'recommend':
        return foodStyleAiRecommend;
      case 'lowfat':
      case 'lessfat':
      case 'reducedfat':
        return foodStyleLowFat;
      case 'lowsalt':
      case 'lesssalt':
      case 'lowsodium':
      case 'reducedsodium':
        return foodStyleLowSalt;
      case 'nutfree':
      case 'nutsfree':
      case 'nonut':
      case 'nonuts':
      case 'peanutfree':
        return foodStyleNutFree;
      case 'seafood':
      case 'fish':
      case 'shellfish':
        return foodStyleSeafood;
      case 'meat':
      case 'beef':
      case 'pork':
      case 'chicken':
      case 'lamb':
        return foodStyleMeat;
      case 'muslim':
      case 'halal':
      case 'muslimfriendly':
      case 'halalfriendly':
        return foodStyleMuslimFriendly;
      default:
        return null;
    }
  }

  static String normalizeFoodStyleId(String raw) {
    return tryNormalizeFoodStyleId(raw) ?? foodStyleAiRecommend;
  }

  static String defaultFoodStyleLabel(String styleId) {
    switch (normalizeFoodStyleId(styleId)) {
      case foodStyleLowFat:
        return 'Low Fat';
      case foodStyleLowSalt:
        return 'Low salt';
      case foodStyleNutFree:
        return 'Nut-free';
      case foodStyleSeafood:
        return 'Seafood';
      case foodStyleMeat:
        return 'Meat';
      case foodStyleMuslimFriendly:
        return 'Muslim friendly';
      case foodStyleAiRecommend:
      default:
        return 'AI recommend';
    }
  }

  static String normalizeMenuCountHint(String raw) {
    final trimmed = raw.trim();
    final key = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    switch (key) {
      case '1':
      case 'one':
        return '1';
      case '1-3':
      case '1to3':
      case '1~3':
        return '1-3';
      case '1-5':
      case '1to5':
      case '1~5':
        return '1-5';
      case 'all':
      case 'full':
      case 'fullmenu':
        return 'all';
      default:
        return '1-5';
    }
  }

  static bool hasSavedPresetSettings(SharedPreferences prefs) {
    return prefs.containsKey(_presetKey) ||
        prefs.containsKey(_customPresetDescriptionKey) ||
        prefs.containsKey(selectedLanguageCodeKey) ||
        prefs.containsKey(selectedFoodStyleKey) ||
        prefs.containsKey(selectedMenuNumberKey);
  }

  static String resolveSupportedLanguageCode({
    required String systemLocaleCode,
    required Iterable<String> supportedLanguageCodes,
    String? storedLanguageCode,
    String fallbackLanguageCode = 'en',
  }) {
    final supported = supportedLanguageCodes.toSet();

    String normalize(String code) => code.trim().replaceAll('_', '-');

    String? matchSupported(String? raw) {
      if (raw == null) return null;

      final normalized = normalize(raw);
      if (normalized.isEmpty) return null;
      if (supported.contains(normalized)) return normalized;

      final lowerNormalized = normalized.toLowerCase();
      for (final code in supported) {
        if (code.toLowerCase() == lowerNormalized) return code;
      }

      final languageOnly = normalized.split('-').first;
      if (languageOnly.isEmpty) return null;

      for (final code in supported) {
        if (code.toLowerCase() == languageOnly.toLowerCase()) return code;
      }

      return null;
    }

    return matchSupported(storedLanguageCode) ??
        matchSupported(systemLocaleCode) ??
        (supported.contains(fallbackLanguageCode)
            ? fallbackLanguageCode
            : supported.isNotEmpty
                ? supported.first
                : fallbackLanguageCode);
  }

  static String _resolveFoodStyleLabel({
    required String rawStyle,
    required String styleId,
    String? selectedFoodStyleLabel,
  }) {
    final explicit = selectedFoodStyleLabel?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final raw = rawStyle.trim();
    if (raw.isNotEmpty && !supportedFoodStyleIds.contains(raw)) {
      return raw;
    }
    return defaultFoodStyleLabel(styleId);
  }

  static String _foodStyleRules(String styleId) {
    switch (styleId) {
      case foodStyleLowFat:
        return '''
- Prefer grilled, steamed, clear-broth, vegetable-forward, and lean-protein items when visible.
- Treat fried items, cream, butter, visibly oily cuts, and heavy sauces as caution.
- Do not state exact fat or nutrition values. Say this is a photo/OCR-based estimate.''';
      case foodStyleLowSalt:
        return '''
- Treat salty broth, pickles, fermented seafood, soy sauce, soybean paste, and sauce-heavy items as caution.
- Mention practical options when reasonable, such as asking for sauce on the side or eating less broth.
- Do not state exact sodium content. Say this is a photo/OCR-based estimate.''';
      case foodStyleNutFree:
        return '''
- If nuts, peanuts, cashews, almonds, sesame, nut-like toppings, sauces, desserts, or unclear garnish may be present, mark caution.
- There is no guarantee from an image or OCR. Mention cross-contamination risk.
- Use requiresStaffCheck=true aggressively and tell the user to staff check ingredients before ordering.''';
      case foodStyleSeafood:
        return '''
- Prefer items visibly or textually based on fish, shellfish, shrimp, crab, squid, seafood broth, or seafood sauce.
- Separate clear seafood matches from caution cases where seafood broth or sauce is only possible.
- Do not guarantee allergy safety from the image/OCR alone.''';
      case foodStyleMeat:
        return '''
- Prefer meat-centered items with visible or textual beef, pork, chicken, lamb, or other animal protein.
- If broth or sauce may contain meat but is uncertain, label it as an estimate rather than a fact.
- Rank robust meat/protein-centered dishes above vague or side-only dishes.''';
      case foodStyleMuslimFriendly:
        return '''
- Never claim halal certification unless exact visible halal certification text/logo is present.
- If pork, bacon, ham, sausage, lard, alcohol, mirin, sake, wine sauce, or similar terms appear, mark caution or notRecommended.
- Chicken, beef, seafood, and vegetable items still need staff check when halal status is unknown.
- Use requiresStaffCheck=true aggressively.
- There is no guarantee from an image or OCR. Include a no halal certification claim disclaimer when certification is not visible.''';
      case foodStyleAiRecommend:
      default:
        return '''
- Recommend by general popularity, representative local dishes, visual certainty, and tourist friendliness.
- Prefer items with clear names and enough visible/OCR evidence over uncertain items.
- Keep safety and allergy language conservative when ingredients are unclear.''';
    }
  }

  static String _buildFoodStylePromptSection({
    required String styleId,
    required String label,
  }) {
    return '''
Food style preset:
- selectedFoodStyle id: "$styleId"
- selectedFoodStyle label: "$label"
- This style is a recommendation preference, diet lens, or safety lens. It is NOT a menu category.
- Rank and explain menu items by how well they fit selectedFoodStyle="$styleId".
- Do not hallucinate ingredients, nutrition facts, allergens, halal status, or certifications.
- Use "recommended", "caution", "notRecommended", or "unknown" in foodStyleFit.
- Set styleMatched=true only when visible text/OCR/image evidence supports the match.
- styleFitScore must be 0.0 to 1.0 and reflect fit after caution/safety concerns.
- Put concise evidence in matchedEvidence and concise risk text in cautionReason.
- Use sourceImageIndexes when multiple images are provided; use zero-based indexes when knowable.

Style-specific rules:
${_foodStyleRules(styleId)}

Recommendation ordering:
- If selectedFoodStyle is present, sort recommended by the selected food style.
- Prefer high styleFitScore and low caution risk.
- For nutFree and muslimFriendly, do not push uncertain safety-sensitive items to the top just because they look appealing.
- For safety-sensitive styles, use requiresStaffCheck=true whenever ingredients, cross-contamination, or certification status is uncertain.

Safety wording:
- These are photo/OCR-based estimates, not medical, allergy, nutrition, religious, or certification guarantees.
- For allergy or religious-diet decisions, tell the user to confirm with restaurant staff.
''';
  }

  static String _foodStyleSummarySchema({
    required String styleId,
    required String label,
  }) {
    return '''
  "selectedFoodStyle": "$styleId",
  "selectedFoodStyleLabel": "$label",
  "foodStyleApplied": true,
  "foodStyleSummary": {
    "styleId": "$styleId",
    "matchedItemCount": 0,
    "cautionItemCount": 0,
    "notRecommendedItemCount": 0,
    "topRecommendedItemIndexes": [0],
    "confidence": 0.0,
    "reason": "string",
    "disclaimer": "string"
  },''';
  }

  static String _foodStyleItemSchema() {
    return '''
      "foodStyleFit": "recommended|caution|notRecommended|unknown",
      "styleMatched": true,
      "styleFitScore": 0.0,
      "recommendationRank": 1,
      "recommendationReason": "string",
      "matchedEvidence": ["string"],
      "cautionReason": "string",
      "dietaryWarnings": ["string"],
      "allergyHints": ["string"],
      "requiresStaffCheck": false,
      "sourceImageIndexes": [0]''';
  }

  static String _fullMenuSchemaFor(String menuCountHint) {
    if (menuCountHint != 'all') {
      return '''

}

Compact fullMenu rule:
- menuCountHint="$menuCountHint"; prioritize recommended/items and compact JSON.
- Omit fullMenu, or return only a minimal empty fullMenu placeholder if needed.
- Do not spend tokens building the entire full menu for this mode.''';
    }

    return '''
,

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
- menuCountHint="all"; fullMenu is REQUIRED and is the main output area.
- Fill fullMenu.items.main/side/meal/drink/beverage/unknown with remaining non-recommended items.
- Never repeat any recommended item in fullMenu.items.
- Use most remaining tokens for fullMenu.items and keep descriptions short or empty.
- fullMenu.summary should be very short or empty. Prefer item coverage over prose.
- If not all items fit, set fullMenu.truncated=true; otherwise false.''';
  }

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
    return prefs.getString(_customPresetDescriptionKey) ??
        'No description available';
  }

  // Get question by preset id
  static Future<String> getQuestionByPreset(int presetId) async {
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
    String? selectedFoodStyleLabel,
  }) {
    debugPrint(
        'Creating preset description for language code: $selectedLanguageCode');

    final outputLang = selectedLanguageCode;
    final styleId = normalizeFoodStyleId(selectedFoodStyle);
    final styleLabel = _resolveFoodStyleLabel(
      rawStyle: selectedFoodStyle,
      styleId: styleId,
      selectedFoodStyleLabel: selectedFoodStyleLabel,
    );
    final menuCountHint = normalizeMenuCountHint(selectedMenuNumber);
    final foodStyleSection = _buildFoodStylePromptSection(
      styleId: styleId,
      label: styleLabel,
    );
    final foodStyleSummarySchema = _foodStyleSummarySchema(
      styleId: styleId,
      label: styleLabel,
    );
    final foodStyleItemSchema = _foodStyleItemSchema();
    final fullMenuSchema = _fullMenuSchemaFor(menuCountHint);

    // ✅ 공통 베이스(스키마/규칙) — 영어로 고정해도 outputLanguage로 결과 언어는 맞춰짐
    final base = '''
You MUST output ONLY valid JSON (no extra text, markdown, code fences, explanations, or RECOMMEND line).

Goal:
- Extract menu items from the provided image/OCR text.
- Produce results for the app UI: "Recommended Dishes" chips + optional "Full Menu" preview.

$foodStyleSection

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
5) Food style rule:
   - selectedFoodStyle="$styleId" and selectedFoodStyleLabel="$styleLabel".
   - Apply this as the recommendation/ranking standard, not as a simple category label.
   - Do NOT hallucinate dietary tags, allergy safety, nutrition values, halal status, or certifications.
6) menuCountHint="$menuCountHint" controls recommended count only:
   - "1": exactly 1 recommended item. fullMenu should be empty or minimal.
   - "1-3": up to 3 recommended items. fullMenu should be empty or minimal.
   - "1-5": up to 5 recommended items. fullMenu should be empty or minimal.
   - "all": recommended may be 1-4 items only. Use most remaining tokens for fullMenu.items.
   - For difficult menus, it is better to return fewer recommended items and more fullMenu items.

7) TOKEN SAFETY (VERY IMPORTANT):
   - Keep the entire JSON compact.
   - Use short ids like "m1", "m2", "m3".
   - If menuCountHint is not "all", spend tokens on recommended items, not fullMenu.
   - If menuCountHint is "all", spend most tokens on fullMenu.items, not on descriptions.
   - If not all items fit, set fullMenu.truncated=true.
   - Keep nulls where schema requires them, but avoid verbose text.
   - For difficult or very long menus, prefer many readable names with empty shortDesc and null prices over rich prose.
   - Do not spend many tokens trying to explain uncertain items.
   - It is better to return minimal valid item objects than to fail the whole JSON.
   - If the menu is difficult, dense, handwritten, vertical, or partially occluded, prioritize extraction reliability over completeness, translation quality, and description quality.

8) Tags limit:
   - "tags" MUST contain at most 4 strings per item. (0–4)

9) ID format:
   - "id" MUST be short and unique within this response.
   - Use simple IDs like "m1", "m2", "m3"... (no long UUIDs)

10) Detail quality (IMPORTANT):
   - For EACH recommended item, shortDesc MUST mention:
     (a) ingredients OR cooking method AND (b) flavor profile (e.g., spicy/savory) in 1–2 sentences.
   - Avoid generic phrases like "delicious". Be concrete.

11) Full menu and multi-scan:
   - If menuCountHint is not "all", recommended/items are primary and fullMenu should be omitted or minimal.
   - If menuCountHint is "all", fullMenu is the categorized menu extraction area.
   - The parser can handle missing fullMenu; do not force fullMenu in compact recommendation modes.
   - Merge duplicate menu items across OCR, repeated headers, numbering, prices, spacing, punctuation, and multiple images.
   - For multiple images, fill sourceImageIndexes where practical and focus on the consolidated recommendation result.
   - Do not describe every image at length when a compact recommendation answer is requested.
   - For difficult menus (handwritten, vertical, dense, low-contrast, partially occluded), prioritize readable item names over rich prose.

Return JSON with EXACT schema:

{
  "isMenu": true,
  "userMessage": "string",
  "outputLanguage": "$outputLang",
  $foodStyleSummarySchema
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
      "confidence": 0.0,
$foodStyleItemSchema
    }
  ]$fullMenuSchema

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
        prefs.getString(selectedFoodStyleKey) ?? foodStyleAiRecommend;
    final selectedMenuNumber = prefs.getString(selectedMenuNumberKey) ?? '1-5';

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
