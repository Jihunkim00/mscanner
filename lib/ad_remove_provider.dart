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
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthChanged);

    // 앱 시작 시 이미 로그인된 유저가 있으면 바로 구독 시작
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _startListening(currentUser.uid);
    }
  }

  void _onAuthChanged(User? user) {
    _subscription?.cancel();

    if (user == null) {
      _isAdRemoved = false;
      _isSubscribed = false;
      notifyListeners();
    } else {
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

      // userStatus 와 premiumExpiry 필드를 읽어옴
      final status = data?['userStatus'] as String?;
      final Timestamp? expiryTs = data?['premiumExpiry'] as Timestamp?;

      // premium 구독이 만료되지 않았는지 체크
      final hasActivePremium = status == 'premium'
          && expiryTs != null
          && DateTime.now().isBefore(expiryTs.toDate());

      // adfree 이거나, 구독이 유효할 때만 광고 제거
      final newAdRemove = status == 'adfree' || hasActivePremium;

      // 구독 여부는 유효한 premium 만
      final newSubscribed = hasActivePremium;

      if (newAdRemove != _isAdRemoved || newSubscribed != _isSubscribed) {
        _isAdRemoved  = newAdRemove;
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

  void refreshStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscription?.cancel();
    _startListening(user.uid);
  }
}
