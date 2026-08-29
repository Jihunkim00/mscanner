import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/screens/vision_service.dart';

void main() {
  test('resolves scan mode from actual source image count', () {
    expect(VisionService.resolveScanModeForSourceImageCount(1), 'single');
    expect(VisionService.resolveScanModeForSourceImageCount(2), 'multi');
    expect(VisionService.resolveScanModeForSourceImageCount(3), 'multi');
    expect(VisionService.resolveScanModeForSourceImageCount(4), 'multi');
  });

  test('builds ordered separate-image V2 payload for four sources', () {
    final request = VisionV2RequestContract.multi(
      imagesBase64: const ['image-1', 'image-2', 'image-3', 'image-4'],
      prompt: 'prompt',
      maxOutputTokens: 9000,
      scanMode: 'multi',
      responseMode: 'stream',
      requestId: 'v-test-multi',
    );

    expect(request['imageBase64'], isNull);
    expect(request['storagePaths'], isNull);
    expect(request['imagesBase64'],
        equals(['image-1', 'image-2', 'image-3', 'image-4']));
    expect(request['sourceImageCount'], 4);
    expect(request['scanMode'], 'multi');
    expect(request['responseMode'], 'stream');
    expect(request['requestId'], 'v-test-multi');
  });

  test('builds direct Base64 payload for two sources', () {
    final request = VisionV2RequestContract.multi(
      imagesBase64: const ['image-1', 'image-2'],
      prompt: 'prompt',
      maxOutputTokens: 9000,
      scanMode: 'multi',
      responseMode: 'normal',
    );

    expect(request['imagesBase64'], equals(['image-1', 'image-2']));
    expect(request['sourceImageCount'], 2);
    expect(request['storagePaths'], isNull);
    expect(request['scanMode'], 'multi');
  });

  test('keeps the existing single-image V2 contract', () {
    final request = VisionV2RequestContract.single(
      imageBase64: 'single-image',
      prompt: 'prompt',
      maxOutputTokens: 3000,
      scanMode: 'single',
      responseMode: 'normal',
      sourceImageCount: 1,
      requestId: 'v-test-single',
      requestFullMenu: true,
    );

    expect(request['imageBase64'], 'single-image');
    expect(request['imagesBase64'], isNull);
    expect(request['sourceImageCount'], 1);
    expect(request['scanMode'], 'single');
    expect(request['requestFullMenu'], isTrue);
    expect(request['requestId'], 'v-test-single');
  });

  test('rejects unsafe request ids without sending them', () {
    final request = VisionV2RequestContract.single(
      imageBase64: 'single-image',
      prompt: 'prompt',
      maxOutputTokens: 3000,
      scanMode: 'single',
      responseMode: 'normal',
      sourceImageCount: 1,
      requestId: 'bad request id',
    );

    expect(request['requestId'], isNull);
  });

  test('creates safe request ids for end-to-end tracing', () {
    final requestId = VisionRequestTrace.createRequestId();

    expect(requestId, matches(RegExp(r'^v-[A-Za-z0-9._:-]+$')));
    expect(VisionRequestTrace.normalizeRequestId(requestId), requestId);
  });

  test('rejects more than the actual four-image app limit', () {
    expect(
      () => VisionV2RequestContract.multi(
        imagesBase64: const ['1', '2', '3', '4', '5'],
        prompt: 'prompt',
        maxOutputTokens: 9000,
        scanMode: 'multi',
        responseMode: 'stream',
      ),
      throwsArgumentError,
    );
  });
}
