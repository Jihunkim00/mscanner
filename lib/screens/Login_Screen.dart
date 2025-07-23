import 'dart:io'; // 플랫폼을 감지하기 위해 dart:io 패키지 추가
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '/screens/Home_Screen.dart';
import '/screens/SignUp_Screen.dart';
import '/screens/ChangePassword_Screen.dart';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '/screens/log_service.dart'; // ✅ 로그 서비스 추가
import '/screens/url_launcher1.dart'; // ← 만들어둔 위젯 import 추가

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  Future<User?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Google sign-in error: $e');
      // 에러 메시지 제거
      return null;
    }
  }

  Future<User?> _signInWithApple() async {
    try {
      // Apple 인증 요청
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Firebase로 전달할 OAuthCredential 생성
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase 로그인 시도
      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      return userCredential.user;
    } catch (e) {
      print('Apple sign-in error: $e');
      // 에러 메시지 제거
      return null;
    }
  }

  Future<void> _signInWithEmailPassword() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await LogService().logLoginSuccess(); // ✅ 추가된 부분

      _navigateAfterSignIn(userCredential.user);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  // **게스트 로그인 기능 추가 및 Cupertino 스타일 다이얼로그로 변경**
  Future<void> _signInAsGuest() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();

      // 게스트 로그인 성공 시 Cupertino 스타일 다이얼로그 표시
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(AppLocalizations.of(context)?.guestLoginTitle ?? 'Guest Login'),
          content: Text(AppLocalizations.of(context)?.guestLoginContent ??
              'You are logged in as a guest. All data will be deleted upon logout.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)?.confirm ?? 'Confirm'),
            ),
          ],
        ),
      );

      _navigateAfterSignIn(userCredential.user);
    } catch (e) {
      setState(() {
        _errorMessage =
            AppLocalizations.of(context)?.guestLoginFailed ?? 'Guest login failed. Please try again.';
      });
      print('Guest sign-in error: $e');
    }
  }

  Future<void> _navigateAfterSignIn(User? user) async {
    if (user == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }



  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Color(0xFFEFEFF4),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 100),
                Semantics(
                  label: 'App logo and title',
                  child: Image.asset(
                    'assets/images/tittle.png', // 이미지 경로를 적절히 수정
                    width: 220, // 원하는 이미지 너비
                    height: 100, // 원하는 이미지 높이
                  ),
                ),

                SizedBox(height: 50),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Sign in with Google',
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            User? user = await _signInWithGoogle();
                            if (user != null) {
                              await LogService().logLoginSuccess(); // ✅ 추가된 부분
                              _navigateAfterSignIn(user);
                            }
                          },
                          icon: Image.asset(
                            'assets/images/google_logo.png',
                            width: 24,
                            height: 24,
                            semanticLabel: 'Google logo',
                          ),
                          label: Text(localizations?.continueWithGoogle ?? 'Continue with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: Size(double.infinity, 60),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Apple 로그인 버튼은 iOS 플랫폼에서만 표시
                      if (Platform.isIOS)
                        Semantics(
                          label: 'Sign in with Apple',
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              User? user = await _signInWithApple();
                              if (user != null) {
                                await LogService()
                                    .logLoginSuccess(); // ✅ 추가된 부분
                                _navigateAfterSignIn(user);
                              }
                            },
                            icon: Image.asset(
                              'assets/images/apple_logo.png',
                              width: 24,
                              height: 24,
                              semanticLabel: 'Apple logo',
                            ),
                            label:
                            Text(localizations?.continueWithApple ?? 'Continue with Apple'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 60),
                            ),
                          ),
                        ),
                      SizedBox(height: 20),
                      // **게스트 로그인 버튼 추가**
                      Semantics(
                        label: 'Continue as Guest',
                        child: ElevatedButton(
                          onPressed: _signInAsGuest,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 60),
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black,
                          ),
                          child: Text(
                            localizations?.continueAsGuest ?? 'Continue as Guest',
                            style: TextStyle(fontFamily: 'SFPro', fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Semantics(
                        label: 'Email input field',
                        child: CupertinoTextField(
                          controller: _emailController,
                          placeholder: localizations?.email ?? 'Email',
                          placeholderStyle: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.grey),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          style: TextStyle(
                              fontFamily: 'SFPro',
                              color: isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                      SizedBox(height: 20),
                      Semantics(
                        label: 'Password input field',
                        child: CupertinoTextField(
                          controller: _passwordController,
                          placeholder: localizations?.password ?? 'Password',
                          obscureText: true,
                          placeholderStyle: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.grey),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          style: TextStyle(
                              fontFamily: 'SFPro',
                              color: isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                      SizedBox(height: 10),
                      Semantics(
                        label: 'Forgot Password link',
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (context) => ChangePasswordScreen()),
                            );
                          },
                          child: Text(
                            localizations?.forgotPassword ?? 'Forgot Password?',
                            style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 14,
                                color: Colors.blue),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      if (_errorMessage != null)
                        Semantics(
                          label: 'Error message',
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      Semantics(
                        label: 'Login button',
                        child: ElevatedButton(
                          onPressed: _signInWithEmailPassword,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            backgroundColor: Colors.blue,
                          ),
                          child: Text(
                            localizations?.login ?? 'Log in',
                            style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 16,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Semantics(
                        label: 'Sign up new account button',
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignUpScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.white),
                          ),
                          child: Text(
                            localizations?.signUpNewAccount ?? 'Sign up new Account',
                            style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 16,
                                color: Colors.black),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Semantics(
                        label: 'Privacy policy and terms links',
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            children: [
                              CustomLinkLauncher(
                                url: 'https://mscanner.net/privacy-policy/',
                                title: localizations?.privacyPolicy ?? 'Privacy Policy',
                                centerAlign: true, // 🔹 중앙 정렬

                              ),
                              CustomLinkLauncher(
                                url: 'https://mscanner.net/terms-conditions/',
                                title: localizations?.termsAndConditions ?? 'Terms & Conditions',
                                centerAlign: true, // 🔹 중앙 정렬

                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                    ],
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}
