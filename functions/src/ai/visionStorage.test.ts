import assert from "node:assert/strict";
import {
  cleanupTempUploads,
  normalizeStoragePaths,
  readVisionStorageImages,
  VisionStorageBucket,
  VisionStorageFile,
} from "./visionStorage";

const paths = [
  "temp_scan/uid-123/scan-abc/1.jpg",
  "temp_scan/uid-123/scan-abc/2.jpg",
  "temp_scan/uid-123/scan-abc/3.jpg",
  "temp_scan/uid-123/scan-abc/4.jpg",
];

assert.deepEqual(
  normalizeStoragePaths(paths, "uid-123", 4),
  paths,
);
assert.throws(
  () => normalizeStoragePaths(paths.slice(0, 2), "uid-123", 3),
  /sourceImageCount/,
);
assert.throws(
  () => normalizeStoragePaths(["other/uid-123/scan-abc/1.jpg", "other/uid-123/scan-abc/2.jpg"], "uid-123", 2),
  /temp_scan/,
);
assert.throws(
  () => normalizeStoragePaths([
    "temp_scan/other-user/scan-abc/1.jpg",
    "temp_scan/other-user/scan-abc/2.jpg",
  ], "uid-123", 2),
  /authenticated user/,
);
assert.throws(
  () => normalizeStoragePaths([], "uid-123", 2),
  /non-empty/,
);
assert.throws(
  () => normalizeStoragePaths(["temp_scan/uid-123/scan-abc/2.jpg", "temp_scan/uid-123/scan-abc/1.jpg"], "uid-123", 2),
  /source image order/,
);

class FakeFile implements VisionStorageFile {
  constructor(
    private readonly bytes: Buffer,
    private readonly failDelete = false,
  ) {}

  async download(): Promise<[Buffer]> {
    return [this.bytes];
  }

  async delete(): Promise<void> {
    if (this.failDelete) throw new Error("delete failed");
  }
}

class FakeBucket implements VisionStorageBucket {
  readonly files = new Map<string, FakeFile>();

  file(path: string): VisionStorageFile {
    const file = this.files.get(path);
    if (!file) throw new Error("missing fake file");
    return file;
  }
}

async function runStorageTests(): Promise<void> {
  const bucket = new FakeBucket();
  bucket.files.set(paths[0], new FakeFile(Buffer.from("first")));
  bucket.files.set(paths[1], new FakeFile(Buffer.from("second")));
  const read = await readVisionStorageImages(paths.slice(0, 2), bucket);
  assert.deepEqual(read.imagesBase64, [
    Buffer.from("first").toString("base64"),
    Buffer.from("second").toString("base64"),
  ]);
  assert.equal(read.totalBytes, 11);

  bucket.files.set(paths[2], new FakeFile(Buffer.from("third"), true));
  const cleanup = await cleanupTempUploads(paths.slice(0, 3), bucket);
  assert.equal(cleanup.attempted, 3);
  assert.equal(cleanup.deleted, 2);
  assert.equal(cleanup.warnings.length, 1);

  console.log("visionStorage tests passed");
}

runStorageTests().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
