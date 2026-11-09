import { createHash } from "node:crypto";
import sharp from "sharp";
import { DEFAULTS } from "./config.js";

export interface ProcessedImage {
  bytes: Buffer;
  width: number;
  height: number;
  sha256: string;
}

/** Auto-rotate, shrink to at most 1080 px on the long edge, encode as WebP. */
export async function toWebp(source: Buffer): Promise<ProcessedImage> {
  const output = await sharp(source, { limitInputPixels: 60_000_000 })
    .rotate()
    .resize({
      width: DEFAULTS.storedLongEdge,
      height: DEFAULTS.storedLongEdge,
      fit: "inside",
      withoutEnlargement: true,
    })
    .webp({ quality: DEFAULTS.webpQuality, effort: 4 })
    .toBuffer({ resolveWithObject: true });
  return {
    bytes: output.data,
    width: output.info.width,
    height: output.info.height,
    sha256: createHash("sha256").update(output.data).digest("hex"),
  };
}
