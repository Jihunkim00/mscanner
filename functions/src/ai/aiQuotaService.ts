import * as admin from "firebase-admin";

import {
  AiEntitlementTier,
  AiQuotaLimits,
  AiScanMode,
  AI_QUOTA_ENFORCEMENT_ENABLED,
  dailyQuotaForTier,
  utcDayKey,
} from "./aiAccessConfig";

export interface AiQuotaReservation {
  allowed: boolean;
  enforced: boolean;
  dayKey: string;
  tier: AiEntitlementTier;
  scanMode: AiScanMode;
  limit: number | null;
  usedCount: number;
}

export interface ReserveAiQuotaOptions {
  firestore?: admin.firestore.Firestore;
  now?: Date;
  limits?: AiQuotaLimits;
  enforcementEnabled?: boolean;
}

function safeCount(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return 0;
  return Math.max(0, Math.floor(value));
}

function quotaRef(
  firestore: admin.firestore.Firestore,
  uid: string,
  dayKey: string
): admin.firestore.DocumentReference {
  return firestore.collection("ai_usage").doc(uid).collection("daily").doc(dayKey);
}

/**
 * Reserve one AI request inside a Firestore transaction.
 *
 * requestId is deliberately absent: it is an observability identifier, not an
 * idempotency key. Reusing a requestId therefore cannot skip a quota charge.
 */
export async function reserveAiQuota(
  uid: string,
  tier: AiEntitlementTier,
  scanMode: AiScanMode,
  options: ReserveAiQuotaOptions = {}
): Promise<AiQuotaReservation> {
  const now = options.now ?? new Date();
  const dayKey = utcDayKey(now);
  const limit = options.limits?.[tier] ?? dailyQuotaForTier(tier);
  const enforced = options.enforcementEnabled ?? AI_QUOTA_ENFORCEMENT_ENABLED;

  if (!enforced || limit === null) {
    return {
      allowed: true,
      enforced: false,
      dayKey,
      tier,
      scanMode,
      limit,
      usedCount: 0,
    };
  }

  const firestore = options.firestore ?? admin.firestore();
  const ref = quotaRef(firestore, uid, dayKey);
  const timestamp = admin.firestore.Timestamp.fromDate(now);

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() ?? {} : {};
    const currentTotal = safeCount(data.totalCount);

    if (currentTotal >= limit) {
      return {
        allowed: false,
        enforced: true,
        dayKey,
        tier,
        scanMode,
        limit,
        usedCount: currentTotal,
      };
    }

    const singleCount = safeCount(data.singleCount) + (scanMode === "single" ? 1 : 0);
    const multiCount = safeCount(data.multiCount) + (scanMode === "multi" ? 1 : 0);
    const nextTotal = currentTotal + 1;

    transaction.set(ref, {
      dayKey,
      totalCount: nextTotal,
      singleCount,
      multiCount,
      lastUsedAt: timestamp,
      updatedAt: timestamp,
    }, {merge: true});

    return {
      allowed: true,
      enforced: true,
      dayKey,
      tier,
      scanMode,
      limit,
      usedCount: nextTotal,
    };
  });
}
