import 'package:flutter/material.dart';
import 'dart:io';
import 'Loading_Screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/widgets/tutorial_indicator.dart';

class TutorialCameraScreen extends StatefulWidget {
  @override
  _TutorialCameraScreenState createState() => _TutorialCameraScreenState();
}

class _TutorialCameraScreenState extends State<TutorialCameraScreen> {
  bool _isProcessing = false;
  File? _sampleImageFile;

  @override
  void initState() {
    super.initState();
    _loadSampleImage();
  }

  Future<void> _loadSampleImage() async {
    final byteData = await rootBundle.load('assets/images/tutorial_sample.jpg');
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/tutorial_sample.jpg');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    setState(() {
      _sampleImageFile = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _sampleImageFile == null
          ? Center(child: CupertinoActivityIndicator(radius: 15))
          : Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              _sampleImageFile!,
              fit: BoxFit.cover,
            ),
          ),
          // 🔻 튜토리얼 인디케이터 추가
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: TutorialIndicator(),
          ),
          // 🔻 셔터 버튼
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onShutterPressed,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ),
          ),
          // 🔻 Skip 버튼
          // Skip 버튼
          Positioned(
            bottom: 50,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.blueGrey[300] : Colors.blueGrey[700], // ✅ 다크/라이트 모드 대응
                foregroundColor: isDarkMode ? Colors.black : Colors.white, // 텍스트 색상 반전
                shape: RoundedRectangleBorder( // 둥근 버튼
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), // 여백 추가
              ),
              child: Text(AppLocalizations.of(context)?.skip ?? 'Skip'),
            ),
          ),

        ],
      ),

    );
  }

  Future<void> _onShutterPressed() async {
    if (_isProcessing || _sampleImageFile == null) return;
    _isProcessing = true;

    try {
      DateTime captureTime = DateTime.now();
      Position? position = await _getCurrentLocation();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoadingScreen(
            image: _sampleImageFile!,
            captureTime: captureTime,
            position: position,
            isTutorial: true,
          ),
        ),
      );
    } catch (e) {
      print("튜토리얼 오류: $e");
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }
}
