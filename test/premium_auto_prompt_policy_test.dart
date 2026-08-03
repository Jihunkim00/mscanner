import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/services/premium_auto_prompt_policy.dart';

void main() {
  const policy = PremiumAutoPromptPolicy();
  final now = DateTime(2026, 8, 3, 12);

  PremiumAutoPromptDecision evaluate({
    int homeEntryCount = 3,
    DateTime? lastShownAt,
    bool isGuest = true,
    bool isSubscribed = false,
    bool isAdRemoved = false,
    bool entitlementLoaded = true,
    bool shownThisSession = false,
    bool manuallyOpenedThisSession = false,
    bool routeIsCurrent = true,
  }) {
    return policy.evaluate(
      homeEntryCount: homeEntryCount,
      lastShownAt: lastShownAt,
      now: now,
      isGuest: isGuest,
      isSubscribed: isSubscribed,
      isAdRemoved: isAdRemoved,
      entitlementLoaded: entitlementLoaded,
      shownThisSession: shownThisSession,
      manuallyOpenedThisSession: manuallyOpenedThisSession,
      routeIsCurrent: routeIsCurrent,
    );
  }

  group('PremiumAutoPromptPolicy', () {
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

    test('can show on the third guest Home entry without prior display', () {
      final decision = evaluate(homeEntryCount: 3);

      expect(decision.shouldShow, isTrue);
      expect(decision.reason, 'eligible');
      expect(decision.shouldCountHomeEntry, isTrue);
    });

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

    test('excludes non-guest users from counting and showing', () {
      final decision = evaluate(isGuest: false);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'not_guest');
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('does not count or show while entitlement is loading', () {
      final decision = evaluate(entitlementLoaded: false);

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'entitlement_loading');
      expect(decision.shouldCountHomeEntry, isFalse);
    });

    test('does not show inside the seven day cooldown', () {
      final decision = evaluate(
        lastShownAt: now.subtract(const Duration(days: 3)),
      );

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'cooldown');
      expect(decision.cooldownRemaining, const Duration(days: 4));
      expect(decision.shouldCountHomeEntry, isTrue);
    });

    test('can show after the seven day cooldown has elapsed', () {
      final decision = evaluate(
        lastShownAt: now.subtract(const Duration(days: 8)),
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

    test('handles a future last shown time without crashing', () {
      final decision = evaluate(lastShownAt: now.add(const Duration(days: 1)));

      expect(decision.shouldShow, isFalse);
      expect(decision.reason, 'cooldown');
      expect(decision.cooldownRemaining, PremiumAutoPromptPolicy.cooldown);
    });
  });
}
