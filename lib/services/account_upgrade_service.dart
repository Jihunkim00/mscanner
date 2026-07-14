import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AccountUpgradeResult {
  final bool success;
  final User? user;
  final bool migrationPerformed;
  final bool shouldContinueToPurchase;
  final String? message;
  final String? errorCode;

  const AccountUpgradeResult({
    required this.success,
    this.user,
    this.migrationPerformed = false,
    this.shouldContinueToPurchase = false,
    this.message,
    this.errorCode,
  });

  factory AccountUpgradeResult.failure(String message, {String? errorCode}) {
    return AccountUpgradeResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }

  factory AccountUpgradeResult.cancelled([String? message]) {
    return AccountUpgradeResult(
      success: false,
      message: message ?? 'Sign-in was cancelled.',
      errorCode: 'cancelled',
    );
  }
}

class AccountUpgradeService {
  AccountUpgradeService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static bool _googleInitialized = false;

  static Future<AccountUpgradeResult> createEmailAccountAndUpgrade({
    required String email,
    required String password,
  }) async {
    final current = _auth.currentUser;
    if (current == null) {
      return AccountUpgradeResult.failure('No active user found.');
    }

    final cred = EmailAuthProvider.credential(email: email, password: password);
    if (!current.isAnonymous) {
      return _linkCredentialToCurrentUser(cred);
    }

    return _linkAnonymousOrSwitch(
      anonymousUser: current,
      credential: cred,
      signInExisting: () => _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
      emailInUseMessage:
          'This email is already in use. Signed in to existing account.',
    );
  }

  static Future<AccountUpgradeResult> signInExistingEmailAccount({
    required String email,
    required String password,
  }) async {
    final before = _auth.currentUser;
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final target = userCredential.user;
      if (target == null) {
        return AccountUpgradeResult.failure(
            'Unable to sign in to this account.');
      }

      final migrated = await _migrateIfNeeded(before, target.uid);
      return AccountUpgradeResult(
        success: true,
        user: target,
        migrationPerformed: migrated,
        shouldContinueToPurchase: true,
        message: migrated
            ? 'Signed in and migrated guest data.'
            : 'Signed in successfully.',
      );
    } on FirebaseAuthException catch (e) {
      return AccountUpgradeResult.failure(
        _friendlyAuthError(e),
        errorCode: e.code,
      );
    } catch (_) {
      return AccountUpgradeResult.failure(
          'Unable to sign in. Please try again.');
    }
  }

  static Future<AccountUpgradeResult> continueWithGoogle() async {
    final before = _auth.currentUser;
    try {
      await _initializeGoogleSignIn();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return AccountUpgradeResult.failure(
            'Google sign-in failed. Please try again.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      if (before != null && before.isAnonymous) {
        return _linkAnonymousOrSwitch(
          anonymousUser: before,
          credential: credential,
          signInExisting: () => _auth.signInWithCredential(credential),
          emailInUseMessage: 'Signed in with existing Google account.',
        );
      }

      final signedIn = await _auth.signInWithCredential(credential);
      return AccountUpgradeResult(
        success: true,
        user: signedIn.user,
        shouldContinueToPurchase: true,
      );
    } on GoogleSignInException catch (_) {
      return AccountUpgradeResult.cancelled('Google sign-in was cancelled.');
    } on FirebaseAuthException catch (e) {
      return AccountUpgradeResult.failure(_friendlyAuthError(e),
          errorCode: e.code);
    } catch (_) {
      return AccountUpgradeResult.failure(
          'Google sign-in failed. Please try again.');
    }
  }

  static Future<AccountUpgradeResult> continueWithApple() async {
    final before = _auth.currentUser;

    if (!Platform.isIOS && !Platform.isMacOS) {
      return AccountUpgradeResult.failure(
          'Apple Sign-In is only available on Apple devices.');
    }

    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: hashedNonce,
      );

      final token = appleCredential.identityToken;
      if (token == null || token.isEmpty) {
        return AccountUpgradeResult.failure(
            'Apple sign-in failed. Please try again.');
      }

      final credential = AppleAuthProvider.credentialWithIDToken(
        token,
        rawNonce,
        AppleFullPersonName(
          givenName: appleCredential.givenName,
          familyName: appleCredential.familyName,
        ),
      );

      if (before != null && before.isAnonymous) {
        return _linkAnonymousOrSwitch(
          anonymousUser: before,
          credential: credential,
          signInExisting: () => _auth.signInWithCredential(credential),
          emailInUseMessage: 'Signed in with existing Apple account.',
        );
      }

      final signedIn = await _auth.signInWithCredential(credential);
      return AccountUpgradeResult(
        success: true,
        user: signedIn.user,
        shouldContinueToPurchase: true,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AccountUpgradeResult.cancelled('Apple sign-in was cancelled.');
      }
      return AccountUpgradeResult.failure(
          'Apple sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      return AccountUpgradeResult.failure(_friendlyAuthError(e),
          errorCode: e.code);
    } catch (_) {
      return AccountUpgradeResult.failure(
          'Apple sign-in failed. Please try again.');
    }
  }

  static Future<AccountUpgradeResult> _linkCredentialToCurrentUser(
      AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AccountUpgradeResult.failure('No active user found.');
    }

    try {
      final linked = await user.linkWithCredential(credential);
      return AccountUpgradeResult(
        success: true,
        user: linked.user,
        shouldContinueToPurchase: true,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        return AccountUpgradeResult(
          success: true,
          user: user,
          shouldContinueToPurchase: true,
          message: 'This provider is already linked.',
        );
      }
      return AccountUpgradeResult.failure(_friendlyAuthError(e),
          errorCode: e.code);
    }
  }

  static Future<AccountUpgradeResult> _linkAnonymousOrSwitch({
    required User anonymousUser,
    required AuthCredential credential,
    required Future<UserCredential> Function() signInExisting,
    required String emailInUseMessage,
  }) async {
    final oldUid = anonymousUser.uid;

    try {
      final linked = await anonymousUser.linkWithCredential(credential);
      return AccountUpgradeResult(
        success: true,
        user: linked.user,
        shouldContinueToPurchase: true,
        message: 'Account upgraded successfully.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' &&
          e.code != 'email-already-in-use' &&
          e.code != 'provider-already-linked') {
        return AccountUpgradeResult.failure(_friendlyAuthError(e),
            errorCode: e.code);
      }

      try {
        final signedIn = await signInExisting();
        final targetUser = signedIn.user;
        if (targetUser == null) {
          return AccountUpgradeResult.failure('Unable to switch account.');
        }

        final migrated =
            await _mergeGuestData(oldUid: oldUid, newUid: targetUser.uid);
        return AccountUpgradeResult(
          success: true,
          user: targetUser,
          migrationPerformed: migrated,
          shouldContinueToPurchase: true,
          message: migrated
              ? '$emailInUseMessage Guest data migrated.'
              : emailInUseMessage,
        );
      } on FirebaseAuthException catch (signInError) {
        return AccountUpgradeResult.failure(
          _friendlyAuthError(signInError),
          errorCode: signInError.code,
        );
      }
    }
  }

  static Future<bool> _migrateIfNeeded(User? before, String targetUid) async {
    if (before == null || !before.isAnonymous || before.uid == targetUid) {
      return false;
    }
    return _mergeGuestData(oldUid: before.uid, newUid: targetUid);
  }

  static Future<bool> _mergeGuestData({
    required String oldUid,
    required String newUid,
  }) async {
    if (oldUid == newUid) return false;

    bool migrated = false;
    final pointsMigrated =
        await _mergeUserPoints(oldUid: oldUid, newUid: newUid);
    final userDataMigrated =
        await _mergeNestedCollection('user_data', oldUid, newUid);
    final ratingMigrated =
        await _mergeNestedCollection('user_rating', oldUid, newUid);

    migrated = pointsMigrated || userDataMigrated || ratingMigrated;
    if (migrated) {
      await _firestore.collection('user_points').doc(oldUid).set({
        'migratedToUid': newUid,
        'migratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return migrated;
  }

  static Future<bool> _mergeUserPoints(
      {required String oldUid, required String newUid}) async {
    final sourceRef = _firestore.collection('user_points').doc(oldUid);
    final targetRef = _firestore.collection('user_points').doc(newUid);

    return _firestore.runTransaction((tx) async {
      final sourceSnap = await tx.get(sourceRef);
      if (!sourceSnap.exists) return false;

      final sourceData = sourceSnap.data() ?? <String, dynamic>{};
      final targetSnap = await tx.get(targetRef);
      final targetData = targetSnap.data() ?? <String, dynamic>{};

      final merged = <String, dynamic>{...sourceData, ...targetData};
      merged['points'] =
          _safeNum(targetData['points']) + _safeNum(sourceData['points']);

      if (_asBool(sourceData['adFreePurchased']) ||
          _asBool(targetData['adFreePurchased'])) {
        merged['adFreePurchased'] = true;
      }

      merged['premium'] = _mergeMaps(
        _asMap(sourceData['premium']),
        _asMap(targetData['premium']),
      );

      tx.set(targetRef, merged, SetOptions(merge: true));
      return true;
    });
  }

  static Future<bool> _mergeNestedCollection(
      String root, String oldUid, String newUid) async {
    final source =
        await _firestore.collection(root).doc(oldUid).collection('data').get();
    if (source.docs.isEmpty) return false;

    bool changed = false;
    final batch = _firestore.batch();

    for (final doc in source.docs) {
      final destRef = _firestore
          .collection(root)
          .doc(newUid)
          .collection('data')
          .doc(doc.id);
      final destSnap = await destRef.get();
      final merged = _mergeMaps(
        Map<String, dynamic>.from(doc.data()),
        destSnap.exists
            ? (destSnap.data() ?? <String, dynamic>{})
            : <String, dynamic>{},
      );
      batch.set(destRef, merged, SetOptions(merge: true));
      changed = true;
    }

    if (changed) {
      await batch.commit();
    }
    return changed;
  }

  static Map<String, dynamic> _mergeMaps(
    Map<String, dynamic> source,
    Map<String, dynamic> destination,
  ) {
    final merged = <String, dynamic>{...source};
    destination.forEach((key, destValue) {
      if (!merged.containsKey(key)) {
        merged[key] = destValue;
        return;
      }

      final sourceValue = merged[key];
      if (sourceValue is Map && destValue is Map) {
        merged[key] = _mergeMaps(
          Map<String, dynamic>.from(sourceValue),
          Map<String, dynamic>.from(destValue),
        );
      } else if (sourceValue is List && destValue is List) {
        final combined = [...sourceValue, ...destValue];
        merged[key] = combined.map((e) => e.toString()).toSet().toList();
      } else if (sourceValue is num && destValue is num) {
        merged[key] = max(sourceValue, destValue);
      } else {
        merged[key] = destValue;
      }
    });
    return merged;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static int _safeNum(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  static bool _asBool(dynamic value) => value == true;

  static Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      serverClientId:
          '522189466074-ijitmvohfhromjc32kkjs6khbprasp8e.apps.googleusercontent.com',
      clientId: Platform.isIOS
          ? '522189466074-qjculmgnptdeorlv86rh9e0uulp934rs.apps.googleusercontent.com'
          : null,
    );
    _googleInitialized = true;
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'This account already exists. Please sign in.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
