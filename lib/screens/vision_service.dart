import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '/helpers/settings_helper.dart';

class VisionService {
  // 기존: static Future<String> analyzeImage(File imageFile) async {
  static Future<String> analyzeImage(
      File imageFile, {
        String? promptContext,
      }) async {

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final presetId = await SettingsHelper.getPreset();
      final question = await SettingsHelper.getQuestionByPreset(presetId);

      // 1) RAG + 프리셋 질문을 하나로 합친 텍스트
      final Map<String, String> ragPrefixMap = {
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


// 2) contentList에 mergedPrompt(텍스트)와 이미지(blocl)만 담습니다.
      final langCode = await SettingsHelper.getLanguageCode();

// ragPrefixMap에서 해당 언어 템플릿 가져와서 context, question 대체
      final template = ragPrefixMap[langCode] ?? ragPrefixMap['en']!;
      final mergedPrompt = template
          .replaceAll('{promptContext}', promptContext ?? '')
          .replaceAll('{question}', question ?? '');

      final List<Map<String, dynamic>> contentList = [
        {
          'type': 'text',
          'text': mergedPrompt,
        },
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
      ];

// 3) messages 배열에는 user 메시지 하나만. content에 contentList 배열을 넘겨야 합니다.
      final payload = {
        'model': 'gpt-4.1-mini',
        'messages': [
          {
            'role': 'user',
            'content': contentList,
          }
        ],
        'max_tokens': 1000,
      };





      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['API_KEY']}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final assistantMessages = json['choices']
            .where((choice) => choice['message']['role'] == 'assistant')
            .map((choice) => choice['message']['content'])
            .join('\n');
        return assistantMessages;
      } else {
        throw Exception('GPT 응답 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Vision 분석 중 오류: $e');
    }
  }
}
