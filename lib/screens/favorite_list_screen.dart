import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'favorite_screen.dart'; // ✅ FavoriteScreen을 사용하므로 유지
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/animated_map_screen.dart'; // ← 추가
import '../models/place_data.dart'; // ← 추가

class FavoriteListScreen extends StatefulWidget {
  @override
  _FavoriteListScreenState createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  List<DocumentSnapshot> _favoriteResults = [];
  Set<String> _selectedIds = {}; // ← 추가
  bool _isDarkMode = false;
  String _currentSort = 'latest'; // 기본 정렬: 최신순

  @override
  void initState() {
    super.initState();
    _checkDarkMode();
    _loadFavoriteResults();
  }

  Future<void> _checkDarkMode() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    setState(() {
      _isDarkMode = savedThemeMode == AdaptiveThemeMode.dark;
    });
  }

  Future<void> _loadFavoriteResults() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot querySnapshot;

    if (_currentSort == 'latest') {
      querySnapshot = await FirebaseFirestore.instance
          .collection('user_rating')
          .doc(user.uid)
          .collection('data')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();
    } else {
      querySnapshot = await FirebaseFirestore.instance
          .collection('user_rating')
          .doc(user.uid)
          .collection('data')
          .orderBy('country', descending: false)
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();
    }

    setState(() {
      _favoriteResults = querySnapshot.docs;
      _selectedIds.clear(); // 새로 로드 시 선택 초기화
    });
  }

  void _showSortingOptions() {
    final textColor = _isDarkMode ? Colors.white : Colors.black;
    final localizations = AppLocalizations.of(context);
    showCupertinoModalPopup(
      context: context,
      builder: (context) =>
          CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                isDefaultAction: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.clock, color: textColor),
                    SizedBox(width: 8),
                    Text(localizations?.viewbylatest ?? 'View by latest',
                        style: TextStyle(color: textColor)),

                  ],
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSort = 'latest';
                    _loadFavoriteResults();
                  });
                },
              ),
              CupertinoActionSheetAction(
                isDefaultAction: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.globe, color: textColor),
                    SizedBox(width: 8),
                    Text(localizations?.viewbycountry ?? 'View by country',
                        style: TextStyle(color: textColor)),
                  ],
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSort = 'country';
                    _loadFavoriteResults();
                  });
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: Text('Cancel', style: TextStyle(color: textColor)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
    );
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
    final backgroundColor = _isDarkMode ? Colors.black : const Color(
        0xFFEFEFF4);
    final textColor = _isDarkMode ? Colors.white : Colors.black;

    final locale = Localizations.localeOf(context);
    final rtlLanguageCodes = ['ar', 'ur'];
    final isRTL = rtlLanguageCodes.contains(locale.languageCode.toLowerCase());

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // 리스트
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _favoriteResults.isEmpty
                  ? Center(
                child: Text(
                  'No History Found',
                  style: TextStyle(color: textColor),
                ),
              )
                  : ListView.builder(
                itemCount: _favoriteResults.length,
                itemBuilder: (context, index) {
                  final doc = _favoriteResults[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isSelected = _selectedIds.contains(doc.id);

                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      child: const Icon(
                        CupertinoIcons.delete,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    onDismissed: (_) => _deleteFavoriteResult(index),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: CachedNetworkImage(
                            imageUrl: data['image_url'] ?? '',
                            placeholder: (_, __) =>
                            const CupertinoActivityIndicator(),
                            errorWidget: (_, __, ___) =>
                            const Icon(Icons.error),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(
                        data['restaurantName'] ?? 'No Restaurant Name',
                        style: TextStyle(color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          // 왼쪽 텍스트: 부모의 가용 너비만큼 차지, 필요 시 ellipsis
                          Expanded(
                            child: Text(
                              data['timestamp'] != null
                                  ? DateFormat('yyyy-MM-dd HH:mm')
                                  .format(DateTime.parse(data['timestamp']))
                                  : 'No date',
                              style: TextStyle(color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 8), // 두 텍스트 사이 여백

                          // 오른쪽 텍스트: 마찬가지로 가용 너비만큼 차지
                          Expanded(
                            child: Text(
                              data['country'] ?? 'Unknown Country',
                              style: TextStyle(color: textColor),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true)
                              _selectedIds.add(doc.id);
                            else
                              _selectedIds.remove(doc.id);
                          });
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FavoriteScreen(
                                  documentId: doc.id,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // 정렬 버튼 (겹치도록 배치)
            Positioned(
              top: -15,
              right: isRTL ? null : 16,
              left: isRTL ? 14 : null,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(
                    CupertinoIcons.list_bullet,
                    color: textColor,
                    size: 28,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: _showSortingOptions,
                ),
              ),
            ),

            // 선택된 항목이 있을 때만 노출되는 "지도에서 보기" 버튼
            if (_selectedIds.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: ElevatedButton.icon(
                  onPressed: _goToAnimatedMap,
                  icon: const Icon(Icons.map),
                  label: const Text('선택한 장소 지도에서 보기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,            // 텍스트/아이콘 색
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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