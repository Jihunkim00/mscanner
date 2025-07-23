import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GPTService {
  // GPT-4 API 호출 함수
  Future<String> getGPTResponse(BuildContext context, String countryCode) async {
    final apiKey = dotenv.env['API_KEY'];  // dotenv를 통해 API 키를 가져옴
    Locale systemLocale = Localizations.localeOf(context);  // 시스템 언어 Locale 가져옴
    String systemLanguageCode = systemLocale.languageCode;  // 시스템 언어 코드를 가져옴

    // 프롬프트에 시스템 언어 코드를 명시적으로 추가
    final prompt = "Provide today's travel information for the following country code ($countryCode) in $systemLanguageCode, in under 50 characters.";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),  // 올바른 엔드포인트 사용
      headers: {
        'Authorization': 'Bearer $apiKey',  // API 키를 Authorization 헤더에 포함
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": 'gpt-4o-mini',  // 사용하고자 하는 모델
        "messages": [
          {
            "role": "system",  // 시스템 역할
            "content": "You are a helpful assistant that provides concise information."
          },
          {
            "role": "user",  // 사용자 역할, 여기에 사용자 프롬프트 추가
            "content": prompt  // 명확한 언어 정보가 포함된 프롬프트
          }
        ],
        "max_tokens": 50,
        "temperature": 0.7,
      }),
    );

    // 응답 상태 코드와 메시지 확인
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['choices'][0]['message']['content'].trim();
    } else {
      print('Error: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to load GPT response');
    }
  }
}
