import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/services/multi_scan_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const policy = MultiScanUsagePolicy();
  final day = DateTime(2026, 9, 5, 12);

  test('Guest/free first Multi Scan of a day skips the interstitial', () {
    final decision = policy.evaluate(
      isPremium: false,
      isAdRemoved: false,
      usageDate: policy.dateKey(day),
      usageCount: 0,
      now: day,
    );

    expect(decision.shouldShowInterstitial, isFalse);
    expect(decision.shouldRecordUsage, isTrue);
    expect(decision.reason, MultiScanAdReason.firstDailyScan);
  });

  test('Guest/free second and later scans require the interstitial', () {
    final decision = policy.evaluate(
      isPremium: false,
      isAdRemoved: false,
      usageDate: policy.dateKey(day),
      usageCount: 1,
      now: day,
    );

    expect(decision.shouldShowInterstitial, isTrue);
    expect(decision.reason, MultiScanAdReason.repeatDailyScan);
  });

  test('A new local day resets the no-ad allowance', () {
    final decision = policy.evaluate(
      isPremium: false,
      isAdRemoved: false,
      usageDate: policy.dateKey(day),
      usageCount: 4,
      now: day.add(const Duration(days: 1)),
    );

    expect(decision.shouldShowInterstitial, isFalse);
    expect(decision.dailyCount, 0);
  });

  test('Premium and existing ad-free entitlement bypass the gate', () {
    final premium = policy.evaluate(
      isPremium: true,
      isAdRemoved: false,
      usageDate: policy.dateKey(day),
      usageCount: 10,
      now: day,
    );
    final adFree = policy.evaluate(
      isPremium: false,
      isAdRemoved: true,
      usageDate: policy.dateKey(day),
      usageCount: 10,
      now: day,
    );

    expect(premium.shouldShowInterstitial, isFalse);
    expect(premium.shouldRecordUsage, isFalse);
    expect(adFree.shouldShowInterstitial, isFalse);
    expect(adFree.shouldRecordUsage, isFalse);
  });

  test('checking usage does not count a cancelled scan', () async {
    SharedPreferences.setMockInitialValues({});
    final coordinator = MultiScanStartCoordinator(
      usage: MultiScanUsageService(),
      showInterstitial: () async => true,
    );

    final result = await coordinator.start(
      isPremium: false,
      isAdRemoved: false,
      canContinue: () => false,
      now: day,
    );

    expect(result.recordedCount, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(MultiScanUsagePolicy.usageCountPrefsKey), isNull);
  });

  test('an unavailable interstitial is fail-open and usage still starts',
      () async {
    SharedPreferences.setMockInitialValues({
      MultiScanUsagePolicy.usageDatePrefsKey: policy.dateKey(day),
      MultiScanUsagePolicy.usageCountPrefsKey: 1,
    });
    final coordinator = MultiScanStartCoordinator(
      usage: MultiScanUsageService(),
      showInterstitial: () async => false,
    );

    final result = await coordinator.start(
      isPremium: false,
      isAdRemoved: false,
      now: day,
    );

    expect(result.interstitialAttempted, isTrue);
    expect(result.interstitialShown, isFalse);
    expect(result.recordedCount, 2);
  });
}
