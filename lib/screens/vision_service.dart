import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '/helpers/settings_helper.dart';
import 'package:mscanner/models/scan_mode.dart';
import 'package:mscanner/screens/vision_prompt_builder.dart';
import 'package:mscanner/utils/sse_event_parser.dart';

class VisionService {
  static const bool _useRag = false;

  static String _resolvePromptContext(String? promptContext) {
    if (!_useRag) return '';
    final safe = (promptContext ?? '').trim();
    return safe.length > 3000 ? safe.substring(0, 3000) : safe;
  }

  // 기존: static Future<String> analyzeImage(File imageFile) async {
  static Future<String> analyzeImage(
      File imageFile, {
        String? promptContext,
        int maxOutputTokens = 3000, // ✅ 추가
        ScanMode scanMode = ScanMode.single,
        int photoCount = 1,
      }) async {

    try {
      final bytes = await imageFile.readAsBytes();
      final kb = bytes.length / 1024;
      print('🗜️ [Vision] bytes=${kb.toStringAsFixed(1)}KB file=${imageFile.path}');

      final tEncode0 = DateTime.now();
      final base64Image = base64Encode(bytes);
      print('⏱️ [Vision] base64Encode ${DateTime.now().difference(tEncode0).inMilliseconds}ms');


      final presetId = await SettingsHelper.getPreset();
      final question = await SettingsHelper.getQuestionByPreset(presetId);

      // 1) 스캔 모드별 Vision prompt를 분리해서 구성합니다.
      final langCode = await SettingsHelper.getLanguageCode();
      final mergedPromptWithProtocol = buildVisionPrompt(
        scanMode: scanMode,
        targetLanguage: langCode,
        promptContext: _resolvePromptContext(promptContext),
        question: question,
        photoCount: photoCount,
      );

// 2) contentList에 mode-specific prompt(텍스트)와 이미지(block)만 담습니다.
      final List<Map<String, dynamic>> contentList = [
        {
          'type': 'text',
          'text': mergedPromptWithProtocol,
        },
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
      ];

// 3) messages 배열에는 user 메시지 하나만. content에 contentList 배열을 넘겨야 합니다.
      final payload = {
        'model': 'gpt-5-mini',
        'messages': [
          {'role': 'user', 'content': contentList}
        ],
        'reasoning_effort': 'low',              // ✅ 빈 응답/짧은 응답 방지에 도움
        'max_completion_tokens': maxOutputTokens,
      };


      final tReq0 = DateTime.now();
      print('🚀 [Vision] request start ${tReq0.toIso8601String()} maxTokens=$maxOutputTokens model=gpt-5-mini rag=$_useRag scanMode=${scanMode.wireName} photoCount=$photoCount');

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['API_KEY']}',
        },
        body: jsonEncode(payload),
      );

      final reqMs = DateTime.now().difference(tReq0).inMilliseconds;
      print('⏱️ [Vision] response in ${reqMs}ms status=${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final content = json['choices']?[0]?['message']?['content'];
        final text = (content is String) ? content : (content?.toString() ?? '');
        print('🧾 [Vision] contentLen=${text.trim().length}');
        if (text.trim().isEmpty) {
          print('⚠️ [Vision] EMPTY content body=${utf8.decode(response.bodyBytes)}');
        }
        return text;


      } else {
        final body = utf8.decode(response.bodyBytes);
        print('❌ [Vision] error body=$body');
        throw Exception('GPT 응답 실패: ${response.statusCode}\n$body');
      }

    } catch (e) {
      throw Exception('Vision 분석 중 오류: $e');
    }
  }
  /// ✅ Streaming version: yields incremental text chunks (SSE)
  static Stream<String> analyzeImageStream(
      File imageFile, {
        String? promptContext,
        int maxOutputTokens = 3000,
        ScanMode scanMode = ScanMode.single,
        int photoCount = 1,
      }) async* {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final presetId = await SettingsHelper.getPreset();
    final question = await SettingsHelper.getQuestionByPreset(presetId);
    final lang = (await SettingsHelper.getLanguageCode()).toString();

    final mergedPromptWithProtocol = buildVisionPrompt(
      scanMode: scanMode,
      targetLanguage: lang,
      promptContext: _resolvePromptContext(promptContext),
      question: question,
      photoCount: photoCount,
    );

    final List<Map<String, dynamic>> contentList = [
      {'type': 'text', 'text': mergedPromptWithProtocol},
      {
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},

      },
    ];

    final payload = {
      'model': 'gpt-5.4-mini',
      'messages': [
        {'role': 'user', 'content': contentList}
      ],
      'reasoning_effort': 'low',
      'max_completion_tokens': maxOutputTokens,
      'stream': true,
    };

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.env['API_KEY']}',
      });
      request.body = jsonEncode(payload);

      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (streamedResponse.statusCode != 200) {
        final errBody = await streamedResponse.stream.bytesToString();
        throw Exception('Stream request failed: ${streamedResponse.statusCode} $errBody');
      }

      final parser = SseEventParser();
      final decoder = utf8.decoder;
      var hasContent = false;

      final guardedStream = streamedResponse.stream
          .transform(decoder)
          .timeout(const Duration(seconds: 45));

      await for (final chunk in guardedStream) {
        for (final data in parser.addChunk(chunk)) {
          if (data == '[DONE]') {
            if (!hasContent) {
              throw const FormatException('Empty streaming response');
            }
            return;
          }

          try {
            final j = jsonDecode(data);
            final delta = j['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) {
              hasContent = true;
              yield delta;
            }
          } catch (_) {
            // ignore malformed chunk
          }
        }
      }

      for (final data in parser.flush()) {
        if (data == '[DONE]') break;
        try {
          final j = jsonDecode(data);
          final delta = j['choices']?[0]?['delta']?['content'];
          if (delta is String && delta.isNotEmpty) {
            hasContent = true;
            yield delta;
          }
        } catch (_) {}
      }

      if (!hasContent) {
        throw const FormatException('Empty streaming response');
      }
    } finally {
      client.close();
    }
  }


}
