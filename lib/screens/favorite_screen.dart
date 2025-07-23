import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'mapscreen.dart';
import 'package:getwidget/getwidget.dart'; // GetWidget 패키지 임포트

class FavoriteScreen extends StatefulWidget {
  final String documentId;

  FavoriteScreen({required this.documentId});

  @override
  _FavoriteScreenState createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  bool _isDarkMode = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  final GlobalKey _shareWidgetKey = GlobalKey();
  Map<String, dynamic>? _favoriteData;
  TextEditingController _restaurantNameController = TextEditingController();
  TextEditingController _reviewController = TextEditingController();
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _checkDarkMode();
    _fetchFavoriteData();
  }

  Future<void> _checkDarkMode() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
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
          double latitude = _favoriteData?['latitude'] ?? 0.0;
          double longitude = _favoriteData?['longitude'] ?? 0.0;

          // Listener to detect changes in the restaurant name
          _restaurantNameController.addListener(() {
            setState(() {
              _hasChanges = _restaurantNameController.text !=
                  _favoriteData?['restaurantName'];
            });
          });
        });
      }
    }
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.saved ?? 'Saved'),

          ),
        );

        setState(() {
          _hasChanges = false; // 저장 후 변경 상태 초기화
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _shareCapturedImage() async {
    try {
      // 위젯이 완전히 렌더링된 후에 캡처하도록 합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RenderRepaintBoundary? boundary =
        _shareWidgetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

        if (boundary == null) {
          print('RenderRepaintBoundary is still null');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: RenderRepaintBoundary is not ready.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // 현재 디바이스의 픽셀 비율을 가져오고, 해상도를 높이기 위해 두 배로 설정
        double pixelRatio = MediaQuery.of(context).devicePixelRatio;
        double desiredPixelRatio = pixelRatio * 2;

        // 높은 픽셀 비율로 이미지 캡처
        var image = await boundary.toImage(pixelRatio: desiredPixelRatio);
        ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        // 임시 파일로 저장
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/shared_image.png').create();
        await file.writeAsBytes(pngBytes);

        // 쉐어 기능 호출
        await Share.shareXFiles(
          [XFile(file.path)],
          text: AppLocalizations.of(context)?.checkOutRestaurant ?? 'Check out this restaurant!',
        );
      });
    } catch (e) {
      // 예외 발생 시 로그 출력
      print('Error sharing the image: $e');
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

  @override
  Widget build(BuildContext context) {
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
    final dynamic  rawList   = _favoriteData!['responses'];
    final dynamic  rawSingle = _favoriteData!['response'];

        List<String>   normalized;
        if (rawList is List) {
          normalized = rawList.map((e) => e.toString()).toList();
        } else if (rawSingle != null) {
          normalized = [rawSingle.toString()];
        } else {
          normalized = [];
        }

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
                            Colors.black.withOpacity(0.3),
                            BlendMode.darken,
                          ),
                          borderRadius: BorderRadius.circular(8),
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
                                              _favoriteData!['other'] ?? 'Unknown other',
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
                                    Icon(CupertinoIcons.time, color: Colors.white),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMM dd, yyyy - h:mm a').format(
                                          DateTime.parse(_favoriteData!['timestamp']),
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
                                    hintText: '레스토랑 이름',
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
                                          _hasChanges =
                                              _rating != (_favoriteData?['rating'] ?? 0) ||
                                                  _restaurantNameController.text.trim() != (_favoriteData?['restaurantName'] ?? '');
                                        });

                                      },
                                      child: Icon(
                                        index < _rating
                                            ? CupertinoIcons.star_fill
                                            : CupertinoIcons.star,
                                        color: index < _rating ? Colors.amber : Colors.grey,
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
                  // AI 응답
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.aiAnswer,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          responseText.isNotEmpty
                              ? responseText
                              : 'No responses available',  // ← join 결과가 비어있으면 대체 문구 출력
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.copy, color: Colors.blue, size: 20),
                                onPressed: () => _copyTextToClipboard(responseText),  // ← 복사할 때도 join 결과 사용
                              ),
                              IconButton(
                                icon: Icon(CupertinoIcons.square_arrow_up, color: Colors.blue, size: 24),
                                onPressed: _shareCapturedImage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
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
                            hintText: AppLocalizations.of(context)?.reviewHint ??
                                'Write your thoughts about this restaurant...',
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
                      foregroundColor: _isDarkMode ? Colors.grey : Colors.white,
                      backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey,
                      textStyle: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.save),
                  ),
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
        ],
      ),
    );
  }

  // 지도 화면으로 이동하는 함수
  void _navigateToMapScreen() {
    if (_favoriteData != null) {
      String restaurantName = _favoriteData?['restaurantName'] ?? 'Unknown Restaurant';
      GeoPoint geoPoint = _favoriteData?['gps'] ?? GeoPoint(0.0, 0.0); // gps 필드가 없을 경우 기본값 설정

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
