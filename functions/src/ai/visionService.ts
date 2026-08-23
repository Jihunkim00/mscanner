import {HttpsError} from "firebase-functions/v2/https";
import OpenAI from "openai";

import {ANALYSIS_MODEL} from "./aiConfig";
import {
  VISION_MULTI_RESPONSE_JSON_SCHEMA,
  VISION_RESPONSE_JSON_SCHEMA,
  VisionResponse,
  normalizeVisionResponse,
} from "./responseSchema";

interface VisionCallableRequest {
  auth?: unknown;
  data?: unknown;
}

interface VisionV2Response {
  success: true;
  vision: VisionResponse;
  meta: {
    model: string;
    scanMode: "single" | "multi";
    responseMode: "normal" | "stream";
    maxOutputTokens: number;
    latencyMs: number;
  };
  usage: Record<string, unknown>;
  result: string;
  model: string;
  scanMode: "single" | "multi";
  responseMode: "normal" | "stream";
  maxOutputTokens: number;
}

type RequestData = Record<string, unknown>;

function isRecord(value: unknown): value is RequestData {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function normalizeScanMode(value: unknown): "single" | "multi" {
  return value === "multi" ? "multi" : "single";
}

function normalizeResponseMode(value: unknown): "normal" | "stream" {
  return value === "stream" ? "stream" : "normal";
}

function normalizeMaxOutputTokens(
  value: unknown,
  scanMode: "single" | "multi"
): number {
  const fallback = scanMode === "multi" ? 9000 : 3000;
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.floor(value), 1000), 9000);
}

function normalizeUsage(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) return {};

  const usage: Record<string, unknown> = {};
  for (const key of ["prompt_tokens", "completion_tokens", "total_tokens"]) {
    if (typeof value[key] === "number") usage[key] = value[key];
  }

  const details = value.prompt_tokens_details;
  if (isRecord(details) && typeof details.cached_tokens === "number") {
    usage.prompt_tokens_details = {cached_tokens: details.cached_tokens};
  }
  return usage;
}

function safeOpenAiError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return {name: error.name, message: error.message};
  }
  return {};
}

function countFullMenuItems(vision: VisionResponse): number {
  const fullMenu = vision.fullMenu;
  if (!isRecord(fullMenu) || !isRecord(fullMenu.items)) return 0;
  return Object.keys(fullMenu.items).reduce((count, category) => {
    const items = fullMenu.items[category];
    return count + (Array.isArray(items) ? items.length : 0);
  }, 0);
}

function fullMenuCounts(vision: VisionResponse): Record<string, number> {
  const fullMenu = vision.fullMenu;
  const counts: Record<string, number> = {};
  if (!isRecord(fullMenu) || !isRecord(fullMenu.items)) return counts;

  for (const category of Object.keys(fullMenu.items)) {
    const items = fullMenu.items[category];
    if (Array.isArray(items)) counts[category] = items.length;
  }
  return counts;
}

function normalizeSourceImageCount(value: unknown): number | null {
  if (typeof value !== "number" ||
      !Number.isInteger(value) ||
      value < 1 ||
      value > 20) {
    return null;
  }
  return value;
}

function sourceCoverage(
  vision: VisionResponse,
  sourceImageCount: number | null
): string {
  const seen = new Set<number>();
  for (const item of vision.recommended ?? []) {
    for (const index of item.sourceImageIndexes ?? []) {
      if (Number.isInteger(index) &&
          index >= 1 &&
          (sourceImageCount === null || index <= sourceImageCount)) {
        seen.add(index);
      }
    }
  }
  return String(seen.size) + "/" + String(sourceImageCount ?? "?");
}

export async function handleAnalyzeVisionV2(
  request: VisionCallableRequest,
  apiKey: string
): Promise<VisionV2Response> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const imageBase64 = data.imageBase64;
  const prompt = data.prompt;
  if (typeof imageBase64 !== "string" || imageBase64.trim().length === 0) {
    throw new HttpsError("invalid-argument", "imageBase64 required");
  }
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new HttpsError("invalid-argument", "prompt required");
  }

  const scanMode = normalizeScanMode(data.scanMode);
  const responseMode = normalizeResponseMode(data.responseMode);
  const maxOutputTokens = normalizeMaxOutputTokens(data.maxOutputTokens, scanMode);
  const sourceImageCount = normalizeSourceImageCount(data.sourceImageCount);
  const openai = new OpenAI({apiKey});
  const startedAt = Date.now();

  let response: any;
  try {
    response = await openai.chat.completions.create({
      model: ANALYSIS_MODEL,
      messages: [
        {
          role: "user",
          content: [
            {type: "text", text: prompt},
            {
              type: "image_url",
              image_url: {url: `data:image/jpeg;base64,${imageBase64}`},
            },
          ],
        },
      ],
      reasoning_effort: "low",
      max_completion_tokens: maxOutputTokens,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "vision_menu_result",
          description: "A structured food-menu vision analysis result.",
          strict: false,
          schema: scanMode === "multi" ?
            VISION_MULTI_RESPONSE_JSON_SCHEMA :
            VISION_RESPONSE_JSON_SCHEMA,
        },
      },
    } as any);
  } catch (error) {
    console.error("[VisionV2] OpenAI request failed", safeOpenAiError(error));
    throw new HttpsError("internal", "Vision analysis failed.");
  }

  const choice = response.choices?.[0];
  const refusal = choice?.message?.refusal;
  if (typeof refusal === "string" && refusal.trim()) {
    throw new HttpsError("internal", "Vision analysis was refused.");
  }

  const content = choice?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new HttpsError("internal", "OpenAI returned an empty result.");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new HttpsError("internal", "Structured output parsing failed.");
  }

  let vision: VisionResponse;
  let fullMenuCount = 0;
  try {
    vision = normalizeVisionResponse(parsed);
    fullMenuCount = countFullMenuItems(vision);
    if (scanMode === "multi" && vision.isMenu && fullMenuCount === 0) {
      throw new Error("multi menu response contained no full menu items");
    }
  } catch (error) {
    console.error("[VisionV2] Structured response validation failed", {
      message: error instanceof Error ? error.message : String(error),
    });
    throw new HttpsError("internal", "Structured response validation failed.");
  }

  const recommendedCount = vision.recommended?.length ?? 0;
  console.log("[VisionV2] scanMode=%s", scanMode);
  console.log("[VisionV2] itemsCount=%d", vision.items.length);
  console.log(
    "[VisionV2] recommendedCount=%d",
    recommendedCount
  );
  console.log(
    "[VisionV2] recommendedSourceCoverage=%s",
    sourceCoverage(vision, sourceImageCount)
  );
  console.log("[VisionV2] fullMenuCount=%d", fullMenuCount);
  console.log(
    "[VisionV2] fullMenuByCategory=%s",
    JSON.stringify(fullMenuCounts(vision))
  );
  console.log(
    "[VisionV2] fullMenuSummaryPresent=%s",
    Boolean(vision.fullMenu?.summary?.trim())
  );

  const latencyMs = Date.now() - startedAt;
  const usage = normalizeUsage(response.usage);
  const result = JSON.stringify(vision);

  return {
    success: true,
    vision,
    meta: {
      model: ANALYSIS_MODEL,
      scanMode,
      responseMode,
      maxOutputTokens,
      latencyMs,
    },
    usage,
    result,
    model: ANALYSIS_MODEL,
    scanMode,
    responseMode,
    maxOutputTokens,
  };
}
