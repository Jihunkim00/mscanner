import 'package:flutter/material.dart';

/// 당신의 프로젝트 스타일에 맞춰 약간의 변수/테마만 손보면 바로 사용 가능합니다.
/// 사용처 예) Setting_Screen에서 기존 "엔진" 선택 항목을 탭하면 이 BottomSheet를 띄우세요.
///
/// showModalBottomSheet(
///   context: context,
///   showDragHandle: true,
///   builder: (_) => EngineSelectionSheet(
///     isPremium: userIsPremium,
///     currentEngineId: currentEngineId, // 'gpt-4.1-mini' | 'gpt-5'
///     onSelect: (engineId) async {
///       // vision_service 연동: 아래 helper를 참고해 VisionService에 반영
///       await onChangeEngine(engineId);
///     },
///   ),
/// );
///
/// currentEngineId는 기본값으로 'gpt-4.1-mini'를 권장합니다.

class EngineSelectionSheet extends StatelessWidget {
  const EngineSelectionSheet({
    super.key,
    required this.isPremium,
    required this.currentEngineId,
    required this.onSelect,
  });

  /// 프리미엄 구독 여부
  final bool isPremium;

  /// 현재 설정된 엔진 ID: 'gpt-4.1-mini' | 'gpt-5-mini'
  final String currentEngineId;

  /// 사용자가 선택했을 때 호출됩니다. 비동기 저장 및 vision_service 반영을 여기서 처리하세요.
  final Future<void> Function(String engineId) onSelect;

  static const _engines = [
    _EngineOption(
      id: 'gpt-4.1-mini',
      title: 'GPT‑4.1‑mini',
      subtitle: '기본 • 빠르고 저렴함',
      premiumOnly: false,
    ),
    _EngineOption(
      id: 'gpt-5-mini',
      title: 'GPT‑5',
      subtitle: '고정확도 • Vision 강화',
      premiumOnly: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                '엔진 선택',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ..._engines.map((e) => _EngineTile(
              option: e,
              selected: currentEngineId == e.id,
              isPremium: isPremium,
              onTap: () async {
                if (e.premiumOnly && !isPremium) return; // 비프리미엄은 차단
                if (currentEngineId == e.id) return; // 동일 선택 방지
                await onSelect(e.id);
                // 닫기
                if (context.mounted) Navigator.of(context).pop();
              },
            )),
            const SizedBox(height: 4),
            const _HintRow(),
          ],
        ),
      ),
    );
  }
}

class _EngineTile extends StatelessWidget {
  const _EngineTile({
    required this.option,
    required this.selected,
    required this.isPremium,
    required this.onTap,
  });

  final _EngineOption option;
  final bool selected;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = option.premiumOnly && !isPremium;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: disabled ? theme.disabledColor : null,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: disabled ? theme.disabledColor : theme.textTheme.bodySmall?.color?.withOpacity(0.7),
    );

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Radio<String>(
              value: option.id,
              groupValue: selected ? option.id : null,
              onChanged: disabled
                  ? null
                  : (_) {
                onTap();
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(option.title, style: titleStyle),
                      ),
                      if (option.premiumOnly)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _PremiumBadge(disabled: disabled),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(option.subtitle, style: subtitleStyle),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, color: disabled ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.disabled});
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = disabled ? theme.disabledColor.withOpacity(0.12) : theme.colorScheme.primary.withOpacity(0.12);
    final fg = disabled ? theme.disabledColor : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: fg.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 14, color: fg),
          const SizedBox(width: 4),
          Text('Premium', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'GPT‑5는 프리미엄 전용이며 Vision 서비스와 연동되어 스캔 품질이 향상됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineOption {
  const _EngineOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.premiumOnly,
  });
  final String id; // 'gpt-4.1-mini' | 'gpt-5'
  final String title;
  final String subtitle;
  final bool premiumOnly;
}

/// ---------------------------
/// vision_service 연동 helper 예시
/// ---------------------------
///
/// 아래 헬퍼는 프로젝트의 vision_service.dart에 맞게만 살짝 수정해 넣어주세요.
/// 예시는 VisionService의 싱글톤 또는 Provider 인스턴스를 받아서
/// 엔진 ID를 설정하고, 필요하면 영속 저장(SharedPreferences / Firestore)에 반영합니다.

/// 예시 인터페이스 (당신의 /mnt/data/vision_service.dart에 맞게 업데이트 필요)
abstract class VisionService {
  Future<void> setEngine(String engineId); // 'gpt-4.1-mini' | 'gpt-5'
  String get currentEngineId;
}

/// 실제 프로젝트에선 DI/Provider를 통해 VisionService를 주입하세요.
Future<void> onChangeEngine(String engineId, {required VisionService service, Future<void> Function(String id)? persist}) async {
  await service.setEngine(engineId);
  if (persist != null) {
    await persist(engineId); // 예: SharedPreferences('engineId') 저장 또는 Firestore 사용자 설정 문서 업데이트
  }
}
