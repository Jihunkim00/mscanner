import 'package:shared_preferences/shared_preferences.dart';

enum MultiScanAdReason {
  premium,
  adRemoved,
  firstDailyScan,
  repeatDailyScan,
}

class MultiScanAdDecision {
  const MultiScanAdDecision({
    required this.shouldShowInterstitial,
    required this.shouldRecordUsage,
    required this.reason,
    required this.dailyCount,
  });

  final bool shouldShowInterstitial;
  final bool shouldRecordUsage;
  final MultiScanAdReason reason;
  final int dailyCount;
}

/// Central policy for the free Multi Scan allowance.
class MultiScanUsagePolicy {
  static const int freeMultiScanWithoutAdPerDay = 1;
  static const String usageDatePrefsKey = 'multiScanUsageDate';
  static const String usageCountPrefsKey = 'multiScanUsageCount';

  const MultiScanUsagePolicy();

  String dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  MultiScanAdDecision evaluate({
    required bool isPremium,
    required bool isAdRemoved,
    required String? usageDate,
    required int usageCount,
    required DateTime now,
  }) {
    if (isPremium) {
      return const MultiScanAdDecision(
        shouldShowInterstitial: false,
        shouldRecordUsage: false,
        reason: MultiScanAdReason.premium,
        dailyCount: 0,
      );
    }

    if (isAdRemoved) {
      return const MultiScanAdDecision(
        shouldShowInterstitial: false,
        shouldRecordUsage: false,
        reason: MultiScanAdReason.adRemoved,
        dailyCount: 0,
      );
    }

    final today = dateKey(now);
    final normalizedCount =
        usageDate == today ? usageCount.clamp(0, 1 << 30).toInt() : 0;
    final hasUsedFreeAllowance =
        normalizedCount >= freeMultiScanWithoutAdPerDay;

    return MultiScanAdDecision(
      shouldShowInterstitial: hasUsedFreeAllowance,
      shouldRecordUsage: true,
      reason: hasUsedFreeAllowance
          ? MultiScanAdReason.repeatDailyScan
          : MultiScanAdReason.firstDailyScan,
      dailyCount: normalizedCount,
    );
  }
}

class MultiScanStartResult {
  const MultiScanStartResult({
    required this.decision,
    required this.interstitialAttempted,
    required this.interstitialShown,
    required this.recordedCount,
  });

  final MultiScanAdDecision decision;
  final bool interstitialAttempted;
  final bool interstitialShown;
  final int? recordedCount;
}

/// Coordinates the ad gate and usage write without coupling policy tests to
/// the Google Mobile Ads SDK.
class MultiScanStartCoordinator {
  const MultiScanStartCoordinator({
    required this.usage,
    required this.showInterstitial,
  });

  final MultiScanUsageService usage;
  final Future<bool> Function() showInterstitial;

  Future<MultiScanStartResult> start({
    required bool isPremium,
    required bool isAdRemoved,
    bool Function()? canContinue,
    DateTime? now,
  }) async {
    final decision = await usage.evaluate(
      isPremium: isPremium,
      isAdRemoved: isAdRemoved,
      now: now,
    );

    var interstitialShown = false;
    if (decision.shouldShowInterstitial) {
      try {
        interstitialShown = await showInterstitial();
      } catch (_) {
        interstitialShown = false;
      }
    }

    if (canContinue != null && !canContinue()) {
      return MultiScanStartResult(
        decision: decision,
        interstitialAttempted: decision.shouldShowInterstitial,
        interstitialShown: interstitialShown,
        recordedCount: null,
      );
    }

    int? recordedCount;
    if (decision.shouldRecordUsage) {
      recordedCount = await usage.recordScanStarted(now: now);
    }

    return MultiScanStartResult(
      decision: decision,
      interstitialAttempted: decision.shouldShowInterstitial,
      interstitialShown: interstitialShown,
      recordedCount: recordedCount,
    );
  }
}

class MultiScanUsageService {
  MultiScanUsageService({
    Future<SharedPreferences> Function()? preferencesProvider,
    MultiScanUsagePolicy policy = const MultiScanUsagePolicy(),
  })  : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance,
        _policy = policy;

  final Future<SharedPreferences> Function() _preferencesProvider;
  final MultiScanUsagePolicy _policy;

  Future<MultiScanAdDecision> evaluate({
    required bool isPremium,
    required bool isAdRemoved,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final prefs = await _preferencesProvider();
    return _policy.evaluate(
      isPremium: isPremium,
      isAdRemoved: isAdRemoved,
      usageDate: prefs.getString(MultiScanUsagePolicy.usageDatePrefsKey),
      usageCount: prefs.getInt(MultiScanUsagePolicy.usageCountPrefsKey) ?? 0,
      now: current,
    );
  }

  /// Records a scan only after the selected images are ready and the scan is
  /// about to start. Cancelled capture flows never call this method.
  Future<int> recordScanStarted({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final prefs = await _preferencesProvider();
    final today = _policy.dateKey(current);
    final storedDate = prefs.getString(MultiScanUsagePolicy.usageDatePrefsKey);
    final storedCount =
        prefs.getInt(MultiScanUsagePolicy.usageCountPrefsKey) ?? 0;
    final normalizedCount = storedCount.clamp(0, 1 << 30).toInt();
    final nextCount = storedDate == today ? normalizedCount + 1 : 1;

    await prefs.setString(MultiScanUsagePolicy.usageDatePrefsKey, today);
    await prefs.setInt(
      MultiScanUsagePolicy.usageCountPrefsKey,
      nextCount,
    );
    return nextCount;
  }
}
