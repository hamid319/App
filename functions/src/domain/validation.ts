import { createHash } from "node:crypto";
import { PipelineError } from "./errors.js";
import type {
  AttractionCandidate,
  CommonsPhotoMetadata,
  Coordinates,
} from "./types.js";

const QID_PATTERN = /^Q[1-9][0-9]*$/;
const ALLOWED_MEDIA_HOSTS = new Set([
  "upload.wikimedia.org",
  "thumb.wikimedia.org",
  "commons.wikimedia.org",
]);
const NON_PHOTO_PATTERNS = [
  /\bmap\b/i,
  /\blocator(?: map)?\b/i,
  /\blogo\b/i,
  /\bflag\b/i,
  /\bcoat of arms\b/i,
  /\bdiagram\b/i,
  /\b(?:floor|site|route|architectural) plan\b/i,
  /\broute map\b/i,
];

export function normalizeQid(value: unknown): string {
  if (typeof value !== "string") {
    throw new PipelineError("invalid-argument", "cityQid must be a string");
  }
  const qid = value.trim().toUpperCase();
  if (!QID_PATTERN.test(qid)) {
    throw new PipelineError("invalid-argument", "cityQid must match Q[1-9][0-9]*");
  }
  return qid;
}

export function isQid(value: string): boolean {
  return QID_PATTERN.test(value);
}

export function assertCoordinates(value: Coordinates): void {
  if (
    !Number.isFinite(value.latitude) ||
    !Number.isFinite(value.longitude) ||
    value.latitude < -90 ||
    value.latitude > 90 ||
    value.longitude < -180 ||
    value.longitude > 180
  ) {
    throw new PipelineError("invalid-city-coordinates", "Invalid coordinates");
  }
}

export function assertEarthGlobe(globeQid: string | undefined): void {
  if (globeQid && globeQid !== "Q2") {
    throw new PipelineError("invalid-city-globe", "Coordinates are not on Earth");
  }
}

export function sanitizePlainText(value: string | undefined): string {
  if (!value) return "";
  return value
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, " ")
    .trim();
}

export function assertSafeWikimediaUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new PipelineError("unsafe-media-url", "Malformed media URL");
  }
  if (
    url.protocol !== "https:" ||
    !ALLOWED_MEDIA_HOSTS.has(url.hostname.toLowerCase()) ||
    (url.port !== "" && url.port !== "443") ||
    url.username !== "" ||
    url.password !== ""
  ) {
    throw new PipelineError("unsafe-media-url", "Media URL is not allowlisted");
  }
  return url;
}

export interface NormalizedLicense {
  name: "CC0-1.0" | "CC-BY-4.0" | "CC-BY-SA-4.0";
  url: string;
}

export function normalizeLicense(
  shortName: string,
  licenseUrl: string,
): NormalizedLicense | null {
  const name = sanitizePlainText(shortName).toLowerCase().replace(/_/g, " ").replace(/-/g, " ");
  let parsed: URL;
  try {
    parsed = new URL(licenseUrl.trim());
  } catch {
    return null;
  }
  if (parsed.protocol !== "https:" || parsed.hostname !== "creativecommons.org" || parsed.search || parsed.hash) {
    return null;
  }
  const path = parsed.pathname.replace(/\/$/, "").toLowerCase();
  if (path === "/publicdomain/zero/1.0" && /^cc0(?: 1\.0)?$/.test(name)) {
    return { name: "CC0-1.0", url: "https://creativecommons.org/publicdomain/zero/1.0/" };
  }
  if (path === "/licenses/by/4.0" && /^cc by 4\.0$/.test(name)) {
    return { name: "CC-BY-4.0", url: "https://creativecommons.org/licenses/by/4.0/" };
  }
  if (path === "/licenses/by-sa/4.0" && /^cc by sa 4\.0$/.test(name)) {
    return { name: "CC-BY-SA-4.0", url: "https://creativecommons.org/licenses/by-sa/4.0/" };
  }
  return null;
}

export function isKnownNonPhoto(metadata: CommonsPhotoMetadata): boolean {
  const haystack = [metadata.fileTitle, metadata.description, ...metadata.categories]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  return NON_PHOTO_PATTERNS.some((pattern) => pattern.test(haystack));
}

export function stablePlaceId(qid: string): string {
  if (!isQid(qid)) throw new PipelineError("invalid-place-qid", "Invalid place QID");
  return `wd_${qid}`;
}

export function sha256(buffer: Buffer): string {
  return createHash("sha256").update(buffer).digest("hex");
}

export function rankCandidates(
  candidates: AttractionCandidate[],
  typePriority: ReadonlyMap<string, number>,
): AttractionCandidate[] {
  const priority = (candidate: AttractionCandidate): number =>
    Math.min(
      ...candidate.types.map((type) => typePriority.get(type) ?? 999),
      999,
    );
  return [...candidates].sort((a, b) =>
    b.sitelinks - a.sitelinks ||
    Number(b.p18Files.length > 0) - Number(a.p18Files.length > 0) ||
    priority(a) - priority(b) ||
    a.distanceKm - b.distanceKm ||
    a.qid.localeCompare(b.qid, "en", { numeric: true }),
  );
}

export function deterministicDescription(
  candidate: AttractionCandidate,
  cityName: string,
  countryName: string,
): string {
  const sourceDescription = sanitizePlainText(candidate.wikidataDescription);
  if (sourceDescription) {
    const sentence = sourceDescription.replace(/[.!?]+$/, "");
    return `${sentence.charAt(0).toUpperCase()}${sentence.slice(1)}.`;
  }
  const label = sanitizePlainText(candidate.typeLabels[0]) || "attraction";
  return `${candidate.name} is a ${label.toLowerCase()} near ${cityName}, ${countryName}.`;
}
