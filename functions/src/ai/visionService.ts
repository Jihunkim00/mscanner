import {HttpsError} from "firebase-functions/v2/https";
import OpenAI from "openai";

import {ANALYSIS_MODEL} from "./aiConfig";
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
import {
  cleanupTempUploads,
  normalizeStoragePaths,
  readVisionStorageImages,
} from "./visionStorage";

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
    partial: boolean;
    validSourceCount: number;
    expectedSourceCount: number;
    validationWarningCount: number;
    validationWarnings: string[];
    requestId: string | null;
    requestFullMenu: boolean;
    inputMode: "storage_paths" | "images_base64";
    storageReadLatencyMs: number | null;
    storageReadBytes: number;
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

function visionLog(requestId: string | null, message: string): void {
  console.log(`[VisionV2][${requestId ?? "no-request-id"}] ${message}`);
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

export async function handleAnalyzeVisionV2(
  request: VisionCallableRequest,
  apiKey: string
): Promise<VisionV2Response> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const requestId = normalizeRequestId(data.requestId);
  const prompt = data.prompt;
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new HttpsError("invalid-argument", "prompt required");
  }

  const hasStoragePaths = data.storagePaths !== undefined;
  const hasLegacyMultiImages =
    Array.isArray(data.imagesBase64) && data.imagesBase64.length > 1;
  const scanMode: "single" | "multi" =
    hasStoragePaths || hasLegacyMultiImages ? "multi" : "single";
  const requestFullMenu = scanMode === "single" && data.requestFullMenu === true;
  const responseMode = normalizeResponseMode(data.responseMode);
  const maxOutputTokens = normalizeMaxOutputTokens(data.maxOutputTokens, scanMode);
  let imagesBase64: string[];
  let inputImageCount: number;
  let sourceImageCount: number | null;
  let inputMode: "storage_paths" | "images_base64";
  let storagePaths: string[] | null = null;
  let storageReadLatencyMs: number | null = null;
  let storageReadBytes = 0;
  try {
    if (hasStoragePaths) {
      const authUid = isRecord(request.auth) && typeof request.auth.uid === "string" ?
        request.auth.uid :
        null;
      if (authUid === null || authUid.trim().length === 0) {
        throw new Error("authenticated uid required for storage paths");
      }
      storagePaths = normalizeStoragePaths(
        data.storagePaths,
        authUid,
        data.sourceImageCount,
      );
      imagesBase64 = [];
      inputImageCount = storagePaths.length;
      sourceImageCount = storagePaths.length;
      inputMode = "storage_paths";
    } else {
      const normalizedImages = normalizeVisionImages(data, scanMode);
      imagesBase64 = normalizedImages.imagesBase64;
      inputImageCount = normalizedImages.inputImageCount;
      sourceImageCount = normalizedImages.sourceImageCount;
      inputMode = "images_base64";
    }
  } catch (error) {
    visionLog(requestId, "input_normalization_failed");
    throw new HttpsError(
      "invalid-argument",
      error instanceof Error ? error.message : "Invalid vision image input"
    );
  }
  visionLog(requestId, `input_mode=${inputMode}`);
  if (storagePaths !== null) {
    visionLog(requestId, `sourceImageCount=${sourceImageCount}`);
    visionLog(requestId, "tempReadStart");
    const readStartedAt = Date.now();
    try {
      const storageImages = await readVisionStorageImages(storagePaths);
      imagesBase64 = storageImages.imagesBase64;
      storageReadBytes = storageImages.totalBytes;
      storageReadLatencyMs = Date.now() - readStartedAt;
      visionLog(
        requestId,
        `tempReadComplete totalBytes=${storageReadBytes} latencyMs=${storageReadLatencyMs}`,
      );
    } catch (error) {
      storageReadLatencyMs = Date.now() - readStartedAt;
      visionLog(requestId, `tempReadFailure latencyMs=${storageReadLatencyMs}`);
      try {
        const cleanup = await cleanupTempUploads(storagePaths);
        visionLog(requestId, `cleanupAttempt count=${cleanup.attempted}`);
        if (cleanup.warnings.length === 0) {
          visionLog(requestId, `cleanupComplete deleted=${cleanup.deleted}`);
        } else {
          visionLog(requestId, "cleanupWarning");
        }
      } catch {
        visionLog(requestId, "cleanupWarning");
      }
      throw new HttpsError("internal", "Vision image loading failed.");
    }
  }
  visionLog(
    requestId,
    `request_received scanMode=${scanMode} inputImageCount=${inputImageCount} ` +
    `sourceImageCount=${sourceImageCount ?? "unknown"} requestFullMenu=${requestFullMenu}`
  );
  try {
    const openai = new OpenAI({apiKey});
    const startedAt = Date.now();

    let response: any;
    visionLog(requestId, `openai_start model=${ANALYSIS_MODEL}`);
    try {
      response = await openai.chat.completions.create({
        model: ANALYSIS_MODEL,
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
      visionLog(requestId, `openai_success latencyMs=${Date.now() - startedAt}`);
    } catch (error) {
      visionLog(requestId, "openai_failure");
      console.error("[VisionV2] OpenAI request failed", safeOpenAiError(error));
      throw new HttpsError("internal", "Vision analysis failed.");
    }

    const choice = response.choices?.[0];
    const refusal = choice?.message?.refusal;
    if (typeof refusal === "string" && refusal.trim()) {
      visionLog(requestId, "openai_refusal");
      throw new HttpsError("internal", "Vision analysis was refused.");
    }

    const content = choice?.message?.content;
    if (typeof content !== "string" || content.trim().length === 0) {
      visionLog(requestId, "openai_empty_response");
      throw new HttpsError("internal", "OpenAI returned an empty result.");
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(content);
    } catch {
      visionLog(requestId, "json_parse_failure");
      throw new HttpsError("internal", "Structured output parsing failed.");
    }
    visionLog(requestId, "json_parse_success");

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
      visionLog(
        requestId,
        `validation_success stage=${validationStage} recommendedCount=${vision.recommended?.length ?? 0} ` +
      `fullMenuCount=${fullMenuCount}`
      );
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      visionLog(requestId, `validation_failure stage=${validationStage}`);
      console.error("[VisionV2] Structured response validation failed", {
        message: reason,
      });
      console.error("[VisionV2] validationHardFailureReason=%s", reason);
      throw new HttpsError("internal", "Structured response validation failed.");
    }

    const recommendedCount = vision.recommended?.length ?? 0;
    visionLog(
      requestId,
      `response_ready partial=${partial} recommendedCount=${recommendedCount} ` +
    `fullMenuCount=${fullMenuCount}`
    );
    console.log(
      "[VisionV2] scanMode=%s inputImageCount=%d sourceImageCount=%s",
      scanMode,
      inputImageCount,
      sourceImageCount ?? "unknown"
    );
    console.log("[VisionV2] itemsCount=%d", vision.items.length);
    console.log(
      "[VisionV2] recommendedCount=%d",
      recommendedCount
    );
    if (aggregationDiagnostics !== undefined) {
      console.log("[VisionV2] sourceCount=%d", inputImageCount);
      console.log("[VisionV2] sourceStatuses=%s",
        JSON.stringify(aggregationDiagnostics.sourceStatuses));
      console.log("[VisionV2] perSourceRecommendedCounts=%s",
        JSON.stringify(aggregationDiagnostics.perSourceRecommendedCounts));
      console.log("[VisionV2] perSourceMenuItemCounts=%s",
        JSON.stringify(aggregationDiagnostics.perSourceMenuItemCounts));
      console.log("[VisionV2] rawInventoryCount=%d",
        aggregationDiagnostics.rawInventoryCount);
      console.log("[VisionV2] recommendedInventoryOverlapCount=%d",
        aggregationDiagnostics.recommendedInventoryOverlapCount);
      console.log("[VisionV2] finalFullMenuCount=%d",
        aggregationDiagnostics.finalFullMenuCount);
    }
    console.log(
      "[VisionV2] recommendedSourceCoverage=%s",
      aggregationDiagnostics?.recommendedSourceCoverage ??
      sourceCoverage(vision, inputImageCount)
    );
    console.log("[VisionV2] fullMenuCount=%d", fullMenuCount);
    if (requestFullMenu) {
      visionLog(
        requestId,
        `single_full_menu rawCount=${rawSingleFullMenuCount} ` +
      `recommendedOverlapCount=${singleFullMenuOverlapCount} finalCount=${fullMenuCount}`
      );
    }
    console.log(
      "[VisionV2] fullMenuByCategory=%s",
      JSON.stringify(fullMenuCounts(vision))
    );
    console.log(
      "[VisionV2] fullMenuSummaryPresent=%s",
      Boolean(vision.fullMenu?.summary?.trim())
    );
    if (declaredIsMenuMismatch) {
      console.log("[VisionV2] declaredIsMenuMismatch=true");
    }
    for (const warning of validationWarnings) {
      console.log("[VisionV2] multiValidationWarning=%s", warning);
    }

    const latencyMs = Date.now() - startedAt;
    console.log("[VisionV2] latencyMs=%d", latencyMs);
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
        partial,
        validSourceCount,
        expectedSourceCount,
        validationWarningCount: validationWarnings.length,
        validationWarnings,
        requestId,
        requestFullMenu,
        inputMode,
        storageReadLatencyMs,
        storageReadBytes,
      },
      usage,
      result,
      model: ANALYSIS_MODEL,
      scanMode,
      responseMode,
      maxOutputTokens,
    };
  } finally {
    if (storagePaths !== null) {
      visionLog(requestId, `cleanupAttempt count=${storagePaths.length}`);
      try {
        const cleanup = await cleanupTempUploads(storagePaths);
        if (cleanup.warnings.length === 0) {
          visionLog(requestId, `cleanupComplete deleted=${cleanup.deleted}`);
        } else {
          visionLog(requestId, "cleanupWarning");
          console.warn(
            "[VisionV2] cleanupWarning count=%d",
            cleanup.warnings.length,
          );
        }
      } catch (error) {
        visionLog(requestId, "cleanupWarning");
        console.warn(
          "[VisionV2] cleanupWarning reason=%s",
          error instanceof Error ? error.name : "unknown",
        );
      }
    }
  }
}
