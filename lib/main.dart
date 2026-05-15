// main.dart
import 'dart:ui';

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
import 'ad_remove_provider.dart';
import 'analytics_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';  // 이 줄 추가 map
import 'package:package_info_plus/package_info_plus.dart';
import 'helpers/settings_helper.dart';

enum GuestWelcomeAction {
  continueGuest,
  signIn,
}

// 전역 변수 선언
InterstitialAd? globalInterstitialAd;

// 전면 광고 사용 여부 설정
bool enableInterstitialAds = false; // true로 바꾸면 다시 사용됨
bool _hasScheduledPresetRefreshForSession = false;
const String _lastProcessedPresetVersionKey = 'last_processed_preset_app_version';


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

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await MobileAds.instance.initialize();

  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  final prefs = await SharedPreferences.getInstance();
  final String? savedLocale = prefs.getString('selectedLocale');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AdRemoveProvider(),
      child: MyApp(
        savedThemeMode: savedThemeMode ?? AdaptiveThemeMode.light,
        savedLocale: savedLocale,
      ),
    ),
  );

  unawaited(_initializeAfterLaunch());
}

Future<void> _initializeAfterLaunch() async {
  try {
    _schedulePresetRefreshIfNeeded();
    await AnalyticsService.instance.init();
    debugPrint('[Analytics] init success');
    await AnalyticsService.instance.logAppOpen();
    debugPrint('[Analytics] app_open logged');

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('analytics_first_open_logged') ?? false;
    if (!seen) {
      await AnalyticsService.instance.logFirstOpen();
      await prefs.setBool('analytics_first_open_logged', true);
    }

    await LocationService().requestPermission();

    bool nonPersonalized = false;
    if (Platform.isIOS) {
      final status =
      await AppTrackingTransparency.requestTrackingAuthorization();
      if (status != TrackingStatus.authorized) {
        nonPersonalized = true;
      }
    }

    if (enableInterstitialAds) {
      await loadInterstitialAd(nonPersonalized: nonPersonalized);
    }

    // ✅ 화면 방향 고정 (iPad 구분)
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      final context = binding.focusManager.primaryFocus?.context;
      if (context != null) {
        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        if (!isTablet) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
      }
    });

  } catch (e) {
    debugPrint("초기화 중 오류 발생: $e");
  }
}

void _schedulePresetRefreshIfNeeded() {
  if (_hasScheduledPresetRefreshForSession) {
    debugPrint('[PresetBootstrap] Skipping duplicate schedule in this session.');
    return;
  }

  _hasScheduledPresetRefreshForSession = true;
  unawaited(_refreshPresetAfterAppUpdate());
}

Future<void> _refreshPresetAfterAppUpdate() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final lastProcessedVersion = prefs.getString(_lastProcessedPresetVersionKey);

    if (lastProcessedVersion == currentVersion) {
      debugPrint('[PresetBootstrap] Presets already refreshed for version $currentVersion.');
      return;
    }

    debugPrint(
      '[PresetBootstrap] App update detected. Refreshing presets for version '
          '$currentVersion (last: ${lastProcessedVersion ?? 'none'}).',
    );

    await SettingsHelper.refreshCustomPresetDescriptionFromSavedSettings();
    await prefs.setString(_lastProcessedPresetVersionKey, currentVersion);

    debugPrint('[PresetBootstrap] Presets refreshed successfully for version $currentVersion.');
  } catch (e) {
    debugPrint('[PresetBootstrap] Failed to refresh presets after update: $e');
  }
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
      unawaited(AnalyticsService.instance.setUserId(user.uid));
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
        await AnalyticsService.instance.setUserId(user.uid);

        final action = await _showGuestWelcomePopup();

        if (!mounted) return;

        if (action == GuestWelcomeAction.signIn) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        if (action == GuestWelcomeAction.continueGuest) {
          _navigateAfterSignIn(user);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.guestLoginFailed ??
                  'Guest login failed. Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.guestLoginFailed ??
                'Guest login failed. Please try again.',
          ),
        ),
      );
      print('Guest sign-in error: $e');
    }
  }

  Future<GuestWelcomeAction?> _showGuestWelcomePopup() {
    final mediaQuery = MediaQuery.of(context).size;
    final localizations = AppLocalizations.of(context);

    return showCupertinoModalPopup<GuestWelcomeAction>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.18),
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: ClipRect(
                        child: Transform.translate(
                          offset: const Offset(0, -4),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: 340,
                            child: Image.asset(
                              'assets/images/guest_welcome.png',
                              height: 285,
                              fit: BoxFit.fitHeight,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      localizations?.guestLoginTitle ?? 'Welcome, Explorer!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      localizations?.guestLoginContent ??
                          'In Guest Mode, you can scan food menus to get personalized recommendations, but you won’t be able to save your favorites or view history across devices.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 17,
                        height: 1.45,
                        color: Color(0xFF222222),
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4A84D8),
                              Color(0xFF5A92E5),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x334A84D8),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                              GuestWelcomeAction.continueGuest,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            localizations?.confirm2 ?? "Got it, let's go!",
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          GuestWelcomeAction.signIn,
                        );
                      },
                      child: Text(
                        localizations?.login2 ?? 'Sign in now',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A84D8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
