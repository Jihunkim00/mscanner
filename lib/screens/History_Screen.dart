import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'map_screen.dart';
import 'favorite_list_screen.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isDarkMode = false;
  String _currentSegment = 'Saved';

  @override
  void initState() {
    super.initState();
    _checkDarkMode();
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
          onValueChanged: (String? value) {
            setState(() {
              _currentSegment = value ?? 'Saved';
            });
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
