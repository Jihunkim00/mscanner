// main.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/screens/PresetSelectionScreen.dart';
import 'package:mscanner/screens/location_service.dart';
import 'firebase_options.dart';
import '/screens/Login_Screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'helpers/l10n.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getwidget/getwidget.dart';
import 'dart:io';
import 'dart:async';
import '/screens/Home_Screen.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '/screens/result_screen.dart';
import '/screens/result_screen_arguments.dart';
import '/screens/auth_service.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '/screens/log_service.dart';
import 'package:provider/provider.dart';
import 'ad_remove_provider.dart'; // 경로에 맞게 수정


// 전역 변수 선언
InterstitialAd? globalInterstitialAd;

// 전면 광고 사용 여부 설정
bool enableInterstitialAds = false; // true로 바꾸면 다시 사용됨


// 광고 로드 함수 정의
Future<void> loadInterstitialAd({bool nonPersonalized = false}) async {
  AdRequest request = nonPersonalized
      ? AdRequest(extras: {'npa': '1'})
      : AdRequest();

  // 플랫폼에 따른 광고 유닛 ID 설정
  String adUnitId;
  if (Platform.isIOS) {
    adUnitId = 'ca-app-pub-2942885230901008/8324808650'; // iOS 광고 유닛
  } else {
    adUnitId = 'ca-app-pub-2942885230901008/5920902942'; // Android 광고 유닛
  }

  InterstitialAd.load(
    adUnitId: adUnitId,
    request: request,
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) {
        print("전면 광고 로드 성공 ($adUnitId)");
        globalInterstitialAd = ad;
        globalInterstitialAd?.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                print("전면 광고 닫힘");
                ad.dispose();
                globalInterstitialAd = null;
                loadInterstitialAd(nonPersonalized: nonPersonalized);
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                print("전면 광고 표시 실패: $err");
                ad.dispose();
                globalInterstitialAd = null;
                loadInterstitialAd(nonPersonalized: nonPersonalized);
              },
            );
      },
      onAdFailedToLoad: (err) {
        print("전면 광고 로드 실패: $err");
        globalInterstitialAd = null;
        Future.delayed(Duration(seconds: 5), () {
          loadInterstitialAd(nonPersonalized: nonPersonalized);
        });
      },
    ),
  );
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocationService().requestPermission();
  await MobileAds.instance.initialize();

  final savedThemeMode = await AdaptiveTheme.getThemeMode() ?? AdaptiveThemeMode.light;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedLocale = prefs.getString('selectedLocale');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AdRemoveProvider(),
      child: MyApp(savedThemeMode: savedThemeMode, savedLocale: savedLocale),
    ),
  );


  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      // ✅ 화면 방향 고정은 postFrameCallback에서 MediaQuery가 사용 가능할 때 적용
      final context = WidgetsBinding.instance.focusManager.primaryFocus?.context;
      if (context != null) {
        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        if (!isTablet) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
      }

      // ✅ ATT 권한 요청 및 광고 초기화
      bool nonPersonalized = false;
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.requestTrackingAuthorization();
        if (status != TrackingStatus.authorized) {
          nonPersonalized = true;
        }
      }

      if (enableInterstitialAds) {
        await loadInterstitialAd(nonPersonalized: nonPersonalized);
      }

    } catch (e) {
      debugPrint("초기화 중 오류 발생: $e");
    }
  });
}



class MyApp extends StatelessWidget {
  final AdaptiveThemeMode savedThemeMode;
  final String? savedLocale;

  MyApp({required this.savedThemeMode, this.savedLocale});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      dark: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      initial: savedThemeMode,
      builder: (theme, darkTheme) => MaterialApp(
        title: 'Navigation App',
        theme: theme,
        darkTheme: darkTheme,
        locale: savedLocale != null ? Locale(savedLocale!) : null,
        supportedLocales: L10n.all,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: _getInitialScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/result_screen') {
            final args = settings.arguments;
            if (args is ResultScreenArguments) {
              return MaterialPageRoute(
                builder: (context) {
                  return ResultScreen(
                    image: args.image,
                    images: args.images,            // if you stored it in your args
                    responses: args.responses,
                    position: args.position,
                    captureTime: args.captureTime,
                    isFromHistory: args.isFromHistory,
                    title: args.title,
                    location: args.location,
                    geohash: args.geohash,
                    ragDetail: args.ragDetail,
                  );
                },
              );
            } else {
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: Text('Error')),
                  body: Center(child: Text('Invalid arguments for ResultScreen')),
                ),
              );
            }
          }
          return null;
        },
        routes: {
          '/login': (context) => LoginScreen(),
          '/home': (context) => HomeScreen(),

        },
      ),
    );
  }

  Widget _getInitialScreen() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return HomeScreen();
    } else {
      return IntroductionScreenPage();
    }
  }
}

class IntroductionScreenPage extends StatefulWidget {
  @override
  _IntroductionScreenPageState createState() => _IntroductionScreenPageState();
}

class _IntroductionScreenPageState extends State<IntroductionScreenPage> {
  final AuthService _authService = AuthService();

  Future<void> _signInAsGuest() async {
    try {
      User? user = await _authService.signInAnonymously();

      if (user != null) {
        await LogService().logLoginSuccess();

        await showCupertinoDialog(
          context: context,
          builder: (context) =>
              CupertinoAlertDialog(
                title: Text(AppLocalizations
                    .of(context)
                    ?.guestLoginTitle ?? 'Guest Login'),
                content: Text(AppLocalizations
                    .of(context)
                    ?.guestLoginContent ??
                    'You are logged in as a guest. All data will be deleted upon logout.'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations
                        .of(context)
                        ?.confirm ?? 'Confirm'),
                  ),
                ],
              ),
        );

        _navigateAfterSignIn(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations
              .of(context)
              ?.guestLoginFailed ?? 'Guest login failed. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations
            .of(context)
            ?.guestLoginFailed ?? 'Guest login failed. Please try again.')),
      );
      print('Guest sign-in error: $e');
    }
  }

  void _navigateAfterSignIn(User user) {
    bool isFirstLogin = user.metadata.creationTime ==
        user.metadata.lastSignInTime;

    if (isFirstLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => PresetSelectionScreen(isFirstLogin: true)),
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
    final mediaQuery = MediaQuery
        .of(context)
        .size;
    final localizations = AppLocalizations.of(context);
    final isDarkMode = AdaptiveTheme
        .of(context)
        .mode == AdaptiveThemeMode.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ GFImageOverlay 대신 기본 Container로 배경 이미지 설정
          Container(
            height: mediaQuery.height,
            width: mediaQuery.width,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  Platform.isIOS
                      ? 'assets/images/apple_sample.png'
                      : 'assets/images/android_sample.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ✅ 나머지 오버레이 요소들
          Positioned(
            top: mediaQuery.height * 0.88,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  label: '${localizations?.introductionTitle1 ??
                      'Introduction'} ${localizations?.languagesdescprition1 ??
                      ''}',
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: localizations?.introductionTitle1 ??
                              'Introduction',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: mediaQuery.height * 0.15,
            left: 20,
            right: 20,
            child: Text(
              localizations?.languagesdescprition ?? 'Description',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          Positioned(
            left: 20,
            bottom: 40,
            child: GFButton(
              onPressed: _signInAsGuest,
              text: localizations?.browse ?? 'Explore as a Guest',
              color: Colors.transparent,
              textStyle: TextStyle(
                fontFamily: 'SF Pro Display',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              type: GFButtonType.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
          ),

          Positioned(
            right: 20,
            bottom: 40,
            child: GFButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              text: localizations?.login ?? 'Login',
              color: Colors.transparent,
              textStyle: TextStyle(
                fontFamily: 'SF Pro Display',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              type: GFButtonType.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
