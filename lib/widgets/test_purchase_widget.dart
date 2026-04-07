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
import '/screens/log_service.dart';
import '/analytics_service.dart';
import 'package:flutter/cupertino.dart';


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
  final _log = LogService();

  // 광고 제거와 구독 상태 분리
  bool _isAdFree = false;
  bool _isSubscribed = false;

  bool _restoring = false;

  // ✅ 상품 ID 정리: 3개월 제거, 월 정기(premium_monthly)만 사용
  static const _productIds = <String>{'remove_ads', 'premium_monthly'};

  @override
  void initState() {
    super.initState();
    _log.logPremiumCtaClick(placement: 'settings', plan: 'view');
    unawaited(AnalyticsService.instance.logPaywallView(source: 'settings', trigger: 'purchase_widget_open'));
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

  void _onPurchaseError(Object error) async {
    debugPrint('purchaseStream error: $error');

    // 이미 소유 중인 상품 오류가 발생하면 복원 시도
    if (error is IAPError &&
        error.code == 'purchase_error' &&
        (error.message.contains('itemAlreadyOwned'))) {
      _iap.restorePurchases();
    }
    await _log.logPurchaseFailed(
      productId: 'unknown_product',
      errorCode: 'stream_error',
      errorMsg: error.toString(),
    );
    await AnalyticsService.instance.logPurchaseFailed(
      productId: 'unknown_product',
      errorCode: 'stream_error',
      errorMsg: error.toString(),
    );
  }

  Future<void> _checkPreviousPurchase() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      if (!mounted) return;
      setState(() {
        _isAdFree = false;
        _isSubscribed = false;
      });
      return;
    }

    final uid = currentUser.uid;
    bool isAdFree = false;
    bool isSubscribed = false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_points')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()! as Map<String, dynamic>;

        // 1) 영구 광고 제거 권리
        isAdFree = data['adFreePurchased'] as bool? ?? false;

        // 2) 프리미엄 권리 판정 (신규 스키마 우선)
        final premium = data['premium'];
        final now = DateTime.now();

        if (premium is Map<String, dynamic>) {
          final status = (premium['status'] as String? ?? 'expired').toLowerCase();
          final Timestamp? ts = premium['expiresAt'] as Timestamp?;
          final DateTime? expiresAt = ts?.toDate();

          final bool hasExpires = expiresAt != null;
          final bool entitlementValid = hasExpires && now.isBefore(expiresAt!);

          // 서버가 권리 확정 전/유예 중인 상태
          final bool statusActive = status == 'active' || status == 'grace' || status == 'pending';

          // 취소했어도 만료 전 권리는 유지
          final bool canceledButEntitled = status == 'canceled' && entitlementValid;

          // 권장 로직: 만료일이 있으면 그걸 우선시
          if (hasExpires) {
            isSubscribed = entitlementValid || statusActive || canceledButEntitled;
          } else {
            // expiresAt 없으면 무기한 활성 방지: 활성 상태에서만 임시 true
            isSubscribed = statusActive;
          }
        } else {
          // (옵션) 레거시 스키마 백업: premiumExpiry 가 있으면 사용
          final Timestamp? legacyTs = data['premiumExpiry'] as Timestamp?;
          if (legacyTs != null) {
            isSubscribed = now.isBefore(legacyTs.toDate());
          }
        }

        if (isSubscribed) {
          // 구독 중이면 광고 제거도 ON
          isAdFree = true;
        }
      }
    } catch (e) {
      debugPrint('Error checking previous purchase: $e');
    }

    // Provider 반영 (기존 그대로)
    final adProvider = Provider.of<AdRemoveProvider>(context, listen: false);
    adProvider.setRemoveAds(isAdFree);
    adProvider.setSubscribed(isSubscribed);

    setState(() {
      _isAdFree = isAdFree;
      _isSubscribed = isSubscribed;
    });
  }


  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
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
        // ✅ 추가: 성공(ACK) 로그
        await _log.logPurchaseAcknowledged(
          productId: purchase.productID,
          orderId: purchase.verificationData.serverVerificationData,
        );


        _iap.completePurchase(purchase);
      } else if (status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
        await _log.logPurchaseFailed(
          productId: purchase.productID,
          errorCode: '${purchase.error?.code}',
          errorMsg: purchase.error?.message,
        );
        await AnalyticsService.instance.logPurchaseFailed(
          productId: purchase.productID,
          errorCode: '${purchase.error?.code}',
          errorMsg: purchase.error?.message,
        );
      }
    }
  }

  // ✅ 복원 시도 + 결과 피드백 (SnackBar)
  Future<void> _restoreWithFeedback() async {
    await _log.logPremiumCtaClick(placement: 'settings', plan: 'restore');
    await AnalyticsService.instance.logPurchaseRestoreStarted();

    if (_restoring) return;     // ✅ 가드
    _restoring = true;
    final before = _processedTxns.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.iapRestoreTrying)),
    );

    try {
      await _iap.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.iapRestoreError}: $e')),
      );
      _restoring = false;        // ✅ 해제
      return;
    }

    final after = _processedTxns.length;
    if (after > before) {
      await AnalyticsService.instance.logPurchaseRestoreSuccess();
    } else {
      await AnalyticsService.instance.logPurchaseRestoreEmpty();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          after > before
              ? AppLocalizations.of(context)!.iapRestoreDone
              : AppLocalizations.of(context)!.iapRestoreEmpty,
        ),
      ),
    );
    _restoring = false;          // ✅ 해제
  }


  Future<void> _onPurchaseSuccess(PurchaseDetails purchase) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.premiumLoginRequiredMessage)),
      );
      return;
    }

    final uid = currentUser.uid;
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

      final matchedProduct = _products.where((p) => p.id == purchase.productID).cast<ProductDetails?>().firstWhere((p) => p != null, orElse: () => null);
      await AnalyticsService.instance.logPurchaseSuccess(
        productId: purchase.productID,
        currency: matchedProduct?.currencyCode,
        priceLocal: matchedProduct?.rawPrice,
      );
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

  void _buy(ProductDetails product) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.premiumLoginRequiredMessage)),
      );
      return;
    }
    await _log.logPremiumCtaClick(
      placement: 'settings',
      plan: product.id == 'premium_monthly' ? 'monthly' : 'remove_ads',
    );
    await AnalyticsService.instance.logPlanSelected(productId: product.id);
    await _log.logPurchaseStarted(productId: product.id);
    await AnalyticsService.instance.logPurchaseStart(productId: product.id);

    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      // ✅ 안드로이드: premium 이력 없으면 무료 1개월 오퍼 강제, 있으면 기본 플랜
      String? token;
      if (!_isSubscribed) {
        token = _findAndroidOfferToken(
          product,
          basePlanId: 'monthly',
          offerId: 'free1month',
        );
      }

      final param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: token, // 첫 구독이면 free1month, 그 외 null(기본)
      );
      _iap.buyNonConsumable(purchaseParam: param);
      return;
    }

    // iOS 그대로
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
        final Color warmLink = isDark ? const Color(0xFFE5DDD8) : const Color(0xFF5A4942);
        final Color warmLegal = isDark ? const Color(0xFFC8BCB4) : const Color(0xFF6F5D55);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ListTile(title: Text(_error!));

// 광고 제거는 상태에 따라 보이게, 구독은 무조건 1개만
    List<ProductDetails> available = _products.where((p) {
      if (_isAdFree && p.id == 'remove_ads') return false;
      return true;
    }).toList();

// ✅ ANDROID 전용: premium_monthly는 하나만 노출(무료오퍼/기본 중 상황에 맞게 선택)
    if (Platform.isAndroid) {
      // premium 후보들 수집
      final premiumCandidates = _products.where((p) => p.id == 'premium_monthly').toList();

      ProductDetails? chosen;

      // 무료 오퍼 토큰 있는지 검사 함수 (null-safe)
      String? _trialToken(ProductDetails p) => _findAndroidOfferToken(
        p,
        basePlanId: 'monthly',
        offerId: 'free1month',
      );

      if (!_isSubscribed) {
        // 첫 구독자 → 무료 오퍼 있는 항목을 우선 선택
        for (final p in premiumCandidates) {
          if (_trialToken(p) != null) {
            chosen = p;
            break;
          }
        }
        // 무료 오퍼 후보가 없으면 아무거나 1개
        chosen ??= premiumCandidates.isNotEmpty ? premiumCandidates.first : null;
      } else {
        // 이미 구독 권리 있음 → 기본 플랜(무료오퍼 없는 항목) 우선
        for (final p in premiumCandidates) {
          if (_trialToken(p) == null) {
            chosen = p;
            break;
          }
        }
        // 기본 플랜 후보 없으면 아무거나 1개
        chosen ??= premiumCandidates.isNotEmpty ? premiumCandidates.first : null;
      }

      // 리스트에서 premium 전부 제거 후, 선택된 것만 1개 추가
      available = available.where((p) => p.id != 'premium_monthly').toList();
      if (chosen != null) {
        available.add(chosen);
      }
    }


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
                            _buildProductTitle(prod, warmText, warmTextSub),
                            const SizedBox(height: 6),
                            // 👉 여기 Builder(...) 부분 삭제!
                            Text(
                              prod.description,
                              style: TextStyle(fontSize: 12, color: warmTextSub),
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
          // 👇 여기 추가
          if (available.any((p) => p.id == 'premium_monthly'))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.sub_badge_trial_1m, // "1개월 무료 체험 제공" 같은 안내
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: warmText,
                ),
              ),
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: warmText),
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
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minSize: 34,
                      onPressed: () => launchUrl(Uri.parse('https://mscanner.net/terms-conditions/')),
                      child: Text(
                        l10n.terms,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: warmLink,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minSize: 34,
                      onPressed: () => launchUrl(Uri.parse('https://mscanner.net/privacy-policy/')),
                      child: Text(
                        l10n.privacy,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: warmLink,
                        ),
                      ),
                    ),
                  ],
                )

              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minSize: 34,
                  onPressed: _restoreWithFeedback,
                  child: Text(
                    AppLocalizations.of(context)!.restorePurchases,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: warmLegal,
                    ),
                  ),
                ),
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