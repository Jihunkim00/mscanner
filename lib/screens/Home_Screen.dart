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
  bool _isPremium = false; // ← ① 프리미엄 상태 변수 추가
  late AdRemoveProvider _adProvider;  // ← 추가
  bool _isFirstLogin = false; // 처음 로그인 여부 확인
  Timer? _blinkTimer;
  bool _blinkState = false;
  DateTime? _lastMultiScanTap;  // ← ① 추가


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
  }
  @override
    void didChangeDependencies() {
        super.didChangeDependencies();
        // Provider 생성 후 한 번만 _syncPremium을 리스닝
        _adProvider = Provider.of<AdRemoveProvider>(context);
        _adProvider.addListener(_syncPremium);
      }

    // Provider.isSubscribed 값이 바뀔 때마다 _isPremium 동기화
    void _syncPremium() {
        if (!mounted) return;
        setState(() {
          _isPremium = _adProvider.isSubscribed;
        });
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

  /// Firestore 에서 userStatus 를 읽어와서 _isPremium 세팅
   Future<void> _loadUserStatus() async {
       final uid = FirebaseAuth.instance.currentUser?.uid;
       if (uid == null) return;
       final doc = await FirebaseFirestore.instance
           .collection('user_points')
           .doc(uid)
           .get();
       if (doc.exists && doc.data()?['userStatus'] == 'premium') {
         setState(() => _isPremium = true);
         print('✅ 프리미엄 유저입니다. 광고가 제거됩니다.');
       }
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

      if (doc.exists && doc.data()?['enabled'] == true) {
        final data = doc.data()!;
        final String languageCode = PlatformDispatcher.instance.locale.languageCode;
        String? localizedMessage = data['message_$languageCode'] ?? data['message_en'];

        final shouldShow = await _shouldShowEmergencyPopup();

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
      // _checkDarkMode(),//
      _fetchLatestLikedData(),
      //_fetchUserPoints(),//
    ]);

    _countryFuture = LocationService().getCountryCodeFromGPS();
    await _loadInitialData();
    await _checkFirstLogin();


    // FirebaseAuth 상태 변화 리스너
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // 새로운 사용자가 로그인했을 때
        Provider.of<AdRemoveProvider>(context, listen: false)
            .refreshStatus();      // ← 이렇게 호출
        _onNewUserLogin();
      }
    });
    await _checkEmergencyNotice();
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
      Future.delayed(Duration(seconds: 6), ()
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

  void _onItemTapped(int index) {
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
         if (_lastMultiScanTap != null && now.difference(_lastMultiScanTap!) < Duration(seconds: 10)) {
           return;
         }
         _lastMultiScanTap = now;
      if (!Provider.of<AdRemoveProvider>(context, listen: false).isSubscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.premiumFunctionMessage)),
        );
        return;
      }
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

    Timer(Duration(seconds: 12), () {
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
    final bool premium = _isPremium;

    // 현재 테마 밝기
    final brightness = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark
        ? Brightness.dark
        : Brightness.light;
    final isAdRemoved = context.watch<AdRemoveProvider>().isAdRemoved;

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
                      color: _isPremium ? null : Colors.grey,
                    ),
                    label: localizations?.multiScan ?? 'multi scan',
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
          // ✅ 새로 추가된 플로팅 도움말 버튼


        ],
      ),

    );

  }

  List<Widget> _getWidgetOptions() {
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
         onCancel: () {
          _onItemTapped(0);
         },
        isPremium: _isPremium,

         ),

      // 히스토리
      HistoryScreen(),

      // 설정
      SettingScreen(),
    ];
  }
  @override
  void dispose() {
    _adProvider.removeListener(_syncPremium);
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

class _HomeContentState extends State<HomeContent> {

  BannerAd? _adaptiveBanner;
  bool _isBannerLoaded = false;
  bool _didLoadBanner = false;

  TextEditingController _restaurantNameController = TextEditingController();
  bool _isSaving = false; // 추가
  int _rating = 0;
  double _carouselSpacing = 10.0; // Spacing between "도시별 추천"과 GFCard

  @override
  void initState() {
    super.initState();

  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadBanner) {
      _loadAdaptiveBanner();
      _didLoadBanner = true;
    }
  }


  void _loadAdaptiveBanner() async {
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
    _adaptiveBanner?.dispose(); // ⬅️ 추가
    super.dispose();
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
            // 최신 좋아요 콘텐츠 표시
            if (widget.latestLikedData != null)
              _buildLatestLikedContainer(context),

            // 메인 카드 (헤더 + 캐러셀)
            _buildHeaderRow(),
            _buildGFCardCarousel(),

            const SizedBox(height: 20),

        // 광고 배너 (isAdRemoved 가 false 일 때만 보여줌)
                  if (!isAdRemoved && _isBannerLoaded && _adaptiveBanner != null)
              Container(
                width: _adaptiveBanner!.size.width.toDouble(),
                height: _adaptiveBanner!.size.height.toDouble(),
                alignment: Alignment.center,
                child: AdWidget(ad: _adaptiveBanner!),
              ),

            // 도움말 배너
            const SizedBox(height: 20),
            _buildManualBanner(context),

            const SizedBox(height: 20),
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
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final User? user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        final String location = widget.latestLikedData?['location'] ?? 'Unknown';
        final List<String> responses = List<String>.from(widget.latestLikedData?['responses'] ?? []);
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
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
        ));
    } finally {
      _isSaving = false;
      if (mounted) setState(() {});
    }
  }




  /// 2) 메인 카드 섹션
  Widget _buildHeaderRow() {
    final localizations = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: Platform.isIOS ? 30.0 : 20.0,
        left: 10.0,
        right: 10.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            localizations?.cityrecommand ?? 'Recommendations by Region',
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
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
          return Center(child: Text('Error loading cards'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No data available'));
        } else {
          final cardData = snapshot.data!;
          return SizedBox(
            height: 300,
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
                    width: 300,
                    margin: EdgeInsets.symmetric(horizontal: 5),
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
                            SizedBox(height: 1),
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