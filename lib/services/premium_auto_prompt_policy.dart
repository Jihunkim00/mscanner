enum PremiumAutoPromptAudience {
  guest,
  registeredFree,
  ineligible,
}

extension PremiumAutoPromptAudienceX on PremiumAutoPromptAudience {
  String get analyticsValue {
    switch (this) {
      case PremiumAutoPromptAudience.guest:
        return 'guest';
      case PremiumAutoPromptAudience.registeredFree:
        return 'registered_free';
      case PremiumAutoPromptAudience.ineligible:
        return 'ineligible';
    }
  }

  String get prefsSegment {
    switch (this) {
      case PremiumAutoPromptAudience.guest:
        return 'guest';
      case PremiumAutoPromptAudience.registeredFree:
        return 'registered';
      case PremiumAutoPromptAudience.ineligible:
        return 'ineligible';
    }
  }
}

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
  static const Duration registeredCooldown = Duration(days: 7);

  const PremiumAutoPromptPolicy();

  static String homeEntryCountPrefsKey(
    String uid,
    PremiumAutoPromptAudience audience,
  ) =>
      'premium_auto_prompt_home_entry_count_${audience.prefsSegment}_$uid';

  static String registeredLastShownAtPrefsKey(String uid) =>
      'premium_auto_prompt_last_shown_at_registered_$uid';

  bool shouldShow({
    required PremiumAutoPromptAudience audience,
    required int homeEntryCount,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool isSubscribed,
    required bool isAdRemoved,
    required bool entitlementLoaded,
    required bool shownThisSession,
    required bool manuallyOpenedThisSession,
    bool routeIsCurrent = true,
    bool recentInterstitial = false,
  }) {
    return evaluate(
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
    ).shouldShow;
  }

  PremiumAutoPromptDecision evaluate({
    required PremiumAutoPromptAudience audience,
    required int homeEntryCount,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool isSubscribed,
    required bool isAdRemoved,
    required bool entitlementLoaded,
    required bool shownThisSession,
    required bool manuallyOpenedThisSession,
    bool routeIsCurrent = true,
    bool recentInterstitial = false,
  }) {
    if (!routeIsCurrent) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'route_not_current',
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

    if (audience == PremiumAutoPromptAudience.ineligible) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'ineligible',
        shouldCountHomeEntry: false,
      );
    }

    if (audience == PremiumAutoPromptAudience.registeredFree) {
      final remaining = registeredCooldownRemaining(
        lastShownAt: lastShownAt,
        now: now,
      );
      if (remaining > Duration.zero) {
        return PremiumAutoPromptDecision(
          shouldShow: false,
          reason: 'registered_cooldown',
          shouldCountHomeEntry: false,
          cooldownRemaining: remaining,
        );
      }
    }

    if (homeEntryCount < homeEntryInterval) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'entry_count_not_met',
        shouldCountHomeEntry: true,
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

    if (recentInterstitial) {
      return const PremiumAutoPromptDecision(
        shouldShow: false,
        reason: 'recent_interstitial',
        shouldCountHomeEntry: true,
      );
    }

    return const PremiumAutoPromptDecision(
      shouldShow: true,
      reason: 'eligible',
      shouldCountHomeEntry: true,
    );
  }

  Duration registeredCooldownRemaining({
    required DateTime? lastShownAt,
    required DateTime now,
  }) {
    if (lastShownAt == null) return Duration.zero;

    final elapsed = now.difference(lastShownAt);
    if (elapsed < Duration.zero) return registeredCooldown;
    if (elapsed >= registeredCooldown) return Duration.zero;
    return registeredCooldown - elapsed;
  }

  bool isRecentInterstitial({
    required DateTime? lastShownAt,
    required DateTime now,
    required Duration cooldown,
  }) {
    if (lastShownAt == null) return false;
    final elapsed = now.difference(lastShownAt);
    if (elapsed < Duration.zero) return true;
    return elapsed < cooldown;
  }
}
