import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mscanner/models/order_phrase_models.dart';
import 'package:mscanner/services/order_phrase_service.dart';
import 'package:mscanner/services/order_phrase_tts_service.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

Future<void> showOrderPhraseBottomSheet({
  required BuildContext context,
  required String menuName,
  required String menuOriginal,
  String? menuOriginalReading,
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
      menuOriginalReading: menuOriginalReading,
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
    this.menuOriginalReading,
    required this.originLanguage,
    required this.targetLanguage,
  });

  final String menuName;
  final String menuOriginal;
  final String? menuOriginalReading;
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

  String _scenarioLabel(AppLocalizations l10n, OrderScenario scenario) {
    switch (scenario) {
      case OrderScenario.basicOrder:
        return l10n.tts_scenarioBasicOrder;
      case OrderScenario.customizeOrder:
        return l10n.tts_scenarioCustomizeOrder;
      case OrderScenario.allergyCheck:
        return l10n.tts_scenarioAllergyCheck;
      case OrderScenario.recommendationAsk:
        return l10n.tts_scenarioRecommendationAsk;
    }
  }

  String _modifierLabel(AppLocalizations l10n, OrderModifier modifier) {
    switch (modifier) {
      case OrderModifier.noCilantro:
        return l10n.tts_modifierNoCilantro;
      case OrderModifier.noOnion:
        return l10n.tts_modifierNoOnion;
      case OrderModifier.lessSpicy:
        return l10n.tts_modifierLessSpicy;
      case OrderModifier.lessSalty:
        return l10n.tts_modifierLessSalty;
    }
  }

  String _allergyLabel(AppLocalizations l10n, AllergyType allergy) {
    switch (allergy) {
      case AllergyType.peanut:
        return l10n.tts_allergyPeanut;
      case AllergyType.milk:
        return l10n.tts_allergyMilk;
      case AllergyType.shrimp:
        return l10n.tts_allergyShrimp;
      case AllergyType.egg:
        return l10n.tts_allergyEgg;
    }
  }

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
          menuOriginalReading: widget.menuOriginalReading,
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
      setState(() => _error = AppLocalizations.of(context)!.tts_generationFailed);
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

    try {
      debugPrint('[OrderPhraseBottomSheet] origin=${_result!.originLanguageCode.code}');
      debugPrint('[OrderPhraseBottomSheet] ttsText=${_result!.ttsText}');

      await _ttsService.speak(
        language: _result!.originLanguageCode,
        text: _result!.ttsText,
      );
    } catch (e, st) {
      debugPrint('[OrderPhraseBottomSheet] speak error: $e');
      debugPrint('$st');
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1B1F) : const Color(0xFFF7F8FA);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);
    final subColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottomInset),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 26, offset: const Offset(0, 12)),
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
                  Text(
                  l10n.tts_orderPhraseTitle,
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
                  _SectionTitle(l10n.tts_scenarioSectionTitle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OrderScenario.values
                        .map(
                          (scenario) => _ChoicePill(
                            label: _scenarioLabel(l10n, scenario),
                        selected: _scenario == scenario,
                        onTap: () => setState(() => _scenario = scenario),
                      ),
                    )
                        .toList(),
                  ),
                  if (_scenario == OrderScenario.customizeOrder) ...[
                    const SizedBox(height: 12),
                    _SectionTitle(l10n.tts_modifierSectionTitle),
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
                    _SectionTitle(l10n.tts_allergySectionTitle),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AllergyType.values
                          .map(
                            (value) => _ChoicePill(
                              label: _allergyLabel(l10n, value),
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
                    color: isDark ? const Color(0xFF2A2D33) : const Color(0xFFF3F4F6),
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
                      l10n.tts_generatePhraseButton,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
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
    _SectionTitle(l10n.tts_resultSectionTitle),
                    const SizedBox(height: 8),
                    Text(
                      _result!.ttsText,
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
                    Row(
                      children: [
                        _SheetActionButton(
                          onPressed: _toggleSpeak,
                          icon: PhosphorIcon(
                            _isSpeaking ? PhosphorIcons.stop() : PhosphorIcons.speakerHigh(),
                            size: 16,
                          ),
    label: _isSpeaking ? l10n.tts_stop : l10n.tts_listen,
                        ),
                        const SizedBox(width: 8),
                        _SheetActionButton(
                          onPressed: _isLoading ? null : _generatePhrase,
                          icon: PhosphorIcon(PhosphorIcons.arrowsClockwise(), size: 16),
    label: l10n.tts_regenerate,
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