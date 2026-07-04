import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_helper.dart';

class PresetUpdateReviewDecision {
  final bool shouldShowReview;
  final bool isFreshInstall;
  final String currentVersion;

  const PresetUpdateReviewDecision({
    required this.shouldShowReview,
    required this.isFreshInstall,
    required this.currentVersion,
  });
}

class PresetUpdateReviewService {
  static const String lastSeenAppVersionKey = 'lastSeenAppVersion';
  static const String lastPresetReviewAppVersionKey =
      'lastPresetReviewAppVersion';

  static Future<PresetUpdateReviewDecision> evaluateLaunch({
    SharedPreferences? prefs,
    String? currentVersion,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final resolvedVersion = currentVersion ?? await _currentAppVersion();

    final lastSeenVersion =
        resolvedPrefs.getString(lastSeenAppVersionKey)?.trim();
    final lastReviewVersion =
        resolvedPrefs.getString(lastPresetReviewAppVersionKey)?.trim();
    final hasPresetSettings =
        SettingsHelper.hasSavedPresetSettings(resolvedPrefs);

    final isFreshInstall =
        (lastSeenVersion == null || lastSeenVersion.isEmpty) &&
            !hasPresetSettings;

    if (isFreshInstall) {
      await resolvedPrefs.setString(lastSeenAppVersionKey, resolvedVersion);
      return PresetUpdateReviewDecision(
        shouldShowReview: false,
        isFreshInstall: true,
        currentVersion: resolvedVersion,
      );
    }

    final reviewAlreadyCompleted = lastReviewVersion == resolvedVersion;
    final sameVersionAlreadySeen = lastSeenVersion == resolvedVersion;

    if (reviewAlreadyCompleted || sameVersionAlreadySeen) {
      return PresetUpdateReviewDecision(
        shouldShowReview: false,
        isFreshInstall: false,
        currentVersion: resolvedVersion,
      );
    }

    return PresetUpdateReviewDecision(
      shouldShowReview: true,
      isFreshInstall: false,
      currentVersion: resolvedVersion,
    );
  }

  static Future<void> markReviewComplete({
    SharedPreferences? prefs,
    String? currentVersion,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final resolvedVersion = currentVersion ?? await _currentAppVersion();

    await resolvedPrefs.setString(
      lastPresetReviewAppVersionKey,
      resolvedVersion,
    );
    await resolvedPrefs.setString(lastSeenAppVersionKey, resolvedVersion);
  }

  static Future<String> _currentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      debugPrint('[PresetUpdateReview] Failed to read app version: $e');
      return 'unknown';
    }
  }
}
