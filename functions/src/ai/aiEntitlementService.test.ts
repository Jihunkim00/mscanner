import assert from "node:assert/strict";
import * as admin from "firebase-admin";

import {
  resolveAiEntitlement,
} from "./aiEntitlementService";

type DocumentData = Record<string, unknown> | undefined;

function fakeFirestore(
  dataByCollection: Record<string, DocumentData>
): admin.firestore.Firestore {
  return {
    collection: (name: string) => ({
      doc: () => ({
        get: async () => {
          const data = dataByCollection[name];
          return {
            exists: data !== undefined,
            data: () => data,
          };
        },
      }),
    }),
  } as unknown as admin.firestore.Firestore;
}

void (async () => {
  const now = new Date("2026-08-29T00:00:00.000Z");
  const future = admin.firestore.Timestamp.fromDate(
    new Date("2026-08-30T00:00:00.000Z")
  );
  const past = admin.firestore.Timestamp.fromDate(
    new Date("2026-08-28T00:00:00.000Z")
  );
  const verifiedAt = admin.firestore.Timestamp.fromDate(now);

  const trustedDocument = {
    premium: {
      status: "active",
      expiresAt: future,
      verifiedAt,
      source: "apple",
      productId: "premium.monthly",
    },
    updatedAt: verifiedAt,
  };

  const noDocument = await resolveAiEntitlement(
    "uid",
    {firestore: fakeFirestore({}), now}
  );
  assert.deepEqual(noDocument, {
    tier: "free",
    premiumActive: false,
    trust: "none",
    source: "none",
  });

  const userPointsOnly = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        user_points: {
          premium: {status: "active", expiresAt: future},
          isPremium: true,
          isSubscribed: true,
        },
      }),
      now,
    }
  );
  assert.deepEqual(userPointsOnly, {
    tier: "free",
    premiumActive: false,
    trust: "none",
    source: "none",
  });

  const active = await resolveAiEntitlement(
    "uid",
    {firestore: fakeFirestore({
      server_entitlements: trustedDocument,
    }), now}
  );
  assert.deepEqual(active, {
    tier: "premium",
    premiumActive: true,
    trust: "trusted",
    source: "apple",
  });

  const grace = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, status: "grace"},
        },
      }),
      now,
    }
  );
  assert.equal(grace.premiumActive, true);
  assert.equal(grace.trust, "trusted");

  const canceledButEntitled = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, status: "canceled"},
        },
      }),
      now,
    }
  );
  assert.deepEqual(canceledButEntitled, {
    tier: "premium",
    premiumActive: true,
    trust: "trusted",
    source: "apple",
  });

  const expiredStatus = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, status: "expired"},
        },
      }),
      now,
    }
  );
  assert.deepEqual(expiredStatus, {
    tier: "free",
    premiumActive: false,
    trust: "trusted",
    source: "apple",
  });

  const expiredTimestamp = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, expiresAt: past},
        },
      }),
      now,
    }
  );
  assert.equal(expiredTimestamp.premiumActive, false);
  assert.equal(expiredTimestamp.trust, "trusted");

  const invalidSource = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, source: "client"},
        },
      }),
      now,
    }
  );
  assert.deepEqual(invalidSource, {
    tier: "free",
    premiumActive: false,
    trust: "none",
    source: "none",
  });

  const missingVerifiedAt = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, verifiedAt: null},
        },
      }),
      now,
    }
  );
  assert.equal(missingVerifiedAt.premiumActive, false);
  assert.equal(missingVerifiedAt.trust, "none");

  const noExpiry = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, expiresAt: null},
        },
      }),
      now,
    }
  );
  assert.deepEqual(noExpiry, {
    tier: "free",
    premiumActive: false,
    trust: "trusted",
    source: "apple",
  });

  const pending = await resolveAiEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        server_entitlements: {
          ...trustedDocument,
          premium: {...trustedDocument.premium, status: "pending"},
        },
      }),
      now,
    }
  );
  assert.deepEqual(pending, {
    tier: "free",
    premiumActive: false,
    trust: "none",
    source: "none",
  });

  console.log("aiEntitlementService tests passed");
})().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
