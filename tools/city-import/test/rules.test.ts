import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { INTEREST_TYPES } from "../src/config.js";
import { isUsablePhoto, choosePhotos } from "../src/collect.js";
import { normalizeLicense } from "../src/licenses.js";
import { CATEGORY_TYPES } from "../src/config.js";
import { interestsFor, typesFor } from "../src/mapping.js";
import { catalogNameVariants, matchAttraction, nameScore, normalizeName } from "../src/match.js";
import { osmAddress, osmCommonsFile } from "../src/osm.js";
import type { OsmPlace } from "../src/osm.js";
import { shortenText, splitSentences, stripPronunciation } from "../src/wikimedia.js";
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
  it("maps catalog categories and OSM tags to app types and interests", () => {
    expect(typesFor("Museum")).toEqual(["museum"]);
    expect(typesFor("Park", { tourism: "zoo" })).toEqual(["park", "zoo"]);
    expect(typesFor("Something new")).toEqual(["tourist_attraction"]);
    expect(interestsFor(typesFor("Religious Site"))).toEqual(["history"]);
    expect(interestsFor(["museum", "park"])).toEqual(["culture", "nature"]);
  });

  it("covers every category used in the catalog", () => {
    const catalog = JSON.parse(readFileSync(new URL("../catalog.json", import.meta.url), "utf8")) as {
      cities: Array<{ attractions: Array<{ category: string }> }>;
    };
    const used = new Set(catalog.cities.flatMap((c) => c.attractions.map((a) => a.category)));
    expect([...used].filter((c) => !(c in CATEGORY_TYPES))).toEqual([]);
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

  it("keeps up to ten candidates, files used earlier in the city last", () => {
    const all = new Map(
      Array.from({ length: 12 }, (_, i) => i + 1)
        .map((id) => [`File:${id}.jpg`, meta({ fileTitle: `File:${id}.jpg`, pageId: id })]),
    );
    const used = new Set<number>([2]);
    const chosen = choosePhotos([...all.keys()], all, used);
    expect(chosen.map((p) => p.pageId)).toEqual([1, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    expect(chosen[0].filePageUrl).toBe("https://commons.wikimedia.org/wiki/File%3A1.jpg");
    // Only the default selection (first three) is reserved for this place.
    expect(used).toEqual(new Set([1, 2, 3, 4]));

    const few = choosePhotos(["File:2.jpg", "File:12.jpg"], all, used);
    expect(few.map((p) => p.pageId)).toEqual([12, 2]);
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

  it("does not end sentences at ordinals, Roman numerals or abbreviations", () => {
    const text = "Die Schule entstand im 19. Jahrhundert unter Karl IV. als Neubau. Sie liegt z. B. am 29. Mai offen. Danach folgt viel mehr Text.";
    expect(shortenText(text, 100)).toBe("Die Schule entstand im 19. Jahrhundert unter Karl IV. als Neubau. Sie liegt z. B. am 29. Mai offen.");
    expect(shortenText("Built in 1755. Rebuilt later by St. John and others in the next years.", 30)).toBe("Built in 1755.");
  });

  it("keeps closing quotes with their sentence", () => {
    expect(splitSentences('Er hieß „der Pate.“ Danach kam mehr.')).toEqual({
      sentences: ["Er hieß „der Pate.“", " Danach kam mehr."],
      rest: "",
    });
  });

  it("removes pronunciations in brackets and the punctuation they leave", () => {
    expect(stripPronunciation("Der Parque das Nações [ˈpaɾkɯ dɐʃ nɐˈsõĩʃ], zu deutsch Park der Nationen."))
      .toBe("Der Parque das Nações, zu deutsch Park der Nationen.");
    expect(stripPronunciation("Der Rossio, [ʀu'siw], offiziell Praça de D. Pedro IV, ['prasɐ də dõ], ist ein Platz."))
      .toBe("Der Rossio, offiziell Praça de D. Pedro IV, ist ein Platz.");
    expect(stripPronunciation("Der Louvre [ˈluːvrə] , ist ein Museum.")).toBe("Der Louvre, ist ein Museum.");
    // Brackets without IPA and Danish letters stay.
    expect(stripPronunciation("Im Stadtteil Nørrebro [Kopenhagen] liegt der Park."))
      .toBe("Im Stadtteil Nørrebro [Kopenhagen] liegt der Park.");
  });
});

const osm = (name: string, tags: Record<string, string> = {}, lat = 38.7, lng = -9.14): OsmPlace => ({
  type: "way",
  id: Math.floor(Math.random() * 1e6),
  coordinates: { lat, lng },
  tags: { name, ...tags },
});

describe("name matching", () => {
  it("normalises accents, case and punctuation", () => {
    expect(normalizeName("Praça do Comércio")).toBe("praca do comercio");
    expect(normalizeName("St. Paul's Cathedral")).toBe("st pauls cathedral");
    expect(normalizeName("Straße")).toBe("strasse");
  });

  it("splits catalog names into their variants", () => {
    expect(catalogNameVariants("Grüngürtel (Cologne Green Belt)")).toEqual([
      "grungurtel cologne green belt",
      "grungurtel",
      "cologne green belt",
    ]);
  });

  it("accepts a longer name only when the extra words name the kind of place", () => {
    expect(nameScore("sagrada familia", "basilica de la sagrada familia")).toBeGreaterThanOrEqual(0.85);
    expect(nameScore("parque das nacoes", "teleferico do parque das nacoes")).toBeLessThan(0.85);
    expect(nameScore("alfama", "alfama")).toBe(1);
  });

  it("finds the place by its English or local name and prefers the one with Wikidata", () => {
    const center = { lat: 38.72, lng: -9.14 };
    const places = [
      osm("Torre de Belém", { "name:en": "Belém Tower" }),
      osm("Torre de Belém", { "name:en": "Belém Tower", wikidata: "Q215003", tourism: "attraction" }),
      osm("Teleférico do Parque das Nações"),
    ];
    expect(matchAttraction("Belém Tower (Torre de Belém)", places, center)?.place.tags.wikidata).toBe("Q215003");
    expect(matchAttraction("Parque das Nações", places, center)).toBeNull();
  });
});

describe("OSM tags", () => {
  it("builds an address", () => {
    expect(osmAddress({ "addr:street": "Rua Augusta", "addr:housenumber": "24", "addr:postcode": "1100-053", "addr:city": "Lisboa" }))
      .toBe("Rua Augusta 24, 1100-053 Lisboa");
    expect(osmAddress({})).toBeNull();
  });

  it("reads Commons files from wikimedia_commons and image tags", () => {
    expect(osmCommonsFile({ wikimedia_commons: "File:Belem_Tower.jpg" })).toBe("File:Belem Tower.jpg");
    expect(osmCommonsFile({ image: "https://commons.wikimedia.org/wiki/File:Torre_de_Bel%C3%A9m.jpg" })).toBe("File:Torre de Belém.jpg");
    expect(osmCommonsFile({ wikimedia_commons: "Category:Belém Tower" })).toBeNull();
  });
});

describe("request batching", () => {
  it("splits long titles so URLs stay short", async () => {
    const { urlSafeBatches } = await import("../src/wikimedia.js");
    const thai = Array.from({ length: 30 }, (_, i) => `File:วัดพระศรีรัตนศาสดาราม ${i}.jpg`);
    const batches = urlSafeBatches(thai, 50, 2000);
    expect(batches.length).toBeGreaterThan(1);
    expect(batches.flat()).toEqual(thai);
    for (const b of batches) expect(encodeURIComponent(b.join("|")).length).toBeLessThan(2100);
    expect(urlSafeBatches(["a", "b", "c"], 2, 1000)).toEqual([["a", "b"], ["c"]]);
  });
});
