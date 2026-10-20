import { describe, expect, it } from "vitest";
import { collectCity, type CollectSource } from "../src/collect.js";
import type { CityCollection, CityDoc, PlaceDoc } from "../src/model.js";
import { publishCity } from "../src/publish.js";
import { renderReport } from "../src/report.js";
import type { DataStore, PhotoStore, StoredObjectInfo } from "../src/stores.js";
import type { Candidate, PhotoMetadata } from "../src/wikimedia.js";

const city = { id: "pt_lisbon", wikidataId: "Q597", nameEn: "Lisbon", nameDe: "Lissabon", countryCode: "PT", targetPlaces: 2 };

const candidate = (id: string, sitelinks: number, classQids: string[]): Candidate => ({
  wikidataId: id,
  coordinates: { lat: 38.7, lng: -9.1 },
  sitelinks,
  distanceKm: 1.234,
  classQids,
  p18Files: [`File:${id}.jpg`],
});

const photo = (title: string, pageId: number, overrides: Partial<PhotoMetadata> = {}): PhotoMetadata => ({
  fileTitle: title,
  pageId,
  thumbnailUrl: `https://upload.wikimedia.org/${pageId}.jpg`,
  width: 3000,
  height: 2000,
  mime: "image/jpeg",
  mediaType: "BITMAP",
  creator: "Jane Doe",
  licenseShortName: "CC BY 4.0",
  licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
  description: "",
  categories: [],
  ...overrides,
});

function fakeSource(): CollectSource {
  return {
    cityLocation: async () => ({ coordinates: { lat: 38.72, lng: -9.14 }, countryQid: "Q45" }),
    findCandidates: async () => [
      candidate("Q1", 90, ["Q33506"]),
      candidate("Q2", 80, ["Q22698"]),
      candidate("Q3", 70, ["Q2977"]),
      candidate("Q4", 60, ["Q16970"]),
    ],
    entityInfo: async (ids) =>
      new Map(ids.map((id) => [id, {
        labels: id === "Q3" ? {} : { en: `Place ${id}`, de: `Ort ${id}` },
        descriptions: { en: "museum in Lisbon" },
        wikipediaTitles: { en: `Place_${id}`, de: `Ort_${id}` },
      }])),
    photoFiles: async (round) => new Map(round.map((c) => [c.wikidataId, [...c.p18Files, `File:${c.wikidataId}-b.jpg`]])),
    photoMetadata: async (titles) =>
      new Map(titles.map((t, i) => [t, t.startsWith("File:Q2") ? photo(t, 100 + i, { width: 400 }) : photo(t, 100 + i)])),
    wikipediaSummary: async (lang, title) => ({ text: `${lang} text for ${title}.`, url: `https://${lang}.wikipedia.org/wiki/${title}` }),
  };
}

describe("collectCity", () => {
  it("keeps named places with usable photos up to the target, best-known first", async () => {
    const collection = await collectCity(city, fakeSource());
    expect(collection.places.map((p) => p.wikidataId)).toEqual(["Q1", "Q4"]);
    expect(collection.skipped).toEqual([
      { wikidataId: "Q3", name: "Q3", reason: "no name" },
      { wikidataId: "Q2", name: "Place Q2", reason: "no usable photo" },
    ]);
    const first = collection.places[0];
    expect(first).toMatchObject({
      id: "wd_Q1",
      cityId: "pt_lisbon",
      names: { en: "Place Q1", de: "Ort Q1" },
      descriptions: { en: "en text for Place_Q1.", de: "de text for Ort_Q1." },
      types: ["museum"],
      interests: ["culture"],
      popularity: 90,
      distanceKm: 1.2,
    });
    expect(first.photos).toHaveLength(2);
    expect(collection.places[1].interests).toEqual(["history"]);
  });
});

class FakePhotos implements PhotoStore {
  objects = new Map<string, StoredObjectInfo>();
  puts = 0;
  async head(key: string) {
    return this.objects.get(key) ?? null;
  }
  async put(key: string, _bytes: Buffer, info: StoredObjectInfo) {
    this.puts += 1;
    this.objects.set(key, info);
  }
  publicUrl(key: string) {
    return `https://img.test/${key}`;
  }
}

class FakeData implements DataStore {
  places = new Map<string, PlaceDoc>();
  cities = new Map<string, CityDoc>();
  async existingPlaces(cityId: string) {
    return new Map([...this.places.values()].filter((p) => p.cityId === cityId).map((p) => [p.id, p.status]));
  }
  async writePlaces(places: PlaceDoc[]) {
    for (const p of places) this.places.set(p.id, p);
  }
  async hidePlaces(ids: string[]) {
    for (const id of ids) this.places.set(id, { ...this.places.get(id)!, status: "hidden" });
  }
  async writeCity(c: CityDoc) {
    this.cities.set(c.id, c);
  }
  async writeRun() {}
}

describe("publishCity", () => {
  const deps = (photos: FakePhotos, data: FakeData) => ({
    photos,
    data,
    download: async () => Buffer.from("jpeg"),
    convert: async () => ({ bytes: Buffer.from("webp"), width: 1280, height: 853, sha256: "abc" }),
    now: () => new Date("2026-10-21T10:00:00Z"),
  });

  it("uploads photos once, writes places and the city, and is safe to rerun", async () => {
    const collection = await collectCity(city, fakeSource());
    const photos = new FakePhotos();
    const data = new FakeData();

    const first = await publishCity(collection, new Set(), "run1", deps(photos, data));
    expect(first).toMatchObject({ published: 2, hidden: 0, photosUploaded: 4, photosReused: 0 });
    const doc = data.places.get("wd_Q1")!;
    expect(doc).toMatchObject({
      source: "wikidata",
      cityId: "pt_lisbon",
      status: "active",
      name: "Place Q1",
      description: "en text for Place_Q1.",
      imageUrls: ["https://img.test/places/pt_lisbon/wd_Q1/100.webp", "https://img.test/places/pt_lisbon/wd_Q1/101.webp"],
    });
    expect(doc.photos[0]).toMatchObject({ creator: "Jane Doe", licenseName: "CC BY 4.0", width: 1280 });
    expect(data.cities.get("pt_lisbon")).toMatchObject({ placeCount: 2, nameDe: "Lissabon" });

    const again = await publishCity(collection, new Set(), "run2", deps(photos, data));
    expect(again).toMatchObject({ published: 2, photosUploaded: 0, photosReused: 4 });
    expect(photos.puts).toBe(4);
  });

  it("hides excluded and dropped places instead of deleting them", async () => {
    const collection = await collectCity(city, fakeSource());
    const photos = new FakePhotos();
    const data = new FakeData();
    await publishCity(collection, new Set(), "run1", deps(photos, data));

    const result = await publishCity(collection, new Set(["Q4"]), "run2", deps(photos, data));
    expect(result).toMatchObject({ published: 1, hidden: 1 });
    expect(data.places.get("wd_Q4")?.status).toBe("hidden");
    expect(data.places.get("wd_Q1")?.status).toBe("active");
  });

  it("skips a place whose photos all fail", async () => {
    const collection = await collectCity(city, fakeSource());
    const data = new FakeData();
    const result = await publishCity(collection, new Set(), "run1", {
      ...deps(new FakePhotos(), data),
      download: async () => {
        throw new Error("404");
      },
    });
    expect(result).toMatchObject({ published: 0, placesWithoutPhotos: 2 });
  });
});

describe("renderReport", () => {
  it("escapes text from the sources and marks excluded places", async () => {
    const collection: CityCollection = await collectCity(city, fakeSource());
    collection.places[0].names.de = '<script>alert("x")</script>';
    const html = renderReport([collection], { pt_lisbon: ["Q4"] });
    expect(html).not.toContain("<script>alert");
    expect(html).toContain("&lt;script&gt;");
    expect(html).toContain('class="card excluded"');
  });
});
