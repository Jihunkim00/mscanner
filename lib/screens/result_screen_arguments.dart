// result_screen_arguments.dart

import 'dart:io';
import 'package:geolocator/geolocator.dart';

class ResultScreenArguments {
  final File image;
  final List<File>? images;     // ← 멀티 이미지 리스트 필드 추가
  final List<String> responses; // ← GPT 응답 리스트 필드 추가
  final Position? position;
  final DateTime captureTime;
  final bool isFromHistory;
  final String? title;
  final String? location;
  final String? geohash;
  final String? ragDetail;
  final bool isTutorial;

  ResultScreenArguments({
    required this.image,
    this.images,                  // ← 생성자에 images 추가
    required this.responses,      // ← 생성자에 responses 추가
    this.position,
    required this.captureTime,
    this.isFromHistory = false,
    this.title,
    this.location,
    this.geohash,
    this.ragDetail,
    this.isTutorial = false,
  });
}
