import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '/helpers/settings_helper.dart';

class VisionService {
  // Keep the released callable as the default until V2 is explicitly enabled.
  static const bool _useVisionV2 = false;
  static const bool _useRag = false;

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  static String _resolvePromptContext(String? promptContext) {
    if (!_useRag) return '';
    final safe = (promptContext ?? '').trim();
    return safe.length > 3000 ? safe.substring(0, 3000) : safe;
  }

  static String _resolveScanMode(int maxOutputTokens) {
    return maxOutputTokens >= 9000 ? 'multi' : 'single';
  }

  static Future<String> _callAnalyzeVision({
    required String imageBase64,
    required String prompt,
    required int maxOutputTokens,
    required String scanMode,
    required String responseMode,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      debugPrint(
        '🚀 [Functions] analyzeVision call '
        'scanMode=$scanMode responseMode=$responseMode '
        'maxTokens=$maxOutputTokens imageBase64Len=${imageBase64.length}',
      );

      final callable = _functions.httpsCallable(
        'analyzeVision',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

      final result = await callable.call({
        'imageBase64': imageBase64,
        'prompt': prompt,
        'maxOutputTokens': maxOutputTokens,
        'scanMode': scanMode,
        'responseMode': responseMode,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final text = data['result']?.toString() ?? '';

      debugPrint(
        '✅ [Functions] analyzeVision success '
        'model=${data['model']} scanMode=${data['scanMode']} '
        'responseMode=${data['responseMode']} '
        'maxOutputTokens=${data['maxOutputTokens']} '
        'textLen=${text.trim().length}',
      );

      if (text.trim().isEmpty) {
        throw const FormatException('Empty Functions response');
      }

      return text;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ [Functions] analyzeVision failed '
        'code=${e.code} message=${e.message} details=${e.details}',
      );
      rethrow;
    } catch (e) {
      debugPrint('❌ [Functions] analyzeVision unknown error=$e');
      rethrow;
    }
  }

  static Future<String> _callAnalyzeVisionV2({
    required String imageBase64,
    required String prompt,
    required int maxOutputTokens,
    required String scanMode,
    required String responseMode,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      debugPrint(
        '[Functions] analyzeVisionV2 call '
        'scanMode=$scanMode responseMode=$responseMode '
        'maxTokens=$maxOutputTokens imageBase64Len=${imageBase64.length}',
      );

      final callable = _functions.httpsCallable(
        'analyzeVisionV2',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );
      final result = await callable.call({
        'imageBase64': imageBase64,
        'prompt': prompt,
        'maxOutputTokens': maxOutputTokens,
        'scanMode': scanMode,
        'responseMode': responseMode,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final meta = data['meta'] is Map
          ? Map<String, dynamic>.from(data['meta'] as Map)
          : const <String, dynamic>{};
      final vision = data['vision'];

      debugPrint(
        '[Functions] analyzeVisionV2 success '
        'model=${meta['model'] ?? data['model']} '
        'scanMode=${meta['scanMode'] ?? data['scanMode']} '
        'responseMode=${meta['responseMode'] ?? data['responseMode']} '
        'latencyMs=${meta['latencyMs']}',
      );

      if (vision is Map) {
        return jsonEncode(Map<String, dynamic>.from(vision));
      }

      final legacyResult = data['result']?.toString() ?? '';
      if (legacyResult.trim().isEmpty) {
        throw const FormatException('Empty Vision V2 response');
      }
      return legacyResult;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[Functions] analyzeVisionV2 failed '
        'code=${e.code} message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[Functions] analyzeVisionV2 unknown error=$e');
      rethrow;
    }
  }

  static Map<String, String> _fullPromptTemplates() {
    return {
      'ko': '''[장소 메모]
{promptContext}

이 이미지가 음식 메뉴나 음식 사진이라면, 내용을 번역하고 설명 및 추천해 주세요.
음식과 관련 없어 보이면 그렇게 말씀해 주세요.

{question}
''',
      'en': '''[Location Memo]
{promptContext}

If this image is a food menu or food photo, please translate, describe, and recommend it.
If it doesn’t seem food-related, just say so.

{question}
''',
      'ja': '''[Location Memo]
{promptContext}

この画像が料理のメニューや料理の写真であれば、翻訳して説明し、推薦してください。
食べ物に関係がないようであれば、そのように言ってください。

{question}
''',
      'zh': '''[Location Memo]
{promptContext}

如果此图像是食物菜单或食物照片，请翻译、描述并推荐。
如果看起来与食物无关，请指出。

{question}
''',
      'zh-Hans': '''[Location Memo]
{promptContext}

如果此图像是食物菜单或食物照片，请翻译、描述并推荐。
如果看起来与食物无关，请指出。

{question}
''',
      'zh-Hant': '''[Location Memo]
{promptContext}

如果此圖像是食物菜單或食物照片，請翻譯、描述並推薦。
如果看起來與食物無關，請說明。

{question}
''',
      'hi': '''[Location Memo]
{promptContext}

यदि यह चित्र खाद्य मेनू या खाद्य फ़ोटो है, तो कृपया इसका अनुवाद करें, वर्णन करें और अनुशंसा करें।
यदि यह खाद्य से संबंधित नहीं लगता है, तो बस बता दें।

{question}
''',
      'es': '''[Location Memo]
{promptContext}

Si esta imagen es un menú o una foto de comida, por favor tradúcelo, descríbelo y haz una recomendación.
Si no parece relacionado con comida, simplemente dilo.

{question}
''',
      'fr': '''[Location Memo]
{promptContext}

Si cette image est un menu ou une photo de nourriture, veuillez la traduire, la décrire et faire une recommandation.
Si cela ne semble pas lié à la nourriture, dites-le simplement.

{question}
''',
      'vi': '''[Location Memo]
{promptContext}

Nếu hình ảnh này là thực đơn hoặc ảnh món ăn, vui lòng dịch, mô tả và gợi ý.
Nếu không liên quan đến thực phẩm, chỉ cần nói vậy.

{question}
''',
      'th': '''[Location Memo]
{promptContext}

หากภาพนี้เป็นเมนูอาหารหรือภาพอาหาร โปรดแปล อธิบาย และแนะนำ
หากดูไม่เกี่ยวกับอาหาร โปรดบอกด้วย

{question}
''',
      'ar': '''[Location Memo]
{promptContext}

إذا كانت هذه الصورة قائمة طعام أو صورة طعام، يرجى ترجمتها ووصفها وتقديم التوصيات.
إذا لم تكن لها علاقة بالطعام، فقط قل ذلك.

{question}
''',
      'bn': '''[Location Memo]
{promptContext}

এই ছবিটি যদি খাবারের মেনু বা খাবারের ছবি হয়, অনুগ্রহ করে এটি অনুবাদ করুন, বর্ণনা করুন এবং সুপারিশ করুন।
যদি এটি খাবারের সাথে সম্পর্কিত না হয়, তাহলে শুধু বলুন।

{question}
''',
      'ru': '''[Location Memo]
{promptContext}

Если это изображение меню или фотографии еды, пожалуйста, переведите, опишите и дайте рекомендации.
Если это не связано с едой, просто скажите об этом.

{question}
''',
      'pt': '''[Location Memo]
{promptContext}

Se esta imagem for um menu de comida ou foto de comida, por favor, traduza, descreva e recomende.
Se não parecer relacionado à comida, apenas diga isso.

{question}
''',
      'pt-BR': '''[Location Memo]
{promptContext}

Se esta imagem for um cardápio ou uma foto de comida, por favor, traduza, descreva e recomende.
Se não parecer relacionado à comida, apenas diga isso.

{question}
''',
      'ur': '''[Location Memo]
{promptContext}

اگر یہ تصویر کھانے کے مینو یا کھانے کی تصویر ہے تو براہ کرم اس کا ترجمہ کریں، وضاحت کریں اور سفارش کریں۔
اگر یہ کھانے سے متعلق نہیں لگتا تو صرف اتنا کہہ دیں۔

{question}
''',
      'id': '''[Location Memo]
{promptContext}

Jika gambar ini adalah menu makanan atau foto makanan, silakan terjemahkan, jelaskan, dan rekomendasikan.
Jika tidak tampak terkait dengan makanan, cukup katakan saja.

{question}
''',
      'de': '''[Location Memo]
{promptContext}

Wenn dieses Bild ein Speisekarte oder Essensfoto ist, bitte übersetzen, beschreiben und empfehlen.
Wenn es nicht mit Essen zu tun hat, sagen Sie es einfach.

{question}
''',
      'mr': '''[Location Memo]
{promptContext}

हे चित्र अन्न मेनू किंवा अन्नाचे छायाचित्र असल्यास, कृपया त्याचे भाषांतर करा, वर्णन करा आणि शिफारस करा.
जर ते अन्नाशी संबंधित वाटत नसेल तर फक्त तसेच सांगा.

{question}
''',
      'te': '''[Location Memo]
{promptContext}

ఈ చిత్రం ఆహార మెనూ లేదా ఆహార ఫోటో అయితే, దయచేసి అనువదించండి, వివరించండి మరియు సిఫార్సు చేయండి.
అది ఆహారంతో సంబంధం లేకపోతే, కేవలం అలా చెప్పండి.

{question}
''',
      'tr': '''[Location Memo]
{promptContext}

Bu resim bir yemek menüsü veya yemek fotoğrafıysa, lütfen çevirin, açıklayın ve önerin.
Yemekle ilgili görünmüyorsa, sadece belirtin.

{question}
''',
    };
  }

  static Map<String, String> _streamPromptTemplates() {
    return {
      'ko': '''[장소 메모]
{promptContext}

이 이미지가 음식 메뉴나 음식 사진이라면, 내용을 번역하고 설명 및 추천해 주세요.
음식과 관련 없어 보이면 그렇게 말씀해 주세요.

{question}
''',
      'en': '''[Location Memo]
{promptContext}

If this image is a food menu or food photo, please translate, describe, and recommend it.
If it doesn’t seem food-related, just say so.

{question}
''',
      'ja': '''[Location Memo]
{promptContext}

この画像が料理のメニューや料理の写真であれば、翻訳して説明し、推薦してください。
食べ物に関係がないようであれば、そのように言ってください。

{question}
''',
      'zh': '''[Location Memo]
{promptContext}

如果此图像是食物菜单或食物照片，请翻译、描述并推荐。
如果看起来与食物无关，请指出。

{question}
''',
    };
  }

  static Future<String> _buildPrompt({
    required String outputProtocol,
    required String? promptContext,
    required bool streamMode,
  }) async {
    final presetId = await SettingsHelper.getPreset();
    final question = await SettingsHelper.getQuestionByPreset(presetId);
    final langCode = await SettingsHelper.getLanguageCode();

    final templates =
        streamMode ? _streamPromptTemplates() : _fullPromptTemplates();
    final template = templates[langCode] ?? templates['en']!;

    final mergedPrompt = template
        .replaceAll('{promptContext}', _resolvePromptContext(promptContext))
        .replaceAll('{question}', question);

    return '$outputProtocol\n$mergedPrompt';
  }

  static Future<String> analyzeImage(
    File imageFile, {
    String? promptContext,
    int maxOutputTokens = 3000,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final kb = bytes.length / 1024;
      debugPrint(
          '🗜️ [Vision] bytes=${kb.toStringAsFixed(1)}KB file=${imageFile.path}');

      final tEncode0 = DateTime.now();
      final base64Image = base64Encode(bytes);
      debugPrint(
          '⏱️ [Vision] base64Encode ${DateTime.now().difference(tEncode0).inMilliseconds}ms');

      const outputProtocol = '''[OUTPUT PROTOCOL]
Output exactly ONE JSON object.
- No RECOMMEND line
- No markdown
- No code fences
- No extra text
- Keep the JSON key order as: isMenu, userMessage, outputLanguage, selectedFoodStyle, selectedFoodStyleLabel, foodStyleApplied, foodStyleSummary, place, recommended, optional fullMenu
''';

      final mergedPromptWithProtocol = await _buildPrompt(
        outputProtocol: outputProtocol,
        promptContext: promptContext,
        streamMode: false,
      );

      final scanMode = _resolveScanMode(maxOutputTokens);
      final tReq0 = DateTime.now();

      debugPrint(
        '🚀 [Vision] functions request start ${tReq0.toIso8601String()} '
        'maxTokens=$maxOutputTokens model=gpt-5.6-luna '
        'callable=${_useVisionV2 ? 'analyzeVisionV2' : 'analyzeVision'} '
        'scanMode=$scanMode rag=$_useRag',
      );

      final text = await (_useVisionV2
          ? _callAnalyzeVisionV2(
              imageBase64: base64Image,
              prompt: mergedPromptWithProtocol,
              maxOutputTokens: maxOutputTokens,
              scanMode: scanMode,
              responseMode: 'normal',
            )
          : _callAnalyzeVision(
              imageBase64: base64Image,
              prompt: mergedPromptWithProtocol,
              maxOutputTokens: maxOutputTokens,
              scanMode: scanMode,
              responseMode: 'normal',
            ));

      final reqMs = DateTime.now().difference(tReq0).inMilliseconds;
      debugPrint('⏱️ [Vision] functions response in ${reqMs}ms');
      debugPrint('🧾 [Vision] contentLen=${text.trim().length}');

      return text;
    } catch (e) {
      throw Exception('Vision 분석 중 오류: $e');
    }
  }

  /// 기존 LoadingScreen 구조 유지를 위해 [Stream] 형태는 유지합니다.
  /// 단, Firebase callable은 SSE streaming이 아니므로 최종 결과를 한 번 받아 yield 합니다.
  static Stream<String> analyzeImageStream(
    File imageFile, {
    String? promptContext,
    int maxOutputTokens = 3000,
  }) async* {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      const outputProtocol = '''[OUTPUT PROTOCOL]
Output exactly ONE JSON object using the existing app schema.
- No RECOMMEND line
- No markdown
- No code fences
- No extra text
- Keep the JSON key order as: isMenu, userMessage, outputLanguage, selectedFoodStyle, selectedFoodStyleLabel, foodStyleApplied, foodStyleSummary, place, recommended, optional fullMenu
''';

      final mergedPromptWithProtocol = await _buildPrompt(
        outputProtocol: outputProtocol,
        promptContext: promptContext,
        streamMode: true,
      );

      final scanMode = _resolveScanMode(maxOutputTokens);
      final tReq0 = DateTime.now();

      debugPrint(
        '🚀 [VisionStream] functions request start ${tReq0.toIso8601String()} '
        'maxTokens=$maxOutputTokens model=gpt-5.6-luna '
        'callable=${_useVisionV2 ? 'analyzeVisionV2' : 'analyzeVision'} '
        'scanMode=$scanMode rag=$_useRag',
      );

      final text = await (_useVisionV2
          ? _callAnalyzeVisionV2(
              imageBase64: base64Image,
              prompt: mergedPromptWithProtocol,
              maxOutputTokens: maxOutputTokens,
              scanMode: scanMode,
              responseMode: 'stream',
            )
          : _callAnalyzeVision(
              imageBase64: base64Image,
              prompt: mergedPromptWithProtocol,
              maxOutputTokens: maxOutputTokens,
              scanMode: scanMode,
              responseMode: 'stream',
            ));

      final reqMs = DateTime.now().difference(tReq0).inMilliseconds;
      debugPrint('⏱️ [VisionStream] functions response in ${reqMs}ms');
      debugPrint('🧾 [VisionStream] contentLen=${text.trim().length}');

      yield text;
    } catch (e) {
      throw Exception('Vision streaming 분석 중 오류: $e');
    }
  }
}
