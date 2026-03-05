import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/widgets/mscanner_search_ui.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

enum _FilterType { recent, topRated, cuisine, date, location }

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  LatLng _initialPosition = const LatLng(51.509364, -0.128928);
  bool _locationLoaded = false;

  // ✅ raw data
  List<Map<String, dynamic>> _historyItems = [];

  // ✅ filtered result
  List<Map<String, dynamic>> _filteredItems = [];
  Set<Marker> _markers = {};

  bool _isDarkMode = false;
  String _searchText = '';

  String? _selectedId;
  final Map<String, LatLng> _idToLatLng = {}; // docId -> LatLng
  final Map<String, Map<String, dynamic>> _idToData = {}; // docId -> data

  // ✅ current “active filter”
  _FilterType _activeFilter = _FilterType.recent;

  // ✅ bottom sheet filter values
  String? _selectedCuisine; // e.g. "Japanese"
  String? _selectedLocation; // e.g. "Japan" or "Seoul"
  DateTimeRange? _selectedDateRange; // start~end

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadMarkersFromFirestore();
  }

  // ---------- location ----------
  Future<void> _getUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final position =
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _locationLoaded = true;
      });
    } catch (_) {}
  }

  // ---------- firestore ----------
  Future<void> _loadMarkersFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_rating')
          .doc(user.uid)
          .collection('data')
          .orderBy('timestamp', descending: true)
          .limit(300)
          .get();

      final items = <Map<String, dynamic>>[];
      _idToLatLng.clear();
      _idToData.clear();

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final merged = {...data, 'id': doc.id};

// ✅ 여기 추가: 카드/검색에서 쓸 “메뉴 타이틀” 미리 계산
        merged['__menuTitle'] = _menuTitleForItem(merged);

        items.add(merged);

        // gps -> marker position
        if (data['gps'] is GeoPoint) {
          final geo = data['gps'] as GeoPoint;
          final pos = LatLng(geo.latitude, geo.longitude);
          _idToLatLng[doc.id] = pos;
        }
        _idToData[doc.id] = merged;
      }

      if (!mounted) return;

      setState(() {
        _historyItems = items;
      });

      // ✅ apply current filters and rebuild markers
      _applyAllFiltersAndRebuild();

      // ✅ optional: 처음 한 개가 있으면 지도 포커스
      if (_filteredItems.isNotEmpty) {
        final id = (_filteredItems.first['id'] ?? '').toString();
        if (id.isNotEmpty) _focusToItem(id);
      }
    } catch (e) {
      debugPrint('Firestore error: $e');
    }
  }

  // ---------- map helpers ----------
  Future<void> _focusToItem(String id) async {
    final controller = _mapController;
    final pos = _idToLatLng[id];
    if (controller == null || pos == null) return;

    setState(() => _selectedId = id);

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 16)),
    );
    await controller.showMarkerInfoWindow(MarkerId(id));
  }

  void _shareLocation(Map<String, dynamic> data) {
    final geoPoint = data['gps'] as GeoPoint?;
    if (geoPoint == null) return;

    final url = 'https://maps.google.com/?q=${geoPoint.latitude},${geoPoint.longitude}';
    final message = '${data['restaurantName'] ?? ''}\n\n$url';
    Share.share(message);
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    if (_isDarkMode) {
      final darkMapStyle =
      await rootBundle.loadString('assets/map_styles/dark_mode.json');
      controller.setMapStyle(darkMapStyle);
    } else {
      controller.setMapStyle(null);
    }
  }

  // ---------- filter core ----------
  DateTime? _parseTs(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  String _norm(dynamic v) => (v ?? '').toString().trim();

  String? _extractJsonObjectFromText(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    // ```json ... ``` 코드블럭 제거
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
      s = s.replaceAll(RegExp(r'\s*```$'), '');
      s = s.trim();
    }

    // 앞에 RECOMMEND/기타 텍스트가 붙어 있어도 첫 '{'부터
    final start = s.indexOf('{');
    if (start < 0) return null;

    // 마지막 '}'까지
    final end = s.lastIndexOf('}');
    if (end < 0 || end <= start) return null;

    final candidate = s.substring(start, end + 1).trim();
    if (!candidate.startsWith('{') || !candidate.endsWith('}')) return null;

    return candidate;
  }

  List<String> _normalizeResponsesFromItem(Map<String, dynamic> item) {
    final rawList = item['responses'];
    final rawSingle = item['response'];

    if (rawList is List) {
      return rawList.map((e) => e.toString()).toList();
    }
    if (rawSingle != null) {
      return [rawSingle.toString()];
    }
    return const [];
  }

  String? _extractFirstRecommendedTranslated(List<String> responses) {
    for (final r in responses) {
      final jsonStr = _extractJsonObjectFromText(r);
      if (jsonStr == null) continue;

      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          final rec = decoded['recommended'];
          if (rec is List && rec.isNotEmpty && rec.first is Map) {
            final m = Map<String, dynamic>.from(rec.first as Map);

            final translated = (m['name'] ?? '').toString().trim();        // ✅ 번역명 우선
            final original = (m['nameOriginal'] ?? '').toString().trim();  // fallback

            if (translated.isNotEmpty) return translated;
            if (original.isNotEmpty) return original;
          }
        }
      } catch (_) {
        // ignore
      }
    }
    return null;
  }

  String? _extractFirstNumberedMenuFromText(List<String> responses) {
    final joined = responses.join('\n').replaceAll('\r', '');
    final lines = joined.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final m = RegExp(r'^\s*1\s*[\.\)\]\:\-]\.?\s*').firstMatch(line);
      if (m != null) {
        var first = line.substring(m.end).trim();

        // 꼬리 컷
        for (final t in const [' - ', ' – ', ' — ', ': ', '(', '[', '|']) {
          final idx = first.indexOf(t);
          if (idx > 0) first = first.substring(0, idx).trim();
        }

        // 뒤에 가격/숫자 제거
        first = first.replaceAll(RegExp(r'\s*[0-9][0-9,\.\s]*$'), '').trim();

        if (first.length >= 2) return first;
        break;
      }
    }
    return null;
  }

  String _menuTitleForItem(Map<String, dynamic> item) {
    // 1) JSON recommended[0].name (번역명)
    final responses = _normalizeResponsesFromItem(item);
    final fromJson = _extractFirstRecommendedTranslated(responses);
    if (fromJson != null && fromJson.isNotEmpty) return fromJson;

    // 2) 이미 저장된 대표 메뉴 필드가 있다면 사용
    final direct = _norm(item['primary_menu'] ?? item['menu_name'] ?? item['menuName']);
    if (direct.isNotEmpty) return direct;

    // 3) 구버전 텍스트에서 1번 메뉴 추출
    final fromText = _extractFirstNumberedMenuFromText(responses);
    if (fromText != null && fromText.isNotEmpty) return fromText;

    // 4) 최후 fallback: restaurant
    final restaurant = _norm(item['restaurantName']);
    return restaurant.isNotEmpty ? restaurant : (AppLocalizations.of(context)?.map_unknown ?? 'Unknown');
  }

  void _applyAllFiltersAndRebuild() {
    // 1) search filter
    List<Map<String, dynamic>> list = _historyItems.where((item) {
      if (_searchText.isEmpty) return true;

      final q = _searchText.toLowerCase();
      final restaurant = _norm(item['restaurantName']).toLowerCase();
      final country = _norm(item['country']).toLowerCase();
      final cuisine = _norm(item['cuisine']).toLowerCase();
      final menuName = _norm(item['__menuTitle']).toLowerCase();

      return restaurant.contains(q) ||
          country.contains(q) ||
          cuisine.contains(q) ||
          menuName.contains(q);
    }).toList();

    // 2) bottom sheet filters: cuisine/location/date
    if (_selectedCuisine != null && _selectedCuisine!.isNotEmpty) {
      list = list.where((e) => _norm(e['cuisine']) == _selectedCuisine).toList();
    }

    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      // country 또는 city를 location으로 보고 필터
      final loc = _selectedLocation!;
      list = list.where((e) {
        final country = _norm(e['country']);
        final city = _norm(e['city']); // 있으면 사용
        return country == loc || city == loc;
      }).toList();
    }

    if (_selectedDateRange != null) {
      final start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23,
        59,
        59,
      );

      list = list.where((e) {
        final dt = _parseTs(e['timestamp']);
        if (dt == null) return false;
        return !dt.isBefore(start) && !dt.isAfter(end);
      }).toList();
    }

    // 3) sorting: recent/topRated
    if (_activeFilter == _FilterType.topRated) {
      list.sort((a, b) {
        final ra = (a['rate'] as num?)?.toDouble() ?? 0.0;
        final rb = (b['rate'] as num?)?.toDouble() ?? 0.0;
        // 평점 같으면 최신순
        final tA = _parseTs(a['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = _parseTs(b['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final c = rb.compareTo(ra);
        return c != 0 ? c : tB.compareTo(tA);
      });
    } else {
      // recent default
      list.sort((a, b) {
        final tA = _parseTs(a['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = _parseTs(b['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });
    }

    // 4) rebuild markers (only filtered ids)
    final Set<Marker> markers = {};
    for (final item in list) {
      final id = _norm(item['id']);
      if (id.isEmpty) continue;

      final pos = _idToLatLng[id];
      if (pos == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: pos,
          onTap: () => setState(() => _selectedId = id),
          infoWindow: InfoWindow(
            title: _norm(item['restaurantName']).isEmpty
                ? AppLocalizations.of(context)?.map_noTitle ?? 'No Title'
                : _norm(item['restaurantName']),
            snippet: AppLocalizations.of(context)?.shareLocation ?? 'Share location',
            onTap: () => _shareLocation(item),
          ),
        ),
      );
    }

    setState(() {
      _filteredItems = list;
      _markers = markers;

      // 선택된 아이디가 필터로 사라졌으면 해제
      if (_selectedId != null && !_filteredItems.any((e) => _norm(e['id']) == _selectedId)) {
        _selectedId = null;
      }
    });
  }

  // ---------- bottom sheets ----------
  List<String> _getDistinctValues(String key) {
    final set = <String>{};
    for (final e in _historyItems) {
      final v = _norm(e[key]);
      if (v.isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _openCuisineSheet() async {
    final options = _getDistinctValues('cuisine');
    if (options.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OptionSheet(
        title: AppLocalizations.of(context)?.map_cuisine ?? 'Cuisine',
        current: _selectedCuisine,
        options: options,
      ),
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedCuisine = picked.isEmpty ? null : picked);
      _applyAllFiltersAndRebuild();
      if (_filteredItems.isNotEmpty) {
        final id = _norm(_filteredItems.first['id']);
        if (id.isNotEmpty) _focusToItem(id);
      }
    }
  }

  Future<void> _openLocationSheet() async {
    // country + city 둘 다 합치기
    final set = <String>{};
    for (final e in _historyItems) {
      final c = _norm(e['country']);
      final city = _norm(e['city']);
      if (c.isNotEmpty) set.add(c);
      if (city.isNotEmpty) set.add(city);
    }
    final options = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (options.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OptionSheet(
        title: AppLocalizations.of(context)?.map_location ?? 'Location',
        current: _selectedLocation,
        options: options,
      ),
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedLocation = picked.isEmpty ? null : picked);
      _applyAllFiltersAndRebuild();
      if (_filteredItems.isNotEmpty) {
        final id = _norm(_filteredItems.first['id']);
        if (id.isNotEmpty) _focusToItem(id);
      }
    }
  }

  Future<void> _openDatePicker() async {
    final now = DateTime.now();
    final initial = _selectedDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      builder: (context, child) {
        final isDark = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _applyAllFiltersAndRebuild();
      if (_filteredItems.isNotEmpty) {
        final id = _norm(_filteredItems.first['id']);
        if (id.isNotEmpty) _focusToItem(id);
      }
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCuisine = null;
      _selectedLocation = null;
      _selectedDateRange = null;
      _activeFilter = _FilterType.recent;
    });
    _applyAllFiltersAndRebuild();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    _isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;
    final bg = _isDarkMode ? CupertinoColors.black : const Color(0xFFF6F7FB);
    final pageBg = _isDarkMode
        ? CupertinoColors.black
        : const Color(0xFFEFEFF4); // ✅ 여기로 통일

    // layout constants
    const double topControlsHeight = 120;
    const double bottomCardsHeight = 210;

    // 작은 “필터 상태” 표기 (원하면 제거 가능)
    final hasExtraFilter =
        (_selectedCuisine != null) || (_selectedLocation != null) || (_selectedDateRange != null);

    return CupertinoPageScaffold(
      backgroundColor: pageBg,
      child: Stack(
        children: [
          // MAP
          Positioned.fill(
            top: topControlsHeight,
            bottom: bottomCardsHeight - 30,
            child: _locationLoaded
                ? ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14),
                markers: _markers,
                onMapCreated: _onMapCreated,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),
            )
                : const Center(child: CupertinoActivityIndicator()),
          ),

          // TOP CONTROLS
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MScannerSearchField(
                    placeholder: AppLocalizations.of(context)?.map_searchHistory ?? 'Search History',
                    onChanged: (v) {
                      setState(() => _searchText = v);
                      _applyAllFiltersAndRebuild();
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              MScannerPillChip(
                                label: AppLocalizations.of(context)?.map_recent ?? 'Recent',
                                selected: _activeFilter == _FilterType.recent,
                                scheme: MScannerAccent.orange, // ✅ 여기만 오렌지로
                                onTap: () {
                                  setState(() => _activeFilter = _FilterType.recent);
                                  _applyAllFiltersAndRebuild();
                                  if (_filteredItems.isNotEmpty) {
                                    final id = _norm(_filteredItems.first['id']);
                                    if (id.isNotEmpty) _focusToItem(id);
                                  }
                                },
                              ),
                              MScannerPillChip(
                                label: AppLocalizations.of(context)?.map_topRated ?? 'Top Rated',
                                selected: _activeFilter == _FilterType.topRated,
                                scheme: MScannerAccent.orange, // ✅ 여기만 오렌지로
                                onTap: () {
                                  setState(() => _activeFilter = _FilterType.topRated);
                                  _applyAllFiltersAndRebuild();
                                  if (_filteredItems.isNotEmpty) {
                                    final id = _norm(_filteredItems.first['id']);
                                    if (id.isNotEmpty) _focusToItem(id);
                                  }
                                },
                              ),

                              MScannerPillChip(
                                label: AppLocalizations.of(context)?.map_date ?? 'Date',
                                selected: _selectedDateRange != null,
                                scheme: MScannerAccent.orange, // ✅ 여기만 오렌지로
                                onTap: _openDatePicker,
                              ),
                              MScannerPillChip(
                                label: AppLocalizations.of(context)?.map_location ?? 'Location',
                                selected: _selectedLocation != null,
                                scheme: MScannerAccent.orange, // ✅ 여기만 오렌지로
                                onTap: _openLocationSheet,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (hasExtraFilter)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: GestureDetector(
                            onTap: _clearAllFilters,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isDarkMode
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.map_clear ?? 'Clear',
                                style: TextStyle(
                                  color: _isDarkMode ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM CARDS
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            height: bottomCardsHeight,
            child: _filteredItems.isEmpty
                ? Center(
              child: Text(
                AppLocalizations.of(context)?.map_noResults ?? 'No results',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final id = _norm(item['id']);
                final selected = id.isNotEmpty && id == _selectedId;

                return _HistoryCard(
                  data: item,
                  selected: selected,
                  onTap: () {
                    if (id.isNotEmpty) _focusToItem(id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// ---------- bottom sheet option list ----------
class _OptionSheet extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.current,
  });

  final String title;
  final List<String> options;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final isDark = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;
    final bg = isDark ? const Color(0xFF111113) : Colors.white;
    final accent = MScannerSearchUi.accent(context, scheme: MScannerAccent.orange);

    return SafeArea(
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, ''), // clear this filter
                  child: Text(AppLocalizations.of(context)?.map_clear ?? 'Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                itemBuilder: (context, i) {
                  final v = options[i];
                  final selected = v == current;

                  return ListTile(
                    dense: true,
                    title: Text(
                      v,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: accent)
                        : null,
                    onTap: () => Navigator.pop(context, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- chip ----------
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    final bg = selected
        ? const Color(0xFF2D6CDF)
        : (isDark ? CupertinoColors.systemGrey.withOpacity(0.22) : const Color(0xFFE9F0FA));

    final fg = selected ? Colors.white : (isDark ? Colors.white : const Color(0xFF2D4B6A));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.12)
                  : (isDark ? CupertinoColors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06)),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- card ----------
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.data,
    required this.onTap,
    required this.selected,
  });

  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (data['image_url'] ?? '').toString();
    final title = (data['__menuTitle'] ?? data['menuName'] ?? data['primary_menu'] ?? data['restaurantName'] ?? 'Unknown').toString();
    final restaurant = (data['restaurantName'] ?? '').toString();
    final dateText = _formatDate(data['timestamp']);
    final rating = (data['rate'] as num?)?.toDouble() ?? 4.0;

    final isDark = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final metaColor = isDark ? Colors.white60 : Colors.black45;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.45) : const Color(0x14000000),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: selected
                ? const Color(0xFF2D6CDF).withOpacity(isDark ? 0.9 : 0.8)
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.transparent),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl.startsWith('http')
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: isDark ? Colors.white.withOpacity(0.06) : CupertinoColors.systemGrey5,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? Colors.white.withOpacity(0.06) : CupertinoColors.systemGrey5,
                    child: Icon(CupertinoIcons.photo, color: metaColor),
                  ),
                )
                    : Container(
                  color: isDark ? Colors.white.withOpacity(0.06) : CupertinoColors.systemGrey5,
                  child: Icon(CupertinoIcons.photo, color: metaColor),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            if (restaurant.isNotEmpty)
              Text(
                restaurant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 12,
                    color: metaColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) {
                  final filled = index < rating.round();
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF8B637),
                      size: 16,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? dt;
    if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    } else if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    }
    if (dt == null) return '';
    return DateFormat('MMM d').format(dt);
  }
}