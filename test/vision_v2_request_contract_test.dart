import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/screens/vision_service.dart';

void main() {
  test('builds ordered separate-image V2 payload for four sources', () {
    final request = VisionV2RequestContract.multi(
      imagesBase64: const ['image-1', 'image-2', 'image-3', 'image-4'],
      prompt: 'prompt',
      maxOutputTokens: 9000,
      scanMode: 'multi',
      responseMode: 'stream',
    );

    expect(request['imageBase64'], isNull);
    expect(request['imagesBase64'],
        equals(['image-1', 'image-2', 'image-3', 'image-4']));
    expect(request['sourceImageCount'], 4);
    expect(request['scanMode'], 'multi');
    expect(request['responseMode'], 'stream');
  });

  test('keeps the existing single-image V2 contract', () {
    final request = VisionV2RequestContract.single(
      imageBase64: 'single-image',
      prompt: 'prompt',
      maxOutputTokens: 3000,
      scanMode: 'single',
      responseMode: 'normal',
      sourceImageCount: 1,
    );

    expect(request['imageBase64'], 'single-image');
    expect(request['imagesBase64'], isNull);
    expect(request['sourceImageCount'], 1);
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
