import {HttpsError} from "firebase-functions/v2/https";

import {AiEntitlementTier, AiScanMode} from "./aiAccessConfig";
import {AiEntitlement} from "./aiEntitlementService";

export interface AiCallableRequest {
  auth?: unknown;
  app?: unknown;
  data?: unknown;
}

export interface AiAccessContext {
  uid: string;
  requestId: string | null;
}

export interface AiAccessDecision {
  context: AiAccessContext;
  entitlement: AiEntitlement;
  quota: {
    allowed: boolean;
    enforced: boolean;
    dayKey: string;
    tier: AiEntitlementTier;
    scanMode: AiScanMode;
    limit: number | null;
    usedCount: number;
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function normalizeAiRequestId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const requestId = value.trim();
  if (!requestId || requestId.length > 64 ||
      !/^[A-Za-z0-9._:-]+$/.test(requestId)) {
    return null;
  }
  return requestId;
}

function authUid(value: unknown): string | null {
  if (!isRecord(value) || typeof value.uid !== "string") return null;
  const uid = value.uid.trim();
  return uid ? uid : null;
}

/** Validate auth and observe App Check without enforcing it. */
export function beginAiAccessObservation(
  request: AiCallableRequest
): AiAccessContext {
  const uid = authUid(request.auth);
  if (uid === null) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const requestId = normalizeAiRequestId(data.requestId);
  const appCheckState = request.app !== undefined && request.app !== null ?
    "valid" :
    "missing_or_invalid";
  const label = requestId ?? "no-request-id";
  console.log(
    "[AI Access][" + label + "] appCheck=" + appCheckState
  );

  return {uid, requestId};
}

/**
 * Resolve entitlement and reserve quota immediately before the OpenAI call.
 * Dependencies are injected to keep the policy unit-testable.
 */
export async function resolveAndReserveAiAccess(
  context: AiAccessContext,
  scanMode: AiScanMode,
  dependencies: {
    resolveEntitlement: (uid: string) => Promise<AiEntitlement>;
    reserveQuota: (
      uid: string,
      tier: AiEntitlementTier,
      scanMode: AiScanMode
    ) => Promise<AiAccessDecision["quota"]>;
  }
): Promise<AiAccessDecision> {
  const entitlement = await dependencies.resolveEntitlement(context.uid);
  const label = context.requestId ?? "no-request-id";
  console.log(
    "[AI Access][" + label + "] entitlementTrust=" + entitlement.trust +
    " tier=" + entitlement.tier +
    " source=" + entitlement.source
  );

  const quota = await dependencies.reserveQuota(
    context.uid,
    entitlement.tier,
    scanMode
  );

  if (!quota.allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Daily AI quota exceeded."
    );
  }

  return {context, entitlement, quota};
}
