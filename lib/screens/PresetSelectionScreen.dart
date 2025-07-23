import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/settings_helper.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:adaptive_theme/adaptive_theme.dart'; // Import for adaptive theme
import 'package:mscanner/screens/TutorialCamera_Screen.dart';


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

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguageCode', _selectedLanguageCode);
    await prefs.setString('selectedFoodStyle', _selectedFoodStyle);
    await prefs.setString('selectedMenuNumber', _selectedMenuNumber);

    print('Saved Language Code: $_selectedLanguageCode');
    print('Saved Food Style: $_selectedFoodStyle');
    print('Saved Menu Number: $_selectedMenuNumber');

    String preset = _createPresetDescription();
    await SettingsHelper.saveCustomPresetDescription(preset);

    // 확인을 위해 바로 값을 가져와서 출력
    String savedLanguageCode = prefs.getString('selectedLanguageCode') ?? 'Not found';
    String savedFoodStyle = prefs.getString('selectedFoodStyle') ?? 'Not found';
    String savedMenuNumber = prefs.getString('selectedMenuNumber') ?? 'Not found';

    print('Loaded Language Code: $savedLanguageCode');
    print('Loaded Food Style: $savedFoodStyle');
    print('Loaded Menu Number: $savedMenuNumber');

    if (!widget.isFirstLogin) { // 첫 로그인 (튜토리얼)이 아닐 때만
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preset saved!'),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }




    // 1초 딜레이 후 홈 화면으로 전환
    await Future.delayed(Duration(seconds: 1));

    if (widget.isFirstLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TutorialCameraScreen()),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  String _createPresetDescription() {
    print('Creating preset description for language code: $_selectedLanguageCode');
    switch (_selectedLanguageCode) {
      case 'ko':
        return "메뉴 전체의 개요 설명을 실시한다. 이 사진에 포함된 음식 메뉴를 ${_selectedFoodStyle} 순서 대로하며 사진상 ${_selectedMenuNumber}가지 메뉴를 선택하여 음식의 이름을 사진의 원어와 한글 발음으로 제공하고 내용을 검색 요약하여 설명을 출력 답변은 총 500문자 정도로 정리 제공된 사진외의 추측성 메뉴와 설명은 하지 말고 음식 메뉴판이 아닌 경우 아니라고 표시 음식 메뉴가 아니라 음식 사진의 경우 음식을 분석여 이름 칼로리 대략적 성분 간략한 성명을 해줘 ";
      case 'ja':
        return "メニュー全体の概要説明を行う。この写真に含まれている食品メニューを${_selectedFoodStyle}の順に並べ、写真上${_selectedMenuNumber}のメニューを選択して食べ物の名前を写真の原語と日本語の発音で提供し、内容を検索要約して説明を出力回答は合計500文字程度にまとめられた写真以外の推測性メニューと説明はしないで食べ物メニュー版でない場合ではないと表示. メニューではなく料理の写真の場合は、料理を分析して、名前、カロリー、おおよその成分、簡単な説明を提供してください.";
      case 'zh':
        return "给出整个菜单的概述 ${_selectedFoodStyle}此照片中包含的菜单顺序，选择照片中的1到${_selectedMenuNumber}个菜单，提供照片的原语言和中文发音的食物名称，搜索内容，总结内容，并输出解释 答案总共大约500个字符, 如果这是一张食物照片而不是菜单，请分析食物并提供其名称、热量、大致成分和简要描述。";
      case 'zh-Hans':
        return "提供整个菜单的概览。照片中包含的食物菜单按 ${_selectedFoodStyle} 的顺序排列，照片中选择 ${_selectedMenuNumber} 菜单，并以照片的原始语言和中文（简体）发音提供食物名称。总共 500 个搜索、摘要和描述输出。除提供的照片外，请勿提供推测性菜单或描述。如果不是食物菜单，请注明 否。 如果这是一张食物照片而不是菜单，请分析食物并提供其名称、热量、大致成分和简要描述。";
      case 'zh-Hant':
        return "提供整個菜單的概覽。此照片中包含的食物選單按${_selectedFoodStyle}的順序排列，並且在照片中選擇了${_selectedMenuNumber}菜單。 ，總共 500 條回复，除了所提供的照片之外，請不要提供推測性的菜單或描述。如果不是食物菜單，請註明「否」,如果這是一張食物照片而不是菜單，請分析食物並提供其名稱、熱量、大致成分和簡要描述。 ";
      case 'hi':
        return "संपूर्ण मेनू का एक सिंहावलोकन दें। ${_selectedFoodStyle} इस फोटो में शामिल भोजन मेनू के अनुशंसित क्रम का पालन करता है, फोटो में ${_selectedMenuNumber} मेनू का चयन करता है, मूल भाषा में भोजन का नाम और फोटो का हिंदी उच्चारण प्रदान करता है, सामग्री की खोज करता है, सारांशित करता है सामग्री, और विवरण आउटपुट करता है। उत्तर कुल मिलाकर लगभग 500 अक्षर का होना चाहिए। प्रदान की गई तस्वीरों के अलावा काल्पनिक मेनू या विवरण प्रदान न करें, और यदि यह भोजन मेनू नहीं है तो 'नहीं' बताएं।, अगर यह मेनू की बजाय भोजन की तस्वीर है, तो भोजन का विश्लेषण करें और इसका नाम कैलोरी अनुमानित घटक और एक संक्षिप्त विवरण प्रदान करें।";
      case 'es':
        return "Brinde una descripción general de todo el menú. ${_selectedFoodStyle} sigue el orden recomendado de los menús de comida incluidos en esta foto, selecciona de ${_selectedMenuNumber} menús en la foto, proporciona el nombre de la comida en el idioma original de la foto y la pronunciación en español, busca el contenido, resume el contenido y genera una descripción La respuesta debe tener aproximadamente 500 caracteres en total. No proporcione menús especulativos ni descripciones distintas a las fotografías proporcionadas, e indique no si no es un menú de comida. Si es una foto de comida en lugar de un menú, analice la comida y proporcione su nombre, calorías, ingredientes aproximados y una breve descripción.";
      case 'fr':
        return "Donnez un aperçu de l'ensemble du menu. ${_selectedFoodStyle} suit l'ordre recommandé des menus inclus dans cette photo, sélectionne ${_selectedMenuNumber} menus dans la photo, fournit le nom de la nourriture dans la langue d'origine de la photo et la prononciation en français, recherche le contenu, résume le contenu et génère une explication. La réponse doit comporter environ 500 caractères au total. Ne fournissez pas de menus ou de descriptions spéculatifs autres que les photos fournies, et indiquez non s'il ne s'agit pas d'un menu alimentaire, S'il s'agit d'une photo de nourriture et non d'un menu, analysez la nourriture et fournissez son nom, ses calories, ses ingrédients approximatifs et une brève description.";
      case 'vi':
        return "Cung cấp cái nhìn tổng quan về toàn bộ thực đơn. ${_selectedFoodStyle} theo thứ tự các thực đơn thực phẩm được đề xuất trong bức ảnh này, chọn ${_selectedMenuNumber} thực đơn trong ảnh, cung cấp tên món ăn bằng ngôn ngữ gốc và cách phát âm bằng tiếng Việt của bức ảnh, tìm kiếm nội dung, tóm tắt nội dung và xuất ra một giải thích Câu trả lời phải có khoảng 500 ký tự. Đừng cung cấp các thực đơn hoặc mô tả suy đoán khác với các bức ảnh đã cung cấp, và chỉ ra không nếu nó không phải là thực đơn thực phẩm, Nếu đây là ảnh món ăn thay vì thực đơn, hãy phân tích món ăn và cung cấp tên, lượng calo, thành phần ước tính và một mô tả ngắn gọn.";
      case 'th':
        return "ให้ภาพรวมของเมนูทั้งหมด ${_selectedFoodStyle} ปฏิบัติตามลำดับของเมนูอาหารที่รวมอยู่ในภาพนี้ เลือกเมนู ${_selectedMenuNumber} รายการในภาพ ให้ชื่ออาหารในภาษาต้นฉบับของภาพและการออกเสียงเป็นภาษาไทย ค้นหาเนื้อหา สรุปเนื้อหา และสร้างคำอธิบาย คำตอบควรมีประมาณ 500 ตัวอักษร อย่าให้เมนูหรือคำอธิบายที่คาดเดาได้นอกเหนือจากรูปภาพที่ให้ไว้ และระบุว่าไม่ใช่เมนูอาหาร หากนี่เป็นภาพอาหารไม่ใช่เมนู ให้วิเคราะห์อาหารและระบุชื่อ แคลอรี่ ส่วนผสมโดยประมาณ และคำอธิบายสั้น ๆ.";
      case 'ar':
        return "تقديم لمحة عامة عن القائمة بأكملها. ${_selectedFoodStyle} يتبع ترتيب القوائم الموصى بها في هذه الصورة، يختار ${_selectedMenuNumber} قائمة من الصورة، يوفر اسم الطعام باللغة الأصلية للصورة والنطق بالعربية، يبحث عن المحتويات، يلخص المحتويات، ويصدر تفسيرًا. يجب أن تكون الإجابة حوالي 500 حرفًا إجمالاً. لا تقدم قوائم أو وصفات تخمينية بخلاف الصور المقدمة، وتوضح لا إذا لم يكن عنصرًا غذائيًا.إذا كانت هذه صورة لطعام وليست قائمة، فقم بتحليل الطعام وقدم اسمه، والسعرات الحرارية، والمكونات التقريبية، ووصفًا موجزًا.";
      case 'bn':
        return "পুরো মেনুর ওভারভিউ প্রদান করুন। ${_selectedFoodStyle} এই ছবিতে অন্তর্ভুক্ত খাবারের মেনুগুলির সুপারিশকৃত ক্রম অনুসরণ করে, ছবিতে ${_selectedMenuNumber} মেনু নির্বাচন করে, ছবির মূল ভাষায় খাবারের নাম এবং বাংলা উচ্চারণ প্রদান করে, বিষয়বস্তু অনুসন্ধান করে, বিষয়বস্তু সংক্ষিপ্ত করে এবং একটি ব্যাখ্যা আউটপুট করে। উত্তর মোটামুটি 500 অক্ষরের হওয়া উচিত। প্রদান করা ফটোগুলি ব্যতীত অনুমানমূলক মেনু বা বর্ণনা প্রদান করবেন না এবং এটি খাদ্য মেনু না হলে 'না' নির্দেশ করুন।, যদি এটি মেনু নয় বরং খাবারের ছবি হয়, তাহলে খাবারটি বিশ্লেষণ করুন এবং এর নাম, ক্যালোরি, আনুমানিক উপাদান এবং একটি সংক্ষিপ্ত বর্ণনা প্রদান করুন।";
      case 'ru':
        return "Обзор всего меню. ${_selectedFoodStyle} следует рекомендованному порядку блюд на этой фотографии, выбирает ${_selectedMenuNumber} меню на фотографии, предоставляет название блюда на оригинальном языке и его русскую транскрипцию, ищет содержание, резюмирует его и выводит объяснение. Ответ должен содержать примерно 500 символов. Не предоставляйте предположительные меню или описания, отличные от представленных фотографий, и укажите нет, если это не меню еды, Если это фотография еды, а не меню, проанализируйте блюдо и укажите его название, калории, приблизительные ингредиенты и краткое описание.";
      case 'pt':
        return "Visão geral de todo o menu. ${_selectedFoodStyle} ordena os menus de comida incluídos nesta foto, seleciona ${_selectedMenuNumber} menus na foto, fornece o nome da comida no idioma original e a pronúncia em inglês da foto, pesquisa o conteúdo, resume o conteúdo e produz uma explicação. A resposta deve ter aproximadamente 500 caracteres no total. Não forneça menus especulativos ou descrições diferentes das fotos fornecidas e indique não se não for um menu de comida, Se for uma foto de comida em vez de um menu, analise o alimento e forneça seu nome, calorias, ingredientes aproximados e uma breve descrição.";
      case 'pt-BR':
        return "Dê uma visão geral de todo o cardápio. ${_selectedFoodStyle} segue a ordem recomendada dos menus de comida incluídos nesta foto, seleciona ${_selectedMenuNumber} menus na foto, fornece o nome da comida no idioma original da foto e a pronúncia em português do Brasil, busca o conteúdo, resume o conteúdo e fornece uma explicação. A resposta deve ter aproximadamente 500 caracteres. Não forneça menus especulativos ou descrições além das fotos fornecidas, e indique não se não for um menu de comida, Se for uma foto de comida em vez de um cardápio, analise o alimento e forneça seu nome, calorias, ingredientes aproximados e uma breve descrição.";
      case 'ur':
        return "پورے مینو کا جائزہ دیں۔ ${_selectedFoodStyle} اس تصویر میں شامل کھانے کے مینو کی سفارش کردہ ترتیب کی پیروی کرتا ہے، تصویر میں ${_selectedMenuNumber} مینو کا انتخاب کرتا ہے، تصویر کی اصل زبان میں کھانے کا نام اور اردو میں اس کا تلفظ فراہم کرتا ہے، مواد کی تلاش کرتا ہے، مواد کو خلاصہ کرتا ہے، اور ایک وضاحت فراہم کرتا ہے۔ جواب میں تقریباً 500 حروف ہونے چاہئیں۔ فراہم کردہ تصاویر کے علاوہ قیاس آرائیوں پر مبنی مینو یا تفصیلات فراہم نہ کریں، اور اگر یہ کھانے کا مینو نہیں ہے تو 'نہیں' بتائیں۔اگر یہ مینو کی بجائے کھانے کی تصویر ہے، تو کھانے کا تجزیہ کریں اور اس کا نام، کیلوریز، اندازاً اجزاء اور ایک مختصر وضاحت فراہم کریں";
      case 'id':
        return "Berikan gambaran umum tentang seluruh menu. ${_selectedFoodStyle} mengikuti urutan menu makanan yang direkomendasikan dalam foto ini, memilih ${_selectedMenuNumber} menu dalam foto, memberikan nama makanan dalam bahasa asli foto dan pengucapan dalam bahasa Indonesia, mencari konten, merangkum konten, dan memberikan penjelasan. Jawabannya harus sekitar 500 karakter. Jangan memberikan menu atau deskripsi spekulatif selain foto yang disediakan, dan tunjukkan tidak jika itu bukan menu makanan, Jika ini adalah foto makanan bukan menu, analisis makanan dan berikan namanya, kalori, perkiraan bahan, dan deskripsi singkat.";
      case 'de':
        return "Geben Sie einen Überblick über das gesamte Menü. ${_selectedFoodStyle} folgt der empfohlenen Reihenfolge der in diesem Foto enthaltenen Speisekarten, wählt ${_selectedMenuNumber} Menüs aus dem Foto aus, gibt den Namen der Speisen in der Originalsprache des Fotos und die deutsche Aussprache an, sucht nach Inhalten, fasst diese zusammen und gibt eine Erklärung aus. Die Antwort sollte insgesamt etwa 500 Zeichen umfassen. Geben Sie keine spekulativen Menüs oder Beschreibungen an, die nicht in den bereitgestellten Fotos enthalten sind, und geben Sie an, dass es sich nicht um ein Speisekartenmenü handelt, falls dies nicht der Fall ist, Wenn dies ein Foto von Essen und kein Menü ist, analysieren Sie das Essen und geben Sie Name, Kalorien, ungefähre Zutaten und eine kurze Beschreibung an.";
      case 'mr':
        return "संपूर्ण मेनूचे विहंगावलोकन द्या. ${_selectedFoodStyle} या छायाचित्रात समाविष्ट असलेल्या खाद्यपदार्थ मेनूंच्या शिफारस केलेल्या क्रमाचे अनुसरण करते, छायाचित्रातील ${_selectedMenuNumber} मेनू निवडते, छायाचित्राच्या मूळ भाषेत खाद्यपदार्थाचे नाव आणि मराठीत उच्चार प्रदान करते, सामग्री शोधते, सामग्रीचा सारांश देते आणि स्पष्टीकरण तयार करते. उत्तर एकूण 500 अक्षरे असावे. प्रदान केलेल्या फोटोंशिवाय अनुमानी मेनू किंवा वर्णने प्रदान करू नका आणि ते अन्न मेनू नसल्यास 'नाही' असे सूचित करा, जर ही मेनू नसून अन्नाची छायाचित्र असेल, तर अन्नाचे विश्लेषण करा आणि त्याचे नाव, कॅलोरीज, अंदाजे घटक आणि एक संक्षिप्त वर्णन द्या.";
      case 'te':
        return "మొత్తం మెనూ గురించి ఓవర్వ్యూ ఇవ్వండి. ${_selectedFoodStyle} ఈ ఫోటోలో చేర్చిన ఫుడ్ మెనూలకు సూచించిన క్రమాన్ని అనుసరిస్తుంది, ఫోటోలో ${_selectedMenuNumber} మెనూలను ఎంచుకుంటుంది, ఫోటో యొక్క అసలు భాషలో ఆహారం పేరు మరియు తెలుగు ఉచ్చారణను అందిస్తుంది, విషయాన్ని వెతుకుతుంది, విషయాన్ని సంగ్రహిస్తుంది మరియు వివరణను అవుట్పుట్ చేస్తుంది. సమాధానం మొత్తం సుమారు 500 అక్షరాలు ఉండాలి. అందించిన ఫోటోలు కాకుండా ఊహాత్మక మెనూలను లేదా వివరణలను అందించవద్దు మరియు అది ఆహార మెనూ కాదని సూచించండి, ఇది మెన్యూగా కాకుండా ఆహార ఫోటో అయితే, ఆహారాన్ని విశ్లేషించి దాని పేరు, క్యాలరీలు, అంచనా పదార్థాలు మరియు ఒక చిన్న వివరణను అందించండి。";
      case 'tr':
        return "Tüm menünün genel bir görünümünü verin. ${_selectedFoodStyle} bu fotoğrafta yer alan yiyecek menülerinin önerilen sırasına uyar, fotoğrafta ${_selectedMenuNumber} menü seçer, yiyecek adını fotoğrafın orijinal dilinde ve Türkçe telaffuzuyla sağlar, içeriği arar, içeriği özetler ve bir açıklama sunar. Cevap toplamda yaklaşık 500 karakter olmalıdır. Sağlanan fotoğrafların dışında spekülatif menüler veya açıklamalar sunmayın ve yiyecek menüsü değilse belirtin, Eğer bu bir menü değil de yemek fotoğrafıysa, yemeği analiz edin ve adını, kalorilerini, yaklaşık malzemelerini ve kısa bir açıklamayı sağlayın.";
      default:
        return "Overview of the entire menu. ${_selectedFoodStyle} order of food menus included in this photo, selects ${_selectedMenuNumber} menus in the photo, provides the name of the food in the original language and English pronunciation of the photo, searches for the contents, summarizes the contents, and outputs an explanation. The answer should be approximately 500 characters in total. Do not provide speculative menus or descriptions other than the provided photos, and indicate no if it is not a food menu. If it's a photo of food rather than a menu, analyze the food and provide its name, calories, approximate ingredients, and a brief description.";
    }
  }
}
