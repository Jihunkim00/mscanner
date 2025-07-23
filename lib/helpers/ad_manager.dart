// lib/helpers/ad_manager.dart

import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // 싱글톤 인스턴스
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  // 전면 광고 변수
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  // 보상형 전면 광고 변수
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isRewardedInterstitialAdLoaded = false;

  // 전면 광고 로드 함수
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-2942885230901008/7617786169' // 테스트용 Android 전면 광고 ID
          : 'ca-app-pub-3940256099942544/4411468910', // 테스트용 iOS 전면 광고 ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          print('전면 광고 로드 성공');
          _interstitialAd!.setImmersiveMode(true);
          // 광고가 로드되면 다시 로드할 수 있도록 리스너 설정
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _isInterstitialAdLoaded = false;
              loadInterstitialAd(); // 광고가 닫히면 새로운 광고 로드
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _isInterstitialAdLoaded = false;
              loadInterstitialAd(); // 광고 표시 실패 시 새로운 광고 로드
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('전면 광고 로드 실패: $error');
          _isInterstitialAdLoaded = false;
          // 실패 시 일정 시간 후 다시 시도할 수 있음
          Future.delayed(Duration(seconds: 10), () {
            loadInterstitialAd();
          });
        },
      ),
    );
  }

  // 전면 광고 표시 함수
  void showInterstitialAd(Function onAdClosed) {
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _isInterstitialAdLoaded = false;
          loadInterstitialAd(); // 광고가 닫히면 새로운 광고 로드
          onAdClosed(); // 광고 닫힌 후 콜백 호출
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _isInterstitialAdLoaded = false;
          loadInterstitialAd(); // 광고 표시 실패 시 새로운 광고 로드
          onAdClosed(); // 광고 실패 시 콜백 호출
        },
      );
      _interstitialAd!.show();
      _isInterstitialAdLoaded = false;
      _interstitialAd = null;
    } else {
      print('전면 광고가 로드되지 않았습니다.');
      onAdClosed(); // 광고가 로드되지 않았을 때 콜백 호출
    }
  }

  // 보상형 전면 광고 로드 함수
  void loadRewardedInterstitialAd() {
    RewardedInterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-2942885230901008/2508929714' // 테스트용 Android 보상형 전면 광고 ID
          : 'ca-app-pub-3940256099942544/6978759866', // 테스트용 iOS 보상형 전면 광고 ID
      request: AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoaded = true;
          print('보상형 전면 광고 로드 성공');

          // 광고 이벤트 리스너 설정
          _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedInterstitialAd ad) =>
                print('보상형 전면 광고 표시됨'),
            onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
              ad.dispose();
              _isRewardedInterstitialAdLoaded = false;
              loadRewardedInterstitialAd(); // 광고가 닫히면 새로운 광고 로드
            },
            onAdFailedToShowFullScreenContent: (RewardedInterstitialAd ad, AdError error) {
              ad.dispose();
              _isRewardedInterstitialAdLoaded = false;
              loadRewardedInterstitialAd(); // 광고 표시 실패 시 새로운 광고 로드
            },
            onAdImpression: (RewardedInterstitialAd ad) => print('보상형 전면 광고 인상 발생'),
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('보상형 전면 광고 로드 실패: $error');
          _isRewardedInterstitialAdLoaded = false;
          // 실패 시 일정 시간 후 다시 시도할 수 있음
          Future.delayed(Duration(seconds: 10), () {
            loadRewardedInterstitialAd();
          });
        },
      ),
    );
  }

  // 보상형 전면 광고 표시 함수
  void showRewardedInterstitialAd(Function onAdClosed, Function(RewardItem) onUserEarnedReward, {required Null Function(LoadAdError error) onAdFailedToLoad}) {
    if (_isRewardedInterstitialAdLoaded && _rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
          ad.dispose();
          _isRewardedInterstitialAdLoaded = false;
          loadRewardedInterstitialAd(); // 광고가 닫히면 새로운 광고 로드
          onAdClosed(); // 광고 닫힌 후 콜백 호출
        },
        onAdFailedToShowFullScreenContent: (RewardedInterstitialAd ad, AdError error) {
          ad.dispose();
          _isRewardedInterstitialAdLoaded = false;
          loadRewardedInterstitialAd(); // 광고 표시 실패 시 새로운 광고 로드
          onAdClosed(); // 광고 실패 시 콜백 호출
        },
        onAdShowedFullScreenContent: (RewardedInterstitialAd ad) =>
            print('보상형 전면 광고가 표시됨'),
        onAdImpression: (RewardedInterstitialAd ad) => print('보상형 전면 광고 인상 발생'),
      );

      _rewardedInterstitialAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('사용자가 보상을 받았습니다: ${reward.amount} ${reward.type}');
        onUserEarnedReward(reward);
      });

      _isRewardedInterstitialAdLoaded = false;
      _rewardedInterstitialAd = null;
    } else {
      print('보상형 전면 광고가 로드되지 않았습니다.');
      onAdClosed(); // 광고가 로드되지 않았을 때 콜백 호출
    }
  }
}
