export type VisionPrice = number | string | null;

export interface VisionPrices {
  small: VisionPrice;
  medium: VisionPrice;
  large: VisionPrice;
  single: VisionPrice;
  currency: string | null;
}

export interface VisionMenuItem {
  id: string;
  nameOriginal: string;
  name: string;
  originLanguageCode: string;
  nameOriginalReading?: string;
  shortDesc: string;
  prices: VisionPrices | null;
  price?: VisionPrice;
  tags: string[];
  category: string;
  confidence: number | null;
  foodStyleFit?: string;
  styleMatched?: boolean;
  styleFitScore?: number;
  recommendationRank?: number;
  recommendationReason?: string;
  matchedEvidence?: string[];
  cautionReason?: string;
  dietaryWarnings?: string[];
  allergyHints?: string[];
  requiresStaffCheck?: boolean;
  sourceImageIndexes?: number[];
}

export interface VisionPlace {
  name: string | null;
  address: string | null;
  city: string | null;
}

export interface VisionFullMenu {
  items: Record<string, VisionMenuItem[]>;
  summary: string;
  truncated: boolean;
}

export interface VisionResponse {
  isMenu: boolean;
  userMessage: string;
  outputLanguage: string;
  items: VisionMenuItem[];
  recommended?: VisionMenuItem[];
  selectedFoodStyle?: string;
  selectedFoodStyleLabel?: string;
  foodStyleApplied?: boolean;
  foodStyleSummary?: Record<string, unknown>;
  place?: VisionPlace;
  reason?: string;
  fullMenu?: VisionFullMenu | null;
}

const priceSchema = {
  type: "object",
  additionalProperties: false,
  required: ["small", "medium", "large", "single", "currency"],
  properties: {
    small: {type: ["number", "string", "null"]},
    medium: {type: ["number", "string", "null"]},
    large: {type: ["number", "string", "null"]},
    single: {type: ["number", "string", "null"]},
    currency: {type: ["string", "null"]},
  },
};

const menuItemSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "nameOriginal",
    "name",
    "originLanguageCode",
    "shortDesc",
    "prices",
    "tags",
    "category",
    "confidence",
  ],
  properties: {
    id: {type: "string"},
    nameOriginal: {type: "string"},
    name: {type: "string"},
    originLanguageCode: {type: "string"},
    nameOriginalReading: {type: "string"},
    shortDesc: {type: "string"},
    prices: {anyOf: [priceSchema, {type: "null"}]},
    price: {type: ["number", "string", "null"]},
    tags: {type: "array", items: {type: "string"}},
    category: {
      type: "string",
      enum: ["main", "side", "meal", "drink", "beverage", "unknown"],
    },
    confidence: {type: ["number", "null"]},
    foodStyleFit: {
      type: "string",
      enum: ["recommended", "caution", "notRecommended", "unknown"],
    },
    styleMatched: {type: "boolean"},
    styleFitScore: {type: "number"},
    recommendationRank: {type: "integer"},
    recommendationReason: {type: "string"},
    matchedEvidence: {type: "array", items: {type: "string"}},
    cautionReason: {type: "string"},
    dietaryWarnings: {type: "array", items: {type: "string"}},
    allergyHints: {type: "array", items: {type: "string"}},
    requiresStaffCheck: {type: "boolean"},
    sourceImageIndexes: {
      type: "array",
      items: {type: "integer", minimum: 1},
    },
  },
};

const categoryItemsSchema = {
  type: "object",
  additionalProperties: false,
  required: ["main", "side", "meal", "drink", "beverage", "unknown"],
  properties: {
    main: {type: "array", items: menuItemSchema},
    side: {type: "array", items: menuItemSchema},
    meal: {type: "array", items: menuItemSchema},
    drink: {type: "array", items: menuItemSchema},
    beverage: {type: "array", items: menuItemSchema},
    unknown: {type: "array", items: menuItemSchema},
  },
};

const fullMenuSchema = {
  type: "object",
  additionalProperties: false,
  required: ["items", "summary", "truncated"],
  properties: {
    items: categoryItemsSchema,
    summary: {type: "string"},
    truncated: {type: "boolean"},
  },
};

export const VISION_RESPONSE_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["isMenu", "userMessage", "outputLanguage"],
  properties: {
    isMenu: {type: "boolean"},
    userMessage: {type: "string"},
    outputLanguage: {type: "string"},
    items: {type: "array", items: menuItemSchema},
    // Existing Flutter prompts call the list recommended.
    recommended: {type: "array", items: menuItemSchema},
    selectedFoodStyle: {type: "string"},
    selectedFoodStyleLabel: {type: "string"},
    foodStyleApplied: {type: "boolean"},
    foodStyleSummary: {
      type: "object",
      additionalProperties: false,
      required: [
        "styleId",
        "matchedItemCount",
        "cautionItemCount",
        "notRecommendedItemCount",
        "topRecommendedItemIndexes",
        "confidence",
        "reason",
        "disclaimer",
      ],
      properties: {
        styleId: {type: "string"},
        matchedItemCount: {type: "integer"},
        cautionItemCount: {type: "integer"},
        notRecommendedItemCount: {type: "integer"},
        topRecommendedItemIndexes: {
          type: "array",
          items: {type: "integer"},
        },
        confidence: {type: "number"},
        reason: {type: "string"},
        disclaimer: {type: "string"},
      },
    },
    place: {
      type: "object",
      additionalProperties: false,
      required: ["name", "address", "city"],
      properties: {
        name: {type: ["string", "null"]},
        address: {type: ["string", "null"]},
        city: {type: ["string", "null"]},
      },
    },
    reason: {type: "string"},
    fullMenu: {anyOf: [fullMenuSchema, {type: "null"}]},
  },
};

export const VISION_MULTI_RESPONSE_JSON_SCHEMA = {
  ...VISION_RESPONSE_JSON_SCHEMA,
  required: [
    "isMenu",
    "userMessage",
    "outputLanguage",
    "recommended",
    "fullMenu",
  ],
  properties: {
    ...VISION_RESPONSE_JSON_SCHEMA.properties,
    fullMenu: {anyOf: [fullMenuSchema, {type: "null"}]},
  },
};

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireString(record: UnknownRecord, key: string): string {
  const value = record[key];
  if (typeof value !== "string") throw new Error(key);
  return value;
}

function validateMenuItem(value: unknown): void {
  if (!isRecord(value)) throw new Error();
  for (const key of [
    "id",
    "nameOriginal",
    "name",
    "originLanguageCode",
    "shortDesc",
    "category",
  ]) {
    requireString(value, key);
  }
  if (!String(value.nameOriginal).trim() && !String(value.name).trim()) {
    throw new Error();
  }
  if (value.prices !== null && !isRecord(value.prices)) throw new Error();
  if (!Array.isArray(value.tags) ||
      value.tags.some((item) => typeof item !== "string")) {
    throw new Error();
  }
  if (value.confidence !== null && typeof value.confidence !== "number") {
    throw new Error();
  }
  if (value.sourceImageIndexes !== undefined &&
      (!Array.isArray(value.sourceImageIndexes) ||
       value.sourceImageIndexes.some((item) =>
         !Number.isInteger(item) || (item as number) < 1))) {
    throw new Error();
  }
}

function validateItemList(value: unknown): void {
  if (!Array.isArray(value)) throw new Error();
  for (const item of value) validateMenuItem(item);
}

function validateFullMenu(value: unknown): void {
  if (value === null) return;
  if (!isRecord(value)) throw new Error();

  const items = value.items;
  if (items !== undefined) {
    if (!isRecord(items)) throw new Error();
    for (const category of [
      "main",
      "side",
      "meal",
      "drink",
      "beverage",
      "unknown",
    ]) {
      if (items[category] !== undefined) validateItemList(items[category]);
    }
  }
  if (value.summary !== undefined && typeof value.summary !== "string") {
    throw new Error();
  }
  if (value.truncated !== undefined && typeof value.truncated !== "boolean") {
    throw new Error();
  }
}

export function normalizeVisionResponse(value: unknown): VisionResponse {
  if (!isRecord(value)) throw new Error();
  if (typeof value.isMenu !== "boolean") throw new Error();
  requireString(value, "userMessage");
  requireString(value, "outputLanguage");

  const items = Array.isArray(value.items) ? value.items : [];
  const recommended = Array.isArray(value.recommended) ?
    value.recommended :
    [];
  const rawItems = items.length > 0 ? items : recommended;
  validateItemList(rawItems);
  if (!value.isMenu && (rawItems as unknown[]).length > 0) throw new Error();
  if (value.items !== undefined) validateItemList(value.items);
  if (value.recommended !== undefined) validateItemList(value.recommended);
  if (value.fullMenu !== undefined) validateFullMenu(value.fullMenu);

  return {
    ...(value as unknown as VisionResponse),
    items: rawItems as VisionMenuItem[],
  };
}
