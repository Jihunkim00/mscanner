
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import '/screens/log_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';


/// ===== 상위 통화 & 국가→통화 매핑(요약) =====
const Set<String> kTopCurrencies = {
  'USD','EUR','JPY','GBP','AUD','CAD','CHF','CNY','HKD','SGD',
  'INR','KRW','TWD','THB','MYR','IDR','VND','PHP','NZD','SEK',
  'NOK','DKK','PLN','CZK','HUF','TRY','SAR','AED','QAR','KWD',
  'BHD','OMR','RUB','ZAR','BRL','MXN','ARS','CLP','COP','PEN',
  'BOB','UYU','ILS','EGP','NGN','KES','MAD','TND','RON','BGN',
  'RSD','UAH'
};

const Map<String, String> kCountryToCurrency = {
  // 북미
  'US':'USD','CA':'CAD','MX':'MXN',
  // 유럽(유로권)
  'AT':'EUR','BE':'EUR','CY':'EUR','EE':'EUR','FI':'EUR','FR':'EUR','DE':'EUR','GR':'EUR','IE':'EUR',
  'IT':'EUR','LV':'EUR','LT':'EUR','LU':'EUR','MT':'EUR','NL':'EUR','PT':'EUR','SK':'EUR','SI':'EUR','ES':'EUR',
  // 유럽(비유로)
  'GB':'GBP','CH':'CHF','NO':'NOK','SE':'SEK','DK':'DKK','PL':'PLN','CZ':'CZK','HU':'HUF',
  // 중동
  'TR':'TRY','AE':'AED','SA':'SAR','QA':'QAR','KW':'KWD','BH':'BHD','OM':'OMR','IL':'ILS','EG':'EGP',
  // 아프리카(대표)
  'ZA':'ZAR','MA':'MAD','TN':'TND','DZ':'DZD','NG':'NGN','KE':'KES',
  // 아시아
  'KR':'KRW','JP':'JPY','CN':'CNY','TW':'TWD','HK':'HKD','MO':'MOP',
  'SG':'SGD','MY':'MYR','TH':'THB','ID':'IDR','VN':'VND','PH':'PHP',
  'IN':'INR',
  // 오세아니아
  'AU':'AUD','NZ':'NZD',
};

String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'USD': return '\$';
    case 'EUR': return '€';
    case 'JPY': return '¥';
    case 'KRW': return '₩';
    case 'GBP': return '£';
    case 'CNY': return '元';
    case 'VND': return '₫';
    case 'PHP': return '₱';
    case 'THB': return '฿';
    case 'INR': return '₹';
    default: return '';
  }
}

String? _guessFromSymbol(String? s) {
  if (s == null || s.isEmpty) return null;
  switch (s) {
    case '₩': return 'KRW';
    case '€': return 'EUR';
    case '£': return 'GBP';
    case '₫': return 'VND';
    case '₱': return 'PHP';
    case '฿': return 'THB';
    case '₹': return 'INR';
    default: return null; // '$','¥' 모호 → 다른 정보로 보정
  }
}

String pickLocalCurrency({String? detectedCountryCode, String? currencySymbolHint}) {
  final bySym = _guessFromSymbol(currencySymbolHint);
  if (bySym != null) return bySym;
  if (detectedCountryCode != null) {
    final c = kCountryToCurrency[detectedCountryCode.toUpperCase()];
    if (c != null) return c;
  }
  final cc = ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
  final byLocale = cc != null ? kCountryToCurrency[cc] : null;
  return byLocale ?? 'USD';
}

/// ===== Firestore 모델 =====
class FxDoc {
  final String base; // e.g., 'USD', 'EUR', 'KRW', 'JPY', 'CNY'
  final Map<String, double> rates; // 1 base -> X
  final DateTime? updatedAt;
  FxDoc({required this.base, required this.rates, required this.updatedAt});

  static FxDoc? fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    final base = (data['base'] as String).toUpperCase();
    final rawRates = (data['rates'] as Map).map(
          (k, v) => MapEntry(k.toString().toUpperCase(), (v as num).toDouble()),
    );
    DateTime? updated;
    final u = data['updatedAt'];
    if (u is Timestamp) updated = u.toDate();
    if (u is String) updated = DateTime.tryParse(u);
    return FxDoc(base: base, rates: rawRates, updatedAt: updated);
  }
}

class FxRepository {
  final FirebaseFirestore _db;
  FxRepository(this._db);

  Stream<FxDoc?> streamFxCore(String base) =>
      _db.collection('fx_core').doc(base.toUpperCase()).snapshots().map(FxDoc.fromSnap);

  Stream<Map<String, FxDoc>> streamFxCores(Iterable<String> bases) {
    final ids = bases.map((e) => e.toUpperCase()).toList();
    return _db
        .collection('fx_core')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .map((snap) {
      final m = <String, FxDoc>{};
      for (final d in snap.docs) {
        final fx = FxDoc.fromSnap(d);
        if (fx != null) m[d.id.toUpperCase()] = fx;
      }
      return m;
    });
  }
}

/// ===== 변환 =====
double? convertViaBase({
  required double amount,
  required String from,
  required String to,
  required FxDoc baseDoc,
}) {
  final f = from.toUpperCase();
  final t = to.toUpperCase();
  if (f == t) return amount;
  final rFrom = baseDoc.rates[f];
  if (rFrom == null || rFrom == 0) return null;
  final inBase = amount / rFrom; // A -> base
  if (t == baseDoc.base) return inBase;
  final rTo = baseDoc.rates[t];  // base -> B
  if (rTo == null) return null;
  return inBase * rTo;
}

String? normalizeToSupported(String code, FxDoc doc) {
  final c = code.toUpperCase();
  return doc.rates.containsKey(c) ? c : null;
}

FxDoc? pickBestBaseDoc({
  required String from,
  required String to,
  required Map<String, FxDoc> docs,
}) {
  final toU = to.toUpperCase();
  final order = [
    toU, // 타깃 동일 베이스 우선
    'USD', 'EUR', 'KRW', 'JPY', 'CNY',
  ];
  final seen = <String>{};
  for (final id in order) {
    if (!seen.add(id)) continue;
    final d = docs[id];
    if (d == null) continue;
    final fOk = d.rates.containsKey(from.toUpperCase());
    final tOk = d.rates.containsKey(toU);
    if (fOk && tOk) return d;
  }
  return null;
}

DateTime? latestUpdatedAt(Map<String, FxDoc> docs) {
  DateTime? u;
  for (final d in docs.values) {
    final du = d.updatedAt;
    if (du == null) continue;
    if (u == null || du.isAfter(u)) u = du;
  }
  return u;
}

/// ===== 타깃 통화 (5개) =====
enum TargetCurrency { usd, eur, krw, jpy, cny }

String _targetCodeOf(TargetCurrency t) {
  switch (t) {
    case TargetCurrency.usd: return 'USD';
    case TargetCurrency.eur: return 'EUR';
    case TargetCurrency.krw: return 'KRW';
    case TargetCurrency.jpy: return 'JPY';
    case TargetCurrency.cny: return 'CNY';
  }
}

/// ===== 외부에서 쓰는: 작게 보이는 아이콘 버튼 =====
class FxQuickFxButton extends StatelessWidget {
  const FxQuickFxButton({
    super.key,
    required this.initialAmount,
    this.detectedCountryCode,
    this.currencySymbolHint,
    this.initialTarget = TargetCurrency.usd,
    this.iconSize = 18, // 작게
    this.padding = const EdgeInsets.all(4),
    this.iconData,
    // [ADD] 결과에서 파싱한 다중 금액 후보
    this.parsedAmounts = const <double>[],
  });

  final double initialAmount;
  final String? detectedCountryCode;
  final String? currencySymbolHint;
  final TargetCurrency initialTarget;
  final double iconSize;
  final EdgeInsets padding;
  final IconData? iconData;
  // [ADD]
  final List<double> parsedAmounts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: IconButton(
        iconSize: iconSize,
        splashRadius: iconSize + 6,
        tooltip: AppLocalizations.of(context)?.fx_tooltip,
        icon: Icon(Icons.currency_exchange),
        onPressed: () async {
          // 🔹 from/to 산출
          final from = pickLocalCurrency(
            detectedCountryCode: detectedCountryCode,
            currencySymbolHint: currencySymbolHint,
          );
          final to = _targetCodeOf(initialTarget);

          // 🔹 로그: 환율 기능 열기
          await LogService().logCurrencyCalcOpen(
            from: from,
            to: to,
            context: 'scan', // 필요하면 'manual' 등으로 바꿔도 됨
          );
          showModalBottomSheet(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent, // 바깥 배경 투명(시트 색 우리가 지정)
            builder: (_) => FxConverterSheet(
              initialAmount: initialAmount,
              detectedCountryCode: detectedCountryCode,
              currencySymbolHint: currencySymbolHint,
              initialTarget: initialTarget,
              // [ADD] 그대로 전달
              parsedAmounts: parsedAmounts,
            ),
          );
        },
      ),
    );
  }
}

/// ===== 바텀시트: 전체 환율 변환창(타이트 레이아웃) =====
class FxConverterSheet extends StatefulWidget {
  const FxConverterSheet({
    super.key,
    required this.initialAmount,
    this.detectedCountryCode,
    this.currencySymbolHint,
    this.initialTarget = TargetCurrency.usd,
    this.parsedAmounts = const <double>[],
  });

  final double initialAmount;
  final String? detectedCountryCode;
  final String? currencySymbolHint;
  final TargetCurrency initialTarget;

  final List<double> parsedAmounts;

  @override
  State<FxConverterSheet> createState() => _FxConverterSheetState();
}

class _AmountChipsBar extends StatelessWidget {
  const _AmountChipsBar({
    required this.cands,
    required this.selectedIdx,
    required this.onTapChip,
    required this.onTapMore,
    required this.fmt,
    this.maxWidth = 220,
    this.maxHeight = 32,
  });

  final List<double> cands;
  final Set<int> selectedIdx;
  final void Function(int idx) onTapChip;
  final VoidCallback onTapMore;
  final String Function(double v) fmt;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visible = cands.take(3).toList();
    final extra = cands.length - visible.length;

    final children = <Widget>[
      for (var i = 0; i < visible.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(
              fmt(visible[i]),
              style: const TextStyle(fontSize: 11),
            ),
            selected: selectedIdx.contains(i),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            onSelected: (_) => onTapChip(i),
            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7F7F7),
            selectedColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
          ),
        ),
      if (extra > 0)
        InkWell(
          onTap: onTapMore,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
            ),
            child: const Icon(Icons.add, size: 14),
          ),
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}


class _FxConverterSheetState extends State<FxConverterSheet> {
  late final FxRepository _repo;
  late TextEditingController _amountCtrl;
  late String _localCurrency;
  TargetCurrency _target = TargetCurrency.usd;

  // [ADD] 선택 상태/도우미
  final Set<int> _selectedIdx = {};
  List<double> get _cands => widget.parsedAmounts;

  double get _selectedSum {
    double s = 0;
    for (final i in _selectedIdx) {
      if (i >= 0 && i < _cands.length) s += _cands[i];
    }
    return double.parse(s.toStringAsFixed(2));
  }

  void _applySelectedToField() {
    if (_selectedIdx.isEmpty) return;
    final v = _selectedSum;
    // 입력란에 합계 입력 → 즉시 환산 반영되도록 setState
    _amountCtrl.text = v.toStringAsFixed(2);
    _amountCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountCtrl.text.length),
    );
    setState(() {}); // 결과 영역 갱신
  }

  void _toggleIdx(int idx) {
    setState(() {
      if (_selectedIdx.contains(idx)) {
        _selectedIdx.remove(idx);
      } else {
        _selectedIdx.add(idx);
      }
    });
    _applySelectedToField();
  }

  void _openAllCandidatesSheet() {
    if (_cands.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _cands.length,
            itemBuilder: (_, i) {
              final selected = _selectedIdx.contains(i);
              return ListTile(
                dense: true,
                title: Text(_fmtAmount(_cands[i])),
                trailing: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleIdx(i);
                },
              );
            },
          ),
        );
      },
    );
  }

  // [ADD] 수동/순차 누적 항목 보관
  final List<double> _exprTerms = [];

  // [ADD] 누적 합계
  double get _exprSum => _exprTerms.fold<double>(0, (p, e) => p + e);

  // [ADD] 입력창 숫자 파싱
  double _parseField() {
    return double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
  }

  // [ADD] 입력창 값을 항목으로 추가(+), 입력창/칩 선택 초기화
  void _addCurrentAsTerm() {
    final v = _parseField();
    if (v <= 0) return;
    setState(() {
      _exprTerms.add(double.parse(v.toStringAsFixed(2)));
      _amountCtrl.clear();
      _selectedIdx.clear();
    });
  }

  // [ADD] 수식 문자열 (예: "1,000 + 500 + 600")
  String get _exprFormula {
    if (_exprTerms.isEmpty) return '';
    return _exprTerms.map(_fmtAmount).join(' + ');
  }

  String _fmtAmount(double v) {
    // 천단위 콤마, 소수 0~2자리 자동
    final hasFraction = v.truncateToDouble() != v;
    final s = hasFraction ? v.toStringAsFixed(2) : v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  // [ADD] 화면에 보여줄 수식(누적항목 + 현재 입력값까지 포함)
  String get _displayFormula {
    final tail = _parseField();
    final parts = <String>[..._exprTerms.map(_fmtAmount)];
    if (tail > 0) parts.add(_fmtAmount(tail));
    return parts.join(' + ');
  }




  Widget _targetChip(String label, TargetCurrency value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7F7F7);
    final selectedBg = isDark ? const Color(0xFF3A3A3C) : Colors.white;
    final sideColor = isDark ? Colors.white24 : Colors.grey.shade400;

    final selected = _target == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _target = value),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        backgroundColor: bg,           // 비선택
        selectedColor: selectedBg,     // 선택
        side: BorderSide(color: sideColor),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _repo = FxRepository(FirebaseFirestore.instance);
    _amountCtrl = TextEditingController(
      text: widget.initialAmount == 0 ? '' : widget.initialAmount.toString(),
    );
    _localCurrency = pickLocalCurrency(
      detectedCountryCode: widget.detectedCountryCode,
      currencySymbolHint: widget.currencySymbolHint,
    );
    _target = widget.initialTarget;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _openCurrencyPicker({required FxDoc? eur, required FxDoc? usd}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFEFF4);
    final cardBg  = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final divider = isDark ? Colors.white10 : Colors.black12;
    final sideColor = isDark ? Colors.white24 : Colors.black12;

    final supported = <String>{};
    if (eur != null) supported.addAll(eur.rates.keys.map((e) => e.toUpperCase()));
    if (usd != null) supported.addAll(usd.rates.keys.map((e) => e.toUpperCase()));
    final all = (supported.isEmpty ? kTopCurrencies.toList() : supported.toList())..sort();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String q = '';
        return Material(
          color: sheetBg,
          child: StatefulBuilder(builder: (ctx, setM) {
            final filtered = all.where((c) => q.isEmpty ? true : c.contains(q.toUpperCase())).toList();
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      onChanged: (v) => setM(() => q = v),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: AppLocalizations.of(context)?.fx_search_currency_hint,
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderSide: BorderSide(color: sideColor)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: sideColor)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(color: divider, height: 1),
                      itemBuilder: (_, i) {
                        final code = filtered[i];
                        final sym = currencySymbol(code);
                        final isSelected = code == _localCurrency;
                        return Container(
                          color: cardBg,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              sym.isEmpty ? code : '$code  ($sym)',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                                : null,
                            onTap: () {
                              setState(() => _localCurrency = code);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // iOS systemGroupedBackground 계열과 유사한 팔레트
    final sheetBg  = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFEFF4);
    final cardBg   = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final border   = isDark ? Colors.white24 : Colors.grey.shade400;
    final subtleTx = isDark ? Colors.white70 : Colors.black54;

    // 5개 베이스 문서를 한 번에 스트림
    final fx$ = _repo.streamFxCores(const ['USD', 'EUR', 'KRW', 'JPY', 'CNY']);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) {
          return Material(
            color: sheetBg, // ✅ HomeScreen과 동일 컨셉
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: StreamBuilder<Map<String, FxDoc>>(
                stream: fx$,
                builder: (context, snap) {
                  final docs = snap.data ?? const <String, FxDoc>{};
                  // ✅ 누락됐던 fallback 기준일 계산
                  final fallbackUpdated = latestUpdatedAt(docs);

                  final targetCode = _targetCodeOf(_target);

                  final double fieldVal = _parseField();
                  final double amount = _exprSum + fieldVal;

                  double? result;
                  DateTime? usedUpdatedAt;

                  if (amount > 0) {
                    final baseDoc = pickBestBaseDoc(
                      from: _localCurrency,
                      to: targetCode,
                      docs: docs,
                    );
                    if (baseDoc != null) {
                      result = convertViaBase(
                        amount: amount,
                        from: _localCurrency,
                        to: targetCode,
                        baseDoc: baseDoc,
                      );
                      usedUpdatedAt = baseDoc.updatedAt;
                    }
                  }

// 기준일 텍스트
                  // ✅ String 으로 만들어서 l10n 함수에 그대로 전달
                  final updatedText = (usedUpdatedAt ?? fallbackUpdated) != null
                      ? DateFormat('yyyy-MM-dd').format(
                    (usedUpdatedAt ?? fallbackUpdated)!.toLocal(),
                  )
                      : (AppLocalizations.of(context)?.fx_unknown ?? 'Unknown');

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 12),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      // 헤더 (작게)
                      Row(
                        children: [
                          const Icon(Icons.currency_exchange, size: 18),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context)!.fx_title,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 0,
                                    children: [
                                      _targetChip('USD', TargetCurrency.usd),
                                      _targetChip('EUR', TargetCurrency.eur),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 0,
                                    children: [
                                      _targetChip('KRW', TargetCurrency.krw),
                                      _targetChip('JPY', TargetCurrency.jpy),
                                      _targetChip('CNY', TargetCurrency.cny),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 통화 변경 + 업데이트일
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: cardBg, // 버튼 배경도 카드 톤
                              side: BorderSide(color: border),
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                            ),
                            icon: const Icon(Icons.flag, size: 16),
                            label: Text(
                              AppLocalizations.of(context)!.fx_currency_btn(_localCurrency),
                            ),
                            onPressed: () {
                              _openCurrencyPicker(
                                eur: docs['EUR'],
                                usd: docs['USD'],
                              );
                            },
                          ),
                          const Spacer(),
                          Text(
                            AppLocalizations.of(context)!.fx_base_date(updatedText),
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: subtleTx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 금액 입력(카드 톤 + 테두리)
                      // 금액 입력(카드 톤 + 테두리) + [ADD] 오른쪽 하단 작은 칩 바
                      Stack(
                        children: [
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: AppLocalizations.of(context)?.fx_amount_label,
                              hintText: AppLocalizations.of(context)?.fx_amount_hint,
                              filled: true,
                              fillColor: cardBg,
                              border: OutlineInputBorder(borderSide: BorderSide(color: border)),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              // [ADD] 우상단 + 버튼 공간 확보
                              contentPadding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
// [ADD] 우상단 동그라미 + 버튼 (입력값을 누적 항목으로 이동)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _addCurrentAsTerm,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: cardBg,                // 모노톤 배경
                                  shape: BoxShape.circle,
                                  border: Border.all(color: border), // 모노톤 테두리
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.add, size: 14, color: subtleTx), // 모노톤 아이콘
                              ),
                            ),
                          ),
                          if (_cands.isNotEmpty)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: _AmountChipsBar(
                                cands: _cands,
                                selectedIdx: _selectedIdx,
                                onTapChip: _toggleIdx,
                                onTapMore: _openAllCandidatesSheet,
                                fmt: _fmtAmount,
                                // 카드/통화 버튼 크기와 비슷하게 아주 작게
                                maxWidth: 220,
                                maxHeight: 32,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),


                      // 결과
                      if (amount <= 0)
                        Text(
                            AppLocalizations.of(context)!.fx_enter_amount_to_convert(targetCode),
                            style: TextStyle(fontSize: 13, color: subtleTx))
                      else if (result == null)
                        Text(
                          AppLocalizations.of(context)!.fx_error_no_rate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Text(
                              NumberFormat.currency(
                                symbol: currencySymbol(targetCode),
                                decimalDigits: 2,
                              ).format(result).trim(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(targetCode, style: TextStyle(fontSize: 14, color: subtleTx)),
                            // [ADD] 오른쪽 수식(예: "1,000 + 500 + 600")을 작게/흐리게
                            if ((_exprTerms.length + (_parseField() > 0 ? 1 : 0)) >= 2) ...[
                              const Spacer(),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _displayFormula, // 예: "5,000 + 5,000"
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtleTx.withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
