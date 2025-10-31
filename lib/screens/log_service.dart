// log_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// 레거시 로그 저장 비활성화 플래그
const bool _legacyEnabled = false;

// ✅ DB 저장을 막을 "중복" div (BASE div 기준) — 필요 시 여기에만 추가/삭제
const Set<int> _disabledBaseDivs = {
  10,   // scan_result_received_success (요약) → 202(success)로 대체
  200,  // camera_open → 201(multi_scan_submit)로 대체
  500,  // history_open → 501(history_detail_view)로 대체
};

/// LogDiv 전략: result로 구분 vs 상태별로 code 분할
enum LogDivStrategy {
  singleWithResult,   // 하나의 log_div + result 필드(기본)
  splitByResult,      // result 별로 log_div를 분리(예: 2021/2022/2023)
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  /// 설정: log_div 분할 전략 (원하면 splitByResult 로 바꾸면 됩니다)
  LogDivStrategy logDivStrategy = LogDivStrategy.singleWithResult;

  // ───────────────────────── 공통 유틸 ─────────────────────────

  Future<String> getUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('uuid');
    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString('uuid', uuid);
    }
    return uuid;
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    String deviceModel = '';
    String osVersion = '';

    if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      deviceModel = iosInfo.utsname.machine ?? '';
      osVersion = iosInfo.systemVersion ?? '';
    } else if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      deviceModel = androidInfo.model ?? '';
      osVersion = androidInfo.version.release ?? '';
    }

    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return {
      'device': deviceModel,
      'os': osVersion,
      'lang_cd': locale.languageCode,
      'country_cd': locale.countryCode ?? 'XX',
    };
  }

  Future<Map<String, String>> _getAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'app_version': info.version,
      'build_number': info.buildNumber,
    };
  }

  /// 원시타입만 허용. List/Map/기타는 JSON 문자열로 변환하여 extras_* 에 저장
  dynamic _normalizeValue(dynamic v) {
    if (v == null) return null;
    if (v is String || v is num || v is bool) return v;
    try {
      return jsonEncode(v);
    } catch (_) {
      // 최후의 수단: toString()
      return v.toString();
    }
  }

  /// params(Map)을 extras_* 평탄 필드로 변환
  Map<String, dynamic> _flattenExtras(Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return {};
    final out = <String, dynamic>{};
    params.forEach((key, value) {
      final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_');
      out['extras_$safeKey'] = _normalizeValue(value);
    });
    return out;
  }

  /// result 별로 log_div 분할하고 싶을 때 매핑 규칙 정의
  /// 예시: 202(attempt/success/fail) → 2021/2022/2023
  int _mapLogDivByResult({
    required int baseDiv,
    required String result, // attempt|success|fail
  }) {
    if (logDivStrategy == LogDivStrategy.singleWithResult) return baseDiv;

    int offset;
    switch (result) {
      case 'attempt':
        offset = 1;
        break;
      case 'success':
        offset = 2;
        break;
      case 'fail':
        offset = 3;
        break;
      default:
        offset = 0; // unknown
    }
    return baseDiv * 10 + offset; // 202→2021/2022/2023
  }

  Future<void> _writeLog(Map<String, dynamic> payload) async {
    await FirebaseFirestore.instance.collection('logs').add({
      ...payload,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// (옵션) 저장 여부 결정 가드
  bool _shouldStore({
    required int baseDiv,
    required String eventName,
    required String result,
  }) {
    // BASE div 기준으로만 판단 (singleWithResult, splitByResult 모두 호환)
    if (_disabledBaseDivs.contains(baseDiv)) return false;
    return true;
  }

  Future<void> _log({
    required int logDiv,
    required String eventName,
    Map<String, dynamic>? params,
    String result = 'success', // attempt|success|fail
  }) async {

    if (!_shouldStore(baseDiv: logDiv, eventName: eventName, result: result)) {
      return;
    }
    final uuid = await getUuid();
    final deviceInfo = await _getDeviceInfo();
    final appInfo = await _getAppInfo();

    final flat = _flattenExtras(params);

    final resolvedDiv = _mapLogDivByResult(baseDiv: logDiv, result: result);

    await _writeLog({
      'log_div': resolvedDiv,
      'event_name': eventName,
      'result': result,
      'log_date': DateTime.now().toUtc().toIso8601String(),
      'user_id': uuid,
      ...appInfo,
      ...deviceInfo,
      // 🔽 모든 추가 값은 extras_* 로만 저장 (단일 레벨)
      ...flat,
    });
  }

  // ───────────────────────── 레거시 유지 ─────────────────────────
  Future<void> sendLog(int logDiv) async {

    if (!_legacyEnabled) return;
    final uuid = await getUuid();
    final deviceInfo = await _getDeviceInfo();
    final appInfo = await _getAppInfo();

    await FirebaseFirestore.instance.collection('logs').add({
      'log_div': logDiv,
      'event_name': 'legacy_$logDiv',
      'log_date': DateTime.now().toUtc().toIso8601String(),
      'user_id': uuid,
      ...appInfo,
      ...deviceInfo,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // 로그인 성공(레거시: div=2)
  Future<void> logLoginSuccess({String method = 'google'}) async {
    await sendLog(2);
    await _log(
      logDiv: 2,
      eventName: 'login_success',
      params: {'method': method},
      result: 'success',
    );
  }

  // 스캔 결과 수신 성공(레거시: div=10)
  Future<void> logScanCompleted({
    int? latencyMs,
    String? modelVer,
  }) async {
    await sendLog(10);
    await _log(
      logDiv: 10,
      eventName: 'scan_result_received_success',
      params: {'latency_ms': latencyMs, 'model_ver': modelVer},
      result: 'success',
    );
  }

  // 세션 중복 방지용(메모리)
  final Set<String> _sessionOnceKeys = {};

  bool _oncePerSession(String key) {
    if (_sessionOnceKeys.contains(key)) return false;
    _sessionOnceKeys.add(key);
    return true;
  }

// 일 1회 제한(SharedPreferences 사용)
  Future<bool> _oncePerDay(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final dayKey = 'log_once_day:$key:${now.year}-${now.month}-${now.day}';
    if (prefs.getBool(dayKey) == true) return false;
    await prefs.setBool(dayKey, true);
    return true;
  }

// 샘플링(0.0~1.0)
  bool _sample(double rate) {
    if (rate >= 1.0) return true;
    if (rate <= 0.0) return false;
    final r = (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
    return r < rate;
  }


  // ───────────────────────── 신규 이벤트 ─────────────────────────
  // A. 로그인
  Future<void> logLoginAttempt({String method = 'google'}) async =>
      _log(logDiv: 100, eventName: 'login_attempt', result: 'attempt', params: {'method': method});

  Future<void> logLoginFail({String method = 'google', String? errorCode, String? errorMsg}) async =>
      _log(logDiv: 101, eventName: 'login_fail', result: 'fail', params: {'method': method, 'error_code': errorCode, 'error_msg': errorMsg});

  Future<void> logPremiumLoginDetected({required bool isPremium, String? entitlement}) async =>
      _log(logDiv: 110, eventName: 'premium_login_detected', params: {'is_premium': isPremium, 'entitlement': entitlement});

  // B. 스캔 퍼널
  Future<void> logCameraOpen({String reason = 'quick'}) async =>
      _log(logDiv: 200, eventName: 'camera_open', result: 'attempt', params: {'reason': reason});

  Future<void> logMultiScanSubmit({required int imageCount, String source = 'gallery'}) async =>
      _log(logDiv: 201, eventName: 'multi_scan_submit', result: 'attempt', params: {'image_count': imageCount, 'source': source});

  Future<void> logScanResultAttempt({String modelVer = 'vX'}) async =>
      _log(logDiv: 202, eventName: 'scan_result_received', result: 'attempt', params: {'model_ver': modelVer});

  Future<void> logScanResultSuccess({required int latencyMs, required String modelVer, String? topLabel, bool? isMenuLike}) async =>
      _log(logDiv: 202, eventName: 'scan_result_received', result: 'success', params: {
        'latency_ms': latencyMs,
        'model_ver': modelVer,
        'top_label': topLabel,
        'is_menu_like': isMenuLike,
      });

  Future<void> logScanResultFail({required String modelVer, String? errorCode, String? errorMsg}) async =>
      _log(logDiv: 202, eventName: 'scan_result_received', result: 'fail', params: {
        'model_ver': modelVer,
        'error_code': errorCode,
        'error_msg': errorMsg,
      });

  // C. 환율
  Future<void> logCurrencyCalcOpen({required String from, required String to, String context = 'manual'}) async =>
      _log(logDiv: 400, eventName: 'currency_calc_open', result: 'attempt', params: {'from_currency': from, 'to_currency': to, 'context': context});

  // D. 결과 화면 액션
  Future<void> logShareClick({required String dest, String context = 'result'}) async =>
      _log(logDiv: 600, eventName: 'share_click', params: {'dest': dest, 'context': context});

  Future<void> logCopyClick({required String field}) async =>
      _log(logDiv: 601, eventName: 'copy_click', params: {'field': field});

  Future<void> logSaveClick({required bool hasComment, int contentLength = 0, String context = 'result'}) async =>
      _log(logDiv: 602, eventName: 'save_click', params: {'has_comment': hasComment, 'content_length': contentLength, 'context': context});

  Future<void> logRatingPrompt({required String action, int? stars}) async =>
      _log(logDiv: 603, eventName: 'rating_prompt', params: {'action': action, 'stars': stars});

  // E. 이력/지도
  Future<void> logHistoryOpen() async =>
      _log(logDiv: 500, eventName: 'history_open');

  Future<void> logHistoryDetailView({required int itemAgeDays, required String itemType}) async =>
      _log(logDiv: 501, eventName: 'history_detail_view', params: {'item_age_days': itemAgeDays, 'item_type': itemType});

  Future<void> logMapOpen({String provider = 'map', required String from}) async =>
      _log(logDiv: 502, eventName: 'map_open', params: {'provider': provider, 'from': from});

  Future<void> logContentImpression({
    required String contentType,
    required int count,
    double sampleRate = 1.0,
    bool oncePerSession = true,
    bool oncePerDay = false,
    bool debug = false, // ← 임시 디버그
  }) async {
    if (count <= 0) {
      if (debug) print('[logContentImpression] skip: count<=0');
      return;
    }
    if (contentType.isEmpty || contentType == 'none' || contentType == 'placeholder') {
      if (debug) print('[logContentImpression] skip: invalid contentType=$contentType');
      return;
    }
    if (!_sample(sampleRate)) {
      if (debug) print('[logContentImpression] skip: sampled out (rate=$sampleRate)');
      return;
    }
    final key = 'imp_$contentType';
    if (oncePerSession && !_oncePerSession(key)) {
      if (debug) print('[logContentImpression] skip: oncePerSession gate ($key)');
      return;
    }
    if (oncePerDay && !await _oncePerDay(key)) {
      if (debug) print('[logContentImpression] skip: oncePerDay gate ($key)');
      return;
    }

    await _log(
      logDiv: 300,
      eventName: 'content_impression',
      params: {
        'content_type': contentType,
        'count': count,
        'sample_rate': sampleRate,
      },
      result: 'success',
    );
    if (debug) print('[logContentImpression] stored: type=$contentType, count=$count');
  }


  // G. 매뉴얼/설정/프리셋
  Future<void> logManualOpen({required String entryPoint}) async =>
      _log(logDiv: 700, eventName: 'manual_open', params: {'entry_point': entryPoint});

  Future<void> logSettingsOpen() async =>
      _log(logDiv: 701, eventName: 'settings_open');

  Future<void> logPresetSave({required String presetType, required int fieldsCount}) async =>
      _log(logDiv: 702, eventName: 'preset_save', params: {'preset_type': presetType, 'fields_count': fieldsCount});

  // H. 프리미엄/결제
  Future<void> logPremiumCtaClick({required String placement, required String plan}) async =>
      _log(logDiv: 800, eventName: 'premium_cta_click', params: {'placement': placement, 'plan': plan});

  Future<void> logPurchaseStarted({required String productId}) async =>
      _log(logDiv: 801, eventName: 'purchase_flow_started', result: 'attempt', params: {'product_id': productId});

  Future<void> logPurchaseAcknowledged({required String productId, String? orderId}) async =>
      _log(logDiv: 802, eventName: 'purchase_flow_acknowledged', result: 'success', params: {'product_id': productId, 'order_id': orderId});

  Future<void> logPurchaseFailed({required String productId, String? errorCode, String? errorMsg}) async =>
      _log(logDiv: 802, eventName: 'purchase_flow_acknowledged', result: 'fail', params: {'product_id': productId, 'error_code': errorCode, 'error_msg': errorMsg});
}
