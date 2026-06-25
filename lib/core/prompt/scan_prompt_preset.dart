enum ScanPromptPreset {
  defaultFoodScan,
  conciseTranslation,
  premiumDetailed,
  multiImageMerge;

  String get id => name;

  bool get isPremium =>
      this == ScanPromptPreset.premiumDetailed ||
      this == ScanPromptPreset.multiImageMerge;

  static ScanPromptPreset fromId(
    String? value, {
    ScanPromptPreset fallback = ScanPromptPreset.defaultFoodScan,
  }) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return fallback;
    return ScanPromptPreset.values.firstWhere(
      (preset) => preset.id == normalized,
      orElse: () => fallback,
    );
  }
}
