import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  bool _initialized = false;
  String _appVersion = 'unknown';
  String _buildNumber = 'unknown';
  String _platform = Platform.isIOS ? 'ios' : 'android';
  String _premiumStatus = 'free';

  Future<void> init() async {
    if (_initialized) return;
    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;
    _buildNumber = info.buildNumber;

    final prefs = await SharedPreferences.getInstance();
    _premiumStatus = prefs.getString('analytics_premium_status') ?? 'free';

    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.setDefaultEventParameters(_baseParams());
    _initialized = true;
  }

  Map<String, Object> _baseParams() {
    return {
      'platform': _platform,
      'app_version': _appVersion,
      'build_number': _buildNumber,
      'premium_status': _premiumStatus,
    };
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
    bool alsoRecordCrashlyticsBreadcrumb = true,
  }) async {
    final merged = <String, Object?>{..._baseParams(), ...params}
      ..removeWhere((key, value) => value == null);

    final normalized = merged.map((key, value) => MapEntry(key, value as Object));

    assert(() {
      if (name.length > 40) {
        debugPrint('Analytics event name too long: $name');
      }
      normalized.forEach((key, value) {
        if (key.length > 40) {
          debugPrint('Analytics param key too long: $key');
        }
        if (value is String && value.length > 100) {
          debugPrint('Analytics param value too long for $key');
        }
      });
      return true;
    }());

    await analytics.logEvent(name: name, parameters: normalized);

    if (alsoRecordCrashlyticsBreadcrumb) {
      FirebaseCrashlytics.instance.log('analytics:$name:${normalized.toString()}');
    }
  }

  Future<void> setUserId(String? userId) async {
    await analytics.setUserId(id: userId);
    await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? 'anonymous');
  }

  Future<void> setCurrentScreen(String screenName) async {
    await analytics.logScreenView(screenName: screenName, screenClass: screenName);
  }

  Future<void> setPremiumStatus(String status) async {
    _premiumStatus = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('analytics_premium_status', status);
    await analytics.setUserProperty(name: 'premium_status', value: status);
    await analytics.setDefaultEventParameters(_baseParams());
  }

  Future<void> logAppOpen() => logEvent('app_open_custom');
  Future<void> logFirstOpen() => logEvent('first_open_custom');

  Future<void> logOnboardingStart({String source = 'preset'}) =>
      logEvent('onboarding_start', params: {'source': source});

  Future<void> logOnboardingComplete({required String path}) =>
      logEvent('onboarding_complete', params: {'path': path});

  Future<void> logScanStarted({
    required String scanMode,
    required String entryPoint,
    int imageCount = 1,
  }) =>
      logEvent('scan_started', params: {
        'scan_mode': scanMode,
        'entry_point': entryPoint,
        'image_count': imageCount,
      });

  Future<void> logScanSuccess({
    required String scanMode,
    required int imageCount,
    required int latencyMs,
  }) =>
      logEvent('scan_success', params: {
        'scan_mode': scanMode,
        'image_count': imageCount,
        'latency_ms': latencyMs,
      });

  Future<void> logScanFailed({
    required String scanMode,
    String? stage,
    String? errorCode,
  }) =>
      logEvent('scan_failed', params: {
        'scan_mode': scanMode,
        'stage': stage ?? 'unknown',
        'error_code': errorCode ?? 'unknown',
      });

  Future<void> logResultViewed({String entryPoint = 'scan_result'}) =>
      logEvent('result_viewed', params: {'entry_point': entryPoint});

  Future<void> logShareResult({required String channel}) =>
      logEvent('share_result', params: {'channel': channel});

  Future<void> logPaywallView({required String source, String? trigger}) =>
      logEvent('paywall_view', params: {
        'source': source,
        'trigger': trigger ?? 'default',
      });

  Future<void> logPlanSelected({required String productId}) =>
      logEvent('plan_selected', params: {'product_id': productId});

  Future<void> logPurchaseStart({required String productId}) =>
      logEvent('purchase_started', params: {'product_id': productId});

  Future<void> logPurchaseSuccess({
    required String productId,
    String? currency,
    double? priceLocal,
  }) =>
      logEvent('purchase_success', params: {
        'product_id': productId,
        'currency': currency,
        'price_local': priceLocal,
      });

  Future<void> logPurchaseFailed({
    required String productId,
    String? errorCode,
    String? errorMsg,
  }) =>
      logEvent('purchase_failed', params: {
        'product_id': productId,
        'error_code': errorCode ?? 'unknown',
        'error_msg': errorMsg,
      });

  Future<void> logPurchaseRestoreStarted() => logEvent('purchase_restore_started');
  Future<void> logPurchaseRestoreSuccess() => logEvent('purchase_restore_success');
  Future<void> logPurchaseRestoreEmpty() => logEvent('purchase_restore_empty');

  Future<void> logExchangeRateViewed({String source = 'result'}) =>
      logEvent('exchange_rate_viewed', params: {'source': source});
}
