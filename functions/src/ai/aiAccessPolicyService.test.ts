import assert from "node:assert/strict";

import {
  beginAiAccessObservation,
  resolveAndReserveAiAccess,
} from "./aiAccessPolicyService";

void (async () => {
  const context = beginAiAccessObservation({
    auth: {uid: "uid"},
    app: {appId: "firebase-app"},
    data: {requestId: "vision-123"},
  });
  assert.deepEqual(context, {uid: "uid", requestId: "vision-123"});

  const missingAppCheck = beginAiAccessObservation({
    auth: {uid: "uid"},
    data: {requestId: "vision-124"},
  });
  assert.equal(missingAppCheck.uid, "uid");

  assert.throws(
    () => beginAiAccessObservation({data: {requestId: "unauthenticated"}}),
    (error: unknown) => error instanceof Error
  );

  const allowed = await resolveAndReserveAiAccess(
    context,
    "single",
    {
      resolveEntitlement: async () => ({
        tier: "free",
        premiumActive: false,
        source: "missing_user_points",
      }),
      reserveQuota: async (_uid, tier, scanMode) => ({
        allowed: true,
        enforced: false,
        dayKey: "2026-08-29",
        tier,
        scanMode,
        limit: null,
        usedCount: 0,
      }),
    }
  );
  assert.equal(allowed.entitlement.tier, "free");
  assert.equal(allowed.quota.allowed, true);

  await assert.rejects(
    () => resolveAndReserveAiAccess(
      context,
      "multi",
      {
        resolveEntitlement: async () => ({
          tier: "premium",
          premiumActive: true,
          source: "user_points.premium",
        }),
        reserveQuota: async (_uid, tier, scanMode) => ({
          allowed: false,
          enforced: true,
          dayKey: "2026-08-29",
          tier,
          scanMode,
          limit: 1,
          usedCount: 1,
        }),
      }
    ),
    (error: unknown) => {
      return error instanceof Error &&
      "code" in error &&
      error.code === "resource-exhausted";
    }
  );

  console.log("aiAccessPolicyService tests passed");
})().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
