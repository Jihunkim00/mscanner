import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/settings_helper.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:adaptive_theme/adaptive_theme.dart'; // Import for adaptive theme
import 'package:mscanner/screens/TutorialCamera_Screen.dart';
import '/screens/log_service.dart';
import '/analytics_service.dart';
import '../helpers/preset_update_review_service.dart';

// 언어 정보를 담는 클래스
class Language {
  final String code;
  final String name;

  Language({required this.code, required this.name});
}

class _FoodStyleOption {
  final String id;
  final String label;

  const _FoodStyleOption({required this.id, required this.label});
}

class PresetSelectionScreen extends StatefulWidget {
  final bool isFirstLogin;
  final bool isUpdateReview;

  const PresetSelectionScreen({
    super.key,
    this.isFirstLogin = false,
    this.isUpdateReview = false,
  });

  @override
  _PresetSelectionScreenState createState() => _PresetSelectionScreenState();
}

class _PresetSelectionScreenState extends State<PresetSelectionScreen> {
  String _selectedLanguageCode = 'en'; // 기본값을 'en' (English)으로 설정
  String _selectedFoodStyle = SettingsHelper.foodStyleAiRecommend;
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

  List<_FoodStyleOption> getFoodStyles(AppLocalizations localizations) {
    return [
      _FoodStyleOption(
        id: SettingsHelper.foodStyleAiRecommend,
        label: localizations.foodStyleAIRecommend,
      ),
      _FoodStyleOption(
        id: SettingsHelper.foodStyleLowFat,
        label: localizations.foodStyleLowFat,
      ),
      _FoodStyleOption(
        id: SettingsHelper.foodStyleLowSalt,
        label: localizations.foodStyleLowSalt,
      ),
      _FoodStyleOption(
        id: SettingsHelper.foodStyleNutFree,
        label: localizations.foodStyleNutFree,
      ),
      _FoodStyleOption(
        id: SettingsHelper.foodStyleSeafood,
        label: localizations.foodStyleSeafood,
      ),
      _FoodStyleOption(
        id: SettingsHelper.foodStyleMeat,
        label: localizations.foodStyleMeat,
      ),
      _FoodStyleOption(
        id: SettingsHelper.foodStyleMuslimFriendly,
        label: localizations.foodStyleMuslim,
      ),
    ];
  }

  Map<String, String> _localizedFoodStyleIds(AppLocalizations localizations) {
    return {
      localizations.foodStyleAIRecommend.trim():
          SettingsHelper.foodStyleAiRecommend,
      localizations.foodStyleLowFat.trim(): SettingsHelper.foodStyleLowFat,
      localizations.foodStyleLowSalt.trim(): SettingsHelper.foodStyleLowSalt,
      localizations.foodStyleNutFree.trim(): SettingsHelper.foodStyleNutFree,
      localizations.foodStyleSeafood.trim(): SettingsHelper.foodStyleSeafood,
      localizations.foodStyleMeat.trim(): SettingsHelper.foodStyleMeat,
      localizations.foodStyleMuslim.trim():
          SettingsHelper.foodStyleMuslimFriendly,
    };
  }

  String _normalizeFoodStyleForUi(
    AppLocalizations localizations,
    String raw,
  ) {
    final trimmed = raw.trim();
    final localized = _localizedFoodStyleIds(localizations)[trimmed];
    if (localized != null) return localized;
    return SettingsHelper.tryNormalizeFoodStyleId(trimmed) ??
        SettingsHelper.foodStyleAiRecommend;
  }

  String _foodStyleLabelForId(
    AppLocalizations localizations,
    String styleId,
  ) {
    switch (SettingsHelper.normalizeFoodStyleId(styleId)) {
      case SettingsHelper.foodStyleLowFat:
        return localizations.foodStyleLowFat;
      case SettingsHelper.foodStyleLowSalt:
        return localizations.foodStyleLowSalt;
      case SettingsHelper.foodStyleNutFree:
        return localizations.foodStyleNutFree;
      case SettingsHelper.foodStyleSeafood:
        return localizations.foodStyleSeafood;
      case SettingsHelper.foodStyleMeat:
        return localizations.foodStyleMeat;
      case SettingsHelper.foodStyleMuslimFriendly:
        return localizations.foodStyleMuslim;
      case SettingsHelper.foodStyleAiRecommend:
      default:
        return localizations.foodStyleAIRecommend;
    }
  }

  List<String> getMenuNumbers(AppLocalizations localizations) {
    return [
      localizations.menuNumber1,
      localizations.menuNumber1to3,
      localizations.menuNumber1to5,
      localizations.menuNumberAll,
    ];
  }

  String _normalizeMenuCountHint(AppLocalizations localizations, String raw) {
    final value = raw.trim();
    final map = {
      '1': '1',
      '1-3': '1-3',
      '1-5': '1-5',
      'all': 'all',
      localizations.menuNumber1: '1',
      localizations.menuNumber1to3: '1-3',
      localizations.menuNumber1to5: '1-5',
      localizations.menuNumberAll: 'all',
    };
    return map[value] ?? '1-5';
  }

  String _menuCountLabelFromStored(AppLocalizations localizations, String raw) {
    switch (_normalizeMenuCountHint(localizations, raw)) {
      case '1':
        return localizations.menuNumber1;
      case '1-3':
        return localizations.menuNumber1to3;
      case '1-5':
        return localizations.menuNumber1to5;
      case 'all':
        return localizations.menuNumberAll;
      default:
        return localizations.menuNumber1to5;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.setCurrentScreen('preset_selection_screen');
      AnalyticsService.instance.logOnboardingStart(
          source: widget.isFirstLogin
              ? 'first_login'
              : widget.isUpdateReview
                  ? 'update_review'
                  : 'settings');
    });
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

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings(String systemLocaleCode) async {
    final localizations = AppLocalizations.of(context)!;
    final supportedLanguageCodes = languages.map((lang) => lang.code);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedMenuNumber = prefs.getString('selectedMenuNumber') ?? '1-5';
    final storedFoodStyle =
        prefs.getString(SettingsHelper.selectedFoodStyleKey) ??
            SettingsHelper.foodStyleAiRecommend;
    final storedLanguage =
        prefs.getString(SettingsHelper.selectedLanguageCodeKey);

    if (!mounted) return;
    setState(() {
      _selectedLanguageCode = SettingsHelper.resolveSupportedLanguageCode(
        storedLanguageCode: storedLanguage,
        systemLocaleCode: systemLocaleCode,
        supportedLanguageCodes: supportedLanguageCodes,
      );
      _selectedFoodStyle =
          _normalizeFoodStyleForUi(localizations, storedFoodStyle);
      _selectedMenuNumber =
          _menuCountLabelFromStored(localizations, storedMenuNumber);
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
    if (!foodStyles.any((style) => style.id == _selectedFoodStyle)) {
      _selectedFoodStyle = foodStyles.isNotEmpty
          ? foodStyles[0].id
          : SettingsHelper.foodStyleAiRecommend;
    }
    if (!menuNumbers.contains(_selectedMenuNumber)) {
      _selectedMenuNumber = menuNumbers.isNotEmpty ? menuNumbers[0] : '1-5';
    }

    final Color backgroundColor =
        brightness == Brightness.dark ? Colors.black : Color(0xFFEFEFF4);
    final Color textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
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
      color: brightness == Brightness.dark
          ? Colors.white24
          : Colors.black45, // 다크 모드와 라이트 모드에 따라 다른 색상 적용
    );

    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _resetInactivityTimer,
        onPanDown: (_) => _resetInactivityTimer(),
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor:
                AdaptiveTheme.of(context).brightness == Brightness.dark
                    ? Colors.black // 다크 모드일 때 검은색
                    : Color(0xFFEFEFF4), // 라이트 모드일 때 기존 본문 배경색
            elevation: 0, // 그림자 없애기
            leading: CupertinoNavigationBarBackButton(
              color: AdaptiveTheme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              onPressed: () {
                if (widget.isUpdateReview) {
                  Navigator.pushReplacementNamed(context, '/home');
                } else {
                  Navigator.of(context).pop();
                }
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10.0), // 좌우 패딩 설정
                      child: Text(
                        localizations.languagesdescprition,
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10.0), // 좌우 패딩 설정
                      child: Text(
                        localizations.fooddescprition,
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10.0), // 좌우 패딩 설정
                      child: Text(
                        localizations.menudescribe,
                        // 설명 텍스트, 원하는 내용으로 수정하세요
                        style: descriptionStyle,
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey
                                  : Colors.white,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
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
      String title,
      List<dynamic> options,
      String selectedValue,
      ValueChanged<String> onChanged,
      TextStyle itemStyle,
      TextStyle headingStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: headingStyle),
        SizedBox(height: 10),
        Container(
          height: 60, // 드롭다운 높이를 조절하여 스크롤 가능하게 설정
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            color: AdaptiveTheme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
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
                } else if (option is _FoodStyleOption) {
                  return DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(option.label, style: itemStyle),
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
                fillColor:
                    AdaptiveTheme.of(context).brightness == Brightness.dark
                        ? Colors.grey[900]
                        : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor:
                  AdaptiveTheme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
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
    final localizations = AppLocalizations.of(context)!;
    final normalizedMenuCount =
        _normalizeMenuCountHint(localizations, _selectedMenuNumber);

    await prefs.setString(
        SettingsHelper.selectedLanguageCodeKey, _selectedLanguageCode);
    await prefs.setString(
        SettingsHelper.selectedFoodStyleKey, _selectedFoodStyle);
    await prefs.setString(
        SettingsHelper.selectedMenuNumberKey, normalizedMenuCount);

    print('Saved Language Code: $_selectedLanguageCode');
    print('Saved Food Style: $_selectedFoodStyle');
    print('Saved Menu Number: $normalizedMenuCount');

    // ✅ 첫 로그인(튜토리얼) 아닐 때만 로그
    await AnalyticsService.instance.logOnboardingComplete(
      path: widget.isFirstLogin
          ? 'first_login'
          : widget.isUpdateReview
              ? 'update_review'
              : 'settings',
    );

    if (!widget.isFirstLogin) {
      try {
        final count = [
          _selectedLanguageCode,
          _selectedFoodStyle,
          _selectedMenuNumber,
        ].where((e) => e.isNotEmpty).length;

        await LogService().logPresetSave(
          fieldsCount: count, // 예: 3
          presetType: 'manual_save', // 원하는 라벨 (e.g., 'manual_save')
        );
      } catch (e) {
        debugPrint('[LogService] logPresetSave failed: $e');
      }
    }

    final preset = _createPresetDescription(
      selectedMenuNumber: normalizedMenuCount,
    );
    await SettingsHelper.saveCustomPresetDescription(preset);
    if (widget.isUpdateReview) {
      await PresetUpdateReviewService.markReviewComplete(prefs: prefs);
    }
    _isPresetSaved = true;

    // 확인을 위해 바로 값을 가져와서 출력
    final savedLanguageCode =
        prefs.getString(SettingsHelper.selectedLanguageCodeKey) ?? 'Not found';
    final savedFoodStyle =
        prefs.getString(SettingsHelper.selectedFoodStyleKey) ?? 'Not found';
    final savedMenuNumber =
        prefs.getString(SettingsHelper.selectedMenuNumberKey) ?? 'Not found';

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

  String _createPresetDescription({String? selectedMenuNumber}) {
    final localizations = AppLocalizations.of(context)!;
    return SettingsHelper.buildPresetDescription(
      selectedLanguageCode: _selectedLanguageCode,
      selectedFoodStyle: _selectedFoodStyle,
      selectedMenuNumber: selectedMenuNumber ?? _selectedMenuNumber,
      selectedFoodStyleLabel:
          _foodStyleLabelForId(localizations, _selectedFoodStyle),
    );
  }
}
