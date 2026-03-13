import 'dart:async';
import 'dart:convert'; // JSON 인코딩 및 디코딩에 사용
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/screens/Camera_Screen.dart';
import '/screens/History_Screen.dart';
import '/screens/Setting_Screen.dart';
import 'package:getwidget/getwidget.dart';
import 'detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Shared Preferences 추가
import 'package:flutter_html/flutter_html.dart'; // flutter_html 패키지 import
import 'package:cached_network_image/cached_network_image.dart'; // CachedNetworkImage 추가
import 'location_service.dart';  // LocationService 파일 가져오기
import '/screens/custom_cache_manager.dart'; // CustomCacheManager import
import '/screens/url_launcher.dart'; // ← 만들어둔 위젯 import 추가
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '/widgets/comment_section.dart';
import '/screens/geohash_service.dart';
import 'package:provider/provider.dart';
import '/ad_remove_provider.dart'; // 경로에 따라 수정 필요
import '/widgets/premium_ad_overlay.dart';
import '/widgets/test_purchase_widget.dart';
import '/screens/log_service.dart';
import '/widgets/how_to_use_mscanner_card.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _emergencyMessage;
  String? _currentGeohash;
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  Map<String, dynamic>? _latestLikedData;
  DocumentSnapshot? _latestLikedDoc;
  int _userPoints = 0;
  bool _shouldHighlightCameraTab = false; // 카메라 탭 하이라이트 상태

  bool _isFirstLogin = false; // 처음 로그인 여부 확인
  Timer? _blinkTimer;
  bool _blinkState = false;
  DateTime? _lastMultiScanTap;  // ← ① 추가

  bool _showPremiumOverlay = false; // 🔹 프리미엄 팝업 표시 여부
  StreamSubscription<User?>? _authSub;


  // ─────────────────────────────────────────────────────────
  // * 메인 카드 데이터, 도시별 추천 데이터를 최초 로딩 시 한 번만 불러오기 위한 Future
  // ─────────────────────────────────────────────────────────
  Future<List<Map<String, String>>>? _mainCardDataFuture;
  Future<List<Map<String, String>>>? _cityDataFuture;

  // 캐싱된 데이터(메인 카드, 도시별 추천)
  List<Map<String, String>>? _cachedMainCardData;
  List<Map<String, String>>? _cachedCityData;

  Future<String?>? _countryFuture; // 비동기로 국가 값을 가져오기 위한 Future 변수
  Key _homeContentKey = UniqueKey(); // HomeContent 위젯의 키를 추가

  @override
  void initState() {
    super.initState();
    _loadGeohash();
    _initializeHome();
    _checkPremiumOverlay(); // 🔹 프리미엄 팝업 체크 추가
  }
  @override
    void didChangeDependencies() {
        super.didChangeDependencies();
        // 별도 리스너 불필요 – Provider를 build 시점에 바로 읽습니다.
      }

  Future<void> _loadGeohash() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final geohash = await GeohashService().getCurrentGeohash5();


      if (!mounted) return;
      setState(() {
        _currentGeohash = geohash;
      });

      print('홈 화면 geohash: $geohash');
    } catch (e) {
      print('Geohash 불러오기 실패: $e');
    }
  }



  Future<void> _checkPremiumOverlay() async {
    final adp = context.read<AdRemoveProvider>();
    if (adp.isSubscribed || adp.isAdRemoved) {
      debugPrint('[PremiumOverlay] premium/adfree 사용자 → 팝업 안 띄움');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('premium_overlay_closed_time');
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;

    if (last == null || now - last > dayMs) {
      debugPrint('[PremiumOverlay] 조건 충족 → 3초 뒤 표시');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showPremiumOverlay = true);
      });
    } else {
      debugPrint('[PremiumOverlay] 24시간 내에 닫음 → 표시 안 함');
    }
  }

  Future<void> _closePremiumOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('premium_overlay_closed_time', DateTime.now().millisecondsSinceEpoch);
    setState(() => _showPremiumOverlay = false);
  }






  Future<bool> _shouldShowEmergencyPopup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final lastClosedTime = prefs.getInt('emergency_popup_closed_time');
    if (lastClosedTime == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    return now - lastClosedTime > 86400000; // 24시간
  }

  Future<void> _checkEmergencyNotice() async {
    try {
      final todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
      final doc = await FirebaseFirestore.instance
          .collection('emergency_notice')
          .doc(todayDocId)
          .get();

      if (!mounted) return;                         // ✅ 추가

      if (doc.exists && doc.data()?['enabled'] == true) {
        final data = doc.data()!;
        final String languageCode = PlatformDispatcher.instance.locale.languageCode;
        String? localizedMessage = data['message_$languageCode'] ?? data['message_en'];

        final shouldShow = await _shouldShowEmergencyPopup();

        if (!mounted) return;                       // ✅ 추가

        if (shouldShow && mounted) {
          _showEmergencyPopup(localizedMessage ?? 'Emergency Notice');
        }
      }
    } catch (e) {
      print('긴급 공지 확인 실패: $e');
    }
  }



  Future<void> _initializeHome() async {
    await Future.wait([
      _fetchLatestLikedData(),
    ]);

    _countryFuture = LocationService().getCountryCodeFromGPS();
    await _loadInitialData();
    await _checkFirstLogin();

    // ✅ 구독 보관 + mounted 가드 + context 접근 전 안전화
    _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) return;
      if (!mounted) return;                 // ✅ 필수

      // ✅ context를 꼭 써야 한다면, 지역 변수로 잡아두고 최소한만 사용
      final adp = context.read<AdRemoveProvider>();
      adp.refreshStatus();
      _onNewUserLogin();
    });

    // ✅ 다이얼로그는 프레임 이후로 미루기
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _checkEmergencyNotice();
    });
  }

  // 병렬 호출로 메인, 도시 데이터 불러오기
  Future<void> _loadInitialData() async {
    // Future.wait를 사용해 병렬로 호출합니다.
    final results = await Future.wait([
      _getMainCardData(),

    ]);
    if (!mounted) return;    // ← 이 줄 추가
    setState(() {
      _cachedMainCardData = results[0];

      // Future 변수에도 캐싱된 데이터를 할당하여 HomeContent에 전달되게 함
      _mainCardDataFuture = Future.value(_cachedMainCardData);

    });
  }
  void _showEmergencyPopup(String message) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            ' ${localizations.emergencyTitle ?? '긴급 공지'}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
            ),
            textAlign: TextAlign.center,
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemRed,
                  size: 30,
                ),
                SizedBox(height: 10),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        localizations.dismissToday,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                      onPressed: () async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(
                          'emergency_popup_closed_time',
                          DateTime.now().millisecondsSinceEpoch,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        localizations.close,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  void _onNewUserLogin() {
    _clearCachedData();
    setState(() {
      _homeContentKey = UniqueKey();
    });
    Future<void> _refreshLikedOnceOnly() async {
      if (_latestLikedData == null) {
        await _fetchLatestLikedData();
      }
    }

    // ⭐ 최초 로그인 시에만 깜빡이기 실행
    if (_isFirstLogin) {
      Future.delayed(Duration(seconds: 3), ()
      {
        if (mounted) _highlightCameraTab();
      });


    }
  }


  Future<void> _clearCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mainCardData');

    await prefs.remove('mainCardData_cache_timestamp');

    _cachedMainCardData = null;


    // 메인/도시 데이터 Future도 다시 불러오기
    _loadInitialData();
  }

  // 최초 로그인 여부 확인
  Future<void> _checkFirstLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasLoggedInBefore = prefs.getBool('hasLoggedInBefore') ?? false;

    if (!hasLoggedInBefore) {
      setState(() {
        _isFirstLogin = true;
      });
      // ⏱ 15초 후에 하이라이트 시작
      Future.delayed(Duration(seconds: 5), () async {
        if (mounted) {
          _highlightCameraTab();

          // 이 타이밍에 저장해도 괜찮음 (딜레이 이후 최초 하이라이트 기록)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasLoggedInBefore', true);
        }
      });
    }
  }


  Future<void> _checkDarkMode() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    setState(() {
      _isDarkMode = savedThemeMode == AdaptiveThemeMode.dark;
    });
  }

  void _onItemTapped(int index) async {
    await LogService().logCameraOpen(reason: 'home_tab'); // ① 카메라 버튼 누름

    // 1: 카메라 탭
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => CameraScreen(
            onCancel: () {
              // 카메라 화면에서 뒤로가거나 onCancel() 호출되면
              Navigator.of(ctx).pop();      // 화면 pop
              setState(() => _selectedIndex = 0); // 홈 탭으로

            },
          ),
        ),
      );
      return;
    }
    // 2: 멀티스캔 탭
    if (index == 2) {
      // 10초 이내 재클릭 방지
         final now = DateTime.now();
         if (_lastMultiScanTap != null && now.difference(_lastMultiScanTap!) < Duration(seconds: 1)) {
           return;
         }
         _lastMultiScanTap = now;
         if (!context.read<AdRemoveProvider>().isSubscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.premiumFunctionMessage)),
        );
        return;
      }
         await LogService().logCameraOpen(reason: 'multi_scan_tab'); // ① 변형(멀티스캔 진입 의도)

         Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => CameraScreen(
            isPremium: true,
            onCancel: () {
              Navigator.of(ctx).pop();
              setState(() => _selectedIndex = 0);
            },
          ),
        ),
      );
      return;
    }
    // 그 외 탭
    setState(() => _selectedIndex = index);
  }



  /// ─────────────────────────────────────────────────────────
  /// 1) 계속 매 빌드마다 가져와야 하는 'Last Liked Data'
  /// ─────────────────────────────────────────────────────────
  Future<void> _fetchLatestLikedData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('user_data')
            .doc(user.uid)
            .collection('data')
            .where('liked', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            _latestLikedDoc = querySnapshot.docs.first;
            _latestLikedData =
            _latestLikedDoc?.data() as Map<String, dynamic>?;

            // Geohash 필드가 없는 경우 추가
            if (_latestLikedData != null &&
                !_latestLikedData!.containsKey('geohash')) {
              _latestLikedData!['geohash'] = _latestLikedDoc!.get('geohash');
            }
          });
          print('Firestore 데이터 읽기 성공: $_latestLikedData');
        } else {
          setState(() {
            _latestLikedDoc = null;
            _latestLikedData = null;
          });
          print('Firestore 데이터 없음');
        }
      } catch (e) {
        print('Firestore 데이터 읽기 실패: $e');
      }
    } else {
      print('사용자가 로그인되어 있지 않습니다.');
    }
  }

  Future<List<Map<String, String>>> _getMainCardData() async {
    if (_cachedMainCardData != null && _cachedMainCardData!.isNotEmpty) {
      return _cachedMainCardData!;
    }

    _cachedMainCardData = await _loadDataLocally('mainCardData');
    if (_cachedMainCardData != null && _cachedMainCardData!.isNotEmpty) {
      return _cachedMainCardData!;
    }

    try {
      String? country;
      try {
        country = await LocationService().getCountryCodeFromGPS()
            .timeout(Duration(seconds: 3), onTimeout: () => 'KR');
      } catch (_) {
        country = 'KR';
      }

      print('현재 위치의 국가: $country');
      CollectionReference collectionRef = FirebaseFirestore.instance.collection('verified_data');

      List<String> docNames = (country == 'JP')
          ? ['osaka1', 'osaka2', 'osaka3', 'osaka4', 'osaka5']
          : ['korea1', 'korea2', 'korea3', 'korea4', 'korea5'];

      List<Map<String, String>> dataList = [];
      String lang = PlatformDispatcher.instance.locale.languageCode;

      for (String docName in docNames) {
        DocumentSnapshot doc = await collectionRef.doc(docName).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            dataList.add({
              'image_url': data['image_url'] ?? '',
              'image_url_2': data['image_url_2'] ?? '',
              'image_url_3': data['image_url_3'] ?? '',
              'image_url_4': data['image_url_4'] ?? '',
              'image_url_5': data['image_url_5'] ?? '',
              'title': data['title_$lang'] ?? data['title_en'] ?? 'No Title',
              'subtitle': data['subtitle_$lang'] ?? data['subtitle_en'] ?? 'No Subtitle',
              'detail': data['detail_$lang'] ?? data['detail_en'] ?? 'No Detail',
            });
          }
        }
      }

      _cachedMainCardData = dataList;
      await _saveDataLocally('mainCardData', dataList);
      return dataList;
    } catch (e) {
      print('Error fetching main card data: $e');
      return [];
    }
  }


  /// ─────────────────────────────────────────────────────────
  /// 사용자 포인트 읽기 (실시간 갱신 용도)
  /// ─────────────────────────────────────────────────────────
  Future<void> _fetchUserPoints() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userPointsDoc = await FirebaseFirestore.instance
          .collection('user_points')
          .doc(user.uid)
          .get();

      if (userPointsDoc.exists) {
        setState(() {
          _userPoints = userPointsDoc.get('points') ?? 0;
        });
      } else {
        setState(() {
          _userPoints = 0;
        });
      }
    }
  }
  // 카메라 탭 하이라이트 시작
  void _highlightCameraTab() {
    setState(() {
      _shouldHighlightCameraTab = true;
      _blinkState = true;
    });

    _blinkTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      setState(() {
        _blinkState = !_blinkState;
      });
    });

    Timer(Duration(seconds: 8), () {
      _blinkTimer?.cancel();
      setState(() {
        _shouldHighlightCameraTab = false;
        _blinkState = false;
      });
    });
  }


  /// ─────────────────────────────────────────────────────────
  /// 로컬 캐싱 (SharedPreferences) 메서드 (만료시간 1일 적용)
  /// ─────────────────────────────────────────────────────────
  Future<void> _saveDataLocally(
      String key, List<Map<String, String>> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonData = jsonEncode(data);
    await prefs.setString(key, jsonData);
    // 캐시 타임스탬프 저장 (1일 = 86,400,000 밀리초)
    await prefs.setInt('${key}_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, String>>?> _loadDataLocally(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonData = prefs.getString(key);
    int? cacheTimestamp = prefs.getInt('${key}_cache_timestamp');
    if (jsonData != null && cacheTimestamp != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      // 1일 = 86,400,000 밀리초
      if (cacheAge < 86400000) {
        List<dynamic> decodedData = jsonDecode(jsonData);
        return List<Map<String, String>>.from(
            decodedData.map((e) => Map<String, String>.from(e)));
      }
    }
    return null;
  }



  /// ─────────────────────────────────────────────────────────
  /// 빌드
  /// ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isSubscribed = context.watch<AdRemoveProvider>().isSubscribed;
    final isAdRemoved  = context.watch<AdRemoveProvider>().isAdRemoved;

    // 현재 테마 밝기
    final brightness = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark
        ? Brightness.dark
        : Brightness.light;


    // 배경색 및 텍스트 색상
    final Color backgroundColor =
    brightness == Brightness.dark ? CupertinoColors.black : Color(0xFFEFEFF4);
    final Color bottomNavBarColor =
    brightness == Brightness.dark ? Colors.black : Color(0xFFEFEFF4);

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false; // 홈 탭으로 돌아가기만 하고 시스템 뒤로는 막음
        }
        return true;  // 홈 탭에서 한 번 더 누르면 앱 종료
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: backgroundColor,
            resizeToAvoidBottomInset: true,
            body: _selectedIndex == 0
                ? HomeContent(
              key: _homeContentKey,
              latestLikedData: _latestLikedData,
              latestLikedDoc: _latestLikedDoc,
              onRefresh: _fetchLatestLikedData,
              mainCardDataFuture: _mainCardDataFuture,
              cityDataFuture: _cityDataFuture,
              userGeohash: _currentGeohash ?? 'zzzzzzzz', // ✅ 추가된 부분
               // ← ⑤ HomeContent 에 상태 전달
            )
                : _getWidgetOptions().elementAt(_selectedIndex),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: bottomNavBarColor,
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: localizations?.home ?? 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: AnimatedOpacity(
                      opacity: _blinkState ? 1.0 : 0.8,
                      duration: Duration(milliseconds: 400),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: _shouldHighlightCameraTab
                              ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.7),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ]
                              : [],
                        ),
                        child: Icon(Icons.camera, size: 24),
                      ),
                    ),
                    label: localizations?.camera ?? 'Camera',
                  ),
              BottomNavigationBarItem(
                                      icon: Icon(
                                        Icons.photo_library,
                                        color: isSubscribed ? null : Colors.grey,
                                      ),
                                  label: localizations?.multiScan ?? 'Multi scan',
                                ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: localizations?.history ?? 'History',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: localizations?.settings ?? 'Settings',
                  ),
                ],
                currentIndex: _selectedIndex,
                selectedItemColor: Colors.blue,
                unselectedItemColor: Colors.grey,
                onTap: _onItemTapped,
                showUnselectedLabels: true,
                selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
              ),
            ),
          ),
          if (_emergencyMessage != null)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _emergencyMessage!,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 🔻 문구 보여주기 (깜빡임 애니메이션 포함)
          if (_shouldHighlightCameraTab)
            Positioned(
              bottom: 70,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _blinkState ? 1.0 : 0.3,
                  duration: Duration(milliseconds: 600),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        localizations!.cameraHint, // or 고정 문구
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'SFProText',
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ),

              ),
            ),
          // ✅ 프리미엄 광고 팝업
          if (_showPremiumOverlay && !(isSubscribed || isAdRemoved))
            Positioned.fill(
              child: Container(
                color: Colors.black54,
    child: SafeArea( // 👈 추가
                child: Center(
                  child: PremiumAdOverlay(
                    // ⬇︎ 단말 폭 기준으로 적당히 리사이즈해서 디코딩
                    image: ResizeImage(
                      const AssetImage('assets/images/admscanner.png'),
                      width: (MediaQuery.of(context).size.width * 2).toInt(), // 선명도 확보용
                    ),
                    locale: Localizations.localeOf(context),
                    adFreePrice: simpleLocalizedPrice(Localizations.localeOf(context)),
                    premiumMonthlyPrice: simpleLocalizedPrice(Localizations.localeOf(context)),
                    // ⬇︎ 화면 꽉 채우되, 중요한 왼쪽 영역이 보이게 정렬
                    // ⬇️ 이미지 잘림 최소화
                    imageFit: BoxFit.cover,       // ✅ 세로 기준으로 꽉 차게
                    imageAlignment: Alignment.topLeft, // ✅ 위쪽 기준
                    panelOffsetY: -60,                // ✅ 텍스트 위로 올리기

                    onPrimaryTap: () async {
                      await LogService().logPremiumCtaClick(placement: 'overlay', plan: 'subscription'); // ⑰ 프리미엄 CTA
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) {
                          return DraggableScrollableSheet(
                            initialChildSize: 0.7,
                            minChildSize: 0.5,
                            maxChildSize: 0.95,
                            builder: (ctx, scrollController) {
                              return Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SingleChildScrollView(
                                    controller: scrollController,
                                    child: TestPurchaseWidget(
                                      onPurchased: () {
                                        Navigator.of(context).maybePop(); // 바텀시트 닫기
                                        _closePremiumOverlay();          // 프리미엄 오버레이도 닫기
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    onClose: _closePremiumOverlay,
                  )
                ),
              ),
            ),


            )],
      ),
    );
  }





  List<Widget> _getWidgetOptions() {
    final isSubscribed = context.watch<AdRemoveProvider>().isSubscribed;
    return <Widget>[
      // 홈
      HomeContent(
        key: _homeContentKey,
        latestLikedData: _latestLikedData,
        latestLikedDoc: _latestLikedDoc,
        onRefresh: _fetchLatestLikedData,
        mainCardDataFuture: _mainCardDataFuture,
        cityDataFuture: _cityDataFuture, userGeohash: '',
            // ← ⑤ HomeContent 에 상태 전달
      ),

      // 카메라
      CameraScreen(
        onCancel: () {
          // 카메라에서 취소되었을 때 홈 화면으로 이동
          _onItemTapped(0);
        },
      ),
      CameraScreen(
        onCancel: () => _onItemTapped(0),
          isPremium: isSubscribed,
      ),

      // 히스토리
      HistoryScreen(),

      // 설정
      SettingScreen(),
    ];
  }
  @override
  void dispose() {
    _authSub?.cancel();          // ✅ 스트림 구독 해제

    _blinkTimer?.cancel();
    super.dispose();
  }
}

// HomeContent 위젯
class HomeContent extends StatefulWidget {
  final Map<String, dynamic>? latestLikedData;
  final DocumentSnapshot? latestLikedDoc;
  final VoidCallback onRefresh;

  // ─────────────────────────────────────────────────────────
  // HomeScreen에서 받아온 Future
  // ─────────────────────────────────────────────────────────
  final Future<List<Map<String, String>>>? mainCardDataFuture;
  final Future<List<Map<String, String>>>? cityDataFuture;
  final String userGeohash;


  const HomeContent({
    Key? key,
    this.latestLikedData,
    this.latestLikedDoc,
    required this.onRefresh,
    required this.mainCardDataFuture,
    required this.cityDataFuture,
    required this.userGeohash, // ✅ required 처리
       // ← ④ 생성자에 추가
  }) : super(key: key);

  @override
  _HomeContentState createState() => _HomeContentState();
}
class _MenuImageSuggestion {
  final String docId;
  final String title;
  final String subtitle;
  final String shortDesc;
  final String? imageUrl;

  const _MenuImageSuggestion({
    required this.docId,
    required this.title,
    required this.subtitle,
    required this.shortDesc,
    this.imageUrl,
  });
}

class _HomeContentState extends State<HomeContent> {

  BannerAd? _adaptiveBanner;
  bool _isBannerLoaded = false;
  bool _didLoadBanner = false;

  TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _topSearchController = TextEditingController();
  final FocusNode _topSearchFocusNode = FocusNode();
  Timer? _topSearchDebounce;

  List<_MenuImageSuggestion> _topSearchSuggestions = [];
  bool _showTopSearchSuggestions = false;
  bool _isSearchingTopSuggestions = false;

  bool _isSaving = false; // 추가

  int _rating = 0;
  double _carouselSpacing = 10.0; // Spacing between "도시별 추천"과 GFCard

  bool _sentMainCardsImpression = false;
  bool _sentManualImpression = false; // (아래 4번에서 사용)
  String? _extractPrimaryMenuFromResponses(List<String> responses) {
    if (responses.isEmpty) return null;

    // 1) JSON이면 recommended[0].name 우선
    for (final r in responses) {
      final s = r.trim();
      if (!s.startsWith('{')) continue;
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final rec = decoded['recommended'];
          if (rec is List && rec.isNotEmpty && rec.first is Map) {
            final m = Map<String, dynamic>.from(rec.first as Map);
            final name = (m['name'] ?? '').toString().trim();
            final nameOriginal = (m['nameOriginal'] ?? '').toString().trim();
            final pick = nameOriginal.isNotEmpty ? nameOriginal : name;
            if (pick.length >= 2) return pick;
          }
        }
      } catch (_) {}
    }

    // 2) 텍스트면 "1." / "1)" 같은 첫 항목 파싱
    final joined = responses.join('\n').replaceAll('\r', '');
    final lines = joined.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final reFirstItemPrefix = RegExp(r'^\s*1\s*[\.\)\]\:\-]\.?\s*');
      final m = reFirstItemPrefix.firstMatch(line);
      if (m != null) {
        var first = line.substring(m.end).trim();

        // 같은 줄에 2. 3. 붙어있으면 컷
        final nextItem = RegExp(r'\s*[2-9]\s*[\.\)\]\:\-]\.?\s*');
        final cut = nextItem.firstMatch(first);
        if (cut != null && cut.start > 0) {
          first = first.substring(0, cut.start).trim();
        }

        // 꼬리 설명 컷
        for (final t in [' - ', ' – ', ' — ', ': ', '(', '[', '|']) {
          final idx = first.indexOf(t);
          if (idx > 0) first = first.substring(0, idx).trim();
        }

        // 끝 가격 제거
        first = first.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();

        if (first.length >= 2) return first;
      }
    }

    return null;
  }


  @override
  void initState() {
    super.initState();

    _topSearchFocusNode.addListener(() {
      if (!_topSearchFocusNode.hasFocus && mounted) {
        setState(() {
          _showTopSearchSuggestions = false;
        });
      }
    });
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadBanner) {
          final adp = context.read<AdRemoveProvider>();
          if (!(adp.isSubscribed || adp.isAdRemoved)) {
            _loadAdaptiveBanner(); // 권리 없을 때만 로드
          }
      _didLoadBanner = true;
    }
  }


  void _loadAdaptiveBanner() async {
    final adp = context.read<AdRemoveProvider>();
    if (adp.isSubscribed || adp.isAdRemoved) return; // 이중 가드

    final AnchoredAdaptiveBannerAdSize? size =
    await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) return;

    _adaptiveBanner = BannerAd(
      size: size,
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-2942885230901008/6352101999' // ✅ 실제 Android 배너 ID
          : 'ca-app-pub-2942885230901008/3614258015', // ✅ 실제 iOS 배너 ID
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, error) {
          print('배너 로드 실패: $error');
          ad.dispose();
        },
      ),
      request: AdRequest(),
    );


    await _adaptiveBanner!.load();
  }




  @override
  void dispose() {
    _restaurantNameController.dispose();
    _topSearchController.dispose();
    _topSearchFocusNode.dispose();
    _topSearchDebounce?.cancel();
    _adaptiveBanner?.dispose();
    super.dispose();
  }


  String _normalizeSearchKeyword(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
  String? _extractMenuImageUrl(Map<String, dynamic> data) {
    for (final key in [
      'thumb_url',
      'image_url',
      'imageUrl',
      'generated_image_url',
      'downloadUrl',
    ]) {
      final v = (data[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }


  void _onTopSearchChanged(String value) {
    _topSearchDebounce?.cancel();

    final q = _normalizeSearchKeyword(value);
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _topSearchSuggestions = [];
        _showTopSearchSuggestions = false;
        _isSearchingTopSuggestions = false;
      });
      return;
    }

    _topSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadTopSearchSuggestions(q);
    });
  }

  Future<void> _loadTopSearchSuggestions(String keyword) async {
    final normalized = _normalizeSearchKeyword(keyword);
    if (normalized.isEmpty) return;

    if (mounted) {
      setState(() {
        _isSearchingTopSuggestions = true;
      });
    }


    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_images')
          .where('menu_search_keywords', arrayContains: normalized)
          .limit(10)
          .get();

      final items = snap.docs.map((doc) {
        final data = doc.data();

        final display = (data['menu_display'] ?? '').toString().trim();
        final original = (data['menu_original'] ?? '').toString().trim();
        final translated = (data['menu_translated'] ?? '').toString().trim();
        final shortDesc = (data['shortDesc'] ?? '').toString().trim();
        final imageUrl = _extractMenuImageUrl(data);

        final title = display.isNotEmpty
            ? display
            : (original.isNotEmpty ? original : translated);

        final subtitle = [original, translated]
            .where((e) => e.isNotEmpty && e != title)
            .toSet()
            .join(' · ');

        return _MenuImageSuggestion(
          docId: doc.id,
          title: title,
          subtitle: subtitle,
          shortDesc: shortDesc,
          imageUrl: imageUrl,
        );
      }).where((e) => e.title.isNotEmpty).toList();

      if (!mounted) return;
      setState(() {
        _topSearchSuggestions = items;
        _showTopSearchSuggestions = items.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _topSearchSuggestions = [];
        _showTopSearchSuggestions = false;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSearchingTopSuggestions = false;
      });
    }
  }

  Future<void> _performTopSearch(String keyword) async {
    final q = _normalizeSearchKeyword(keyword);
    if (q.isEmpty) return;

    await _loadTopSearchSuggestions(q);
    if (!mounted) return;

    if (_topSearchSuggestions.isEmpty) {
      setState(() {
        _showTopSearchSuggestions = false;
      });
      return;
    }


    if (_topSearchSuggestions.length == 1) {
      _openMenuPreviewSheet(_topSearchSuggestions.first);
      return;
    }

    setState(() {
      _showTopSearchSuggestions = true;
    });
  }

  void _openMenuPreviewSheet(_MenuImageSuggestion item) {
    _topSearchController.text = item.title;
    _topSearchFocusNode.unfocus();

    setState(() {
      _showTopSearchSuggestions = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(ctx).size.height * 0.30,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: item.imageUrl != null
                          ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                        const Center(child: CupertinoActivityIndicator()),
                        errorWidget: (_, __, ___) => Container(
                          color: isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.restaurant, size: 44),
                          ),
                        ),
                      )
                          : Container(
                        color: isDarkMode
                            ? Colors.white10
                            : Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.restaurant, size: 44),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SFProDisplay',
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    item.shortDesc.isNotEmpty
                        ? item.shortDesc
                        : 'No description available.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: isDarkMode ? Colors.white : Colors.black87,
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










  Widget _buildSearchBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: Radius.circular(
                (_showTopSearchSuggestions && _topSearchSuggestions.isNotEmpty) ? 8 : 18,
              ),
            ),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade300,
            ),
          ),


          child: TextField(
            controller: _topSearchController,
            focusNode: _topSearchFocusNode,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (_) {
              setState(() {});
              _onTopSearchChanged(_topSearchController.text);
            },
            onSubmitted: _performTopSearch,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontFamily: 'SFProText',
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: AppLocalizations.of(context)?.home_searchAiFoodImage ??
                  'Search Ai food image...',
              hintStyle: TextStyle(
                fontSize: 14,
                height: 1.2,
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontFamily: 'SFProText',
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Icon(
                  CupertinoIcons.search,
                  size: 18,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              suffixIcon: _isSearchingTopSuggestions
                  ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CupertinoActivityIndicator(radius: 8),
                ),
              )
                  : (_topSearchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 18,
                  color: isDarkMode ? Colors.white54 : Colors.black38,
                ),
                onPressed: () {
                  _topSearchController.clear();
                  setState(() {
                    _topSearchSuggestions = [];
                    _showTopSearchSuggestions = false;
                  });
                },
              )),

            ),
          ),

        ),
    if (_showTopSearchSuggestions && _topSearchSuggestions.isNotEmpty) ...[
    Transform.translate(
    offset: const Offset(0, -1),
    child: Container(

            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8),
          bottom: Radius.circular(16),
        ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade300,
        ),
      ),

            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _topSearchSuggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade200,
              ),
              itemBuilder: (_, index) {
                final item = _topSearchSuggestions[index];

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  title: Text(

                    item.title,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: item.subtitle.isNotEmpty
                      ? Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  )
                      : null,
                  onTap: () => _openMenuPreviewSheet(item),
                );
              },
            ),
          ),
    )
    ],

      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
        // 구독(premium)이나 광고제거(adfree) 둘 중 하나라도 있으면 isAdRemoved=true
    final isAdRemoved = context.watch<AdRemoveProvider>().isAdRemoved;



    return Container(
      margin: const EdgeInsets.only(top: 50), // 상단 여백
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 검색바
            _buildSearchBar(context),
            const SizedBox(height: 16),

            // 최신 좋아요 콘텐츠 표시 (기존 유지)
            if (widget.latestLikedData != null) _buildLatestLikedContainer(context),

            // 메인 카드 (헤더 + 캐러셀)
            _buildHeaderRow(),
            _buildGFCardCarousel(),

            const SizedBox(height: 16),

            HowToUseMscannerCard(
              onCardTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => CameraScreen(
                      onCancel: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // AD 라벨 + 기존 배너 광고
            if (!isAdRemoved) ...[
              Center(
                child: Text(
                  AppLocalizations.of(context)?.home_adLabel ?? 'AD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Consumer<AdRemoveProvider>(
                builder: (context, adProvider, child) {
                  if (adProvider.isSubscribed || adProvider.isAdRemoved) {
                    return SizedBox.shrink();
                  } else if (_isBannerLoaded && _adaptiveBanner != null) {
                    return Container(
                      width: _adaptiveBanner!.size.width.toDouble(),
                      height: _adaptiveBanner!.size.height.toDouble(),
                      alignment: Alignment.center,
                      child: AdWidget(ad: _adaptiveBanner!),
                    );
                  } else {
                    return SizedBox.shrink();
                  }
                },
              ),
              const SizedBox(height: 20),
            ],

            // Trending 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  localizations?.home_trendingNearYou ?? "What's Trending Near You",
                  style: TextStyle(
                    fontFamily: 'SFProDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 댓글 섹션 (기존 유지)
            CommentSection(userGeohash: widget.userGeohash),
          ],
        ),
      ),
    );
  }


  /// 1) "Last Liked Data" 표시 컨테이너
  Widget _buildLatestLikedContainer(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final data = widget.latestLikedData;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    final DateTime timestamp = DateTime.parse(data!['timestamp']);
    final String formattedDate =
    DateFormat('MMM dd, yyyy - h:mm a').format(timestamp);

    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 이미지 + 텍스트
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['image_url'] != null)
                  CachedNetworkImage(
                    imageUrl: data['image_url'],
                    width: MediaQuery.of(context).size.width * 0.20,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                    cacheManager: CustomCacheManager(),
                  ),
                SizedBox(width: 10),
                // 타이틀, 날짜, 위치 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Html(
                        data: data['title'] ?? 'No Title',
                        style: {
                          'body': Style(
                            color: isDarkMode ? Colors.white54 : Colors.grey[800],
                            fontSize: FontSize(14),
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w500,
                          ),
                        },
                      ),
                      SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color:
                          isDarkMode ? Colors.white54 : Colors.grey[800],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        data['location'] ?? 'No Location',
                        style: TextStyle(
                          color:
                          isDarkMode ? Colors.white54 : Colors.grey[800],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 25),

            // 레스토랑 이름 입력 + 별점
            CupertinoTextField(
              controller: _restaurantNameController,
              placeholder: localizations?.enterRestaurantName ??
                  'Enter restaurant name',
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.white54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              style: TextStyle(color: textColor),
            ),
            SizedBox(height: 10),
            // 별점
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    color: index < _rating ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            SizedBox(height: 10),

            // 저장 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 오른쪽으로 살짝 밀기 위한 Spacer
                Spacer(flex: 1),

                // 기존 스타일 유지한 Save 버튼
                SizedBox(
                  width: 90,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveData(false),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.grey : Colors.white,
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(localizations?.save ?? 'Save'),
                  ),
                ),

                SizedBox(width: 10),

                // 새로 추가된 Skip 버튼 (기존과 동일 스타일)
                SizedBox(
                  width: 110,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveData(true),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.grey : Colors.white,
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(localizations?.skip ?? 'Skip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _lastPressedTime;

  void _saveData(bool isSkip) {
    final now = DateTime.now();
    if (_lastPressedTime != null && now.difference(_lastPressedTime!) < Duration(milliseconds: 1200)) {
      return; // 연타 방지 (1.2초 간격 제한)
    }

    _lastPressedTime = now;
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    Future.microtask(() async {
      await _performSave(isSkip);
    });
  }



  Future<void> _performSave(bool isSkip) async {
    await LogService().logRatingPrompt(
      action: isSkip ? 'skip' : 'save',
      stars: isSkip ? null : _rating,
    ); // ⑧ 등급 버튼(저장/건너뛰기)

    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final User? user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        final String location = widget.latestLikedData?['location'] ?? 'Unknown';
        final List<String> responses = List<String>.from(widget.latestLikedData?['responses'] ?? []);
        final primary = _extractPrimaryMenuFromResponses(responses);
        final String timestamp = DateTime.now().toIso8601String();
        final String restaurantName = isSkip
            ? AppLocalizations.of(context)?.restaurantName ?? 'Restaurant Name'
            : _restaurantNameController.text.trim();

        final int rating = isSkip ? 0 : _rating;

        // GPS 및 geohash
        GeoPoint? gps = widget.latestLikedData?['gps'];
        String? geohash = widget.latestLikedData?['geohash'];

        // 위치 정보 파싱
        List<String> locationParts = location.split(',').map((part) => part.trim()).toList();
        String country = 'Unknown Country';
        String city = 'Unknown City';
        String other = '';

        if (locationParts.length >= 3) {
          other = locationParts.sublist(0, locationParts.length - 2).join(', ');
          city = locationParts[locationParts.length - 2];
          country = locationParts.last;
        } else if (locationParts.length == 2) {
          city = locationParts[0];
          country = locationParts[1];
        } else if (locationParts.length == 1) {
          country = locationParts[0];
        }

        if (restaurantName.isNotEmpty && rating > 0 || isSkip) {
          // ① user_rating 저장
          final ratingRef = firestore
              .collection('user_rating')
              .doc(user.uid)
              .collection('data')
              .doc(); // .add() 대신 doc 생성

          batch.set(ratingRef, {
            'restaurantName': restaurantName,
            'country': country,
            'city': city,
            'other': other,
            'rating': rating,
            'timestamp': timestamp,
            'gps': gps,
            'geohash': geohash,
            'image_url': widget.latestLikedData?['image_url'],
            'responses': responses,
            'review': widget.latestLikedData?['review'] ?? '',
            if (primary != null) 'primary_menu': primary, // ✅ 추가
          });

          // ② ranking_data 저장
          final rankingRef = firestore.collection('ranking_data').doc();
          batch.set(rankingRef, {
            'restaurantName': restaurantName,
            'country': country,
            'rating': rating,
            'timestamp': timestamp,
            'geohash': geohash,
          });

          // ③ 포인트 +1
          final pointRef = firestore.collection('user_points').doc(user.uid);
          batch.set(pointRef, {
            'points': FieldValue.increment(1),
          }, SetOptions(merge: true));

          // ④ liked 해제
          if (widget.latestLikedDoc != null) {
            batch.update(widget.latestLikedDoc!.reference, {'liked': false});
          }

          // 🔥 모든 변경 사항을 한 번에 커밋
          await batch.commit();

          // ✅ 저장 완료 메시지
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(localizations?.saved ?? 'Saved'),
                duration: Duration(seconds: 2),
              ),
            );

          // 필드 초기화 및 새로고침
          _restaurantNameController.clear();
          setState(() {
            _rating = 0;
            widget.onRefresh();
          });
        } else {
          // 입력 누락 메시지
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  localizations?.pleaseEnterRestaurantAndRating ??
                      'Please enter a restaurant name and rating',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
        }
      }
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context)?.home_errorSavingData ?? 'Error saving data'}: $e'),
          backgroundColor: Colors.red,
        ));
    } finally {
      _isSaving = false;
      if (mounted) setState(() {});
    }
  }




  /// 메인 카드 섹션 헤더 (Mscanner's Picks + View All)
  Widget _buildHeaderRow() {
    return Padding(
      padding: EdgeInsets.only(
        top: Platform.isIOS ? 18.0 : 12.0,
        left: 6.0,
        right: 6.0,
      ),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)?.home_mscannerPicks ?? "Mscanner's Picks",
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () async {
              final future = widget.mainCardDataFuture;
              if (future == null) return;
              final items = await future;
              if (!mounted || items.isEmpty) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(
                    items: items,
                    initialIndex: 0,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: Colors.deepOrange,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Row(
              children: [
                Text(AppLocalizations.of(context)?.home_viewAll ?? 'View All'),
                SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 메인 카드 캐러셀 (PageView 아님, 그냥 ListView)
  Widget _buildGFCardCarousel() {
    return FutureBuilder<List<Map<String, String>>>(
      future: widget.mainCardDataFuture, // HomeScreen에서 넘겨준 Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text(AppLocalizations.of(context)?.home_errorLoadingCards ?? 'Error loading cards'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)?.home_noDataAvailable ?? 'No data available'));
        } else {
          final cardData = snapshot.data!;
          if (!_sentMainCardsImpression && cardData.isNotEmpty) {
            _sentMainCardsImpression = true; // 위젯 수명 내 중복 방지
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return; // 안전 가드
              LogService().logContentImpression(
                contentType: 'home_main_cards',
                count: cardData.length,
                sampleRate: 1.0,       // 테스트는 1.0 (샘플링 배제)
                oncePerSession: false, // 테스트는 false로 (게이트 배제)
                oncePerDay: false,     // 테스트는 false로
                debug: false,           // 콘솔에 이유 출력
              );
            });
          }



          return SizedBox(
            height: 260,
            child: ListView.builder(
              shrinkWrap: true, // ✅ 추가 필요
              scrollDirection: Axis.horizontal,
              itemCount: cardData.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // 여기서 DetailScreen으로 이동 시, "전체 데이터"와 "현재 인덱스"를 함께 넘김
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(
                          items: cardData,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 260,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GFImageOverlay(
                        height: MediaQuery.of(context).size.height * 0.3,
                        width: MediaQuery.of(context).size.width * 0.8,
                        image: CachedNetworkImageProvider(
                          cardData[index]['image_url']!,
                          cacheManager: CustomCacheManager(),
                        ),
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Html(
                                data: cardData[index]['title']!,
                                style: {
                                  'body': Style(
                                    fontFamily: 'SFProText',
                                    color: GFColors.LIGHT,
                                    fontSize: FontSize(14),
                                    fontWeight: FontWeight.bold,
                                  ),
                                },
                              ),
                              const SizedBox(height: 1),
                              Html(
                                data: cardData[index]['subtitle']!,
                                style: {
                                  'body': Style(
                                    fontFamily: 'SFProText',
                                    color: GFColors.LIGHT,
                                    fontSize: FontSize(12),
                                    fontWeight: FontWeight.bold,
                                  ),
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );

              },
            ),
          );
        }

      },
    );
  }


  Widget _buildManualBanner(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconPath = isDarkMode
        ? 'assets/images/manual_dark.png'
        : 'assets/images/manual_light.png';
    if (!_sentManualImpression) {
      _sentManualImpression = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
       });
    }


    return CustomLinkLauncher(
      url: 'https://mscanner.net/how-to-use/',
      title: localizations?.manualTitle ?? 'Manual page',
      subtitle: localizations?.manualSubtitle ?? 'Read our documentation',
      iconPath: iconPath,
      titleStyle: TextStyle(
        fontSize: 15, // ✅ 좀 더 큼직한 텍스트
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.grey[800],
        fontFamily: 'SFPro',
      ),
      subtitleStyle: TextStyle(
        fontSize: 13,
        color: isDarkMode ? Colors.white70 : Colors.grey[700],
        fontFamily: 'SFPro',
      ),
    );
  }
}