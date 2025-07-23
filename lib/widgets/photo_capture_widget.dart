import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

/// PhotoCaptureWidget
///
/// - [isMulti]: true일 경우 갤러리에서 최대 [maxCount]만큼 이미지를 선택
///   false일 경우 카메라 촬영으로 단일 이미지를 선택
/// - 선택된 이미지 리스트는 [onCaptured] 콜백으로 전달
/// - 사용자가 취소했을 때는 [onCancel] 콜백이 호출되어 홈으로 복귀
class PhotoCaptureWidget extends StatefulWidget {
  final bool isMulti;
  final int maxCount;
  final void Function(List<File>) onCaptured;
  final VoidCallback onCancel;

  const PhotoCaptureWidget({
    Key? key,
    this.isMulti = false,
    this.maxCount = 4,
    required this.onCaptured,
    required this.onCancel,
  }) : super(key: key);

  @override
  _PhotoCaptureWidgetState createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  final ImagePicker _picker = ImagePicker();
  List<File> _photos = [];

  @override
  void initState() {
    super.initState();
    // 화면이 뜨자마자 사진 선택/촬영 실행
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickPhotos());
  }

  Future<void> _pickPhotos() async {
    if (widget.isMulti) {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (!mounted) return;
      // 취소하거나 선택 없으면 바로 홈으로
      if (pickedFiles == null || pickedFiles.isEmpty) {
        widget.onCancel();
        return;
      }
    // ★ 5장 이상 선택 시, 스낵바 안내는 띄우되 앞의 4장만 사용
         if (pickedFiles.length > widget.maxCount) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(AppLocalizations.of(context)!.maxScanImages(widget.maxCount))
             ),
           );
         }
      final files = pickedFiles
          .take(widget.maxCount)
          .map((pf) => File(pf.path))
          .toList();
      setState(() => _photos = files);
      widget.onCaptured(files);
    } else {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;
      // 취소했을 때 홈으로
      if (picked == null) {
        widget.onCancel();
        return;
      }

      final file = File(picked.path);
      setState(() => _photos = [file]);
      widget.onCaptured([file]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 뒤로가기 버튼 완전 차단
      onWillPop: () async => false,
      child: Center(
        child: _photos.isEmpty
        // 사진 선택 전에는 빈 화면. 아이콘도 제거
            ? SizedBox.shrink()
        // 선택된 사진 썸네일만 표시
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _photos
              .map((file) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              file,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ))
              .toList(),
        ),
      ),
    );
  }
}
