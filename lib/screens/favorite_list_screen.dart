import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'favorite_screen.dart'; // ✅ FavoriteScreen을 사용하므로 유지
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class FavoriteListScreen extends StatefulWidget {
  @override
  _FavoriteListScreenState createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  List<DocumentSnapshot> _favoriteResults = [];
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode ? Colors.black : Color(0xFFEFEFF4);
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
              padding: const EdgeInsets.only(top: 10), // 버튼 높이만큼 위에 여백 줌
              child: _favoriteResults.isEmpty
                  ? Center(child: Text(
                  'No History Found', style: TextStyle(color: textColor)))
                  : ListView.builder(
                itemCount: _favoriteResults.length,
                itemBuilder: (context, index) {
                  final data = _favoriteResults[index].data() as Map<
                      String,
                      dynamic>;

                  return Dismissible(
                    key: Key(_favoriteResults[index].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      child: Icon(
                        CupertinoIcons.delete,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteFavoriteResult(index);
                    },
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: CachedNetworkImage(
                            imageUrl: data['image_url'] ?? '',
                            placeholder: (_, __) =>
                                CupertinoActivityIndicator(),
                            errorWidget: (_, __, ___) => Icon(Icons.error),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['timestamp'] != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(
                                DateTime.parse(data['timestamp']))
                                : 'No date',
                            style: TextStyle(color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            data['country'] ?? 'Unknown Country',
                            style: TextStyle(color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FavoriteScreen(
                                    documentId: _favoriteResults[index].id),
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
              right: isRTL ? null : 14,
              left: isRTL ? 14 : null,
              child: Container(
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.black : const Color(0xFFEFEFF4),

                  borderRadius: BorderRadius.circular(10),

                ),
                child: IconButton(
                  icon: Icon(
                    CupertinoIcons.list_bullet,
                    color: textColor,
                    size: 28,
                  ),
                  padding: EdgeInsets.all(4), // 패딩 최소화
                  constraints: BoxConstraints(), // 버튼 크기 최소화
                  onPressed: _showSortingOptions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
