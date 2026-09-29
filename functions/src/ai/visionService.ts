import {HttpsError} from "firebase-functions/v2/https";
import OpenAI from "openai";

import {ANALYSIS_MODEL, VISION_V3_MODEL} from "./aiConfig";
import {
  VISION_MULTI_AI_RESPONSE_JSON_SCHEMA,
  VISION_RESPONSE_JSON_SCHEMA,
  VISION_SINGLE_FULL_MENU_RESPONSE_JSON_SCHEMA,
  VisionResponse,
  normalizeVisionMultiResponse,
  normalizeVisionResponse,
} from "./responseSchema";
import {
  aggregateVisionMultiResponse,
  VisionAggregationDiagnostics,
} from "./visionAggregation";
import {
  buildVisionImageContent,
  normalizeVisionImages,
} from "./visionRequest";

interface VisionCallableRequest {
  auth?: unknown;
  data?: unknown;
}

interface VisionAnalysisResponse {
  success: true;
  vision: VisionResponse;
  meta: {
    model: string;
    scanMode: "single" | "multi";
    responseMode: "normal" | "stream";
    maxOutputTokens: number;
    latencyMs: number;
    partial: boolean;
    validSourceCount: number;
    expectedSourceCount: number;
    validationWarningCount: number;
    validationWarnings: string[];
    requestId: string | null;
    requestFullMenu: boolean;
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

function normalizeRequestId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const safe = value.trim();
  if (!safe || safe.length > 64 || !/^[A-Za-z0-9._:-]+$/.test(safe)) {
    return null;
  }
  return safe;
}

function visionLog(
  requestId: string | null,
  message: string,
  version: "VisionV2" | "VisionV3" = "VisionV2"
): void {
  console.log(`[${version}][${requestId ?? "no-request-id"}] ${message}`);
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

function normalizeUsage(value: unknown, includeReasoningTokens = false): Record<string, unknown> {
  if (!isRecord(value)) return {};

  const usage: Record<string, unknown> = {};
  for (const key of ["prompt_tokens", "completion_tokens", "total_tokens"]) {
    if (typeof value[key] === "number") usage[key] = value[key];
  }

  const details = value.prompt_tokens_details;
  if (isRecord(details) && typeof details.cached_tokens === "number") {
    usage.prompt_tokens_details = {cached_tokens: details.cached_tokens};
  }
  const completionDetails = value.completion_tokens_details;
  if (includeReasoningTokens && isRecord(completionDetails) &&
      typeof completionDetails.reasoning_tokens === "number") {
    usage.completion_tokens_details = {
      reasoning_tokens: completionDetails.reasoning_tokens,
    };
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

function countRawFullMenuItems(value: unknown): number {
  if (!isRecord(value) || !isRecord(value.fullMenu)) return 0;
  const items = value.fullMenu.items;
  if (!isRecord(items)) return 0;
  return Object.values(items).reduce<number>((count, category) => {
    return count + (Array.isArray(category) ? category.length : 0);
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

async function handleAnalyzeVision(
  request: VisionCallableRequest,
  apiKey: string,
  model: string,
  version: "VisionV2" | "VisionV3"
): Promise<VisionAnalysisResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const requestId = normalizeRequestId(data.requestId);
  const log = (message: string) => visionLog(requestId, message, version);
  const prompt = data.prompt;
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new HttpsError("invalid-argument", "prompt required");
  }

  const scanMode: "single" | "multi" =
    Array.isArray(data.imagesBase64) && data.imagesBase64.length > 1 ?
      "multi" :
      "single";
  const requestFullMenu = scanMode === "single" && data.requestFullMenu === true;
  const responseMode = normalizeResponseMode(data.responseMode);
  const maxOutputTokens = normalizeMaxOutputTokens(data.maxOutputTokens, scanMode);
  let normalizedImages;
  try {
    normalizedImages = normalizeVisionImages(data, scanMode);
  } catch (error) {
    log("input_normalization_failed");
    throw new HttpsError(
      "invalid-argument",
      error instanceof Error ? error.message : "Invalid vision image input"
    );
  }
  const {
    imagesBase64,
    inputImageCount,
    sourceImageCount,
  } = normalizedImages;
  log(`request_received scanMode=${scanMode} inputImageCount=${inputImageCount} ` +
    `sourceImageCount=${sourceImageCount ?? "unknown"} requestFullMenu=${requestFullMenu}`
  );
  const openai = new OpenAI({apiKey});
  const startedAt = Date.now();

  let response: any;
  log(`openai_start model=${model}`);
  try {
    response = await openai.chat.completions.create({
      model,
      messages: [
        {
          role: "user",
          content: buildVisionImageContent(prompt, imagesBase64),
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
            VISION_MULTI_AI_RESPONSE_JSON_SCHEMA :
            requestFullMenu ?
              VISION_SINGLE_FULL_MENU_RESPONSE_JSON_SCHEMA :
              VISION_RESPONSE_JSON_SCHEMA,
        },
      },
    } as any);
    log(`openai_success latencyMs=${Date.now() - startedAt}`);
  } catch (error) {
    log("openai_failure");
    console.error("[" + version + "] OpenAI request failed", safeOpenAiError(error));
    throw new HttpsError("internal", "Vision analysis failed.");
  }

  const choice = response.choices?.[0];
  const refusal = choice?.message?.refusal;
  if (typeof refusal === "string" && refusal.trim()) {
    log("openai_refusal");
    throw new HttpsError("internal", "Vision analysis was refused.");
  }

  const content = choice?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    log("openai_empty_response");
    throw new HttpsError("internal", "OpenAI returned an empty result.");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    log("json_parse_failure");
    throw new HttpsError("internal", "Structured output parsing failed.");
  }
  log("json_parse_success");

  let vision: VisionResponse;
  let fullMenuCount = 0;
  let aggregationDiagnostics: VisionAggregationDiagnostics | undefined;
  let declaredIsMenuMismatch = false;
  let partial = false;
  let validSourceCount = 1;
  const expectedSourceCount = inputImageCount;
  let validationWarnings: string[] = [];
  let rawSingleFullMenuCount = 0;
  let singleFullMenuOverlapCount = 0;
  let validationStage = "normalization";
  try {
    if (scanMode === "multi") {
      const analysis = normalizeVisionMultiResponse(parsed, inputImageCount);
      declaredIsMenuMismatch = analysis.declaredIsMenu !== analysis.isMenu;
      partial = analysis.partial === true;
      validSourceCount = analysis.validSourceCount ?? analysis.sources.length;
      validationWarnings = [...(analysis.validationWarnings ?? [])];
      validationStage = "aggregation";
      const aggregated = aggregateVisionMultiResponse(analysis);
      vision = aggregated.vision;
      aggregationDiagnostics = aggregated.diagnostics;
    } else {
      if (requestFullMenu) rawSingleFullMenuCount = countRawFullMenuItems(parsed);
      vision = normalizeVisionResponse(parsed);
    }
    fullMenuCount = countFullMenuItems(vision);
    if (requestFullMenu) {
      singleFullMenuOverlapCount = Math.max(
        rawSingleFullMenuCount - fullMenuCount,
        0,
      );
    }
    log(`validation_success stage=${validationStage} recommendedCount=${vision.recommended?.length ?? 0} ` +
      `fullMenuCount=${fullMenuCount}`
    );
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    log(`validation_failure stage=${validationStage}`);
    console.error("[" + version + "] Structured response validation failed", {
      message: reason,
    });
    console.error("[" + version + "] validationHardFailureReason=%s", reason);
    throw new HttpsError("internal", "Structured response validation failed.");
  }

  const recommendedCount = vision.recommended?.length ?? 0;
  log(`response_ready partial=${partial} recommendedCount=${recommendedCount} ` +
    `fullMenuCount=${fullMenuCount}`
  );
  console.log(
    "[" + version + "] scanMode=%s inputImageCount=%d sourceImageCount=%s",
    scanMode,
    inputImageCount,
    sourceImageCount ?? "unknown"
  );
  console.log("[" + version + "] itemsCount=%d", vision.items.length);
  console.log(
    "[" + version + "] recommendedCount=%d",
    recommendedCount
  );
  if (aggregationDiagnostics !== undefined) {
    console.log("[" + version + "] sourceCount=%d", inputImageCount);
    console.log("[" + version + "] sourceStatuses=%s",
      JSON.stringify(aggregationDiagnostics.sourceStatuses));
    console.log("[" + version + "] perSourceRecommendedCounts=%s",
      JSON.stringify(aggregationDiagnostics.perSourceRecommendedCounts));
    console.log("[" + version + "] perSourceMenuItemCounts=%s",
      JSON.stringify(aggregationDiagnostics.perSourceMenuItemCounts));
    console.log("[" + version + "] rawInventoryCount=%d",
      aggregationDiagnostics.rawInventoryCount);
    console.log("[" + version + "] recommendedInventoryOverlapCount=%d",
      aggregationDiagnostics.recommendedInventoryOverlapCount);
    console.log("[" + version + "] finalFullMenuCount=%d",
      aggregationDiagnostics.finalFullMenuCount);
  }
  console.log(
    "[" + version + "] recommendedSourceCoverage=%s",
    aggregationDiagnostics?.recommendedSourceCoverage ??
      sourceCoverage(vision, inputImageCount)
  );
  console.log("[" + version + "] fullMenuCount=%d", fullMenuCount);
  if (requestFullMenu) {
    log(`single_full_menu rawCount=${rawSingleFullMenuCount} ` +
      `recommendedOverlapCount=${singleFullMenuOverlapCount} finalCount=${fullMenuCount}`
    );
  }
  console.log(
    "[" + version + "] fullMenuByCategory=%s",
    JSON.stringify(fullMenuCounts(vision))
  );
  console.log(
    "[" + version + "] fullMenuSummaryPresent=%s",
    Boolean(vision.fullMenu?.summary?.trim())
  );
  if (declaredIsMenuMismatch) {
    console.log("[" + version + "] declaredIsMenuMismatch=true");
  }
  for (const warning of validationWarnings) {
    console.log("[" + version + "] multiValidationWarning=%s", warning);
  }

  const latencyMs = Date.now() - startedAt;
  const responseModel = version === "VisionV3" &&
      typeof response.model === "string" && response.model.trim() ?
    response.model : model;
  console.log("[" + version + "] model=%s", responseModel);
  console.log("[" + version + "] latencyMs=%d", latencyMs);
  const usage = normalizeUsage(response.usage, version === "VisionV3");
  if (version === "VisionV3") {
    log(
      `token_usage prompt=${usage.prompt_tokens ?? "unknown"} ` +
      `completion=${usage.completion_tokens ?? "unknown"} ` +
      `total=${usage.total_tokens ?? "unknown"} ` +
      `reasoning=${isRecord(usage.completion_tokens_details) ?
        usage.completion_tokens_details.reasoning_tokens ?? "unknown" : "unknown"}`
    );
  }
  const result = JSON.stringify(vision);

  return {
    success: true,
    vision,
    meta: {
      model: responseModel,
      scanMode,
      responseMode,
      maxOutputTokens,
      latencyMs,
      partial,
      validSourceCount,
      expectedSourceCount,
      validationWarningCount: validationWarnings.length,
      validationWarnings,
      requestId,
      requestFullMenu,
    },
    usage,
    result,
    model: responseModel,
    scanMode,
    responseMode,
    maxOutputTokens,
  };
}


export async function handleAnalyzeVisionV2(
  request: VisionCallableRequest,
  apiKey: string
): Promise<VisionAnalysisResponse> {
  return handleAnalyzeVision(request, apiKey, ANALYSIS_MODEL, "VisionV2");
}

export async function handleAnalyzeVisionV3(
  request: VisionCallableRequest,
  apiKey: string
): Promise<VisionAnalysisResponse> {
  return handleAnalyzeVision(request, apiKey, VISION_V3_MODEL, "VisionV3");
}
