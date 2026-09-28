import { describe, expect, it } from "vitest";
import {
  assertSafeWikimediaUrl,
  deterministicDescription,
  isKnownNonPhoto,
  normalizeLicense,
  normalizeQid,
} from "../src/domain/validation.js";
import type { AttractionCandidate, CommonsPhotoMetadata } from "../src/domain/types.js";

describe("pipeline validation", () => {
  it("normalizes only Wikidata QIDs", () => {
    expect(normalizeQid(" q1055 ")).toBe("Q1055");
    expect(() => normalizeQid("Hamburg")).toThrow();
    expect(() => normalizeQid("Q0")).toThrow();
  });

  it("accepts only exact matching v1 license names and URLs", () => {
    expect(normalizeLicense("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/")?.name).toBe("CC-BY-4.0");
    expect(normalizeLicense("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/")?.name).toBe("CC-BY-SA-4.0");
    expect(normalizeLicense("CC0", "https://creativecommons.org/publicdomain/zero/1.0/")?.name).toBe("CC0-1.0");
    expect(normalizeLicense("Public domain", "")).toBeNull();
    expect(normalizeLicense("CC BY 4.0", "https://evilcreativecommons.org/licenses/by/4.0/")).toBeNull();
    expect(normalizeLicense("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0/")).toBeNull();
    expect(normalizeLicense("CC BY 4.0", "https://creativecommons.org/licenses/by-sa/4.0/")).toBeNull();
  });

  it("rejects SSRF-shaped URLs", () => {
    expect(assertSafeWikimediaUrl("https://upload.wikimedia.org/a.jpg").hostname).toBe("upload.wikimedia.org");
    expect(assertSafeWikimediaUrl("https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a.jpg/800px-a.jpg").hostname).toBe("thumb.wikimedia.org");
    for (const url of ["http://upload.wikimedia.org/a.jpg", "https://user@upload.wikimedia.org/a.jpg", "https://upload.wikimedia.org.evil.test/a.jpg", "https://127.0.0.1/a.jpg"]) {
      expect(() => assertSafeWikimediaUrl(url)).toThrow();
    }
  });

  it("rejects known maps and plans without rejecting plants or planetariums", () => {
    expect(isKnownNonPhoto(photo("File:City map.jpg"))).toBe(true);
    expect(isKnownNonPhoto(photo("File:Architectural plan.png"))).toBe(true);
    expect(isKnownNonPhoto(photo("File:Planetarium and plant garden.jpg"))).toBe(false);
  });

  it("uses factual source descriptions unchanged and a near-city fallback", () => {
    const candidate = attraction();
    expect(deterministicDescription({ ...candidate, wikidataDescription: "art museum in Germany" }, "Hamburg", "Germany")).toBe("Art museum in Germany.");
    expect(deterministicDescription(candidate, "Hamburg", "Germany")).toBe("Place Q1 is a museum near Hamburg, Germany.");
  });
});

function attraction(): AttractionCandidate {
  return { rank: 0, qid: "Q1", name: "Place Q1", coordinates: { latitude: 1, longitude: 2 }, countryQid: "Q183", types: ["Q33506"], typeLabels: ["museum"], sitelinks: 1, distanceKm: 1, p18Files: [], sourceRevisionId: 1, sourceRevisionTimestamp: "2026-01-01T00:00:00Z" };
}

function photo(fileTitle: string): CommonsPhotoMetadata {
  return { fileTitle, pageId: 1, sourceSha1: "abc", originalUrl: "https://upload.wikimedia.org/a.jpg", thumbnailUrl: "https://upload.wikimedia.org/a.jpg", mime: "image/jpeg", mediaType: "BITMAP", width: 1000, height: 800, revisionId: 2, revisionTimestamp: "2026-01-01T00:00:00Z", creator: "Creator", credit: "Creator", licenseShortName: "CC BY 4.0", licenseUrl: "https://creativecommons.org/licenses/by/4.0/", categories: [] };
}
