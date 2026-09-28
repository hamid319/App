import sharp from "sharp";
import type { PipelineLimits } from "../domain/types.js";
import { PipelineError } from "../domain/errors.js";
import { sha256 } from "../domain/validation.js";

export interface ProcessedImage {
  bytes: Buffer;
  width: number;
  height: number;
  sha256: string;
}

export async function processImage(
  source: Buffer,
  limits: PipelineLimits,
): Promise<ProcessedImage> {
  if (source.length === 0 || source.length > limits.maxImageBytes) {
    throw new PipelineError("source-image-size", "Invalid source image size");
  }
  const input = sharp(source, { limitInputPixels: 50_000_000, failOn: "warning" });
  const metadata = await input.metadata();
  const width = metadata.width ?? 0;
  const height = metadata.height ?? 0;
  const longEdge = Math.max(width, height);
  const shortEdge = Math.min(width, height);
  if (longEdge < limits.minLongEdge || shortEdge < limits.minShortEdge) {
    throw new PipelineError("source-resolution", "Source image resolution is too small");
  }
  const output = await input
    .rotate()
    .resize({ width: limits.maxOutputLongEdge, height: limits.maxOutputLongEdge, fit: "inside", withoutEnlargement: true })
    .webp({ quality: 82, effort: 4 })
    .toBuffer({ resolveWithObject: true });
  if (!output.info.width || !output.info.height) {
    throw new PipelineError("image-processing", "Processed image has invalid dimensions");
  }
  return {
    bytes: output.data,
    width: output.info.width,
    height: output.info.height,
    sha256: sha256(output.data),
  };
}

