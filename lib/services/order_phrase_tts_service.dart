import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mscanner/models/order_phrase_models.dart';

class OrderPhraseTtsService {
  OrderPhraseTtsService._internal();

  static final OrderPhraseTtsService instance =
      OrderPhraseTtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.44);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _initialized = true;
  }

  Future<void> speak({
    required SupportedLanguage language,
    required String text,
  }) async {
    final normalized = _normalizeForTts(text, language);
    if (normalized.isEmpty) return;

    await _ensureInitialized();
    await _tts.stop();

    final locale = _ttsLanguageCode(language);
    final langResult = await _tts.setLanguage(locale);
    debugPrint('[OrderPhraseTTS] setLanguage($locale) => $langResult');

    if (language == SupportedLanguage.ja) {
      await _setPreferredJapaneseVoice();
    }

    debugPrint('[OrderPhraseTTS] speak(${language.code}) => $normalized');
    await _tts.speak(normalized);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  String _ttsLanguageCode(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.ko:
        return 'ko-KR';
      case SupportedLanguage.en:
        return 'en-US';
      case SupportedLanguage.ja:
        return 'ja-JP';
    }
  }

  String _normalizeForTts(String input, SupportedLanguage language) {
    var s = input.trim();
    if (s.isEmpty) return '';

    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'[|•·]+'), ' ');
    s = s.replaceAll(RegExp(r'\b\d{1,2}[.)]\s*'), ' ');
    s = s.replaceAll(
      RegExp(r'\b\d+\s*(원|엔|¥|\$|krw|jpy|usd)\b', caseSensitive: false),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\b\d+\b'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (language == SupportedLanguage.ja) {
      s = s.replaceAll('。 。', '。');
    }

    return s;
  }

  Future<void> _setPreferredJapaneseVoice() async {
    final dynamic voices = await _tts.getVoices;
    if (voices is! List) return;

    Map<String, String>? selected;

    for (final dynamic raw in voices) {
      if (raw is! Map) continue;

      final voice = raw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      final locale = (voice['locale'] ?? voice['language'] ?? '').toLowerCase();

      if (locale == 'ja-jp') {
        selected = voice;
        break;
      }

      if (selected == null && locale.startsWith('ja')) {
        selected = voice;
      }
    }

    debugPrint('[OrderPhraseTTS] selected ja voice: $selected');

    if (selected != null) {
      await _tts.setVoice(selected);
    }
  }
}
