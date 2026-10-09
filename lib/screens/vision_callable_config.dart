class VisionCallableConfig {
  static const bool useVisionV3 = bool.fromEnvironment(
    'MSCANNER_VISION_V3',
    defaultValue: true,
  );

  static const String callableName =
      useVisionV3 ? 'analyzeVisionV3' : 'analyzeVisionV2';
  static const String expectedModelName =
      useVisionV3 ? 'gpt-6-luna' : 'gpt-5.6-luna';

  static String callableNameFor(bool useV3) =>
      useV3 ? 'analyzeVisionV3' : 'analyzeVisionV2';
}
