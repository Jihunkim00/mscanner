// /widgets/ai_food_image_button.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/screens/result_screen.dart';

String buildMenuKey(String original, String translated) {
  final base = '${original.trim()}|${translated.trim()}'.toLowerCase();
  return sha1.convert(utf8.encode(base)).toString();
}

String _normalizeMenuKeyword(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

void _addMenuKeywordVariants(Set<String> out, String value) {
  final normalized = _normalizeMenuKeyword(value);
  if (normalized.isEmpty) return;

  void addOne(String v) {
    final s = v.trim();
    if (s.length >= 2) {
      out.add(s);
    }
  }

  addOne(normalized);
  addOne(normalized.replaceAll(' ', ''));

  final parts = normalized
      .split(RegExp(r'[\s\-/(),._]+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 2)
      .toSet();

  for (final part in parts) {
    addOne(part);

    // 자동완성용 prefix 저장
    final maxPrefix = part.length > 10 ? 10 : part.length;
    for (int i = 2; i <= maxPrefix; i++) {
      addOne(part.substring(0, i));
    }
  }
}

List<String> buildMenuSearchKeywords({
  required String display,
  required String original,
  required String translated,
  List<String> chips = const [],
}) {
  final out = <String>{};

  _addMenuKeywordVariants(out, display);
  _addMenuKeywordVariants(out, original);
  _addMenuKeywordVariants(out, translated);

  for (final chip in chips) {
    _addMenuKeywordVariants(out, chip);
  }

  return out.toList();
}


class AiFoodImageButton extends StatefulWidget {
  final String menuKey;
  final Map<String, dynamic> menu; // {original, translated}
  final String? shortDesc;
  final List<String> tags;
  final String? searchedMenuDocId;
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

  @override
  State<AiFoodImageButton> createState() => _AiFoodImageButtonState();
}

class _AiFoodImageButtonState extends State<AiFoodImageButton> {
  bool _localLoading = false;

  Future<void> _requestGenerate() async {
    if (_localLoading) return;

    setState(() => _localLoading = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('generateMenuImage');

      final menuOriginal = (widget.menu['original'] ?? '').toString().trim();
      final menuTranslated = (widget.menu['translated'] ?? '').toString().trim();
      final menuDisplay = menuTranslated.isNotEmpty ? menuTranslated : menuOriginal;
      final user = FirebaseAuth.instance.currentUser;

      final menuDocRef = FirebaseFirestore.instance
          .collection('menu_images')
          .doc(widget.menuKey);
      final existingDoc = await menuDocRef.get();

      await menuDocRef.set({
        'searched_menu_doc_id': widget.searchedMenuDocId,
        'menu_key': widget.menuKey,
        'menu_original': menuOriginal,
        'menu_translated': menuTranslated,
        'menu_display': menuDisplay,
        'shortDesc': (widget.shortDesc ?? '').trim(),
        'menu_chips': widget.tags,
        'menu_search_keywords': buildMenuSearchKeywords(
          display: menuDisplay,
          original: menuOriginal,
          translated: menuTranslated,
          chips: widget.tags,
        ),
        if (user != null) 'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existingDoc.exists || existingDoc.data()?['createdAt'] == null)
          'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));


      await callable.call({
        'menuKey': widget.menuKey,
        'menu': widget.menu,
        'shortDesc': (widget.shortDesc ?? '').trim(),
        'tags': widget.tags,
        if (widget.searchedMenuDocId != null)
          'searchedMenuDocId': widget.searchedMenuDocId,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _localLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI food image failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef =
    FirebaseFirestore.instance.collection('menu_images').doc(widget.menuKey);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final status = (data?['status'] ?? '').toString();
        final thumbUrl = (data?['thumb_url'] ?? '').toString();

        final isReady = status == 'ready' && thumbUrl.isNotEmpty;
        final isLoading = _localLoading || status == 'pending';

        if ((_localLoading && status == 'pending') || isReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _localLoading) {
              setState(() => _localLoading = false);
            }
          });
        }

        if (isReady) {
          return InkWell(
            onTap: () {
              // 필요하면 여기서 full 이미지 팝업
            },
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                thumbUrl,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return AiSparkleIconButton(
                    isLoading: isLoading,
                    onTap: isLoading ? () {} : _requestGenerate,
                    size: widget.size,
                  );
                },
              ),
            ),
          );
        }

        return AiSparkleIconButton(
          isLoading: isLoading,
          onTap: isLoading ? () {} : _requestGenerate,
          size: widget.size,
        );
      },
    );
  }
}