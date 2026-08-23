// functions/src/index.ts
export {updateFxTop50Daily} from "./fxUpdater";

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import { randomUUID } from "crypto";
import sharp from "sharp";

if (admin.apps.length === 0) {
  admin.initializeApp();
}


const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

export const generateMenuImage = onCall(
  { timeoutSeconds: 120, memory: "1GiB", secrets: [OPENAI_API_KEY] },
  async (req) => {
    const auth = req.auth;
    if (!auth) throw new HttpsError("unauthenticated", "Login required.");

    const { menuKey, menu, shortDesc, tags, searchedMenuDocId } = req.data || {};
    if (!menuKey || typeof menuKey !== "string") {
      throw new HttpsError("invalid-argument", "menuKey required");
    }
    if (!menu || typeof menu !== "object") {
      throw new HttpsError("invalid-argument", "menu required");
    }

    const original = String(menu.original ?? "").trim();
    const translated = String(menu.translated ?? "").trim();

    const docRef = admin.firestore().collection("menu_images").doc(menuKey);

    // 1) 중복 체크 + pending 락
    const docSnap = await docRef.get();
    if (docSnap.exists) {
      const d = docSnap.data(); // ✅ non-null assertion 제거
      if (d?.status === "ready" && d.thumb_url) {
        return { status: "ready", thumb_url: d.thumb_url, full_url: d.full_url };
      }
      if (d?.status === "pending") {
        return { status: "pending" };
      }
    }

    await docRef.set(
      {
        status: "pending",
        menu: { original, translated },
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 2) OpenAI 이미지 생성
    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });

    const name = translated || original || "food";
    const desc = String(shortDesc ?? "").trim();
    const tagText = Array.isArray(tags) ? tags.slice(0, 6).join(", ") : "";

    const prompt = [
      `Professional food photography of "${name}" (${original || translated}).`,
      desc ? `Dish description: ${desc}.` : "",
      tagText ? `Keywords: ${tagText}.` : "",
      "Plated on ceramic dish, natural soft light, shallow depth of field, 50mm lens, high detail, appetizing.",
      "No text, no watermark, no logo.",
    ].filter(Boolean).join(" ");

    // GPT Image 모델은 base64 반환이 기본
    const result = await openai.images.generate({
      model: "gpt-image-1-mini",
      prompt,
      size: "1024x1024",
      quality: "low",
    });

    const b64 = result.data?.[0]?.b64_json;
    if (!b64) throw new Error("No b64_json returned");

    const fullBytes = Buffer.from(b64, "base64");

    // 3) 썸네일 생성(예: 512)
    const thumbBytes = await sharp(fullBytes).resize(512, 512, { fit: "cover" }).jpeg({ quality: 82 }).toBuffer();
    const fullJpg = await sharp(fullBytes).jpeg({ quality: 88 }).toBuffer();

    // 4) Storage 업로드 + download token URL 만들기
    const bucket = admin.storage().bucket();
    const token = randomUUID();

    const fullPath = `ai_food/${menuKey}/full.jpg`;
    const thumbPath = `ai_food/${menuKey}/thumb.jpg`;

    await bucket.file(fullPath).save(fullJpg, {
      contentType: "image/jpeg",
      metadata: {
        cacheControl: "public, max-age=31536000",
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });

    await bucket.file(thumbPath).save(thumbBytes, {
      contentType: "image/jpeg",
      metadata: {
        cacheControl: "public, max-age=31536000",
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });

    const enc = encodeURIComponent;
    const baseUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/`;
    const fullUrl = `${baseUrl}${enc(fullPath)}?alt=media&token=${token}`;
    const thumbUrl = `${baseUrl}${enc(thumbPath)}?alt=media&token=${token}`;

    // 5) Firestore 업데이트
    await docRef.set(
      {
        status: "ready",
        full_url: fullUrl,
        thumb_url: thumbUrl,
        model: "gpt-image-1-mini",
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 6) searched menu 문서에도 URL 넣기(요구사항)
    if (searchedMenuDocId && typeof searchedMenuDocId === "string") {
      await admin.firestore().collection("searched menu").doc(searchedMenuDocId).set(
        {
          menu_image_thumb_url: thumbUrl,
          menu_image_full_url: fullUrl,
          menu_image_status: "ready",
          menu_key: menuKey,
        },
        { merge: true }
      );
    }

    return { status: "ready", thumb_url: thumbUrl, full_url: fullUrl };
  }
);

type LangCode = "ko" | "en" | "ja";
type Scenario = "basic_order" | "customize_order" | "allergy_check" | "recommendation_ask";
type Modifier = "less_spicy" | "less_salty" | "no_cilantro" | "no_onion";
type Allergy = "peanut" | "milk" | "shrimp" | "egg";

const supportedLanguages = new Set<LangCode>(["ko", "en", "ja"]);
const supportedScenarios = new Set<Scenario>([
  "basic_order",
  "customize_order",
  "allergy_check",
  "recommendation_ask",
]);
const supportedModifiers = new Set<Modifier>([
  "less_spicy",
  "less_salty",
  "no_cilantro",
  "no_onion",
]);
const supportedAllergies = new Set<Allergy>(["peanut", "milk", "shrimp", "egg"]);
const modifierPriority: Modifier[] = [
  "no_cilantro",
  "no_onion",
  "less_spicy",
  "less_salty",
];

const modifierText = {
  ko: {
    no_cilantro: "고수는 빼 주세요",
    no_onion: "양파는 빼 주세요",
    less_spicy: "덜 맵게 해 주세요",
    less_salty: "덜 짜게 해 주세요",
  },
  en: {
    no_cilantro: "no cilantro",
    no_onion: "no onion",
    less_spicy: "less spicy",
    less_salty: "less salty",
  },
  ja: {
    no_cilantro: "パクチーぬき",
    no_onion: "たまねぎぬき",
    less_spicy: "からさひかえめ",
    less_salty: "えんぶんひかえめ",
  },
} as const;

const allergyText = {
  ko: {peanut: "땅콩", milk: "우유", shrimp: "새우", egg: "계란"},
  en: {peanut: "peanuts", milk: "milk", shrimp: "shrimp", egg: "egg"},
  ja: {peanut: "ピーナッツ", milk: "ぎゅうにゅう", shrimp: "えび", egg: "たまご"},
} as const;

function joinWithAnd(items: string[], lang: LangCode): string {
  if (items.length <= 1) return items[0] ?? "";
  if (lang === "ko") return `${items.slice(0, -1).join(", ")} 그리고 ${items[items.length - 1]}`;
  if (lang === "ja") return `${items.slice(0, -1).join("、")} と ${items[items.length - 1]}`;
  return `${items.slice(0, -1).join(", ")} and ${items[items.length - 1]}`;
}

function composeTexts(
  menuName: string,
  scenario: Scenario,
  modifiers: Modifier[],
  allergies: Allergy[]
): {koText: string; enText: string; jaText: string; tags: string[]} {
  switch (scenario) {
  case "basic_order":
    return {
      koText: `${menuName} 하나 주문할게요.`,
      enText: `I'd like one ${menuName}, please.`,
      jaText: `${menuName}をひとつおねがいします。`,
      tags: ["basic_order"],
    };

  case "customize_order": {
    const sorted = [...modifiers].sort(
      (a, b) => modifierPriority.indexOf(a) - modifierPriority.indexOf(b)
    );

    const koMods = sorted.map((m) => modifierText.ko[m]).join(", ");
    const enMods = sorted.map((m) => modifierText.en[m]).join(", ");
    const jaMods = sorted.map((m) => modifierText.ja[m]).join("、");

    return {
      koText: `${menuName} 하나 주문할게요. ${koMods}.`,
      enText: `I'd like one ${menuName}, please. ${enMods}.`,
      jaText: `${menuName}をひとつおねがいします。${jaMods}でおねがいします`,
      tags: ["customize_order", ...sorted],
    };
  }

  case "allergy_check": {
    const koAllergy = allergies.map((a) => allergyText.ko[a]);
    const enAllergy = allergies.map((a) => allergyText.en[a]);
    const jaAllergy = allergies.map((a) => allergyText.ja[a]);

    return {
      koText: `저는 ${joinWithAnd(koAllergy, "ko")} 알레르기가 있어요. ${menuName}에 들어가나요?`,
      enText: `I'm allergic to ${joinWithAnd(enAllergy, "en")}. Does ${menuName} contain it?`,
      jaText: `わたしは${joinWithAnd(jaAllergy, "ja")}のアレルギーがあります。${menuName}にはいっていますか。`,
      tags: ["allergy_check", ...allergies],
    };
  }

  case "recommendation_ask":
    return {
      koText: `${menuName}이랑 비슷한 메뉴 추천해 주세요.`,
      enText: `Could you recommend something similar to ${menuName}?`,
      jaText: `${menuName}ににたメニューをおすすめしてもらえますか。`,
      tags: ["recommendation_ask"],
    };
  }
}

function composeTextByLanguage(
  menuName: string,
  lang: LangCode,
  scenario: Scenario,
  modifiers: Modifier[],
  allergies: Allergy[]
): { text: string; tags: string[] } {
  const composed = composeTexts(menuName, scenario, modifiers, allergies);

  switch (lang) {
  case "ko":
    return { text: composed.koText, tags: composed.tags };

  case "en":
    return { text: composed.enText, tags: composed.tags };

  case "ja":
    return { text: composed.jaText, tags: composed.tags };

  default:
    return { text: composed.enText, tags: composed.tags };
  }
}

function hasJapaneseKanji(text: string): boolean {
  return /[\u4E00-\u9FFF]/.test(text);
}

function sanitizeMenuNameForSpeech(text: string): string {
  return text
    .replace(/\s+/g, " ")
    .replace(/\b\d{1,2}[.)]\s*/g, " ")
    .replace(/\b\d+\s*(원|엔|¥|\$|krw|jpy|usd)\b/gi, " ")
    .replace(/\b\d+\b/g, " ")
    .replace(/[|•·]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function buildTtsLocalMenuName(
  originLanguageCode: LangCode,
  menuOriginal: string,
  menuOriginalReading: string
): string {
  const reading = sanitizeMenuNameForSpeech(menuOriginalReading.trim());
  if (reading) return reading;

  const cleaned = sanitizeMenuNameForSpeech(menuOriginal);
  if (cleaned) {
    if (originLanguageCode === "ja" && hasJapaneseKanji(cleaned)) {
      return cleaned;
    }
    return cleaned;
  }

  if (originLanguageCode === "ja") return "このりょうり";
  if (originLanguageCode === "ko") return "이 메뉴";
  return "this dish";
}


export const generateOrderPhrase = onCall(async (req) => {
  const data = req.data ?? {};
  const originLanguageCode = String(data.originLanguageCode ?? data.languageCode ?? "").trim() as LangCode;
  const targetLanguageCode = String(data.targetLanguageCode ?? data.languageCode ?? "").trim() as LangCode;
  const menuName = String(data.menuName ?? "").trim();
  const menuOriginalRaw = String(data.menuOriginal ?? "").trim();
  const menuOriginalReading = String(data.menuOriginalReading ?? "").trim();
  const menuOriginal = menuOriginalRaw || menuName;
  const scenario = String(data.scenario ?? "").trim() as Scenario;
  const modifiers = Array.isArray(data.modifiers) ? data.modifiers as string[] : [];
  const allergies = Array.isArray(data.allergies) ? data.allergies as string[] : [];

  if (!supportedLanguages.has(originLanguageCode)) {
    throw new HttpsError("invalid-argument", "originLanguageCode must be ko, en, or ja");
  }
  if (!supportedLanguages.has(targetLanguageCode)) {
    throw new HttpsError("invalid-argument", "targetLanguageCode must be ko, en, or ja");
  }
  if (!menuName) {
    throw new HttpsError("invalid-argument", "menuName is required");
  }
  if (!supportedScenarios.has(scenario)) {
    throw new HttpsError("invalid-argument", "scenario is invalid");
  }


  const typedModifiers = [...new Set(modifiers)].map((m) => String(m).trim() as Modifier);
  const typedAllergies = [...new Set(allergies)].map((a) => String(a).trim() as Allergy);

  if (typedModifiers.some((m) => !supportedModifiers.has(m))) {
    throw new HttpsError("invalid-argument", "modifiers contain unsupported value");
  }
  if (typedAllergies.some((a) => !supportedAllergies.has(a))) {
    throw new HttpsError("invalid-argument", "allergies contain unsupported value");
  }
  if (scenario === "customize_order" && typedModifiers.length === 0) {
    throw new HttpsError("invalid-argument", "customize_order requires modifiers");
  }
  if (scenario === "allergy_check" && typedAllergies.length === 0) {
    throw new HttpsError("invalid-argument", "allergy_check requires allergies");
  }

  const ttsMenuName = buildTtsLocalMenuName(originLanguageCode, menuOriginal, menuOriginalReading);
  const local = composeTextByLanguage(menuOriginal, originLanguageCode, scenario, typedModifiers, typedAllergies);
  const ttsLocal = composeTextByLanguage(ttsMenuName, originLanguageCode, scenario, typedModifiers, typedAllergies);
  const target = composeTextByLanguage(menuName, targetLanguageCode, scenario, typedModifiers, typedAllergies);

  return {
    success: true,
    // new fields
    originLanguageCode,
    targetLanguageCode,
    localText: local.text,
    ttsText: ttsLocal.text,
    targetText: target.text,
    tags: local.tags,
    // legacy compatibility
    languageCode: originLanguageCode,
  };
});

function resolveVisionMaxOutputTokens(
  value: unknown,
  scanMode: string
): number {
  const fallback = scanMode === "multi" ? 9000 : 3000;
  const serverMax = 9000;

  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallback;
  }

  return Math.min(
    Math.max(Math.floor(value), 1000),
    serverMax
  );
}

export const analyzeVision = onCall(
  {
    timeoutSeconds: 180,
    memory: "1GiB",
    secrets: [OPENAI_API_KEY],
  },
  async (req) => {
    const auth = req.auth;

    if (!auth) {
      throw new HttpsError(
        "unauthenticated",
        "Login required."
      );
    }

    const {
      imageBase64,
      prompt,
      maxOutputTokens,
      scanMode,
      responseMode,
    } = req.data || {};

    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "imageBase64 required"
      );
    }

    if (!prompt || typeof prompt !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "prompt required"
      );
    }

    const safeScanMode =
      scanMode === "multi" ? "multi" : "single";

    const safeResponseMode =
      responseMode === "stream" ? "stream" : "normal";

    const safeMaxOutputTokens =
      resolveVisionMaxOutputTokens(
        maxOutputTokens,
        safeScanMode
      );

    // 메뉴 분석·번역 모델
    const model = "gpt-5.6-luna";

    const openai = new OpenAI({
      apiKey: OPENAI_API_KEY.value(),
    });

    const response =
      await openai.chat.completions.create({
        model,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: prompt,
              },
              {
                type: "image_url",
                image_url: {
                  url:
                    `data:image/jpeg;base64,${imageBase64}`,
                },
              },
            ],
          },
        ],
        reasoning_effort: "low",
        max_completion_tokens:
          safeMaxOutputTokens,
      } as any);

    const content =
      response.choices?.[0]?.message?.content ?? "";

    if (!content.trim()) {
      throw new HttpsError(
        "internal",
        "OpenAI returned an empty result."
      );
    }

    return {
      success: true,
      result: content,
      model,
      scanMode: safeScanMode,
      responseMode: safeResponseMode,
      maxOutputTokens: safeMaxOutputTokens,
      usage: response.usage ?? null,
    };
  }
);
