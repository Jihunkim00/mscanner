export type AiEntitlementTier = "free" | "premium";
export type AiScanMode = "single" | "multi";

// PR12 only lays down the quota foundation. Enforcement is intentionally off
// until production metrics have been observed and a separate rollout changes it.
export const AI_QUOTA_ENFORCEMENT_ENABLED = false;
export const AI_QUOTA_TIME_ZONE = "UTC";
export interface AiQuotaLimits {
  free: number | null;
  premium: number | null;
}

export const AI_QUOTA_LIMITS: AiQuotaLimits = {
  free: null,
  premium: null,
};

export function dailyQuotaForTier(tier: AiEntitlementTier): number | null {
  return AI_QUOTA_LIMITS[tier];
}

export function utcDayKey(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}
