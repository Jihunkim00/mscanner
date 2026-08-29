import assert from "node:assert/strict";
import * as admin from "firebase-admin";

import {
  TRUSTED_ENTITLEMENTS_COLLECTION,
  readTrustedEntitlement,
  writeTrustedEntitlement,
} from "../entitlements/trustedEntitlementService";

type DocumentData = Record<string, unknown> | undefined;

function fakeFirestore(
  data: DocumentData,
  onSet?: (value: Record<string, unknown>) => void,
  collectionNames: string[] = []
): admin.firestore.Firestore {
  return {
    collection: (name: string) => {
      collectionNames.push(name);
      return {
        doc: () => ({
          get: async () => ({
            exists: data !== undefined,
            data: () => data,
          }),
          set: async (value: Record<string, unknown>) => {
            onSet?.(value);
          },
        }),
      };
    },
  } as unknown as admin.firestore.Firestore;
}

void (async () => {
  const now = new Date("2026-08-29T00:00:00.000Z");
  const future = admin.firestore.Timestamp.fromDate(
    new Date("2026-08-30T00:00:00.000Z")
  );
  const verifiedAt = admin.firestore.Timestamp.fromDate(now);

  const validDocument = {
    premium: {
      status: "active",
      expiresAt: future,
      verifiedAt,
      source: "apple",
      productId: "premium.monthly",
    },
    updatedAt: verifiedAt,
  };

  const missing = await readTrustedEntitlement(
    "uid",
    {firestore: fakeFirestore(undefined)}
  );
  assert.equal(missing, null);

  const valid = await readTrustedEntitlement(
    "uid",
    {firestore: fakeFirestore(validDocument)}
  );
  assert.equal(valid?.premium.source, "apple");

  const missingProductId = await readTrustedEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        ...validDocument,
        premium: {...validDocument.premium, productId: undefined},
      }),
    }
  );
  assert.equal(missingProductId, null);

  const missingVerifiedAt = await readTrustedEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        ...validDocument,
        premium: {...validDocument.premium, verifiedAt: null},
      }),
    }
  );
  assert.equal(missingVerifiedAt, null);

  const invalidSource = await readTrustedEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        ...validDocument,
        premium: {...validDocument.premium, source: "client"},
      }),
    }
  );
  assert.equal(invalidSource, null);

  const pendingStatus = await readTrustedEntitlement(
    "uid",
    {
      firestore: fakeFirestore({
        ...validDocument,
        premium: {...validDocument.premium, status: "pending"},
      }),
    }
  );
  assert.equal(pendingStatus, null);

  const collectionNames: string[] = [];
  const userPointsOnly = await readTrustedEntitlement(
    "uid",
    {
      firestore: fakeFirestore(
        undefined,
        undefined,
        collectionNames
      ),
    }
  );
  assert.equal(userPointsOnly, null);
  assert.deepEqual(collectionNames, [TRUSTED_ENTITLEMENTS_COLLECTION]);

  let written: Record<string, unknown> | undefined;
  await writeTrustedEntitlement(
    "uid",
    {
      verifiedSource: "google",
      verifiedStatus: "active",
      verifiedExpiresAt: future,
      verifiedProductId: "premium.yearly",
    },
    {firestore: fakeFirestore(undefined, (value) => written = value)}
  );
  assert.equal(written?.premium &&
  (written.premium as Record<string, unknown>).source, "google");
  assert.equal(written?.premium &&
  (written.premium as Record<string, unknown>).productId, "premium.yearly");
  assert.ok(written?.premium &&
  (written.premium as Record<string, unknown>).verifiedAt);
  assert.ok(written?.updatedAt);

  await assert.rejects(
    () => writeTrustedEntitlement(
      "uid",
      {
        verifiedSource: "client" as "apple",
        verifiedExpiresAt: future,
      }
    ),
    /Invalid verified entitlement metadata/
  );

  await assert.rejects(
    () => writeTrustedEntitlement(
      "uid",
      {
        verifiedSource: "apple",
        verifiedExpiresAt: "future" as unknown as Date,
      }
    ),
    /verifiedExpiresAt must be a valid server date/
  );

  await assert.rejects(
    () => writeTrustedEntitlement(
      "uid",
      {
        verifiedSource: "apple",
        verifiedStatus: "pending" as "active",
        verifiedExpiresAt: future,
      }
    ),
    /Invalid verified entitlement metadata/
  );

  console.log("trustedEntitlementService tests passed");
})().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
