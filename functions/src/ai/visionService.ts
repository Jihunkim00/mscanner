import {HttpsError} from "firebase-functions/v2/https";
import OpenAI from "openai";

import {ANALYSIS_MODEL} from "./aiConfig";
import {
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
          schema: VISION_RESPONSE_JSON_SCHEMA,
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
  try {
    vision = normalizeVisionResponse(parsed);
  } catch (error) {
    console.error("[VisionV2] Structured response validation failed", {
      message: error instanceof Error ? error.message : String(error),
    });
    throw new HttpsError("internal", "Structured response validation failed.");
  }

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
