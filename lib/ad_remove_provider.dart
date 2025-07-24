import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 광고 제거 및 프리미엄 구독 상태를 실시간으로 관리하는 Provider
class AdRemoveProvider extends ChangeNotifier {
  bool _isAdRemoved = false;
  bool _isSubscribed = false;

  bool get isAdRemoved => _isAdRemoved;
  bool get isSubscribed => _isSubscribed;

  StreamSubscription<DocumentSnapshot>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  AdRemoveProvider() {
    // 로그인 상태 변화 감지
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthChanged);

    // 앱 시작 시 이미 로그인된 사용자가 있으면 구독 시작
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _startListening(currentUser.uid);
    }
  }

  void _onAuthChanged(User? user) {
    _subscription?.cancel();

    if (user == null) {
      // 로그아웃 시 초기화
      _isAdRemoved = false;
      _isSubscribed = false;
      notifyListeners();
    } else {
      // 로그인 시 Firestore 구독 시작
      _startListening(user.uid);
    }
  }

  /// Firestore user_points 문서를 실시간 구독
  void _startListening(String uid) {
    _subscription = FirebaseFirestore.instance
        .collection('user_points')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>?;

      // 1) 영구 광고 제거 구매 여부
      final bool adFreePerm = data?['adFreePurchased'] as bool? ?? false;

      // 2) 3개월 프리미엄 만료일 체크
      final Timestamp? expiryTs = data?['premiumExpiry'] as Timestamp?;
      final bool hasActivePremium = expiryTs != null
          && DateTime.now().isBefore(expiryTs.toDate());

      // 광고 제거 여부: 영구 제거 OR 프리미엄 활성 시
      final bool newAdRemove = adFreePerm || hasActivePremium;

      // 구독 여부: 프리미엄이 유효할 때만 true
      final bool newSubscribed = hasActivePremium;

      if (newAdRemove != _isAdRemoved || newSubscribed != _isSubscribed) {
        _isAdRemoved = newAdRemove;
        _isSubscribed = newSubscribed;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('AdRemoveProvider listen error: $e');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  /// 강제로 광고 제거 상태 설정 (테스트용)
  void setRemoveAds(bool value) {
    if (_isAdRemoved != value) {
      _isAdRemoved = value;
      notifyListeners();
    }
  }

  /// 강제로 구독 상태 설정 (테스트용)
  void setSubscribed(bool value) {
    if (_isSubscribed != value) {
      _isSubscribed = value;
      notifyListeners();
    }
  }

  /// 수동으로 Firestore 구독을 재시작하고 싶을 때
  void refreshStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription?.cancel();
    _startListening(user.uid);
  }
}
