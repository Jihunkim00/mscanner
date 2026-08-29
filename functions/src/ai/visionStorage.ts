import * as admin from "firebase-admin";

export const MAX_TEMP_IMAGE_COUNT = 4;
export const MIN_TEMP_IMAGE_COUNT = 2;

export interface VisionStorageFile {
  download(): Promise<[Buffer]>;
  delete(): Promise<unknown>;
}

export interface VisionStorageBucket {
  file(path: string): VisionStorageFile;
}

export interface ReadVisionStorageImagesResult {
  imagesBase64: string[];
  totalBytes: number;
}

export interface CleanupTempUploadsResult {
  attempted: number;
  deleted: number;
  warnings: string[];
}

type StoragePathParts = {
  scanId: string;
  sourceImageIndex: number;
};

const SAFE_PATH_SEGMENT = /^[A-Za-z0-9._:-]{1,64}$/;

function isSafePathSegment(value: string): boolean {
  return value !== "." && value !== ".." && SAFE_PATH_SEGMENT.test(value);
}

function defaultBucket(): VisionStorageBucket {
  return admin.storage().bucket() as unknown as VisionStorageBucket;
}

function normalizeSourceImageCount(value: unknown): number {
  if (typeof value !== "number" ||
      !Number.isInteger(value) ||
      value < MIN_TEMP_IMAGE_COUNT ||
      value > MAX_TEMP_IMAGE_COUNT) {
    throw new Error(
      "sourceImageCount must be between " + MIN_TEMP_IMAGE_COUNT +
      " and " + MAX_TEMP_IMAGE_COUNT,
    );
  }
  return value;
}

function parseStoragePath(path: string): StoragePathParts {
  const segments = path.split("/");
  if (segments.length !== 4 || segments[0] !== "temp_scan") {
    throw new Error("storage path must use temp_scan prefix");
  }
  if (!isSafePathSegment(segments[1]) ||
      !isSafePathSegment(segments[2])) {
    throw new Error("invalid temp storage path format");
  }

  const fileName = segments[3];
  const lowerFileName = fileName.toLowerCase();
  const extension = lowerFileName.endsWith(".jpeg") ? ".jpeg" : ".jpg";
  if (!lowerFileName.endsWith(extension)) {
    throw new Error("temp storage path must use jpg or jpeg");
  }
  const indexText = fileName.slice(0, -extension.length);
  const sourceImageIndex = Number(indexText);
  if (!Number.isInteger(sourceImageIndex) ||
      sourceImageIndex < 1 ||
      sourceImageIndex > MAX_TEMP_IMAGE_COUNT ||
      String(sourceImageIndex) !== indexText) {
    throw new Error("invalid temp storage path image index");
  }
  return {scanId: segments[2], sourceImageIndex};
}

export function normalizeStoragePaths(
  value: unknown,
  uid: string,
  sourceImageCount: unknown
): string[] {
  const count = normalizeSourceImageCount(sourceImageCount);
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error("storagePaths must be a non-empty array");
  }
  if (value.length !== count) {
    throw new Error("storagePaths count must match sourceImageCount");
  }

  const paths: string[] = [];
  let scanId: string | null = null;
  for (let position = 0; position < value.length; position++) {
    const valueAtPosition = value[position];
    if (typeof valueAtPosition !== "string" || valueAtPosition.trim() === "") {
      throw new Error("storagePaths must contain non-empty strings");
    }
    const path = valueAtPosition.trim();
    const segments = path.split("/");
    if (segments[1] !== uid) {
      throw new Error("storage path does not belong to the authenticated user");
    }
    const parts = parseStoragePath(path);
    if (scanId === null) scanId = parts.scanId;
    if (parts.scanId !== scanId) {
      throw new Error("storagePaths must use one scan id");
    }
    if (parts.sourceImageIndex !== position + 1) {
      throw new Error("storagePaths must preserve source image order");
    }
    paths.push(path);
  }
  return paths;
}

export async function readVisionStorageImages(
  paths: string[],
  bucket: VisionStorageBucket = defaultBucket(),
): Promise<ReadVisionStorageImagesResult> {
  const imagesBase64: string[] = [];
  let totalBytes = 0;
  for (const path of paths) {
    const [buffer] = await bucket.file(path).download();
    totalBytes += buffer.length;
    imagesBase64.push(buffer.toString("base64"));
  }
  return {imagesBase64, totalBytes};
}

export async function cleanupTempUploads(
  paths: string[],
  bucket: VisionStorageBucket = defaultBucket(),
): Promise<CleanupTempUploadsResult> {
  const result: CleanupTempUploadsResult = {
    attempted: paths.length,
    deleted: 0,
    warnings: [],
  };
  for (const path of paths) {
    try {
      await bucket.file(path).delete();
      result.deleted++;
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      result.warnings.push(path + ": " + reason);
    }
  }
  return result;
}
