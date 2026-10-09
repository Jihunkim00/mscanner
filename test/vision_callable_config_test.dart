import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/screens/vision_callable_config.dart';

void main() {
  const v3Enabled = bool.fromEnvironment(
    'MSCANNER_VISION_V3',
    defaultValue: true,
  );

  test('maps the default build to analyzeVisionV2', () {
    expect(VisionCallableConfig.callableNameFor(false), 'analyzeVisionV2');
  });

  test('maps the V3 opt-in build to analyzeVisionV3', () {
    expect(VisionCallableConfig.callableNameFor(true), 'analyzeVisionV3');
  });

  test('selected callable follows the build-time define', () {
    expect(
      VisionCallableConfig.callableName,
      v3Enabled ? 'analyzeVisionV3' : 'analyzeVisionV2',
    );
    expect(
      VisionCallableConfig.expectedModelName,
      v3Enabled ? 'gpt-6-luna' : 'gpt-5.6-luna',
    );
  });
}
