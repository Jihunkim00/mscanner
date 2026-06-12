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
import '/analytics_service.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '/screens/image_merge_service.dart';
import 'package:mscanner/models/scan_mode.dart';
import 'package:mscanner/utils/async_request_gate.dart';


/// ✅ LoadingScreen에서도 멀티 스캔 이미지를 1장으로 병합/압축해서 전송
Future<Uint8List> mergeImages(List<Uint8List> bytesList) async {
  return await ImageMergeService.mergeAndCompress(bytesList);
}

class _PreparedVisionInput {
  final File visionFile;
  final String promptContext;
  final ScanMode scanMode;
  final int photoCount;
  _PreparedVisionInput(
    this.visionFile,
    this.promptContext,
    this.scanMode,
    this.photoCount,
  );
}


class LoadingScreen extends StatefulWidget {
  final File? image;
  final List<File>? images;     // 새로 추가한 멀티 이미지 리스트
  final DateTime captureTime;
  final Position? position;
  final bool isTutorial;
  final int maxOutputTokens; // ✅ 이미지 1장당 최대 출력 토큰



  LoadingScreen({
    Key? key,
    this.image,
    this.images,
    required this.captureTime,
    this.position,
    this.isTutorial = false,
    this.maxOutputTokens = 3000,
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
  final AsyncRequestGate _gptRequestGate = AsyncRequestGate();
  Timer? _loadingWatchdog;

  /// GPT 분석 Future는 initState 에서 바로 시작
  late Future<_PreparedVisionInput> _preparedFuture;

  static const Duration _prepareInputTimeout = Duration(seconds: 90);
  static const Duration _streamPreviewTimeout = Duration(seconds: 15);
  static const Duration _loadingStreamInactivityTimeout = Duration(seconds: 75);
  static const Duration _fallbackAnalyzeTimeout = Duration(seconds: 90);

  @override
  void initState() {
    super.initState();
    // 위치 기반 RAG 컨텍스트를 포함한 분석 준비
    _preparedFuture = _prepareVisionInput();
    _loadingWatchdog = Timer(const Duration(seconds: 40), () {
      if (!mounted || _hasNavigated || _isLoadingError) return;
      _showErrorUI();
    });
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
    final scanMode = files.length > 1 ? ScanMode.multi : ScanMode.single;
    return VisionService.analyzeImage(
      files.first,
      promptContext: promptContext,
      scanMode: scanMode,
      photoCount: files.length,
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
  Future<_PreparedVisionInput> _prepareVisionInput() async {
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

    // ✅ 입력 파일들(카메라/앨범/멀티스캔)
    final files = widget.images != null && widget.images!.isNotEmpty
        ? widget.images!
        : [widget.image!];

    // ✅ 분석용 파일 생성:
    // - 멀티스캔: 여러 장을 1장으로 병합/압축 후 1회만 호출
    // - 단일: 1장도 동일 파이프라인으로 압축(원본 용량이 큰 경우 대비)
    final tempDir = await getTemporaryDirectory();
    File visionFile;

    if (files.length > 1) {
      final bytesList = await Future.wait(files.map((f) => f.readAsBytes()));
      final mergedBytes = await compute(mergeImages, bytesList);
      visionFile = File('${tempDir.path}/vision_merged_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await visionFile.writeAsBytes(mergedBytes, flush: true);
    } else {
      final bytes = await files.first.readAsBytes();
      final compressedBytes = await compute(mergeImages, [bytes]);
      visionFile = File('${tempDir.path}/vision_single_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await visionFile.writeAsBytes(compressedBytes, flush: true);
    }

    // 🔎 디버그: 전송 파일 크기 확인
    try {
      final sz = await visionFile.length();
      print('🗜️ [Vision] send file size = ${(sz / 1024).toStringAsFixed(1)} KB');
    } catch (_) {}

    final scanMode = files.length > 1 ? ScanMode.multi : ScanMode.single;
    return _PreparedVisionInput(visionFile, promptContext, scanMode, files.length);
  }

  Future<List<String>> _waitFirstRecommendFromStream(
      Stream<String> stream, {
        Duration timeout = _streamPreviewTimeout,
      }) async {
    final buffer = StringBuffer();
    final completer = Completer<List<String>>();
    StreamSubscription<String>? sub;

    sub = stream.listen((delta) {
      buffer.write(delta);
      final s = buffer.toString();
      final m = RegExp(r'RECOMMEND:\s*(.+)').firstMatch(s);
      if (m != null) {
        final oneLine = m.group(1)!.split('\n').first.trim();
        final items = oneLine
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (!completer.isCompleted && items.isNotEmpty) {
          completer.complete(items);
          sub?.cancel();
        }
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.complete(<String>[]);
    }, onDone: () {
      if (!completer.isCompleted) completer.complete(<String>[]);
    });

    // 타임아웃 처리
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(<String>[]);
        sub?.cancel();
      }
    });

    return completer.future;
  }
  /// 넉넉한 타임아웃 + 스트리밍 우선 + 단일 요청 fallback
  Future<void> _handleGptResult() async {
    await _gptRequestGate.run(() async {
      try {
        final prepared = await _preparedFuture.timeout(_prepareInputTimeout);

        // ✅ 미리보기용 첫 이미지 (ResultScreen에 보여줄 썸네일)
        final File firstImage =
        (widget.images != null && widget.images!.isNotEmpty)
            ? widget.images!.first
            : widget.image!;

        final rawStream = VisionService.analyzeImageStream(
          prepared.visionFile,
          promptContext: prepared.promptContext,
          maxOutputTokens: widget.maxOutputTokens,
          scanMode: prepared.scanMode,
          photoCount: prepared.photoCount,
        );

        final stream = rawStream
            .timeout(_loadingStreamInactivityTimeout)
            .asBroadcastStream();

        if (!_hasNavigated && mounted) {
          _hasNavigated = true;
          await LogService().logScanCompleted();
          await AnalyticsService.instance.logScanSuccess(
            scanMode: ((widget.images?.length ?? 0) > 1) ? 'multi' : 'single',
            imageCount: widget.images?.length ?? 1,
            latencyMs: DateTime.now().difference(widget.captureTime).inMilliseconds,
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                image: firstImage,
                images: widget.images,
                responses: <String>[],
                responseStream: stream,
                initialFastRecommend: const [],
                position: widget.position,
                captureTime: widget.captureTime,
                isTutorial: widget.isTutorial,
              ),
            ),
          );
        }
      } catch (e) {
        // ✅ 스트리밍 실패 시: 기존 Future 방식 fallback
        try {
          final prepared = await _preparedFuture.timeout(_prepareInputTimeout);
          final resp = await VisionService.analyzeImage(
            prepared.visionFile,
            promptContext: prepared.promptContext,
            maxOutputTokens: widget.maxOutputTokens,
            scanMode: prepared.scanMode,
            photoCount: prepared.photoCount,
          ).timeout(_fallbackAnalyzeTimeout);

          if (!_hasNavigated && mounted) {
            _hasNavigated = true;
            await LogService().logScanCompleted();
            await AnalyticsService.instance.logScanSuccess(
              scanMode: ((widget.images?.length ?? 0) > 1) ? 'multi' : 'single',
              imageCount: widget.images?.length ?? 1,
              latencyMs: DateTime.now().difference(widget.captureTime).inMilliseconds,
            );
            _navigateToResultScreen([resp], previewImage: prepared.visionFile);
          }
        } catch (_) {
          _showErrorUI();
        }
      }
    });
  }



  /// 에러 UI 표시 후 5초 대기 -> 홈 복귀
  void _showErrorUI() {
    unawaited(AnalyticsService.instance.logScanFailed(
      scanMode: ((widget.images?.length ?? 0) > 1) ? 'multi' : 'single',
      stage: 'loading_screen',
      errorCode: 'analysis_failed',
    ));
    if (!mounted || _hasNavigated) return;
    setState(() => _isLoadingError = true);
    Future.delayed(Duration(seconds: 5), () {
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }



  void _navigateToResultScreenStream(Stream<String> stream, {required File previewImage}) {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // ✅ Result 화면 프리뷰 이미지는 "보여주기용"으로 원본 첫 장을 쓰되,
    // 분석에는 previewImage(병합/압축본)를 사용했습니다.
    final File firstImage = (widget.images != null && widget.images!.isNotEmpty)
        ? widget.images!.first
        : widget.image!;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          image: firstImage,
          images: widget.images,
          responses: <String>[],            // 스트림이니까 비움
          responseStream: stream,           // ✅ 반드시 넣기!
          position: widget.position,
          captureTime: widget.captureTime,
          isTutorial: widget.isTutorial,
        ),
      ),
    );
  }

  void _navigateToResultScreen(List<String> responses, {File? previewImage}) {
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
  void dispose() {
    _loadingWatchdog?.cancel();
    super.dispose();
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