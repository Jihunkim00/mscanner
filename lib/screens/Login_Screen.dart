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
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    await _googleSignIn.initialize(
      // ✅ Android에서는 반드시 Web Client ID 지정해야 함
      serverClientId:
      '522189466074-ijitmvohfhromjc32kkjs6khbprasp8e.apps.googleusercontent.com',
      // ✅ iOS에서는 clientId 지정 (Firebase Console iOS OAuth ID)
      clientId: Platform.isIOS
          ? '522189466074-qjculmgnptdeorlv86rh9e0uulp934rs.apps.googleusercontent.com'
          : null,
    );
  }

  Future<User?> _signInWithGoogle() async {
    await LogService().logLoginAttempt(method: 'google');
    try {
      final account = await _googleSignIn.authenticate(); // ← signIn() 아님
      final idToken = account.authentication.idToken; // ← property, nullable

      if (idToken == null) {
        throw Exception('Google idToken is null');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      await LogService().logLoginSuccess(method: 'google');
      return userCredential.user;
    } catch (e) {
      await LogService().logLoginFail(
          method: 'google', errorCode: 'exception', errorMsg: e.toString());
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> _signInWithApple() async {
    await LogService().logLoginAttempt(method: 'apple');
    try {
      // 1) rawNonce 생성 + 해시
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // 2) 애플 인증 (hashedNonce 전달)
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: hashedNonce,
      );

      // 3) Firebase용 credential (idToken + rawNonce + AppleFullPersonName(널 불가))
      final oauth = AppleAuthProvider.credentialWithIDToken(
        appleCredential.identityToken!, // String (not null)
        rawNonce, // String (not null)
        AppleFullPersonName(
          // 객체 자체는 not null, 내부 필드는 null 허용
          givenName: appleCredential.givenName,
          familyName: appleCredential.familyName,
        ),
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(oauth);
      await LogService().logLoginSuccess(method: 'apple');
      return userCredential.user;
    } catch (e) {
      await LogService().logLoginFail(
          method: 'password', errorCode: 'exception', errorMsg: e.toString());
      debugPrint('Apple sign-in error: $e');
      return null;
    }
  }

  Future<void> _signInWithEmailPassword() async {
    await LogService().logLoginAttempt(method: 'password'); // 🔹 시도
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await LogService().logLoginSuccess(method: 'password'); // 🔹 성공

      _navigateAfterSignIn(userCredential.user);
    } catch (e) {
      await LogService().logLoginFail(
          method: 'password', errorCode: 'exception', errorMsg: e.toString()); // 🔹 실패
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  // **게스트 로그인**
  Future<void> _signInAsGuest() async {
    await LogService().logLoginAttempt(method: 'guest');
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      await LogService().logLoginSuccess(method: 'guest');

      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title:
          Text(AppLocalizations.of(context)?.guestLoginTitle ?? 'Guest Login'),
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
    } on FirebaseAuthException catch (e) {
      await LogService()
          .logLoginFail(method: 'guest', errorCode: e.code, errorMsg: e.message);
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.guestLoginFailed ??
            'Guest login failed. Please try again.';
      });
    } catch (e) {
      await LogService().logLoginFail(
          method: 'guest', errorCode: 'exception', errorMsg: e.toString());
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.guestLoginFailed ??
            'Guest login failed. Please try again.';
      });
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

    // UI theme tokens (스크린샷 스타일)
    const primaryOrange = Color(0xFFD8753B);
    final bgColor = isDarkMode ? const Color(0xFF0B0B0B) : const Color(0xFFEFEFF4);
    final cardColor = isDarkMode ? const Color(0xFF141414) : Colors.white;
    final fieldFill = isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF2F4F7);
    final dividerColor = isDarkMode ? Colors.white24 : Colors.black12;
    final double appleScale = isDarkMode ? 1.18 : 1.10;
    final googleIconAsset = isDarkMode
        ? 'assets/images/google_dark.png'
        : 'assets/images/google_light.png';

    final appleIconAsset = isDarkMode
        ? 'assets/images/apple_dark.png'
        : 'assets/images/apple_light.png';

    InputDecoration _fieldDecoration({
      required String label,
      required IconData icon,
      String? hint,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      );
    }
    Widget _authIcon(String asset, {double box = 22, double scale = 1.0}) {
      return SizedBox(
        width: box,
        height: box,
        child: Transform.scale(
          scale: scale,
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      );
    }
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // 카드
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.45 : 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 상단 이미지 + 닫기
                          Stack(
                            children: [
                              SizedBox(
                                height: 150,
                                width: double.infinity,
                                child: Image.asset(
                                  // ⚠️ 음식 사진으로 교체 추천
                                  'assets/images/login_header.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    // asset 없을 때 fallback
                                    return Container(
                                      color: fieldFill,
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        'assets/images/tittle.png',
                                        width: 170,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Material(
                                  color: Colors.black.withOpacity(0.25),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Discover the world through its flavors with AI intelligence. Your culinary journey continues here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    height: 1.35,
                                    fontSize: 16,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // 이메일
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                  decoration: _fieldDecoration(
                                    label: 'Email Address',
                                    icon: Icons.mail_outline,
                                    hint: 'name@example.com',
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 비밀번호
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                  decoration: _fieldDecoration(
                                    label: localizations?.password ?? 'Password',
                                    icon: Icons.lock_outline,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                            builder: (context) =>
                                                ChangePasswordScreen()),
                                      );
                                    },
                                    child: Text(
                                      localizations?.forgotPassword ??
                                          'Forgot Password?',
                                      style: const TextStyle(
                                        fontFamily: 'SFPro',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: primaryOrange,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),

                                // Sign In
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _signInWithEmailPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryOrange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      localizations?.login ?? 'Sign In',
                                      style: const TextStyle(
                                        fontFamily: 'SFPro',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: dividerColor, height: 1)),
                                    Padding(
                                      padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        'OR CONTINUE WITH',
                                        style: TextStyle(
                                          fontFamily: 'SFPro',
                                          fontSize: 12,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w700,
                                          color: isDarkMode
                                              ? Colors.white54
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: dividerColor, height: 1)),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            User? user = await _signInWithGoogle();
                                            if (user != null) _navigateAfterSignIn(user);
                                          },
                                          icon: _authIcon(googleIconAsset, box: 22, scale: 1.0),
                                          label: const Text('Google'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDarkMode ? Colors.white : Colors.black,
                                            side: BorderSide(color: dividerColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          onPressed: Platform.isIOS
                                              ? () async {
                                            User? user = await _signInWithApple();
                                            if (user != null) _navigateAfterSignIn(user);
                                          }
                                              : null,
                                          icon: _authIcon(appleIconAsset, box: 22, scale: appleScale),
                                          label: const Text('Apple'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDarkMode ? Colors.white : Colors.black,
                                            side: BorderSide(color: dividerColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Guest
                                Center(
                                  child: TextButton(
                                    onPressed: _signInAsGuest,
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryOrange,
                                    ),
                                    child: Text(
                                      localizations?.continueAsGuest ??
                                          'Continue as Guest',
                                      style: const TextStyle(
                                        fontFamily: 'SFPro',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // Privacy / Terms
                                Column(
                                  children: [
                                    CustomLinkLauncher(
                                      url: 'https://mscanner.net/privacy-policy/',
                                      title: localizations?.privacyPolicy ??
                                          'Privacy Policy',
                                      centerAlign: true,
                                    ),
                                    CustomLinkLauncher(
                                      url:
                                      'https://mscanner.net/terms-conditions/',
                                      title: localizations?.termsAndConditions ??
                                          'Terms & Conditions',
                                      centerAlign: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 하단 Sign up 텍스트
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SignUpScreen()),
                          );
                        },
                        child: const Text(
                          'Sign up for free',
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w800,
                            color: primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}