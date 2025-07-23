import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '/screens/Home_Screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:getwidget/getwidget.dart'; // GetWidget package import
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

class _ResultScreenState extends State<ResultScreen> {
  String _address = 'Loading...';
  TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  bool _isDarkMode = false;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isLiked = false;
  bool _isCloudSaveEnabled = false;
  bool _isAllowedUser = false;
  Uint8List? _mergedImageBytes; // ✅ 병합된 이미지 저장용

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

    // ── UI 로딩 후에 이미지 병합 시작 ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // UI 로딩이 끝난 후 병합 작업 시작
      if (!widget.isTutorial && widget.images != null && widget.images!.length > 1) {
        _startMergeInBackground();  // 병합 작업을 비동기적으로 시작
      }
    });

    // 튜토리얼 모드일 때 탭 이벤트 리스너 등록
    if (widget.isTutorial) {
      Future.delayed(Duration.zero, () {
        GestureBinding.instance.pointerRouter.addGlobalRoute(_handleTutorialTap);
      });
    }

    // 공통 초기 설정
    _loadSettings();
    if (widget.title != null) {
      _storeNameController.text = widget.title!;
    }
    _isLiked = true;

    // 다크 모드 체크
    _checkDarkMode();

    // 결과 화면 로드 완료 로그
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LogService().logScanCompleted();
      print("✅ [ResultScreen] first frame rendered at ${DateTime.now().toIso8601String()}");
    });

    // 허용 사용자 체크
    _checkAllowedUser();

    // 위치 및 RAG, 푸드 디테일 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.position != null) {
        // 위치가 있을 경우
        _getAddressFromLatLng(widget.position!);

        final geohashService = GeohashService();
        _geohash = geohashService.generateGeohash(
          widget.position!.latitude,
          widget.position!.longitude,
        );

        _fetchRAGData();
        _fetchFoodDetail();
      }
      else if (widget.isFromHistory) {
        // 히스토리에서 온 경우
        setState(() {
          _address = widget.location ?? 'Location not available';
          _geohash = widget.geohash;
          _ragDetail = widget.ragDetail;
        });
        _fetchExistingReview();
        if (_ragDetail == null) {
          _fetchRAGData();
        }
        _fetchFoodDetail();
      }
      else {
        // 위치 정보가 없을 경우
        setState(() {
          _address = 'Location not available';
        });
      }
    });
  }


  Map<String, double> parseNutritionalData(String text) {
    final result = <String, double>{};

    // kcal 정보 추출 (예: "105 kcal")
    final regCal = RegExp(r'(\d+(\.\d+)?)\s*kcal', caseSensitive: false);
    final matchCal = regCal.firstMatch(text);
    if (matchCal != null) result['calories'] = double.parse(matchCal.group(1)!);

    // 단백질 추출 (예: "단백질: 11.4g")
    final regProtein = RegExp(r'단백질\s*[:=]\s*(\d+(\.\d+)?)\s*g');
    final matchProtein = regProtein.firstMatch(text);
    if (matchProtein != null) result['protein'] = double.parse(matchProtein.group(1)!);

    // 탄수화물 추출 (예: "탄수화물: 67.1g")
    final regCarbs = RegExp(r'탄수화물\s*[:=]\s*(\d+(\.\d+)?)\s*g');
    final matchCarbs = regCarbs.firstMatch(text);
    if (matchCarbs != null) result['carbs'] = double.parse(matchCarbs.group(1)!);

    // 지방 추출 (예: "지방: 7.35g")
    final regFat = RegExp(r'지방\s*[:=]\s*(\d+(\.\d+)?)\s*g');
    final matchFat = regFat.firstMatch(text);
    if (matchFat != null) result['fat'] = double.parse(matchFat.group(1)!);

    return result;
  }



  // Called when the loading timeout occurs
  void _onLoadingTimeout() {
    setState(() {
      _isLoadingError = true;
      _isLoading = false; // Stop loading
    });

    // After displaying the error message, go back to the home screen after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }
  bool _hasNavigatedFromTutorial = false; // 클래스 멤버 변수 추가 필요

  void _handleTutorialTap(PointerEvent event) {
    if (_hasNavigatedFromTutorial) return; // 중복 방지
    _hasNavigatedFromTutorial = true;

    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }


  void _startMergeInBackground() async {
    try {
      // 1) 이미지 바이트 로드
      final bytesList = await Future.wait(
        widget.images!.map((file) => file.readAsBytes()),
      );

      // 2) top‐level 함수 mergeImages를 compute로 호출
      final merged = await compute(mergeImages, bytesList);

      // 3) UI 업데이트
      if (mounted) {
        setState(() {
          _mergedImageBytes = merged;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mergedImageBytes = null);
      }
      print('❌ 이미지 병합 실패: $e');
    }
  }






  @override
  void dispose() {
    if (widget.isTutorial) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleTutorialTap);
    }
    _mergedImageBytes = null; // ✅ 메모리 정리
    _timer?.cancel();
    _storeNameController.dispose();
    _reviewController.dispose();

    super.dispose();
  }

  /// 특정 UID 사용자만 허용
  Future<void> _checkAllowedUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 허용할 UID 리스트 또는 단일 UID
      const allowedUidList = ['XSouRMPnmnhgQ0QiK8zgNvOQAwu1', 'sHWmp3IoNCh7YUY7BXjJ4OEIr9t1','UCNasiqnZgdvERYimeM9TvmNDI33','bVAaTXHSi1TTQGp7HPwT1whDUIS2','QV9xmlGofQbMe9ZOOTFxlAjnqbI3','01RLorc0WFWyxQIlae4wcXC9KJF3','pfJilWN46cPj9ikX0S8eXWNJCLe2'];
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
      Reference ref = FirebaseStorage.instance.ref().child('Beta_test').child(fileName);
      SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');

      UploadTask uploadTask;

      if (_mergedImageBytes != null) {
        // ✅ 병합된 이미지 사용
        uploadTask = ref.putData(_mergedImageBytes!, metadata);
      } else {
        // ✅ fallback: 단일 이미지 사용
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
            .doc(docId);  // ✅ 문서 ID 고정

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
          'review': _reviewController.text.trim(), // ✅ 리뷰 저장
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

    final allGeohashes = {centerHash, ...neighbors}; // 중복 제거된 Set

    // 🔸 현재 앱 표시 언어 (없으면 시스템 언어 fallback)
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('selectedLangCode') ?? Platform.localeName.split('_').first;

    await FirebaseFirestore.instance.collection('rag_reviews').add({
      'menuName': _storeNameController.text.trim(),
      'detail': trimmedReview,
      'geohashes': allGeohashes.toList(),     // ✅ center + 주변 geohash 포함
      'geohash5': centerHash.substring(0, 5), // ✅ center geohash의 앞 5자리
      'lang': langCode,                       // ✅ 리뷰 작성 당시의 앱 언어
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
// 추가: 사용 횟수 증가 및 리뷰 요청 메서드
  Future<void> _checkAndRequestReview() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int usageCount = prefs.getInt('usageCount') ?? 0;
    usageCount++;
    await prefs.setInt('usageCount', usageCount);

    bool hasReviewed = prefs.getBool('hasReviewed') ?? false;

    if (!hasReviewed) {
      // 최초 5회 사용 시 리뷰 요청
      if (usageCount == 5) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          await prefs.setBool('hasReviewed', true); // 리뷰 요청 후 표시
        }
      }
      // 5번 이후는 30번마다 요청
      else if (usageCount > 5 && (usageCount - 5) % 30 == 0) {
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

    // 🔥 이미지 업로드 먼저 확인
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
      return; // ❌ 저장 중단
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
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.textCopied ?? 'Text copied to clipboard',
        ),
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
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String getIconPath(String iconName) {
      return isDarkMode
          ? 'assets/images/${iconName}_white.png'
          : 'assets/images/$iconName.png';
    }

    // ✅ System Share를 바로 실행
    _shareToPlatform(context, 'shareToSystem');

  }

  // Method to extract all food names
  List<String> _extractAllFoodNames(String text) {
    List<String> extractedNames = [];

    // Split the response into lines
    List<String> lines = text.split('\n');

    for (String line in lines) {
      line = line.trim();

      // Regular expression to capture text enclosed in '**'
      final RegExp regExp = RegExp(
        r'\*\*(.*?)\*\*', // Capture all text between '**'
      );

      final Match? match = regExp.firstMatch(line);
      if (match != null && match.groupCount >= 1) {
        String foodName = match.group(1)?.trim() ?? '';

        // Remove any text within parentheses (e.g., "족발(앞발)" -> "족발")
        foodName = foodName.replaceAll(RegExp(r'\(.*?\)'), '').trim();

        // Ensure the food name is not empty and not too long
        if (foodName.isNotEmpty && foodName.length < 50) {
          extractedNames.add(foodName);
        }
      }
    }

    return extractedNames;
  }

  // Fetch food detail from Firestore
  Future<void> _fetchFoodDetail() async {
    try {
      List<String> foodNames = _extractAllFoodNames(widget.responses.join('\n'));
      if (foodNames.isEmpty) {
        print('No food names found in response.');
        return;
      }

      bool detailFound = false; // Track if detail is found

      for (String foodName in foodNames) {
        // Firestore query to search for documents where 'foodname' matches
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
          break; // Exit loop after finding the detail
        }
      }

      if (!detailFound) {
        // No matching document found
        setState(() {
          _foodDetail = null;
        });
      }
    } catch (e) {
      print('Failed to fetch food detail: $e');
      setState(() {
        _foodDetail = null; // Set to null in case of error
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

          // ✅ SharedPreferences에 없으면 시스템 언어 사용
          langCode ??= Localizations.localeOf(context).toLanguageTag(); // 예: 'ko' or 'pt-BR'

          // ✅ Firestore 필드명 포맷에 맞춰 언어 코드 변환 (pt-BR -> pt_BR 등)
          langCode = langCode.replaceAll('-', '_');

          String detailField = 'detail_$langCode';

          setState(() {
            _ragDetail = data.containsKey(detailField)
                ? data[detailField]
                : data['detail_en']; // 언어 없을 경우 fallback to English
          });
        } else {
          setState(() {
            _ragDetail = null;
          });
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



  // ── 2. PageView 기반 풀스크린 뷰어 호출 함수 ──
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
                        // ─── 썸네일 그리드 ───
                        // ─── 썸네일 그리드 (ImageGridViewer 사용) ───
                        ImageGridViewer(
                          images: widget.images != null && widget.images!.isNotEmpty
                              ? widget.images!
                              : [widget.image],
                          onTap: (i) {
                            final files = widget.images != null && widget.images!.isNotEmpty
                                ? widget.images!
                                : [widget.image];
                            _showFullImage(files: files, initialIndex: i);
                          },
                        ),

                        SizedBox(height: 16),

                        // ─── AI 응답 영역 (기존 코드 그대로) ───
                        Container(
                          decoration: boxDecoration,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(localizations!.aiAnswer,
                                  style: TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.bold, color: textColor)),
                              SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.responses.join('\n\n'),
                                      style: TextStyle(fontFamily: 'SFPro', fontSize: 12, color: textColor),
                                    ),
                                  ),
                                  Builder(builder: (_) {
                                    final nutritionData =
                                    parseNutritionalData(widget.responses.join('\n\n'));
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
                                    icon: Icon(Icons.copy, color: Colors.blue, size: 20),
                                    onPressed: () =>
                                        _copyTextToClipboard(widget.responses.join('\n\n')),
                                  ),
                                  IconButton(
                                    icon: Icon(CupertinoIcons.square_arrow_up, color: Colors.blue, size: 24),
                                    onPressed: () => Platform.isIOS
                                        ? _shareToPlatform(context, 'shareToSystem')
                                        : _showShareOptions(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

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

// ✅ 리뷰 입력 (모든 사용자 가능)
                        SizedBox(height: 16),
                        Container(
                          decoration: boxDecoration,
                          padding: EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.reviewTitle, // ✅ '리뷰 입력'
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
                                  hintText: localizations.reviewHint, // ✅ '음식점에 대한 간단한 감상평을 입력하세요'
                                  hintStyle: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),


                        SafeArea(
                          bottom: true,  // 하단 안전 영역만 적용
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveScanResult,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey
                                    : Colors.white,
                                backgroundColor: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey,
                                minimumSize: Size(double.infinity, 48),
                                textStyle: TextStyle(fontFamily: 'SFPro', fontSize: 14),
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
                                  color: _isDarkMode ? Colors.redAccent : Colors.red,
                                  size: 40.0,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  localizations.cloudsavingError,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'SFProText',
                                    color:
                                    _isDarkMode ? Colors.white70 : CupertinoColors.systemGrey,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ])
        )
    );
  }
}