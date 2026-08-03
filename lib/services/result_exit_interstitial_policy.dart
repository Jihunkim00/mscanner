class ResultExitInterstitialDecision {
  const ResultExitInterstitialDecision({
    required this.shouldShow,
    required this.reason,
    required this.shouldCountExit,
    this.cooldownRemaining = Duration.zero,
  });

  final bool shouldShow;
  final String reason;
  final bool shouldCountExit;
  final Duration cooldownRemaining;
}

class ResultExitInterstitialPolicy {
  static const int resultExitInterval = 4;
  static const Duration resultExitCooldown = Duration(minutes: 3);

  static const String exitCountPrefsKey = 'result_exit_interstitial_count';
  static const String lastShownAtPrefsKey =
      'result_exit_interstitial_last_shown_at';

  const ResultExitInterstitialPolicy();

  bool shouldShow({
    required int exitCount,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool isAdRemoved,
    required bool isSubscribed,
    required bool isTutorial,
    required bool isFromHistory,
    required bool adReady,
    bool alreadyShowing = false,
  }) {
    return evaluate(
      exitCount: exitCount,
      lastShownAt: lastShownAt,
      now: now,
      isAdRemoved: isAdRemoved,
      isSubscribed: isSubscribed,
      isTutorial: isTutorial,
      isFromHistory: isFromHistory,
      adReady: adReady,
      alreadyShowing: alreadyShowing,
    ).shouldShow;
  }

  ResultExitInterstitialDecision evaluate({
    required int exitCount,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool isAdRemoved,
    required bool isSubscribed,
    required bool isTutorial,
    required bool isFromHistory,
    required bool adReady,
    bool alreadyShowing = false,
  }) {
    if (isTutorial) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'tutorial',
        shouldCountExit: false,
      );
    }

    if (isFromHistory) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'history',
        shouldCountExit: false,
      );
    }

    if (isSubscribed) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'premium',
        shouldCountExit: false,
      );
    }

    if (isAdRemoved) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'ad_removed',
        shouldCountExit: false,
      );
    }

    if (exitCount < resultExitInterval) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'frequency_not_met',
        shouldCountExit: true,
      );
    }

    final remaining = cooldownRemaining(lastShownAt: lastShownAt, now: now);
    if (remaining > Duration.zero) {
      return ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'cooldown',
        shouldCountExit: true,
        cooldownRemaining: remaining,
      );
    }

    if (alreadyShowing) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'already_showing',
        shouldCountExit: true,
      );
    }

    if (!adReady) {
      return const ResultExitInterstitialDecision(
        shouldShow: false,
        reason: 'ad_not_ready',
        shouldCountExit: true,
      );
    }

    return const ResultExitInterstitialDecision(
      shouldShow: true,
      reason: 'eligible',
      shouldCountExit: true,
    );
  }

  Duration cooldownRemaining({
    required DateTime? lastShownAt,
    required DateTime now,
  }) {
    if (lastShownAt == null) return Duration.zero;
    final elapsed = now.difference(lastShownAt);
    if (elapsed >= resultExitCooldown) return Duration.zero;
    return resultExitCooldown - elapsed;
  }
}
