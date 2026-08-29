import assert from "node:assert/strict";
import * as admin from "firebase-admin";

import {
  resolveAiEntitlement,
} from "./aiEntitlementService";

void (async () => {
type UserPointsData = Record<string, unknown> | undefined;

function fakeFirestore(data: UserPointsData): admin.firestore.Firestore {
  return {
    collection: () => ({
      doc: () => ({
        get: async () => ({
          exists: data !== undefined,
          data: () => data,
        }),
      }),
    }),
  } as unknown as admin.firestore.Firestore;
}

const now = new Date("2026-08-29T00:00:00.000Z");
const future = admin.firestore.Timestamp.fromDate(
  new Date("2026-08-30T00:00:00.000Z")
);
const past = admin.firestore.Timestamp.fromDate(
  new Date("2026-08-28T00:00:00.000Z")
);

const noDocument = await resolveAiEntitlement(
  "uid",
  {firestore: fakeFirestore(undefined), now}
);
assert.deepEqual(noDocument, {
  tier: "free",
  premiumActive: false,
  source: "missing_user_points",
});

const active = await resolveAiEntitlement(
  "uid",
  {
    firestore: fakeFirestore({
      premium: {status: "active", expiresAt: future},
    }),
    now,
  }
);
assert.equal(active.tier, "premium");
assert.equal(active.premiumActive, true);
assert.equal(active.source, "user_points.premium");

const expired = await resolveAiEntitlement(
  "uid",
  {
    firestore: fakeFirestore({
      premium: {status: "active", expiresAt: past},
    }),
    now,
  }
);
assert.equal(expired.tier, "free");
assert.equal(expired.premiumActive, false);

const canceledButEntitled = await resolveAiEntitlement(
  "uid",
  {
    firestore: fakeFirestore({
      premium: {status: "canceled", expiresAt: future},
    }),
    now,
  }
);
assert.equal(canceledButEntitled.premiumActive, true);

const legacyActive = await resolveAiEntitlement(
  "uid",
  {firestore: fakeFirestore({premiumExpiry: future}), now}
);
assert.equal(legacyActive.tier, "premium");
assert.equal(legacyActive.source, "user_points.premiumExpiry");

const legacyExpired = await resolveAiEntitlement(
  "uid",
  {firestore: fakeFirestore({premiumExpiry: past}), now}
);
assert.equal(legacyExpired.tier, "free");

// Client-style flags do not participate in server entitlement resolution.
const clientFlagIgnored = await resolveAiEntitlement(
  "uid",
  {
    firestore: fakeFirestore({
      premium: {status: "expired"},
      isPremium: true,
      isSubscribed: true,
    }),
    now,
  }
);
assert.equal(clientFlagIgnored.tier, "free");

console.log("aiEntitlementService tests passed");
})().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
