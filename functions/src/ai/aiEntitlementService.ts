import * as admin from "firebase-admin";

import {AiEntitlementTier} from "./aiAccessConfig";

export type AiEntitlementSource =
  | "user_points.premium"
  | "user_points.premiumExpiry"
  | "missing_user_points"
  | "invalid_user_points";

export interface AiEntitlement {
  tier: AiEntitlementTier;
  premiumActive: boolean;
  source: AiEntitlementSource;
}

export interface ResolveAiEntitlementOptions {
  firestore?: admin.firestore.Firestore;
  now?: Date;
}

function toDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (typeof value === "number" || typeof value === "string") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  if (typeof value === "object" && value !== null &&
      "toDate" in value && typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function premiumResult(
  active: boolean,
  source: AiEntitlementSource
): AiEntitlement {
  return {
    tier: active ? "premium" : "free",
    premiumActive: active,
    source,
  };
}

/**
 * Resolve AI entitlement from the server-side user_points document only.
 * Client payload flags such as premium/isPremium/isSubscribed are never read.
 *
 * The active/expired semantics intentionally match AdRemoveProvider: a
 * canceled entitlement remains active until its expiry timestamp, while an
 * active/grace/pending status without an expiry is treated as active.
 */
export async function resolveAiEntitlement(
  uid: string,
  options: ResolveAiEntitlementOptions = {}
): Promise<AiEntitlement> {
  const firestore = options.firestore ?? admin.firestore();
  const now = options.now ?? new Date();
  const snapshot = await firestore.collection("user_points").doc(uid).get();

  if (!snapshot.exists) {
    return premiumResult(false, "missing_user_points");
  }

  const data = snapshot.data();
  if (!isRecord(data)) {
    return premiumResult(false, "invalid_user_points");
  }

  const premium = data.premium;
  if (isRecord(premium)) {
    const status = typeof premium.status === "string" ?
      premium.status.toLowerCase() :
      "expired";
    const expiresAt = toDate(premium.expiresAt);
    const entitlementValid = expiresAt !== null && now < expiresAt;
    const statusActive = status === "active" ||
      status === "grace" ||
      status === "pending";

    // A future expiry preserves access even when the subscription is canceled.
    const active = expiresAt !== null ? entitlementValid : statusActive;
    return premiumResult(active, "user_points.premium");
  }

  const legacyExpiry = toDate(data.premiumExpiry);
  return premiumResult(
    legacyExpiry !== null && now < legacyExpiry,
    legacyExpiry === null ? "invalid_user_points" : "user_points.premiumExpiry"
  );
}
