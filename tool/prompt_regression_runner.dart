import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:mscanner/core/prompt/food_style_prompt_rules.dart';
import 'package:mscanner/core/prompt/scan_prompt_builder.dart';
import 'package:mscanner/core/prompt/scan_prompt_preset.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';

Future<void> main(List<String> arguments) async {
  final options = _RunnerOptions.parse(arguments);
  final fixtureFiles = _findFixtures();
  final prompt = ScanPromptBuilder(
    scanPreset: options.preset,
    targetLanguage: options.language,
    isMultiScan: options.multi,
    includeCurrency: true,
    includeRagContext: false,
    selectedFoodStyle: options.foodStyle,
    isPremiumUser: options.preset.isPremium,
    scanMode: options.multi ? 'multi' : 'single',
    sourceImageCount: options.multi ? fixtureFiles.length : 1,
  ).build();

  stdout.writeln('preset=${options.preset.id}');
  stdout.writeln('language=${options.language}');
  stdout.writeln('foodStyle=${options.foodStyle.id}');
  stdout.writeln('multi=${options.multi}');
  stdout.writeln('fixtures:');
  for (final file in fixtureFiles) {
    stdout.writeln('- ${file.path}');
  }

  if (!options.live) {
    stdout.writeln('\n--- prompt dry-run ---\n$prompt');
    return;
  }

  if (fixtureFiles.isEmpty) {
    stderr.writeln(
      'No fixture images found. Add images under '
      'test/prompt_regression/fixtures/.',
    );
    exitCode = 2;
    return;
  }

  final endpoint = _resolveEndpoint();
  if (endpoint == null) {
    stderr.writeln(
      'Set LIVE_VISION_ENDPOINT or FIREBASE_PROJECT_ID before --live.',
    );
    exitCode = 2;
    return;
  }

  final imageBytes = options.multi
      ? _mergeImages(fixtureFiles)
      : await fixtureFiles.first.readAsBytes();
  final responseText = await _callVision(
    endpoint: endpoint,
    authToken: Platform.environment['LIVE_VISION_AUTH_TOKEN'],
    imageBytes: imageBytes,
    prompt: prompt,
    multi: options.multi,
  );

  final parsed = ResultParsingService.parseAiJson(
    responses: [responseText],
    imageCount: options.multi ? fixtureFiles.length : 1,
  );
  _printSummary(parsed.aiJson, parsed.aiJsonError);
  final contractErrors = _validateLiveContract(
    parsed.aiJson,
    responseText,
    options.foodStyle,
  );
  if (contractErrors.isEmpty) {
    stdout.writeln('contractValidation=ok');
  } else {
    stdout.writeln('contractValidation=failed');
    for (final error in contractErrors) {
      stdout.writeln('contractError=$error');
    }
    exitCode = 3;
  }

  if (options.saveOutput) {
    final outputDirectory = Directory('test/prompt_regression/outputs');
    await outputDirectory.create(recursive: true);
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final outputFile = File(
      '${outputDirectory.path}/'
      '${options.preset.id}_${options.foodStyle.id}_$timestamp.json',
    );
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        parsed.aiJson ?? {'rawResponse': responseText},
      ),
    );
    stdout.writeln('saved=${outputFile.path}');
  }
}

Uri? _resolveEndpoint() {
  final explicit = Platform.environment['LIVE_VISION_ENDPOINT']?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return Uri.tryParse(explicit);
  }

  final projectId = Platform.environment['FIREBASE_PROJECT_ID']?.trim();
  if (projectId == null || projectId.isEmpty) return null;
  return Uri.parse(
    'https://asia-northeast3-$projectId.cloudfunctions.net/analyzeVision',
  );
}

List<File> _findFixtures() {
  final fixtureDirectory = Directory('test/prompt_regression/fixtures');
  final fixtures = fixtureDirectory.existsSync()
      ? fixtureDirectory.listSync().whereType<File>().where((file) {
          final lower = file.path.toLowerCase();
          return lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp');
        }).toList()
      : <File>[];
  fixtures.sort((a, b) => a.path.compareTo(b.path));

  if (fixtures.isEmpty) {
    final fallback = File('assets/images/tutorial_sample.jpg');
    if (fallback.existsSync()) {
      fixtures.add(fallback);
    }
  }
  return fixtures;
}

Uint8List _mergeImages(List<File> files) {
  final decoded = files
      .map((file) => image.decodeImage(file.readAsBytesSync()))
      .whereType<image.Image>()
      .toList();
  if (decoded.isEmpty) {
    throw const FormatException('Fixture images could not be decoded.');
  }
  if (decoded.length == 1) {
    return Uint8List.fromList(image.encodeJpg(decoded[0]));
  }

  const cellWidth = 1000;
  const cellHeight = 1200;
  final columns = decoded.length == 2 ? 1 : 2;
  final rows = decoded.length == 2 ? 2 : (decoded.length + 1) ~/ 2;
  final canvas = image.Image(
    width: cellWidth * columns,
    height: cellHeight * rows,
  );

  for (var index = 0; index < decoded.length; index++) {
    final fitted = _fitAndCrop(decoded[index], cellWidth, cellHeight);
    final x = (index % columns) * cellWidth;
    final y = (index ~/ columns) * cellHeight;
    image.compositeImage(canvas, fitted, dstX: x, dstY: y);
  }
  return Uint8List.fromList(image.encodeJpg(canvas, quality: 85));
}

image.Image _fitAndCrop(
  image.Image source,
  int targetWidth,
  int targetHeight,
) {
  final scale = math.max(
    targetWidth / source.width,
    targetHeight / source.height,
  );
  final resized = image.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: image.Interpolation.average,
  );
  return image.copyCrop(
    resized,
    x: (resized.width - targetWidth) ~/ 2,
    y: (resized.height - targetHeight) ~/ 2,
    width: targetWidth,
    height: targetHeight,
  );
}

Future<String> _callVision({
  required Uri endpoint,
  required String? authToken,
  required Uint8List imageBytes,
  required String prompt,
  required bool multi,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(endpoint);
    request.headers.contentType = ContentType.json;
    final token = authToken?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.write(
      jsonEncode({
        'data': {
          'imageBase64': base64Encode(imageBytes),
          'prompt': prompt,
          'maxOutputTokens': multi ? 9000 : 3000,
          'scanMode': multi ? 'multi' : 'single',
          'responseMode': 'normal',
        },
      }),
    );

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Vision endpoint returned ${response.statusCode}: $responseBody',
        uri: endpoint,
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const FormatException('Callable response is not a JSON object.');
    }
    final callableResult = decoded['result'];
    if (callableResult is Map) {
      final resultText = callableResult['result']?.toString();
      if (resultText != null && resultText.trim().isNotEmpty) {
        return resultText;
      }
    }
    if (callableResult is String && callableResult.trim().isNotEmpty) {
      return callableResult;
    }
    throw const FormatException('Callable response contains no result text.');
  } finally {
    client.close(force: true);
  }
}

void _printSummary(Map<String, dynamic>? json, String? parseError) {
  final items = json?['items'] is List ? json!['items'] as List : const [];
  final summary = json?['foodStyleSummary'] is Map
      ? Map<String, dynamic>.from(json!['foodStyleSummary'] as Map)
      : const <String, dynamic>{};
  final missingTranslation = items.where((item) {
    return item is Map &&
        (item['translatedName'] ?? item['name'] ?? '')
            .toString()
            .trim()
            .isEmpty;
  }).length;
  final suspiciousPrices = items.where((item) {
    return item is Map &&
        item['price'] != null &&
        (item['originalName'] ?? item['nameOriginal'] ?? '')
            .toString()
            .trim()
            .isEmpty;
  }).length;
  final missingDietaryCaution = items.where((item) {
    if (item is! Map) return false;
    final warnings = item['dietaryWarnings'];
    final caution = (item['cautionReason'] ?? '').toString().trim();
    return warnings is List && warnings.isNotEmpty && caution.isEmpty;
  }).length;

  stdout.writeln('jsonParseStatus=${json != null ? 'ok' : 'failed'}');
  if (parseError != null) stdout.writeln('jsonParseError=$parseError');
  stdout.writeln('itemCount=${items.length}');
  stdout.writeln('selectedFoodStyle=${json?['selectedFoodStyle'] ?? ''}');
  stdout.writeln('matchedItemCount=${summary['matchedItemCount'] ?? 0}');
  stdout.writeln('cautionItemCount=${summary['cautionItemCount'] ?? 0}');
  stdout.writeln(
    'notRecommendedItemCount=${summary['notRecommendedItemCount'] ?? 0}',
  );
  stdout.writeln(
    'topRecommendedItemIndexes=${summary['topRecommendedItemIndexes'] ?? const []}',
  );
  stdout.writeln('missingTranslatedNameWarning=$missingTranslation');
  stdout.writeln('priceHallucinationWarning=$suspiciousPrices');
  stdout.writeln('dietaryCautionWarning=$missingDietaryCaution');
}

List<String> _validateLiveContract(
  Map<String, dynamic>? json,
  String rawResponse,
  FoodStyle selectedFoodStyle,
) {
  if (json == null) return const ['response_is_not_parseable_json'];
  final errors = <String>[];
  if (json['selectedFoodStyle']?.toString() != selectedFoodStyle.id) {
    errors.add('selectedFoodStyle_missing_or_mismatched');
  }
  if (json['foodStyleSummary'] is! Map) {
    errors.add('foodStyleSummary_missing');
  }

  final items = json['items'];
  if (items is! List) {
    errors.add('items_missing');
  } else {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item is! Map) {
        errors.add('item_${index}_is_not_an_object');
        continue;
      }
      for (final key in const [
        'foodStyleFit',
        'styleMatched',
        'styleFitScore',
      ]) {
        if (!item.containsKey(key)) errors.add('item_${index}_missing_$key');
      }
    }
  }

  final lower = rawResponse.toLowerCase();
  if (selectedFoodStyle == FoodStyle.nutFree &&
      (lower.contains('guaranteed nut-free') ||
          lower.contains('guaranteed nut free') ||
          lower.contains('allergy-safe'))) {
    errors.add('nut_free_safety_guarantee_detected');
  }
  if (selectedFoodStyle == FoodStyle.muslimFriendly &&
      (lower.contains('guaranteed halal') ||
          lower.contains('definitely halal') ||
          lower.contains('safe for all muslim'))) {
    errors.add('halal_safety_guarantee_detected');
  }
  if ((selectedFoodStyle == FoodStyle.lowFat ||
          selectedFoodStyle == FoodStyle.lowSalt) &&
      (lower.contains('guaranteed low-fat') ||
          lower.contains('guaranteed low fat') ||
          lower.contains('guaranteed low-salt') ||
          lower.contains('guaranteed low salt'))) {
    errors.add('definitive_nutrition_claim_detected');
  }
  return errors;
}

class _RunnerOptions {
  const _RunnerOptions({
    required this.preset,
    required this.language,
    required this.foodStyle,
    required this.multi,
    required this.live,
    required this.saveOutput,
  });

  final ScanPromptPreset preset;
  final String language;
  final FoodStyle foodStyle;
  final bool multi;
  final bool live;
  final bool saveOutput;

  factory _RunnerOptions.parse(List<String> arguments) {
    String value(String name, String fallback) {
      final prefix = '--$name=';
      final match =
          arguments.where((arg) => arg.startsWith(prefix)).firstOrNull;
      return match?.substring(prefix.length) ?? fallback;
    }

    return _RunnerOptions(
      preset: ScanPromptPreset.fromId(value('preset', 'defaultFoodScan')),
      language: value('lang', 'en'),
      foodStyle: FoodStyle.fromStoredValue(
        value('food-style', FoodStyle.aiRecommend.id),
      ),
      multi: arguments.contains('--multi'),
      live: arguments.contains('--live'),
      saveOutput: arguments.contains('--save-output'),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
