import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final liveEnabled =
      Platform.environment['LIVE_VISION_TEST']?.toLowerCase() == 'true';

  test(
    'live Vision response satisfies the prompt regression contract',
    () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          'tool/prompt_regression_runner.dart',
          '--preset=premiumDetailed',
          '--lang=ko',
          '--food-style=muslimFriendly',
          '--live',
        ],
        workingDirectory: Directory.current.path,
        environment: Platform.environment,
      );

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout.toString(), contains('jsonParseStatus=ok'));
      expect(result.stdout.toString(), contains('selectedFoodStyle='));
      expect(result.stdout.toString(), contains('matchedItemCount='));
      expect(result.stdout.toString(), contains('contractValidation=ok'));
    },
    skip: liveEnabled
        ? false
        : 'Set LIVE_VISION_TEST=true to call the configured live endpoint.',
  );
}
