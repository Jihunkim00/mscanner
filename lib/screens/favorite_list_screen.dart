import 'package:flutter/material.dart';
import '/features/food_journey/services/food_journey_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../styles/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'favorite_screen.dart'; // ✅ FavoriteScreen을 사용하므로 유지
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/animated_map_screen.dart'; // ← 추가
import '../models/place_data.dart'; // ← 추가
import '/screens/log_service.dart';
import 'package:mscanner/widgets/mscanner_search_ui.dart';
import 'package:provider/provider.dart';
import '/ad_remove_provider.dart';
import '/services/history_retention_service.dart';

class FavoriteListScreen extends StatefulWidget {
  const FavoriteListScreen({super.key});

  @override
  State<FavoriteListScreen> createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  List<DocumentSnapshot> _favoriteResults = [];
  final Set<String> _selectedIds = {}; // ← 추가
  // ✅ 이미지 토글: true면 menu(촬영본), false면 food(대표 음식 사진)
  final Set<String> _showMenuPhotoIds = {};
  String _currentSort = 'latest'; // 기본 정렬: 최신순
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  bool? _loadedForPremium;
  bool? _loadedForEntitlement;
  int _loadRequest = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final entitlement = context.watch<AdRemoveProvider>();
    final isPremium = entitlement.isSubscribed;
    final isEntitlementLoaded = entitlement.isEntitlementLoaded;
    if (_loadedForPremium == isPremium &&
        _loadedForEntitlement == isEntitlementLoaded) {
      return;
    }
    _loadedForPremium = isPremium;
    _loadedForEntitlement = isEntitlementLoaded;
    _loadFavoriteResults();
  }

  // ✅ 상단 필터(예: All / Recent / Top Rated)
  String _activeFilter = 'all';

  int _calcItemAgeDays(Map<String, dynamic> data) {
    try {
      final ts = data['timestamp'];
      final dt = ts is String ? DateTime.parse(ts) : (ts as DateTime?);
      if (dt == null) return 0;
      return DateTime.now().difference(dt).inDays;
    } catch (_) {
      return 0;
    }
  }

  String _inferItemType(Map<String, dynamic> data) {
    // responses(스캔 결과)가 있으면 'scan', 없으면 'manual'로 간주
    final r = data['responses'];
    if (r is List && r.isNotEmpty) return 'scan';
    return 'manual';
  }

  // ---------- NEW: History 카드 표시용 파서 (기존 DB 호환) ----------
  DateTime? _parseTimestamp(Map<String, dynamic> data) {
    try {
      final ts = data['timestamp'];
      if (ts is String) return DateTime.tryParse(ts);
      if (ts is DateTime) return ts;
    } catch (_) {}
    return null;
  }

  double _parseRating(Map<String, dynamic> data) {
    final r = data['rating'];
    if (r is int) return r.toDouble();
    if (r is double) return r;
    return 0.0;
  }

  String? _extractJsonObjectFromText(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    // ```json ... ``` 코드블럭 제거
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
      s = s.replaceAll(RegExp(r'\s*```$'), '');
      s = s.trim();
    }

    // 앞에 RECOMMEND/기타 텍스트가 있어도 첫 '{'부터 자르기
    final start = s.indexOf('{');
    if (start < 0) return null;

    // 마지막 '}'까지
    final end = s.lastIndexOf('}');
    if (end < 0 || end <= start) return null;

    final candidate = s.substring(start, end + 1).trim();
    if (!candidate.startsWith('{') || !candidate.endsWith('}')) return null;

    return candidate;
  }

  // 대표 메뉴명: 1) 필드 우선 2) responses JSON recommended[0] 3) 텍스트에서 1번 추출 4) restaurantName fallback
  String _primaryMenuName(Map<String, dynamic> data) {
    final direct =
        (data['primary_menu'] ?? data['menu_name'] ?? data['menuName'])
            ?.toString()
            .trim();
    if (direct != null && direct.isNotEmpty) return direct;

    // responses: List<String> 또는 response: String (구버전)
    final rawList = data['responses'];
    final rawSingle = data['response'];
    final List<String> responses = (rawList is List)
        ? rawList.map((e) => e.toString()).toList()
        : (rawSingle != null ? [rawSingle.toString()] : const <String>[]);

// 2) JSON first recommended (✅ 번역명(name) 우선)
    for (final r in responses) {
      final jsonStr = _extractJsonObjectFromText(r);
      if (jsonStr == null) continue;

      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          final rec = decoded['recommended'];
          if (rec is List && rec.isNotEmpty && rec.first is Map) {
            final m = Map<String, dynamic>.from(rec.first as Map);

            final translated = (m['name'] ?? '').toString().trim(); // ✅ 번역명
            final original = (m['nameOriginal'] ?? '').toString().trim(); // 원문명

            if (translated.isNotEmpty) return translated;
            if (original.isNotEmpty) return original;
          }
        }
      } catch (_) {
        // ignore
      }
    }

    // 3) 텍스트 1번 항목 추출 (구버전)
    final joined = responses.join('\n').replaceAll('\r', '');
    final lines = joined.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final m = RegExp(r'^\s*1\s*[\.\)\]\:\-]\.\?\s*').firstMatch(line);
      if (m != null) {
        var first = line.substring(m.end).trim();
        // 꼬리 자르기
        for (final t in const [' - ', ' – ', ' — ', ': ', '(', '[', '|']) {
          final idx = first.indexOf(t);
          if (idx > 0) first = first.substring(0, idx).trim();
        }
        first = first.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();
        if (first.length >= 2) return first;
        break;
      }
    }

    final fallback =
        (data['restaurantName'] ?? data['title'] ?? 'No Title').toString();
    return fallback;
  }

  String _restaurantName(Map<String, dynamic> data) {
    return (data['restaurantName'] ?? data['title'] ?? 'No Restaurant Name')
        .toString();
  }

  // 대표 음식 사진(새 필드) -> 없으면 기존 촬영본(image_url)
  String _foodImageUrl(Map<String, dynamic> data) {
    final u = (data['food_image_url'] ??
            data['foodImageUrl'] ??
            data['dish_image_url'] ??
            data['dishImageUrl'])
        ?.toString()
        .trim();
    if (u != null && u.isNotEmpty) return u;
    return (data['image_url'] ?? '').toString();
  }

  String _menuImageUrl(Map<String, dynamic> data) {
    return (data['image_url'] ?? '').toString();
  }

  bool _isRecent(Map<String, dynamic> data, {int days = 7}) {
    final dt = _parseTimestamp(data);
    if (dt == null) return false;
    return DateTime.now().difference(dt).inDays <= days;
  }

  // ---------- NEW: 필터 적용 ----------
  List<DocumentSnapshot> _applyFilter(List<DocumentSnapshot> docs) {
    if (_activeFilter == 'all') return docs;
    if (_activeFilter == 'recent') {
      return docs
          .where((d) => _isRecent(d.data() as Map<String, dynamic>, days: 7))
          .toList();
    }
    if (_activeFilter == 'top') {
      return docs
          .where((d) => _parseRating(d.data() as Map<String, dynamic>) >= 4.5)
          .toList();
    }
    return docs;
  }

  List<DocumentSnapshot> _applySearch(List<DocumentSnapshot> docs) {
    final q = _searchText.trim().toLowerCase();
    if (q.isEmpty) return docs;

    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final haystack = [
        _primaryMenuName(data),
        _restaurantName(data),
        (data['country'] ?? '').toString(),
        (data['city'] ?? '').toString(),
        (data['cuisine'] ?? '').toString(),
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  // ---------- NEW: 섹션 그룹(이번 주 / 월별) ----------
  Map<String, List<DocumentSnapshot>> _groupBySection(
      List<DocumentSnapshot> docs) {
    final Map<String, List<DocumentSnapshot>> groups = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dt = _parseTimestamp(data);
      final key = (dt != null && DateTime.now().difference(dt).inDays <= 7)
          ? 'THIS_WEEK'
          : (dt != null ? DateFormat('MMMM').format(dt) : 'UNKNOWN');
      groups.putIfAbsent(key, () => <DocumentSnapshot>[]).add(doc);
    }
    return groups;
  }

  Widget _buildTopControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: MScannerSearchField(
            controller: _searchController,
            placeholder:
                AppLocalizations.of(context)?.favoriteList_searchHistory ??
                    'Search History',
            onChanged: (v) => setState(() => _searchText = v),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // ---- Filters ----
              MScannerPillChip(
                label: AppLocalizations.of(context)?.favoriteList_all ?? 'All',
                selected: _activeFilter == 'all',
                scheme: MScannerAccent.orange,
                onTap: () => setState(() => _activeFilter = 'all'),
              ),
              MScannerPillChip(
                label: AppLocalizations.of(context)?.favoriteList_recent ??
                    'Recent',
                selected: _activeFilter == 'recent',
                scheme: MScannerAccent.orange,
                onTap: () => setState(() => _activeFilter = 'recent'),
              ),
              MScannerPillChip(
                label: AppLocalizations.of(context)?.favoriteList_topRated ??
                    'Top Rated',
                selected: _activeFilter == 'top',
                scheme: MScannerAccent.orange,
                onTap: () => setState(() => _activeFilter = 'top'),
              ),

              const SizedBox(width: 8),

              // ---- Sorting (map_screen처럼 chip로 통일) ----
              MScannerPillChip(
                label:
                    AppLocalizations.of(context)?.favoriteList_date ?? 'Date',
                selected: _currentSort == 'latest',
                scheme: MScannerAccent.orange,
                onTap: () {
                  if (_currentSort == 'latest') return;
                  setState(() => _currentSort = 'latest');
                  _loadFavoriteResults();
                },
              ),
              MScannerPillChip(
                label: AppLocalizations.of(context)?.favoriteList_country ??
                    'Country',
                selected: _currentSort == 'country',
                scheme: MScannerAccent.orange,
                onTap: () {
                  if (_currentSort == 'country') return;
                  setState(() => _currentSort = 'country');
                  _loadFavoriteResults();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyCard({
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required bool isSelected,
  }) {
    final menuName = _primaryMenuName(data);
    final restaurant = _restaurantName(data);
    final rating = _parseRating(data);
    final dt = _parseTimestamp(data);
    final dateText = dt != null
        ? DateFormat('MMM d, h:mm a', AppLocalizations.of(context)!.localeName)
            .format(dt)
        : AppLocalizations.of(context)?.favoriteList_noDate ?? 'No date';

    final showMenu = _showMenuPhotoIds.contains(doc.id);
    final img = showMenu ? _menuImageUrl(data) : _foodImageUrl(data);

    return SavedHistoryCard(
      menuName: menuName,
      restaurant: restaurant,
      rating: rating,
      dateText: dateText,
      imageUrl: img,
      isSelected: isSelected,
      onTap: () {
        final ageDays = _calcItemAgeDays(data);
        final itemType = _inferItemType(data);
        LogService()
            .logHistoryDetailView(itemAgeDays: ageDays, itemType: itemType);
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FavoriteScreen(documentId: doc.id),
            ));
      },
      onImageTap: () => setState(() {
        if (_showMenuPhotoIds.contains(doc.id)) {
          _showMenuPhotoIds.remove(doc.id);
        } else {
          _showMenuPhotoIds.add(doc.id);
        }
      }),
      onSelected: (val) => setState(() {
        if (val == true) {
          _selectedIds.add(doc.id);
        } else {
          _selectedIds.remove(doc.id);
        }
      }),
    );
  }

  Future<void> _loadFavoriteResults() async {
    final user = FirebaseAuth.instance.currentUser;
    final request = ++_loadRequest;
    if (user == null) {
      if (mounted) setState(() => _favoriteResults = []);
      return;
    }

    final entitlement = context.read<AdRemoveProvider>();
    if (!entitlement.isEntitlementLoaded) return;
    final isPremium = entitlement.isSubscribed;
    final historyCollection = FirebaseFirestore.instance
        .collection('user_rating')
        .doc(user.uid)
        .collection('data');

    await const HistoryRetentionService().enforce(
      historyCollection: historyCollection,
      isPremium: isPremium,
    );
    if (!mounted || request != _loadRequest) return;

    QuerySnapshot<Map<String, dynamic>> querySnapshot;
    if (_currentSort == 'latest' || !isPremium) {
      Query<Map<String, dynamic>> query =
          historyCollection.orderBy('timestamp', descending: true);
      // Free/Guest retention is always the newest 20 entries. Country sort
      // is applied locally after selecting that same newest window.
      if (!isPremium) {
        query = query.limit(HistoryRetentionPolicy.freeHistoryLimit);
      }
      querySnapshot = await query.get();
    } else {
      // Premium has no storage-retention cap. This remains a UI query, not a
      // deletion policy; a future paginated UI can add a page size here.
      querySnapshot = await historyCollection
          .orderBy('country', descending: false)
          .orderBy('timestamp', descending: true)
          .get();
    }

    var docs = querySnapshot.docs.toList();
    if (!isPremium && _currentSort == 'country') {
      docs.sort((a, b) {
        final countryCompare = (a.data()['country'] ?? '').toString().compareTo(
              (b.data()['country'] ?? '').toString(),
            );
        if (countryCompare != 0) return countryCompare;
        return (b.data()['timestamp'] ?? '').toString().compareTo(
              (a.data()['timestamp'] ?? '').toString(),
            );
      });
    }

    if (!mounted || request != _loadRequest) return;
    setState(() {
      _favoriteResults = docs;
      _selectedIds.clear(); // 새로 로드 시 선택 초기화
    });
  }

  Future<void> _deleteFavoriteResult(int index) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('user_rating')
        .doc(user.uid)
        .collection('data')
        .doc(_favoriteResults[index].id)
        .delete();

    FoodJourneyService.instance.invalidate(user.uid);

    setState(() {
      _favoriteResults.removeAt(index);
    });
  }

  void _goToAnimatedMap() {
    // 선택된 DocumentSnapshot → PlaceData 변환
    final selectedPlaces = _favoriteResults
        .where((doc) => _selectedIds.contains(doc.id))
        .map((doc) => PlaceData.fromFirestore(doc))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (selectedPlaces.isNotEmpty) {
      LogService().logMapOpen(from: 'history');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnimatedMapScreen(selectedPlaces: selectedPlaces),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final backgroundColor = colors.background;
    final textColor = colors.text;

    final loc = AppLocalizations.of(context)!; // ← 추가

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ NEW: 상단 필터 + 섹션 리스트
            Column(
              children: [
                _buildTopControls(),
                Expanded(
                  child: _favoriteResults.isEmpty
                      ? Center(
                          child: Text(
                              AppLocalizations.of(context)
                                      ?.favoriteList_noHistoryFound ??
                                  'No History Found',
                              style: TextStyle(color: textColor)),
                        )
                      : Builder(builder: (_) {
                          final filtered =
                              _applySearch(_applyFilter(_favoriteResults));
                          final grouped = _groupBySection(filtered);

                          // 섹션 순서: This Week -> 나머지
                          final keys = grouped.keys.toList();
                          keys.sort((a, b) {
                            if (a == 'THIS_WEEK') return -1;
                            if (b == 'THIS_WEEK') return 1;
                            return a.compareTo(b);
                          });

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 120),
                            itemCount: keys.length,
                            itemBuilder: (context, sectionIdx) {
                              final key = keys[sectionIdx];
                              final items =
                                  grouped[key] ?? const <DocumentSnapshot>[];
                              final title = key == 'THIS_WEEK'
                                  ? (AppLocalizations.of(context)
                                          ?.favoriteList_thisWeek ??
                                      'This Week')
                                  : key == 'UNKNOWN'
                                      ? key
                                      : DateFormat.MMMM(loc.localeName).format(
                                          _parseTimestamp(items.first.data()
                                              as Map<String, dynamic>)!);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                            child: Text(
                                          AppLocalizations.of(context)!
                                              .favoriteList_entries(
                                                  items.length),
                                          textAlign: TextAlign.end,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colors.secondaryText,
                                              ),
                                        )),
                                      ],
                                    ),
                                  ),
                                  ...items.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final isSelected =
                                        _selectedIds.contains(doc.id);
                                    final idx = _favoriteResults
                                        .indexWhere((d) => d.id == doc.id);

                                    return Dismissible(
                                      key: Key(doc.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        color: Colors.redAccent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: const Icon(CupertinoIcons.delete,
                                            color: Colors.white, size: 30),
                                      ),
                                      onDismissed: (_) {
                                        if (idx >= 0) {
                                          _deleteFavoriteResult(idx);
                                        }
                                      },
                                      child: _historyCard(
                                        doc: doc,
                                        data: data,
                                        isSelected: isSelected,
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          );
                        }),
                ),
              ],
            ),

            // 선택된 항목이 있을 때만 노출되는 "지도에서 보기" 버튼
            if (_selectedIds.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: FilledButton.tonalIcon(
                  // ← 통일감 있는 M3 톤 다운 버튼
                  onPressed: _goToAnimatedMap,
                  icon: const Icon(Icons.map),
                  label: Text(loc.viewOnMap), // ← l10n 적용
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Presentation of an existing saved record; actions stay with the list state.
class SavedHistoryCard extends StatelessWidget {
  const SavedHistoryCard({
    super.key,
    required this.menuName,
    required this.restaurant,
    required this.rating,
    required this.dateText,
    required this.imageUrl,
    required this.isSelected,
    required this.onTap,
    required this.onImageTap,
    required this.onSelected,
  });

  final String menuName;
  final String restaurant;
  final double rating;
  final String dateText;
  final String imageUrl;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onImageTap;
  final ValueChanged<bool?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(menuName, style: textTheme.titleMedium),
        if (restaurant.trim().isNotEmpty &&
            restaurant.trim().toLowerCase() !=
                menuName.trim().toLowerCase()) ...[
          const SizedBox(height: 2),
          Text(restaurant,
              style:
                  textTheme.bodySmall?.copyWith(color: colors.secondaryText)),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(dateText,
                style: textTheme.labelSmall
                    ?.copyWith(color: colors.secondaryText)),
            if (rating > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1), style: textTheme.labelSmall),
              ]),
          ],
        ),
      ],
    );
    final image = Semantics(
      button: true,
      child: GestureDetector(
        onTap: onImageTap,
        child: ClipRRect(
          borderRadius: AppTheme.controlRadius,
          child: SizedBox.square(
            dimension: 64,
            child: imageUrl.isEmpty
                ? Icon(Icons.image_not_supported_outlined,
                    color: colors.secondaryText)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (_, __) => const CupertinoActivityIndicator(),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_outlined),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
    );
    final checkbox = Checkbox(
      value: isSelected,
      activeColor: colors.primary,
      checkColor: colors.onPrimary,
      semanticLabel: menuName,
      onChanged: onSelected,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.cardRadius,
          side: BorderSide(color: isSelected ? colors.primary : colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              if (constraints.maxWidth < 220 * scale) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [image, const Spacer(), checkbox]),
                      const SizedBox(height: 8),
                      details,
                    ]);
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    image,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    checkbox,
                  ]);
            }),
          ),
        ),
      ),
    );
  }
}
