import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'map_screen.dart';
import 'favorite_list_screen.dart';
import '/screens/log_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _currentSegment = 'Saved';
  bool _sentHistoryOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_sentHistoryOpen) {
        _sentHistoryOpen = true;
        await LogService().logHistoryOpen(); // ⑨ 이력 화면 진입
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: HistoryViewSwitcher(
              value: _currentSegment,
              onChanged: (String? value) async {
                setState(() {
                  _currentSegment = value ?? 'Saved';
                });

                if (_currentSegment == 'Map') {
                  await LogService()
                      .logMapOpen(from: 'history'); // ⑪ 지도 버튼(탭) 누름
                } else if (_currentSegment == 'Saved') {
                  // 필요하면 여기서도 다시 기록할 수 있지만, 기본은 최초 1회만 기록 권장
                  // if (!_sentHistoryOpen) { _sentHistoryOpen = true; await LogService().logHistoryOpen(); }
                }
              },
            ),
          ),
          Expanded(
            child: _currentSegment == 'Saved'
                ? const FavoriteListScreen()
                : const MapScreen(),
          ),
        ]),
      ),
    );
  }
}

class HistoryViewSwitcher extends StatelessWidget {
  const HistoryViewSwitcher(
      {super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: value,
        backgroundColor: colors.subtleSurface,
        thumbColor: colors.primary,
        onValueChanged: onChanged,
        children: {
          for (final segment in {'Saved': l10n.save, 'Map': l10n.map}.entries)
            segment.key: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                segment.value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: value == segment.key
                          ? colors.onPrimary
                          : colors.secondaryText,
                    ),
              ),
            ),
        },
      ),
    );
  }
}
