import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { INTEREST_TYPES } from "../src/config.js";
import { isUsablePhoto, choosePhotos } from "../src/collect.js";
import { normalizeLicense } from "../src/licenses.js";
import { appTypesFor, interestsFor } from "../src/mapping.js";
import { shortenText } from "../src/wikimedia.js";
import type { PhotoMetadata } from "../src/wikimedia.js";

describe("licences", () => {
  it("accepts CC BY / BY-SA of any version, CC0 and public domain", () => {
    expect(normalizeLicense("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0")?.name).toBe("CC BY-SA 3.0");
    expect(normalizeLicense("CC BY 2.0", "//creativecommons.org/licenses/by/2.0/")?.url).toBe(
      "https://creativecommons.org/licenses/by/2.0/",
    );
    expect(normalizeLicense("CC BY-SA 3.0 de", "")?.name).toBe("CC BY-SA 3.0 DE");
    expect(normalizeLicense("CC0", "")?.name).toBe("CC0");
    expect(normalizeLicense("Public domain", "")?.name).toBe("Public domain");
  });

  it("rejects non-commercial, no-derivatives and unknown licences", () => {
    expect(normalizeLicense("CC BY-NC-SA 4.0", "")).toBeNull();
    expect(normalizeLicense("CC BY-ND 4.0", "")).toBeNull();
    expect(normalizeLicense("GFDL", "")).toBeNull();
    expect(normalizeLicense("", "")).toBeNull();
  });

  it("drops licence URLs that are not creativecommons.org", () => {
    expect(normalizeLicense("CC BY 4.0", "https://evil.example/by/4.0")?.url).toBeUndefined();
  });
});

describe("type and interest mapping", () => {
  it("maps Wikidata classes to app types and interests", () => {
    const types = appTypesFor(["Q33506", "Q22698", "Q2977"]);
    expect(types).toEqual(["museum", "church", "park"]);
    expect(interestsFor(types)).toEqual(["culture", "nature", "history"]);
  });

  it("stays in sync with the Interest enum of the app", () => {
    const dart = readFileSync(new URL("../../../lib/common/models/interest.dart", import.meta.url), "utf8");
    for (const [interest, types] of Object.entries(INTEREST_TYPES)) {
      const block = dart.match(new RegExp(`\\b${interest}\\(\\{([^}]*)\\}\\)`))?.[1];
      expect(block, `interest ${interest} missing in interest.dart`).toBeDefined();
      const dartTypes = [...block!.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]);
      expect(dartTypes.sort()).toEqual([...types].sort());
    }
  });
});

const meta = (overrides: Partial<PhotoMetadata> = {}): PhotoMetadata => ({
  fileTitle: "File:Belem Tower.jpg",
  pageId: 1,
  thumbnailUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Belem.jpg/1280px-Belem.jpg",
  width: 4000,
  height: 3000,
  mime: "image/jpeg",
  mediaType: "BITMAP",
  creator: "Jane Doe",
  licenseShortName: "CC BY-SA 4.0",
  licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
  description: "The tower at sunset",
  categories: ["Category:Belém Tower"],
  ...overrides,
});

describe("photo selection", () => {
  it("accepts a large, credited, freely licensed photo from either media host", () => {
    expect(isUsablePhoto(meta())).toBe(true);
    expect(isUsablePhoto(meta({ thumbnailUrl: "https://thumb.wikimedia.org/x.jpg" }))).toBe(true);
  });

  it("rejects small files, maps, drawings, missing authors and foreign hosts", () => {
    expect(isUsablePhoto(meta({ width: 640, height: 480 }))).toBe(false);
    expect(isUsablePhoto(meta({ fileTitle: "File:Lisbon locator map.png", mime: "image/png" }))).toBe(false);
    expect(isUsablePhoto(meta({ categories: ["Category:Engravings of Lisbon"] }))).toBe(false);
    expect(isUsablePhoto(meta({ creator: "" }))).toBe(false);
    expect(isUsablePhoto(meta({ creator: "", licenseShortName: "Public domain" }))).toBe(true);
    expect(isUsablePhoto(meta({ thumbnailUrl: "https://example.com/x.jpg" }))).toBe(false);
    expect(isUsablePhoto(meta({ mime: "image/svg+xml" }))).toBe(false);
  });

  it("takes at most three photos and never reuses a file in the same city", () => {
    const all = new Map(
      [1, 2, 3, 4].map((id) => [`File:${id}.jpg`, meta({ fileTitle: `File:${id}.jpg`, pageId: id })]),
    );
    const used = new Set<number>([2]);
    const chosen = choosePhotos([...all.keys()], all, used);
    expect(chosen.map((p) => p.pageId)).toEqual([1, 3, 4]);
    expect(chosen[0].filePageUrl).toBe("https://commons.wikimedia.org/wiki/File%3A1.jpg");
    expect(used).toEqual(new Set([1, 2, 3, 4]));
  });
});

describe("description text", () => {
  it("keeps whole sentences within the limit", () => {
    const text = "First sentence here. Second sentence is longer than the first one. Third.";
    expect(shortenText(text, 30)).toBe("First sentence here.");
    expect(shortenText(text, 500)).toBe(text);
  });

  it("cuts at a word boundary when the first sentence is too long", () => {
    expect(shortenText("A very long first sentence without any break", 20)).toBe("A very long first…");
  });
});
