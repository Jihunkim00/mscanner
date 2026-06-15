// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ v7부터는 싱글톤 사용
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // 선택: Android에서 serverClientId(웹 클라이언트 ID)가 필요한 환경이 많음
  // iOS에서 clientId를 따로 지정할 수도 있음.
  final String? serverClientId;
  final String? iosClientId;

  bool _googleInitialized = false;

  AuthService({this.serverClientId, this.iosClientId});

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      clientId: iosClientId,          // iOS일 때 필요하면 지정
      serverClientId: serverClientId, // Android에서 종종 필요(웹 클라이언트 ID)
    );
    _googleInitialized = true;
  }

  // ---------------------------
  // Google Sign-In (v7 스타일)
  // ---------------------------
  Future<User?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      // v7: UI 흐름 시작은 authenticate()
      final GoogleSignInAccount account =
      await _googleSignIn.authenticate();

      // v7: authentication에는 idToken만 제공
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-id-token-null',
          message: 'Google ID token is null',
        );
      }

      final OAuthCredential credential =
      GoogleAuthProvider.credential(idToken: idToken);

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      // 필요한 경우 GoogleSignInException 처리 분기 가능
      // (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled 등)
      // print('Google sign-in error: $e');
      return null;
    }
  }

  // ---------------------------
  // Apple Sign-In (nonce 필수)
  // ---------------------------
  Future<User?> signInWithApple() async {
    try {
      // (1) rawNonce 생성 및 해시
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // (2) 애플 인증 (nonce 전달)
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = apple.identityToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'apple-id-token-null',
          message: 'Apple identityToken is null',
        );
      }

      // (3) Firebase 자격 증명 (idToken + rawNonce + AppleFullPersonName(널 금지))
      final oauth = AppleAuthProvider.credentialWithIDToken(
        idToken,
        rawNonce,
        AppleFullPersonName(
          givenName: apple.givenName,
          familyName: apple.familyName,
        ),
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(oauth);

      return userCredential.user;
    } catch (e) {
      // print('Apple sign-in error: $e');
      return null;
    }
  }

  // 이메일/비밀번호 로그인
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } catch (e) {
      // print('Email/Password sign-in error: $e');
      return null;
    }
  }

  // 익명 로그인 (게스트 로그인)
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      // print('Guest sign-in error: $e');
      return null;
    }
  }

  // 로그아웃 (Google 세션도 함께 정리 권장)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore google sign out errors
    }
    await _auth.signOut();
  }

  // ---------------------------
  // Utils (Apple nonce)
  // ---------------------------
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
}
