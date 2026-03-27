String buildPresetDescription({
  required String outputLang,
  required String styleHint,
  required String menuCountHint,
}) {
  const String intro =
      'Follow the output protocol exactly. Return exactly one RECOMMEND line followed by one JSON object. Do not add extra text.\n';

  final base = '''
You MUST output in TWO phases, in this exact order:
PHASE 1) Output exactly ONE line (no extra lines):
RECOMMEND: <dish1> | <dish2> | <dish3>
- Use translated names in outputLanguage = "$outputLang" (if uncertain, use original).
- No extra text.

PHASE 2) Then output ONLY valid JSON (no extra text, markdown, code fences, or explanations).

Goal:
- Extract menu items from the provided image/OCR text.
- Produce results for the app UI: "Recommended Dishes" chips + optional "Full Menu" preview.

Hard rules:
1) Output language rule:
   - shortDesc, tags MUST be written in outputLanguage = "$outputLang".
   - nameOriginal MUST be the EXACT original text extracted from the image/OCR (do NOT translate).
   - name MUST be the translated name in outputLanguage. If translation is identical or uncertain, set name = nameOriginal.
2) Never invent items not visible in the image/OCR.
3) If the image is NOT a food menu, return isMenu=false with a short reason.
4) Keep shortDesc to 1–2 sentences max.
5) Use styleHint="$styleHint" only as ranking preference (do NOT hallucinate dietary tags).
6) menuCountHint="$menuCountHint" controls ONLY the "recommended" list size:
   - "1": 1 item
   - "1-3": up to 3 items
   - "1-5": up to 5 items
   - "all": up to 6 items

7) TOKEN SAFETY (VERY IMPORTANT):
   - Keep the entire JSON compact.
   - If the menu is long, DO NOT output every item as structured arrays.
   - Prefer: recommended (structured, detailed) + fullMenu summary (structured text).
   - You must stay within the output limit; if needed, set fullMenu.truncated=true and summarize the rest.

8) Tags limit:
   - "tags" MUST contain at most 4 strings per item. (0–4)

9) ID format:
   - "id" MUST be short and unique within this response.
   - Use simple IDs like "m1", "m2", "m3"... (no long UUIDs)

10) Detail quality (IMPORTANT):
   - For EACH recommended item, shortDesc MUST mention:
     (a) ingredients OR cooking method AND (b) flavor profile (e.g., spicy/savory) in 1–2 sentences.
   - Avoid generic phrases like "delicious". Be concrete.

11) FullMenu preview detail rule:
   - In fullMenu.items, for each category include at most 2 items with non-empty shortDesc.
   - All other items must set shortDesc="" to save tokens.

12) FullMenu summary formatting rule (VERY IMPORTANT):
   - fullMenu.summary MUST use this structure in outputLanguage:
     "Main highlights: <A> — <note>; <B> — <note>. Other mains: <list up to 8>.
      Sides highlights: <A> — <note>; <B> — <note>. Other sides: <list up to 8>.
      Drinks highlights: <A> — <note>. Other drinks: <list up to 8>."
   - Each <note> must be 6–14 words describing ingredients/method/flavor (concrete).
   - Do NOT output a plain list only.

Return JSON with EXACT schema:

{
  "isMenu": true,
  "outputLanguage": "$outputLang",
  "place": { "name": null, "address": null, "city": null },

  "recommended": [
    {
      "id": "string",
      "nameOriginal": "string",
      "name": "string",
      "shortDesc": "string",
      "prices": { "small": null, "medium": null, "large": null, "single": null, "currency": "ISO 4217 code like KRW, JPY, USD, EUR, etc. or null" },
      "tags": ["string"],
      "category": "main|side|meal|drink|beverage|unknown",
      "confidence": 0.0
    }
  ],

  "fullMenu": {
    "items": {
      "main": [],
      "side": [],
      "meal": [],
      "drink": [],
      "beverage": [],
      "unknown": []
    },
    "summary": "string",
    "truncated": true
  }
}

Full menu output rule:
- Always fill "recommended" as structured items (most detailed).
- For fullMenu.items:
  - If the menu is short, you MAY include more items.
  - If the menu is long, include ONLY a small preview per category (max 12 items total across all categories).
- Put the rest into fullMenu.summary using the required formatting rule.
- If you omit any items due to length, set fullMenu.truncated=true; otherwise false.

If isMenu=false, return EXACTLY:
{
  "isMenu": false,
  "outputLanguage": "$outputLang",
  "reason": "short string"
}
''';


  return intro + base;
}
