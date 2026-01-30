import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '/screens/Home_Screen.dart';
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
import 'package:in_app_review/in_app_review.dart';
import 'nutrition_chart.dart';
import '/screens/log_service.dart'; // ✅ 로그 서비스 추가
import 'package:flutter/gestures.dart';
import 'package:mscanner/widgets/tutorial_indicator.dart';
import 'dart:typed_data'; // Uint8List 사용
import '/screens/image_merge_service.dart'; // ImageMergeService 경로에 맞게 수정
import '/widgets/image_grid_viewer.dart'; // ✅ 로그 서비스 추가
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:mscanner/widgets/fx_auto_converter_card.dart';

// NOTE: searched_menu 저장은 UI 흐름과 분리(비동기)해서 실행합니다.

/// 파일 최상단에 선언
Future<Uint8List> mergeImages(List<Uint8List> bytesList) async {
  return await ImageMergeService.mergeAndCompress(bytesList);
}

class ResultScreen extends StatefulWidget {
  final File image;
  final List<File>? images;      // ← 멀티 이미지 리스트 필드 추가
  final List<String> responses;   // ← String → List<String>
  final Position? position;
  final DateTime captureTime;
  final bool isFromHistory;
  final String? title;
  final String? location;
  final String? geohash; // Added geohash
  final String? ragDetail; // Added ragDetail
  final bool isTutorial; // ✅ 추가

  ResultScreen({
    required this.image,
    this.images,                  // ← 생성자에 images 파라미터 추가
    required this.responses,       // ← List<String> 받도록
    this.position,
    required this.captureTime,
    this.isFromHistory = false,
    this.title,
    this.location,
    this.geohash, // Added geohash
    this.ragDetail, // Added ragDetail
    this.isTutorial = false, // ✅ 기본값 false
  });

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _MenuTag {
  final String name;
  final int count;
  const _MenuTag(this.name, this.count);
}

class _ResultScreenState extends State<ResultScreen> {
  // === Auto FX: detected hints ===
  String? _isoCountryCode;                 // e.g., 'KR', 'JP'
  String? _currencySymbolHint;             // e.g., '₩','€','$','¥'
  double? _amountFromResponses;            // extracted number from AI response

  bool _sentAiImpression = false;
  bool _sentRagImpression = false;

  // 🔽🔽🔽 [NEW] 다중 금액 후보 보관 리스트
  List<double> _amountCandidates = [];     // ex) [12500, 3500, 7000]

  // ✅ 주변 타인 메뉴 태그 Future
  Future<List<_MenuTag>>? _nearbyMenuTagsFuture;

  Future<void> _initCountryCurrencyHints() async {
    try {
      // Extract from responses
      final raw = widget.responses.join('\n\n');
      _currencySymbolHint = _extractCurrencySymbolFromText(raw);
      _amountFromResponses = _extractAmountFromText(raw);
      _amountCandidates = _extractAmountsNextToFoodNames(raw);

      // Country ISO2 from GPS if available
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

      // Fallback to device locale
      _isoCountryCode ??=
          ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  // Extract first number (e.g., 12,500 or 12.50)
  double? _extractAmountFromText(String text) {
    final cleaned = text.replaceAll(',', ' ').replaceAll('\u00A0', ' ');
    final regex = RegExp(r'(\d+[\s\d]*\.?\d*)');
    final m = regex.firstMatch(cleaned);
    if (m == null) return null;
    final numStr = m.group(1)!.replaceAll(' ', '');
    return double.tryParse(numStr);
  }

  // Detect currency symbol from text
  String? _extractCurrencySymbolFromText(String text) {
    // '$','¥'는 모호해도 힌트로 사용 (국가코드/로케일로 보정)
    const symbols = ['₩', '€', '£', '₫', '₱', '฿', '₹', '¥', '\$'];
    for (final s in symbols) {
      if (text.contains(s)) return s;
    }
    return null;
  }

  /// AI 응답에서 1번 메뉴만 추출
  /// - "1.", "1)", "1).", "1]", "1:", "1-" 등 허용
  /// - "1." 형태가 없으면 null 반환(=저장 스킵)
  String? _extractMenuOnlyFromAiResponses() {
    final joined = widget.responses.join('\n').replaceAll('\r', '');
    final lines = joined.split('\n');

    String? first;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // ✅ 1번 표기 모두 허용
      final reFirstItemPrefix = RegExp(r'^\s*1\s*[\.\)\]\:\-]\.?\s*');
      final m = reFirstItemPrefix.firstMatch(line);

      if (m != null) {
        first = line.substring(m.end).trim();

        // ✅ 같은 줄에 "2.", "2)", "2:"... 붙어 있으면 여기서 컷
        final nextItem = RegExp(r'\s*[2-9]\s*[\.\)\]\:\-]\.?\s*');
        final cut = nextItem.firstMatch(first);
        if (cut != null && cut.start > 0) {
          first = first.substring(0, cut.start).trim();
        }
        break;
      }
    }

    if (first == null || first.isEmpty) return null;

    // 꼬리 설명 컷
    final cutTokens = <String>[' - ', ' – ', ' — ', ': ', '(', '[', '|'];
    for (final t in cutTokens) {
      final idx = first!.indexOf(t);
      if (idx > 0) {
        first = first.substring(0, idx).trim();
      }
    }

    // 끝에 붙은 가격/숫자 제거 (예: "Kimchi 12000")
    first = first!.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();

    if (first.length < 2) return null;
    return first;
  }

  /// searched menu 컬렉션에 (geohash + 메뉴명 + 시스템언어)만 비동기로 저장
  void _saveSearchedMenuFireAndForget() {
    if (widget.isTutorial) return;
    if (widget.isFromHistory) return; // 히스토리 진입 시 중복 저장 방지
    if (_geohash == null) return;

    final menuName = _extractMenuOnlyFromAiResponses();
    if (menuName == null) return;

    final systemLang = ui.PlatformDispatcher.instance.locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;

    unawaited(() async {
      try {
        await FirebaseFirestore.instance.collection('searched menu').add({
          'menu_name': menuName,
          'geohash': _geohash,
          'lang': systemLang,
          'timestamp': DateTime.now().toIso8601String(),
          if (user != null) 'uid': user.uid,
        });
      } catch (e) {
        if (kDebugMode) {
          print('❌ searched_menu 저장 실패: $e');
        }
      }
    }());
  }

  String _safePrefix(String geohash, int len) {
    if (geohash.isEmpty) return geohash;
    if (len <= 0) return geohash;
    return geohash.substring(0, geohash.length < len ? geohash.length : len);
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
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();

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
          if (kDebugMode) print('❌ nearby tags error: ${snap.error}');
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(width: 1),
                        ),
                        child: Text(
                          '#${t.name}(${t.count})',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
  TextEditingController _storeNameController = TextEditingController();
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

  Timer? _timer; // Timer variable
  bool _isLoadingError = false; // Error state variable

  String? _geohash; // Variable to store geohash
  String? _ragDetail; // Variable to store ragDetail

  // New variable
  String? _foodDetail; // Variable to store foodDetail
  List<File> _viewerImages = [];
  int _viewerInitialIndex = 0;

  @override
  void initState() {
    super.initState();
    print("▶️ [ResultScreen] initState at ${DateTime.now().toIso8601String()}");

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
        GestureBinding.instance.pointerRouter.addGlobalRoute(_handleTutorialTap);
      });
    }

    _loadSettings();
    if (widget.title != null) {
      _storeNameController.text = widget.title!;
    }
    _isLiked = true;

    _checkDarkMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          "✅ [ResultScreen] first frame rendered at ${DateTime.now().toIso8601String()}");
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
            final a = await _fetchNearbyMenuTags(prefixLen: 6, days: 30, maxDocs: 200);
            if (a.isNotEmpty) return a;
            return _fetchNearbyMenuTags(prefixLen: 5, days: 30, maxDocs: 200);
          }();
        });


        // ✅ searched menu 저장(비동기)
        _saveSearchedMenuFireAndForget();

        _fetchRAGData();
        _fetchFoodDetail();
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
            final a =
            await _fetchNearbyMenuTags(prefixLen: 6, days: 30, maxDocs: 200);
            if (a.isNotEmpty) return a;
            return _fetchNearbyMenuTags(prefixLen: 5, days: 30, maxDocs: 200);
          }();
        }

        _fetchExistingReview();
        if (_ragDetail == null) {
          _fetchRAGData();
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
      setState(() {
        _isCloudSaveEnabled = prefs.getBool('cloudSaveEnabled') ?? true;
      });
    } catch (e) {
      print('Failed to load settings: $e');
      setState(() {
        _isCloudSaveEnabled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load settings, cloud save enabled by default'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloudSaveEnabled', _isCloudSaveEnabled);
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
      print('✅ 이미지 업로드 완료: $_imageUrl');
    } catch (e) {
      print('❌ 이미지 업로드 실패: $e');
      _imageUrl = null;
    }
  }

  Future<void> _saveDataToFirestore() async {
    if (!_isCloudSaveEnabled) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_imageUrl == null) {
          print('⚠️ Firestore 저장 중단: _imageUrl is null');
          return;
        }

        final docId = '${_geohash ?? 'nogeo'}_${widget.captureTime.toIso8601String()}';
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
          'review': _reviewController.text.trim(),
        });

        print('Data saved to Firestore with ID: $docId');
      } else {
        print('No user logged in');
      }
    } catch (e) {
      print('Failed to save data: $e');
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
    final langCode =
        prefs.getString('selectedLangCode') ?? Platform.localeName.split('_').first;

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

    print('리뷰 저장 완료');
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
      print('Data saved to SharedPreferences');
    } catch (e) {
      print('Failed to save data to SharedPreferences: $e');
    }
  }

  Future<void> _checkAndRequestReview() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int usageCount = prefs.getInt('usageCount') ?? 0;
    usageCount++;
    await prefs.setInt('usageCount', usageCount);

    bool hasReviewed = prefs.getBool('hasReviewed') ?? false;

    if (!hasReviewed) {
      if (usageCount == 5) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          await prefs.setBool('hasReviewed', true);
        }
      } else if (usageCount > 5 && (usageCount - 5) % 30 == 0) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          inAppReview.requestReview();
        }
      }
    }
  }

  Future<void> _saveScanResult() async {
    if (widget.isTutorial) {
      print('⛔ 튜토리얼 모드이므로 저장 로직 중단');
      return;
    }
    setState(() {
      _isLoading = true;
      _isLoadingError = false;
    });

    _timer = Timer(Duration(seconds: 30), _onLoadingTimeout);

    await _uploadImage();
    if (_imageUrl == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed, please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _saveDataToFirestore();
    await _saveDataToSharedPreferences();
    await _submitReview();

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

      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
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
        content:
        Text(AppLocalizations.of(context)?.textCopied ?? 'Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLiked
              ? AppLocalizations.of(context)?.liked ?? 'Liked'
              : AppLocalizations.of(context)?.unliked ?? 'Unliked',
        ),
        duration: Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _shareToPlatform(BuildContext context, String platform) async {
    await LogService().logShareClick(dest: 'system', context: 'result');
    String message =
        "${AppLocalizations.of(context)?.checkOutContent ?? 'Check out this content!'}\n\n${widget.responses.join('\n\n')}";
    String filePath = widget.image.path;
    String title = AppLocalizations.of(context)?.shareVia ?? 'Share via';

    try {
      switch (platform) {
        case 'shareToSystem':
          final RenderBox box = context.findRenderObject() as RenderBox;
          final List<XFile> files = [XFile(filePath)];
          await Share.shareXFiles(
            files,
            text: message,
            subject: title,
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          );
          break;
        default:
          print('Unsupported platform');
      }
    } catch (e) {
      print("Error during sharing: $e");
    }
  }

  void _showShareOptions(BuildContext context) {
    _shareToPlatform(context, 'shareToSystem');
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
    const int BLOCK_FOLLOW_LINES = 20;
    const int BLOCK_MAX_CHARS = 2000;

    final results = <double>[];
    final seen = <String>{};

    final lines = text.split('\n');
    final nameReg = RegExp(r'\*\*(.+?)\*\*');

    final amountReg = RegExp(
      r'(?<!\d)'
      r'(?:'
      r'(?:KRW|JPY|USD|EUR|CNY|HKD|TWD|NTD|SGD|AUD|CAD|GBP|CHF|₩|\$|€|¥|元|원|엔|달러|유로|엔화)\s*'
      r'(?:(?:\d{1,3}(?:[.,\s]\d{3})*|\d+)(?:[.,]\d+)?))'
      r'|'
      r'(?:(?:\d{1,3}(?:[.,\s]\d{3})*|\d+)(?:[.,]\d+)?\s*'
      r'(?:KRW|JPY|USD|EUR|CNY|HKD|TWD|NTD|SGD|AUD|CAD|GBP|CHF|₩|\$|€|¥|元|원|엔|달러|유로|엔화)?)'
      r')'
      r'(?!\d)',
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
      RegExp(r'^\s*(?:\d+\.\s*|\d+\)\s*|\(\d+\)\s*|\[\d+\]\s*|[-–—•*·]\s*)'),
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
        p = p.substring(0, m.start).replaceAll(RegExp(r'[.,]'), '') +
            '.' +
            m.group(2)!;
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
      for (int j = i; j < lines.length && taken <= BLOCK_FOLLOW_LINES; j++) {
        var cur = stripPrefix(lines[j]).trimRight();
        if (j > i && cur.isEmpty) break;
        if (j > i && nameReg.hasMatch(cur)) break;
        buffer.writeln(cur);
        taken++;
      }

      var block = buffer.toString().trim();
      if (block.length > BLOCK_MAX_CHARS) {
        block = block.substring(0, BLOCK_MAX_CHARS);
      }

      final afterName = block.substring(nameMatch.end).trimLeft();
      final searchAreas = <String>[afterName, block];

      for (final area in searchAreas) {
        for (final m in amountReg.allMatches(area)) {
          final captured = m.group(0)!;

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
      List<String> foodNames = _extractAllFoodNames(widget.responses.join('\n'));
      if (foodNames.isEmpty) {
        print('No food names found in response.');
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
            _foodDetail = doc['detail'] ?? null;
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
      print('Failed to fetch food detail: $e');
      setState(() {
        _foodDetail = null;
      });
    }
  }

  Future<void> _fetchRAGData() async {
    if (_geohash == null) return;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('rag_data')
          .where('geohashes', arrayContains: _geohash)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = querySnapshot.docs.first;
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

        if (data != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? langCode = prefs.getString('languageCode');
          langCode ??= Localizations.localeOf(context).toLanguageTag();
          langCode = langCode.replaceAll('-', '_');

          String detailField = 'detail_$langCode';

          setState(() {
            _ragDetail =
            data.containsKey(detailField) ? data[detailField] : data['detail_en'];
          });
        } else {
          setState(() {
            _ragDetail = null;
          });
          await _trySendImpressions();
        }
      } else {
        setState(() {
          _ragDetail = null;
        });
      }
    } catch (e) {
      print('Failed to fetch RAG data: $e');
      setState(() {
        _ragDetail = null;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    print("▶️ [ResultScreen] build() at ${DateTime.now().toIso8601String()}");
    final localizations = AppLocalizations.of(context);
    final Color backgroundColor = _isDarkMode ? Colors.black : Color(0xFFEFEFF4);
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final BoxDecoration boxDecoration = BoxDecoration(
      color: _isDarkMode ? Colors.grey[850] : Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          offset: Offset(0, 2),
          blurRadius: 6,
        ),
      ],
    );

    return WillPopScope(
      onWillPop: () async {
        if (!_isLoading) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
          return false;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          leading: widget.isTutorial
              ? null
              : IconButton(
            icon: Icon(CupertinoIcons.back, color: textColor, size: 30),
            onPressed: () {
              if (!_isLoading) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => HomeScreen()),
                );
              }
            },
          ),
          title: widget.isTutorial ? TutorialIndicator() : null,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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

                  // ─── AI 응답 카드 ───
                  Container(
                    decoration: boxDecoration,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              localizations!.aiAnswer,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            if ((_amountFromResponses ?? 0) > 0)
                              FxQuickFxButton(
                                initialAmount: _amountFromResponses ?? 0,
                                detectedCountryCode: _isoCountryCode,
                                currencySymbolHint: _currencySymbolHint,
                                initialTarget: TargetCurrency.usd,
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                parsedAmounts: _amountCandidates,
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.responses.join('\n\n'),
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 12,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Builder(builder: (_) {
                              final nutritionData = parseNutritionalData(
                                  widget.responses.join('\n\n'));
                              if (nutritionData.containsKey('calories')) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: NutritionChart(
                                      calories: nutritionData['calories'],
                                      protein: nutritionData['protein'] ?? 0,
                                      carbs: nutritionData['carbs'] ?? 0,
                                      fat: nutritionData['fat'] ?? 0,
                                    ),
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            }),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy,
                                  color: Colors.blue, size: 20),
                              onPressed: () =>
                                  _copyTextToClipboard(widget.responses.join('\n\n')),
                            ),
                            IconButton(
                              icon: Icon(CupertinoIcons.square_arrow_up,
                                  color: Colors.blue, size: 24),
                              onPressed: () => Platform.isIOS
                                  ? _shareToPlatform(context, 'shareToSystem')
                                  : _showShareOptions(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ✅ 여기! 결과 카드 바깥 바로 아래에 “근처 타인 메뉴 태그”
                  _buildNearbyMenuTags(),


                  // ✅ RAG Answer (허용 사용자만)
                  if (_isAllowedUser && (_ragDetail?.isNotEmpty ?? false)) ...[
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

                  // ✅ 리뷰 입력
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

                  SafeArea(
                    bottom: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          final _comment =
                          _reviewController.text.trim();
                          LogService().logSaveClick(
                            hasComment: _comment.isNotEmpty,
                            contentLength: _comment.length,
                            context: 'result',
                          );

                          if (!_isMergeDone) {
                            if (!_pendingSave) {
                              setState(() => _pendingSave = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context)!
                                      .mergeInProgress),
                                ),
                              );
                            }
                            return;
                          }
                          _saveScanResult();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey
                              : Colors.white,
                          backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
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
                      color: Colors.black.withOpacity(0.5),
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
                            color: _isDarkMode
                                ? Colors.redAccent
                                : Colors.red,
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
          ],
        ),
      ),
    );
  }
}
