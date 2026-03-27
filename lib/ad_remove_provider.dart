import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/analytics_service.dart';

/// 광고 제거(ad-free)와 프리미엄 구독 상태를 실시간 관리하는 Provider
class AdRemoveProvider extends ChangeNotifier {
  bool _isAdRemoved = false;   // 광고 제거 여부 (adfree 영구권리 OR premium 활성시 true)
  bool _isSubscribed = false;  // 프리미엄 기능 사용 가능 여부 (premium 활성시 true)

  bool get isAdRemoved => _isAdRemoved;
  bool get isSubscribed => _isSubscribed;

  StreamSubscription<DocumentSnapshot>? _userPointsSub;
  StreamSubscription<User?>? _authSub;

  AdRemoveProvider() {
    // 로그인 상태 감지
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);

    // 앱 시작 시 이미 로그인 되어 있으면 바로 구독 시작
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) _startListening(current.uid);
  }

  void _onAuthChanged(User? user) {
    _userPointsSub?.cancel();

    if (user == null) {
      // 로그아웃 시 상태 초기화
      _applyState(isAdRemoved: false, isSubscribed: false);
    } else {
      _startListening(user.uid);
    }
  }

  /// Firestore: user_points/{uid} 문서를 실시간 구독
  void _startListening(String uid) {
    _userPointsSub = FirebaseFirestore.instance
        .collection('user_points')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        _applyState(isAdRemoved: false, isSubscribed: false);
        return;
      }
      final data = doc.data() as Map<String, dynamic>?;

      // 1) 영구 광고 제거 권리(adfree)
      final bool adFreePurchased = (data?['adFreePurchased'] as bool?) ?? false;

      // 2) 프리미엄 활성 여부 계산 (신규 스키마 우선, 레거시 보조)
      final bool premiumActive = _computePremiumActive(data);

      // 정책:
      // - isSubscribed: premiumActive
      // - isAdRemoved: adFreePurchased || premiumActive
      final bool newSubscribed = premiumActive;
      final bool newAdRemoved  = adFreePurchased || premiumActive;

      _applyState(isAdRemoved: newAdRemoved, isSubscribed: newSubscribed);
    }, onError: (e) {
      debugPrint('AdRemoveProvider listen error: $e');
      // 에러 시 기존 상태 유지 (필요하면 fallback 처리)
    });
  }

  /// 신규 스키마: premium: {status, expiresAt, ...}
  /// 레거시 스키마: premiumExpiry (Timestamp)
  bool _computePremiumActive(Map<String, dynamic>? data) {
    final now = DateTime.now();

    // ── 1) 신규 스키마
    final premium = data?['premium'];
    if (premium is Map<String, dynamic>) {
      final String status = (premium['status'] as String? ?? 'expired').toLowerCase();
      final Timestamp? ts = premium['expiresAt'] as Timestamp?;
      final DateTime? expiresAt = ts?.toDate();

      final bool hasExpires = expiresAt != null;
      final bool entitlementValid = hasExpires && now.isBefore(expiresAt!);

      // 상태 기반 활성(서버가 권리 확정 전/유예 중인 상황)
      final bool statusActive = status == 'active' || status == 'grace' || status == 'pending';

      // ❗️취소되었더라도 만료 전이면 권리 유효
      final bool canceledButEntitled = status == 'canceled' && entitlementValid;

      // 권장: 만료일이 있다면 만료일을 "단일 진실"로 우선시
      if (hasExpires) {
        return entitlementValid || statusActive; // 권리가 남아있거나(만료 전) 상태가 활성(유예/보류/활성)
      } else {
        // expiresAt가 아직 안 온 케이스(결제 직후 pending 등): 오직 활성 상태에서만 true
        return statusActive;
      }
    }

    // ── 2) 레거시 스키마
    final Timestamp? legacyExpiryTs = data?['premiumExpiry'] as Timestamp?;
    if (legacyExpiryTs != null) {
      return now.isBefore(legacyExpiryTs.toDate());
    }

    return false;
  }


  void _applyState({required bool isAdRemoved, required bool isSubscribed}) {
    if (_isAdRemoved != isAdRemoved || _isSubscribed != isSubscribed) {
      _isAdRemoved = isAdRemoved;
      _isSubscribed = isSubscribed;
      notifyListeners();

      final premiumStatus = isSubscribed ? 'premium' : (isAdRemoved ? 'ad_free' : 'free');
      unawaited(AnalyticsService.instance.setPremiumStatus(premiumStatus));
    }
  }

  @override
  void dispose() {
    _userPointsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // ↓↓↓ 테스트/임시용 setter (운영에선 사용 지양)
  void setRemoveAds(bool value) => _applyState(
    isAdRemoved: value,
    isSubscribed: _isSubscribed,
  );

  void setSubscribed(bool value) => _applyState(
    isAdRemoved: _isAdRemoved || value, // 프리미엄 ON이면 광고 제거도 ON
    isSubscribed: value,
  );

  /// 수동으로 Firestore 구독 재시작
  void refreshStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userPointsSub?.cancel();
    _startListening(user.uid);
  }
}
