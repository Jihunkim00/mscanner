import {
  VisionMenuItem,
  VisionMultiAnalysis,
  VisionResponse,
  VisionSourceAnalysis,
  VisionSourceStatus,
} from "./responseSchema";

export interface VisionAggregationDiagnostics {
  sourceStatuses: Record<string, number>;
  perSourceRecommendedCounts: Record<string, number>;
  perSourceMenuItemCounts: Record<string, number>;
  rawInventoryCount: number;
  recommendedInventoryOverlapCount: number;
  recommendedCount: number;
  recommendedSourceCoverage: string;
  finalFullMenuCount: number;
}

export interface VisionAggregationResult {
  vision: VisionResponse;
  diagnostics: VisionAggregationDiagnostics;
}

const MENU_CATEGORIES = [
  "main",
  "side",
  "meal",
  "drink",
  "beverage",
  "unknown",
] as const;

function normalizeItemName(item: {
  nameOriginal?: string;
  name?: string;
}): string {
  const source = (item.nameOriginal || item.name || "").toLowerCase();
  return source
    .trim()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .replace(/\s+/g, " ");
}

function sourceItemKey(sourceImageIndex: number, item: {
  nameOriginal?: string;
  name?: string;
}): string {
  return sourceImageIndex + ":" + normalizeItemName(item);
}

function publicItemKey(item: VisionMenuItem): string {
  return item.category + ":" + normalizeItemName(item);
}

function mergeSourceIndexes(
  target: VisionMenuItem,
  incoming: VisionMenuItem
): VisionMenuItem {
  const indexes = new Set([
    ...(target.sourceImageIndexes ?? []),
    ...(incoming.sourceImageIndexes ?? []),
  ]);
  return {
    ...target,
    sourceImageIndexes: Array.from(indexes).sort((a, b) => a - b),
  };
}

function deduplicatePublicItems(items: VisionMenuItem[]): VisionMenuItem[] {
  const deduplicated = new Map<string, VisionMenuItem>();
  for (const item of items) {
    const key = publicItemKey(item);
    const existing = deduplicated.get(key);
    deduplicated.set(
      key,
      existing ? mergeSourceIndexes(existing, item) : item
    );
  }
  return Array.from(deduplicated.values());
}

function normalizeCategory(category: string): string {
  return MENU_CATEGORIES.includes(category as typeof MENU_CATEGORIES[number]) ?
    category :
    "unknown";
}

function toPublicInventoryItem(
  source: VisionSourceAnalysis,
  item: VisionSourceAnalysis["menuItems"][number],
  ordinal: number
): VisionMenuItem {
  return {
    id: "inventory-" + source.sourceImageIndex + "-" + (item.id || ordinal),
    nameOriginal: item.nameOriginal.trim(),
    name: item.name.trim(),
    originLanguageCode: item.originLanguageCode.trim(),
    shortDesc: item.shortDesc.trim(),
    prices: null,
    price: item.price,
    tags: [],
    category: normalizeCategory(item.category),
    confidence: item.confidence ?? null,
    sourceImageIndexes: [source.sourceImageIndex],
  };
}

function toPublicRecommendation(
  source: VisionSourceAnalysis,
  item: VisionMenuItem
): VisionMenuItem {
  return {
    ...item,
    sourceImageIndexes: [source.sourceImageIndex],
  };
}

function emptyCategoryMap(): Record<string, VisionMenuItem[]> {
  return {
    main: [],
    side: [],
    meal: [],
    drink: [],
    beverage: [],
    unknown: [],
  };
}

function countStatuses(
  sources: VisionSourceAnalysis[]
): Record<string, number> {
  const counts: Record<VisionSourceStatus, number> = {
    menu: 0,
    non_menu: 0,
    unreadable: 0,
    duplicate: 0,
  };
  for (const source of sources) counts[source.status]++;
  return counts;
}

export function aggregateVisionMultiResponse(
  analysis: VisionMultiAnalysis
): VisionAggregationResult {
  const sources = [...analysis.sources].sort(
    (a, b) => a.sourceImageIndex - b.sourceImageIndex
  );
  const recommendedItems: VisionMenuItem[] = [];
  const recommendedKeys = new Set<string>();
  const perSourceRecommendedCounts: Record<string, number> = {};
  const perSourceMenuItemCounts: Record<string, number> = {};

  for (const source of sources) {
    perSourceRecommendedCounts[String(source.sourceImageIndex)] =
      source.recommended.length;
    perSourceMenuItemCounts[String(source.sourceImageIndex)] =
      source.menuItems.length;
    if (source.status !== "menu") continue;

    for (const item of source.recommended) {
      recommendedItems.push(toPublicRecommendation(source, item));
      recommendedKeys.add(sourceItemKey(source.sourceImageIndex, item));
    }
  }

  const recommended = deduplicatePublicItems(recommendedItems);
  const inventoryItems: VisionMenuItem[] = [];
  let rawInventoryCount = 0;
  let recommendedInventoryOverlapCount = 0;

  for (const source of sources) {
    if (source.status !== "menu") continue;
    for (let index = 0; index < source.menuItems.length; index++) {
      const item = source.menuItems[index];
      rawInventoryCount++;
      if (recommendedKeys.has(sourceItemKey(source.sourceImageIndex, item))) {
        recommendedInventoryOverlapCount++;
        continue;
      }
      inventoryItems.push(toPublicInventoryItem(source, item, index));
    }
  }

  const fullMenuItems = deduplicatePublicItems(inventoryItems);
  const fullMenuByCategory = emptyCategoryMap();
  for (const item of fullMenuItems) {
    fullMenuByCategory[normalizeCategory(item.category)].push(item);
  }

  const recommendedSourceIndexes = new Set<number>();
  for (const item of recommended) {
    for (const sourceImageIndex of item.sourceImageIndexes ?? []) {
      recommendedSourceIndexes.add(sourceImageIndex);
    }
  }

  const fullMenu = analysis.isMenu ? {
    items: fullMenuByCategory,
    summary: "",
    truncated: sources.some((source) => source.truncated),
  } : null;

  const vision: VisionResponse = {
    isMenu: analysis.isMenu,
    userMessage: analysis.userMessage,
    outputLanguage: analysis.outputLanguage,
    items: recommended,
    recommended,
    fullMenu,
  };
  if (analysis.selectedFoodStyle !== undefined) {
    vision.selectedFoodStyle = analysis.selectedFoodStyle;
  }
  if (analysis.selectedFoodStyleLabel !== undefined) {
    vision.selectedFoodStyleLabel = analysis.selectedFoodStyleLabel;
  }
  if (analysis.foodStyleApplied !== undefined) {
    vision.foodStyleApplied = analysis.foodStyleApplied;
  }
  if (analysis.foodStyleSummary !== undefined) {
    vision.foodStyleSummary = analysis.foodStyleSummary;
  }
  if (analysis.place !== undefined) vision.place = analysis.place;
  if (analysis.reason !== undefined) vision.reason = analysis.reason;

  return {
    vision,
    diagnostics: {
      sourceStatuses: countStatuses(sources),
      perSourceRecommendedCounts,
      perSourceMenuItemCounts,
      rawInventoryCount,
      recommendedInventoryOverlapCount,
      recommendedCount: recommended.length,
      recommendedSourceCoverage:
        recommendedSourceIndexes.size + "/" + sources.length,
      finalFullMenuCount: fullMenuItems.length,
    },
  };
}
