import assert from "node:assert/strict";
import * as admin from "firebase-admin";

import {
  AiQuotaReservation,
  reserveAiQuota,
} from "./aiQuotaService";

void (async () => {
interface FakeSnapshot {
  exists: boolean;
  data: () => Record<string, unknown>;
}

interface FakeTransaction {
  get: (ref: unknown) => Promise<FakeSnapshot>;
  set: (ref: unknown, data: Record<string, unknown>) => void;
}

function fakeFirestore(initial: Record<string, unknown> = {}) {
  let state = {...initial};
  let exists = Object.keys(initial).length > 0;
  let transactionCount = 0;
  let writeCount = 0;

  const firestore = {
    collection: () => ({
      doc: () => ({
        collection: () => ({
          doc: () => ({}),
        }),
      }),
    }),
    runTransaction: async (
      callback: (transaction: FakeTransaction) => Promise<AiQuotaReservation>
    ): Promise<AiQuotaReservation> => {
      transactionCount += 1;
      const transaction: FakeTransaction = {
        get: async () => ({
          exists,
          data: () => state,
        }),
        set: (_ref, data) => {
          writeCount += 1;
          state = {...state, ...data};
          exists = true;
        },
      };
      return callback(transaction);
    },
  } as unknown as admin.firestore.Firestore;

  return {
    firestore,
    state: () => state,
    transactionCount: () => transactionCount,
    writeCount: () => writeCount,
  };
}

const now = new Date("2026-08-29T00:00:00.000Z");
const limits = {free: 2, premium: 5};
const store = fakeFirestore();

const first = await reserveAiQuota(
  "uid",
  "free",
  "single",
  {firestore: store.firestore, now, limits, enforcementEnabled: true}
);
assert.equal(first.allowed, true);
assert.equal(first.usedCount, 1);
assert.equal(store.state().singleCount, 1);
assert.equal(store.state().multiCount, 0);

const second = await reserveAiQuota(
  "uid",
  "free",
  "multi",
  {firestore: store.firestore, now, limits, enforcementEnabled: true}
);
assert.equal(second.allowed, true);
assert.equal(second.usedCount, 2);
assert.equal(store.state().singleCount, 1);
assert.equal(store.state().multiCount, 1);

// A repeated requestId is intentionally not accepted by this API. A repeated
// call still reaches the transaction and is denied at the limit.
const repeatedRequest = await reserveAiQuota(
  "uid",
  "free",
  "single",
  {firestore: store.firestore, now, limits, enforcementEnabled: true}
);
assert.equal(repeatedRequest.allowed, false);
assert.equal(store.writeCount(), 2);
assert.equal(store.transactionCount(), 3);

const disabled = await reserveAiQuota(
  "uid",
  "free",
  "single",
  {now}
);
assert.equal(disabled.allowed, true);
assert.equal(disabled.enforced, false);

const newDay = await reserveAiQuota(
  "uid",
  "premium",
  "multi",
  {
    firestore: store.firestore,
    now: new Date("2026-08-30T00:00:00.000Z"),
    limits,
    enforcementEnabled: true,
  }
);
assert.equal(newDay.allowed, true);
assert.equal(newDay.dayKey, "2026-08-30");

console.log("aiQuotaService tests passed");
})().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
