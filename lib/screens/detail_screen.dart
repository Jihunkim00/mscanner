import 'dart:io';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_html/flutter_html.dart';

class DetailScreen extends StatefulWidget {
  final List<Map<String, String>> items;
  final int initialIndex;

  const DetailScreen({
    Key? key,
    required this.items,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // initialIndex로 PageView 시작점 설정
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
    isDarkMode ? CupertinoColors.black : Color(0xFFEFEFF4);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          // index 위치의 데이터를 꺼냄
          final data = widget.items[index];
          return _buildDetailItem(context, data, index);
        },
      ),
    );
  }

  /// 개별 페이지(상세 정보) 빌드
  Widget _buildDetailItem(
      BuildContext context,
      Map<String, String> data,
      int pageIndex,
      ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? CupertinoColors.white : CupertinoColors.black;

    // 주요 필드들
    final String imageUrl = data['image_url'] ?? '';
    final String title = data['title'] ?? 'No Title';
    final String subtitle = data['subtitle'] ?? 'No Subtitle';
    final String detail = data['detail'] ?? 'No Detail';

    final String? imageUrl2 = data['image_url_2'];
    final String? imageUrl3 = data['image_url_3'];
    final String? imageUrl4 = data['image_url_4'];
    final String? imageUrl5 = data['image_url_5'];

    // 추가 이미지 리스트
    final List<String> additionalImageUrls = [
      if (imageUrl2 != null && imageUrl2.isNotEmpty) imageUrl2,
      if (imageUrl3 != null && imageUrl3.isNotEmpty) imageUrl3,
      if (imageUrl4 != null && imageUrl4.isNotEmpty) imageUrl4,
      if (imageUrl5 != null && imageUrl5.isNotEmpty) imageUrl5,
    ];

    // detail 일부만 표시
    final String trimmedDetail = (detail.length > 200)
        ? detail.substring(0, 200) + '...'
        : detail;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 메인 이미지
            Expanded(
              flex: 2,
              child: GFImageOverlay(
                height: MediaQuery.of(context).size.height * 0.5,
                width: MediaQuery.of(context).size.width,
                image: NetworkImage(
                  imageUrl.isNotEmpty
                      ? imageUrl
                      : 'https://via.placeholder.com/150',
                ),
                boxFit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Html(
                        data: title,
                        style: {
                          'body': Style(
                            color: GFColors.LIGHT,
                            fontSize: FontSize(24),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SFProText',
                          ),
                        },
                      ),
                      const SizedBox(height: 1),
                      Html(
                        data: subtitle,
                        style: {
                          'body': Style(
                            color: GFColors.LIGHT,
                            fontSize: FontSize(16),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SFProText',
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 하단 텍스트 + 추가 이미지
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // detail 일부 표시
                    Html(
                      data: trimmedDetail,
                      style: {
                        'body': Style(
                          color: textColor,
                          fontSize: FontSize(14),
                          fontFamily: 'SFProText',
                        ),
                      },
                    ),

                    // more... 버튼
                    if (detail.length > 200)
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (BuildContext context) {
                              return Container(
                                color: isDarkMode
                                    ? CupertinoColors.black
                                    : CupertinoColors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    child: Html(
                                      data: detail,
                                      style: {
                                        'body': Style(
                                          color: textColor,
                                          fontSize: FontSize(14),
                                          fontFamily: 'SFProText',
                                        ),
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            'more...',
                            style: TextStyle(
                              fontFamily: 'SFProText',
                              fontSize: 14,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 하단 추가 이미지 가로 스크롤
                    _buildImageCarousel(context, additionalImageUrls),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 왼쪽 상단 뒤로가기 버튼
        Positioned(
          top: Platform.isIOS ? 46 : 26,
          left: 1,
          child: IconButton(
            icon: const Icon(
              CupertinoIcons.back,
              color: Colors.white,
              size: 30.0,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  /// [하단 썸네일] 이미지 리스트
  Widget _buildImageCarousel(
      BuildContext context, List<String> imageUrls) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.15,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            // 이미지 클릭 시 => "이미지 전체 뷰어" 다이얼로그 실행
            onTap: () {
              _showFullScreenCarousel(context, imageUrls, index);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: MediaQuery.of(context).size.width * 0.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrls[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                      ) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (
                      BuildContext context,
                      Object exception,
                      StackTrace? stackTrace,
                      ) {
                    // 에러 시 대체 이미지
                    return Image.asset('assets/images/default_image.png',
                        fit: BoxFit.cover);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// **전체 화면(풀스크린) 이미지 뷰어**를 띄우는 메서드
  /// - PageView.builder + InteractiveViewer
  /// - [initialIndex]부터 시작 → 좌우 스와이프 가능
  void _showFullScreenCarousel(
      BuildContext context, List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true, // 바깥 영역 탭 시 닫기
      builder: (BuildContext context) {
        // Scaffold로 감싸 fullscreen 처럼 사용
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 좌우 스와이프
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: imageUrls.length,
                itemBuilder: (context, pageIndex) {
                  return Center(
                    child: InteractiveViewer(
                      panEnabled: true, // 드래그로 이동
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrls[pageIndex],
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              // 닫기 버튼(우상단)
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
