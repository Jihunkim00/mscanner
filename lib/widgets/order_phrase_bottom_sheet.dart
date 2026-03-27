import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mscanner/models/order_phrase_models.dart';
import 'package:mscanner/services/order_phrase_service.dart';
import 'package:mscanner/services/order_phrase_tts_service.dart';

Future<void> showOrderPhraseBottomSheet({
  required BuildContext context,
  required String menuName,
  required String menuOriginal,
  required SupportedLanguage originLanguage,
  required SupportedLanguage targetLanguage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.18),
    builder: (context) => OrderPhraseBottomSheet(
      menuName: menuName,
      menuOriginal: menuOriginal,
      originLanguage: originLanguage,
      targetLanguage: targetLanguage,
    ),
  );
}

class OrderPhraseBottomSheet extends StatefulWidget {
  const OrderPhraseBottomSheet({
    super.key,
    required this.menuName,
    required this.menuOriginal,
    required this.originLanguage,
    required this.targetLanguage,
  });

  final String menuName;
  final String menuOriginal;
  final SupportedLanguage originLanguage;
  final SupportedLanguage targetLanguage;

  @override
  State<OrderPhraseBottomSheet> createState() => _OrderPhraseBottomSheetState();
}

class _OrderPhraseBottomSheetState extends State<OrderPhraseBottomSheet> {
  final OrderPhraseService _service = OrderPhraseService();
  final OrderPhraseTtsService _ttsService = OrderPhraseTtsService.instance;

  OrderScenario _scenario = OrderScenario.basicOrder;
  final Set<OrderModifier> _modifiers = <OrderModifier>{};
  final Set<AllergyType> _allergies = <AllergyType>{};

  bool _isLoading = false;
  bool _isSpeaking = false;
  String? _error;
  GenerateOrderPhraseResponse? _result;

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _generatePhrase() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _service.generate(
        GenerateOrderPhraseRequest(

          menuName: widget.menuName,
          menuOriginal: widget.menuOriginal,
          originLanguageCode: widget.originLanguage,
          targetLanguageCode: widget.targetLanguage,
          scenario: _scenario,
          modifiers: _scenario == OrderScenario.customizeOrder
              ? _modifiers.toList()
              : const <OrderModifier>[],
          allergies: _scenario == OrderScenario.allergyCheck
              ? _allergies.toList()
              : const <AllergyType>[],
        ),
      );
      if (!mounted) return;
      setState(() => _result = response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '문장 생성에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSpeak() async {
    if (_result == null) return;
    if (_isSpeaking) {
      await _ttsService.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _ttsService.speak(
      language: _result!.originLanguageCode,
      text: _result!.ttsText,
    );
    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFCFCFD);
    final cardBg = isDark ? const Color(0xFF26262A) : Colors.white;
    final summaryBg = isDark ? const Color(0xFF2C2C31) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottomInset),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '주문 문장 만들기',
                    style: TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.menuName,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 14,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('상황 선택'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OrderScenario.values
                        .map(
                          (scenario) => _ChoicePill(
                        label: scenario.labelKo,
                        selected: _scenario == scenario,
                        onTap: () => setState(() => _scenario = scenario),
                      ),
                    )
                        .toList(),
                  ),
                  if (_scenario == OrderScenario.customizeOrder) ...[
                    const SizedBox(height: 12),
                    const _SectionTitle('옵션 선택'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: OrderModifier.values
                          .map(
                            (value) => _ChoicePill(
                          label: value.labelKo,
                          selected: _modifiers.contains(value),
                          onTap: () {
                            setState(() {
                              if (_modifiers.contains(value)) {
                                _modifiers.remove(value);
                              } else {
                                _modifiers.add(value);
                              }
                            });
                          },
                        ),
                      )
                          .toList(),
                    ),
                  ],
                  if (_scenario == OrderScenario.allergyCheck) ...[
                    const SizedBox(height: 12),
                    const _SectionTitle('알레르기 선택'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AllergyType.values
                          .map(
                            (value) => _ChoicePill(
                          label: value.labelKo,
                          selected: _allergies.contains(value),
                          onTap: () {
                            setState(() {
                              if (_allergies.contains(value)) {
                                _allergies.remove(value);
                              } else {
                                _allergies.add(value);
                              }
                            });
                          },
                        ),
                      )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isLoading ? null : _generatePhrase,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(
                      '문장 생성',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 10),
              _SectionCard(
                isHighlight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('생성 결과'),
                    const SizedBox(height: 8),
                    Text(
                      _result!.localText,
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.targetText,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 13,
                        height: 1.35,
                        color: subColor,
                      ),
                    ),
                    if ((_result!.enText ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'EN: ${_result!.enText}',
                        style: TextStyle(fontSize: 12, height: 1.35, color: subColor.withOpacity(0.9)),
                      ),
                    ],
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _toggleSpeak,
                          icon: PhosphorIcon(
                            _isSpeaking ? PhosphorIcons.stop() : PhosphorIcons.speakerHigh(),
                            size: 16,
                          ),
                          label: Text(_isSpeaking ? '정지' : '듣기'),
                        ),
                        const SizedBox(width: 8),
                        _SheetActionButton(
                          onPressed: _isLoading ? null : _generatePhrase,
                          icon: PhosphorIcon(PhosphorIcons.arrowsClockwise(), size: 16),
                          label: '다시 생성',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.isHighlight = false});

  final Widget child;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isHighlight
        ? (isDark ? const Color(0xFF2C2C31) : const Color(0xFFF6F7F9))
        : (isDark ? const Color(0xFF26262A) : Colors.white);
    final borderColor =
    isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontFamily: 'SFPro', fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBg = isDark ? const Color(0xFF34343A) : const Color(0xFFF1F3F5);
    final selectedBorder = isDark ? Colors.white.withOpacity(0.16) : const Color(0xFFD1D5DB);
    final unselectedBorder = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E7EB);
    final selectedText = isDark ? Colors.white : const Color(0xFF111827);
    final unselectedText = theme.textTheme.bodyMedium?.color?.withOpacity(0.88);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? selectedBg : Colors.transparent,
          border: Border.all(
            color: selected ? selectedBorder : unselectedBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}