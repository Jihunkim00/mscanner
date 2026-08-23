import assert from "node:assert/strict";
import {
  VISION_SINGLE_FULL_MENU_RESPONSE_JSON_SCHEMA,
  VisionMenuItem,
  normalizeVisionResponse,
} from "./responseSchema";

function item(name: string): VisionMenuItem {
  return {
    id: "item-" + name,
    nameOriginal: name,
    name,
    originLanguageCode: "en",
    shortDesc: "A readable menu item.",
    prices: {
      small: null,
      medium: null,
      large: null,
      single: null,
      currency: null,
    },
    tags: [],
    category: "main",
    confidence: 0.9,
  };
}

const normalized = normalizeVisionResponse({
  isMenu: true,
  userMessage: "result",
  outputLanguage: "en",
  recommended: [item("A-B"), item("B")],
  fullMenu: {
    items: {
      main: [item(" a b "), item("B"), item("C")],
    },
    summary: "",
    truncated: false,
  },
});

assert.equal(normalized.recommended?.length, 2);
assert.equal(normalized.fullMenu?.items.main.length, 1);
assert.equal(normalized.fullMenu?.items.main[0].name, "C");

const withoutFullMenu = normalizeVisionResponse({
  isMenu: true,
  userMessage: "result",
  outputLanguage: "en",
  recommended: [item("A")],
});
assert.equal(withoutFullMenu.fullMenu, undefined);

const required = VISION_SINGLE_FULL_MENU_RESPONSE_JSON_SCHEMA.required as string[];
assert(required.includes("recommended"));
assert(required.includes("fullMenu"));

console.log("visionSingle tests passed");
