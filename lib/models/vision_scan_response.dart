class FoodStyleSummary {
  const FoodStyleSummary({
    required this.styleId,
    required this.matchedItemCount,
    required this.cautionItemCount,
    required this.notRecommendedItemCount,
    required this.topRecommendedItemIndexes,
    required this.confidence,
    required this.reason,
    required this.disclaimer,
  });

  final String styleId;
  final int matchedItemCount;
  final int cautionItemCount;
  final int notRecommendedItemCount;
  final List<int> topRecommendedItemIndexes;
  final double confidence;
  final String reason;
  final String disclaimer;

  factory FoodStyleSummary.fromJson(Map<String, dynamic>? json) {
    final source = json ?? const <String, dynamic>{};
    return FoodStyleSummary(
      styleId: _string(source['styleId']),
      matchedItemCount: _integer(source['matchedItemCount']),
      cautionItemCount: _integer(source['cautionItemCount']),
      notRecommendedItemCount: _integer(source['notRecommendedItemCount']),
      topRecommendedItemIndexes: _intList(source['topRecommendedItemIndexes']),
      confidence: _decimal(source['confidence']),
      reason: _string(source['reason']),
      disclaimer: _string(source['disclaimer']),
    );
  }

  Map<String, dynamic> toJson() => {
        'styleId': styleId,
        'matchedItemCount': matchedItemCount,
        'cautionItemCount': cautionItemCount,
        'notRecommendedItemCount': notRecommendedItemCount,
        'topRecommendedItemIndexes': topRecommendedItemIndexes,
        'confidence': confidence,
        'reason': reason,
        'disclaimer': disclaimer,
      };
}

class ImageLevelDetection {
  const ImageLevelDetection({
    required this.imageIndex,
    required this.detectedMenuType,
    this.detectedCuisineType,
    required this.confidence,
  });

  final int imageIndex;
  final String detectedMenuType;
  final String? detectedCuisineType;
  final double confidence;

  factory ImageLevelDetection.fromJson(Map<String, dynamic> json) {
    return ImageLevelDetection(
      imageIndex: _integer(json['imageIndex']),
      detectedMenuType: _string(json['detectedMenuType'], fallback: 'unknown'),
      detectedCuisineType: _nullableString(json['detectedCuisineType']),
      confidence: _decimal(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() => {
        'imageIndex': imageIndex,
        'detectedMenuType': detectedMenuType,
        'detectedCuisineType': detectedCuisineType,
        'confidence': confidence,
      };
}

class VisionMenuItem {
  const VisionMenuItem({
    required this.originalName,
    required this.translatedName,
    required this.description,
    this.price,
    this.currencyCode,
    this.convertedPrice,
    required this.foodStyleFit,
    this.styleMatched,
    required this.styleFitScore,
    this.recommendationRank,
    this.recommendationReason,
    required this.matchedEvidence,
    this.cautionReason,
    required this.dietaryWarnings,
    required this.allergyHints,
    required this.requiresStaffCheck,
    required this.confidence,
    required this.sourceImageIndexes,
    required this.raw,
  });

  final String originalName;
  final String translatedName;
  final String description;
  final dynamic price;
  final String? currencyCode;
  final dynamic convertedPrice;
  final String foodStyleFit;
  final bool? styleMatched;
  final double styleFitScore;
  final int? recommendationRank;
  final String? recommendationReason;
  final List<String> matchedEvidence;
  final String? cautionReason;
  final List<String> dietaryWarnings;
  final List<String> allergyHints;
  final bool requiresStaffCheck;
  final double confidence;
  final List<int> sourceImageIndexes;
  final Map<String, dynamic> raw;

  factory VisionMenuItem.fromJson(Map<String, dynamic> json) {
    final prices = _map(json['prices']);
    return VisionMenuItem(
      originalName: _string(json['originalName'] ?? json['nameOriginal']),
      translatedName: _string(json['translatedName'] ?? json['name']),
      description: _string(json['description'] ?? json['shortDesc']),
      price: json.containsKey('price') ? json['price'] : prices?['single'],
      currencyCode:
          _nullableString(json['currencyCode'] ?? prices?['currency']),
      convertedPrice: json['convertedPrice'],
      foodStyleFit: _string(json['foodStyleFit'], fallback: 'unknown'),
      styleMatched:
          json['styleMatched'] is bool ? json['styleMatched'] as bool : null,
      styleFitScore: _decimal(json['styleFitScore']),
      recommendationRank: _nullableInteger(json['recommendationRank']),
      recommendationReason: _nullableString(json['recommendationReason']),
      matchedEvidence: _stringList(json['matchedEvidence']),
      cautionReason: _nullableString(json['cautionReason']),
      dietaryWarnings: _stringList(json['dietaryWarnings']),
      allergyHints: _stringList(json['allergyHints']),
      requiresStaffCheck: json['requiresStaffCheck'] == true,
      confidence: _decimal(json['confidence']),
      sourceImageIndexes: _intList(json['sourceImageIndexes']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
        ...raw,
        'originalName': originalName,
        'translatedName': translatedName,
        'description': description,
        'price': price,
        'currencyCode': currencyCode,
        'convertedPrice': convertedPrice,
        'foodStyleFit': foodStyleFit,
        'styleMatched': styleMatched,
        'styleFitScore': styleFitScore,
        'recommendationRank': recommendationRank,
        'recommendationReason': recommendationReason,
        'matchedEvidence': matchedEvidence,
        'cautionReason': cautionReason,
        'dietaryWarnings': dietaryWarnings,
        'allergyHints': allergyHints,
        'requiresStaffCheck': requiresStaffCheck,
        'confidence': confidence,
        'sourceImageIndexes': sourceImageIndexes,
      };
}

class VisionScanResponse {
  const VisionScanResponse({
    required this.presetVersion,
    required this.scanPreset,
    required this.detailLevel,
    required this.targetLanguage,
    required this.isMultiScan,
    required this.selectedFoodStyle,
    required this.selectedFoodStyleLabel,
    required this.foodStyleApplied,
    required this.foodStyleSummary,
    required this.imageLevelDetections,
    required this.items,
    required this.warnings,
    required this.raw,
  });

  final String presetVersion;
  final String scanPreset;
  final String detailLevel;
  final String targetLanguage;
  final bool isMultiScan;
  final String selectedFoodStyle;
  final String selectedFoodStyleLabel;
  final bool foodStyleApplied;
  final FoodStyleSummary foodStyleSummary;
  final List<ImageLevelDetection> imageLevelDetections;
  final List<VisionMenuItem> items;
  final List<String> warnings;
  final Map<String, dynamic> raw;

  factory VisionScanResponse.fromJson(Map<String, dynamic> json) {
    final itemMaps = _collectItemMaps(json);
    return VisionScanResponse(
      presetVersion: _string(json['presetVersion']),
      scanPreset: _string(json['scanPreset']),
      detailLevel: _string(json['detailLevel']),
      targetLanguage: _string(json['targetLanguage'] ?? json['outputLanguage']),
      isMultiScan: json['isMultiScan'] == true,
      selectedFoodStyle: _string(json['selectedFoodStyle']),
      selectedFoodStyleLabel: _string(json['selectedFoodStyleLabel']),
      foodStyleApplied: json['foodStyleApplied'] == true,
      foodStyleSummary:
          FoodStyleSummary.fromJson(_map(json['foodStyleSummary'])),
      imageLevelDetections: _mapList(json['imageLevelDetections'])
          .map(ImageLevelDetection.fromJson)
          .toList(growable: false),
      items: itemMaps.map(VisionMenuItem.fromJson).toList(growable: false),
      warnings: _stringList(json['warnings']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
        ...raw,
        'presetVersion': presetVersion,
        'scanPreset': scanPreset,
        'detailLevel': detailLevel,
        'targetLanguage': targetLanguage,
        'isMultiScan': isMultiScan,
        'selectedFoodStyle': selectedFoodStyle,
        'selectedFoodStyleLabel': selectedFoodStyleLabel,
        'foodStyleApplied': foodStyleApplied,
        'foodStyleSummary': foodStyleSummary.toJson(),
        'imageLevelDetections':
            imageLevelDetections.map((item) => item.toJson()).toList(),
        'items': items.map((item) => item.toJson()).toList(),
        'warnings': warnings,
      };
}

List<Map<String, dynamic>> _collectItemMaps(Map<String, dynamic> json) {
  final direct = _mapList(json['items']);
  if (direct.isNotEmpty) return direct;

  final result = <Map<String, dynamic>>[];
  result.addAll(_mapList(json['recommended']));

  final fullMenu = _map(json['fullMenu'] ?? json['full_menu']);
  final categories = _map(fullMenu?['items']) ?? fullMenu;
  if (categories != null) {
    for (final value in categories.values) {
      result.addAll(_mapList(value));
    }
  }
  return result;
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _string(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _nullableString(dynamic value) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? null : result;
}

int _integer(dynamic value) => _nullableInteger(value) ?? 0;

int? _nullableInteger(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _decimal(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _intList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_nullableInteger).whereType<int>().toList(growable: false);
}
