import * as admin from "firebase-admin";

export const TRUSTED_ENTITLEMENTS_COLLECTION = "server_entitlements";

export type TrustedEntitlementSource =
  | "apple"
  | "google"
  | "migration"
  | "admin";

export type TrustedEntitlementStatus =
  | "active"
  | "grace"
  | "canceled"
  | "expired";

export interface TrustedPremiumEntitlement {
  status: TrustedEntitlementStatus;
  expiresAt: Date | null;
  verifiedAt: Date;
  source: TrustedEntitlementSource;
  productId: string | null;
}

export interface TrustedEntitlement {
  premium: TrustedPremiumEntitlement;
  updatedAt: Date;
}

/**
 * This is the narrow input accepted from a future server-side store verifier.
 * It intentionally has no request payload or arbitrary map escape hatch.
 */
export interface VerifiedEntitlementResult {
  verifiedSource: TrustedEntitlementSource;
  verifiedStatus?: TrustedEntitlementStatus;
  verifiedExpiresAt: Date | admin.firestore.Timestamp | null;
  verifiedProductId?: string | null;
}

export interface TrustedEntitlementServiceOptions {
  firestore?: admin.firestore.Firestore;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toDate(value: unknown): Date | null {
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === "object" && value !== null &&
      "toDate" in value && typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }

  return null;
}

function isTrustedSource(value: unknown): value is TrustedEntitlementSource {
  return value === "apple" || value === "google" ||
    value === "migration" || value === "admin";
}

function isTrustedStatus(value: unknown): value is TrustedEntitlementStatus {
  return value === "active" || value === "grace" ||
    value === "canceled" || value === "expired";
}

function normalizeUid(uid: string): string {
  if (typeof uid !== "string" || !uid.trim()) {
    throw new Error("Trusted entitlement uid is required.");
  }
  return uid.trim();
}

function entitlementRef(
  firestore: admin.firestore.Firestore,
  uid: string
): admin.firestore.DocumentReference {
  return firestore.collection(TRUSTED_ENTITLEMENTS_COLLECTION).doc(uid);
}

/**
 * Read and validate the server-owned entitlement document.
 * Any missing or malformed trust metadata is treated as no entitlement.
 */
export async function readTrustedEntitlement(
  uid: string,
  options: TrustedEntitlementServiceOptions = {}
): Promise<TrustedEntitlement | null> {
  const firestore = options.firestore ?? admin.firestore();
  const snapshot = await entitlementRef(firestore, normalizeUid(uid)).get();

  if (!snapshot.exists) return null;

  const data = snapshot.data() ?? {};
  const premium = isRecord(data?.premium) ? data.premium : null;
  if (!premium || !isTrustedStatus(premium.status) ||
      !isTrustedSource(premium.source)) {
    return null;
  }

  if (!Object.prototype.hasOwnProperty.call(premium, "productId")) {
    return null;
  }

  const verifiedAt = toDate(premium.verifiedAt);
  const updatedAt = toDate(data?.updatedAt);
  const expiresAt = premium.expiresAt === null ?
    null : toDate(premium.expiresAt);
  const productId = premium.productId === null ?
    null : premium.productId;

  if (!verifiedAt || !updatedAt ||
      (premium.expiresAt !== null && !expiresAt) ||
      (productId !== null && typeof productId !== "string")) {
    return null;
  }

  return {
    premium: {
      status: premium.status,
      expiresAt,
      verifiedAt,
      source: premium.source,
      productId,
    },
    updatedAt,
  };
}

/**
 * Write a trusted entitlement from a server-side verified result only.
 * Firestore server timestamps are used for all trust metadata generated here.
 */
export async function writeTrustedEntitlement(
  uid: string,
  verified: VerifiedEntitlementResult,
  options: TrustedEntitlementServiceOptions = {}
): Promise<void> {
  const normalizedUid = normalizeUid(uid);
  if (!isRecord(verified)) {
    throw new Error("Invalid verified entitlement metadata.");
  }
  const status = verified.verifiedStatus ?? "active";

  if (!isTrustedSource(verified.verifiedSource) ||
      !isTrustedStatus(status)) {
    throw new Error("Invalid verified entitlement metadata.");
  }

  const expiresAt = verified.verifiedExpiresAt === null ?
    null : toDate(verified.verifiedExpiresAt);
  if (verified.verifiedExpiresAt !== null && !expiresAt) {
    throw new Error("verifiedExpiresAt must be a valid server date.");
  }

  const productId = verified.verifiedProductId ?? null;
  if (productId !== null && typeof productId !== "string") {
    throw new Error("verifiedProductId must be a string or null.");
  }

  const firestore = options.firestore ?? admin.firestore();
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  await entitlementRef(firestore, normalizedUid).set({
    premium: {
      status,
      expiresAt: expiresAt === null ? null :
        admin.firestore.Timestamp.fromDate(expiresAt),
      verifiedAt: timestamp,
      source: verified.verifiedSource,
      productId,
    },
    updatedAt: timestamp,
  });
}
