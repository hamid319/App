import { describe, expect, it } from "vitest";
import { collectCity, type CollectSources } from "../src/collect.js";
import type { CatalogAttraction, CityCollection, CityDoc, PlaceDoc } from "../src/model.js";
import type { OsmPlace } from "../src/osm.js";
import { BudgetExceeded, UploadBudget } from "../src/budget.js";
import { publishCity } from "../src/publish.js";
import { selectPhotos } from "../src/picks.js";
import { renderReport } from "../src/report.js";
import { renderReviewPage } from "../src/review.js";
import type { DataStore, PhotoStore, StoredObjectInfo } from "../src/stores.js";
import type { PhotoMetadata } from "../src/wikimedia.js";

const city = {
  id: "pt_lisbon",
  catalogId: "lisbon",
  nameEn: "Lisbon",
  nameDe: "Lissabon",
  countryCode: "PT",
  lat: 38.7223,
  lng: -9.1393,
};

const seed = (number: number, name: string, category: string): CatalogAttraction => ({
  id: `lisbon-${number}`,
  number,
  name,
  category,
  description: `Catalog text for ${name}.`,
});

const catalog = [
  seed(5, "Miradouro Test", "Viewpoint"),
  seed(1, "Belém Tower (Torre de Belém)", "Historic Site"),
  seed(2, "Blurry Park", "Park"),
  seed(3, "Ghost Place", "Museum"),
  seed(4, "Pantheon (National Pantheon)", "Monument"),
];

const osmPlaces: OsmPlace[] = [
  {
    type: "way",
    id: 11,
    coordinates: { lat: 38.6916, lng: -9.216 },
    tags: {
      name: "Torre de Belém",
      "name:en": "Belém Tower",
      wikidata: "Q1",
      tourism: "attraction",
      opening_hours: "Tu-Su 10:00-18:00",
      "addr:street": "Avenida Brasília",
      "addr:city": "Lisboa",
      website: "https://torre.example",
    },
  },
  { type: "way", id: 12, coordinates: { lat: 38.73, lng: -9.15 }, tags: { name: "Blurry Park", leisure: "park", wikidata: "Q2" } },
  {
    type: "node",
    id: 15,
    coordinates: { lat: 38.715, lng: -9.13 },
    tags: {
      name: "Miradouro Test",
      tourism: "viewpoint",
      image: "https://commons.wikimedia.org/wiki/File:Mira.jpg",
      wikimedia_commons: "Category:Miradouro Test",
    },
  },
];

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

function fakeSources(): CollectSources {
  return {
    osmPlaces: async () => osmPlaces,
    wikimedia: {
      searchEntities: async (query) =>
        query === "Pantheon" ? ["Q9"] : query === "National Pantheon" ? ["Q4"] : [],
      entityInfo: async (ids) =>
        new Map(ids.map((id) => [id, {
          labels: { en: `Place ${id}`, de: `Ort ${id}` },
          descriptions: {},
          wikipediaTitles: { en: `Place_${id}`, de: `Ort_${id}` },
          imageFiles: [`File:${id}.jpg`],
          // Q9 is the Pantheon in Rome: found by the search, but too far away.
          coordinates: id === "Q9" ? { lat: 41.9, lng: 12.48 } : { lat: 38.7146, lng: -9.1249 },
        }])),
      photoFiles: async (lookups) =>
        new Map(lookups.map((l) => [l.wikidataId, [...l.knownFiles, `File:${l.wikidataId}-b.jpg`]])),
      categoryFiles: async (category) => (category === "Miradouro Test" ? ["File:Mira2.jpg"] : []),
      photoMetadata: async (titles) =>
        new Map(titles.map((t, i) => [t, t.startsWith("File:Q2") ? photo(t, 100 + i, { width: 400 }) : photo(t, 100 + i)])),
      wikipediaSummary: async (lang, title) => ({ text: `${lang} text for ${title}.`, url: `https://${lang}.wikipedia.org/wiki/${title}` }),
    },
  };
}

describe("collectCity", () => {
  it("places the catalog on the map, enriches it and reports what is missing", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    expect(collection.places.map((p) => p.id)).toEqual(["wd_Q1", "wd_Q4", "osm_node_15"]);
    expect(collection.osmMatched).toBe(3);
    expect(collection.skipped).toEqual([
      { rank: 2, name: "Blurry Park", reason: "no usable photo" },
      { rank: 3, name: "Ghost Place", reason: "not found on the map" },
    ]);

    const tower = collection.places[0];
    expect(tower).toMatchObject({
      rank: 1,
      catalogName: "Belém Tower (Torre de Belém)",
      names: { en: "Place Q1", de: "Ort Q1" },
      descriptions: { en: "en text for Place_Q1.", de: "de text for Ort_Q1." },
      address: "Avenida Brasília, Lisboa",
      openingHours: "Tu-Su 10:00-18:00",
      website: "https://torre.example/",
      osm: { type: "way", id: 11, url: "https://www.openstreetmap.org/way/11" },
      types: ["historical_landmark"],
      interests: ["history"],
      popularity: 999,
    });
    expect(tower.photos.map((p) => p.fileTitle)).toEqual(["File:Q1.jpg", "File:Q1-b.jpg"]);

    // Not on OSM: found by the variant "National Pantheon", not the far-away "Pantheon".
    expect(collection.places[1]).toMatchObject({ wikidataId: "Q4", rank: 4 });
    expect(collection.places[1].osm).toBeUndefined();

    // On OSM without Wikidata: photos from the image tag and the Commons category,
    // the catalog's own text as description.
    const viewpoint = collection.places[2];
    expect(viewpoint).toMatchObject({
      names: { en: "Miradouro Test" },
      descriptions: { en: "Catalog text for Miradouro Test." },
      types: ["viewpoint"],
      interests: ["views"],
    });
    expect(viewpoint.wikidataId).toBeUndefined();
    expect(viewpoint.photos.map((p) => p.fileTitle)).toEqual(["File:Mira.jpg", "File:Mira2.jpg"]);
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
    const collection = await collectCity(city, catalog, fakeSources());
    const photos = new FakePhotos();
    const data = new FakeData();

    const first = await publishCity(collection, new Set(), "run1", deps(photos, data));
    expect(first).toMatchObject({ published: 3, hidden: 0, photosUploaded: 6, photosReused: 0 });
    const doc = data.places.get("wd_Q1")!;
    expect(doc).toMatchObject({
      source: "wikidata",
      cityId: "pt_lisbon",
      status: "active",
      name: "Place Q1",
      description: "en text for Place_Q1.",
      sourceId: "Q1",
      address: "Avenida Brasília, Lisboa",
      openingHours: "Tu-Su 10:00-18:00",
      osmUrl: "https://www.openstreetmap.org/way/11",
      imageUrls: ["https://img.test/places/pt_lisbon/wd_Q1/100.webp", "https://img.test/places/pt_lisbon/wd_Q1/101.webp"],
    });
    expect(doc.photos[0]).toMatchObject({ creator: "Jane Doe", licenseName: "CC BY 4.0", width: 1280 });
    expect(data.cities.get("pt_lisbon")).toMatchObject({ placeCount: 3, nameDe: "Lissabon", lat: 38.7223 });
    expect(data.places.get("osm_node_15")).toMatchObject({ sourceId: "node/15", website: null });

    const again = await publishCity(collection, new Set(), "run2", deps(photos, data));
    expect(again).toMatchObject({ published: 3, photosUploaded: 0, photosReused: 6 });
    expect(photos.puts).toBe(6);
  });

  it("hides excluded and dropped places instead of deleting them", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    const photos = new FakePhotos();
    const data = new FakeData();
    await publishCity(collection, new Set(), "run1", deps(photos, data));

    const result = await publishCity(collection, new Set(["wd_Q4"]), "run2", deps(photos, data));
    expect(result).toMatchObject({ published: 2, hidden: 1 });
    expect(data.places.get("wd_Q4")?.status).toBe("hidden");
    expect(data.places.get("wd_Q1")?.status).toBe("active");
  });

  it("skips a place whose photos all fail", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    const data = new FakeData();
    const result = await publishCity(collection, new Set(), "run1", {
      ...deps(new FakePhotos(), data),
      download: async () => {
        throw new Error("404");
      },
    });
    expect(result).toMatchObject({ published: 0, placesWithoutPhotos: 3 });
  });

  it("publishes only the photos picked in review, cover first", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    const [first, second] = collection.places[0].photos;
    const photos = new FakePhotos();
    const data = new FakeData();
    const result = await publishCity(collection, new Set(), "run1", {
      ...deps(photos, data),
      picks: { wd_Q1: [second.pageId] },
    });
    expect(result.photosUploaded).toBe(5);
    expect(data.places.get("wd_Q1")?.photos.map((p) => p.commonsPageId)).toEqual([second.pageId]);
    expect(photos.objects.has(`places/pt_lisbon/wd_Q1/${first.pageId}.webp`)).toBe(false);
  });
});

describe("catalog texts", () => {
  it("uses the catalog's German text when there is no German Wikipedia article", async () => {
    const withDe = catalog.map((a) => (a.number === 5 ? { ...a, descriptionDe: "Aussichtspunkt zum Testen." } : a));
    const collection = await collectCity(city, withDe, fakeSources());
    const viewpoint = collection.places.find((p) => p.id === "osm_node_15")!;
    expect(viewpoint.descriptions).toEqual({ en: "Catalog text for Miradouro Test.", de: "Aussichtspunkt zum Testen." });
    expect(viewpoint.wikipediaUrls).toEqual({});
    // A German Wikipedia lead still wins over the catalog text.
    const tower = (await collectCity(city, catalog.map((a) => ({ ...a, descriptionDe: "Katalog." })), fakeSources())).places[0];
    expect(tower.descriptions.de).toBe("de text for Ort_Q1.");
  });
});

describe("selectPhotos", () => {
  it("uses the picks in order, ignores unknown ones and falls back to the first candidates", async () => {
    const place = (await collectCity(city, catalog, fakeSources())).places[0];
    const [a, b] = place.photos.map((p) => p.pageId);
    expect(selectPhotos(place, { wd_Q1: [b, 999, a] }).map((p) => p.pageId)).toEqual([b, a]);
    expect(selectPhotos(place, { wd_Q1: [999] }).map((p) => p.pageId)).toEqual([a, b]);
    expect(selectPhotos(place, {}).map((p) => p.pageId)).toEqual([a, b]);
  });

  it("publishes at most photosPerPlace photos", async () => {
    const place = (await collectCity(city, catalog, fakeSources())).places[0];
    const many = Array.from({ length: 6 }, (_, i) => ({ ...place.photos[0], pageId: 500 + i }));
    const big = { ...place, photos: many };
    expect(selectPhotos(big, {})).toHaveLength(3);
    expect(selectPhotos(big, { wd_Q1: [505, 504, 503, 502] }).map((p) => p.pageId)).toEqual([505, 504, 503]);
  });
});

describe("renderReport", () => {
  it("escapes text from the sources and marks excluded places", async () => {
    const collection: CityCollection = await collectCity(city, catalog, fakeSources());
    collection.places[0].names.de = '<script>alert("x")</script>';
    const html = renderReport([collection], { pt_lisbon: ["wd_Q4"] });
    expect(html).not.toContain("<script>alert");
    expect(html).toContain("&lt;script&gt;");
    expect(html).toContain('class="card excluded"');
  });

  it("shows the picked cover photo first", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    const [first, second] = collection.places[0].photos;
    const html = renderReport([collection], {}, { wd_Q1: [second.pageId] });
    const card = html.slice(html.indexOf("1. Ort Q1") - 600, html.indexOf("1. Ort Q1"));
    expect(card).toContain(second.thumbnailUrl);
    expect(card).not.toContain(first.thumbnailUrl);
  });
});

describe("renderReviewPage", () => {
  it("lists every candidate, numbers the selection and marks the review state", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    collection.places[1].names.de = '<img src=x onerror="alert(1)">';
    const [first, second] = collection.places[0].photos;
    const html = renderReviewPage([collection], collection, { wd_Q1: [second.pageId, first.pageId] }, { pt_lisbon: ["osm_node_15"] });
    expect(html).not.toContain("<img src=x");
    expect(html).toContain('class="card picked" data-id="wd_Q1"');
    expect(html).toContain(`data-selected="${second.pageId},${first.pageId}"`);
    expect(html).toContain('class="card auto" data-id="wd_Q4"');
    expect(html).toContain('class="card excluded" data-id="osm_node_15"');
    expect(html).toMatch(new RegExp(`data-page="${second.pageId}"[^]*?<b>1</b>`));
    expect(html).toContain("Lissabon <span>2/3</span>");
  });
});

describe("free-tier budget", () => {
  it("refuses uploads that would go over the bucket or per-run limit", () => {
    const budget = new UploadBudget(900, { maxBucketBytes: 1000, maxUploadsPerRun: 2 });
    budget.reserve(50);
    expect(() => budget.reserve(60)).toThrow(BudgetExceeded);
    budget.reserve(50);
    expect(() => budget.reserve(1)).toThrow(BudgetExceeded);
    expect(budget.usedBytes).toBe(1000);
    expect(() => new UploadBudget(2000, { maxBucketBytes: 1000, maxUploadsPerRun: 5 })).toThrow(BudgetExceeded);
  });

  it("stops publishing instead of skipping the photo", async () => {
    const collection = await collectCity(city, catalog, fakeSources());
    const photos = new FakePhotos();
    const budget = new UploadBudget(0, { maxBucketBytes: 1000, maxUploadsPerRun: 3 });
    await expect(publishCity(collection, new Set(), "run1", {
      photos,
      data: new FakeData(),
      download: async () => Buffer.from("jpeg"),
      convert: async () => ({ bytes: Buffer.from("webp"), width: 1280, height: 853, sha256: "abc" }),
      reserveUpload: (bytes) => budget.reserve(bytes),
    })).rejects.toThrow(BudgetExceeded);
    expect(photos.puts).toBe(3);
  });
});
