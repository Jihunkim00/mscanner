import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'map_screen.dart';
import 'favorite_list_screen.dart';
import '/screens/log_service.dart';


class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isDarkMode = false;
  String _currentSegment = 'Saved';
  bool _sentHistoryOpen = false;


  @override
  void initState() {
    super.initState();
    _checkDarkMode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_sentHistoryOpen) {
        _sentHistoryOpen = true;
        await LogService().logHistoryOpen(); // ⑨ 이력 화면 진입
      }
    });

  }

  Future<void> _checkDarkMode() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    setState(() {
      _isDarkMode = savedThemeMode == AdaptiveThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
    _isDarkMode ? Colors.black : const Color(0xFFEFEFF4);
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;

    return CupertinoPageScaffold(
      // 최상위 배경색
      backgroundColor: backgroundColor,

      navigationBar: CupertinoNavigationBar(
        // 네비게이션 바 배경색
        backgroundColor: backgroundColor,
        // 기본 구분선 제거
        border: null,
        leading: SizedBox.shrink(),
        middle: CupertinoSlidingSegmentedControl<String>(
          padding: EdgeInsets.only(top: Platform.isIOS ? 0.0 : 0.0),
          backgroundColor: CupertinoColors.systemGrey5,
          thumbColor: CupertinoColors.systemGrey,
          groupValue: _currentSegment,
          onValueChanged: (String? value) async {
            setState(() {
              _currentSegment = value ?? 'Saved';
            });

            if (_currentSegment == 'Map') {
              await LogService().logMapOpen(from: 'history'); // ⑪ 지도 버튼(탭) 누름
            } else if (_currentSegment == 'Saved') {
              // 필요하면 여기서도 다시 기록할 수 있지만, 기본은 최초 1회만 기록 권장
              // if (!_sentHistoryOpen) { _sentHistoryOpen = true; await LogService().logHistoryOpen(); }
            }
          },
          children: {
            'Saved': Text(
              AppLocalizations.of(context)!.save,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            'Map': Text(
              AppLocalizations.of(context)!.map,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
          },
        ),
      ),

      child: _currentSegment == 'Saved'
          ? FavoriteListScreen()
          : MapScreen(),
    );
  }
}
