// Overture Maps places as a second venue source (rows exported by
// scripts/overture.sh). Licences: Meta, Microsoft and most others CDLA
// Permissive 2.0, Foursquare Apache 2.0, AllThePlaces CC0; all storable.
// Overture has more venues than OSM but also stale and mislabelled ones,
// so only well-confirmed rows are used and OSM wins: a row that is already
// on OSM, or sits right on top of a differently named OSM venue (often the
// previous tenant), is dropped.

import { OVERTURE, OVERTURE_TYPES, VENUES } from "./config.js";
import { distanceKm, nameScore, normalizeName } from "./match.js";
import type { Coordinates } from "./model.js";
import type { OsmPlace } from "./osm.js";
import { venueScore, type VenueCandidate } from "./venues.js";

/** One row of data/overture/<cityId>.json. */
export interface OvertureRow {
  id: string;
  name: string | null;
  /** taxonomy.primary, e.g. "italian_restaurant". */
  primary: string | null;
  /** taxonomy.hierarchy, e.g. ["food_and_drink", "restaurant", ...]. */
  hierarchy: string[] | null;
  confidence: number | null;
  status: string | null;
  brand: string | null;
  websites: string[] | null;
  /** Source datasets except Overture itself, e.g. ["meta", "Microsoft"]. */
  datasets: string[] | null;
  /** Newest update_time of those sources (ISO). */
  updated: string | null;
  lat: number;
  lon: number;
}

const LEGAL_FORM = /\b(gmbh|ug|e\.?\s?k\.?|kg|ag|ohg|gbr|ltd|inc|llc|s\.?r\.?l)\b/i;

/** App venue type, or null (fast food, shops, everything else). */
export function overtureType(row: Pick<OvertureRow, "primary" | "hierarchy">): string | null {
  const primary = row.primary ?? "";
  if (OVERTURE_TYPES[primary]) return OVERTURE_TYPES[primary];
  if (row.hierarchy?.[1] === "restaurant" && !/fast_food/.test(primary)) return "restaurant";
  return null;
}

/** "italian_restaurant" -> "italian" (OSM cuisine values), else null. */
export function overtureCuisine(primary: string | null): string | null {
  const match = primary?.match(/^([a-z_]+)_restaurant$/);
  return match && !/fast_food/.test(match[1]) ? match[1] : null;
}

/** Open, confident, no chain or company, confirmed by Meta or two sources within OVERTURE.maxAgeMonths. */
export function isUsableOverture(row: OvertureRow, now: Date): boolean {
  if (!row.name?.trim() || LEGAL_FORM.test(row.name)) return false;
  if (row.status && row.status !== "open") return false;
  if ((row.confidence ?? 0) < OVERTURE.minConfidence || row.brand) return false;
  const datasets = row.datasets ?? [];
  if (!datasets.includes("meta") && datasets.length < 2) return false;
  const updated = row.updated ? Date.parse(row.updated) : NaN;
  const maxAgeMs = OVERTURE.maxAgeMonths * 30.5 * 24 * 3600 * 1000;
  if (!(now.getTime() - updated <= maxAgeMs)) return false;
  return overtureType(row) !== null;
}

function sameName(a: string, b: string): boolean {
  if (nameScore(a, b) >= 0.6) return true;
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  return short.length >= 4 && long.includes(short);
}

/**
 * Venues that only Overture knows, as candidates (id ovt_<id>), within
 * [radiusKm]. [osmVenues] are all downloaded OSM venues, chains included.
 */
export function overtureCandidates(
  rows: OvertureRow[],
  osmVenues: OsmPlace[],
  center: Coordinates,
  radiusKm: number,
  skipIds: ReadonlySet<string>,
  now: Date = new Date(),
): { usable: number; candidates: VenueCandidate[] } {
  const usable = rows.filter((r) => isUsableOverture(r, now));
  // ~100 m grid over the OSM venues for the neighbour checks.
  const cell = (lat: number, lng: number) => [Math.floor(lat * 900), Math.floor(lng * 550)];
  const grid = new Map<string, Array<{ place: OsmPlace; name: string }>>();
  for (const place of osmVenues) {
    const [a, b] = cell(place.coordinates.lat, place.coordinates.lng);
    const key = `${a}:${b}`;
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key)!.push({ place, name: normalizeName(place.tags.name ?? "") });
  }
  const near = (c: Coordinates) => {
    const [a, b] = cell(c.lat, c.lng);
    const out: Array<{ place: OsmPlace; name: string }> = [];
    for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) out.push(...(grid.get(`${a + i}:${b + j}`) ?? []));
    return out;
  };

  const nameCounts = new Map<string, number>();
  for (const r of usable) {
    const key = normalizeName(r.name!);
    nameCounts.set(key, (nameCounts.get(key) ?? 0) + 1);
  }

  const candidates: VenueCandidate[] = [];
  for (const row of usable) {
    const id = `ovt_${row.id}`;
    const name = normalizeName(row.name!);
    if (!name || skipIds.has(id) || (nameCounts.get(name) ?? 0) >= VENUES.chainNameCount) continue;
    const coordinates = { lat: row.lat, lng: row.lon };
    const distance = distanceKm(center, coordinates);
    if (distance > radiusKm) continue;
    const neighbours = near(coordinates).map((o) => ({ ...o, km: distanceKm(coordinates, o.place.coordinates) }));
    if (neighbours.some((o) => o.km <= OVERTURE.matchKm && sameName(name, o.name))) continue;
    if (neighbours.some((o) => o.km <= OVERTURE.conflictKm)) continue;
    const cuisine = overtureCuisine(row.primary);
    const website = row.websites?.[0];
    const tags: Record<string, string> = {
      name: row.name!.trim(),
      ...(cuisine ? { cuisine } : {}),
      ...(website ? { website } : {}),
    };
    candidates.push({
      place: { type: "node", id: 0, coordinates, tags },
      id,
      type: overtureType(row)!,
      distanceKm: distance,
      score: venueScore(tags, distance, radiusKm),
      overtureId: row.id,
    });
  }
  return { usable: usable.length, candidates };
}
