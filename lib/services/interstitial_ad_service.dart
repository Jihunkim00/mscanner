import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdService {
  InterstitialAdService._();

  static final InterstitialAdService instance = InterstitialAdService._();

  static const Duration _loadRetryDelay = Duration(seconds: 30);

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _disposed = false;
  bool _lastNonPersonalized = false;
  Timer? _retryTimer;

  bool get isReady => _interstitialAd != null && !_isShowing;
  bool get isShowing => _isShowing;

  Future<void> preload({bool? nonPersonalized}) async {
    _disposed = false;
    final useNonPersonalized = nonPersonalized ?? _lastNonPersonalized;
    _lastNonPersonalized = useNonPersonalized;

    if (_isLoading || _isShowing || _interstitialAd != null) return;

    _retryTimer?.cancel();
    _isLoading = true;

    final completer = Completer<void>();
    final request = useNonPersonalized
        ? AdRequest(extras: const {'npa': '1'})
        : const AdRequest();

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          if (_disposed) {
            ad.dispose();
          } else {
            _interstitialAd?.dispose();
            _interstitialAd = ad;
            debugPrint('Interstitial ad loaded ($_adUnitId)');
          }
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _interstitialAd = null;
          debugPrint('Interstitial ad failed to load: $error');
          _scheduleRetry(useNonPersonalized);
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    return completer.future;
  }

  Future<bool> show() async {
    if (_isShowing) return false;

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(preload());
      return false;
    }

    _interstitialAd = null;
    _isShowing = true;

    final completer = Completer<bool>();
    bool finished = false;

    void finish({required bool shown}) {
      if (finished) return;
      finished = true;
      ad.dispose();
      _isShowing = false;
      unawaited(preload());
      if (!completer.isCompleted) completer.complete(shown);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        debugPrint('Interstitial ad dismissed');
        finish(shown: true);
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial ad failed to show: $error');
        finish(shown: false);
      },
    );

    try {
      await ad.show();
    } catch (error) {
      debugPrint('Interstitial ad show threw: $error');
      finish(shown: false);
    }

    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
    _isShowing = false;
  }

  static String get _adUnitId {
    if (Platform.isIOS) {
      return 'ca-app-pub-2942885230901008/8324808650';
    }
    return 'ca-app-pub-2942885230901008/5920902942';
  }

  void _scheduleRetry(bool nonPersonalized) {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_loadRetryDelay, () {
      unawaited(preload(nonPersonalized: nonPersonalized));
    });
  }
}
