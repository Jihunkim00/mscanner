import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import '/screens/c_map.dart'; // 경로는 실제 프로젝트에 맞게 조정
import 'package:translator/translator.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';

class CommentSection extends StatefulWidget {
  final String userGeohash;
  const CommentSection({super.key, required this.userGeohash});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _comments = [];
  List<bool> _translatedStates = [];
  List<String> _translatedTexts = [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {

    print('🔥 불러올 geohash5: ${widget.userGeohash}');

    final snapshot = await FirebaseFirestore.instance
        .collection('rag_reviews')
        .where('geohash5', isEqualTo: widget.userGeohash)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    final currentUser = FirebaseAuth.instance.currentUser;
    final filtered = snapshot.docs.where((doc) => doc['uid'] != currentUser?.uid).toList();

    print('📦 불러온 리뷰 개수 (자기 댓글 제외 후): ${filtered.length}');
    setState(() {
      _comments = filtered.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
      _translatedStates = List.filled(_comments.length, false);
      _translatedTexts = List.filled(_comments.length, '');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_comments.isEmpty) return const SizedBox();

    final local = AppLocalizations.of(context)!;

    final first = _comments.first;
    final rest = _comments.length > 1 ? _comments.sublist(1) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(local.commentSection_title, style: Theme.of(context).textTheme.titleMedium),
        _buildCard(first, 0),
        ...(_expanded
            ? rest.asMap().entries.map((entry) {
          final index = entry.key + 1;
          return _buildCard(entry.value, index);
        }).toList()
            : []),
        if (rest.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            child: Text(_expanded
                ? local.commentSection_seeLess
                : local.commentSection_seeMore),
          ),
      ],
    );
  }

  Widget _buildCard(QueryDocumentSnapshot<Map<String, dynamic>> doc, int index) {
    final data = doc.data();
    final rawTime = data['timestamp'];
    DateTime time;

    if (rawTime is Timestamp) {
      time = rawTime.toDate().toLocal(); // ✅ toLocal() 추가

    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    } else {
      time = DateTime.now();
    }

    final local = AppLocalizations.of(context)!;
    final String commentLang = data['lang'] ?? 'en';
    final String systemLang = ui.window.locale.languageCode;
    final emoji = _getFlagEmoji(commentLang);
    final ago = _formatTimeAgo(time, local);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String originalText = data['detail'] ?? local.commentSection_noContent;
    final bool needsTranslation = commentLang != systemLang;

    final bool isTranslated = _translatedStates[index];
    final String translatedText = _translatedTexts[index];

    return InkWell(
      onTap: () {
        final gps = data['gps'];
        if (gps != null && gps is GeoPoint) {
          final latitude = gps.latitude;
          final longitude = gps.longitude;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapScreen(
                latitude: latitude,
                longitude: longitude,
              ),
            ),
          );
        }
      },
      child: Card(
        color: isDark ? theme.cardColor : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$emoji ${local.commentSection_anonymous}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(ago, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Text(isTranslated ? translatedText : originalText),
              if (needsTranslation)
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent, // ← 글씨 바깥도 감지 가능
                    onTap: () async {
                      if (!isTranslated) {
                        final translator = GoogleTranslator();
                        final translation = await translator.translate(
                          originalText,
                          to: systemLang,
                        );
                        setState(() {
                          _translatedTexts[index] = translation.text;
                          _translatedStates[index] = true;
                        });
                      } else {
                        setState(() {
                          _translatedStates[index] = false;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ← 터치 영역 확대
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.transparent, // 필요 시 살짝 배경 색 넣어도 됨
                      ),
                      child: Text(
                        isTranslated
                            ? local.commentSection_original
                            : local.commentSection_translate,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }





  String _getFlagEmoji(String code) {
    const flags = {
      'en': '🇺🇸',
      'ko': '🇰🇷',
      'ja': '🇯🇵',
      'zh': '🇨🇳',
      'zh-Hans': '🇨🇳',
      'zh-Hant': '🇨🇳',
      'hi': '🇮🇳',
      'es': '🇪🇸',
      'fr': '🇫🇷',
      'vi': '🇻🇳',
      'th': '🇹🇭',
      'ar': '🇸🇦',
      'bn': '🇧🇩',
      'ru': '🇷🇺',
      'pt': '🇵🇹',
      'pt-BR': '🇧🇷',
      'ur': '🇵🇰',
      'id': '🇮🇩',
      'de': '🇩🇪',
      'mr': '🇮🇳',
      'te': '🇮🇳',
      'tr': '🇹🇷',
    };
    return flags[code] ?? '🌍';
  }

  String _formatTimeAgo(DateTime time, AppLocalizations local) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${local.timeAgo_minutes}';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ${local.timeAgo_hours}';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} ${local.timeAgo_days}';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} ${local.timeAgo_months}';
    } else {
      return '${(diff.inDays / 365).floor()} ${local.timeAgo_years}';
    }
  }
}