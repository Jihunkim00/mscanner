import 'package:flutter/material.dart';
import 'dart:io';
import 'Loading_Screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import '/widgets/photo_capture_widget.dart';
import '/screens/log_service.dart';



class CameraScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final bool isPremium; // (하위 호환 유지용) 상위에서 넘기면 우선 사용, 없으면 Provider 사용
  CameraScreen({
    required this.onCancel,
    this.isPremium = false,           // 기본값 false
    Key? key,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _showClosingOverlay = false;


  String _response = '';
  Position? _position;
  DateTime? _captureTime;
  bool _isProcessing = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    // 다시 진입 시에도 플래그가 초기 상태가 되도록 설정
    _isProcessing = false;
    _isCancelled = false;
  }



  @override
  void dispose() {
    _isCancelled = true; // ② 위젯이 사라질 때도 취소로 마킹
    super.dispose();
  }

  /// PhotoCaptureWidget.onCaptured 콜백
  Future<void> _onCaptured(List<File> rawFiles) async {
    print('📸 _onCaptured called: cancelled=$_isCancelled, processing=$_isProcessing');
    // 이미 처리 중이거나 취소된 상태면 즉시 리턴
    if (_isCancelled || _isProcessing) return;

    // 처리 시작 플래그 설정 (UI 갱신을 위해 setState 사용)
    setState(() => _isProcessing = true);

    try {
      // 프리미엄이 아니면 1장만 허용(혹시 위젯 변경/플랫폼 버그 등으로 여러 장 올 경우 대비)
      // 멀티스캔 탭에서만 여러 장 허용: 네비게이션에서 넘긴 flag만 사용
      final isMultiMode = widget.isPremium; // (이름 그대로: 멀티스캔 여부)
      final incoming = isMultiMode ? rawFiles : (rawFiles.isNotEmpty ? [rawFiles.first] : rawFiles);

      // 🔹 [LOG] ② 멀티 스캔: 사진 선택 후 전송
      if (isMultiMode && incoming.isNotEmpty) {
        // 여러 장이면 개수도 같이 남김
        await LogService().logMultiScanSubmit(imageCount: incoming.length);
      }


      // 1) 이미지 압축
      List<File> files = [];
      for (var f in incoming) {
        files.add(await compressImage(f));
      }

      // 2) 위치 및 시간 정보 취득
      Position? position = await _getCurrentLocation();
      DateTime captureTime = DateTime.now();

      // 중간에 취소되었거나 위젯이 언마운트되었으면 중단
      if (_isCancelled || !mounted) return;
      print('📸 네비게이션 전, mounted=$mounted');

      // 3) 다음 화면으로 안전하게 네비게이션
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('📸 Navigator.push 실행');
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoadingScreen(
              image: files.length == 1 ? files.first : null,
              images: files.length > 1 ? files : null,
              captureTime: captureTime,
              position: position,
              maxOutputTokens: isMultiMode ? 9000 : 3000,
            ),
          ),
        );
      });
    } catch (e) {
      // 에러 발생 시에도 위젯이 살아있으면 스낵바 표시
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.loadingError
                ?? '분석 중 오류가 발생했습니다.',
          ),
        ),
      );
      widget.onCancel();
    } finally {
      // 처리 종료 플래그 해제 (UI 갱신)
      if (mounted) setState(() => _isProcessing = false);
    }
  }



  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // 🔎 원본 크기 로그(디버그)
    try {
      final inSize = await file.length();
      print('🖼️ [Compress] input = ${(inSize / 1024).toStringAsFixed(1)} KB');
    } catch (_) {}

    // ✅ 분석/OCR 용도: 과도한 원본(4K/8K) 전송 방지
    // - 메뉴판은 1280~1600px 정도면 충분한 경우가 대부분
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 60,          // 50~70 권장 (OCR 고려)
      minWidth: 1600,        // ✅ 너무 큰 원본을 줄이기 위한 기준
      minHeight: 1600,
      keepExif: false,
    );

    if (result == null) {
      throw Exception('Failed to compress image');
    }

    final outFile = File(result.path);

    // 🔎 압축 후 크기 로그(디버그)
    try {
      final outSize = await outFile.length();
      print('🗜️ [Compress] output = ${(outSize / 1024).toStringAsFixed(1)} KB');
    } catch (_) {}

    return outFile;
  }


  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationPermissionDialog();
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationPermissionDialog();
      return null;
    }

    return await Geolocator.getCurrentPosition(); // ✅ Position을 반환함
  }


  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (Platform.isIOS) {
          return CupertinoAlertDialog(
            title: Text(
                AppLocalizations.of(context)!.locationPermissionNeeded),
            // 로컬라이즈된 제목
            content: Text(AppLocalizations.of(context)!
                .locationPermissionContent),
            // 로컬라이즈된 내용
            actions: [
              CupertinoDialogAction(
                child: Text(AppLocalizations.of(context)!.cancel),
                // 로컬라이즈된 "취소" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel();
                },
              ),
              CupertinoDialogAction(
                child:
                Text(AppLocalizations.of(context)!.openSettings),
                // 로컬라이즈된 "설정 열기" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openAppSettings();
                },
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: Text(
                AppLocalizations.of(context)!.locationPermissionNeeded),
            // 로컬라이즈된 제목
            content: Text(AppLocalizations.of(context)!
                .locationPermissionContent),
            // 로컬라이즈된 내용
            actions: [
              TextButton(
                child: Text(AppLocalizations.of(context)!.cancel),
                // 로컬라이즈된 "취소" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel();
                },
              ),
              TextButton(
                child:
                Text(AppLocalizations.of(context)!.openSettings),
                // 로컬라이즈된 "설정 열기" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openAppSettings();
                },
              ),
            ],
          );
        }
      },
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (Platform.isIOS) {
          return CupertinoAlertDialog(
            title: Text(
                AppLocalizations.of(context)!.locationServiceDisabled),
            // 로컬라이즈된 제목
            content: Text(AppLocalizations.of(context)!
                .locationServiceDisabledContent),
            // 로컬라이즈된 내용
            actions: [
              CupertinoDialogAction(
                child: Text(AppLocalizations.of(context)!.cancel),
                // 로컬라이즈된 "취소" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel();
                },
              ),
              CupertinoDialogAction(
                child:
                Text(AppLocalizations.of(context)!.openSettings),
                // 로컬라이즈된 "설정 열기" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openLocationSettings();
                },
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: Text(
                AppLocalizations.of(context)!.locationServiceDisabled),
            // 로컬라이즈된 제목
            content: Text(AppLocalizations.of(context)!
                .locationServiceDisabledContent),
            // 로컬라이즈된 내용
            actions: [
              TextButton(
                child: Text(AppLocalizations.of(context)!.cancel),
                // 로컬라이즈된 "취소" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel();
                },
              ),
              TextButton(
                child:
                Text(AppLocalizations.of(context)!.openSettings),
                // 로컬라이즈된 "설정 열기" 버튼
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openLocationSettings();
                },
              ),
            ],
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Provider 기준으로 최신 구독 상태를 읽고, 상위에서 명시적으로 넘긴 값이 true면 그걸 우선.
// 네비게이션에서 넘긴 값으로만 멀티/싱글 결정
    final isMultiMode = widget.isPremium;
    final maxCount = isMultiMode ? 4 : 1;
    return WillPopScope(
      onWillPop: () async {
        // Flutter 레벨 뒤로가기도 홈으로
        widget.onCancel();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(leading: SizedBox.shrink(), /*…*/),
        body: PhotoCaptureWidget(
          isMulti: isMultiMode,
          maxCount: maxCount,
          onCaptured: _onCaptured,
          onCancel: widget.onCancel,
        ),
      ),
    );
  }
}