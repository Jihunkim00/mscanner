import 'package:mscanner/models/scan_mode.dart';

String buildVisionPrompt({
  required ScanMode scanMode,
  required String targetLanguage,
  required String promptContext,
  required String question,
  int photoCount = 1,
}) {
  switch (scanMode) {
    case ScanMode.single:
      return buildSingleScanPrompt(
        targetLanguage: targetLanguage,
        promptContext: promptContext,
        question: question,
      );
    case ScanMode.multi:
      return buildMultiScanPrompt(
        targetLanguage: targetLanguage,
        promptContext: promptContext,
        question: question,
        photoCount: photoCount,
      );
  }
}

String _baseOutputProtocol({required String keyOrder}) => '''[OUTPUT PROTOCOL]
Output exactly ONE JSON object.
- No RECOMMEND line
- No markdown
- No code fences
- No extra text
- Return valid JSON only.
- Keep the JSON key order as: $keyOrder
''';

String _localizedIntro({
  required String targetLanguage,
  required String promptContext,
  required String question,
}) => '''[Location Memo]
$promptContext

If this image is a food menu or food photo, translate it into targetLanguage="$targetLanguage", describe useful details, and recommend dishes.
If it does not seem food-related, return isMenu=false in valid JSON.

[Existing user preset / app schema instructions]
$question
''';

String _sharedMenuRequirements(String targetLanguage) => '''
[Shared menu extraction requirements]
- Preserve the existing app JSON fields whenever possible: isMenu, userMessage, outputLanguage, place, recommended, fullMenu.
- outputLanguage must be "$targetLanguage".
- Extract only visible menu items. Do not invent unseen dishes.
- Include original menu names, translated names, prices, concise descriptions, recommendation reasons, signature/popular hints, spicy level, allergy/caution information, and local insights when supported by visible text or provided context.
- Mark low-confidence or partially unreadable text clearly instead of guessing.
- Return valid JSON only.
''';

String buildSingleScanPrompt({
  required String targetLanguage,
  required String promptContext,
  required String question,
}) {
  return '''${_baseOutputProtocol(keyOrder: 'isMenu, scanMode, outputLanguage, place, recommended, fullMenu')}
${_localizedIntro(targetLanguage: targetLanguage, promptContext: promptContext, question: question)}
${_sharedMenuRequirements(targetLanguage)}
[Single scan mode]
- scanMode must be "single".
- Analyze this as one menu photo.
- Keep the existing single-scan result format compatible with the current UI.
- The result should focus on menu item extraction, translation, prices, descriptions, recommended dishes, signature/popular items, spicy level, allergy/caution notes, and local insights when available.
- Do not add multi-scan-only fields unless they are empty/omitted.
''';
}

String buildMultiScanPrompt({
  required String targetLanguage,
  required String promptContext,
  required String question,
  required int photoCount,
}) {
  return '''${_baseOutputProtocol(keyOrder: 'isMenu, scanMode, outputLanguage, place, recommended, fullMenu, photoAnalyses, mergedResult')}
${_localizedIntro(targetLanguage: targetLanguage, promptContext: promptContext, question: question)}
${_sharedMenuRequirements(targetLanguage)}
[Multi scan mode]
You are analyzing multiple food menu photos.
Treat each photo as a separate source.
Analyze each photo independently first.
For each photo, return photoIndex, detectedSections, itemCount, readableItemCount, unclearItemCount, and items.
After all photos are analyzed, merge the results.
Remove duplicates only in the mergedResult.
Do not mix prices, descriptions, or sections between different photos.
If an item is unclear, mark it as unclear instead of guessing.
Return valid JSON only.

Required analysis order:
1. Treat each photo as a separate source. If the image is a labeled collage, use labels like [PHOTO 1], [PHOTO 2], etc. to assign photoIndex.
2. Extract menu items for each photo independently.
3. Count itemCount for each photo.
4. Count readableItemCount and unclearItemCount for each photo.
5. Summarize detectedSections for each photo.
6. Only after all photoAnalyses are complete, merge the whole result.
7. Remove duplicates only in mergedResult.
8. Do not mix prices, descriptions, or sections between different photos.
9. If an item is unclear, mark it as unclear instead of guessing.
10. Build final recommended/signature/popular/local insights from mergedResult only.

Multi-scan JSON requirements:
- scanMode must be "multi".
- totalPhotoCount should be $photoCount.
- Keep existing fields recommended and fullMenu populated from the merged result so legacy UI still works.
- Compact output rules for stability:
  - recommended must contain at most 5 best items.
  - fullMenu must contain at most 40 unique, readable items across all sections.
  - Keep every item description/reason short (one concise phrase or sentence).
  - Keep photoAnalyses item descriptions short; do not write long explanations.
  - If many menu items are visible, prioritize readable, priced, and recommended/signature items.
  - Prefer compact strings and arrays; do not include markdown or commentary outside JSON.
- Add the following fields as additive fields:
{
  "scanMode": "multi",
  "photoAnalyses": [
    {
      "photoIndex": 1,
      "detectedSections": [],
      "itemCount": 0,
      "readableItemCount": 0,
      "unclearItemCount": 0,
      "items": [
        {
          "originalName": "",
          "translatedName": "",
          "description": "",
          "price": "",
          "spicyLevel": "",
          "confidence": 0.0,
          "isUnclear": false
        }
      ]
    }
  ],
  "mergedResult": {
    "totalPhotoCount": $photoCount,
    "totalItemCount": 0,
    "uniqueItemCount": 0,
    "duplicateItemCount": 0,
    "recommendedItems": [],
    "signatureItems": [],
    "popularItems": [],
    "localInsights": []
  }
}
- If one photo fails or has no readable items, still include a photoAnalyses entry with itemCount=0, readableItemCount=0, unclearItemCount=0 or the number of unclear items, items=[], and a short failure/caution string if needed.
''';
}
