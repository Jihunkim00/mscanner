// /widgets/ai_food_image_button.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'package:mscanner/screens/result_screen.dart';

String buildMenuKey(String original, String translated) {
  final base = '${original.trim()}|${translated.trim()}'.toLowerCase();
  return sha1.convert(utf8.encode(base)).toString();
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