import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/services/result_exit_interstitial_policy.dart';

void main() {
  const policy = ResultExitInterstitialPolicy();
  final now = DateTime(2026, 8, 3, 12);

  ResultExitInterstitialDecision evaluate({
    required int exitCount,
    DateTime? lastShownAt,
    bool isAdRemoved = false,
    bool isSubscribed = false,
    bool isTutorial = false,
    bool isFromHistory = false,
    bool adReady = true,
    bool alreadyShowing = false,
  }) {
    return policy.evaluate(
      exitCount: exitCount,
      lastShownAt: lastShownAt,
      now: now,
      isAdRemoved: isAdRemoved,
      isSubscribed: isSubscribed,
      isTutorial: isTutorial,
      isFromHistory: isFromHistory,
      adReady: adReady,
      alreadyShowing: alreadyShowing,
    );
  }

  group('ResultExitInterstitialPolicy', () {
    test('shows only on every fourth eligible result exit', () {
      for (var exitCount = 1; exitCount < 4; exitCount++) {
        final decision = evaluate(exitCount: exitCount);
        expect(decision.shouldShow, isFalse);
        expect(decision.reason, 'frequency_not_met');
        expect(decision.shouldCountExit, isTrue);
      }

      final fourth = evaluate(exitCount: 4);
      expect(fourth.shouldShow, isTrue);
      expect(fourth.reason, 'eligible');
      expect(fourth.shouldCountExit, isTrue);
    });

    test('enforces the three minute cooldown after a shown ad', () {
      final decision = evaluate(
        exitCount: 4,
        lastShownAt: now.subtract(const Duration(minutes: 2)),
      );

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'cooldown');
      expect(decision.cooldownRemaining, const Duration(minutes: 1));

      final afterCooldown = evaluate(
        exitCount: 4,
        lastShownAt: now.subtract(const Duration(minutes: 3)),
      );
      expect(afterCooldown.shouldShow, isTrue);
    });

    test('excludes premium and ad removed users from counting and showing', () {
      final premium = evaluate(exitCount: 4, isSubscribed: true);
      expect(premium.shouldShow, isFalse);
      expect(premium.reason, 'premium');
      expect(premium.shouldCountExit, isFalse);

      final adRemoved = evaluate(exitCount: 4, isAdRemoved: true);
      expect(adRemoved.shouldShow, isFalse);
      expect(adRemoved.reason, 'ad_removed');
      expect(adRemoved.shouldCountExit, isFalse);
    });

    test('excludes tutorial and history results from counting and showing', () {
      final tutorial = evaluate(exitCount: 4, isTutorial: true);
      expect(tutorial.shouldShow, isFalse);
      expect(tutorial.reason, 'tutorial');
      expect(tutorial.shouldCountExit, isFalse);

      final history = evaluate(exitCount: 4, isFromHistory: true);
      expect(history.shouldShow, isFalse);
      expect(history.reason, 'history');
      expect(history.shouldCountExit, isFalse);
    });

    test('does not show when the ad is not ready or already showing', () {
      final notReady = evaluate(exitCount: 4, adReady: false);
      expect(notReady.shouldShow, isFalse);
      expect(notReady.reason, 'ad_not_ready');
      expect(notReady.shouldCountExit, isTrue);

      final alreadyShowing = evaluate(exitCount: 4, alreadyShowing: true);
      expect(alreadyShowing.shouldShow, isFalse);
      expect(alreadyShowing.reason, 'already_showing');
      expect(alreadyShowing.shouldCountExit, isTrue);
    });
  });
}
