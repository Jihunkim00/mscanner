// /widgets/ai_food_image_button.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mscanner/screens/result_screen.dart';
// ⚠️ 너 프로젝트 경로에 맞게 수정
// AiSparkleIconButton 타입을 쓰기 위해 import가 필요함.
// 만약 순환 import 생기면 AiSparkleIconButton만 별도 파일로 빼는 게 깔끔함.

String buildMenuKey(String original, String translated) {
  final base = '${original.trim()}|${translated.trim()}'.toLowerCase();
  return sha1.convert(utf8.encode(base)).toString(); // doc id로 안전(40 chars)
}

class AiFoodImageButton extends StatelessWidget {
  final String menuKey;
  final Map<String, dynamic> menu; // {original, translated}
  final String? shortDesc;
  final List<String> tags;
  final String? searchedMenuDocId; // 이번 스캔에서 저장한 searched menu 문서 id
  final double size;

  const AiFoodImageButton({
    super.key,
    required this.menuKey,
    required this.menu,
    this.shortDesc,
    this.tags = const [],
    this.searchedMenuDocId,
    this.size = 80,
  });

  Future<void> _requestGenerate(BuildContext context) async {
    try {
      await _upsertMenuImageMetadata();

      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('generateMenuImage');
      await callable.call({
        'menuKey': menuKey,
        'menu': menu,
        'shortDesc': (shortDesc ?? '').trim(),
        'tags': tags,
        if (searchedMenuDocId != null) 'searchedMenuDocId': searchedMenuDocId,
      });

      await _upsertMenuImageMetadata();
    } catch (e) {
      // 너무 시끄럽지 않게 스낵바 정도
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI food image failed: $e')),
      );
    }
  }

  Future<void> _upsertMenuImageMetadata() async {
    final docRef = FirebaseFirestore.instance.collection('menu_images').doc(menuKey);
    final now = FieldValue.serverTimestamp();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final original = (menu['original'] ?? '').toString().trim();
    final translated = (menu['translated'] ?? '').toString().trim();
    final display = translated.isNotEmpty ? translated : original;

    final payload = <String, dynamic>{
      if (searchedMenuDocId != null) 'searched_menu_doc_id': searchedMenuDocId,
      'menu_key': menuKey,
      'menu_original': original,
      'menu_translated': translated,
      'menu_display': display,
      'shortDesc': (shortDesc ?? '').trim(),
      'menu_chips': tags,
      'updatedAt': now,
      if (uid != null) 'uid': uid,
    };

    final snap = await docRef.get();
    if (!snap.exists) {
      payload['createdAt'] = now;
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('menu_images').doc(menuKey);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final status = (data?['status'] ?? '').toString();
        final thumbUrl = (data?['thumb_url'] ?? '').toString();

        final isLoading = status == 'pending';
        final isReady = status == 'ready' && thumbUrl.isNotEmpty;

        if (isReady) {
          return InkWell(
            onTap: () {
              // 원하면 탭 시 full 이미지 팝업 등 가능
            },
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                thumbUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  // 썸네일 깨지면 다시 요청 버튼 제공
                  return AiSparkleIconButton(
                    isLoading: false,
                    onTap: () => _requestGenerate(context),
                    size: size,
                  );
                },
              ),
            ),
          );
        }

        // 없거나 pending이면 기존 aifood 아이콘(+스파클 로딩)
        return AiSparkleIconButton(
          isLoading: isLoading,
          onTap: isLoading ? () {} : () => _requestGenerate(context),
          size: size,
        );
      },
    );
  }
}
