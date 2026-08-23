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

export type VisionSourceStatus =
  | "menu"
  | "non_menu"
  | "unreadable"
  | "duplicate";

export interface VisionInventoryItem {
  id: string;
  nameOriginal: string;
  name: string;
  originLanguageCode: string;
  shortDesc: string;
  price: VisionPrice;
  category: string;
  confidence?: number | null;
}

export interface VisionSourceAnalysis {
  sourceImageIndex: number;
  status: VisionSourceStatus;
  recommended: VisionMenuItem[];
  menuItems: VisionInventoryItem[];
  truncated: boolean;
}

export interface VisionMultiAnalysis {
  isMenu: boolean;
  declaredIsMenu: boolean;
  userMessage: string;
  outputLanguage: string;
  sources: VisionSourceAnalysis[];
  selectedFoodStyle?: string;
  selectedFoodStyleLabel?: string;
  foodStyleApplied?: boolean;
  foodStyleSummary?: Record<string, unknown>;
  place?: VisionPlace;
  reason?: string;
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

const inventoryMenuItemSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "nameOriginal",
    "name",
    "originLanguageCode",
    "shortDesc",
    "price",
    "category",
  ],
  properties: {
    id: {type: "string"},
    nameOriginal: {type: "string"},
    name: {type: "string"},
    originLanguageCode: {type: "string"},
    shortDesc: {type: "string", maxLength: 120},
    price: {type: ["number", "string", "null"]},
    category: {
      type: "string",
      enum: ["main", "side", "meal", "drink", "beverage", "unknown"],
    },
    confidence: {type: ["number", "null"]},
  },
};

const sourceRecommendedProperties: Record<string, unknown> = {
  ...menuItemSchema.properties,
};
delete sourceRecommendedProperties.sourceImageIndexes;

const sourceRecommendedItemSchema = {
  ...menuItemSchema,
  properties: sourceRecommendedProperties,
};

const sourceAnalysisSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "sourceImageIndex",
    "status",
    "recommended",
    "menuItems",
    "truncated",
  ],
  properties: {
    sourceImageIndex: {type: "integer", minimum: 1},
    status: {
      type: "string",
      enum: ["menu", "non_menu", "unreadable", "duplicate"],
    },
    recommended: {type: "array", items: sourceRecommendedItemSchema},
    menuItems: {type: "array", items: inventoryMenuItemSchema},
    truncated: {type: "boolean"},
  },
};

export const VISION_MULTI_AI_RESPONSE_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["isMenu", "userMessage", "outputLanguage", "sources"],
  properties: {
    isMenu: VISION_RESPONSE_JSON_SCHEMA.properties.isMenu,
    userMessage: VISION_RESPONSE_JSON_SCHEMA.properties.userMessage,
    outputLanguage: VISION_RESPONSE_JSON_SCHEMA.properties.outputLanguage,
    selectedFoodStyle: VISION_RESPONSE_JSON_SCHEMA.properties.selectedFoodStyle,
    selectedFoodStyleLabel:
      VISION_RESPONSE_JSON_SCHEMA.properties.selectedFoodStyleLabel,
    foodStyleApplied: VISION_RESPONSE_JSON_SCHEMA.properties.foodStyleApplied,
    foodStyleSummary: VISION_RESPONSE_JSON_SCHEMA.properties.foodStyleSummary,
    place: VISION_RESPONSE_JSON_SCHEMA.properties.place,
    reason: VISION_RESPONSE_JSON_SCHEMA.properties.reason,
    sources: {type: "array", items: sourceAnalysisSchema},
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

const SOURCE_STATUSES: VisionSourceStatus[] = [
  "menu",
  "non_menu",
  "unreadable",
  "duplicate",
];

function validateInventoryItem(value: unknown): VisionInventoryItem {
  if (!isRecord(value)) throw new Error("inventory item");
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
    throw new Error("inventory item name");
  }
  if (value.price !== null &&
      typeof value.price !== "string" &&
      typeof value.price !== "number") {
    throw new Error("inventory item price");
  }
  if (!["main", "side", "meal", "drink", "beverage", "unknown"].
    includes(value.category as string)) {
    throw new Error("inventory item category");
  }
  if (value.confidence !== undefined &&
      value.confidence !== null &&
      typeof value.confidence !== "number") {
    throw new Error("inventory item confidence");
  }
  return value as unknown as VisionInventoryItem;
}

function validatePlace(value: unknown): VisionPlace {
  if (!isRecord(value)) throw new Error("place");
  for (const key of ["name", "address", "city"]) {
    if (value[key] !== null && typeof value[key] !== "string") {
      throw new Error("place");
    }
  }
  return {
    name: value.name as string | null,
    address: value.address as string | null,
    city: value.city as string | null,
  };
}

export function normalizeVisionMultiResponse(
  value: unknown,
  inputImageCount: number
): VisionMultiAnalysis {
  if (!isRecord(value)) throw new Error("multi response");
  if (!Number.isInteger(inputImageCount) || inputImageCount < 1) {
    throw new Error("input image count");
  }
  if (typeof value.isMenu !== "boolean") throw new Error("isMenu");
  const userMessage = requireString(value, "userMessage");
  const outputLanguage = requireString(value, "outputLanguage");
  if (!Array.isArray(value.sources) ||
      value.sources.length !== inputImageCount) {
    throw new Error("sources count");
  }

  const seenIndexes = new Set<number>();
  const sources = value.sources.map(
    (rawSource, position): VisionSourceAnalysis => {
      if (!isRecord(rawSource)) throw new Error("source");
      const sourceImageIndex = rawSource.sourceImageIndex;
      if (!Number.isInteger(sourceImageIndex) ||
        (sourceImageIndex as number) !== position + 1 ||
        (sourceImageIndex as number) < 1 ||
        (sourceImageIndex as number) > inputImageCount ||
        seenIndexes.has(sourceImageIndex as number)) {
        throw new Error("sourceImageIndex");
      }
      seenIndexes.add(sourceImageIndex as number);

      const status = rawSource.status;
      if (typeof status !== "string" ||
        !SOURCE_STATUSES.includes(status as VisionSourceStatus)) {
        throw new Error("source status");
      }
      if (!Array.isArray(rawSource.recommended) ||
        !Array.isArray(rawSource.menuItems) ||
        typeof rawSource.truncated !== "boolean") {
        throw new Error("source fields");
      }

      validateItemList(rawSource.recommended);
      const recommended = rawSource.recommended as VisionMenuItem[];
      const menuItems = rawSource.menuItems.map(validateInventoryItem);
      if (status === "menu") {
        if (recommended.length < 1) {
          throw new Error("menu source recommendation");
        }
        if (menuItems.length < 1) {
          throw new Error("menu source inventory");
        }
      } else if (recommended.length > 0 || menuItems.length > 0) {
        throw new Error("non-menu source items");
      }

      return {
        sourceImageIndex: sourceImageIndex as number,
        status: status as VisionSourceStatus,
        recommended,
        menuItems,
        truncated: rawSource.truncated as boolean,
      };
    }
  );

  for (let index = 1; index <= inputImageCount; index++) {
    if (!seenIndexes.has(index)) throw new Error("missing sourceImageIndex");
  }

  const normalized: VisionMultiAnalysis = {
    isMenu: sources.some((source) => source.status === "menu"),
    declaredIsMenu: value.isMenu,
    userMessage,
    outputLanguage,
    sources,
  };
  if (value.selectedFoodStyle !== undefined) {
    normalized.selectedFoodStyle = requireString(value, "selectedFoodStyle");
  }
  if (value.selectedFoodStyleLabel !== undefined) {
    normalized.selectedFoodStyleLabel =
      requireString(value, "selectedFoodStyleLabel");
  }
  if (value.foodStyleApplied !== undefined &&
      typeof value.foodStyleApplied !== "boolean") {
    throw new Error("foodStyleApplied");
  }
  if (value.foodStyleApplied !== undefined) {
    normalized.foodStyleApplied = value.foodStyleApplied;
  }
  if (value.foodStyleSummary !== undefined) {
    if (!isRecord(value.foodStyleSummary)) throw new Error("foodStyleSummary");
    normalized.foodStyleSummary = value.foodStyleSummary;
  }
  if (value.place !== undefined) normalized.place = validatePlace(value.place);
  if (value.reason !== undefined) {
    normalized.reason = requireString(value, "reason");
  }
  return normalized;
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
