import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/Result_Screen.dart';
import '../main.dart';
import 'vision_service.dart';
import 'package:mscanner/widgets/tutorial_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mscanner/screens/geohash_service.dart';
import '/screens/log_service.dart';


class LoadingScreen extends StatefulWidget {
  final File? image;
  final List<File>? images;     // 새로 추가한 멀티 이미지 리스트
  final DateTime captureTime;
  final Position? position;
  final bool isTutorial;


  LoadingScreen({
      Key? key,
      this.image,
      this.images,
      required this.captureTime,
      this.position,
      this.isTutorial = false,
    })  : assert(image != null || images != null,
             'image 또는 images 중 하나는 반드시 제공되어야 합니다.'),
        super(key: key);

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  late List<String> _loadingMessages;
  late String _currentMessage;

  bool _isLoadingError = false;
  bool _hasNavigated = false;

  /// GPT 분석 Future는 initState 에서 바로 시작
  late Future<List<String>> _gptFutureAll;

  @override
  void initState() {
    super.initState();
    // 위치 기반 RAG 컨텍스트를 포함한 분석 준비
    _gptFutureAll = _prepareAndAnalyzeAll();
    _showAdThenHandleGpt();
  }

  /// geohash로 장소 메모를 DB에서 불러와 promptContext에 삽입한 뒤 GPT 호출
  Future<String> _prepareAndAnalyze() async {
    String promptContext = '';
    if (widget.position != null) {
      final geohash = GeohashService().generateGeohash(
        widget.position!.latitude,
        widget.position!.longitude,
      );
      final firestoreFuture = FirebaseFirestore.instance
          .collection('rag_data')
          .where('geohashes', arrayContains: geohash)
          .limit(1)
          .get();

      final prefsFuture = SharedPreferences.getInstance();

      final results = await Future.wait([firestoreFuture, prefsFuture]);

      final snapshot = results[0] as QuerySnapshot;
      final prefs = results[1] as SharedPreferences;

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        String lang = prefs.getString('selectedLanguageCode') ?? Platform.localeName.split('_').first;
        lang = lang.replaceAll('-', '_');
        promptContext = data['detail_$lang'] ?? '';
      }

    }
    print('▶️ [RAG Context] promptContext: $promptContext');
    final files = widget.images ?? [widget.image!];
        return VisionService.analyzeImage(
          files.first,
          promptContext: promptContext,
        );
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = AppLocalizations.of(context)!;
    _loadingMessages = [
      loc.loadingScanning,
      loc.loadingAnalyzing,
      loc.loadingAlmostDone,
      loc.loadingFinalizing,
      loc.loadingWaiting,
    ];
    _currentMessage = _loadingMessages.first;
    _startLoadingMessages();
  }

  void _startLoadingMessages() {
    for (int i = 1; i < _loadingMessages.length; i++) {
      Future.delayed(Duration(seconds: i * 2), () {
        if (mounted && !_isLoadingError && !_hasNavigated) {
          setState(() => _currentMessage = _loadingMessages[i]);
        }
      });
    }
  }

  /// 광고를 띄우고, 닫힌 뒤에 GPT 결과 처리
  Future<void> _showAdThenHandleGpt() async {
    await Future.delayed(Duration(milliseconds: 800));

    if (enableInterstitialAds && globalInterstitialAd != null) {
      globalInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              globalInterstitialAd = null;
              loadInterstitialAd();
              _handleGptResult();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              globalInterstitialAd = null;
              loadInterstitialAd();
              _handleGptResult();
            },
          );
      globalInterstitialAd!.show();
    } else {
      _handleGptResult();
    }
  }

  // 기존 클래스 내부에 추가
  Future<List<String>> _prepareAndAnalyzeAll() async {
    String promptContext = '';
    if (widget.position != null) {
      final geohash = GeohashService().generateGeohash(
        widget.position!.latitude,
        widget.position!.longitude,
      );
      final snapshot = await FirebaseFirestore.instance
          .collection('rag_data')
          .where('geohashes', arrayContains: geohash)
          .limit(1)
          .get();
      final prefs = await SharedPreferences.getInstance();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        String lang = prefs.getString('selectedLanguageCode')
            ?? Platform.localeName.split('_').first;
        lang = lang.replaceAll('-', '_');
        promptContext = data['detail_$lang'] ?? '';
      }
    }
    // 멀티 이미지를 리스트로 준비
    final files = widget.images != null && widget.images!.isNotEmpty
        ? widget.images!
        : [widget.image!];
    // 모든 파일에 대해 GPT 호출
    return Future.wait(files.map((file) =>
        VisionService.analyzeImage(file, promptContext: promptContext)
    ));
  }





  /// 60초 타임아웃과 모든 예외를 동일하게 잡아서 에러 UI로
  Future<void> _handleGptResult() async {
    try {
      final responses = await _gptFutureAll.timeout(Duration(seconds: 60));
      if (!_hasNavigated && mounted) {
        await LogService().logScanCompleted();
        _navigateToResultScreen(responses); // ✅ 튜토리얼 여부 상관없이 결과 화면으로 이동
      }
    } catch (e) {
      _showErrorUI();
    }
  }



  /// 에러 UI 표시 후 5초 대기 -> 홈 복귀
  void _showErrorUI() {
    if (!mounted || _hasNavigated) return;
    setState(() => _isLoadingError = true);
    Future.delayed(Duration(seconds: 5), () {
      if (!_hasNavigated) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }



  void _navigateToResultScreen(List<String> responses) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    final File firstImage = (widget.images != null && widget.images!.isNotEmpty)
            ? widget.images!.first
            : widget.image!;

       Navigator.of(context).pushReplacement(
         MaterialPageRoute(
           builder: (_) => ResultScreen(
            image: firstImage,
            images: widget.images,     // ✅ 멀티 이미지 리스트 전달
            responses: responses,
            position: widget.position,
            captureTime: widget.captureTime,
            isTutorial: widget.isTutorial,
         ),
       ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context); // 🔥 build 메서드 초반에!


    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : Color(0xFFEFEFF4),
      child: Stack(
        children: [
          // 🔻 메시지 영역 (중앙)
          Center(
            child: _isLoadingError
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: Colors.red,
                  size: 40,
                ),
                SizedBox(height: 20),
                Text(
                  loc.gptErrorMessage.replaceAll(r'\n', '\n'),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : CupertinoColors.systemGrey,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 15),
                SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  child: Text(
                    _currentMessage,
                    key: ValueKey(_currentMessage),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : CupertinoColors
                          .systemGrey,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    loc.aiLoadingMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : CupertinoColors
                          .systemGrey2,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // ✅ 튜토리얼 모드 표시 (Visibility 로 감싸서 경고 제거)
          Visibility(
          visible: widget.isTutorial,
    child: Align(
    alignment: Alignment.topLeft,
    child: Padding(
    padding: EdgeInsets.only(
    top: mediaQuery.padding.top + 10,
    left: 20,
    ),
    child: TutorialIndicator(), // 이미 fontSize:14
    ),
            ),
          )],
      ),
    );
  }
}