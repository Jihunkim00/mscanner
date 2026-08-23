import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '/screens/home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async'; // To use Timer
import '/screens/geohash_service.dart'; // Adjust the actual path accordingly
import '/screens/log_service.dart'; // ✅ 로그 서비스 추가
import 'package:flutter/gestures.dart';
import 'package:mscanner/widgets/tutorial_indicator.dart';
import '/screens/image_merge_service.dart'; // ImageMergeService 경로에 맞게 수정
import '/widgets/image_grid_viewer.dart'; // ✅ 로그 서비스 추가
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:mscanner/widgets/fx_auto_converter_card.dart';
// NOTE: FX/태그 보조 아이콘은 Material 아이콘을 사용합니다.

import 'dart:math' as math;
import '/widgets/ai_food_image_button.dart'; // 파일 경로 맞게
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import '/analytics_service.dart';
import 'package:provider/provider.dart';
import '/ad_remove_provider.dart';
import '/services/interstitial_ad_service.dart';
import '/services/result_exit_interstitial_policy.dart';
import 'package:mscanner/models/order_phrase_models.dart';
import 'package:mscanner/widgets/order_phrase_bottom_sheet.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mscanner/widgets/result/result_decision_skeleton.dart';
import 'package:mscanner/widgets/result/result_decision_cards.dart';
import 'package:mscanner/widgets/result/result_ui_copy.dart';
import 'package:mscanner/widgets/menu_tag_registry.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';
import 'package:mscanner/screens/result/result_action_service.dart';
import 'vision_service.dart';

// NOTE: searched_menu 저장은 UI 흐름과 분리(비동기)해서 실행합니다.

/// 파일 최상단에 선언
Future<Uint8List> mergeImages(List<Uint8List> bytesList) async {
  return await ImageMergeService.mergeAndCompress(bytesList);
}

class ResultScreen extends StatefulWidget {
  final File image;
  final List<File>? images; // ← 멀티 이미지 리스트 필드 추가
  final List<String> responses; // ← String → List<String>
  final Position? position;
  final DateTime captureTime;
  final bool isFromHistory;
  final String? title;
  final String? location;
  final String? geohash; // Added geohash
  final String? ragDetail; // Added ragDetail
  final bool isTutorial; // ✅ 추가
  final Stream<String>? responseStream; // ✅ 스트리밍 응답
  final List<String> initialFastRecommend; // ✅ 첫 추천칩 미리 표시용

  final String? visionRequestId;

  const ResultScreen({
    super.key,
    required this.image,
    this.images, // ← 생성자에 images 파라미터 추가
    required this.responses, // ← List<String> 받도록
    this.position,
    required this.captureTime,
    this.isFromHistory = false,
    this.title,
    this.location,
    this.geohash, // Added geohash
    this.ragDetail, // Added ragDetail
    this.isTutorial = false, // ✅ 기본값 false
    this.responseStream,
    this.initialFastRecommend = const [],
    this.visionRequestId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _MenuTag {
  final String name;
  final int count;
  const _MenuTag(this.name, this.count);
}

@immutable
class _MenuNamePair {
  final String original;
  final String translated;
  const _MenuNamePair({required this.original, required this.translated});

  String get _o => original.trim();
  String get _t => translated.trim();

  bool get hasAny => _o.isNotEmpty || _t.isNotEmpty;

  /// UI/집계에서 기본으로 쓸 표시값(언어는 일단 번역 우선)
  String get display => _t.isNotEmpty ? _t : _o;

  /// 중복 집계용 키(원문 우선, 없으면 번역)
  String get key {
    final base = _o.isNotEmpty ? _o : _t;
    return base.trim().toLowerCase();
  }

  Map<String, dynamic> toMap() => {
        'original': _o,
        'translated': _t,
      };
}

class _ResultScreenState extends State<ResultScreen> {
  // ✅ ResultScreen에서 주문 문구/TTS 진입 기능 토글
  // false: 버튼 비활성화 유지
  // true : 버튼 즉시 재활성화
  static const bool _enableOrderPhraseTts =
      false; //TTS 활성화 ########### 한글 일어 영문간

  static final RegExp _jaScriptRegex = RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF]');
  static final RegExp _koScriptRegex = RegExp(r'[\uAC00-\uD7AF]');

  SupportedLanguage _orderPhraseLanguage(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code == 'en') return SupportedLanguage.en;
    if (code == 'ja') return SupportedLanguage.ja;
    return SupportedLanguage.ko;
  }

  SupportedLanguage _orderPhraseOriginLanguage({
    required String menuOriginal,
    String? originLanguageCode,
  }) {
    final explicit = originLanguageCode?.trim().toLowerCase();
    if (explicit == 'ko') return SupportedLanguage.ko;
    if (explicit == 'ja') return SupportedLanguage.ja;
    if (explicit == 'en') return SupportedLanguage.en;
    final text = menuOriginal.trim();
    if (_koScriptRegex.hasMatch(text)) return SupportedLanguage.ko;
    if (_jaScriptRegex.hasMatch(text)) return SupportedLanguage.ja;
    final cc = _isoCountryCode?.trim().toUpperCase();
    if (cc == 'KR') return SupportedLanguage.ko;
    if (cc == 'JP') return SupportedLanguage.ja;
    return SupportedLanguage.en;
  }

  bool _analyticsViewedLogged = false;
  bool _priceCardEventLogged = false;
  bool _localInsightEventLogged = false;
  Timer? _stuckUiTimer;
  bool _showStuckFallback = false;
  final ResultExitInterstitialPolicy _resultExitInterstitialPolicy =
      const ResultExitInterstitialPolicy();
  bool _isLeavingResult = false;
  bool _navigationCompleted = false;

  bool get _isResultExitBlocked => _isLoading || _isWaitingFullMenu;

  // ===== Recommended price candidates (for FxQuickFxButton) =====
  double? _parseAmountAny(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final cleaned = s.replaceAll(',', '').replaceAll('\u00A0', ' ');
      final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
      if (m == null) return null;
      return double.tryParse(m.group(1)!);
    }
    return null;
  }

  List<double> _extractAmountsFromRecommendedPrices(
      List<Map<String, dynamic>> items) {
    final out = <double>[];
    for (final item in items) {
      // new schema: prices.{single/small/medium/large}
      final prices = item['prices'];
      if (prices is Map) {
        for (final k in const ['single', 'small', 'medium', 'large']) {
          final a = _parseAmountAny(prices[k]);
          if (a != null && a > 0) out.add(a);
        }
      }

      // old schema fallback
      final a2 = _parseAmountAny(item['price']);
      if (a2 != null && a2 > 0) out.add(a2);
    }
    // de-dup (string key)
    final seen = <String>{};
    final uniq = <double>[];
    for (final a in out) {
      final key = a.toStringAsFixed(2);
      if (seen.add(key)) uniq.add(a);
    }
    return uniq;
  }

  final Set<String> _aiButtonReadyKeys = <String>{};

// ===== Streaming AI response =====
  StreamSubscription<String>? _aiStreamSub;
  final StringBuffer _aiStreamBuffer = StringBuffer();
  bool _aiStreamDone = false;
  bool _aiStreamHadError = false;
  String? _aiStreamErrorMessage;

  Timer? _aiFirstChunkTimer;
  Timer? _aiInactivityTimer;
  Timer? _aiHardTimeoutTimer;
  bool _aiGotFirstChunk = false;

  bool get _isWaitingFullMenu =>
      widget.responseStream != null && !_aiStreamDone;

  // ✅ 추가
  bool get _hasAnyAiText =>
      _aiStreamBuffer.toString().trim().isNotEmpty ||
      widget.responses.any((e) => e.trim().isNotEmpty);

  bool get _hasPartialAiResult =>
      _fastRecommend.isNotEmpty ||
      _getRecommendedItems().isNotEmpty ||
      _hasAnyAiText;

  bool get _canShowTerminalActions =>
      _aiJson != null || (_aiStreamDone && _hasPartialAiResult);

// RECOMMEND: line fast chips
  List<String> _fastRecommend = <String>[];

// Reveal chips: 1 first, then others after stream done
  int _revealRecommendedCount = 1;
  Timer? _revealTimer;

  // === Auto FX: detected hints ===
  String? _isoCountryCode; // e.g., 'KR', 'JP'
  String? _currencySymbolHint; // e.g., '₩','€','$','¥'
  String? _currencyCodeHint; // ✅ e.g., 'KRW','JPY','USD'

  String? _extractCurrencyCodeFromText(String text) {
    return ResultParsingService.extractCurrencyCodeFromText(text);
  }

  double? _amountFromResponses; // extracted number from AI response

  bool _sentAiImpression = false;
  bool _sentRagImpression = false;
  bool _pendingSearchedMenuSave = false; // ✅ 스트림 끝나고 searched_menu 저장하기 위한 플래그

  String? _searchedMenuDocId; // ✅ 이번 결과에서 저장한 searched menu 문서 id

  // ✅ AI JSON parsed result (new UI)
  Map<String, dynamic>? _aiJson;
  final Set<String> _aiImageCheckingKeys = <String>{};
  final Set<String> _aiImageCheckedKeys = <String>{};
  final Map<String, String> _existingAiImageUrlByMenuKey = <String, String>{};

  // 🔽🔽🔽 [NEW] 다중 금액 후보 보관 리스트
  List<double> _amountCandidates = []; // ex) [12500, 3500, 7000]

  Future<void> _initCountryCurrencyHints() async {
    try {
      final raw = widget.responses.join('\n\n');

      _currencySymbolHint = _extractCurrencySymbolFromText(raw);
      _currencyCodeHint = _extractCurrencyCodeFromText(raw); // ✅ 추가
      _amountFromResponses = _extractAmountFromText(raw);
      _amountCandidates = _extractAmountsNextToFoodNames(raw);

      if (widget.position != null) {
        try {
          final placemarks = await placemarkFromCoordinates(
            widget.position!.latitude,
            widget.position!.longitude,
          );
          if (placemarks.isNotEmpty) {
            _isoCountryCode = placemarks.first.isoCountryCode?.toUpperCase();
          }
        } catch (_) {}
      }

      _isoCountryCode ??=
          ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  // ✅ 주변 타인 메뉴 태그 Future
  Future<List<_MenuTag>>? _nearbyMenuTagsFuture;

  // Extract first number (e.g., 12,500 or 12.50)
  double? _extractAmountFromText(String text) {
    return ResultParsingService.extractAmountFromText(text);
  }

  // Detect currency symbol from text
  String? _extractCurrencySymbolFromText(String text) {
    return ResultParsingService.extractCurrencySymbolFromText(text);
  }
  // ✅ NEW: parse JSON from responses
// - 단일 스캔: 첫 번째 유효 JSON 사용
// - 멀티 스캔: responses 안의 JSON들을 "추천메뉴/전체메뉴" 기준으로 병합(중복 제거)

  String? _extractJsonObjectFromText(String input) {
    return ResultParsingService.extractJsonObjectFromText(input);
  }

  void _trace(String message) {
    VisionRequestTrace.log(widget.visionRequestId, message);
  }

  void _parseAiJson() {
    _trace('parse_start');
    try {
      final parsed = ResultParsingService.parseAiJson(
        responses: widget.responses,
        imageCount: widget.images?.length ?? 1,
      );
      _aiJson = parsed.aiJson;
      if (_aiJson == null) {
        _trace('parse_failed reason=${parsed.aiJsonError ?? 'empty_response'}');
      } else {
        _trace(
          'parse_success recommendedCount=${_getRecommendedItems().length} '
          'fullMenuCount=${_countFullMenuItems(_aiJson)}',
        );
      }
    } catch (_) {
      _aiJson = null;
      _trace('parse_failed reason=parser_exception');
    }
  }

  int _countFullMenuItems(Map<String, dynamic>? aiJson) {
    if (aiJson == null) return 0;
    final rawFullMenu = aiJson['fullMenu'] ?? aiJson['full_menu'];
    if (rawFullMenu is! Map) return 0;
    final rawItems = rawFullMenu['items'];
    final items = rawItems is Map ? rawItems : rawFullMenu;
    return items.values.fold<int>(
      0,
      (total, value) => total + (value is List ? value.length : 0),
    );
  }

  // ✅ NEW: recommended list extractor
  List<Map<String, dynamic>> _getRecommendedItems() {
    return ResultParsingService.getRecommendedItems(_aiJson);
  }

  String _aiResultType() {
    return ResultParsingService.aiResultType(_aiJson);
  }

  String _aiUserMessage() {
    return ResultParsingService.aiUserMessage(_aiJson);
  }

  bool get _shouldShowDecisionSummary {
    if (_isWaitingFullMenu) return true;
    return ResultParsingService.shouldShowDecisionSummary(_aiJson);
  }

  bool _hasAnyFullMenuItems(Map<String, dynamic>? itemsMap) {
    if (itemsMap == null || itemsMap.isEmpty) return false;

    for (final v in itemsMap.values) {
      if (v is List && v.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasUsableFullMenu() {
    return ResultParsingService.hasUsableFullMenu(_aiJson);
  }

  void _cancelAiStreamTimers() {
    _aiFirstChunkTimer?.cancel();
    _aiInactivityTimer?.cancel();
    _aiHardTimeoutTimer?.cancel();
  }

  void _armAiInactivityTimeout() {
    _aiInactivityTimer?.cancel();
    _aiInactivityTimer = Timer(const Duration(seconds: 75), () {
      if (_aiStreamDone) return;

      _completeAiStream(
        hadError: !_hasPartialAiResult,
        errorMessage: _hasPartialAiResult
            ? null
            : AppLocalizations.of(context)?.result_aiTimeoutMoreResponse,
      );

      if (mounted) setState(() {});
      _aiStreamSub?.cancel();
    });
  }

  bool _tryParseCurrentStreamJson() {
    final raw = _aiStreamBuffer.toString().trim();
    final s = _extractJsonObjectFromText(raw);
    if (s == null) return false;

    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        _aiJson = Map<String, dynamic>.from(decoded);
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _finishAiStreamNow({
    bool hadError = false,
    String? errorMessage,
  }) {
    if (_aiStreamDone) return;
    _completeAiStream(hadError: hadError, errorMessage: errorMessage);
    if (mounted) setState(() {});
    _aiStreamSub?.cancel();
  }

  void _kickoffRecommendedReveal() {
    _revealTimer?.cancel();

    final jsonRec = _getRecommendedItems();
    final total = jsonRec.isNotEmpty ? jsonRec.length : _fastRecommend.length;
    if (total <= 0) return;

    if (_revealRecommendedCount <= 0) _revealRecommendedCount = 1;
    if (mounted) setState(() {});

    // If streaming and not done yet, keep only the first revealed chip.
    if (widget.responseStream != null && !_aiStreamDone) return;

    _revealTimer = Timer.periodic(const Duration(milliseconds: 220), (t) {
      if (!mounted) return t.cancel();
      if (_revealRecommendedCount >= total) return t.cancel();
      setState(() => _revealRecommendedCount += 1);
    });
  }

  void _showFullMenuSheet() {
    if (!_hasUsableFullMenu()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)?.result_fullMenuUnavailable ??
                    'Full menu is not available yet.')),
      );
      return;
    }

    final j = _aiJson;
    if (j == null) return;

    final rawFm = j['fullMenu'] ?? j['full_menu'] ?? j['menu'] ?? j['menus'];
    if (rawFm is! Map) return;

    Map<String, dynamic>? itemsMap;
    String? summary;
    bool truncated = false;

    if (rawFm['items'] is Map) {
      itemsMap = Map<String, dynamic>.from(rawFm['items'] as Map);
      summary = (rawFm['summary'] ?? '').toString().trim();
      truncated = rawFm['truncated'] == true;
    } else {
      itemsMap = Map<String, dynamic>.from(rawFm);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFCFCFD);
    final cardBg = isDark ? const Color(0xFF26262A) : Colors.white;
    final summaryBg =
        isDark ? const Color(0xFF2C2C31) : const Color(0xFFF6F7F9);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final hasAnyMenuItems = _hasAnyFullMenuItems(itemsMap);
    final hasAnyContent = hasAnyMenuItems || ((summary ?? '').isNotEmpty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: summaryBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            CupertinoIcons.square_list,
                            size: 18,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)?.result_viewFullMenu ??
                                'Full Menu',
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        IconButton(
                          splashRadius: 20,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: subColor,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      children: [
                        if ((summary ?? '').isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: summaryBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  truncated
                                      ? (AppLocalizations.of(context)
                                              ?.favorite_summaryTruncated ??
                                          'Menu Summary')
                                      : (AppLocalizations.of(context)
                                              ?.favorite_summary ??
                                          'Summary'),
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  summary!,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 13,
                                    height: 1.45,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        ..._buildMenuSection('Main', itemsMap?['main']),
                        ..._buildMenuSection('Side', itemsMap?['side']),
                        ..._buildMenuSection('Meal', itemsMap?['meal']),
                        ..._buildMenuSection('Drink', itemsMap?['drink']),
                        ..._buildMenuSection('Beverage', itemsMap?['beverage']),
                        ..._buildMenuSection('Other', itemsMap?['unknown']),
                        if (!hasAnyContent)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              AppLocalizations.of(context)
                                      ?.result_noMenuItemsFound ??
                                  'No menu items found.',
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 13,
                                color: subColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMenuSection(String title, dynamic items) {
    if (items is! List || items.isEmpty) return const [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionBg = isDark ? const Color(0xFF26262A) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final priceBg =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6);

    final menuItems = items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return [
      Text(
        title,
        style: TextStyle(
          fontFamily: 'SFPro',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: sectionBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: List.generate(menuItems.length, (index) {
            final m = menuItems[index];
            final nameOriginal = (m['nameOriginal'] ?? '').toString().trim();
            final nameTranslated = (m['name'] ?? '').toString().trim();

            final displayName = nameOriginal.isNotEmpty
                ? (nameTranslated.isNotEmpty &&
                        nameTranslated.toLowerCase() !=
                            nameOriginal.toLowerCase()
                    ? '$nameOriginal ($nameTranslated)'
                    : nameOriginal)
                : nameTranslated;

            final desc = (m['shortDesc'] ?? '').toString();
            final priceLabel = _priceLabelFromItem(m);

            final mk = buildMenuKey(nameOriginal, nameTranslated);
            final effectivePrice =
                (_convertedPriceByMenuKey[mk] ?? priceLabel)?.trim();
            final showPrice =
                effectivePrice != null && effectivePrice.isNotEmpty;

            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: borderColor,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          height: 1.25,
                        ),
                      ),
                      if (showPrice) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _toggleSinglePriceConversion(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: priceBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  effectivePrice,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (_singlePriceLoadingMenuKeys.contains(mk))
                                  const CupertinoActivityIndicator(radius: 7)
                                else
                                  Icon(
                                    Icons.currency_exchange,
                                    size: 15,
                                    color: _convertedPriceByMenuKey
                                            .containsKey(mk)
                                        ? Theme.of(context).colorScheme.primary
                                        : subColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          desc,
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 12,
                            height: 1.4,
                            color: subColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

// ===== Price label helpers =====
  String? _currencyCodeFromItem(Map<String, dynamic> item) {
    String? code;
    final prices = item['prices'];
    if (prices is Map) {
      final p = Map<String, dynamic>.from(prices);
      code = (p['currency'] ?? p['currencyCode'])?.toString();
    }
    code ??= (item['currency'] ?? item['currencyCode'] ?? item['priceCurrency'])
        ?.toString();
    if (code == null) return null;
    final c = code.trim();
    if (c.isEmpty) return null;
    return c.toUpperCase();
  }

  String? _symbolForCurrency(String? code) {
    if (code == null) return null;
    switch (code.toUpperCase()) {
      case 'KRW':
        return '₩';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'VND':
        return '₫';
      case 'THB':
        return '฿';
      case 'PHP':
        return '₱';
      case 'INR':
        return '₹';
      default:
        return null;
    }
  }

  bool _isAmbiguousSymbol(String symbol) => symbol == r'$' || symbol == '¥';

  String _commaInt(int n) {
    final sign = n < 0 ? '-' : '';
    var s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        buf.write(',');
      }
    }
    return sign + buf.toString();
  }

  String _formatAmount(double v) {
    // 정수면 소수점 제거
    if ((v - v.roundToDouble()).abs() < 0.000001) {
      return _commaInt(v.round());
    }
    var s = v.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'\.?0+$'), ''); // 12.00 -> 12, 12.50 -> 12.5
    final parts = s.split('.');
    final i = int.tryParse(parts[0]) ?? 0;
    final head = _commaInt(i);
    if (parts.length == 2) return '$head.${parts[1]}';
    return head;
  }

  String _formatMoney(double amount,
      {String? currencyCode,
      String? symbolHint,
      bool includeCodeIfAmbiguous = true}) {
    final sym = _symbolForCurrency(currencyCode) ?? symbolHint;
    final a = _formatAmount(amount);
    if (sym != null && sym.isNotEmpty) {
      final base = '$sym$a';
      if (currencyCode != null &&
          includeCodeIfAmbiguous &&
          _isAmbiguousSymbol(sym)) {
        return '$base ($currencyCode)';
      }
      return base;
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      return '$currencyCode $a';
    }
    return a;
  }

  String _formatMoneyRange(double min, double max,
      {String? currencyCode, String? symbolHint}) {
    final sym = _symbolForCurrency(currencyCode) ?? symbolHint;
    final aMin = _formatAmount(min);
    final aMax = _formatAmount(max);

    if (sym != null && sym.isNotEmpty) {
      var base = '$sym$aMin~$sym$aMax';
      if (currencyCode != null && _isAmbiguousSymbol(sym)) {
        base += ' ($currencyCode)';
      }
      return base;
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      return '$currencyCode $aMin~$aMax';
    }
    return '$aMin~$aMax';
  }

  String? _priceLabelFromItem(Map<String, dynamic> item) {
    final code = _currencyCodeFromItem(item);
    String? localHint;
    if (item['price'] is String) {
      localHint = _extractCurrencySymbolFromText(item['price'] as String);
    }
    final hint = localHint ?? _currencySymbolHint;

    final vals = <double>[];
    final prices = item['prices'];
    if (prices is Map) {
      for (final k in const ['single', 'small', 'medium', 'large']) {
        final a = _parseAmountAny(prices[k]);
        if (a != null && a > 0) vals.add(a);
      }
    }
    if (vals.isEmpty) {
      final a2 = _parseAmountAny(item['price']);
      if (a2 != null && a2 > 0) vals.add(a2);
    }
    if (vals.isEmpty) return null;
    vals.sort();

    if (vals.length == 1) {
      return _formatMoney(vals.first, currencyCode: code, symbolHint: hint);
    }
    return _formatMoneyRange(vals.first, vals.last,
        currencyCode: code, symbolHint: hint);
  }

// ===== FX: quick convert prices to "system" target currency (toggle) =====
  String? _targetCurrencyCode; // e.g., 'KRW','USD'

  bool _isBulkConvertingPrices = false;
  bool _bulkPricesConverted = false;
  final Map<String, String> _convertedPriceByMenuKey = <String, String>{};
  final Set<String> _singlePriceLoadingMenuKeys = <String>{};

  String _currencyFromLanguageCode(String? langCode) {
    final raw = (langCode ?? '').toLowerCase().replaceAll('_', '-');
    final code = raw.split('-').first;

    switch (code) {
      // East Asia
      case 'ko':
        return 'KRW';
      case 'ja':
        return 'JPY';
      case 'zh':
        if (raw.contains('hant') || raw.endsWith('tw')) return 'TWD';
        return 'CNY';

      // English
      case 'en':
        return 'USD';

      // Southeast Asia
      case 'th':
        return 'THB';
      case 'vi':
        return 'VND';
      case 'id':
        return 'IDR';
      case 'ms':
        return 'MYR';
      case 'tl':
      case 'fil':
        return 'PHP';

      // South / Central Asia
      case 'hi':
        return 'INR';
      case 'ru':
        return 'RUB';
      case 'uk':
        return 'UAH';

      // Middle East
      case 'ar':
        return '';

      // Europe → 전부 EUR
      case 'fr':
      case 'de':
      case 'es':
      case 'it':
      case 'pt':
      case 'nl':
      case 'pl':
      case 'sv':
      case 'no':
      case 'da':
      case 'fi':
      case 'cs':
      case 'hu':
      case 'ro':
      case 'el':
      case 'tr':
        return 'EUR';

      default:
        return '';
    }
  }

  Future<String> _ensureTargetCurrencyCode() async {
    if (_targetCurrencyCode != null && _targetCurrencyCode!.trim().isNotEmpty) {
      debugPrint('FX target cache: $_targetCurrencyCode');
      return _targetCurrencyCode!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      const keys = <String>[
        'fx_target_currency',
        'fxTargetCurrency',
        'target_currency',
        'preferred_currency',
        'home_currency',
      ];

      for (final k in keys) {
        final v = prefs.getString(k);
        debugPrint('FX pref check: $k = $v');
        if (v != null && v.trim().length >= 3) {
          final code = v.trim().toUpperCase();
          debugPrint('FX target from pref: $code');
          _targetCurrencyCode = code;
          return code;
        }
      }
    } catch (e) {
      debugPrint('FX pref read error: $e');
    }

    final langCode = ui.PlatformDispatcher.instance.locale.languageCode;
    debugPrint('FX languageCode: $langCode');

    final byLang = _currencyFromLanguageCode(langCode);
    debugPrint('FX target from language: $byLang');

    if (byLang.isNotEmpty) {
      _targetCurrencyCode = byLang;
      return byLang;
    }

    debugPrint('FX fallback target: USD');
    _targetCurrencyCode = 'USD';
    return 'USD';
  }

  List<double> _extractPriceValuesFromItem(Map<String, dynamic> item) {
    final vals = <double>[];
    final prices = item['prices'];
    if (prices is Map) {
      for (final k in const ['single', 'small', 'medium', 'large']) {
        final a = _parseAmountAny(prices[k]);
        if (a != null && a > 0) vals.add(a);
      }
    }
    if (vals.isEmpty) {
      final a2 = _parseAmountAny(item['price']);
      if (a2 != null && a2 > 0) vals.add(a2);
    }
    vals.sort();
    return vals;
  }

  List<Map<String, dynamic>> _collectAllMenuItemsForFx() {
    final out = <Map<String, dynamic>>[];
    out.addAll(_getRecommendedItems());

    final j = _aiJson;
    if (j == null) return out;

    final rawFm = j['fullMenu'] ?? j['full_menu'] ?? j['menu'] ?? j['menus'];
    if (rawFm is Map) {
      if (rawFm['items'] is Map) {
        final itemsMap = Map<String, dynamic>.from(rawFm['items'] as Map);
        for (final v in itemsMap.values) {
          if (v is List) {
            for (final e in v.whereType<Map>()) {
              out.add(Map<String, dynamic>.from(e));
            }
          }
        }
      } else {
        for (final v in rawFm.values) {
          if (v is List) {
            for (final e in v.whereType<Map>()) {
              out.add(Map<String, dynamic>.from(e));
            }
          }
        }
      }
    }
    return out;
  }

  Future<Map<String, FxDoc>> _fetchFxDocsOnce(Iterable<String> bases) async {
    final ids = bases.map((e) => e.toUpperCase()).toSet().toList();
    final limited = ids.take(10).toList();
    final snap = await FirebaseFirestore.instance
        .collection('fx_core')
        .where(FieldPath.documentId, whereIn: limited)
        .get();

    final m = <String, FxDoc>{};
    for (final d in snap.docs) {
      final fx = FxDoc.fromSnap(d);
      if (fx != null) m[d.id.toUpperCase()] = fx;
    }
    return m;
  }

  Future<String?> _convertPriceValuesToLabel({
    required List<double> vals,
    required String from,
    required String to,
  }) async {
    if (vals.isEmpty) return null;
    final toU = to.toUpperCase();
    final fromU = from.toUpperCase();

    if (toU == fromU) {
      if (vals.length == 1) {
        return _formatMoney(vals.first,
            currencyCode: fromU, symbolHint: currencySymbol(fromU));
      }
      return _formatMoneyRange(vals.first, vals.last,
          currencyCode: fromU, symbolHint: currencySymbol(fromU));
    }

    final bases = <String>{toU, 'USD', 'EUR', 'KRW', 'JPY', 'CNY'};
    final docs = await _fetchFxDocsOnce(bases);
    final baseDoc = pickBestBaseDoc(from: fromU, to: toU, docs: docs);
    if (baseDoc == null) return null;

    double? cMin = convertViaBase(
        amount: vals.first, from: fromU, to: toU, baseDoc: baseDoc);
    double? cMax = convertViaBase(
        amount: vals.last, from: fromU, to: toU, baseDoc: baseDoc);
    if (cMin == null || cMax == null) return null;

    cMin = double.parse(cMin.toStringAsFixed(2));
    cMax = double.parse(cMax.toStringAsFixed(2));

    if ((cMin - cMax).abs() < 0.000001) {
      return _formatMoney(cMin,
          currencyCode: toU, symbolHint: currencySymbol(toU));
    }
    return _formatMoneyRange(cMin, cMax,
        currencyCode: toU, symbolHint: currencySymbol(toU));
  }

  Future<void> _toggleBulkPriceConversion() async {
    if (_isBulkConvertingPrices) return;

    if (_bulkPricesConverted) {
      setState(() {
        _bulkPricesConverted = false;
        _convertedPriceByMenuKey.clear();
      });
      return;
    }

    final allItems = _collectAllMenuItemsForFx();
    if (allItems.isEmpty) return;

    setState(() => _isBulkConvertingPrices = true);

    try {
      final to = await _ensureTargetCurrencyCode();

      final groups = <String, List<Map<String, dynamic>>>{};
      for (final item in allItems) {
        final vals = _extractPriceValuesFromItem(item);
        if (vals.isEmpty) continue;

        final code = _currencyCodeFromItem(item);
        String? localHint;
        if (item['price'] is String) {
          localHint = _extractCurrencySymbolFromText(item['price'] as String);
        }
        final from = (code ??
                _currencyCodeHint ??
                pickLocalCurrency(
                  detectedCountryCode: _isoCountryCode,
                  currencySymbolHint: localHint ?? _currencySymbolHint,
                ))
            .toUpperCase();

        groups.putIfAbsent(from, () => <Map<String, dynamic>>[]).add(item);
      }

      if (groups.isEmpty) return;

      final converted = <String, String>{};

      for (final entry in groups.entries) {
        final from = entry.key;
        for (final item in entry.value) {
          final vals = _extractPriceValuesFromItem(item);
          if (vals.isEmpty) continue;

          final label =
              await _convertPriceValuesToLabel(vals: vals, from: from, to: to);
          if (label == null) continue;

          final nameOriginal = (item['nameOriginal'] ?? '').toString().trim();
          final nameTranslated =
              (item['name'] ?? item['nameTranslated'] ?? '').toString().trim();
          final mk = buildMenuKey(nameOriginal, nameTranslated);
          converted[mk] = label;
        }
      }

      if (!mounted) return;
      setState(() {
        _convertedPriceByMenuKey
          ..clear()
          ..addAll(converted);
        _bulkPricesConverted = converted.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)?.result_fxRateLoadFailed ??
                    '환율 정보를 불러오지 못했어요. 네트워크 상태를 확인해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isBulkConvertingPrices = false);
    }
  }

  Future<void> _toggleSinglePriceConversion(Map<String, dynamic> item) async {
    final nameOriginal = (item['nameOriginal'] ?? '').toString().trim();
    final nameTranslated =
        (item['name'] ?? item['nameTranslated'] ?? '').toString().trim();
    final mk = buildMenuKey(nameOriginal, nameTranslated);

    if (_singlePriceLoadingMenuKeys.contains(mk)) return;

    // 이미 변환된 상태면, 이 항목만 원래 통화로 되돌림
    if (_convertedPriceByMenuKey.containsKey(mk)) {
      setState(() => _convertedPriceByMenuKey.remove(mk));
      return;
    }

    final vals = _extractPriceValuesFromItem(item);
    if (vals.isEmpty) return;

    setState(() => _singlePriceLoadingMenuKeys.add(mk));

    try {
      final to = await _ensureTargetCurrencyCode();

      final code = _currencyCodeFromItem(item);
      String? localHint;
      if (item['price'] is String) {
        localHint = _extractCurrencySymbolFromText(item['price'] as String);
      }
      final from = (code ??
              _currencyCodeHint ??
              pickLocalCurrency(
                detectedCountryCode: _isoCountryCode,
                currencySymbolHint: localHint ?? _currencySymbolHint,
              ))
          .toUpperCase();

      final label =
          await _convertPriceValuesToLabel(vals: vals, from: from, to: to);
      if (label == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)?.result_fxConvertFailed ??
                        '해당 금액의 환율 변환에 실패했어요.')),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _convertedPriceByMenuKey[mk] = label;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)?.result_fxRateLoadFailed ??
                    '환율 정보를 불러오지 못했어요. 네트워크 상태를 확인해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _singlePriceLoadingMenuKeys.remove(mk));
    }
  }

  Future<void> _ensureAiImageChecked({
    required String menuKey,
    required String nameOriginal,
    required String nameTranslated,
  }) async {
    if (_aiImageCheckingKeys.contains(menuKey)) return;
    if (_aiImageCheckedKeys.contains(menuKey)) return;

    _aiImageCheckingKeys.add(menuKey);

    try {
      QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('menu_images')
          .where('menu_key', isEqualTo: menuKey)
          .limit(1)
          .get();

      if (snap.docs.isEmpty && nameOriginal.trim().isNotEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('menu_images')
            .where('menu_original', isEqualTo: nameOriginal.trim())
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty && nameTranslated.trim().isNotEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('menu_images')
            .where('menu_translated', isEqualTo: nameTranslated.trim())
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final imageUrl =
            (data['imageUrl'] ?? data['image_url'] ?? '').toString().trim();

        if (imageUrl.isNotEmpty) {
          _existingAiImageUrlByMenuKey[menuKey] = imageUrl;
        }
      }
    } catch (e) {
      debugPrint('AI image check failed for $menuKey: $e');
    } finally {
      _aiImageCheckingKeys.remove(menuKey);
      _aiImageCheckedKeys.add(menuKey);
      _aiButtonReadyKeys.add(menuKey);

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showAiImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlexibleRecommendationCard({
    required bool isDarkMode,
    required String primaryName,
    required String secondaryName,
    required String summary,
    required String? priceLabel,
    required List<String> tags,
    Widget? trailing,
    VoidCallback? onPriceTap,
  }) {
    final cardBg = isDarkMode ? const Color(0xFF252529) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E7EB);
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final subColor = isDarkMode ? Colors.white70 : const Color(0xFF6B7280);
    final chipBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF3F4F6);

    final cleanSummary = summary.trim();
    final cleanPrice = priceLabel?.trim();
    final visibleTags =
        tags.map((e) => e.trim()).where((e) => e.isNotEmpty).take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (primaryName.trim().isNotEmpty)
                  Text(
                    primaryName.trim(),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: titleColor,
                    ),
                  ),
                if (secondaryName.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    secondaryName.trim(),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: subColor,
                    ),
                  ),
                ],
                if (cleanSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    cleanSummary,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 13,
                      height: 1.45,
                      color: subColor,
                    ),
                  ),
                ],
                if ((cleanPrice != null && cleanPrice.isNotEmpty) ||
                    visibleTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (cleanPrice != null && cleanPrice.isNotEmpty)
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onPriceTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cleanPrice,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.currency_exchange,
                                  size: 14,
                                  color: subColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ...visibleTags.map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildDishRow(
    Map<String, dynamic> item,
    Color textColor, {
    required bool isPrimaryRecommended,
  }) {
    final nameOriginal = (item['nameOriginal'] ?? '').toString().trim();
    final nameOriginalReading =
        (item['nameOriginalReading'] ?? '').toString().trim();
    final originLanguageCode =
        (item['originLanguageCode'] ?? '').toString().trim();
    final nameTranslated = (item['name'] ?? '').toString().trim();
    final desc = (item['shortDesc'] ?? '').toString();
    final priceLabel = _priceLabelFromItem(item);

    final tags = (item['tags'] is List)
        ? (item['tags'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final pair =
        _MenuNamePair(original: nameOriginal, translated: nameTranslated);
    final menuKey = buildMenuKey(pair.original, pair.translated);
    final searchedMenuDocIdForThisRow =
        isPrimaryRecommended ? _searchedMenuDocId : null;
    if (!_aiImageCheckedKeys.contains(menuKey) &&
        !_aiImageCheckingKeys.contains(menuKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureAiImageChecked(
          menuKey: menuKey,
          nameOriginal: pair.original,
          nameTranslated: pair.translated,
        );
      });
    }

    final o = nameOriginal.trim();
    final t = nameTranslated.trim();
    final showTranslation =
        t.isNotEmpty && o.isNotEmpty && t.toLowerCase() != o.toLowerCase();
    final primary = o.isNotEmpty ? o : t;
    final secondary = showTranslation ? t : '';
    final effectivePrice =
        (_convertedPriceByMenuKey[menuKey] ?? priceLabel)?.trim();
    final trailing = (!_aiButtonReadyKeys.contains(menuKey) ||
            _searchedMenuDocId == null)
        ? null
        : SizedBox(
            width: 64,
            height: 64,
            child: (_existingAiImageUrlByMenuKey[menuKey]?.isNotEmpty == true)
                ? GestureDetector(
                    onTap: () {
                      final imageUrl = _existingAiImageUrlByMenuKey[menuKey]!;
                      _showAiImagePreview(imageUrl);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingAiImageUrlByMenuKey[menuKey]!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return AiFoodImageButton(
                            menuKey: menuKey,
                            menu: pair.toMap(),
                            shortDesc: desc,
                            tags: tags,
                            searchedMenuDocId: searchedMenuDocIdForThisRow,
                            size: 64,
                          );
                        },
                      ),
                    ),
                  )
                : AiFoodImageButton(
                    menuKey: menuKey,
                    menu: pair.toMap(),
                    shortDesc: desc,
                    tags: tags,
                    searchedMenuDocId: searchedMenuDocIdForThisRow,
                    size: 64,
                  ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFlexibleRecommendationCard(
            isDarkMode: _isDarkMode,
            primaryName: primary,
            secondaryName: secondary,
            summary: desc,
            priceLabel: effectivePrice,
            tags: tags,
            trailing: trailing,
            onPriceTap: () => _toggleSinglePriceConversion(item),
          ),
          if (isPrimaryRecommended) const SizedBox(height: 4),
          const SizedBox(height: 8),
          if (_enableOrderPhraseTts)
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final targetLanguage = _orderPhraseLanguage(context);
                  final targetMenuName =
                      nameTranslated.isNotEmpty ? nameTranslated : pair.display;
                  final menuOriginal =
                      nameOriginal.isNotEmpty ? nameOriginal : pair.original;

                  showOrderPhraseBottomSheet(
                    context: context,
                    menuName: targetMenuName,
                    menuOriginal: menuOriginal,
                    menuOriginalReading: nameOriginalReading.isEmpty
                        ? null
                        : nameOriginalReading,
                    originLanguage: _orderPhraseOriginLanguage(
                      menuOriginal: menuOriginal,
                      originLanguageCode: originLanguageCode,
                    ),
                    targetLanguage: targetLanguage,
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  constraints: const BoxConstraints(minHeight: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.14)
                          : const Color(0xFFD1D5DB).withValues(alpha: 0.72),
                    ),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2A2D33).withValues(alpha: 0.88)
                        : const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.speakerHigh,
                        size: 14,
                        color: textColor.withValues(alpha: 0.82),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)?.result_orderButton ??
                            '주문하기',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF374151).withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ NEW: New main card UI (fallback to old text if JSON not available)
  Widget _buildScanResultCard({
    required AppLocalizations localizations,
    required Color textColor,
    required BoxDecoration boxDecoration,
  }) {
    final rec = _getRecommendedItems();
    final hasFast = _fastRecommend.isNotEmpty;
    final hasJsonRec = rec.isNotEmpty;

    final resultType = _aiResultType();
    final userMessage = _aiUserMessage();

    final canShowMenu = _hasUsableFullMenu();
    final canShowPartialActions = _canShowTerminalActions;
    debugPrint(
        'FULLMENU state => selected=$_selectedMenuNumber, enabled=$_isFullMenuEnabled, hasFast=$hasFast, hasJsonRec=$hasJsonRec, usable=${_hasUsableFullMenu()}');

    if (!hasFast && !hasJsonRec) {
      final shouldHideRawAiText =
          widget.responseStream != null && !_aiStreamDone && !hasJsonRec;

      final isStillLoading = shouldHideRawAiText;
      if (isStillLoading &&
          resultType != 'not_menu' &&
          resultType != 'uncertain') {
        final loadingText = _showStuckFallback
            ? (AppLocalizations.of(context)?.result_aiTimeoutFullMenu ??
                AppLocalizations.of(context)?.result_loadingFullMenu ??
                ResultUiCopy.text(context, ResultUiCopy.loadingFallback))
            : (AppLocalizations.of(context)?.result_loadingFullMenu ??
                ResultUiCopy.text(context, ResultUiCopy.loadingFallback));

        return Container(
          decoration: boxDecoration,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CupertinoActivityIndicator(radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loadingText,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final fallbackDisplayText = userMessage.isNotEmpty
          ? userMessage
          : (resultType == 'not_menu'
              ? (AppLocalizations.of(context)?.result_notMenuMessage ??
                  'This image does not appear to be a food menu. Please retake the photo so menu names or food names are clearly visible.')
              : resultType == 'uncertain'
                  ? (AppLocalizations.of(context)
                          ?.result_uncertainMenuMessage ??
                      'Not sure this is a food menu. Please retake the photo so menu names and prices are clearly visible.')
                  : (AppLocalizations.of(context)
                          ?.result_uncertainMenuMessage ??
                      'Not sure this is a food menu. Please retake the photo so menu names and prices are clearly visible.'));

      return Container(
        decoration: boxDecoration,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? const Color(0xFF232326)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFEAECF0),
                ),
              ),
              child: Text(
                fallbackDisplayText,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 13,
                  height: 1.4,
                  color: textColor.withValues(alpha: 0.82),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ JSON UI

// ✅ FX 버튼(중복 제거): 제목 라인(본문)에서만 노출
    final jsonPriceAmounts = _extractAmountsFromRecommendedPrices(rec);
    final fxAmounts = <double>[
      ...jsonPriceAmounts,
      ..._amountCandidates,
      if ((_amountFromResponses ?? 0) > 0) _amountFromResponses!,
    ];
    final seenFx = <String>{};
    final fxUniq = <double>[];
    for (final a in fxAmounts) {
      if (a <= 0) continue;
      final key = a.toStringAsFixed(2);
      if (seenFx.add(key)) fxUniq.add(a);
    }

    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)?.home_mscannerPicks ??
                    ResultUiCopy.text(
                        context, ResultUiCopy.recommendationHeaderFallback),
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (fxUniq.isNotEmpty)
                (_isBulkConvertingPrices
                    ? const CupertinoActivityIndicator(radius: 9)
                    : IconButton(
                        iconSize: 18,
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        tooltip: _bulkPricesConverted
                            ? (AppLocalizations.of(context)
                                    ?.result_restoreOriginalCurrency ??
                                '원래 통화로 되돌리기')
                            : AppLocalizations.of(context)!
                                .result_convertToSystemCurrency(
                                    _targetCurrencyCode ??
                                        (AppLocalizations.of(context)
                                                ?.result_auto ??
                                            '자동')),
                        icon: Icon(
                          Icons.currency_exchange,
                          color: _bulkPricesConverted
                              ? Theme.of(context).colorScheme.primary
                              : textColor.withValues(alpha: 0.92),
                        ),
                        onPressed: _toggleBulkPriceConversion,
                      )),
            ],
          ),
          const SizedBox(height: 12),
          // ✅ 추천칩 이후, 전체 결과가 아직이면 로딩 표시
          if (_isWaitingFullMenu && rec.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const CupertinoActivityIndicator(radius: 10),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)?.result_loadingFullMenu ??
                      ResultUiCopy.text(context, ResultUiCopy.loadingFallback),
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_aiStreamHadError && _aiStreamErrorMessage != null) ...[
            Text(
              _aiStreamErrorMessage!,
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: 12,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
          ],

          ...rec.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildDishRow(
              item,
              textColor,
              isPrimaryRecommended: index == 0,
            );
          }),

          const SizedBox(height: 10),

          if (_isFullMenuEnabled)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: canShowMenu ? _showFullMenuSheet : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: canShowMenu
                            ? (_isDarkMode
                                ? const Color(0xFF2A2A2E)
                                : const Color(0xFFF6F7F9))
                            : (_isDarkMode
                                ? const Color(0xFF232326)
                                : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: canShowMenu
                              ? (_isDarkMode
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE5E7EB))
                              : (_isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFEAECF0)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!canShowMenu && _isWaitingFullMenu) ...[
                            const CupertinoActivityIndicator(radius: 8),
                            const SizedBox(width: 8),
                          ] else if (canShowMenu) ...[
                            Icon(
                              CupertinoIcons.square_list,
                              size: 18,
                              color: textColor.withValues(alpha: 0.86),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              canShowMenu
                                  ? (AppLocalizations.of(context)
                                          ?.result_viewFullMenu ??
                                      'View Full Menu')
                                  : (_isWaitingFullMenu
                                      ? (AppLocalizations.of(context)
                                              ?.result_preparingMenu ??
                                          'Preparing...')
                                      : 'Menu details unavailable'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: canShowMenu
                                    ? textColor
                                    : textColor.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                          if (canShowMenu) ...[
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_up_chevron_down,
                              size: 13,
                              color: textColor.withValues(alpha: 0.45),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ✅ 로딩 끝난 뒤에만 copy/share 노출
                if (canShowPartialActions) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF2A2A2E)
                          : const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: textColor.withValues(alpha: 0.86),
                        size: 20,
                      ),
                      onPressed: () {
                        final copySource = widget.responses.isNotEmpty
                            ? widget.responses.join('\n\n')
                            : _aiStreamBuffer.toString();
                        _copyTextToClipboard(copySource);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF2A2A2E)
                          : const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        CupertinoIcons.square_arrow_up,
                        color: textColor.withValues(alpha: 0.86),
                        size: 22,
                      ),
                      onPressed: _shareCapturedImage,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// AI 응답에서 1번 메뉴만 추출
  /// - "1.", "1)", "1).", "1]", "1:", "1-" 등 허용
  /// - "1." 형태가 없으면 null 반환(=저장 스킵)
// (기존 1번 파싱 로직) legacy: "1. ..."에서만 메뉴명 추출
  String? _extractMenuFirstLineLegacy() {
    final joined = widget.responses.join('\n').replaceAll('\r', '');
    final lines = joined.split('\n');

    String? first;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final reFirstItemPrefix = RegExp(r'^\s*1\s*[\.\)\]\:\-]\.?\s*');
      final m = reFirstItemPrefix.firstMatch(line);

      if (m != null) {
        first = line.substring(m.end).trim();

        final nextItem = RegExp(r'\s*[2-9]\s*[\.\)\]\:\-]\.?\s*');
        final cut = nextItem.firstMatch(first);
        if (cut != null && cut.start > 0) {
          first = first.substring(0, cut.start).trim();
        }
        break;
      }
    }

    if (first == null || first.isEmpty) return null;

    final cutTokens = <String>[' - ', ' – ', ' — ', ': ', '(', '[', '|'];
    for (final t in cutTokens) {
      final idx = first!.indexOf(t);
      if (idx > 0) first = first.substring(0, idx).trim();
    }

    first = first!.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();
    if (first.length < 2) return null;
    return first;
  }

// ✅ JSON(recommended[0])에서 original+translated 추출
  _MenuNamePair? _extractPrimaryMenuPairFromJson() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return null;

    final item = rec.first;
    final o =
        (item['nameOriginal'] ?? item['original'] ?? '').toString().trim();
    final t = (item['name'] ?? item['translated'] ?? '').toString().trim();

    final pair = _MenuNamePair(original: o, translated: t);
    return pair.hasAny ? pair : null;
  }

// ✅ 최종 primary pair (JSON 우선, 없으면 legacy)
  _MenuNamePair? _extractPrimaryMenuPair() {
    final jsonPair = _extractPrimaryMenuPairFromJson();
    if (jsonPair != null) return jsonPair;

    final legacy = _extractMenuFirstLineLegacy();
    if (legacy == null) return null;

    // "Original (Translated)" 형태면 분해
    final mm = RegExp(r'^(.*?)\s*\((.*?)\)\s*$').firstMatch(legacy);
    if (mm != null) {
      return _MenuNamePair(
        original: mm.group(1)!.trim(),
        translated: mm.group(2)!.trim(),
      );
    }

    return _MenuNamePair(original: legacy, translated: '');
  }

// (기존 시그니처 유지) 저장/표시용 문자열
  String? _extractMenuOnlyFromAiResponses() {
    final pair = _extractPrimaryMenuPair();
    if (pair == null) return null;

    final o = pair.original.trim();
    final t = pair.translated.trim();

    if (o.isNotEmpty && t.isNotEmpty && o.toLowerCase() != t.toLowerCase()) {
      return '$o ($t)';
    }
    return pair.display;
  }

  String _extractPrimaryMenuShortDesc() {
    final rec = _getRecommendedItems();
    if (rec.isNotEmpty) {
      final desc = (rec.first['shortDesc'] ?? '').toString().trim();
      if (desc.isNotEmpty) return desc;
    }
    return '';
  }

  List<String> _extractPrimaryMenuTags() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return const [];

    final rawTags = rec.first['tags'];
    if (rawTags is! List) return const [];

    final ordered = <String>[];
    final seen = <String>{};
    for (final raw in rawTags) {
      final tag = raw.toString().trim();
      if (tag.isEmpty) continue;
      if (!seen.add(tag)) continue;
      ordered.add(tag);
    }
    return ordered;
  }

  String _normalizeMenuText(String input) {
    return ResultParsingService.normalizeMenuText(input);
  }

  bool _isStrongMenuMatch({
    required _MenuNamePair source,
    required Map<String, dynamic> candidate,
  }) {
    final sourceKey = _normalizeMenuText(source.key);
    final sourceOriginal = _normalizeMenuText(source.original);
    final candidateKey =
        _normalizeMenuText((candidate['menu_key'] ?? '').toString());
    final candidateOriginal =
        _normalizeMenuText((candidate['menu_original'] ?? '').toString());

    if (sourceKey.isNotEmpty &&
        candidateKey.isNotEmpty &&
        sourceKey == candidateKey) {
      return true;
    }

    if (sourceOriginal.isNotEmpty &&
        candidateOriginal.isNotEmpty &&
        sourceOriginal == candidateOriginal) {
      return true;
    }

    return false;
  }

  Future<Map<String, String>?> _findMenuImageFromMenuImages({
    required _MenuNamePair pair,
  }) async {
    final candidates = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    final snapByKey = await FirebaseFirestore.instance
        .collection('menu_images')
        .where('menu_key', isEqualTo: pair.key)
        .limit(5)
        .get();
    candidates.addAll(snapByKey.docs);

    if (pair.original.trim().isNotEmpty) {
      final snapByOriginal = await FirebaseFirestore.instance
          .collection('menu_images')
          .where('menu_original', isEqualTo: pair.original.trim())
          .limit(5)
          .get();
      candidates.addAll(snapByOriginal.docs);
    }

    if (pair.translated.trim().isNotEmpty) {
      final snapByTranslated = await FirebaseFirestore.instance
          .collection('menu_images')
          .where('menu_translated', isEqualTo: pair.translated.trim())
          .limit(5)
          .get();
      candidates.addAll(snapByTranslated.docs);
    }

    final seenDocIds = <String>{};

    for (final doc in candidates) {
      if (!seenDocIds.add(doc.id)) continue;

      final data = doc.data();

      if (!_isStrongMenuMatch(source: pair, candidate: data)) {
        continue;
      }

      final thumbUrl = (data['thumb_url'] ??
              data['thumbUrl'] ??
              data['image_thumb_url'] ??
              data['menu_image_thumb_url'] ??
              data['imageUrl'] ??
              data['image_url'] ??
              '')
          .toString()
          .trim();

      final fullUrl = (data['image_url'] ??
              data['imageUrl'] ??
              data['full_url'] ??
              data['fullUrl'] ??
              data['menu_image_full_url'] ??
              thumbUrl)
          .toString()
          .trim();

      if (thumbUrl.isEmpty && fullUrl.isEmpty) continue;

      return {
        'thumb': thumbUrl.isNotEmpty ? thumbUrl : fullUrl,
        'full': fullUrl.isNotEmpty ? fullUrl : thumbUrl,
      };
    }

    return null;
  }

  Future<Map<String, String>> _resolvePrimaryMenuImageFields(
    _MenuNamePair pair,
  ) async {
    try {
      final found = await _findMenuImageFromMenuImages(pair: pair);
      if (found == null) {
        return {
          'menu_image_status': 'pending',
          'menu_image_thumb_url': '',
          'menu_image_full_url': '',
        };
      }

      return {
        'menu_image_status': 'ready',
        'menu_image_thumb_url': found['thumb'] ?? '',
        'menu_image_full_url': found['full'] ?? '',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ menu_images 교차 검증 실패: $e');
      }
      return {
        'menu_image_status': 'pending',
        'menu_image_thumb_url': '',
        'menu_image_full_url': '',
      };
    }
  }

  void _saveSearchedMenuFireAndForget() {
    if (widget.isTutorial) return;
    if (widget.isFromHistory) return;
    if (_geohash == null) return;

    if (widget.responseStream != null && !_aiStreamDone) {
      _pendingSearchedMenuSave = true;
      return;
    }

    final pair = _extractPrimaryMenuPair();
    if (pair == null) return;

    final primaryShortDesc = _extractPrimaryMenuShortDesc();
    final systemLang = ui.PlatformDispatcher.instance.locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;
    final menuTags = _extractPrimaryMenuTags();

    unawaited(() async {
      try {
        final docId = _buildSearchedMenuDocId(
          lang: systemLang,
          geohash: _geohash!,
          menuKey: pair.key,
        );

        final docRef =
            FirebaseFirestore.instance.collection('searched menu').doc(docId);

        _searchedMenuDocId = docRef.id;

        if (mounted) {
          setState(() {});
        }

        final imageFields = await _resolvePrimaryMenuImageFields(pair);

        await docRef.set({
          'menu': pair.toMap(),
          'menu_name': pair.display,
          'menu_key': pair.key,
          'menu_original': pair.original,
          'menu_translated': pair.translated,
          'menu_short_desc': primaryShortDesc,
          'menu_tags': menuTags,
          'geohash': _geohash,
          'lang': systemLang,
          'timestamp': DateTime.now().toIso8601String(),
          'last_seen_at': DateTime.now().toIso8601String(),
          'scan_count': FieldValue.increment(1),
          'menu_image_status': imageFields['menu_image_status'],
          'menu_image_thumb_url': imageFields['menu_image_thumb_url'],
          'menu_image_full_url': imageFields['menu_image_full_url'],
          if (user != null) 'uid': user.uid,
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) debugPrint('❌ searched_menu 저장 실패: $e');
      }
    }());
  }

  String _safePrefix(String geohash, int len) {
    return ResultParsingService.safePrefix(geohash, len);
  }

  String _buildSearchedMenuDocId({
    required String lang,
    required String geohash,
    required String menuKey,
  }) {
    return ResultActionService.buildSearchedMenuDocId(
      lang: lang,
      geohash: geohash,
      menuKey: menuKey,
    );
  }

  /// 저장된 값이 꼬였을 때(한 줄에 2.,3. 붙은 케이스) 표시용으로만 정리
  String _sanitizeMenuName(String raw) {
    var s = raw.replaceAll('\r', '').trim();
    if (s.isEmpty) return s;

    // 다음 항목 붙어 있으면 컷
    final nextItem = RegExp(r'\s*[2-9]\s*[\.\)\]\:\-]\.?\s*');
    final cut = nextItem.firstMatch(s);
    if (cut != null && cut.start > 0) {
      s = s.substring(0, cut.start).trim();
    }

    final cutTokens = <String>[' - ', ' – ', ' — ', ': ', '(', '[', '|'];
    for (final t in cutTokens) {
      final idx = s.indexOf(t);
      if (idx > 0) s = s.substring(0, idx).trim();
    }

    s = s.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();
    return s;
  }

  /// ✅ 주변 타인 메뉴 TOP 1~3
  /// Firestore 제약:
  /// - timestamp range + geohash range를 동시에 못 걸기 때문에
  /// => geohash prefix range만 서버에서 걸고
  /// => timestamp는 클라에서 필터(ISO8601 문자열 비교)
  Future<List<_MenuTag>> _fetchNearbyMenuTags({
    int prefixLen = 6,
    int days = 30,
    int maxDocs = 200,
  }) async {
    if (_geohash == null) return const [];

    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final prefix = _safePrefix(_geohash!, prefixLen);
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final qs = await FirebaseFirestore.instance
        .collection('searched menu')
        .where('lang', isEqualTo: lang)
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: '$prefix\uf8ff')
        .orderBy('geohash')
        .limit(maxDocs)
        .get();

    final Map<String, int> counts = {};
    final Map<String, String> displayName = {};

    for (final d in qs.docs) {
      final data = d.data();

      // 자기 제외
      if (myUid != null && data['uid'] == myUid) continue;

      // ✅ timestamp 기간 필터(클라)
      final ts = (data['timestamp'] ?? '').toString();
      if (ts.isEmpty) continue;
      if (ts.compareTo(since) < 0) continue;

      final raw = (data['menu_name'] ?? '').toString();
      final cleaned = _sanitizeMenuName(raw);
      if (cleaned.isEmpty) continue;

      final key = cleaned.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      displayName.putIfAbsent(key, () => cleaned);
    }

    final tags = counts.entries
        .map((e) => _MenuTag(displayName[e.key] ?? e.key, e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return tags.take(3).toList();
  }

  /// ✅ 결과 카드 바깥에 붙일 “작은 해시태그” UI
  /// - 별도 패딩 없음
  /// - 아주 작은 텍스트/간격
  Widget _buildNearbyMenuTags() {
    final f = _nearbyMenuTagsFuture;
    if (f == null) return const SizedBox.shrink();

    return FutureBuilder<List<_MenuTag>>(
      future: f,
      builder: (context, snap) {
        if (snap.hasError) {
          if (kDebugMode) debugPrint('❌ nearby tags error: ${snap.error}');
          return const SizedBox.shrink();
        }

        if (!snap.hasData) return const SizedBox.shrink();
        final tags = snap.data!;
        if (tags.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 4), // 카드 아래 최소 간격
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 왼쪽 고정 아이콘(배지 느낌)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(width: 1),
                ),
                child: Icon(
                  Icons.near_me, // place / trending_up / groups도 OK
                  size: 11,
                  color: Theme.of(context).textTheme.labelSmall?.color,
                ),
              ),

              const SizedBox(width: 4),

              // ✅ 오른쪽에 태그들이 흘러가며 줄바꿈
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(width: 1),
                        ),
                        child: Text(
                          '#${t.name}(${t.count})',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                    height: 1.0,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _address = 'Loading...';
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  bool _isDarkMode = false;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isMergeDone = false; // ✅ 이미지 병합 완료 플래그
  bool _isLiked = false;
  bool _isCloudSaveEnabled = false;
  bool _isAllowedUser = false;
  Uint8List? _mergedImageBytes; // ✅ 병합된 이미지 저장용
  bool _pendingSave = false; // ✅ merge 완료 후 자동 저장 요청 플래그
  String _selectedMenuNumber = '1-5';
  bool get _isFullMenuEnabled => _selectedMenuNumber == 'all';

  Timer? _timer; // Timer variable
  bool _isLoadingError = false; // Error state variable

  String? _geohash; // Variable to store geohash
  String? _ragDetail; // Variable to store ragDetail

  // New variable
  String? _foodDetail; // Variable to store foodDetail
  List<File> _viewerImages = [];
  int _viewerInitialIndex = 0;
  final GlobalKey _shareWidgetKey = GlobalKey();

  void _completeAiStream({bool hadError = false, String? errorMessage}) {
    if (_aiStreamDone) return;

    _cancelAiStreamTimers();

    _aiStreamDone = true;
    _aiStreamHadError = hadError;
    _aiStreamErrorMessage = errorMessage;
    _trace('stream_complete hadError=$hadError');

    final full = _aiStreamBuffer.toString().trim();
    if (full.isNotEmpty && !widget.responses.contains(full)) {
      widget.responses.add(full);
    }

    _parseAiJson();
    if (hadError && _aiJson == null) {
      _trace('render_error reason=stream_failure');
    }
    _kickoffRecommendedReveal();

    if (_pendingSearchedMenuSave) {
      _pendingSearchedMenuSave = false;
      _saveSearchedMenuFireAndForget();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMenuNumberSetting();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_analyticsViewedLogged) {
        _analyticsViewedLogged = true;
        AnalyticsService.instance.logResultViewed(
            entryPoint: widget.isFromHistory ? 'history' : 'scan_result');
      }
    });
    _parseAiJson(); // ✅ NEW: parse JSON response (if any)
    _fastRecommend = List<String>.from(widget.initialFastRecommend);
    if (_fastRecommend.isNotEmpty) {
      _revealRecommendedCount = 1; // 첫 칩 선공개
    }

// ✅ 스트리밍이 있으면: Result에서 바로 받아서 RECOMMEND 먼저 반영
    if (widget.responseStream != null) {
      _aiGotFirstChunk = false;
      _stuckUiTimer = Timer(const Duration(seconds: 25), () {
        if (!mounted) return;
        if (_aiStreamDone) return;
        if (_fastRecommend.isEmpty && _getRecommendedItems().isEmpty) {
          setState(() {
            _showStuckFallback = true;
          });
        }
      });

      _aiFirstChunkTimer = Timer(const Duration(seconds: 20), () {
        if (_aiStreamDone || _aiGotFirstChunk) return;
        _finishAiStreamNow(
          hadError: true,
          errorMessage:
              AppLocalizations.of(context)?.result_aiTimeoutFirstChunk,
        );
      });

      _aiHardTimeoutTimer = Timer(const Duration(seconds: 120), () {
        if (_aiStreamDone) return;
        _finishAiStreamNow(
          hadError: !_hasPartialAiResult,
          errorMessage: _hasPartialAiResult
              ? null
              : AppLocalizations.of(context)?.result_aiTimeoutFullMenu,
        );
      });

      _armAiInactivityTimeout();

      _aiStreamSub = widget.responseStream!.listen(
        (delta) {
          if (!_aiGotFirstChunk) {
            _aiGotFirstChunk = true;
            _aiFirstChunkTimer?.cancel();
          }

          _armAiInactivityTimeout();
          _aiStreamBuffer.write(delta);

          final s = _aiStreamBuffer.toString();

          // RECOMMEND 라인이 오면 즉시 칩 노출
          final m = RegExp(r'RECOMMEND:\s*(.*)\n').firstMatch(s);
          if (m != null) {
            final oneLine = (m.group(1) ?? '').trim();
            final items = oneLine
                .split('|')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty && e != '-' && e != '—')
                .toList();

            if (items.isNotEmpty && _fastRecommend.isEmpty) {
              _fastRecommend = items;
              _revealRecommendedCount = 1;
              _kickoffRecommendedReveal();
            }
          }

          // ✅ JSON 완성되면 [DONE] 안 기다리고 바로 terminal 처리
          if (_tryParseCurrentStreamJson()) {
            _finishAiStreamNow();
            return;
          }

          if (mounted) setState(() {});
        },
        onError: (e) {
          if (!mounted) return;
          _finishAiStreamNow(
            hadError: !_hasPartialAiResult,
            errorMessage: _hasPartialAiResult
                ? null
                : (e is TimeoutException
                    ? AppLocalizations.of(context)
                        ?.result_aiTimeoutFullMenuStream
                    : AppLocalizations.of(context)
                        ?.result_aiReceiveFailedFullMenuStream),
          );
        },
        onDone: () {
          if (!mounted) return;
          final full = _aiStreamBuffer.toString().trim();
          debugPrint('✅ stream done. fullLen=${_aiStreamBuffer.length}');
          debugPrint(
            '✅ hasJsonStart=${full.contains("{")} hasJsonEnd=${full.contains("}")}',
          );

          _finishAiStreamNow(
            hadError: full.isEmpty && !_hasPartialAiResult,
            errorMessage: (full.isEmpty && !_hasPartialAiResult)
                ? AppLocalizations.of(context)?.result_aiEmptyStreamResponse
                : null,
          );
        },
        cancelOnError: true,
      );
    } else {
      _kickoffRecommendedReveal();
    }

    _initCountryCurrencyHints();

    // ── UI 로딩 후에 이미지 병합 시작 ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isTutorial &&
          widget.images != null &&
          widget.images!.length > 1) {
        _startMergeInBackground();
      } else {
        setState(() => _isMergeDone = true);
      }
    });

    if (widget.isTutorial) {
      Future.delayed(Duration.zero, () {
        GestureBinding.instance.pointerRouter
            .addGlobalRoute(_handleTutorialTap);
      });
    }

    _loadSettings();
    if (widget.title != null) {
      _storeNameController.text = widget.title!;
    }
    _isLiked = true;

    _checkDarkMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          "✅ [ResultScreen] first frame rendered at ${DateTime.now().toIso8601String()}");
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiJson == null) {
        _trace('render_error reason=no_parsed_result');
      } else {
        _trace('render_success');
      }
    });
    _trySendImpressions();

    _checkAllowedUser();

    // 위치 및 RAG, 푸드 디테일 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.position != null) {
        _getAddressFromLatLng(widget.position!);

        final geohashService = GeohashService();
        _geohash = geohashService.generateGeohash(
          widget.position!.latitude,
          widget.position!.longitude,
        );

        setState(() {
          _nearbyMenuTagsFuture = () async {
            final a = await _fetchNearbyMenuTags(
                prefixLen: 6, days: 30, maxDocs: 200);
            if (a.isNotEmpty) return a;
            return _fetchNearbyMenuTags(prefixLen: 5, days: 30, maxDocs: 200);
          }();
        });

        // ✅ searched menu 저장(비동기)
        _saveSearchedMenuFireAndForget();

        //  _fetchRAGData();
        // _fetchFoodDetail();
      } else if (widget.isFromHistory) {
        setState(() {
          _address = widget.location ?? 'Location not available';
          _geohash = widget.geohash;
          _ragDetail = widget.ragDetail;
        });

        // 히스토리에서는 저장 스킵됨
        _saveSearchedMenuFireAndForget();

        // 히스토리에서도 주변태그는 보여주고 싶으면 Future 세팅(원하면 유지)
        if (_geohash != null) {
          _nearbyMenuTagsFuture = () async {
            final a = await _fetchNearbyMenuTags(
                prefixLen: 6, days: 30, maxDocs: 200);
            if (a.isNotEmpty) return a;
            return _fetchNearbyMenuTags(prefixLen: 5, days: 30, maxDocs: 200);
          }();
        }

        _fetchExistingReview();
        if (_ragDetail == null) {
          //  _fetchRAGData();
        }
        _fetchFoodDetail();
      } else {
        setState(() {
          _address = 'Location not available';
        });
      }
    });
  }

  Map<String, double> parseNutritionalData(String text) {
    final result = <String, double>{};

    final regCal = RegExp(r'(\d+(\.\d+)?)\s*kcal', caseSensitive: false);
    final matchCal = regCal.firstMatch(text);
    if (matchCal != null) result['calories'] = double.parse(matchCal.group(1)!);

    final regProtein = RegExp(r'단백질\s*[:=]\s*(\d+(\.\d+)?)\s*g');
    final matchProtein = regProtein.firstMatch(text);
    if (matchProtein != null) {
      result['protein'] = double.parse(matchProtein.group(1)!);
    }

    final regCarbs = RegExp(r'탄수화물\s*[:=]\s*(\d+(\.\d+)?)\s*g');
    final matchCarbs = regCarbs.firstMatch(text);
    if (matchCarbs != null) {
      result['carbs'] = double.parse(matchCarbs.group(1)!);
    }

    final regFat = RegExp(r'지방\s*[:=]\s*(\d+(\.\d+)?)\s*g');
    final matchFat = regFat.firstMatch(text);
    if (matchFat != null) result['fat'] = double.parse(matchFat.group(1)!);

    return result;
  }

  Future<void> _trySendImpressions() async {
    if (!_sentAiImpression) {
      _sentAiImpression = true;
      await LogService().logContentImpression(
        contentType: 'ai_answer',
        count: 1,
      );
    }
    if (!_sentRagImpression &&
        _isAllowedUser &&
        (_ragDetail?.isNotEmpty ?? false)) {
      _sentRagImpression = true;
      await LogService().logContentImpression(
        contentType: 'rag',
        count: 1,
      );
    }
  }

  void _onLoadingTimeout() {
    setState(() {
      _isLoadingError = true;
      _isLoading = false;
    });

    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  bool _hasNavigatedFromTutorial = false;

  void _handleTutorialTap(PointerEvent event) {
    if (_hasNavigatedFromTutorial) return;
    _hasNavigatedFromTutorial = true;

    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  void _startMergeInBackground() async {
    try {
      final bytesList = await Future.wait(
        widget.images!.map((file) => file.readAsBytes()),
      );

      final merged = await compute(mergeImages, bytesList);

      if (!mounted) return;
      setState(() {
        _mergedImageBytes = merged;
        _isMergeDone = true;
      });

      if (_pendingSave) {
        _pendingSave = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _saveScanResult();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mergedImageBytes = null;
        _isMergeDone = true;
      });

      if (_pendingSave) {
        _pendingSave = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _saveScanResult();
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.isTutorial) {
      GestureBinding.instance.pointerRouter
          .removeGlobalRoute(_handleTutorialTap);
    }
    _mergedImageBytes = null;
    _timer?.cancel();
    _aiStreamSub?.cancel();
    _revealTimer?.cancel();
    _stuckUiTimer?.cancel();
    _cancelAiStreamTimers();
    _stuckUiTimer?.cancel();
    _showStuckFallback = false;
    _storeNameController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  /// 특정 UID 사용자만 허용
  Future<void> _checkAllowedUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      const allowedUidList = [
        'XSouRMPnmnhgQ0QiK8zgNvOQAwu1',
        'sHWmp3IoNCh7YUY7BXjJ4OEIr9t1',
        'UCNasiqnZgdvERYimeM9TvmNDI33',
        'bVAaTXHSi1TTQGp7HPwT1whDUIS2',
        'QV9xmlGofQbMe9ZOOTFxlAjnqbI3',
        '01RLorc0WFWyxQIlae4wcXC9KJF3',
        'pfJilWN46cPj9ikX0S8eXWNJCLe2'
      ];
      setState(() {
        _isAllowedUser = allowedUidList.contains(user.uid);
      });
    }
  }

  Future<void> _fetchExistingReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _geohash == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('user_data')
        .doc(user.uid)
        .collection('data')
        .where('geohash', isEqualTo: _geohash)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      if (data.containsKey('review')) {
        _reviewController.text = data['review'] ?? '';
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _isCloudSaveEnabled = prefs.getBool('cloudSaveEnabled') ?? true;
      });
    } catch (e) {
      debugPrint('Failed to load settings: $e');
      if (!mounted) return;
      setState(() {
        _isCloudSaveEnabled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.result_failedLoadSettings ??
                  'Failed to load settings, cloud save enabled by default'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMenuNumberSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final raw = prefs.getString('selectedMenuNumber') ?? '1-5';
      final normalized = _normalizeMenuNumber(raw);

      setState(() {
        _selectedMenuNumber = normalized;
      });

      debugPrint('selectedMenuNumber(raw)=$raw');
      debugPrint('selectedMenuNumber(normalized)=$_selectedMenuNumber');
    } catch (e) {
      debugPrint('loadMenuNumber error=$e');
      if (!mounted) return;
      setState(() {
        _selectedMenuNumber = '1-5';
      });
    }
  }

  String _normalizeMenuNumber(String value) {
    final v = value.trim().toLowerCase();

    if (v == 'all' || v == '전체' || v == 'all menus') return 'all';

    if (v == '1' || v == '1개') return '1';

    if (v == '1-3' || v == '1~3' || v == '1~ 3' || v == '1 ~ 3') {
      return '1-3';
    }

    if (v == '1-5' || v == '1~5' || v == '1~ 5' || v == '1 ~ 5') {
      return '1-5';
    }

    return v;
  }

  Future<void> _uploadImage() async {
    if (widget.isTutorial || !_isCloudSaveEnabled) return;

    _imageUrl = null;

    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref =
          FirebaseStorage.instance.ref().child('Beta_test').child(fileName);
      SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');

      UploadTask uploadTask;

      if (_mergedImageBytes != null) {
        uploadTask = ref.putData(_mergedImageBytes!, metadata);
      } else {
        uploadTask = ref.putFile(widget.image, metadata);
      }

      TaskSnapshot snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ 이미지 업로드 완료: $_imageUrl');
    } catch (e) {
      debugPrint('❌ 이미지 업로드 실패: $e');
      _imageUrl = null;
    }
  }

  Future<void> _saveDataToFirestore() async {
    if (!_isCloudSaveEnabled) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_imageUrl == null) {
          debugPrint('⚠️ Firestore 저장 중단: _imageUrl is null');
          return;
        }
        final primary =
            _extractMenuOnlyFromAiResponses(); // 대표 메뉴명 (JSON 있으면 recommended[0] 우선)
        final docId =
            '${_geohash ?? 'nogeo'}_${widget.captureTime.toIso8601String()}';
        final docRef = FirebaseFirestore.instance
            .collection('user_data')
            .doc(user.uid)
            .collection('data')
            .doc(docId);

        await docRef.set({
          'image_url': _imageUrl,
          'title': _storeNameController.text,
          'responses': widget.responses,
          'location': _address,
          'timestamp': widget.captureTime.toIso8601String(),
          'gps': widget.position != null
              ? GeoPoint(widget.position!.latitude, widget.position!.longitude)
              : null,
          'geohash': _geohash,
          'rag_detail': _ragDetail,
          'food_detail': _foodDetail,
          'liked': _isLiked,
          if (primary != null) 'primary_menu': primary,
          // ✅ 나중에 준비되면 이 필드도 같이 저장하면 “대표 음식사진” 표시 가능
          // 'food_image_url': foodImageUrl,
          'review': _reviewController.text.trim(),
        }, SetOptions(merge: true));

        debugPrint('Data saved to Firestore with ID: $docId');
      } else {
        debugPrint('No user logged in');
      }
    } catch (e) {
      debugPrint('Failed to save data: $e');
    }
  }

  Future<void> _submitReview() async {
    final trimmedReview = _reviewController.text.trim();
    if (trimmedReview.length < 5 || widget.position == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final lat = widget.position!.latitude;
    final lng = widget.position!.longitude;

    final geohashService = GeohashService();
    final centerHash = geohashService.generateGeohash(lat, lng, precision: 8);
    final neighbors = geohashService.getNeighborGeohashes(centerHash);

    final allGeohashes = {centerHash, ...neighbors};

    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('selectedLangCode') ??
        Platform.localeName.split('_').first;

    await FirebaseFirestore.instance.collection('rag_reviews').add({
      'menuName': _storeNameController.text.trim(),
      'detail': trimmedReview,
      'geohashes': allGeohashes.toList(),
      'geohash5': centerHash.substring(0, 5),
      'lang': langCode,
      'timestamp': DateTime.now().toIso8601String(),
      'uid': user.uid,
      'status': 'pending',
      'gps': widget.position != null
          ? GeoPoint(widget.position!.latitude, widget.position!.longitude)
          : null,
    });

    debugPrint('리뷰 저장 완료');
  }

  Future<void> _saveDataToSharedPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> scanResults = prefs.getStringList('scanResults') ?? [];

      String? geohash = _geohash;

      Map<String, dynamic> scanResult = {
        'imagePath': widget.image.path,
        'responses': widget.responses,
        'location': _address,
        'storeName': _storeNameController.text,
        'timestamp': widget.captureTime.toIso8601String(),
        'latitude': widget.position?.latitude,
        'longitude': widget.position?.longitude,
        'geohash': geohash,
        'rag_detail': _ragDetail,
        'food_detail': _foodDetail,
      };

      scanResults.add(jsonEncode(scanResult));
      await prefs.setStringList('scanResults', scanResults);
      debugPrint('Data saved to SharedPreferences');
    } catch (e) {
      debugPrint('Failed to save data to SharedPreferences: $e');
    }
  }

  Future<void> _checkAndRequestReview() async {
    await ResultActionService.checkAndRequestReview();
  }

  Future<void> _exitResultWithInterstitial() async {
    if (_isResultExitBlocked || _isLeavingResult || _navigationCompleted) {
      return;
    }

    _isLeavingResult = true;
    try {
      await _maybeShowResultExitInterstitial();
    } finally {
      _navigateHomeOnce();
    }
  }

  Future<bool> _maybeShowResultExitInterstitial() async {
    final adProvider = context.read<AdRemoveProvider>();
    final adService = InterstitialAdService.instance;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return false;

    final now = DateTime.now();
    final countBefore = math.max(
      0,
      prefs.getInt(ResultExitInterstitialPolicy.exitCountPrefsKey) ?? 0,
    );

    final baseDecision = _resultExitInterstitialPolicy.evaluate(
      exitCount: countBefore,
      lastShownAt: _readResultExitLastShownAt(prefs),
      now: now,
      isAdRemoved: adProvider.isAdRemoved,
      isSubscribed: adProvider.isSubscribed,
      isTutorial: widget.isTutorial,
      isFromHistory: widget.isFromHistory,
      adReady: adService.isReady,
      alreadyShowing: adService.isShowing,
    );

    if (!baseDecision.shouldCountExit) {
      _logResultExitInterstitialEvent(
        'result_exit_interstitial_skipped',
        reason: baseDecision.reason,
        exitCount: countBefore,
        cooldownRemaining: baseDecision.cooldownRemaining,
      );
      return false;
    }

    final exitCount = countBefore + 1;
    await prefs.setInt(
      ResultExitInterstitialPolicy.exitCountPrefsKey,
      exitCount,
    );

    final decision = _resultExitInterstitialPolicy.evaluate(
      exitCount: exitCount,
      lastShownAt: _readResultExitLastShownAt(prefs),
      now: now,
      isAdRemoved: adProvider.isAdRemoved,
      isSubscribed: adProvider.isSubscribed,
      isTutorial: widget.isTutorial,
      isFromHistory: widget.isFromHistory,
      adReady: adService.isReady,
      alreadyShowing: adService.isShowing,
    );

    if (!decision.shouldShow) {
      _logResultExitInterstitialEvent(
        'result_exit_interstitial_skipped',
        reason: decision.reason,
        exitCount: exitCount,
        cooldownRemaining: decision.cooldownRemaining,
      );
      if (decision.reason == 'ad_not_ready') {
        unawaited(adService.preload());
      }
      return false;
    }

    _logResultExitInterstitialEvent(
      'result_exit_interstitial_eligible',
      reason: decision.reason,
      exitCount: exitCount,
      cooldownRemaining: decision.cooldownRemaining,
    );

    final shown = await adService.show();
    if (shown) {
      await prefs.setInt(ResultExitInterstitialPolicy.exitCountPrefsKey, 0);
      await prefs.setString(
        ResultExitInterstitialPolicy.lastShownAtPrefsKey,
        DateTime.now().toIso8601String(),
      );
      _logResultExitInterstitialEvent(
        'result_exit_interstitial_shown',
        reason: 'shown',
        exitCount: exitCount,
      );
      return true;
    }

    _logResultExitInterstitialEvent(
      'result_exit_interstitial_failed',
      reason: 'show_failed',
      exitCount: exitCount,
    );
    return false;
  }

  DateTime? _readResultExitLastShownAt(SharedPreferences prefs) {
    final raw = prefs.getString(
      ResultExitInterstitialPolicy.lastShownAtPrefsKey,
    );
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  void _logResultExitInterstitialEvent(
    String eventName, {
    required String reason,
    required int exitCount,
    Duration cooldownRemaining = Duration.zero,
  }) {
    unawaited(
      AnalyticsService.instance.logEvent(
        eventName,
        params: {
          'platform': Platform.isIOS ? 'ios' : 'android',
          'reason': reason,
          'exit_count': exitCount,
          'cooldown_remaining': cooldownRemaining.inSeconds,
          'entry_point': 'scan_result',
        },
      ),
    );
  }

  void _navigateHomeOnce() {
    if (_navigationCompleted || !mounted) return;
    _navigationCompleted = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

// NOTE(result-refactor): Keep the full save pipeline here for now because it coordinates
  // UI loading states, snackbars, timers, and navigation side-effects tightly coupled to this screen.

  Future<void> _saveScanResult() async {
    if (widget.isTutorial) {
      debugPrint('⛔ 튜토리얼 모드이므로 저장 로직 중단');
      return;
    }
    setState(() {
      _isLoading = true;
      _isLoadingError = false;
    });

    _timer = Timer(Duration(seconds: 30), _onLoadingTimeout);

    await _uploadImage();
    if (!mounted) return;
    if (_imageUrl == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.result_imageUploadFailed ??
                  'Image upload failed, please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _saveDataToFirestore();
    await _saveDataToSharedPreferences();
    await _submitReview();
    if (!mounted) return;

    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }

    if (!_isLoadingError) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.saved ?? 'Saved'),
          duration: Duration(milliseconds: 500),
        ),
      );

      await _checkAndRequestReview();
      unawaited(AnalyticsService.instance.logEvent('result_saved'));

      Future.delayed(Duration(seconds: 2), () {
        if (!mounted) return;
        unawaited(_exitResultWithInterstitial());
      });
    }
  }

  Future<void> _checkDarkMode() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    setState(() {
      _isDarkMode = savedThemeMode == AdaptiveThemeMode.dark;
    });
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];

      setState(() {
        _address = '${place.street}, ${place.locality}, ${place.country}';
      });
    } catch (e) {
      setState(() {
        _address = 'Error retrieving location';
      });
    }
  }

  void _copyTextToClipboard(String text) {
    LogService().logCopyClick(field: 'ai_text');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)?.textCopied ??
            'Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareCapturedImage() async {
    try {
      await LogService().logShareClick(dest: 'system', context: 'result');
      await AnalyticsService.instance.logShareResult(channel: 'system');
      unawaited(AnalyticsService.instance.logEvent('result_shared'));

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final boundary = _shareWidgetKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

        if (boundary == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.favorite_renderNotReady ??
                    'Error: RenderRepaintBoundary is not ready.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (!mounted) return;
        final pixelRatio = MediaQuery.of(context).devicePixelRatio * 2;
        final shareText = AppLocalizations.of(context)?.checkOutContent ??
            'Check out this content!';
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) return;

        final pngBytes = byteData.buffer.asUint8List();

        final tempDir = await getTemporaryDirectory();
        final file =
            await File('${tempDir.path}/result_shared_image.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
        );
      });
    } catch (e) {
      debugPrint('Error sharing captured image: $e');
    }
  }

  // Method to extract all food names
  List<String> _extractAllFoodNames(String text) {
    List<String> extractedNames = [];
    List<String> lines = text.split('\n');

    for (String line in lines) {
      line = line.trim();
      final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
      final Match? match = regExp.firstMatch(line);
      if (match != null && match.groupCount >= 1) {
        String foodName = match.group(1)?.trim() ?? '';
        foodName = foodName.replaceAll(RegExp(r'\(.*?\)'), '').trim();
        if (foodName.isNotEmpty && foodName.length < 50) {
          extractedNames.add(foodName);
        }
      }
    }

    return extractedNames;
  }

  // ✅ 음식명(**굵게**) 라인부터 다음 2~4줄(또는 공백/다음 음식명 전까지) 블록에서 가격을 느슨하게 탐색
  List<double> _extractAmountsNextToFoodNames(String text) {
    const int blockFollowLines = 20;
    const int blockMaxChars = 2000;

    final results = <double>[];
    final seen = <String>{};

    final lines = text.split('\n');
    final nameReg = RegExp(r'\*\*(.+?)\*\*');

    final amountReg = RegExp(
      r'(?:^|[^0-9])((?:(?:KRW|JPY|USD|EUR|CNY|HKD|TWD|NTD|SGD|AUD|CAD|GBP|CHF|₩|\$|€|¥|元|원|엔|달러|유로|엔화)\s*(?:(?:[0-9]{1,3}(?:[.,\s][0-9]{3})*|[0-9]+)(?:[.,][0-9]+)?))|(?:(?:[0-9]{1,3}(?:[.,\s][0-9]{3})*|[0-9]+)(?:[.,][0-9]+)?\s*(?:KRW|JPY|USD|EUR|CNY|HKD|TWD|NTD|SGD|AUD|CAD|GBP|CHF|₩|\$|€|¥|元|원|엔|달러|유로|엔화)?))',
      caseSensitive: false,
    );

    final excludeUnitToken = RegExp(
      r'^(?:k?cal|kj|g|mg|kg|ml|l|cl|dl|%|oz|lb|pcs?|개|잔|인분|servings?)\b',
      caseSensitive: false,
    );
    final excludeInlineSuffix = RegExp(
      r'(?:k?cal|kj|g|mg|kg|ml|l|cl|dl|%|oz|lb|pcs?)$',
      caseSensitive: false,
    );

    String stripPrefix(String s) => s.replaceFirst(
          RegExp(
              r'^\s*(?:\d+\.\s*|\d+\)\s*|\(\d+\)\s*|\[\d+\]\s*|[-–—•*·]\s*)'),
          '',
        );

    double? parseNumber(String captured) {
      var p = captured.replaceAll(
        RegExp(
          r'(KRW|JPY|USD|EUR|CNY|HKD|TWD|NTD|SGD|AUD|CAD|GBP|CHF|원|엔|달러|유로|엔화|₩|\$|€|¥|元)',
          caseSensitive: false,
        ),
        '',
      );

      p = p.replaceAll(RegExp(r'\s+'), '');

      final m = RegExp(r'([.,])(\d{1,2})$').firstMatch(p);
      if (m != null && m.group(1) == ',') {
        p = '${p.substring(0, m.start).replaceAll(RegExp(r'[.,]'), '')}.${m.group(2)!}';
      } else {
        p = p.replaceAll(',', '');
        final dotCount = '.'.allMatches(p).length;
        if (dotCount > 1) {
          p = p.replaceAll('.', '');
        }
      }

      return double.tryParse(p);
    }

    int i = 0;
    while (i < lines.length) {
      var line = stripPrefix(lines[i].trim());
      if (line.isEmpty) {
        i++;
        continue;
      }

      final nameMatch = nameReg.firstMatch(line);
      if (nameMatch == null) {
        i++;
        continue;
      }

      final buffer = StringBuffer();
      int taken = 0;
      for (int j = i; j < lines.length && taken <= blockFollowLines; j++) {
        var cur = stripPrefix(lines[j]).trimRight();
        if (j > i && cur.isEmpty) break;
        if (j > i && nameReg.hasMatch(cur)) break;
        buffer.writeln(cur);
        taken++;
      }

      var block = buffer.toString().trim();
      if (block.length > blockMaxChars) {
        block = block.substring(0, blockMaxChars);
      }

      final afterName = block.substring(nameMatch.end).trimLeft();
      final searchAreas = <String>[afterName, block];

      for (final area in searchAreas) {
        for (final m in amountReg.allMatches(area)) {
          final captured = m.group(1)!;

          final remain = area.substring(m.end).trimLeft();
          final nextToken =
              remain.isEmpty ? '' : remain.split(RegExp(r'\s+')).first;

          final capTrim = captured.trimRight();

          if (excludeUnitToken.hasMatch(nextToken) ||
              excludeInlineSuffix.hasMatch(capTrim)) {
            continue;
          }

          final v = parseNumber(captured);
          if (v != null && v > 0) {
            final key = v.toStringAsFixed(2);
            if (seen.add(key)) results.add(double.parse(key));
          }
        }
      }

      i += taken > 0 ? taken : 1;
    }

    return results;
  }

  Future<void> _fetchFoodDetail() async {
    try {
      List<String> foodNames =
          _extractAllFoodNames(widget.responses.join('\n'));
      if (foodNames.isEmpty) {
        debugPrint('No food names found in response.');
        return;
      }

      bool detailFound = false;

      for (String foodName in foodNames) {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('rag_data_food')
            .where('foodname', isEqualTo: foodName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var doc = querySnapshot.docs.first;
          setState(() {
            _foodDetail = doc['detail'];
          });
          detailFound = true;
          break;
        }
      }

      if (!detailFound) {
        setState(() {
          _foodDetail = null;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch food detail: $e');
      setState(() {
        _foodDetail = null;
      });
    }
  }

  // Future<void> _fetchRAGData() async {
  //   if (_geohash == null) return;

  //try {
  //  QuerySnapshot querySnapshot = await FirebaseFirestore.instance
  //      .collection('rag_data')
  //      .where('geohashes', arrayContains: _geohash)
  //      .limit(1)
  //      .get();

  //if (querySnapshot.docs.isNotEmpty) {
  //  DocumentSnapshot doc = querySnapshot.docs.first;
  // Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

  //if (data != null) {
  //  SharedPreferences prefs = await SharedPreferences.getInstance();
  // String? langCode = prefs.getString('languageCode');
  // langCode ??= Localizations.localeOf(context).toLanguageTag();
  // langCode = langCode.replaceAll('-', '_');

  // String detailField = 'detail_$langCode';

  // setState(() {
  //   _ragDetail =
  //  data.containsKey(detailField) ? data[detailField] : data['detail_en'];
  // });
  // } else {
  //  setState(() {
  //   _ragDetail = null;
  // });
  // await _trySendImpressions();
  // }
  // } else {
  // setState(() {
  // _ragDetail = null;
  // });
  // }
  // } catch (e) {
  // debugPrint('Failed to fetch RAG data: $e');
  // setState(() {
  // _ragDetail = null;
  // });
  // }
  // }

  void _showFullImage({required List<File> files, required int initialIndex}) {
    _viewerImages = files;
    _viewerInitialIndex = initialIndex;
    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: PageController(initialPage: _viewerInitialIndex),
                  itemCount: _viewerImages.length,
                  itemBuilder: (_, idx) => InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        _viewerImages[idx],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _decisionTitle() {
    final pair = _extractPrimaryMenuPair();
    if (pair != null && pair.display.trim().isNotEmpty) {
      return pair.display.trim();
    }
    return _extractMenuOnlyFromAiResponses() ??
        (AppLocalizations.of(context)?.aiAnswer ?? 'ai result');
  }

  String? _decisionSubtitle() {
    final short = _extractPrimaryMenuShortDesc().trim();
    if (short.isNotEmpty) return short;

    final userMsg = _aiUserMessage().trim();
    if (userMsg.isNotEmpty) {
      return userMsg.length > 120 ? '${userMsg.substring(0, 120)}…' : userMsg;
    }
    return null;
  }

  String? _decisionReason() {
    final tags = _decisionQuickTags();
    final reasonFromTags = _decisionReasonFromTags(tags);
    if (reasonFromTags != null) {
      return reasonFromTags;
    }
    final subtitle = _decisionSubtitle()?.trim() ?? '';
    if (subtitle.isNotEmpty) {
      final cleanSubtitle = subtitle
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[\[\]{}<>]'), '')
          .trim();
      if (cleanSubtitle.isNotEmpty) {
        return cleanSubtitle.length > 70
            ? '${cleanSubtitle.substring(0, 70).trimRight()}…'
            : cleanSubtitle;
      }
    }
    final local = _decisionLocalInsights();
    if (local.isNotEmpty) {
      final cleanLocal = local.first
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^[•\-\s]+'), '')
          .trim();
      if (cleanLocal.isNotEmpty) {
        return cleanLocal.length > 70
            ? '${cleanLocal.substring(0, 70).trimRight()}…'
            : cleanLocal;
      }
    }

    return ResultUiCopy.text(context, ResultUiCopy.reasonWeakSignal);
  }

  String? _decisionReasonFromTags(List<String> tags) {
    if (tags.isEmpty) return null;

    final normalized = tags
        .map((e) => MenuTagRegistry.normalizeCode(e).trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    bool has(String code) => normalized.contains(code);
    if (has(MenuTagRegistry.popular) || has(MenuTagRegistry.recommended)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonPopular);
    }
    if (has(MenuTagRegistry.signature)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonSignature);
    }
    if (has(MenuTagRegistry.seafood) || has(MenuTagRegistry.pescatarian)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonSeafood);
    }
    if (has(MenuTagRegistry.spicy)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonSpicy);
    }
    if (has(MenuTagRegistry.vegan) || has(MenuTagRegistry.vegetarian)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonVegan);
    }
    if (has(MenuTagRegistry.glutenFree) || has(MenuTagRegistry.dairyFree)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonDietary);
    }
    if (has(MenuTagRegistry.grill)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonGrill);
    }
    if (has(MenuTagRegistry.stew)) {
      return ResultUiCopy.text(context, ResultUiCopy.reasonStew);
    }
    final firstLabel = quickDecisionTagLabel(tags.first).trim();
    if (firstLabel.isNotEmpty) {
      return ResultUiCopy.text(
        context,
        ResultUiCopy.reasonStyleWithLabel,
        args: {'label': firstLabel},
      );
    }
    return null;
  }

  List<String> _decisionQuickTags() {
    const groupAOrdered = <String>[
      MenuTagRegistry.recommended,
      MenuTagRegistry.signature,
      MenuTagRegistry.popular,
    ];
    const groupBOrdered = <String>[
      MenuTagRegistry.spicy,
      MenuTagRegistry.seafood,
      MenuTagRegistry.egg,
      MenuTagRegistry.vegan,
      MenuTagRegistry.vegetarian,
      MenuTagRegistry.halal,
      MenuTagRegistry.glutenFree,
      MenuTagRegistry.dairyFree,
      MenuTagRegistry.nutAllergy,
      MenuTagRegistry.pescatarian,
      MenuTagRegistry.grill,
      MenuTagRegistry.stew,
    ];
    const recognizedCodes = <String>{
      ...groupAOrdered,
      ...groupBOrdered,
    };

    final recognized = <String>[];
    final fallbackRaw = <String>[];
    final seenNormalized = <String>{};

    for (final raw in _extractPrimaryMenuTags()) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final normalized = MenuTagRegistry.normalizeCode(trimmed).trim();
      if (normalized.isEmpty) continue;
      if (!seenNormalized.add(normalized)) continue;

      if (recognizedCodes.contains(normalized)) {
        recognized.add(normalized);
      } else {
        fallbackRaw.add(trimmed);
      }
    }

    final recognizedSet = recognized.toSet();
    final selected = <String>[];

    for (final code in groupAOrdered) {
      if (recognizedSet.contains(code)) {
        selected.add(code);
        break; // up to 1 from Group A
      }
    }

    for (final code in groupBOrdered) {
      if (selected.length >= 2) break;
      if (!recognizedSet.contains(code)) continue;
      if (selected.contains(code)) continue;
      selected.add(code);
    }

    for (final raw in fallbackRaw) {
      if (selected.length >= 2) break;
      selected.add(raw);
    }

    return selected.take(2).toList(growable: false);
  }

  String? _decisionPriceLabel() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return null;

    final rawLabel = _priceLabelFromItem(rec.first);
    if (rawLabel == null) return null;

    final label = rawLabel.trim();
    return label.isNotEmpty ? label : null;
  }

  List<String> _decisionLocalInsights() {
    final rag = (_ragDetail ?? '').trim();
    if (rag.isEmpty) return const [];

    final lines = rag
        .split(RegExp(r'[\n•]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return lines.take(3).toList();
  }

  Widget _buildDecisionSummarySection() {
    if (_isWaitingFullMenu) {
      return ResultDecisionSkeletonCard(
        isDarkMode: _isDarkMode,
        showResultListSkeleton: true,
      );
    }

    if (!_shouldShowDecisionSummary) {
      return const SizedBox.shrink();
    }

    final pair = _extractPrimaryMenuPair();
    final title = _decisionTitle();
    final original = pair == null
        ? null
        : (pair.original.trim().toLowerCase() == title.trim().toLowerCase()
            ? null
            : pair.original.trim());

    return ResultDecisionCards(
      isDarkMode: _isDarkMode,
      title: title,
      originalTitle: original,
      subtitle: _decisionSubtitle(),
      decisionReason: _decisionReason(),
      priceLabel: _decisionPriceLabel(),
      tags: _decisionQuickTags(),
      localInsights: _decisionLocalInsights(),
      onPriceTap: () {
        if (_priceCardEventLogged) return;
        _priceCardEventLogged = true;
        unawaited(
            AnalyticsService.instance.logEvent('result_price_card_opened'));
      },
      onLocalInsightTap: () {
        if (_localInsightEventLogged) return;
        _localInsightEventLogged = true;
        unawaited(
            AnalyticsService.instance.logEvent('result_local_insight_opened'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "▶️ [ResultScreen] build() at ${DateTime.now().toIso8601String()}");
    final localizations = AppLocalizations.of(context);
    final bool showResultActions = !_isWaitingFullMenu;
    final bool showDecisionArea =
        _isWaitingFullMenu || _shouldShowDecisionSummary;
    final Color backgroundColor =
        _isDarkMode ? Colors.black : const Color(0xFFF5F6F8);
    final Color textColor =
        _isDarkMode ? Colors.white : const Color(0xFF111827);

    final BoxDecoration boxDecoration = BoxDecoration(
      color: _isDarkMode ? const Color(0xFF1F1F22) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE5E7EB),
      ),
      boxShadow: [
        BoxShadow(
          color: _isDarkMode
              ? Colors.black.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.04),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isResultExitBlocked) return;
        unawaited(_exitResultWithInterstitial());
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          leading: widget.isTutorial
              ? null
              : IconButton(
                  icon: Icon(CupertinoIcons.back, color: textColor, size: 30),
                  onPressed: _isResultExitBlocked
                      ? null
                      : () => unawaited(_exitResultWithInterstitial()),
                ),
          title: widget.isTutorial ? TutorialIndicator() : null,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _shareWidgetKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImageGridViewer(
                      images: widget.images != null && widget.images!.isNotEmpty
                          ? widget.images!
                          : [widget.image],
                      onTap: (i) {
                        final files =
                            widget.images != null && widget.images!.isNotEmpty
                                ? widget.images!
                                : [widget.image];
                        _showFullImage(files: files, initialIndex: i);
                      },
                    ),
                    SizedBox(height: 16),
                    if (showDecisionArea) ...[
                      _buildDecisionSummarySection(),
                      SizedBox(height: 16),
                    ],

                    // ✅ NEW UI (JSON-based) with fallback to old text
                    _buildScanResultCard(
                      localizations: localizations!,
                      textColor: textColor,
                      boxDecoration: boxDecoration,
                    ),

                    // ✅ 여기! 결과 카드 바깥 바로 아래에 “근처 타인 메뉴 태그”
                    _buildNearbyMenuTags(),

                    // ✅ RAG Answer (허용 사용자만)
                    if (_isAllowedUser &&
                        (_ragDetail?.isNotEmpty ?? false) &&
                        _decisionLocalInsights().length < 3) ...[
                      SizedBox(height: 16),
                      Container(
                        decoration: boxDecoration,
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RAG Answer',
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              _ragDetail!,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 12,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (showResultActions) ...[
                      SizedBox(height: 16),
                      Container(
                        decoration: boxDecoration,
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.reviewTitle,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _reviewController,
                              maxLines: 3,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 14,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: localizations.reviewHint,
                                hintStyle: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (showResultActions)
                      SafeArea(
                        bottom: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    final comment =
                                        _reviewController.text.trim();
                                    LogService().logSaveClick(
                                      hasComment: comment.isNotEmpty,
                                      contentLength: comment.length,
                                      context: 'result',
                                    );

                                    if (!_isMergeDone) {
                                      if (!_pendingSave) {
                                        setState(() => _pendingSave = true);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                AppLocalizations.of(context)!
                                                    .mergeInProgress),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    _saveScanResult();
                                  },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey
                                  : Colors.white,
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey,
                              minimumSize: Size(double.infinity, 48),
                              textStyle:
                                  TextStyle(fontFamily: 'SFPro', fontSize: 14),
                            ),
                            child: Text(localizations.save),
                          ),
                        ),
                      ),
                    if (_isLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 10.0),
                        ),
                      ),
                    if (_isLoadingError)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              color:
                                  _isDarkMode ? Colors.redAccent : Colors.red,
                              size: 40.0,
                            ),
                            SizedBox(height: 20),
                            Text(
                              localizations.cloudsavingError,
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'SFProText',
                                color: _isDarkMode
                                    ? Colors.white70
                                    : CupertinoColors.systemGrey,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiSparkleIconButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final double size;

  const AiSparkleIconButton({
    super.key,
    required this.isLoading,
    required this.onTap,
    this.size = 44,
  });

  @override
  State<AiSparkleIconButton> createState() => _AiSparkleIconButtonState();
}

class _AiSparkleIconButtonState extends State<AiSparkleIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isLoading) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AiSparkleIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.isLoading && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Center(
                child: OverflowBox(
                  maxWidth: s * 1.2,
                  maxHeight: s * 1.2,
                  child: Image.asset(
                    'assets/icons/aifood.png',
                    width: s * 1.2,
                    height: s * 1.2,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // ✅ "스파클만" 반짝이기 (로딩일 때만)
            if (widget.isLoading)
              Positioned(
                // 스파클이 있는 쪽(좌상단)만 덮기. 필요하면 값 튜닝.
                left: s * 0.00,
                top: s * 0.01,
                width: s * 0.75, // 50% 정도 확대
                height: s * 0.82, // 50% 정도 확대
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final t = _c.value; // 0..1
                      return CustomPaint(
                        painter: _SparkleTwinklePainter(t: t),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SparkleTwinklePainter extends CustomPainter {
  final double t;
  _SparkleTwinklePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // 3개의 별을 서로 다른 위상으로 "반짝"이게
    _drawStar(
      canvas,
      size,
      center: Offset(size.width * 0.30, size.height * 0.30),
      baseRadius: size.shortestSide * 0.10, // 0.07 -> 0.10
      phase: 0.0,
    );
    _drawStar(
      canvas,
      size,
      center: Offset(size.width * 0.55, size.height * 0.18),
      baseRadius: size.shortestSide * 0.075, // 0.05 -> 0.075
      phase: 0.33,
    );
    _drawStar(
      canvas,
      size,
      center: Offset(size.width * 0.18, size.height * 0.55),
      baseRadius: size.shortestSide * 0.06, // 0.04 -> 0.06
      phase: 0.66,
    );
  }

  void _drawStar(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double baseRadius,
    required double phase,
  }) {
    // 트윙클: opacity + scale
    final wave = (math.sin((t + phase) * math.pi * 2) + 1) / 2; // 0..1
    final opacity = ui.lerpDouble(0.15, 1.0, wave)!;
    final scale = ui.lerpDouble(0.85, 1.18, wave)!;

    final rOuter = baseRadius * scale;
    final rInner = rOuter * 0.45;

    // glow(blur) 먼저
    final glowPaint = Paint()
      ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.55 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, rOuter * 0.95, glowPaint);

    // star 본체
    final starPaint = Paint()
      ..color = const Color(0xFFFFE08A).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    const points = 4; // 4방 별(스파클 느낌)
    final step = math.pi / points;
    double angle = -math.pi / 2;

    for (int i = 0; i < points * 2; i++) {
      final radius = (i.isEven) ? rOuter : rInner;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    canvas.drawPath(path, starPaint);

    // 하이라이트(작은 점) — 반짝이는 맛 추가
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center.translate(rOuter * 0.35, -rOuter * 0.15),
        rOuter * 0.12, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparkleTwinklePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class AnimatedDotsText extends StatefulWidget {
  final String baseText;
  final TextStyle? style;
  final Duration period; // 전체 주기
  const AnimatedDotsText({
    super.key,
    required this.baseText,
    this.style,
    this.period = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedDotsText> createState() => _AnimatedDotsTextState();
}

class _AnimatedDotsTextState extends State<AnimatedDotsText> {
  Timer? _timer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      Duration(milliseconds: widget.period.inMilliseconds ~/ 3),
      (_) {
        if (!mounted) return;
        setState(() => _dots = (_dots + 1) % 4); // 0~3
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotStr = '.' * _dots;
    return Text('${widget.baseText}$dotStr', style: widget.style);
  }
}
