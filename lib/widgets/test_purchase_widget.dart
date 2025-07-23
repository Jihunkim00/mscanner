import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '/ad_remove_provider.dart'; // 실제 경로로 수정

class TestPurchaseWidget extends StatefulWidget {
  const TestPurchaseWidget({super.key});

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

  static const _productIds = <String>{'remove_ads', 'premium_3month'};

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
        // 광고 제거 상태
        isAdFree = data['userStatus'] == 'adfree';

        // 구독 상태
        if (data['userStatus'] == 'premium' && data.containsKey('premiumExpiry')) {
          final expiry = (data['premiumExpiry'] as Timestamp).toDate();
          isSubscribed = DateTime.now().isBefore(expiry);
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
    const restoreIds = {'remove_ads', 'premium_3month'};

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
        await ref.set({'userStatus': 'adfree'}, SetOptions(merge: true));
        _isAdFree = true;

               // 광고 제거 권한만 갱신
        Provider.of<AdRemoveProvider>(context, listen: false)
            .setRemoveAds(true);

      } else if (purchase.productID == 'premium_3month') {
        final expiry = DateTime.now().add(const Duration(days: 90));
        await ref.set({
          'userStatus': 'premium',
          'premiumExpiry': Timestamp.fromDate(expiry),
        }, SetOptions(merge: true));

        _isSubscribed = true;
               _isAdFree = true; // 구독 중에도 광고 제거

           final adProvider = Provider.of<AdRemoveProvider>(context, listen: false);
           adProvider.setSubscribed(true);
           adProvider.setRemoveAds(true);
    }

    setState(() {});
    } catch (e) {
    debugPrint('Error saving purchase: $e');
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('저장 중 오류가 발생했습니다: \$e')),
    );
    }
  }


  void _onPurchaseError(Object error) {
    debugPrint('purchaseStream error: $error');
  }

  void _buy(ProductDetails product) {
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ListTile(title: Text(_error!));

    // 광고 제거만 된 유저라면 remove_ads 상품 숨기기
    final available = _products.where((p) {
      if (_isAdFree && p.id == 'remove_ads') return false;
      return true;
    }).toList();

    // 구독 유저
    if (_isSubscribed) {
      return ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(AppLocalizations.of(context)!.premiumUserTitle),
        subtitle: Text(AppLocalizations.of(context)!.premiumUserSubtitle),
      );
    }

    // 구독 전 유저에게 구매 옵션 노출
    if (available.isEmpty) {
      return ListTile(title: Text(AppLocalizations.of(context)!.noAvailableProducts));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: available.length,
      itemBuilder: (_, idx) {
        final prod = available[idx];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.star, size: 20, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prod.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        prod.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _buy(prod),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(prod.price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
