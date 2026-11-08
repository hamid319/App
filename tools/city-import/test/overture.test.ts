import { describe, expect, it } from "vitest";
import { extraPopularity, extraType } from "../src/extras.js";
import type { OsmPlace } from "../src/osm.js";
import { isUsableOverture, overtureCandidates, overtureCuisine, overtureType, type OvertureRow } from "../src/overture.js";
import { toPlaceDoc } from "../src/publish.js";
import { venueDraft } from "../src/venues.js";

const now = new Date("2026-11-08T00:00:00Z");
const center = { lat: 52.52, lng: 13.405 };
const row = (over: Partial<OvertureRow> = {}): OvertureRow => ({
  id: "abc-1",
  name: "Trattoria Uno",
  primary: "italian_restaurant",
  hierarchy: ["food_and_drink", "restaurant", "european_restaurant", "italian_restaurant"],
  confidence: 0.95,
  status: "open",
  brand: null,
  websites: ["https://uno.example"],
  datasets: ["meta"],
  updated: "2026-10-01T00:00:00Z",
  lat: 52.521,
  lon: 13.406,
  ...over,
});
const osm = (name: string, lat: number, lng: number): OsmPlace => ({
  type: "node",
  id: 1,
  coordinates: { lat, lng },
  tags: { name, amenity: "restaurant" },
});

describe("overture rows", () => {
  it("maps categories to app venue types and cuisines", () => {
    expect(overtureType(row())).toBe("restaurant");
    expect(overtureType(row({ primary: "cocktail_bar", hierarchy: ["food_and_drink", "alcoholic_beverage_venue"] }))).toBe("bar");
    expect(overtureType(row({ primary: "fast_food_restaurant", hierarchy: ["food_and_drink", "casual_eatery"] }))).toBeNull();
    expect(overtureType(row({ primary: "bakery", hierarchy: ["food_and_drink", "casual_eatery"] }))).toBeNull();
    expect(overtureCuisine("italian_restaurant")).toBe("italian");
    expect(overtureCuisine("restaurant")).toBeNull();
  });

  it("keeps only confident, recent, non-chain rows", () => {
    expect(isUsableOverture(row(), now)).toBe(true);
    expect(isUsableOverture(row({ confidence: 0.85 }), now)).toBe(false);
    expect(isUsableOverture(row({ brand: "Vapiano" }), now)).toBe(false);
    expect(isUsableOverture(row({ name: "Gastro Service GmbH" }), now)).toBe(false);
    expect(isUsableOverture(row({ datasets: ["Microsoft"] }), now)).toBe(false);
    expect(isUsableOverture(row({ datasets: ["Microsoft", "BrightQuery"] }), now)).toBe(true);
    expect(isUsableOverture(row({ updated: "2024-01-01T00:00:00Z" }), now)).toBe(false);
    expect(isUsableOverture(row({ status: "permanently_closed" }), now)).toBe(false);
  });

  it("adds only venues OSM does not have and drops likely old tenants", () => {
    const rows = [
      row({ id: "same", name: "Hako Ramen Prenzlauer Berg", lat: 52.53, lon: 13.41 }),
      row({ id: "tenant", name: "Oderquelle", lat: 52.54, lon: 13.42 }),
      row({ id: "new", name: "Trattoria Uno", lat: 52.521, lon: 13.406 }),
      row({ id: "far", name: "Weit Weg", lat: 53.5, lon: 13.4 }),
    ];
    const osmVenues = [osm("Hako Ramen", 52.5302, 13.4101), osm("Wei Dao Jia", 52.54003, 13.42003)];
    const { usable, candidates } = overtureCandidates(rows, osmVenues, center, 25, new Set(), now);
    expect(usable).toBe(4);
    expect(candidates.map((c) => c.id)).toEqual(["ovt_new"]);
    const draft = venueDraft({ id: "de_berlin", catalogId: "berlin", nameEn: "Berlin", nameDe: "Berlin", countryCode: "DE", ...center }, candidates[0], 1);
    expect(draft).toMatchObject({ overtureId: "new", cuisine: "italian", website: "https://uno.example/" });
    expect(draft.osm).toBeUndefined();
    const doc = toPlaceDoc(draft, [], "run", "2026-11-08");
    expect(doc).toMatchObject({ sourceId: "overture/new", overtureId: "new", osmUrl: null, kind: "venue" });
  });
});

describe("extra sights", () => {
  it("maps OSM tags to app types and skips small memorials", () => {
    expect(extraType({ tourism: "museum" })).toBe("museum");
    expect(extraType({ leisure: "park" })).toBeNull();
    expect(extraType({ leisure: "park", wikidata: "Q1" })).toBe("park");
    expect(extraType({ historic: "memorial", memorial: "stolperstein", wikidata: "Q2" })).toBeNull();
    expect(extraType({ historic: "memorial", wikidata: "Q2" })).toBe("historical_landmark");
    expect(extraType({ amenity: "restaurant" })).toBeNull();
  });

  it("ranks between venues and catalog sights", () => {
    expect(extraPopularity(0)).toBe(500);
    expect(extraPopularity(1e6)).toBe(949);
  });
});
