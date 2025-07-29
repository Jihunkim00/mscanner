import 'package:flutter/material.dart';
import 'dart:io';
import 'Loading_Screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import '/widgets/photo_capture_widget.dart';


class CameraScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final bool isPremium;
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
      // 1) 이미지 압축
      List<File> files = [];
      for (var f in rawFiles) {
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
        '${tempDir.path}/compressed_${DateTime
        .now()
        .millisecondsSinceEpoch}.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minHeight: 1920,
      minWidth: 1080,
      quality: 50,
    );

    if (result != null) {
      return File(result.path); // XFile을 File로 변환
    } else {
      throw Exception('Failed to compress image');
    }
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
          isMulti: widget.isPremium,
          maxCount: 4,
          onCaptured: _onCaptured,
          onCancel: widget.onCancel,  // ← 여기를 연결
        ),
      ),
    );
  }
}