// Place tiles: one Firestore document per geohash-5 cell (~4.9 x 4.9 km)
// and city, holding a compact list of that cell's best places. The app
// reads the 3 x 3 tiles around the user (9 reads) instead of one document
// per place, so a user anywhere in a big city gets the places near them.
// Must match lib/common/utils/geohash.dart.

import type { PlaceDoc } from "./model.js";

export const TILE = Object.freeze({
  precision: 5,
  /** Best places per tile, by popularity; the rest are still found on the map/search via the full docs. */
  maxSights: 80,
  maxVenues: 150,
  /** Firestore's limit is 1 MiB per document; stay well below. */
  maxBytes: 800_000,
});

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/** Standard geohash of a position. */
export function geohash(lat: number, lng: number, precision: number = TILE.precision): string {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let hash = "", bits = 0, value = 0, evenBit = true;
  while (hash.length < precision) {
    if (evenBit) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { value = value * 2 + 1; lngMin = mid; } else { value *= 2; lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { value = value * 2 + 1; latMin = mid; } else { value *= 2; latMax = mid; }
    }
    evenBit = !evenBit;
    if (++bits === 5) { hash += BASE32[value]; bits = 0; value = 0; }
  }
  return hash;
}

/** One entry of a tile; keys follow the app's PlaceModel.fromJson. */
export interface TileEntry {
  id: string;
  name: string;
  names: PlaceDoc["names"];
  lat: number;
  lng: number;
  kind: PlaceDoc["kind"];
  types: string[];
  popularity: number;
  imageUrls?: string[];
  /** Credit of that image (CC BY needs the author wherever it is shown). */
  photos?: Array<Pick<PlaceDoc["photos"][number], "creator" | "licenseName" | "licenseUrl" | "commonsFilePageUrl">>;
  openingHours?: string;
  cuisine?: string;
  cityId: string;
}

/** placeTiles/{cityId}_{geohash}. */
export interface TileDoc {
  id: string;
  cityId: string;
  geohash: string;
  places: TileEntry[];
  importRunId: string;
  updatedAt: string;
}

function entry(doc: PlaceDoc): TileEntry {
  return {
    id: doc.id,
    name: doc.name,
    names: doc.names,
    lat: doc.lat,
    lng: doc.lng,
    kind: doc.kind,
    types: doc.types,
    popularity: doc.popularity,
    ...(doc.imageUrls[0] ? { imageUrls: [doc.imageUrls[0]] } : {}),
    ...(doc.photos[0]
      ? {
        photos: [{
          creator: doc.photos[0].creator,
          licenseName: doc.photos[0].licenseName,
          ...(doc.photos[0].licenseUrl ? { licenseUrl: doc.photos[0].licenseUrl } : {}),
          commonsFilePageUrl: doc.photos[0].commonsFilePageUrl,
        }],
      }
      : {}),
    ...(doc.openingHours ? { openingHours: doc.openingHours } : {}),
    ...(doc.cuisine ? { cuisine: doc.cuisine } : {}),
    cityId: doc.cityId,
  };
}

/** Tiles for a city's active places: per cell the best TILE.maxSights sights and TILE.maxVenues venues. */
export function buildTiles(cityId: string, docs: PlaceDoc[], importRunId: string, updatedAt: string): TileDoc[] {
  const cells = new Map<string, PlaceDoc[]>();
  for (const doc of docs) {
    if (doc.status !== "active") continue;
    const cell = geohash(doc.lat, doc.lng);
    if (!cells.has(cell)) cells.set(cell, []);
    cells.get(cell)!.push(doc);
  }
  const tiles: TileDoc[] = [];
  for (const [cell, list] of [...cells].sort(([a], [b]) => a.localeCompare(b))) {
    const best = (kind: PlaceDoc["kind"], max: number) =>
      list.filter((d) => d.kind === kind).sort((a, b) => b.popularity - a.popularity || a.id.localeCompare(b.id)).slice(0, max);
    const places = [...best("sight", TILE.maxSights), ...best("venue", TILE.maxVenues)].map(entry);
    // Very dense cell with long names: drop the weakest venues until it fits.
    while (places.length && Buffer.byteLength(JSON.stringify(places)) > TILE.maxBytes) places.pop();
    tiles.push({ id: `${cityId}_${cell}`, cityId, geohash: cell, places, importRunId, updatedAt });
  }
  return tiles;
}
