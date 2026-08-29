import * as admin from "firebase-admin";

import {AiEntitlementTier} from "./aiAccessConfig";
import {
  readTrustedEntitlement,
  TrustedEntitlementSource,
} from "../entitlements/trustedEntitlementService";

export type AiEntitlementSource = TrustedEntitlementSource | "none";
export type AiEntitlementTrust = "trusted" | "none";

export interface AiEntitlement {
  tier: AiEntitlementTier;
  premiumActive: boolean;
  trust: AiEntitlementTrust;
  source: AiEntitlementSource;
}

export interface ResolveAiEntitlementOptions {
  firestore?: admin.firestore.Firestore;
  now?: Date;
}

function premiumResult(
  active: boolean,
  trust: AiEntitlementTrust,
  source: AiEntitlementSource
): AiEntitlement {
  return {
    tier: active ? "premium" : "free",
    premiumActive: active,
    trust,
    source,
  };
}

function noEntitlement(): AiEntitlement {
  return premiumResult(false, "none", "none");
}

/**
 * Resolve AI entitlement from the server-owned server_entitlements document.
 *
 * user_points.premium, premiumExpiry, and client request flags are deliberately
 * outside this resolver's trust boundary. A valid trusted document still needs
 * a future expiry for premium access; malformed or pending documents fail safe.
 */
export async function resolveAiEntitlement(
  uid: string,
  options: ResolveAiEntitlementOptions = {}
): Promise<AiEntitlement> {
  try {
    const trusted = await readTrustedEntitlement(uid, {
      firestore: options.firestore,
    });

    if (!trusted) return noEntitlement();

    const premium = trusted.premium;
    const now = options.now ?? new Date();

    if (premium.status === "expired" || premium.expiresAt === null ||
        now >= premium.expiresAt) {
      return premiumResult(false, "trusted", premium.source);
    }

    // Canceled subscriptions remain entitled through their verified expiry.
    const active = premium.status === "active" ||
      premium.status === "grace" ||
      premium.status === "canceled";

    return premiumResult(
      active,
      "trusted",
      premium.source
    );
  } catch (_error: unknown) {
    // A failed trusted read must never turn into premium access.
    return noEntitlement();
  }
}
