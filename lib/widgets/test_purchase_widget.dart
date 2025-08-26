import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show GooglePlayProductDetails, GooglePlayPurchaseParam; // 👈 Android 오퍼 토큰용
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '/ad_remove_provider.dart'; // 실제 경로로 수정
import 'package:url_launcher/url_launcher.dart';

class TestPurchaseWidget extends StatefulWidget {
  const TestPurchaseWidget({super.key, this.onPurchased});

  final VoidCallback? onPurchased; // ✅ 추가

  @override
  State<TestPurchaseWidget> createState() => _TestPurchaseWidgetState();
}

class _TestPurchaseWidgetState extends State<TestPurchaseWidget> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  final Set<String> _processedTxns = {};
  List<ProductDetails> _products = [];
  bool _loading = true;
  String? _error;

  // 광고 제거와 구독 상태 분리
  bool _isAdFree = false;
  bool _isSubscribed = false;

  // ✅ 상품 ID 정리: 3개월 제거, 월 정기(premium_monthly)만 사용
  static const _productIds = <String>{'remove_ads', 'premium_monthly'};

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: _onPurchaseError,
      onDone: () => _sub.cancel(),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      setState(() {
        _error = AppLocalizations.of(context)!.iapUnavailable;
        _loading = false;
      });
      return;
    }

    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      setState(() {
        _error = response.error!.message;
        _loading = false;
      });
      return;
    }

    setState(() {
      _products = response.productDetails;
      _loading = false;
    });

    await _checkPreviousPurchase();
    await _iap.restorePurchases();
  }

  void _onPurchaseError(Object error) {
    debugPrint('purchaseStream error: $error');

    // 이미 소유 중인 상품 오류가 발생하면 복원 시도
    if (error is IAPError &&
        error.code == 'purchase_error' &&
        (error.message.contains('itemAlreadyOwned'))) {
      _iap.restorePurchases();
    }
  }

  Future<void> _checkPreviousPurchase() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    bool isAdFree = false;
    bool isSubscribed = false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_points')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        // 1) 영구 광고 제거 구매 여부
        isAdFree = data['adFreePurchased'] as bool? ?? false;

        // 2) 서버가 관리하는 구독 상태(권장)
        final premium = data['premium'] as Map<String, dynamic>?;
        if (premium != null) {
          final status = premium['status'] as String? ?? 'expired';
          final expiresAt = (premium['expiresAt'] as Timestamp?)?.toDate();
          final active = status == 'active' || status == 'grace' || status == 'pending';
          final notExpired = (expiresAt == null) || DateTime.now().isBefore(expiresAt);
          isSubscribed = active && notExpired;
          if (isSubscribed) isAdFree = true;
        }
      }
    } catch (e) {
      debugPrint('Error checking previous purchase: $e');
    }

    // Provider 에 두 상태 모두 반영
    final adProvider = Provider.of<AdRemoveProvider>(context, listen: false);
    adProvider.setRemoveAds(isAdFree);
    adProvider.setSubscribed(isSubscribed);

    setState(() {
      _isAdFree = isAdFree;
      _isSubscribed = isSubscribed;
    });
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    // ✅ 3개월 상품 제거에 따라 복원 대상도 정리
    const restoreIds = {'remove_ads', 'premium_monthly'};

    for (var purchase in purchases) {
      final status = purchase.status;
      final id = purchase.productID;
      final isPurchased = status == PurchaseStatus.purchased;
      final isRestored = status == PurchaseStatus.restored && restoreIds.contains(id);

      if (isPurchased || isRestored) {
        final txId = purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
        if (!_processedTxns.contains(txId)) {
          _processedTxns.add(txId);
          _onPurchaseSuccess(purchase);
        }
        _iap.completePurchase(purchase);
      } else if (status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
      }
    }
  }

  Future<void> _onPurchaseSuccess(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('user_points').doc(uid);

    try {
      if (purchase.productID == 'remove_ads') {
        // 영구 광고 제거
        await ref.set({'adFreePurchased': true}, SetOptions(merge: true));
        _isAdFree = true;
        Provider.of<AdRemoveProvider>(context, listen: false).setRemoveAds(true);

      } else if (purchase.productID == 'premium_monthly') {
        // ✅ 구독: 만료일 직접 계산 금지. 서버 검증/웹훅으로 채우도록 pending만 기록.
        await ref.set({
          'premium': {
            'status': 'pending',
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'productId': 'premium_monthly',
            'pendingAt': Timestamp.now(),
          }
        }, SetOptions(merge: true));

        _isSubscribed = true;
        _isAdFree = true; // 구독 중엔 광고 제거

        final adProvider = Provider.of<AdRemoveProvider>(context, listen: false);
        adProvider.setSubscribed(true);
        adProvider.setRemoveAds(true);
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error saving purchase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saving error: $e')),
      );
    }
    // ✅ 성공 시 콜백 → 바텀시트 닫기, 오버레이 닫기 등에 사용
    widget.onPurchased?.call();
  }

  // ✅ Android: basePlanId=monthly + offerId=free1month 의 offerToken으로 결제
  String? _findAndroidOfferToken(ProductDetails prod, {
    required String basePlanId,
    required String offerId,
  }) {
    final gp = prod is GooglePlayProductDetails ? prod : null;
    final offers = gp?.productDetails.subscriptionOfferDetails; // List<SubscriptionOfferDetailsWrapper>?
    if (offers == null) return null;

    for (final o in offers) {
      if (o.basePlanId == basePlanId && o.offerId == offerId) {
        return o.offerIdToken; // ✅ 이 토큰으로 결제해야 1개월 무료 오퍼 적용
      }
    }
    return null;
  }

  void _buy(ProductDetails product) {
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      final token = _findAndroidOfferToken(
        product,
        basePlanId: 'monthly',
        offerId: 'free1month',
      );

      final param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: token, // null이면 기본 베이스 플랜 결제(무료체험 미적용)
      );
      _iap.buyNonConsumable(purchaseParam: param);
      return;
    }

    // iOS: Intro Offer는 콘솔 설정만으로 자동 적용
    final param = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // 👈 추가

        // 👇 따뜻한 모노톤 팔레트 (라이트/다크 자동 전환)
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final Color warmCardBg = isDark ? const Color(0xFF3E2F2A) : const Color(0xFFF3ECE7);
        final Color warmBtnBg  = isDark ? const Color(0xFF4E342E) : const Color(0xFFE8DFDA);
        final Color warmText   = isDark ? Colors.white : const Color(0xFF4A3B35);
        final Color warmTextSub= isDark ? Colors.white70 : const Color(0xFF4A3B35).withOpacity(0.75);
        final Color warmIcon   = isDark ? Colors.white : const Color(0xFF5A463F);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ListTile(title: Text(_error!));

    // 광고 제거만 된 유저라면 remove_ads 상품 숨기기
    final available = _products.where((p) {
      if (_isAdFree && p.id == 'remove_ads') return false;
      return true;
    }).toList();

    // 구독 중인 사용자
    if (_isSubscribed) {
      return ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(AppLocalizations.of(context)!.premiumUserTitle),
        subtitle: Text(AppLocalizations.of(context)!.premiumUserSubtitle),
      );
    }

    // 구매 가능한 상품이 없을 때
    if (available.isEmpty) {
      return ListTile(title: Text(AppLocalizations.of(context)!.noAvailableProducts));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 복원 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () => _iap.restorePurchases(),
                style: ElevatedButton.styleFrom(
                                    backgroundColor: warmBtnBg,
                                    foregroundColor: warmText,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              child: Text(AppLocalizations.of(context)!.restorePurchases),
            ),
          ),

          // 상품 리스트
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: available.length,
            itemBuilder: (_, idx) {
              final prod = available[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                color: warmCardBg,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 20, color: warmIcon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                                                          // 👇 안드로이드에서만 "(앱이름)"을 작은 폰트로 분리 표시
                                                          _buildProductTitle(prod, warmText, warmTextSub),

                            const SizedBox(height: 6),
                            Builder(
                              builder: (_) {
                                final isSub = prod.id == 'premium_monthly';
                                final subtitle = isSub
                                    ? AppLocalizations.of(context)!.sub_badge_trial_1m // 🎁 첫 구독자 1개월 무료
                                    : prod.description;

                                return Text(
                                  subtitle,
                                  style: TextStyle(fontSize: 12, color: warmTextSub),
                                );
                              },
                            ),

                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _buy(prod),
                        style: ElevatedButton.styleFrom(
                                                      backgroundColor: warmBtnBg,
                                                      foregroundColor: warmText,
                                                      elevation: 0,
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
                        child: Text(
                          prod.price,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 👇 고지 문구 블록 (L10n 적용)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                  l10n.sub_disclaimer_title, // "구독 안내"
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${l10n.sub_trial_free}\n'
                      '• ${l10n.sub_auto_renew}\n'
                      '• ${Platform.isIOS ? l10n.sub_manage_ios : l10n.sub_manage_android}\n'
                      '• ${l10n.sub_renew_charge}\n'
                      '• ${l10n.sub_restore}',
                  style: TextStyle(fontSize: 12, color: warmTextSub),
                ),

                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse('https://mscanner.net/terms-conditions/')),
                      child: Text(l10n.terms), // "이용약관"
                    ),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse('https://mscanner.net/privacy-policy/')),
                      child: Text(l10n.privacy), // "개인정보 처리방침"
                    ),
                  ],
                )

              ],
            ),
          ),
        ],
      ),
    );

  }
}
// =========================
//  헬퍼: 상품 타이틀 표시 위젯
// =========================
Widget _buildProductTitle(ProductDetails prod, Color warmText, Color warmTextSub) {
    final title = prod.title;

    // iOS: 앱 이름 접미사가 원래 안 붙으므로 그대로 한 줄 표시
    if (Platform.isIOS) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: warmText),
      );
    }

    // Android: 끝의 괄호 블록( ( ... ) )만 분리해서 축소 표시
    // - 예) "Premium Monthly (My Super Long App Name)"
    final reg = RegExp(r'^(.*?)(\s*\([^()]*\)\s*)$'); // 마지막 괄호 블록만 캡처
    final m = reg.firstMatch(title);

    if (m == null) {
      // 괄호 블록이 없으면 일반 텍스트 처리
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: warmText),
      );
    }

    final mainText = (m.group(1) ?? '').trimRight();
    final appSuffix = (m.group(2) ?? '').trimLeft();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mainText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: warmText),
        ),
        Text(
          appSuffix,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: warmTextSub),
        ),
      ],
    );
}