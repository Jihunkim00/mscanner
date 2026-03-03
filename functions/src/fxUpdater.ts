// functions/src/fxUpdater.ts
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions, logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { getApps, initializeApp } from "firebase-admin/app";

import { getFirestore, FieldValue } from "firebase-admin/firestore";

setGlobalOptions({ region: "asia-northeast3", timeoutSeconds: 60, memory: "256MiB" });
if (getApps().length === 0) initializeApp();
const db = getFirestore();

const FX_KEY = defineSecret("EXCHANGERATE_HOST_KEY");

const SYMBOLS_TOP50 = [
  "USD", "EUR", "JPY", "GBP", "AUD", "CAD", "CHF", "CNY", "HKD", "NZD",
  "SEK", "KRW", "SGD", "NOK", "MXN", "INR", "RUB", "ZAR", "TRY", "BRL",
  "TWD", "DKK", "PLN", "THB", "IDR", "HUF", "CZK", "ILS", "AED", "SAR",
  "MYR", "CLP", "PHP", "COP", "PKR", "EGP", "KWD", "QAR", "BHD", "OMR",
  "NGN", "ARS", "VND", "BDT", "UAH", "MAD", "KES", "LKR", "RON", "HRK",
] as const;

const PROVIDER = "exchangerate.host";

/** /live 응답(JSON) 파싱 + 검증: USD 베이스 */
async function fetchLiveUSD(accessKey: string) {
  const url =
    "https://api.exchangerate.host/live" +
    `?access_key=${encodeURIComponent(accessKey)}` +
    `&currencies=${SYMBOLS_TOP50.join(",")}`;

  const res = await fetch(url, { headers: { "User-Agent": "MscannerFunctions/1.0" } });
  const text = await res.text();

  let json: any;
  try {
    json = JSON.parse(text);
  } catch {
    logger.error(`FX non-JSON, status=${res.status}, head=${text.slice(0, 200)}`);
    throw new Error("FX response not JSON");
  }

  if (json?.success === false || !json?.quotes) {
    logger.error(`FX invalid, status=${res.status}, head=${text.slice(0, 200)}`);
    throw new Error("Invalid FX payload");
  }

  // quotes 예: { "USDJPY": 156.8, "USDEUR": 0.92, ... }
  const quotes: Record<string, number> = json.quotes;

  // USD 베이스 rates 만들기
  const usdRates: Record<string, number> = {};
  for (const ccy of SYMBOLS_TOP50) {
    if (ccy === "USD") {
      usdRates.USD = 1;
      continue;
    }
    const key = `USD${ccy}`;
    const v = quotes[key];
    if (typeof v === "number") usdRates[ccy] = v;
  }

  // 파생에 필요한 필수 키 체크
  for (const must of ["EUR", "JPY", "CNY", "KRW"] as const) {
    if (usdRates[must] == null) {
      logger.error(`Missing USD${must} in quotes; cannot derive ${must} base.`);
      throw new Error(`Missing USD${must} in quotes`);
    }
  }

  return usdRates;
}

async function saveFxDoc(base: "USD" | "EUR" | "JPY" | "CNY" | "KRW", rates: Record<string, number>) {
  if (rates[base] == null) rates[base] = 1;

  const payload = {
    base,
    rates,
    provider: PROVIDER,
    updatedAt: FieldValue.serverTimestamp(),
  };

  await db.doc(`fx_core/${base}`).set(payload, { merge: true });

  const key = `${base}_${new Date().toISOString().slice(0, 13).replace(/[-:T]/g, "")}`;
  await db.doc(`fx_core_history/${key}`).set(payload);

  logger.info(`FX(${base}) saved. count=${Object.keys(rates).length}`);
}

/** USD 스냅샷으로 임의 base 테이블 파생 (rate_base→ccy = rate_USD→ccy / rate_USD→base) */
function deriveFromUSD<T extends "EUR" | "JPY" | "CNY" | "KRW">(
  base: T,
  usdRates: Record<string, number>
): Record<string, number> {
  const denom = usdRates[base];
  if (!denom || typeof denom !== "number") throw new Error(`Invalid denom for ${base}`);
  const out: Record<string, number> = {};
  for (const [ccy, rUsdToCcy] of Object.entries(usdRates)) {
    if (ccy === base) continue;
    out[ccy] = rUsdToCcy / denom;
  }
  out[base] = 1;
  return out;
}

/** 일 1회 실행(UTC 00:00 = KST 09:00) */
export const updateFxTop50Daily = onSchedule(
  { schedule: "0 0 * * *", secrets: [FX_KEY] },
  async () => {
    const accessKey = FX_KEY.value();
    if (!accessKey) {
      logger.error("No API key found in secret: EXCHANGERATE_HOST_KEY");
      return;
    }

    try {
      // 1) USD 베이스 표를 /live로 한 번만 가져온다
      const usdRates = await fetchLiveUSD(accessKey);
      await saveFxDoc("USD", usdRates);

      // 2) 같은 스냅샷으로 여러 기준 통화(EUR/JPY/CNY/KRW) 파생 저장
      const targets: Array<"EUR" | "JPY" | "CNY" | "KRW"> = ["EUR", "JPY", "CNY", "KRW"];
      for (const base of targets) {
        const derived = deriveFromUSD(base, usdRates);
        await saveFxDoc(base, derived);
      }
    } catch (e) {
      logger.error("updateFxTop50Daily failed", e as any);
    }
  }
);
