import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class TutorialIndicator extends StatefulWidget {
  const TutorialIndicator({Key? key}) : super(key: key);

  @override
  _TutorialIndicatorState createState() => _TutorialIndicatorState();
}

class _TutorialIndicatorState extends State<TutorialIndicator> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _visible = !_visible);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 타이머 취소로 메모리 누수 방지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = AppLocalizations.of(context)?.tutorialMode ?? 'Tutorial Mode';

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13, // ✅ 모든 화면과 통일한 글씨 크기
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none, // Cupertino 호환성 보장
          ),
        ),
      ),
    );
  }
}
