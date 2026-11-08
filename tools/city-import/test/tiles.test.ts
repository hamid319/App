import { describe, expect, it } from "vitest";
import type { PlaceDoc } from "../src/model.js";
import { TILE, buildTiles, geohash } from "../src/tiles.js";

const doc = (id: string, kind: PlaceDoc["kind"], popularity: number, lat = 52.52, lng = 13.405, status: PlaceDoc["status"] = "active") =>
  ({ id, kind, popularity, lat, lng, status, name: id, names: { en: id }, types: ["museum"], imageUrls: [], photos: [], openingHours: null, cityId: "de_berlin" }) as unknown as PlaceDoc;

describe("tiles", () => {
  it("encodes standard geohashes", () => {
    expect(geohash(57.64911, 10.40744, 11)).toBe("u4pruydqqvj");
    expect(geohash(52.52, 13.405)).toBe("u33dc");
  });

  it("groups active places per cell, best first, capped per kind", () => {
    const docs = [
      ...Array.from({ length: TILE.maxVenues + 5 }, (_, i) => doc(`v${i}`, "venue", i)),
      doc("s1", "sight", 990),
      doc("hidden", "sight", 999, 52.52, 13.405, "hidden"),
      doc("far", "sight", 500, 48.137, 11.575),
    ];
    const tiles = buildTiles("de_berlin", docs, "run", "now");
    expect(tiles.map((t) => t.id)).toEqual(["de_berlin_u281z", "de_berlin_u33dc"]);
    const berlin = tiles[1];
    expect(berlin.places[0].id).toBe("s1");
    expect(berlin.places).toHaveLength(1 + TILE.maxVenues);
    expect(berlin.places[1].id).toBe(`v${TILE.maxVenues + 4}`);
    expect(berlin.places.some((p) => p.id === "hidden")).toBe(false);
  });
});
