import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/helpers/settings_helper.dart';
import 'package:mscanner/models/scan_mode.dart';
import 'package:mscanner/screens/vision_prompt_builder.dart';

class VisionService {
  static const bool _useRag = false;

  static final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  // 실제 OpenAI 호출은 Cloud Function 내부에서 처리합니다.
  // 여기 값은 로그/Cloud 전달용입니다. Cloud에서 모델을 고정하고 있으면 무시되어도 됩니다.
  static const String _visionModel = 'gpt-5.4-mini';

  static String _resolvePromptContext(String? promptContext) {
    if (!_useRag) return '';
    final safe = (promptContext ?? '').trim();
    return safe.length > 3000 ? safe.substring(0, 3000) : safe;
  }

  /// 기존 호출부 호환용 fallback.
  /// PR #9 LoadingScreen에서는 scanMode/photoCount를 직접 넘기므로 그 값을 우선 사용합니다.
  static ScanMode _resolveScanMode({
    ScanMode? scanMode,
    required int maxOutputTokens,
  }) {
    if (scanMode != null) return scanMode;
    return maxOutputTokens >= 9000 ? ScanMode.multi : ScanMode.single;
  }

  static int _resolvePhotoCount({
    required ScanMode scanMode,
    required int photoCount,
  }) {
    if (scanMode == ScanMode.multi) {
      return photoCount < 2 ? 2 : photoCount;
    }
    return 1;
  }

  static Future<String> _buildPrompt({
    required ScanMode scanMode,
    required int photoCount,
    required String? promptContext,
  }) async {
    final presetId = await SettingsHelper.getPreset();
    final question = await SettingsHelper.getQuestionByPreset(presetId);
    final langCode = await SettingsHelper.getLanguageCode();

    return buildVisionPrompt(
      scanMode: scanMode,
      targetLanguage: langCode,
      promptContext: _resolvePromptContext(promptContext),
      question: question ?? '',
      photoCount: photoCount,
    );
  }

  static Future<String> _callAnalyzeVision({
    required String imageBase64,
    required String prompt,
    required int maxOutputTokens,
    required ScanMode scanMode,
    required int photoCount,
    required String responseMode,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      print(
        '🚀 [Functions] analyzeVision call '
            'model=$_visionModel '
            'scanMode=${scanMode.wireName} '
            'photoCount=$photoCount '
            'responseMode=$responseMode '
            'maxTokens=$maxOutputTokens '
            'imageBase64Len=${imageBase64.length}',
      );

      final callable = _functions.httpsCallable(
        'analyzeVision',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );

      final result = await callable.call({
        'imageBase64': imageBase64,
        'prompt': prompt,
        'maxOutputTokens': maxOutputTokens,
        'scanMode': scanMode.wireName,
        'photoCount': photoCount,
        'responseMode': responseMode,

        // Cloud Function에서 model payload를 받도록 구현되어 있으면 사용됩니다.
        // Cloud에서 모델을 고정하고 있으면 이 값은 무시되어도 괜찮습니다.
        'model': _visionModel,
      });

      final rawData = result.data;
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{'result': rawData?.toString() ?? ''};

      final text = data['result']?.toString() ??
          data['text']?.toString() ??
          data['content']?.toString() ??
          '';

      print(
        '✅ [Functions] analyzeVision success '
            'model=${data['model']} '
            'scanMode=${data['scanMode']} '
            'photoCount=${data['photoCount']} '
            'responseMode=${data['responseMode']} '
            'maxOutputTokens=${data['maxOutputTokens']} '
            'textLen=${text.trim().length}',
      );

      if (text.trim().isEmpty) {
        print('⚠️ [Functions] empty response data=$data');
        throw const FormatException('Empty Functions response');
      }

      return text;
    } on FirebaseFunctionsException catch (e) {
      print(
        '❌ [Functions] analyzeVision failed '
            'code=${e.code} message=${e.message} details=${e.details}',
      );
      rethrow;
    } catch (e) {
      print('❌ [Functions] analyzeVision unknown error=$e');
      rethrow;
    }
  }

  static Future<String> analyzeImage(
      File imageFile, {
        String? promptContext,
        int maxOutputTokens = 3000,
        ScanMode? scanMode,
        int photoCount = 1,
      }) async {
    try {
      final resolvedScanMode = _resolveScanMode(
        scanMode: scanMode,
        maxOutputTokens: maxOutputTokens,
      );

      final resolvedPhotoCount = _resolvePhotoCount(
        scanMode: resolvedScanMode,
        photoCount: photoCount,
      );

      final bytes = await imageFile.readAsBytes();
      final kb = bytes.length / 1024;
      print(
        '🗜️ [Vision] bytes=${kb.toStringAsFixed(1)}KB '
            'file=${imageFile.path}',
      );

      final tEncode0 = DateTime.now();
      final base64Image = base64Encode(bytes);
      print(
        '⏱️ [Vision] base64Encode '
            '${DateTime.now().difference(tEncode0).inMilliseconds}ms',
      );

      final prompt = await _buildPrompt(
        scanMode: resolvedScanMode,
        photoCount: resolvedPhotoCount,
        promptContext: promptContext,
      );

      final tReq0 = DateTime.now();

      print(
        '🚀 [Vision] functions request start ${tReq0.toIso8601String()} '
            'maxTokens=$maxOutputTokens '
            'model=$_visionModel '
            'scanMode=${resolvedScanMode.wireName} '
            'photoCount=$resolvedPhotoCount '
            'rag=$_useRag',
      );

      final text = await _callAnalyzeVision(
        imageBase64: base64Image,
        prompt: prompt,
        maxOutputTokens: maxOutputTokens,
        scanMode: resolvedScanMode,
        photoCount: resolvedPhotoCount,
        responseMode: 'normal',
      );

      final reqMs = DateTime.now().difference(tReq0).inMilliseconds;
      print('⏱️ [Vision] functions response in ${reqMs}ms');
      print('🧾 [Vision] contentLen=${text.trim().length}');

      return text;
    } catch (e) {
      throw Exception('Vision 분석 중 오류: $e');
    }
  }

  /// 기존 LoadingScreen 구조 유지를 위해 Stream<String> 형태는 유지합니다.
  /// Firebase callable은 SSE streaming이 아니므로 최종 결과를 한 번 받아 yield 합니다.
  static Stream<String> analyzeImageStream(
      File imageFile, {
        String? promptContext,
        int maxOutputTokens = 3000,
        ScanMode? scanMode,
        int photoCount = 1,
      }) async* {
    try {
      final resolvedScanMode = _resolveScanMode(
        scanMode: scanMode,
        maxOutputTokens: maxOutputTokens,
      );

      final resolvedPhotoCount = _resolvePhotoCount(
        scanMode: resolvedScanMode,
        photoCount: photoCount,
      );

      final bytes = await imageFile.readAsBytes();
      final kb = bytes.length / 1024;
      print(
        '🗜️ [VisionStream] bytes=${kb.toStringAsFixed(1)}KB '
            'file=${imageFile.path}',
      );

      final tEncode0 = DateTime.now();
      final base64Image = base64Encode(bytes);
      print(
        '⏱️ [VisionStream] base64Encode '
            '${DateTime.now().difference(tEncode0).inMilliseconds}ms',
      );

      final prompt = await _buildPrompt(
        scanMode: resolvedScanMode,
        photoCount: resolvedPhotoCount,
        promptContext: promptContext,
      );

      final tReq0 = DateTime.now();

      print(
        '🚀 [VisionStream] functions request start '
            '${tReq0.toIso8601String()} '
            'maxTokens=$maxOutputTokens '
            'model=$_visionModel '
            'scanMode=${resolvedScanMode.wireName} '
            'photoCount=$resolvedPhotoCount '
            'rag=$_useRag',
      );

      final text = await _callAnalyzeVision(
        imageBase64: base64Image,
        prompt: prompt,
        maxOutputTokens: maxOutputTokens,
        scanMode: resolvedScanMode,
        photoCount: resolvedPhotoCount,
        responseMode: 'stream',
      );

      final reqMs = DateTime.now().difference(tReq0).inMilliseconds;
      print('⏱️ [VisionStream] functions response in ${reqMs}ms');
      print('🧾 [VisionStream] contentLen=${text.trim().length}');

      yield text;
    } catch (e) {
      throw Exception('Vision streaming 분석 중 오류: $e');
    }
  }
}
