import { describe, expect, it } from "vitest";
import { collectCity, type CollectSources } from "../src/collect.js";
import { VENUE_CAPS, VENUES } from "../src/config.js";
import { interestsFor } from "../src/mapping.js";
import type { CatalogAttraction, CityDoc, PlaceDoc } from "../src/model.js";
import type { OsmPlace } from "../src/osm.js";
import { venueQuery } from "../src/osm.js";
import { publishCity } from "../src/publish.js";
import { renderReport } from "../src/report.js";
import { renderReviewPage } from "../src/review.js";
import type { DataStore, PhotoStore, StoredObjectInfo } from "../src/stores.js";
import {
  isUnavailable,
  isChain,
  selectVenues,
  venueCandidates,
  venueCuisine,
  venueDraft,
  venueId,
  venueInterests,
  venuePopularity,
  venueScore,
  venueType,
  type VenueCandidate,
} from "../src/venues.js";
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
const center = { lat: city.lat, lng: city.lng };

let nextId = 1000;
const venue = (tags: Record<string, string>, coordinates = { lat: 38.7225, lng: -9.1395 }, id = nextId++): OsmPlace => ({
  type: "node",
  id,
  coordinates,
  tags: { amenity: "restaurant", ...tags },
});

const candidate = (type: string, score: number, id = nextId++): VenueCandidate => ({
  place: venue({ name: `V${id}` }, undefined, id),
  id: `osm_node_${id}`,
  type,
  distanceKm: 1,
  score,
});

describe("venue types and interests", () => {
  it("maps OSM amenities to one app type and interest", () => {
    const cases: Array<[string, string, string]> = [
      ["restaurant", "restaurant", "food"],
      ["cafe", "cafe", "food"],
      ["biergarten", "biergarten", "food"],
      ["bar", "bar", "nightlife"],
      ["pub", "pub", "nightlife"],
      ["nightclub", "night_club", "nightlife"],
    ];
    for (const [amenity, type, interest] of cases) {
      expect(venueType({ amenity })).toBe(type);
      expect(venueInterests(type)).toEqual([interest]);
      // Same answer as the app's Interest mapping.
      expect(interestsFor([type])).toEqual([interest]);
    }
    expect(venueType({ amenity: "fast_food" })).toBeNull();
    expect(venueType({ tourism: "museum" })).toBeNull();
  });

  it("keeps the first cuisine value", () => {
    expect(venueCuisine({ cuisine: "Portuguese;seafood" })).toBe("portuguese");
    expect(venueCuisine({})).toBeNull();
  });

  it("uses wd_<QID> with a valid Wikidata tag, else the OSM element", () => {
    expect(venueId({ type: "node", id: 5, tags: { wikidata: "Q42" } })).toBe("wd_Q42");
    expect(venueId({ type: "way", id: 6, tags: { wikidata: "Q0" } })).toBe("osm_way_6");
    expect(venueId({ type: "node", id: 7, tags: {} })).toBe("osm_node_7");
  });

  it("asks Overpass for the six amenities without branded ones", () => {
    const query = venueQuery(center, 5);
    expect(query).toContain("around:5000,");
    expect(query).toContain("restaurant|cafe|bar|pub|biergarten|nightclub");
    expect(query).toContain('[!"brand"][!"brand:wikidata"][!"operator:wikidata"]');
  });
});

describe("venue selection", () => {
  it("drops chains: brand tags, and names found too often in the area", () => {
    expect(isChain({ brand: "Starbucks" })).toBe(true);
    expect(isChain({ "brand:wikidata": "Q37158" })).toBe(true);
    expect(isChain({ "operator:wikidata": "Q1" })).toBe(true);
    expect(isChain({ operator: "Família Silva" })).toBe(false);

    const places = [
      venue({ name: "Starbucks", amenity: "cafe", brand: "Starbucks" }),
      venue({ name: "Café X", "brand:wikidata": "Q9" }),
      venue({ name: "Bar Y", amenity: "bar", "operator:wikidata": "Q8" }),
      ...Array.from({ length: VENUES.chainNameCount }, () => venue({ name: "Pastelaria Chain", amenity: "cafe" })),
      venue({ name: "Burger", amenity: "fast_food" }),
      venue({ name: "Tasca Boa" }),
    ];
    expect(venueCandidates(places, center, 5).map((c) => c.place.tags.name)).toEqual(["Tasca Boa"]);
  });

  it("keeps the better of two elements with the same name, skips excluded and far ones", () => {
    const weak = venue({ name: "A Cevicheria" });
    const strong = venue({ name: "A Cevicheria", opening_hours: "Mo-Su 12:00-24:00" });
    const far = venue({ name: "Far Away" }, { lat: 38.9, lng: -9.1393 });
    const excluded = venue({ name: "Excluded" });
    const result = venueCandidates([weak, strong, far, excluded], center, 5, new Set([`osm_node_${excluded.id}`]));
    expect(result.map((c) => c.place.id)).toEqual([strong.id]);
  });

  it("scores Wikidata > photo > opening hours > website > cuisine, closer is better", () => {
    const at = (tags: Record<string, string>, d = 1) => venueScore(tags, d, 5);
    const wikidata = at({ wikidata: "Q1" }, 4.9);
    const photo = at({ wikimedia_commons: "File:Bar.jpg", opening_hours: "x", website: "https://x.test", cuisine: "x" }, 0);
    expect(wikidata).toBeGreaterThan(photo);
    const hours = at({ opening_hours: "x", website: "https://x.test", cuisine: "x" }, 0);
    expect(at({ image: "https://commons.wikimedia.org/wiki/File:Bar.jpg" }, 4.9)).toBeGreaterThan(hours);
    const website = at({ website: "https://x.test", cuisine: "x" }, 0);
    expect(at({ opening_hours: "x" }, 4.9)).toBeGreaterThan(website);
    expect(at({ website: "https://x.test" }, 4.9)).toBeGreaterThan(at({ cuisine: "x", description: "x" }, 0));
    expect(at({ cuisine: "x" }, 4.9)).toBeGreaterThan(at({}, 0));
    expect(at({ description: "x" })).toBe(at({ cuisine: "x" }));
    expect(at({}, 0.5)).toBeGreaterThan(at({}, 3));
    expect(venueScore({}, 1, 5, true)).toBeGreaterThan(venueScore({}, 1, 5, false));
  });

  it("maps every score to an integer popularity 0..499, below every sight", () => {
    const full = venueScore(
      { wikidata: "Q1", wikimedia_commons: "File:a.jpg", opening_hours: "x", website: "https://x.test", cuisine: "x", description: "x" },
      0,
      5,
    );
    expect(venuePopularity(full)).toBe(499);
    expect(venuePopularity(0)).toBe(0);
    expect(venuePopularity(-5)).toBe(0);
    expect(venuePopularity(10_000)).toBe(499);
    for (const score of [0, 3.3, 17, 99.9, 150]) {
      const p = venuePopularity(score);
      expect(Number.isInteger(p)).toBe(true);
      expect(p).toBeLessThan(950);
    }
  });

  it("takes the best venues within the per-type caps and the city maximum", () => {
    const many = [
      ...Array.from({ length: 30 }, (_, i) => candidate("restaurant", 200 - i)),
      ...Array.from({ length: 8 }, (_, i) => candidate("bar", 150 - i)),
      ...Array.from({ length: 8 }, (_, i) => candidate("pub", 140 - i)),
      ...Array.from({ length: 20 }, (_, i) => candidate("cafe", 100 - i)),
      ...Array.from({ length: 9 }, (_, i) => candidate("night_club", 50 - i)),
      ...Array.from({ length: 9 }, (_, i) => candidate("biergarten", 40 - i)),
    ].sort((a, b) => b.score - a.score);
    const chosen = selectVenues(many);
    const count = (types: string[]) => chosen.filter((c) => types.includes(c.type)).length;
    expect(chosen.length).toBeLessThanOrEqual(VENUES.maxPerCity);
    for (const cap of VENUE_CAPS) expect(count([...cap.types])).toBeLessThanOrEqual(cap.max);
    expect(count(["restaurant"])).toBe(15);
    expect(count(["bar", "pub"])).toBe(12);
    // Best restaurants, not the first 15 of any type.
    expect(chosen[0].score).toBe(200);
    expect(selectVenues(many, 5)).toHaveLength(5);
  });

  it("builds a draft with OSM names, one type and the cuisine", () => {
    const place = venue({ name: "Cervejaria Ramiro", "name:de": "Bierhalle Ramiro", cuisine: "seafood;portuguese", wikidata: "Q5" });
    const draft = venueDraft(city, { place, id: venueId(place), type: "restaurant", distanceKm: 1.234, score: 40 }, 1);
    expect(draft).toMatchObject({
      id: "wd_Q5",
      kind: "venue",
      wikidataId: "Q5",
      names: { en: "Cervejaria Ramiro", de: "Bierhalle Ramiro" },
      descriptions: {},
      types: ["restaurant"],
      interests: ["food"],
      cuisine: "seafood",
      distanceKm: 1.2,
      popularity: venuePopularity(40),
    });
  });
});

// ---- collect + publish with fakes (no network) ----

const photo = (title: string, pageId: number): PhotoMetadata => ({
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
});

const catalog: CatalogAttraction[] = [
  { id: "lisbon-1", number: 1, name: "Café A Brasileira", category: "Historic Site", description: "Catalog text." },
];

const sightOsm: OsmPlace = {
  type: "node", id: 1, coordinates: { lat: 38.7107, lng: -9.1424 },
  tags: { name: "Café A Brasileira", wikidata: "Q100", tourism: "attraction", amenity: "cafe" },
};

const venueOsm: OsmPlace[] = [
  // Also the catalog sight: published once, as the sight.
  sightOsm,
  venue({ name: "Park Bar", amenity: "bar", wikidata: "Q200", opening_hours: "Mo-Su 13:00-02:00" }, undefined, 2),
  venue({ name: "Tasca do Chico", cuisine: "portuguese;fado", website: "https://tasca.test" }, undefined, 3),
  venue({ name: "Excluded Pub", amenity: "pub" }, undefined, 4),
];

function sources(): CollectSources {
  return {
    osmPlaces: async () => [sightOsm],
    osmVenues: async () => venueOsm,
    wikimedia: {
      searchEntities: async () => [],
      entityInfo: async (ids) => new Map(ids.map((id) => [id, {
        labels: { en: `Label ${id}` },
        descriptions: { en: `Wikidata description ${id}` },
        wikipediaTitles: id === "Q100" ? { en: "A_Brasileira" } : {},
        imageFiles: [`File:${id}.jpg`],
        coordinates: center,
      }])),
      photoFiles: async (lookups) => new Map(lookups.map((l) => [l.wikidataId, [...l.knownFiles]])),
      categoryFiles: async () => [],
      photoMetadata: async (titles) => new Map(titles.map((t, i) => [t, photo(t, 500 + i)])),
      wikipediaSummary: async (lang, title) => ({ text: `${lang} lead ${title}.`, url: `https://${lang}.wikipedia.org/wiki/${title}` }),
    },
  };
}

class FakePhotos implements PhotoStore {
  objects = new Map<string, StoredObjectInfo>();
  async head(key: string) {
    return this.objects.get(key) ?? null;
  }
  async put(key: string, _bytes: Buffer, info: StoredObjectInfo) {
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

describe("collect and publish venues", () => {
  it("collects venues next to the sights, with or without photos", async () => {
    const collection = await collectCity(city, catalog, sources(), undefined, new Set(["osm_node_4"]));
    expect(collection.places.map((p) => [p.id, p.kind])).toEqual([["wd_Q100", "sight"]]);
    expect(collection.venueCandidates).toEqual({ downloaded: 4, eligible: 2 });
    const venues = collection.venues!;
    expect(venues.map((v) => v.id)).toEqual(["wd_Q200", "osm_node_3"]);
    expect(venues.map((v) => v.rank)).toEqual([1, 2]);

    const [bar, tasca] = venues;
    expect(bar).toMatchObject({
      kind: "venue",
      types: ["bar"],
      interests: ["nightlife"],
      names: { en: "Park Bar", de: "Park Bar" },
      // No Wikipedia article: the Wikidata description, never invented text.
      descriptions: { en: "Wikidata description Q200" },
      openingHours: "Mo-Su 13:00-02:00",
    });
    expect(bar.photos.map((p) => p.fileTitle)).toEqual(["File:Q200.jpg"]);
    expect(tasca).toMatchObject({ cuisine: "portuguese", descriptions: {}, photos: [], website: "https://tasca.test/" });
    for (const v of venues) expect(v.popularity).toBeLessThanOrEqual(499);
    expect(bar.popularity).toBeGreaterThan(tasca.popularity);
  });

  it("publishes venues with kind and cuisine, keeps those without photos, counts only sights", async () => {
    const collection = await collectCity(city, catalog, sources());
    const data = new FakeData();
    const result = await publishCity(collection, new Set(), "run1", {
      photos: new FakePhotos(),
      data,
      download: async () => Buffer.from("jpeg"),
      convert: async () => ({ bytes: Buffer.from("webp"), width: 1280, height: 853, sha256: "abc" }),
      now: () => new Date("2026-10-23T10:00:00Z"),
    });
    expect(result).toMatchObject({ published: 4, venues: 3, venuesWithoutPhotos: 2 });
    expect(data.places.get("wd_Q100")).toMatchObject({ kind: "sight" });
    expect(data.places.get("wd_Q100")).not.toHaveProperty("cuisine");
    expect(data.places.get("osm_node_3")).toMatchObject({
      kind: "venue",
      status: "active",
      cuisine: "portuguese",
      types: ["restaurant"],
      interests: ["food"],
      imageUrls: [],
      photos: [],
      description: null,
      osmUrl: "https://www.openstreetmap.org/node/3",
    });
    for (const doc of data.places.values()) {
      expect(Object.values(doc).includes(undefined)).toBe(false);
    }
    expect(data.cities.get("pt_lisbon")?.placeCount).toBe(1);

    // An excluded venue is hidden on the next run, like a sight.
    await publishCity(collection, new Set(["osm_node_4"]), "run2", {
      photos: new FakePhotos(),
      data,
      download: async () => Buffer.from("jpeg"),
      convert: async () => ({ bytes: Buffer.from("webp"), width: 1280, height: 853, sha256: "abc" }),
    });
    expect(data.places.get("osm_node_4")?.status).toBe("hidden");
  });

  it("lists venues in their own section of the report and the review page", async () => {
    const collection = await collectCity(city, catalog, sources());
    const report = renderReport([collection], {});
    expect(report).toContain("Lokale (Heute Abend)");
    expect(report).toContain("Tasca do Chico");
    expect(report).toContain("kein Foto");
    const review = renderReviewPage([collection], collection, {}, {});
    expect(review).toContain("Lokale (Heute Abend)");
    expect(review).toContain('data-id="osm_node_3"');
  });
});

describe("isUnavailable", () => {
  it("drops venues that closed for good", () => {
    expect(isUnavailable({ name: "Alma (closed)", amenity: "restaurant" })).toBe(true);
    expect(isUnavailable({ name: "Cervejaria Solmar (Fechada)", amenity: "pub" })).toBe(true);
    expect(isUnavailable({ name: "X", amenity: "bar", "disused:amenity": "bar" })).toBe(true);
    expect(isUnavailable({ name: "X", amenity: "bar", opening_hours: "closed" })).toBe(true);
  });

  it("drops venues not open to visitors", () => {
    expect(isUnavailable({ name: "DB Lounge", amenity: "cafe" })).toBe(true);
    expect(isUnavailable({ name: "Kantine", amenity: "restaurant", access: "customers" })).toBe(true);
  });

  it("keeps ordinary venues", () => {
    expect(isUnavailable({ name: "Monkey Bar", amenity: "bar" })).toBe(false);
    expect(isUnavailable({ name: "Lounge 77", amenity: "bar" })).toBe(false);
    expect(isUnavailable({ name: "A Brasileira", amenity: "cafe", opening_hours: "Mo-Su 08:00-02:00" })).toBe(false);
  });
});
