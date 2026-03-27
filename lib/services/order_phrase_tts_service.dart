import 'package:flutter_tts/flutter_tts.dart';
import 'package:mscanner/models/order_phrase_models.dart';

class OrderPhraseTtsService {
  OrderPhraseTtsService._internal();

  static final OrderPhraseTtsService instance = OrderPhraseTtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _initialized = true;
  }

  Future<void> speak({
    required SupportedLanguage language,
    required String text,
  }) async {
    await _ensureInitialized();
    await _tts.setLanguage(_ttsLanguageCode(language));
    await _tts.speak(text);
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
}