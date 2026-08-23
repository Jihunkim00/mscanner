import assert from "node:assert/strict";
import {
  VisionInventoryItem,
  VisionMenuItem,
  VisionMultiAnalysis,
  VisionSourceAnalysis,
  normalizeVisionMultiResponse,
} from "./responseSchema";
import {aggregateVisionMultiResponse} from "./visionAggregation";

function recommendation(name: string, category = "main"): VisionMenuItem {
  return {
    id: "rec-" + name,
    nameOriginal: name,
    name,
    originLanguageCode: "en",
    shortDesc: "Recommended " + name,
    prices: {
      small: null,
      medium: null,
      large: null,
      single: null,
      currency: null,
    },
    tags: [],
    category,
    confidence: 0.9,
    sourceImageIndexes: [99],
  };
}

function inventory(name: string, category = "main"): VisionInventoryItem {
  return {
    id: "inv-" + name,
    nameOriginal: name,
    name,
    originLanguageCode: "en",
    shortDesc: name + " dish",
    price: null,
    category,
    confidence: 0.8,
  };
}

function source(
  sourceImageIndex: number,
  status: "menu" | "non_menu" | "unreadable" | "duplicate",
  recommended: VisionMenuItem[] = [],
  menuItems: VisionInventoryItem[] = [],
): VisionSourceAnalysis {
  return {
    sourceImageIndex,
    status,
    recommended,
    menuItems,
    truncated: false,
  };
}

function rawSource(
  sourceImageIndex: number,
  status: "menu" | "non_menu" | "unreadable" | "duplicate",
  recommended: VisionMenuItem[] = [],
  menuItems: VisionInventoryItem[] = [],
): Record<string, unknown> {
  return {
    sourceImageIndex,
    status,
    recommended,
    menuItems,
    truncated: false,
  };
}

function rawResponse(
  sources: Record<string, unknown>[],
  isMenu = true,
): Record<string, unknown> {
  return {
    isMenu,
    userMessage: "result",
    outputLanguage: "en",
    sources,
  };
}

function normalized(
  sources: VisionSourceAnalysis[],
  declaredIsMenu = true,
): VisionMultiAnalysis {
  return {
    isMenu: sources.some((item) => item.status === "menu"),
    declaredIsMenu,
    userMessage: "result",
    outputLanguage: "en",
    sources,
  };
}

const fourEmptyNonMenu = [
  rawSource(1, "non_menu"),
  rawSource(2, "unreadable"),
  rawSource(3, "duplicate"),
  rawSource(4, "non_menu"),
];
const nonMenuAnalysis = normalizeVisionMultiResponse(
  rawResponse(fourEmptyNonMenu, false),
  4,
);
assert.equal(nonMenuAnalysis.isMenu, false);
assert.equal(nonMenuAnalysis.sources.length, 4);

assert.throws(
  () => normalizeVisionMultiResponse(
    rawResponse([rawSource(1, "menu"), rawSource(2, "menu"), rawSource(4, "menu")]),
    4,
  ),
  /sources count/,
);
assert.throws(
  () => normalizeVisionMultiResponse(
    rawResponse([
      rawSource(1, "menu", [recommendation("a")], [inventory("a")]),
      rawSource(2, "menu", [recommendation("b")], [inventory("b")]),
      rawSource(2, "menu", [recommendation("c")], [inventory("c")]),
      rawSource(4, "menu", [recommendation("d")], [inventory("d")]),
    ]),
    4,
  ),
  /sourceImageIndex/,
);
assert.throws(
  () => normalizeVisionMultiResponse(
    rawResponse([
      rawSource(1, "menu", [recommendation("a")], [inventory("a")]),
      rawSource(2, "menu", [recommendation("b")], [inventory("b")]),
      rawSource(3, "menu", [recommendation("c")], [inventory("c")]),
      rawSource(5, "menu", [recommendation("d")], [inventory("d")]),
    ]),
    4,
  ),
  /sourceImageIndex/,
);
assert.throws(
  () => normalizeVisionMultiResponse(
    rawResponse([
      rawSource(1, "menu", [], [inventory("a")]),
      rawSource(2, "menu", [recommendation("b")], [inventory("b")]),
      rawSource(3, "menu", [recommendation("c")], [inventory("c")]),
      rawSource(4, "menu", [recommendation("d")], [inventory("d")]),
    ]),
    4,
  ),
  /menu source recommendation/,
);
assert.throws(
  () => normalizeVisionMultiResponse(
    rawResponse([
      rawSource(1, "menu", [recommendation("a")], []),
      rawSource(2, "menu", [recommendation("b")], [inventory("b")]),
      rawSource(3, "menu", [recommendation("c")], [inventory("c")]),
      rawSource(4, "menu", [recommendation("d")], [inventory("d")]),
    ]),
    4,
  ),
  /menu source inventory/,
);

const fourMenuSources = [1, 2, 3, 4].map((index) =>
  source(
    index,
    "menu",
    [recommendation("recommended-" + index)],
    [
      inventory("recommended-" + index),
      inventory("other-" + index),
    ],
  ),
);
const fourMenuAnalysis = normalizeVisionMultiResponse(
  rawResponse(fourMenuSources.map((item) => ({...item})), true),
  4,
);
const fourMenuResult = aggregateVisionMultiResponse(fourMenuAnalysis);
assert.equal(fourMenuResult.diagnostics.recommendedCount, 4);
assert.equal(fourMenuResult.diagnostics.recommendedSourceCoverage, "4/4");
assert.equal(fourMenuResult.diagnostics.rawInventoryCount, 8);
assert.equal(fourMenuResult.diagnostics.recommendedInventoryOverlapCount, 4);
assert.equal(fourMenuResult.diagnostics.finalFullMenuCount, 4);
assert.deepEqual(
  fourMenuResult.vision.recommended?.map((item) => item.sourceImageIndexes),
  [[1], [2], [3], [4]],
);

const twoRecommendations = normalized([
  source(1, "menu", [recommendation("a"), recommendation("b")], [
    inventory("a"),
    inventory("b"),
    inventory("c"),
  ]),
]);
const twoRecommendationResult = aggregateVisionMultiResponse(twoRecommendations);
assert.equal(twoRecommendationResult.diagnostics.recommendedCount, 2);
assert.equal(twoRecommendationResult.diagnostics.finalFullMenuCount, 1);

const dedupSources = normalized([
  source(1, "menu", [recommendation("shared")], [
    inventory("shared"),
    inventory("one-only"),
  ]),
  source(2, "menu", [recommendation("two-only")], [
    inventory("two-only"),
    inventory("two-inventory"),
  ]),
  source(3, "menu", [recommendation("shared")], [
    inventory("shared"),
    inventory("three-only"),
  ]),
  source(4, "menu", [recommendation("four-only")], [
    inventory("four-only"),
    inventory("four-inventory"),
  ]),
]);
const dedupResult = aggregateVisionMultiResponse(dedupSources);
assert.equal(dedupResult.diagnostics.recommendedCount, 3);
assert.deepEqual(
  dedupResult.vision.recommended?.find((item) => item.name === "shared")
    ?.sourceImageIndexes,
  [1, 3],
);
assert.equal(dedupResult.diagnostics.recommendedSourceCoverage, "4/4");

const twentyInventory = normalized([
  source(
    1,
    "menu",
    [
      recommendation("item-1"),
      recommendation("item-2"),
      recommendation("item-3"),
      recommendation("item-4"),
    ],
    Array.from({length: 20}, (_, index) => inventory("item-" + (index + 1))),
  ),
]);
const twentyInventoryResult = aggregateVisionMultiResponse(twentyInventory);
assert.equal(twentyInventoryResult.diagnostics.rawInventoryCount, 20);
assert.equal(twentyInventoryResult.diagnostics.recommendedInventoryOverlapCount, 4);
assert.equal(twentyInventoryResult.diagnostics.finalFullMenuCount, 16);

const allOverlap = normalized([
  source(1, "menu", [recommendation("a"), recommendation("b")], [
    inventory("a"),
    inventory("b"),
  ]),
]);
const allOverlapResult = aggregateVisionMultiResponse(allOverlap);
assert.equal(allOverlapResult.diagnostics.finalFullMenuCount, 0);
assert.equal(allOverlapResult.vision.fullMenu?.items.main.length, 0);
assert.equal(allOverlapResult.vision.recommended?.length, 2);

const mismatch = normalizeVisionMultiResponse(
  rawResponse(fourEmptyNonMenu, true),
  4,
);
assert.equal(mismatch.isMenu, false);
assert.equal(mismatch.declaredIsMenu, true);
console.log("visionMulti tests passed");
