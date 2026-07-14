import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'mapscreen.dart';
import 'package:getwidget/getwidget.dart'; // GetWidget 패키지 임포트
import 'dart:convert';
import 'package:mscanner/utils/ai_result_copy_formatter.dart';
import 'package:mscanner/widgets/result/result_decision_cards.dart';

class _FavoriteMenuNamePair {
  final String original;
  final String translated;
  const _FavoriteMenuNamePair(
      {required this.original, required this.translated});

  String get display =>
      translated.trim().isNotEmpty ? translated.trim() : original.trim();
}

class FavoriteScreen extends StatefulWidget {
  final String documentId;

  const FavoriteScreen({super.key, required this.documentId});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  bool _isDarkMode = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  final GlobalKey _shareWidgetKey = GlobalKey();
  Map<String, dynamic>? _favoriteData;
  final TextEditingController _restaurantNameController =
      TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 0;

  String? _extractJsonObjectFromText(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    // 1) ```json ... ``` 코드블럭 제거
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
      s = s.replaceAll(RegExp(r'\s*```$'), '');
      s = s.trim();
    }

    // 2) 앞에 RECOMMEND/기타 텍스트가 붙어있으면 첫 '{'부터 자르기
    final start = s.indexOf('{');
    if (start < 0) return null;

    // 3) 마지막 '}'까지 자르기
    final end = s.lastIndexOf('}');
    if (end < 0 || end <= start) return null;

    final candidate = s.substring(start, end + 1).trim();
    if (!candidate.startsWith('{') || !candidate.endsWith('}')) return null;

    return candidate;
  }

  String _buildReadableCopyText() {
    return AiResultCopyFormatter.buildReadableText(
      aiJson: _aiJson,
      fallbackResponses: _normalizedResponses,
      priceLabelBuilder: (item) {
        final price = (item['price'] ?? '').toString().trim();
        return price.isEmpty ? null : price;
      },
      labels: AiResultCopyFormatterLabels(
        recommendedTitle:
            AppLocalizations.of(context)?.aiAnswer ?? 'Recommended Dishes',
        summaryTitle:
            AppLocalizations.of(context)?.favorite_summary ?? 'Summary',
        priceLabel: '가격',
        tagsLabel: '태그',
        noContentFallback: AppLocalizations.of(context)?.favorite_noResponses ??
            'No responses available',
      ),
    );
  }

  // ✅ JSON(칩 UI) 지원
  Map<String, dynamic>? _aiJson;
  List<String> _normalizedResponses = const [];

  @override
  void initState() {
    super.initState();
    _checkDarkMode();
    _fetchFavoriteData();
  }

  Future<void> _checkDarkMode() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    if (!mounted) return;
    setState(() {
      _isDarkMode = savedThemeMode == AdaptiveThemeMode.dark;
    });
  }

  Future<void> _fetchFavoriteData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('user_rating')
          .doc(user.uid)
          .collection('data')
          .doc(widget.documentId)
          .get();

      if (!mounted) return;
      if (docSnapshot.exists) {
        setState(() {
          _favoriteData = docSnapshot.data() as Map<String, dynamic>?;
          _restaurantNameController.text =
              _favoriteData?['restaurantName'] ?? 'Unknown restaurant';
          _rating = _favoriteData?['rating'] ?? 0;
          _reviewController.text = _favoriteData?['review'] ?? '';
          _reviewController.addListener(() {
            setState(() {
              _hasChanges = true;
            });
          });

          // 추가: 위도와 경도 데이터 가져오기

          // Listener to detect changes in the restaurant name
          _restaurantNameController.addListener(() {
            setState(() {
              _hasChanges = _restaurantNameController.text !=
                  _favoriteData?['restaurantName'];
            });
          });
        });

        // ✅ responses 정규화 + JSON 파싱(구버전 호환)
        final data = docSnapshot.data() as Map<String, dynamic>?;
        final rawList = data?['responses'];
        final rawSingle = data?['response'];
        List<String> normalized;
        if (rawList is List) {
          normalized = rawList.map((e) => e.toString()).toList();
        } else if (rawSingle != null) {
          normalized = [rawSingle.toString()];
        } else {
          normalized = [];
        }
        _normalizedResponses = normalized;
        _parseAiJsonFromResponses(normalized);
      }
    }
  }

  void _parseAiJsonFromResponses(List<String> responses) {
    Map<String, dynamic>? firstJson;
    final List<Map<String, dynamic>> jsonList = [];

    for (final r in responses) {
      final s = _extractJsonObjectFromText(r);
      if (s == null) continue;

      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          firstJson ??= m;
          jsonList.add(m);
        }
      } catch (_) {
        continue;
      }
    }

    if (firstJson == null) {
      _aiJson = null;
      return;
    }

    // 멀티 JSON 병합 로직은 기존 그대로 사용
    if (jsonList.length <= 1) {
      _aiJson = firstJson;
      return;
    }

    final merged = Map<String, dynamic>.from(firstJson);

    final List<Map<String, dynamic>> recommendedAll = [];
    final Map<String, List<Map<String, dynamic>>> fullMenuAll = {
      'main': <Map<String, dynamic>>[],
      'side': <Map<String, dynamic>>[],
      'meal': <Map<String, dynamic>>[],
      'drink': <Map<String, dynamic>>[],
      'beverage': <Map<String, dynamic>>[],
      'unknown': <Map<String, dynamic>>[],
    };

    String dedupKey(Map<String, dynamic> item) {
      final no = (item['nameOriginal'] ?? '').toString().trim().toLowerCase();
      final nt = (item['name'] ?? '').toString().trim().toLowerCase();
      return (no.isNotEmpty ? no : nt).isNotEmpty
          ? (no.isNotEmpty ? no : nt)
          : item.toString();
    }

    List<Map<String, dynamic>> dedupList(List<Map<String, dynamic>> items) {
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final it in items) {
        if (seen.add(dedupKey(it))) out.add(it);
      }
      return out;
    }

    for (final j in jsonList) {
      final rec = j['recommended'];
      if (rec is List) {
        for (final e in rec) {
          if (e is Map) recommendedAll.add(Map<String, dynamic>.from(e));
        }
      }

      final fm = j['fullMenu'] ?? j['full_menu'] ?? j['menu'] ?? j['menus'];
      if (fm is Map) {
        final src = (fm['items'] is Map)
            ? Map<String, dynamic>.from(fm['items'] as Map)
            : Map<String, dynamic>.from(fm);

        for (final k in fullMenuAll.keys) {
          final v = src[k];
          if (v is List) {
            for (final e in v) {
              if (e is Map) fullMenuAll[k]!.add(Map<String, dynamic>.from(e));
            }
          }
        }
      }
    }

    merged['recommended'] = dedupList(recommendedAll);
    merged['fullMenu'] = {
      'items': {
        for (final k in fullMenuAll.keys) k: dedupList(fullMenuAll[k]!)
      },
      'summary': (firstJson['fullMenu'] is Map)
          ? ((firstJson['fullMenu']['summary'] ?? '').toString())
          : '',
      'truncated': (firstJson['fullMenu'] is Map)
          ? (firstJson['fullMenu']['truncated'] == true)
          : false,
    };

    _aiJson = merged;
  }

  List<Map<String, dynamic>> _getRecommendedItems() {
    final j = _aiJson;
    if (j == null) return const [];
    final rec = j['recommended'];
    if (rec is List) {
      return rec
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  void _showFullMenuSheet(Color textColor) {
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
      summary = null;
      truncated = false;
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
                            AppLocalizations.of(context)?.favorite_fullMenu ??
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
                                          'Summary (truncated)')
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
                        ..._buildMenuSection(
                          AppLocalizations.of(context)?.favorite_menuMain ??
                              'Main',
                          itemsMap?['main'],
                          textColor,
                        ),
                        ..._buildMenuSection(
                          AppLocalizations.of(context)?.favorite_menuSide ??
                              'Side',
                          itemsMap?['side'],
                          textColor,
                        ),
                        ..._buildMenuSection(
                          AppLocalizations.of(context)?.favorite_menuMeal ??
                              'Meal',
                          itemsMap?['meal'],
                          textColor,
                        ),
                        ..._buildMenuSection(
                          AppLocalizations.of(context)?.favorite_menuDrink ??
                              'Drink',
                          itemsMap?['drink'],
                          textColor,
                        ),
                        ..._buildMenuSection(
                          AppLocalizations.of(context)?.favorite_menuBeverage ??
                              'Beverage',
                          itemsMap?['beverage'],
                          textColor,
                        ),
                        ..._buildMenuSection(
                          AppLocalizations.of(context)?.favorite_menuOther ??
                              'Other',
                          itemsMap?['unknown'],
                          textColor,
                        ),
                        if ((itemsMap ?? {}).isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              AppLocalizations.of(context)
                                      ?.favorite_noResponses ??
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

  List<Widget> _buildMenuSection(String title, dynamic items, Color textColor) {
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
            final price = _priceLabelFromItem(m) ?? '';

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
                      if (price.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: priceBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            price,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
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

  double? _parseAmountAny(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.trim().replaceAll(',', '').replaceAll('\u00A0', ' ');
      if (cleaned.isEmpty) return null;
      final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
      if (m == null) return null;
      return double.tryParse(m.group(1)!);
    }
    return null;
  }

  String? _currencyCodeFromItem(Map<String, dynamic> item) {
    String? code;
    final prices = item['prices'];
    if (prices is Map) {
      code = (prices['currency'] ?? prices['currencyCode'])?.toString();
    }
    code ??= (item['currency'] ?? item['currencyCode'] ?? item['priceCurrency'])
        ?.toString();
    final c = code?.trim().toUpperCase();
    return (c == null || c.isEmpty || c == 'NULL') ? null : c;
  }

  String? _symbolForCurrency(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'KRW':
        return '₩';
      case 'JPY':
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

  String _commaInt(int n) {
    final sign = n < 0 ? '-' : '';
    var s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    return sign + buf.toString();
  }

  String _formatAmount(double v) {
    if ((v - v.roundToDouble()).abs() < 0.000001) return _commaInt(v.round());
    var s = v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    final parts = s.split('.');
    final head = _commaInt(int.tryParse(parts.first) ?? 0);
    return parts.length == 2 ? '$head.${parts[1]}' : head;
  }

  String _formatMoney(double amount, {String? currencyCode}) {
    final sym = _symbolForCurrency(currencyCode);
    final a = _formatAmount(amount);
    if (sym != null && sym.isNotEmpty) {
      final base = '$sym$a';
      if (currencyCode == 'USD' ||
          currencyCode == 'JPY' ||
          currencyCode == 'CNY') {
        return '$base ($currencyCode)';
      }
      return base;
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      return '$currencyCode $a';
    }
    return a;
  }

  String _formatMoneyRange(double min, double max, {String? currencyCode}) {
    final sym = _symbolForCurrency(currencyCode);
    final aMin = _formatAmount(min);
    final aMax = _formatAmount(max);
    if (sym != null && sym.isNotEmpty) {
      var base = '$sym$aMin~$sym$aMax';
      if (currencyCode == 'USD' ||
          currencyCode == 'JPY' ||
          currencyCode == 'CNY') {
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
    final vals = <double>[];
    final prices = item['prices'];
    if (prices is Map) {
      for (final k in const ['single', 'small', 'medium', 'large']) {
        final a = _parseAmountAny(prices[k]);
        if (a != null && a > 0) vals.add(a);
      }
    }
    if (vals.isEmpty) {
      final raw = (item['price'] ?? '').toString().trim();
      if (raw.isNotEmpty && RegExp(r'[^\d\s,.]').hasMatch(raw)) {
        return raw;
      }
      final a = _parseAmountAny(item['price']);
      if (a != null && a > 0) vals.add(a);
    }
    if (vals.isEmpty) return null;
    vals.sort();
    return vals.length == 1
        ? _formatMoney(vals.first, currencyCode: code)
        : _formatMoneyRange(vals.first, vals.last, currencyCode: code);
  }

  bool _hasAnyFullMenuItems(Map<String, dynamic>? itemsMap) {
    if (itemsMap == null || itemsMap.isEmpty) return false;
    for (final v in itemsMap.values) {
      if (v is List && v.isNotEmpty) return true;
    }
    return false;
  }

  bool _hasUsableFullMenu() {
    final j = _aiJson;
    if (j == null) return false;
    final rawFm = j['fullMenu'] ?? j['full_menu'] ?? j['menu'] ?? j['menus'];
    if (rawFm is! Map) return false;

    Map<String, dynamic>? itemsMap;
    String summary = '';
    if (rawFm['items'] is Map) {
      itemsMap = Map<String, dynamic>.from(rawFm['items'] as Map);
      summary = (rawFm['summary'] ?? '').toString().trim();
    } else {
      itemsMap = Map<String, dynamic>.from(rawFm);
      summary = (rawFm['summary'] ?? '').toString().trim();
    }
    return _hasAnyFullMenuItems(itemsMap) || summary.isNotEmpty;
  }

  _FavoriteMenuNamePair? _extractPrimaryMenuPair() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return null;
    final first = rec.first;
    final original = (first['nameOriginal'] ?? '').toString().trim();
    final translated = (first['name'] ?? '').toString().trim();
    if (original.isEmpty && translated.isEmpty) return null;
    return _FavoriteMenuNamePair(original: original, translated: translated);
  }

  String _decisionTitle() {
    final pair = _extractPrimaryMenuPair();
    if (pair != null && pair.display.isNotEmpty) return pair.display;
    return (_favoriteData?['primary_menu'] ??
            _favoriteData?['menu_name'] ??
            _favoriteData?['menuName'] ??
            _favoriteData?['restaurantName'] ??
            AppLocalizations.of(context)?.favorite_unknownRestaurant ??
            'Scan result')
        .toString();
  }

  String? _decisionOriginalTitle() {
    final pair = _extractPrimaryMenuPair();
    if (pair == null) return null;
    final title = pair.display.trim().toLowerCase();
    final original = pair.original.trim();
    if (original.isEmpty || original.toLowerCase() == title) return null;
    return original;
  }

  String _decisionSubtitle() {
    final country = (_favoriteData?['country'] ?? '').toString().trim();
    final city = (_favoriteData?['city'] ?? '').toString().trim();
    final restaurant =
        (_favoriteData?['restaurantName'] ?? '').toString().trim();
    final location = [country, city].where((e) => e.isNotEmpty).join(', ');
    if (restaurant.isNotEmpty && location.isNotEmpty) {
      return '$restaurant · $location';
    }
    if (restaurant.isNotEmpty) {
      return restaurant;
    }
    if (location.isNotEmpty) {
      return location;
    }
    return AppLocalizations.of(context)?.aiAnswer ?? 'Recommended Dishes';
  }

  String? _decisionReason() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return null;
    final desc = (rec.first['shortDesc'] ?? '').toString().trim();
    return desc.isEmpty ? null : desc;
  }

  String? _decisionPriceLabel() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return null;
    return _priceLabelFromItem(rec.first);
  }

  List<String> _decisionQuickTags() {
    final rec = _getRecommendedItems();
    if (rec.isEmpty) return const [];
    final tags = rec.first['tags'];
    if (tags is! List) return const [];
    return tags
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
  }

  List<String> _decisionLocalInsights() {
    final out = <String>[];
    final other = (_favoriteData?['other'] ?? '').toString().trim();
    final country = (_favoriteData?['country'] ?? '').toString().trim();
    final city = (_favoriteData?['city'] ?? '').toString().trim();
    final whenRaw = (_favoriteData?['timestamp'] ?? '').toString().trim();

    if (city.isNotEmpty || country.isNotEmpty) {
      out.add([city, country].where((e) => e.isNotEmpty).join(', '));
    }
    if (other.isNotEmpty) out.add(other);
    if (whenRaw.isNotEmpty) {
      try {
        out.add(DateFormat('MMM dd, yyyy').format(DateTime.parse(whenRaw)));
      } catch (_) {}
    }
    return out.take(3).toList();
  }

  Widget _buildDecisionSummarySection() {
    final title = _decisionTitle();
    return ResultDecisionCards(
      isDarkMode: _isDarkMode,
      title: title,
      originalTitle: _decisionOriginalTitle(),
      subtitle: _decisionSubtitle(),
      decisionReason: _decisionReason(),
      priceLabel: _decisionPriceLabel(),
      tags: _decisionQuickTags(),
      localInsights: _decisionLocalInsights(),
      onPriceTap: () {},
      onLocalInsightTap: () {},
    );
  }

  Widget _buildDishRow(
    Map<String, dynamic> item,
    Color textColor, {
    required bool isPrimaryRecommended,
  }) {
    final nameOriginal = (item['nameOriginal'] ?? '').toString().trim();
    final nameTranslated = (item['name'] ?? '').toString().trim();
    final desc = (item['shortDesc'] ?? '').toString();
    final priceLabel = _priceLabelFromItem(item);

    final label = nameOriginal.isNotEmpty ? nameOriginal : nameTranslated;
    if (label.isEmpty) return const SizedBox.shrink();

    final showTranslation = nameTranslated.isNotEmpty &&
        nameOriginal.isNotEmpty &&
        nameTranslated.toLowerCase() != nameOriginal.toLowerCase();

    final primary = nameOriginal.isNotEmpty ? nameOriginal : nameTranslated;
    final secondary = showTranslation ? nameTranslated : '';

    final tags = (item['tags'] is List)
        ? (item['tags'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultRecommendationCompactCard(
            isDarkMode: _isDarkMode,
            primaryName: primary,
            secondaryName: secondary,
            summary: desc,
            priceLabel: priceLabel,
            tags: tags,
            trailing: null,
            onPriceTap: () {},
          ),
          if (isPrimaryRecommended) const SizedBox(height: 4),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAiAnswerSection({
    required Color textColor,
    required BoxDecoration boxDecoration,
    required String responseText,
  }) {
    final rec = _getRecommendedItems();

    final hasJsonUi = _aiJson != null && rec.isNotEmpty;

    // ✅ 구버전 호환: JSON 없으면 기존 텍스트 출력 유지
    if (!hasJsonUi) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: boxDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.aiAnswer,
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              responseText.isNotEmpty
                  ? responseText
                  : (AppLocalizations.of(context)?.favorite_noResponses ??
                      'No responses available'),
              style: TextStyle(fontSize: 12, color: textColor),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                    onPressed: () => _copyTextToClipboard(responseText),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.square_arrow_up,
                        color: Colors.blue, size: 24),
                    onPressed: _shareCapturedImage,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ✅ JSON(칩) UI
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.home_mscannerPicks ??
                AppLocalizations.of(context)!.aiAnswer,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...rec.asMap().entries.map((entry) {
            return _buildDishRow(
              entry.value,
              textColor,
              isPrimaryRecommended: entry.key == 0,
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _hasUsableFullMenu()
                      ? () => _showFullMenuSheet(textColor)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF2A2A2E)
                          : const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.square_list,
                          size: 18,
                          color: textColor.withValues(alpha: 0.86),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)?.favorite_viewFullMenu ??
                              'View Full Menu',
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.chevron_up_chevron_down,
                          size: 13,
                          color: textColor.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ),
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
                      Icons.copy,
                      color: textColor.withValues(alpha: 0.86),
                      size: 20,
                    ),
                    onPressed: () =>
                        _copyTextToClipboard(_buildReadableCopyText())),
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
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && _favoriteData != null) {
      try {
        await FirebaseFirestore.instance
            .collection('user_rating')
            .doc(user.uid)
            .collection('data')
            .doc(widget.documentId)
            .update({
          'restaurantName': _restaurantNameController.text,
          'rating': _rating,
          'review': _reviewController.text.trim(), // ✅ 여기
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.saved ?? 'Saved'),
          ),
        );

        setState(() {
          _hasChanges = false; // 저장 후 변경 상태 초기화
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.favorite_failedSaveChanges ?? 'Failed to save changes'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _shareCapturedImage() async {
    try {
      // 위젯이 완전히 렌더링된 후에 캡처하도록 합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RenderRepaintBoundary? boundary = _shareWidgetKey.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;

        if (boundary == null) {
          debugPrint('RenderRepaintBoundary is still null');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context)?.favorite_renderNotReady ??
                      'Error: RenderRepaintBoundary is not ready.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // 현재 디바이스의 픽셀 비율을 가져오고, 해상도를 높이기 위해 두 배로 설정
        if (!mounted) return;
        double pixelRatio = MediaQuery.of(context).devicePixelRatio;
        double desiredPixelRatio = pixelRatio * 2;
        final shareText = AppLocalizations.of(context)?.checkOutRestaurant ??
            'Check out this restaurant!';

        // 높은 픽셀 비율로 이미지 캡처
        var image = await boundary.toImage(pixelRatio: desiredPixelRatio);
        ByteData? byteData =
            await image.toByteData(format: ImageByteFormat.png);
        if (byteData == null) return;
        Uint8List pngBytes = byteData.buffer.asUint8List();

        // 임시 파일로 저장
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/shared_image.png').create();
        await file.writeAsBytes(pngBytes);

        // 쉐어 기능 호출
        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
        );
      });
    } catch (e) {
      // 예외 발생 시 로그 출력
      debugPrint('Error sharing the image: $e');
    }
  }

  void _copyTextToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.textCopied ??
              'Text copied to clipboard',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    if (_favoriteData == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(backgroundColor: backgroundColor),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    // ✅ responses 정규화(구버전 호환) + 텍스트 fallback
    final normalized = _normalizedResponses;
    final String responseText = normalized.join('\n\n');

    if (_favoriteData == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: textColor,
            size: 30.0,
          ),
          onPressed: () {
            if (!_isLoading) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: RepaintBoundary(
              key: _shareWidgetKey, // GlobalKey 연결
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이미지 및 레스토랑 이름, 레이팅을 포함하는 Stack
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _showFullImage, // 이미지 클릭 시 전체 화면 표시
                        child: GFImageOverlay(
                          height: MediaQuery.of(context).size.height / 2,
                          width: double.infinity,
                          image: NetworkImage(_favoriteData!['image_url']),
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 위치 정보 및 시간 정보
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: _navigateToMapScreen, // 지도 화면으로 이동
                                      child: Row(
                                        children: [
                                          Icon(CupertinoIcons.placemark,
                                              color: Colors.white),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${_favoriteData!['country'] ?? 'Unknown Country'}, ${_favoriteData!['city'] ?? 'Unknown City'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: _navigateToMapScreen,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 32,
                                          ),
                                          Expanded(
                                            child: Text(
                                              _favoriteData!['other'] ??
                                                  'Unknown other',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                              softWrap: true,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // 시간 정보
                                Row(
                                  children: [
                                    Icon(CupertinoIcons.time,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMM dd, yyyy - h:mm a')
                                            .format(
                                          DateTime.parse(
                                              _favoriteData!['timestamp']),
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Spacer(), // 위젯 간의 간격을 조절
                                // 레스토랑 이름 입력 가능
                                TextField(
                                  controller: _restaurantNameController,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)
                                            ?.favorite_restaurantNameHint ??
                                        '레스토랑 이름',
                                    hintStyle: TextStyle(color: Colors.white70),
                                    border: InputBorder.none,
                                  ),
                                  maxLines: 1,
                                ),
                                SizedBox(height: 8),
                                // 레이팅을 이미지 하단에 배치
                                Row(
                                  children: List.generate(5, (index) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _rating = index + 1;
                                          _hasChanges = _rating !=
                                                  (_favoriteData?['rating'] ??
                                                      0) ||
                                              _restaurantNameController.text
                                                      .trim() !=
                                                  (_favoriteData?[
                                                          'restaurantName'] ??
                                                      '');
                                        });
                                      },
                                      child: Icon(
                                        index < _rating
                                            ? CupertinoIcons.star_fill
                                            : CupertinoIcons.star,
                                        color: index < _rating
                                            ? Colors.amber
                                            : Colors.grey,
                                        size: 24.0,
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildDecisionSummarySection(),
                  SizedBox(height: 16),
                  // ✅ AI 응답 (JSON 칩 UI + 구버전 텍스트 fallback)
                  _buildAiAnswerSection(
                    textColor: textColor,
                    boxDecoration: boxDecoration,
                    responseText: responseText,
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: boxDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.reviewTitle ?? 'Review',
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
                            hintText: AppLocalizations.of(context)
                                    ?.reviewHint ??
                                'Write your thoughts about this restaurant...',
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
              ),
            ),
          ),
          if (_hasChanges)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      foregroundColor:
                          _isDarkMode ? Colors.white : const Color(0xFF111827),
                      backgroundColor: _isDarkMode
                          ? const Color(0xFF2A2A2E)
                          : const Color(0xFFF6F7F9),
                      disabledForegroundColor:
                          (_isDarkMode ? Colors.white : const Color(0xFF111827))
                              .withValues(alpha: 0.4),
                      disabledBackgroundColor: (_isDarkMode
                              ? const Color(0xFF2A2A2E)
                              : const Color(0xFFF6F7F9))
                          .withValues(alpha: 0.7),
                      textStyle: const TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.save),
                  ),
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
        ],
      ),
    );
  }

  // 지도 화면으로 이동하는 함수
  void _navigateToMapScreen() {
    if (_favoriteData != null) {
      String restaurantName = _favoriteData?['restaurantName'] ??
          AppLocalizations.of(context)?.favorite_unknownRestaurant ??
          'Unknown Restaurant';
      GeoPoint geoPoint =
          _favoriteData?['gps'] ?? GeoPoint(0.0, 0.0); // gps 필드가 없을 경우 기본값 설정

      double latitude = geoPoint.latitude;
      double longitude = geoPoint.longitude;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            restaurantName: restaurantName,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
      );
    }
  }

  // 이미지 전체화면 표시 함수 수정
  void _showFullImage() {
    if (_favoriteData == null) return; // 데이터가 null이면 종료

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context); // 탭하면 다이얼로그 닫힘
              },
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      panEnabled: true, // 패닝 활성화
                      minScale: 1.0, // 최소 확대 비율
                      maxScale: 4.0, // 최대 확대 비율
                      child: Image.network(
                        _favoriteData!['image_url'],
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  // 오른쪽 상단 닫기 버튼
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: Icon(
                        CupertinoIcons.clear,
                        color: Colors.white,
                        size: 30.0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _reviewController.dispose();
    super.dispose();
  }
}
