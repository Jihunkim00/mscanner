import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/services/premium_auto_prompt_policy.dart';

void main() {
  const policy = PremiumAutoPromptPolicy();
  final now = DateTime(2026, 8, 3, 12);

  PremiumAutoPromptDecision evaluate({
    PremiumAutoPromptAudience audience = PremiumAutoPromptAudience.guest,
    int homeEntryCount = 3,
    DateTime? lastShownAt,
    bool isSubscribed = false,
    bool isAdRemoved = false,
    bool entitlementLoaded = true,
    bool shownThisSession = false,
    bool manuallyOpenedThisSession = false,
    bool routeIsCurrent = true,
    bool recentInterstitial = false,
  }) {
    return policy.evaluate(
      audience: audience,
      homeEntryCount: homeEntryCount,
      lastShownAt: lastShownAt,
      now: now,
      isSubscribed: isSubscribed,
      isAdRemoved: isAdRemoved,
      entitlementLoaded: entitlementLoaded,
      shownThisSession: shownThisSession,
      manuallyOpenedThisSession: manuallyOpenedThisSession,
      routeIsCurrent: routeIsCurrent,
      recentInterstitial: recentInterstitial,
    );
  }

  group('PremiumAutoPromptPolicy entitlement retry contract', () {
    test('does not count before entitlement and counts once after loading', () {
      var storedCount = 0;
      var processing = false;
      var processed = false;

      void tryProcess({required bool entitlementLoaded}) {
        if (processing || processed) return;

        final decision = evaluate(
          homeEntryCount: storedCount,
          entitlementLoaded: entitlementLoaded,
        );
        if (!entitlementLoaded) {
          expect(decision.reason, 'entitlement_loading');
          expect(decision.shouldCountHomeEntry, isFalse);
          return;
        }

        processing = true;
        if (decision.shouldCountHomeEntry) {
          storedCount = math.min(
            storedCount + 1,
            PremiumAutoPromptPolicy.homeEntryInterval,
          );
          processed = true;
        }
        processing = false;
      }

      tryProcess(entitlementLoaded: false);
      expect(storedCount, 0);
      expect(processed, isFalse);

      tryProcess(entitlementLoaded: true);
      expect(storedCount, 1);
      expect(processed, isTrue);

      tryProcess(entitlementLoaded: true);
      expect(storedCount, 1);
    });
  });

  group('PremiumAutoPromptPolicy guest audience', () {
    test('does not show on the first guest Home entry', () {
      final decision = evaluate(homeEntryCount: 1);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'entry_count_not_met');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('does not show on the second guest Home entry', () {
      final decision = evaluate(homeEntryCount: 2);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'entry_count_not_met');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('can show on the third guest Home entry', () {
      final decision = evaluate(homeEntryCount: 3);

      expect(decision.shouldShow, isTrue);
      expect(decision.reason, 'eligible');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('ignores date cooldown for guests', () {
      final decision = evaluate(
        homeEntryCount: 3,
        lastShownAt: now.subtract(const Duration(minutes: 1)),
      );

      expect(decision.shouldShow, isTrue);
      expect(decision.reason, 'eligible');
    });

    test('does not show when already auto-shown this session', () {
      final decision = evaluate(shownThisSession: true);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'shown_this_session');
      expect(decision.shouldCountHomeEntry, isTrue);
    });
  });

  group('PremiumAutoPromptPolicy registered free audience', () {
    test('can show on third Home entry without prior display', () {
      final decision = evaluate(
        audience: PremiumAutoPromptAudience.registeredFree,
        homeEntryCount: 3,
      );

      expect(decision.shouldShow, isTrue);
      expect(decision.reason, 'eligible');
    });

    test('does not count or show during registered cooldown', () {
      final decision = evaluate(
        audience: PremiumAutoPromptAudience.registeredFree,
        homeEntryCount: 3,
        lastShownAt: now.subtract(const Duration(days: 3)),
      );

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'registered_cooldown');
      expect(decision.cooldownRemaining, const Duration(days: 4));
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('starts counting again after registered cooldown elapses', () {
      final decision = evaluate(
        audience: PremiumAutoPromptAudience.registeredFree,
        homeEntryCount: 1,
        lastShownAt: now.subtract(const Duration(days: 8)),
      );

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'entry_count_not_met');
      expect(decision.shouldCountHomeEntry, isTrue);
    });
  });

  group('PremiumAutoPromptPolicy result interstitial timestamp window', () {
    const cooldown = Duration(minutes: 5);

    test('treats 30 seconds ago as recent', () {
      expect(
        policy.isRecentInterstitial(
          lastShownAt: now.subtract(const Duration(seconds: 30)),
          now: now,
          cooldown: cooldown,
        ),
        isTrue,
      );
    });

    test('treats 4 minutes ago as recent', () {
      expect(
        policy.isRecentInterstitial(
          lastShownAt: now.subtract(const Duration(minutes: 4)),
          now: now,
          cooldown: cooldown,
        ),
        isTrue,
      );
    });

    test('does not treat exactly 5 minutes ago as recent', () {
      expect(
        policy.isRecentInterstitial(
          lastShownAt: now.subtract(const Duration(minutes: 5)),
          now: now,
          cooldown: cooldown,
        ),
        isFalse,
      );
    });

    test('does not block when timestamp is missing', () {
      expect(
        policy.isRecentInterstitial(
          lastShownAt: null,
          now: now,
          cooldown: cooldown,
        ),
        isFalse,
      );
    });

    test('treats future timestamps as recent', () {
      expect(
        policy.isRecentInterstitial(
          lastShownAt: now.add(const Duration(minutes: 1)),
          now: now,
          cooldown: cooldown,
        ),
        isTrue,
      );
    });
  });
  group('PremiumAutoPromptPolicy result interstitial deferral', () {
    test('defers premium prompt after a recent result interstitial', () {
      final decision = evaluate(
        homeEntryCount: 3,
        recentInterstitial: true,
      );

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'recent_interstitial');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('does not reset or advance count past the threshold when deferred',
        () {
      const countBefore = 3;
      final countAfter = math.min(
        countBefore + 1,
        PremiumAutoPromptPolicy.homeEntryInterval,
      );
      final decision = evaluate(
        homeEntryCount: countAfter,
        recentInterstitial: true,
      );

      expect(countAfter, 3);
      expect(decision.reason, 'recent_interstitial');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('allows prompt once the five minute interstitial window is not recent',
        () {
      final exactlyFiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      final elapsed = now.difference(exactlyFiveMinutesAgo);
      final recent = elapsed < const Duration(minutes: 5);

      final decision = evaluate(
        homeEntryCount: 3,
        recentInterstitial: recent,
      );

      expect(recent, isFalse);
      expect(decision.shouldShow, isTrue);
      expect(decision.reason, 'eligible');
    });

    test('does not block when no interstitial timestamp exists', () {
      final decision = evaluate(homeEntryCount: 3, recentInterstitial: false);

      expect(decision.shouldShow, isTrue);
      expect(decision.reason, 'eligible');
    });

    test('cancels a scheduled prompt if interstitial becomes recent', () {
      final scheduled = evaluate(homeEntryCount: 3, recentInterstitial: false);
      final afterDelay = evaluate(homeEntryCount: 3, recentInterstitial: true);

      expect(scheduled.shouldShow, isTrue);
      expect(afterDelay.shouldShow, isFalse);
      expect(afterDelay.reason, 'recent_interstitial');
      expect(afterDelay.shouldCountHomeEntry, isTrue);
    });
  });

  group('PremiumAutoPromptPolicy common exclusions', () {
    test('excludes premium users from counting and showing', () {
      final decision = evaluate(isSubscribed: true);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'premium');
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('excludes ad removed users from counting and showing', () {
      final decision = evaluate(isAdRemoved: true);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'ad_removed');
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('excludes signed-out users from counting and showing', () {
      final decision = evaluate(audience: PremiumAutoPromptAudience.ineligible);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'ineligible');
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('does not count or show while entitlement is loading', () {
      final decision = evaluate(entitlementLoaded: false);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'entitlement_loading');
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('does not show after manual Premium entry in the same session', () {
      final decision = evaluate(manuallyOpenedThisSession: true);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'manually_opened_this_session');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('does not count or show when Home is not the current route', () {
      final decision = evaluate(routeIsCurrent: false);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'route_not_current');
      expect(decision.shouldCountHomeEntry, isFalse);
    });
  });
}
