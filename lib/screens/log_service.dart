// log_service.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 추가

class LogService {
  static final LogService _instance = LogService._internal();

  factory LogService() => _instance;

  LogService._internal();

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

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

    final locale = WidgetsBinding.instance.window.locale;
    return {
      'device': deviceModel,
      'os': osVersion,
      'lang_cd': locale.languageCode,
      'country_cd': locale.countryCode ?? 'XX',
    };
  }

  Future<void> sendLog(int logDiv) async {
    final uuid = await getUuid();
    final deviceInfo = await _getDeviceInfo();

    // 앱 버전 정보 가져오기
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    await FirebaseFirestore.instance.collection('logs').add({
      'log_div': logDiv,
      'log_date': DateTime.now().toUtc().toIso8601String(),
      'user_id': uuid,
      'app_version': appVersion,     // ✅ 앱 버전 추가
      'build_number': buildNumber,   // ✅ 빌드 번호 추가
      ...deviceInfo,
    });
  }

  // 로그인 성공 후 호출할 함수
  Future<void> logLoginSuccess() async {
    await sendLog(2);
  }

  // 스캔 성공 후 호출할 함수
  Future<void> logScanCompleted() async {
    await sendLog(10);
  }
}
