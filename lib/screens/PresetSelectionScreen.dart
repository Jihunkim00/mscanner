import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/settings_helper.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:adaptive_theme/adaptive_theme.dart'; // Import for adaptive theme
import 'package:mscanner/screens/TutorialCamera_Screen.dart';
import '/screens/log_service.dart';


// 언어 정보를 담는 클래스
class Language {
  final String code;
  final String name;

  Language({required this.code, required this.name});
}

class PresetSelectionScreen extends StatefulWidget {
  final bool isFirstLogin;

  const PresetSelectionScreen({Key? key, this.isFirstLogin = false}) : super(key: key);

  @override
  _PresetSelectionScreenState createState() => _PresetSelectionScreenState();
}



class _PresetSelectionScreenState extends State<PresetSelectionScreen> {
  String _selectedLanguageCode = 'en'; // 기본값을 'en' (English)으로 설정
  String _selectedFoodStyle = 'AI recommend';
  String _selectedMenuNumber = '1-5';
  List<Language> languages = [];

  Timer? _inactivityTimer;
  bool _isPresetSaved = false; // ✅ 저장 플래그 추가

  bool _isSaving = false; // ✅ 중복 저장 방지용 플래그 ← 여기에 추가하세요

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: 3), () {
      if (widget.isFirstLogin && !_isPresetSaved) {
      _savePresetAndNavigate(); // 자동 저장
        }
    });
  }

  void _resetInactivityTimer() {
    if (widget.isFirstLogin && !_isPresetSaved) {
      _startInactivityTimer(); // 사용자 반응이 있으면 타이머 리셋
    }
  }


  // 언어 목록을 Language 객체 리스트로 관리
  List<Language> getLanguages(AppLocalizations localizations) {
    List<Language> langs = [
      Language(code: 'en', name: localizations.languageEnglish),
      Language(code: 'ko', name: localizations.languageKorean),
      Language(code: 'ja', name: localizations.languageJapanese),
      Language(code: 'zh', name: localizations.languageChinese),
      Language(code: 'zh-Hans', name: localizations.languageSimplifiedChinese),
      Language(code: 'zh-Hant', name: localizations.languageTraditionalChinese),
      Language(code: 'hi', name: localizations.languageHindi),
      Language(code: 'es', name: localizations.languageSpanish),
      Language(code: 'fr', name: localizations.languageFrench),
      Language(code: 'vi', name: localizations.languageVietnamese),
      Language(code: 'th', name: localizations.languageThai),
      Language(code: 'ar', name: localizations.languageArabic),
      Language(code: 'bn', name: localizations.languageBengali),
      Language(code: 'ru', name: localizations.languageRussian),
      Language(code: 'pt', name: localizations.languagePortuguese),
      Language(code: 'pt-BR', name: localizations.languagePortugueseBrazil),
      Language(code: 'ur', name: localizations.languageUrdu),
      Language(code: 'id', name: localizations.languageIndonesian),
      Language(code: 'de', name: localizations.languageGerman),
      Language(code: 'mr', name: localizations.languageMarathi),
      Language(code: 'te', name: localizations.languageTelugu),
      Language(code: 'tr', name: localizations.languageTurkish),
    ];

    return langs;
  }

  List<String> getFoodStyles(AppLocalizations localizations) {
    return [
      localizations.foodStyleAIRecommend,
      localizations.foodStyleLowFat,
      localizations.foodStyleLowSalt,
      localizations.foodStyleNutFree,
      localizations.foodStyleSeafood,
      localizations.foodStyleMeat,
      localizations.foodStyleMuslim,
    ];
  }

  List<String> getMenuNumbers(AppLocalizations localizations) {
    return [
      localizations.menuNumber1,
      localizations.menuNumber1to3,
      localizations.menuNumber1to5,
      localizations.menuNumberAll,
    ];
  }


  @override
  void initState() {
    super.initState();
    // 첫 로그인 시 자동 저장 타이머만 설정
    if (widget.isFirstLogin) _startInactivityTimer();

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 2) 여기서 곧바로 로컬라이즈된 언어 리스트 세팅
    final loc = AppLocalizations.of(context)!;
    languages = getLanguages(loc);

    // 3) 시스템 로케일 기반 설정 불러오기
    _loadSettings(Localizations.localeOf(context).toLanguageTag());
  }

// ... build() 에서도 안전하게 languages 사용 가능


  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }


  Future<void> _loadSettings(String systemLocaleCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _selectedLanguageCode = prefs.getString('selectedLanguageCode') ??
          (languages.any((lang) => lang.code == systemLocaleCode)
              ? systemLocaleCode
              : 'en');
      _selectedFoodStyle = prefs.getString('selectedFoodStyle') ?? 'AI recommend';
      _selectedMenuNumber = prefs.getString('selectedMenuNumber') ?? '1-5';
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final brightness = AdaptiveTheme.of(context).brightness;

    final foodStyles = getFoodStyles(localizations);
    final menuNumbers = getMenuNumbers(localizations);

    // 유효한 선택값인지 확인
    if (!languages.any((lang) => lang.code == _selectedLanguageCode)) {
      _selectedLanguageCode = languages.isNotEmpty ? languages[0].code : 'en';
    }
    if (!foodStyles.contains(_selectedFoodStyle)) {
      _selectedFoodStyle = foodStyles.isNotEmpty ? foodStyles[0] : 'AI recommend';
    }
    if (!menuNumbers.contains(_selectedMenuNumber)) {
      _selectedMenuNumber = menuNumbers.isNotEmpty ? menuNumbers[0] : '1-5';
    }

    final Color backgroundColor = brightness == Brightness.dark ? Colors.black : Color(0xFFEFEFF4);
    final Color textColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    final TextStyle headingStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textColor,
      fontFamily: 'SFProText',
    );
    final TextStyle itemStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textColor,
      fontFamily: 'SFProText',
    );
    final TextStyle descriptionStyle = TextStyle(
      fontFamily: 'SFProText',
      fontSize: 12,
      color: brightness == Brightness.dark ? Colors.white24 : Colors.black45, // 다크 모드와 라이트 모드에 따라 다른 색상 적용
    );

    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _resetInactivityTimer,
        onPanDown: (_) => _resetInactivityTimer(),
    child: Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AdaptiveTheme.of(context).brightness == Brightness.dark
            ? Colors.black // 다크 모드일 때 검은색
            : Color(0xFFEFEFF4), // 라이트 모드일 때 기존 본문 배경색
        elevation: 0, // 그림자 없애기
        leading: CupertinoNavigationBarBackButton(
          color: AdaptiveTheme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown(
                  localizations.targetLanguage,
                  languages,
                  _selectedLanguageCode,
                      (value) => setState(() => _selectedLanguageCode = value),
                  itemStyle,
                  headingStyle,
                ),
                // 설명 텍스트에 패딩 추가
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10.0), // 좌우 패딩 설정
                  child: Text(
                    localizations?.languagesdescprition ?? 'Take a photo of a food item or menu, and select the language for the output',
                    style: descriptionStyle,
                  ),
                ),
                SizedBox(height: 20),
                _buildDropdown(
                  localizations.foodStyle,
                  foodStyles,
                  _selectedFoodStyle,
                      (value) => setState(() => _selectedFoodStyle = value),
                  itemStyle,
                  headingStyle,
                ),
                // 설명 텍스트에 패딩 추가
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10.0), // 좌우 패딩 설정
                  child: Text(
                    localizations?.fooddescprition ?? 'Please select a diet or meal plan. The AI will provide recommendations and explanations based on your selection',
                    style: descriptionStyle,
                  ),
                ),
                SizedBox(height: 20),
                _buildDropdown(
                  localizations.foodMenuMaxNumber,
                  menuNumbers,
                  _selectedMenuNumber,
                      (value) => setState(() => _selectedMenuNumber = value),
                  itemStyle,
                  headingStyle,
                ),
                // 설명 텍스트에 패딩 추가
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10.0), // 좌우 패딩 설정
                  child: Text(
                    localizations?.menudescribe ?? '화면에 표시될 음식 메뉴의 개수를 선택해 주세요. 선택한 숫자가 적을수록 설명이 자세해집니다', // 설명 텍스트, 원하는 내용으로 수정하세요
                    style: descriptionStyle,
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : Colors.white,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey,
                      minimumSize: Size(40, 40),
                      textStyle: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                      ),
                    ),
                    child: Text(localizations.saveAndContinue),
                    onPressed: _isSaving ? null : _savePresetAndNavigate,


                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildDropdown(
      String title, List<dynamic> options, String selectedValue,
      ValueChanged<String> onChanged, TextStyle itemStyle, TextStyle headingStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: headingStyle),
        SizedBox(height: 10),
        Container(
          height: 60, // 드롭다운 높이를 조절하여 스크롤 가능하게 설정
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            color: AdaptiveTheme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DropdownButtonFormField<String>(
              value: selectedValue,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
              items: options.map((dynamic option) {
                if (option is Language) {
                  return DropdownMenuItem<String>(
                    value: option.code,
                    child: Text(option.name, style: itemStyle),
                  );
                } else if (option is String) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, style: itemStyle),
                  );
                } else {
                  return DropdownMenuItem<String>(
                    value: '',
                    child: Text('', style: itemStyle),
                  );
                }
              }).toList(),
              decoration: InputDecoration(
                filled: true,
                fillColor: AdaptiveTheme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: AdaptiveTheme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              iconEnabledColor: itemStyle.color,
            ),
          ),
        ),
      ],
    );
  }

  void _savePresetAndNavigate() async {
    if (_isSaving) return; // ❗ 중복 실행 방지
    setState(() {
      _isSaving = true; // ❗ 한번 실행되면 true로 바꿔서 중복 차단
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguageCode', _selectedLanguageCode);
    await prefs.setString('selectedFoodStyle', _selectedFoodStyle);
    await prefs.setString('selectedMenuNumber', _selectedMenuNumber);

    print('Saved Language Code: $_selectedLanguageCode');
    print('Saved Food Style: $_selectedFoodStyle');
    print('Saved Menu Number: $_selectedMenuNumber');

    // ✅ 첫 로그인(튜토리얼) 아닐 때만 로그
    if (!widget.isFirstLogin) {
      try {
        final count = [
          _selectedLanguageCode,
          _selectedFoodStyle,
          _selectedMenuNumber,
        ].where((e) => e.isNotEmpty).length;

        await LogService().logPresetSave(
          fieldsCount: count,          // 예: 3
          presetType: 'manual_save',   // 원하는 라벨 (e.g., 'manual_save')
        );
      } catch (e) {
        debugPrint('[LogService] logPresetSave failed: $e');
      }
    }

    final preset = _createPresetDescription();
    await SettingsHelper.saveCustomPresetDescription(preset);

    // 확인을 위해 바로 값을 가져와서 출력
    final savedLanguageCode =
        prefs.getString('selectedLanguageCode') ?? 'Not found';
    final savedFoodStyle =
        prefs.getString('selectedFoodStyle') ?? 'Not found';
    final savedMenuNumber =
        prefs.getString('selectedMenuNumber') ?? 'Not found';

    print('Loaded Language Code: $savedLanguageCode');
    print('Loaded Food Style: $savedFoodStyle');
    print('Loaded Menu Number: $savedMenuNumber');

    if (!widget.isFirstLogin) {
      // 첫 로그인(튜토리얼) 아닐 때만 토스트
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preset saved!'),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }

    // 1초 딜레이 후 화면 전환
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    if (widget.isFirstLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TutorialCameraScreen()),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }


  String _createPresetDescription() {
    print('Creating preset description for language code: $_selectedLanguageCode');

    final outputLang = _selectedLanguageCode;      // 결과 언어
    final styleHint = _selectedFoodStyle;          // 식단/스타일 힌트(정렬 선호)
    final menuCountHint = _selectedMenuNumber;     // 추천 개수 힌트

    // ✅ 공통 베이스(스키마/규칙) — 영어로 고정해도 outputLanguage로 결과 언어는 맞춰짐
    final base = '''
You MUST output in TWO phases, in this exact order:
PHASE 1) Output exactly ONE line (no extra lines):
RECOMMEND: <dish1> | <dish2> | <dish3>
- Use translated names in outputLanguage = "$outputLang" (if uncertain, use original).
- No extra text.

PHASE 2) Then output ONLY valid JSON (no extra text, markdown, code fences, or explanations).

Goal:
- Extract menu items from the provided image/OCR text.
- Produce results for the app UI: "Recommended Dishes" chips + optional "Full Menu" preview.

Hard rules:
1) Output language rule:
   - shortDesc, tags MUST be written in outputLanguage = "$outputLang".
   - nameOriginal MUST be the EXACT original text extracted from the image/OCR (do NOT translate).
   - name MUST be the translated name in outputLanguage. If translation is identical or uncertain, set name = nameOriginal.
2) Never invent items not visible in the image/OCR.
3) If the image is NOT a food menu, return isMenu=false with a short reason.
4) Keep shortDesc to 1–2 sentences max.
5) Use styleHint="$styleHint" only as ranking preference (do NOT hallucinate dietary tags).
6) menuCountHint="$menuCountHint" controls ONLY the "recommended" list size:
   - "1": 1 item
   - "1-3": up to 3 items
   - "1-5": up to 5 items
   - "all": up to 6 items

7) TOKEN SAFETY (VERY IMPORTANT):
   - Keep the entire JSON compact.
   - If the menu is long, DO NOT output every item as structured arrays.
   - Prefer: recommended (structured, detailed) + fullMenu summary (structured text).
   - You must stay within the output limit; if needed, set fullMenu.truncated=true and summarize the rest.

8) Tags limit:
   - "tags" MUST contain at most 5 strings per item. (0–5)

9) ID format:
   - "id" MUST be short and unique within this response.
   - Use simple IDs like "m1", "m2", "m3"... (no long UUIDs)

10) Detail quality (IMPORTANT):
   - For EACH recommended item, shortDesc MUST mention:
     (a) ingredients OR cooking method AND (b) flavor profile (e.g., spicy/savory) in 1–2 sentences.
   - Avoid generic phrases like "delicious". Be concrete.

11) FullMenu preview detail rule:
   - In fullMenu.items, for each category include at most 2 items with non-empty shortDesc.
   - All other items must set shortDesc="" to save tokens.

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
  "outputLanguage": "$outputLang",
  "place": { "name": null, "address": null, "city": null },

  "recommended": [
    {
      "id": "string",
      "nameOriginal": "string",
      "name": "string",
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
- Always fill "recommended" as structured items (most detailed).
- For fullMenu.items:
  - If the menu is short, you MAY include more items.
  - If the menu is long, include ONLY a small preview per category (max 12 items total across all categories).
- Put the rest into fullMenu.summary using the required formatting rule.
- If you omit any items due to length, set fullMenu.truncated=true; otherwise false.

If isMenu=false, return EXACTLY:
{
  "isMenu": false,
  "outputLanguage": "$outputLang",
  "reason": "short string"
}
''';

    // ✅ 언어별 “한 줄 안내”만 유지 (지원 언어 전부 유지)
    String intro;
    switch (_selectedLanguageCode) {
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

}
