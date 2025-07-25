import 'dart:io'; // 플랫폼을 감지하기 위해 dart:io 패키지 추가
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import '/helpers/settings_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Home_Screen.dart';
import 'PresetSelectionScreen.dart'; // PresetSelectionScreen import 추가
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import '/screens/Login_Screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 패키지 추가
import '/widgets/test_purchase_widget.dart'; // 추가된 위젯 import
import 'package:provider/provider.dart';
import '/ad_remove_provider.dart'; // 경로에 따라 수정 필요

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  TextEditingController _currentPasswordController = TextEditingController();
  TextEditingController _newPasswordController = TextEditingController();
  bool _isDarkMode = false;
  bool _isPasswordChangeVisible = false;
  bool _isCloudSaveEnabled = true; // 클라우드 저장 기본 활성화
  String _selectedEngine = 'GPT-4o';
  String _appVersion = '1.0.0'; // 기본 버전
  User? user;
  int _userPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchUserProfile();
    _fetchAppVersion(); // 앱 버전 불러오기
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 클라우드 저장 상태 로드
    bool cloudSaveEnabled = prefs.getBool('cloudSaveEnabled') ?? true;

    // 테마 상태 로드
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    bool isDarkMode = savedThemeMode == AdaptiveThemeMode.dark;

    // 엔진 설정 로드
    String selectedEngine = await SettingsHelper.getSelectedEngine() ?? 'GPT-4o';

    // 상태 업데이트
    setState(() {
      _isCloudSaveEnabled = cloudSaveEnabled;
      _isDarkMode = isDarkMode;
      _selectedEngine = selectedEngine;
    });

    // 클라우드 저장 상태가 로드된 후에 바로 활성화
    if (_isCloudSaveEnabled) {
      _toggleCloudSave(_isCloudSaveEnabled, initialLoad: true);
    }
  }

  Future<void> _fetchUserProfile() async {
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userPointsDoc = await FirebaseFirestore.instance
          .collection('user_points')
          .doc(user!.uid)
          .get();

      if (userPointsDoc.exists) {
        setState(() {
          _userPoints = userPointsDoc.get('points') ?? 0;
        });
      } else {
        setState(() {
          _userPoints = 0;
        });
      }
    }
  }

  Future<void> _toggleCloudSave(bool value, {bool initialLoad = false}) async {
    setState(() {
      _isCloudSaveEnabled = value;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloudSaveEnabled', _isCloudSaveEnabled);

    // 초기 로드 시에는 클라우드 저장을 바로 활성화하지 않고 상태만 설정
    if (!initialLoad) {
      if (_isCloudSaveEnabled) {
        // 클라우드 저장 활성화 로직 (필요 시 추가)
      } else {
        // 클라우드 저장 비활성화 로직 (필요 시 추가)
      }
    }
  }

  Future<void> _changePassword() async {
    try {
      User user = FirebaseAuth.instance.currentUser!;
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.passwordChangedSuccess ?? 'Password changed successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.failedChangePassword ?? 'Failed to change password: $e')),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final localizations = AppLocalizations.of(context);

    showCupertinoDialog( // 변경: showDialog -> showCupertinoDialog
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(localizations?.confirmDelete ?? 'Confirm Delete'),
          content: Text(localizations?.areYouSureDeleteAccount ?? 'Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text(localizations?.cancel ?? 'Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: Text(localizations?.deleteAccount ?? 'Delete'),
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.accountDeleted ?? 'Account deleted successfully.')),
        );
        await FirebaseAuth.instance.signOut(); // 계정 삭제 후 로그아웃 수행
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.failedDeleteAccount ?? 'No user signed in or user already deleted.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.requiresRecentLogin ?? 'Please log in again and try deleting the account.')),
        );
      } else if (FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.accountDeleted ?? 'Account deleted successfully.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.failedDeleteAccount ?? 'Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    if (user != null && user!.isAnonymous) {
      // 게스트 사용자일 경우 Cupertino 스타일 다이얼로그로 변경
      final localizations = AppLocalizations.of(context);

      bool? confirmLogout = await showCupertinoDialog<bool>( // 변경: showDialog -> showCupertinoDialog
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(localizations?.logoutConfirmationTitle ?? 'Logout Confirmation'),
          content: Text(localizations?.logoutConfirmationContent ?? 'Logging out as a guest will delete all your data. Do you want to proceed?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations?.logout ?? 'Logout'),
              isDestructiveAction: true,
            ),
          ],
        ),
      );

      if (confirmLogout != null && confirmLogout) {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } else {
      // 일반 사용자일 경우 기존 로그아웃 동작 유지
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  void _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });

    if (value) {
      AdaptiveTheme.of(context).setDark();
    } else {
      AdaptiveTheme.of(context).setLight();
    }
  }

  void _onEngineSelected(String? value) {
    setState(() {
      _selectedEngine = value!;
    });
    SettingsHelper.saveSelectedEngine(_selectedEngine);
  }

  void _resetPreset() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PresetSelectionScreen()),
    );
  }

  // **계정 전환 기능 추가**
  Future<void> _convertAccount() async {
    final localizations = AppLocalizations.of(context);
    TextEditingController _conversionEmailController = TextEditingController();
    TextEditingController _conversionPasswordController = TextEditingController();
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    await showCupertinoDialog( // 변경: showDialog -> showCupertinoDialog
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(localizations?.convertAccount ?? 'Convert Account'),
        content: Column(
          children: [
            SizedBox(height: 10), // 추가: 내용과 텍스트필드 간격 조정
            CupertinoTextField(
              controller: _conversionEmailController,
              placeholder: 'Email',
              placeholderStyle: TextStyle(
                // Light 모드: 진한 회색, Dark 모드: 연한 회색
                color: isDark ? CupertinoColors.systemGrey : CupertinoColors.placeholderText,
                fontSize: 14,
                fontFamily: 'SFProText',
              ),
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 14,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.systemGrey5.darkColor
                    : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            SizedBox(height: 10),
            CupertinoTextField(
              controller: _conversionPasswordController,
              placeholder: 'Password',
              placeholderStyle: TextStyle(
                // Light 모드: 진한 회색, Dark 모드: 연한 회색
                color: isDark ? CupertinoColors.systemGrey : CupertinoColors.placeholderText,
                fontSize: 14,
                fontFamily: 'SFProText',
              ),
              obscureText: true,
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 14,
                color: MediaQuery.of(context).platformBrightness == Brightness.dark
                    ? CupertinoColors.white
                    : CupertinoColors.black,
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: MediaQuery.of(context).platformBrightness == Brightness.dark
                    ? CupertinoColors.systemGrey5.darkColor
                    : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              String email = _conversionEmailController.text.trim();
              String password = _conversionPasswordController.text.trim();

              try {
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null && user.isAnonymous) {
                  AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
                  UserCredential userCredential = await user.linkWithCredential(credential);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localizations?.accountConversionSuccess ?? 'Account successfully converted.')),
                  );

                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  _navigateAfterSignIn(userCredential.user);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)?.accountConversionFailed ?? 'Account conversion failed: $e')),
                );
              }
            },
            child: Text(localizations?.convertAccount ?? 'Convert'),
          ),
        ],
      ),
    );
  }

  // **_navigateAfterSignIn 메서드 추가**
  Future<void> _navigateAfterSignIn(User? user) async {
    if (user == null) return;

    bool isFirstLogin = user.metadata.creationTime == user.metadata.lastSignInTime;

    if (isFirstLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PresetSelectionScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final Color backgroundColor = _isDarkMode ? CupertinoColors.black : Color(0xFFEFEFF4);
    final Color textColor = _isDarkMode ? CupertinoColors.white : CupertinoColors.black;
    final Color dropdownColor = _isDarkMode ? Colors.grey[900]! : Colors.white;
    final isAdRemoved = context.watch<AdRemoveProvider>().isAdRemoved;

    bool isGuest = user != null && user!.isAnonymous;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: null, // title 텍스트 제거
        backgroundColor: backgroundColor,
        leading: SizedBox.shrink(), // 빈 공간으로 대체하여 뒤로 가기 버튼 숨기기
        border: null, // 줄 제거

        trailing: Text(
          'v$_appVersion', // 앱 버전 표시
          style: TextStyle(
            fontFamily: 'SFProText',
            fontSize: 14,
            color: textColor,
          ),
        ),
      ),
      backgroundColor: backgroundColor,
      child: ListView(
        children: [
          CupertinoFormSection.insetGrouped(
            backgroundColor: backgroundColor,
            header: Text(
              localizations?.account ?? 'Account', // 계정 섹션 제목
              style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
            ),
            children: [
              CupertinoFormRow(
                prefix: CircleAvatar(
                  radius: 18,
                  backgroundColor: isGuest ? Colors.blue[300] : null,
                  child: isGuest
                      ? Text(
                    'GUEST',
                    style: TextStyle(
                      fontSize: 9,
                      color: _isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                    ),
                  )
                      : null,
                  backgroundImage: isGuest ? null : NetworkImage(user?.photoURL ?? 'https://via.placeholder.com/150'),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 8), // 프로필 사진과 텍스트 사이에 약간의 간격 추가
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                       // Text(
                       //   localizations?.hello ?? 'Hello, ${user?.displayName ?? 'User'}',
                       //   style: TextStyle(
                       //     color: textColor,
                       //     fontWeight: FontWeight.bold,
                       //     fontSize: 14,
                       //   ),
                       // ),
                        //Text( //(포인트 기능 출시 위한 미구현)
                        // '${_userPoints} points',
                        //style: TextStyle(
                        // color: _isDarkMode ? Colors.white70 : Colors.black54,
                        // fontSize: 12,
                        // ),
                        //),
                      ],
                    ),
                    Spacer(), // 로그아웃 버튼을 오른쪽 끝으로 밀기 위해 Spacer 사용
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            CupertinoIcons.square_arrow_right,
                            color: _isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                            size: 24,
                          ),
                          onPressed: _logout,
                        ),
                        Text(
                          localizations?.logout ?? 'Logout',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 10, // 텍스트 크기 작게 설정
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 30.0), // 좌우 패딩 설정 (포인트와 같이 출시위한 임시 비활성화
          //   child: Text(
          //     localizations?.activepoint ?? 'The points display the user activity index, and various rewards will be provided in the future.',
          //     style: TextStyle(
          //       fontFamily: 'SFProText',
          //       fontSize: 12,
          //       color: _isDarkMode ? Colors.white24 : Colors.black45,
          //     ),
          //   ),
          // ),
          CupertinoFormSection.insetGrouped(
            backgroundColor: backgroundColor,
            header: Text(localizations?.display ?? 'Display', style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor)),
            children: [
              CupertinoFormRow(
                prefix: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    CupertinoIcons.moon,
                    color: textColor,
                    size: 20.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations?.darkMode ?? 'Dark Mode',
                      style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
                    ),
                    CupertinoSwitch(
                      value: _isDarkMode,
                      onChanged: _toggleDarkMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0), // 좌우 패딩 설정
            child: Text(
              localizations?.darkdescp ?? 'Enable dark mode for a more comfortable viewing experience', // 설명 텍스트, 원하는 내용으로 수정하세요
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 12,
                color: _isDarkMode ? Colors.white24 : Colors.black45,
              ),
            ),
          ),

          // **Security 섹션을 게스트일 경우 숨기기**
          if (!isGuest)
            CupertinoFormSection.insetGrouped(
              backgroundColor: backgroundColor,
              header: Text(localizations?.security ?? 'Security', style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor)),
              children: [
                CupertinoFormRow(
                  prefix: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      CupertinoIcons.lock,
                      color: textColor,
                      size: 20.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localizations?.changePassword ?? 'Change Password',
                        style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
                      ),
                      CupertinoSwitch(
                        value: _isPasswordChangeVisible,
                        onChanged: (value) {
                          setState(() {
                            _isPasswordChangeVisible = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                if (_isPasswordChangeVisible)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: _currentPasswordController,
                          placeholder: localizations?.password ?? 'Current Password',
                          obscureText: true,
                          style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? CupertinoColors.darkBackgroundGray : CupertinoColors.lightBackgroundGray,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _newPasswordController,
                          placeholder: localizations?.newPassword ?? 'New Password',
                          obscureText: true,
                          style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? CupertinoColors.darkBackgroundGray : CupertinoColors.lightBackgroundGray,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        SizedBox(height: 16),
                        CupertinoButton(
                          child: Text(
                            localizations?.changePassword ?? 'Change Password',
                            style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: CupertinoColors.white),
                          ),
                          onPressed: _changePassword,
                          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.blue, // 원하는 색상으로 변경
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (!isGuest)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0), // 좌우 패딩 설정
              child: Text(
                localizations?.changepassdescp ?? 'For security, regularly change your password and use a strong password that is easy to remember', // 설명 텍스트, 원하는 내용으로 수정하세요
                style: TextStyle(
                  fontFamily: 'SFProText',
                  fontSize: 12,
                  color: _isDarkMode ? Colors.white24 : Colors.black45,
                ),
              ),
            ),

          CupertinoFormSection.insetGrouped(
            backgroundColor: backgroundColor,
            header: Text(localizations?.aiSetting ?? 'AI Setting', style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor)),
            children: [
              CupertinoFormRow(
                prefix: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    CupertinoIcons.slider_horizontal_below_rectangle,
                    color: textColor,
                    size: 20.0,
                  ),
                ),
                child: CupertinoButton(
                  child: Text(localizations?.changepreset ?? 'Change preset', style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor)),
                  onPressed: _resetPreset,
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                ),
              ),
            ],
          ),
          // Reset Preset 섹션 밖에 텍스트 추가
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0), // 좌우 패딩 설정
            child: Text(
              localizations?.aIresetdescp ?? 'You can reset the AI scan settings', // 설명 텍스트, 원하는 내용으로 수정하세요
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 12,
                color: _isDarkMode ? Colors.white24 : Colors.black45,
              ),
            ),
          ),
// ─ Premium 섹션 ─
    if (false) ...[
          if (!isGuest)
            CupertinoFormSection.insetGrouped(
              backgroundColor: backgroundColor,
              header: Text(
                'Premium',
                style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
              ),
              children: const [
                TestPurchaseWidget(),
              ],
            )
          else
            CupertinoFormSection.insetGrouped(
              backgroundColor: backgroundColor,
              header: Text(
                'Premium',
                style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
              ),
              children: [
                CupertinoFormRow(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: Text(
                      AppLocalizations.of(context)!.guestPurchaseMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                ),
              ],
            ),
],

          CupertinoFormSection.insetGrouped(
            backgroundColor: backgroundColor,
            header: Text(localizations?.server ?? 'Server', style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor)),
            children: [
              CupertinoFormRow(
                prefix: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    CupertinoIcons.cloud_upload,
                    color: textColor,
                    size: 20.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations?.cloudSave ?? 'Cloud Save',
                      style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: textColor),
                    ),
                    CupertinoSwitch(
                      value: _isCloudSaveEnabled,
                      onChanged: _toggleCloudSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Cloud Saving 섹션 밖에 텍스트 추가
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0), // 좌우 패딩 설정
            child: Text(
              localizations?.savedescp ?? 'Save the output data to the server. Saving is required to enable additional features', // 설명 텍스트, 원하는 내용으로 수정하세요
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 12,
                color: _isDarkMode ? Colors.white24 : Colors.black45,
              ),
            ),
          ),
          SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isGuest
                ? CupertinoButton(
              child: Text(
                localizations?.convertAccount ?? 'Convert Account',
                style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: CupertinoColors.white),
              ),
              color: CupertinoColors.activeBlue,
              onPressed: _convertAccount,
              borderRadius: BorderRadius.circular(8.0),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            )
                : CupertinoButton(
              child: Text(
                localizations?.deleteAccount ?? 'Delete Account',
                style: TextStyle(fontFamily: 'SFProText', fontSize: 14, color: CupertinoColors.white),
              ),
              color: CupertinoColors.destructiveRed,
              onPressed: _confirmDeleteAccount,
              borderRadius: BorderRadius.circular(8.0),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}
