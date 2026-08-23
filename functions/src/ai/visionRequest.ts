export const MAX_MULTI_IMAGE_COUNT = 4;

export interface NormalizedVisionImages {
  imagesBase64: string[];
  inputImageCount: number;
  sourceImageCount: number | null;
  legacySingleImage: boolean;
}

type RequestData = Record<string, unknown>;

function normalizeSourceImageCount(value: unknown): number | null {
  if (typeof value !== "number" ||
      !Number.isInteger(value) ||
      value < 1 ||
      value > MAX_MULTI_IMAGE_COUNT) {
    return null;
  }
  return value;
}

export function normalizeVisionImages(
  data: RequestData,
  scanMode: "single" | "multi"
): NormalizedVisionImages {
  const rawImagesBase64 = data.imagesBase64;
  const sourceImageCount = normalizeSourceImageCount(data.sourceImageCount);

  if (rawImagesBase64 !== undefined) {
    if (scanMode !== "multi" || !Array.isArray(rawImagesBase64)) {
      throw new Error("imagesBase64 is only valid for multi scans");
    }
    if (rawImagesBase64.length === 0 ||
        rawImagesBase64.length > MAX_MULTI_IMAGE_COUNT) {
      throw new Error("imagesBase64 count is out of range");
    }

    const imagesBase64 = rawImagesBase64.map((value) => {
      if (typeof value !== "string" || value.trim().length === 0) {
        throw new Error("imagesBase64 must contain non-empty strings");
      }
      return value;
    });

    if (sourceImageCount !== imagesBase64.length) {
      throw new Error("sourceImageCount must match imagesBase64 length");
    }

    return {
      imagesBase64,
      inputImageCount: imagesBase64.length,
      sourceImageCount,
      legacySingleImage: false,
    };
  }

  const imageBase64 = data.imageBase64;
  if (typeof imageBase64 !== "string" || imageBase64.trim().length === 0) {
    throw new Error("imageBase64 required");
  }

  return {
    imagesBase64: [imageBase64],
    inputImageCount: 1,
    sourceImageCount: sourceImageCount ?? 1,
    legacySingleImage: scanMode === "multi",
  };
}

export function buildVisionImageContent(
  prompt: string,
  imagesBase64: string[]
): Array<Record<string, unknown>> {
  return [
    {type: "text", text: prompt},
    ...imagesBase64.map((imageBase64) => ({
      type: "image_url",
      image_url: {url: "data:image/jpeg;base64," + imageBase64},
    })),
  ];
}
