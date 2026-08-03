class PremiumAutoPromptDecision {
  const PremiumAutoPromptDecision({
    required this.shouldShow,
    required this.reason,
    required this.shouldCountHomeEntry,
    this.cooldownRemaining = Duration.zero,
  });

  final bool shouldShow;
  final String reason;
  final bool shouldCountHomeEntry;
  final Duration cooldownRemaining;
}

class PremiumAutoPromptPolicy {
  static const int homeEntryInterval = 3;
  static const Duration cooldown = Duration(days: 7);

  const PremiumAutoPromptPolicy();

  static String homeEntryCountPrefsKey(String uid) =>
      'premium_auto_prompt_home_entry_count_$uid';

  static String lastShownAtPrefsKey(String uid) =>
      'premium_auto_prompt_last_shown_at_$uid';

  bool shouldShow({
    required int homeEntryCount,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool isGuest,
    required bool isSubscribed,
    required bool isAdRemoved,
    required bool entitlementLoaded,
    required bool shownThisSession,
    required bool manuallyOpenedThisSession,
    bool routeIsCurrent = true,
  }) {
    return evaluate(
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
    ).shouldShow;
  }

  PremiumAutoPromptDecision evaluate({
    required int homeEntryCount,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool isGuest,
    required bool isSubscribed,
    required bool isAdRemoved,
    required bool entitlementLoaded,
    required bool shownThisSession,
    required bool manuallyOpenedThisSession,
    bool routeIsCurrent = true,
  }) {
    if (!routeIsCurrent) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'route_not_current',
        shouldCountHomeEntry: false,
      );
    }

    if (!isGuest) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'not_guest',
        shouldCountHomeEntry: false,
      );
    }

    if (!entitlementLoaded) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'entitlement_loading',
        shouldCountHomeEntry: false,
      );
    }

    if (isSubscribed) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'premium',
        shouldCountHomeEntry: false,
      );
    }

    if (isAdRemoved) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'ad_removed',
        shouldCountHomeEntry: false,
      );
    }

    if (homeEntryCount < homeEntryInterval) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'entry_count_not_met',
        shouldCountHomeEntry: true,
      );
    }

    final remaining = cooldownRemaining(lastShownAt: lastShownAt, now: now);
    if (remaining > Duration.zero) {
      return PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'cooldown',
        shouldCountHomeEntry: true,
        cooldownRemaining: remaining,
      );
    }

    if (shownThisSession) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'shown_this_session',
        shouldCountHomeEntry: true,
      );
    }

    if (manuallyOpenedThisSession) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'manually_opened_this_session',
        shouldCountHomeEntry: true,
      );
    }

    return const PremiumAutoPromptDecision(
      shouldShow: true,
      reason: 'eligible',
      shouldCountHomeEntry: true,
    );
  }

  Duration cooldownRemaining({
    required DateTime? lastShownAt,
    required DateTime now,
  }) {
    if (lastShownAt == null) return Duration.zero;

    final elapsed = now.difference(lastShownAt);
    if (elapsed < Duration.zero) return cooldown;
    if (elapsed >= cooldown) return Duration.zero;
    return cooldown - elapsed;
  }
}
