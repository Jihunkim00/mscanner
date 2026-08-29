import assert from "node:assert/strict";
import {
  buildVisionImageContent,
  normalizeVisionImages,
  MAX_MULTI_IMAGE_COUNT,
} from "./visionRequest";

const imagesBase64 = ["image-1", "image-2", "image-3", "image-4"];
const normalized = normalizeVisionImages({
  imagesBase64,
  sourceImageCount: 4,
}, "multi");
assert.deepEqual(normalized.imagesBase64, imagesBase64);
assert.equal(normalized.inputImageCount, 4);
assert.equal(normalized.legacySingleImage, false);
const content = buildVisionImageContent("prompt", imagesBase64);
assert.equal(content.length, 5);
assert.equal(content[0].type, "text");
assert.deepEqual(
  content.slice(1).map((part) => (part.image_url as {url: string}).url),
  imagesBase64.map((image) => "data:image/jpeg;base64," + image),
);
assert.throws(
  () => normalizeVisionImages({imagesBase64, sourceImageCount: 3}, "multi"),
  /sourceImageCount must match/
);
const legacy = normalizeVisionImages({
  imageBase64: "legacy-image",
  sourceImageCount: 4,
}, "multi");
assert.equal(legacy.inputImageCount, 1);
assert.equal(legacy.sourceImageCount, 4);
assert.equal(legacy.legacySingleImage, true);
assert.equal(MAX_MULTI_IMAGE_COUNT, 4);
console.log("visionRequest tests passed");
