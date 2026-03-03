// functions/src/index.ts
export {updateFxTop50Daily} from "./fxUpdater";

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import { randomUUID } from "crypto";
import sharp from "sharp";

if (admin.apps.length === 0) {
  admin.initializeApp();
}


const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

export const generateMenuImage = onCall(
  { timeoutSeconds: 120, memory: "1GiB", secrets: [OPENAI_API_KEY] },
  async (req) => {
    const auth = req.auth;
    if (!auth) throw new HttpsError("unauthenticated", "Login required.");

    const { menuKey, menu, shortDesc, tags, searchedMenuDocId } = req.data || {};
    if (!menuKey || typeof menuKey !== "string") {
      throw new HttpsError("invalid-argument", "menuKey required");
    }
    if (!menu || typeof menu !== "object") {
      throw new HttpsError("invalid-argument", "menu required");
    }

    const original = String(menu.original ?? "").trim();
    const translated = String(menu.translated ?? "").trim();

    const docRef = admin.firestore().collection("menu_images").doc(menuKey);

    // 1) 중복 체크 + pending 락
    const docSnap = await docRef.get();
    if (docSnap.exists) {
      const d = docSnap.data(); // ✅ non-null assertion 제거
      if (d?.status === "ready" && d.thumb_url) {
        return { status: "ready", thumb_url: d.thumb_url, full_url: d.full_url };
      }
      if (d?.status === "pending") {
        return { status: "pending" };
      }
    }

    await docRef.set(
      {
        status: "pending",
        menu: { original, translated },
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 2) OpenAI 이미지 생성
    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });

    const name = translated || original || "food";
    const desc = String(shortDesc ?? "").trim();
    const tagText = Array.isArray(tags) ? tags.slice(0, 6).join(", ") : "";

    const prompt = [
      `Professional food photography of "${name}" (${original || translated}).`,
      desc ? `Dish description: ${desc}.` : "",
      tagText ? `Keywords: ${tagText}.` : "",
      "Plated on ceramic dish, natural soft light, shallow depth of field, 50mm lens, high detail, appetizing.",
      "No text, no watermark, no logo.",
    ].filter(Boolean).join(" ");

    // GPT Image 모델은 base64 반환이 기본
    const result = await openai.images.generate({
      model: "gpt-image-1-mini",
      prompt,
      size: "1024x1024",
      quality: "low",
    });

    const b64 = result.data?.[0]?.b64_json;
    if (!b64) throw new Error("No b64_json returned");

    const fullBytes = Buffer.from(b64, "base64");

    // 3) 썸네일 생성(예: 512)
    const thumbBytes = await sharp(fullBytes).resize(512, 512, { fit: "cover" }).jpeg({ quality: 82 }).toBuffer();
    const fullJpg = await sharp(fullBytes).jpeg({ quality: 88 }).toBuffer();

    // 4) Storage 업로드 + download token URL 만들기
    const bucket = admin.storage().bucket();
    const token = randomUUID();

    const fullPath = `ai_food/${menuKey}/full.jpg`;
    const thumbPath = `ai_food/${menuKey}/thumb.jpg`;

    await bucket.file(fullPath).save(fullJpg, {
      contentType: "image/jpeg",
      metadata: {
        cacheControl: "public, max-age=31536000",
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });

    await bucket.file(thumbPath).save(thumbBytes, {
      contentType: "image/jpeg",
      metadata: {
        cacheControl: "public, max-age=31536000",
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });

    const enc = encodeURIComponent;
    const baseUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/`;
    const fullUrl = `${baseUrl}${enc(fullPath)}?alt=media&token=${token}`;
    const thumbUrl = `${baseUrl}${enc(thumbPath)}?alt=media&token=${token}`;

    // 5) Firestore 업데이트
    await docRef.set(
      {
        status: "ready",
        full_url: fullUrl,
        thumb_url: thumbUrl,
        model: "gpt-image-1-mini",
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 6) searched menu 문서에도 URL 넣기(요구사항)
    if (searchedMenuDocId && typeof searchedMenuDocId === "string") {
      await admin.firestore().collection("searched menu").doc(searchedMenuDocId).set(
        {
          menu_image_thumb_url: thumbUrl,
          menu_image_full_url: fullUrl,
          menu_image_status: "ready",
          menu_key: menuKey,
        },
        { merge: true }
      );
    }

    return { status: "ready", thumb_url: thumbUrl, full_url: fullUrl };
  }
);
