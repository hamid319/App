// Evening and food venues (restaurants, cafés, bars, pubs, beer gardens,
// night clubs) picked from OpenStreetMap without a hand-made catalog: chains
// are dropped, the rest is ranked by a notability score (Wikidata item,
// Commons photo, opening hours, website, cuisine/description, closeness)
// and capped per type so a city gets a mix.

import { VENUE_AMENITY_TYPES, VENUE_CAPS, VENUE_MAX_POPULARITY, VENUE_SCORE, VENUE_TYPE_INTERESTS, VENUES } from "./config.js";
import { distanceKm, normalizeName } from "./match.js";
import type { CityConfig, Coordinates, Localized, PlaceDraft } from "./model.js";
import { isQid, osmAddress, osmCommonsFile, osmUrl, safeWebsite, type OsmPlace } from "./osm.js";

export interface VenueCandidate {
  place: OsmPlace;
  id: string;
  /** App type: restaurant, cafe, bar, pub, biergarten or night_club. */
  type: string;
  distanceKm: number;
  score: number;
}

/** App type for an OSM element, or null when it is not a venue we offer (e.g. fast_food). */
export function venueType(tags: Record<string, string>): string | null {
  return VENUE_AMENITY_TYPES[tags.amenity ?? ""] ?? null;
}

/** App interests for a venue type: ["food"] or ["nightlife"]. */
export function venueInterests(type: string): string[] {
  const interest = VENUE_TYPE_INTERESTS[type];
  return interest ? [interest] : [];
}

/** Tagged as part of a chain (brand or operator with a Wikidata item). */
export function isChain(tags: Record<string, string>): boolean {
  return Boolean(tags.brand || tags["brand:wikidata"] || tags["operator:wikidata"]);
}

/** Marks of a closed venue in the name, in the languages of our cities. */
const CLOSED_NAME = /\((?:closed|geschlossen|fechad[oa]|cerrad[oa]|ferm[ée]e?|chiuso|chiusa|zamknięte|uzavřeno)\)/i;

/**
 * Not open to a visitor: closed for good (lifecycle tags, "closed" in the
 * name, opening_hours=closed), only for customers or staff (station
 * lounges, staff canteens), or a canteen/office café.
 */
export function isUnavailable(tags: Record<string, string>): boolean {
  if (CLOSED_NAME.test(tags.name ?? "")) return true;
  if (Object.keys(tags).some((k) => /^(disused|abandoned|was|removed|demolished):/.test(k))) return true;
  if (/^(closed|off)$/i.test((tags.opening_hours ?? "").trim())) return true;
  if (/^(private|customers|permit|no|employees|members)$/i.test(tags.access ?? "")) return true;
  if (/lounge/i.test(tags.name ?? "") && tags.amenity === "cafe") return true;
  if (tags.amenity === "cafe" && /^(canteen|staff)$/i.test(tags.cafe ?? tags.cuisine ?? "")) return true;
  return false;
}

/** wd_<QID> when OSM links a Wikidata item, else osm_<type>_<id>. */
export function venueId(place: Pick<OsmPlace, "type" | "id" | "tags">): string {
  const qid = place.tags.wikidata;
  return isQid(qid) ? `wd_${qid}` : `osm_${place.type}_${place.id}`;
}

/** First value of the cuisine tag ("portuguese;seafood" -> "portuguese"), or null. */
export function venueCuisine(tags: Record<string, string>): string | null {
  const first = (tags.cuisine ?? "").split(";")[0].trim().toLowerCase();
  return first && first.length <= 40 ? first : null;
}

/** The OSM tags point at a Commons file or category. */
export function hasPhotoTag(tags: Record<string, string>): boolean {
  return osmCommonsFile(tags) !== null || Boolean(tags.wikimedia_commons?.startsWith("Category:"));
}

const MAX_SCORE = Object.values(VENUE_SCORE).reduce((sum, points) => sum + points, 0);

/**
 * Notability points: Wikidata item > Commons photo > opening hours >
 * website > cuisine/description > closeness to the centre. [hasPhoto]
 * defaults to what the tags say; after the photo lookup it is the real result.
 */
export function venueScore(
  tags: Record<string, string>,
  distance: number,
  radiusKm: number,
  hasPhoto: boolean = hasPhotoTag(tags),
): number {
  let score = 0;
  if (isQid(tags.wikidata)) score += VENUE_SCORE.wikidata;
  if (hasPhoto) score += VENUE_SCORE.photo;
  if (tags.opening_hours) score += VENUE_SCORE.openingHours;
  if (safeWebsite(tags.website ?? tags["contact:website"])) score += VENUE_SCORE.website;
  if (venueCuisine(tags) || tags.description) score += VENUE_SCORE.details;
  score += VENUE_SCORE.closeness * Math.max(0, 1 - distance / radiusKm);
  return score;
}

/** Integer 0..VENUE_MAX_POPULARITY (499), so venues always rank below sights (>= 950). */
export function venuePopularity(score: number): number {
  return Math.min(VENUE_MAX_POPULARITY, Math.max(0, Math.round((score / MAX_SCORE) * VENUE_MAX_POPULARITY)));
}

/**
 * Scored venues worth considering: a known type, named, within [radiusKm],
 * not a chain (brand tags, or the same name [VENUES.chainNameCount]+ times
 * in the area), not excluded, not already a sight. Of two elements with
 * the same name the better one is kept. Best first.
 */
export function venueCandidates(
  places: OsmPlace[],
  center: Coordinates,
  radiusKm: number,
  skipIds: ReadonlySet<string> = new Set(),
): VenueCandidate[] {
  const named = places.filter(
    (p) => p.tags.name && venueType(p.tags) && !isChain(p.tags) && !isUnavailable(p.tags),
  );
  const nameCounts = new Map<string, number>();
  for (const p of named) {
    const key = normalizeName(p.tags.name);
    nameCounts.set(key, (nameCounts.get(key) ?? 0) + 1);
  }
  const byName = new Map<string, VenueCandidate>();
  const byId = new Set<string>();
  for (const place of named) {
    const key = normalizeName(place.tags.name);
    if (!key || (nameCounts.get(key) ?? 0) >= VENUES.chainNameCount) continue;
    const distance = distanceKm(center, place.coordinates);
    if (distance > radiusKm) continue;
    const id = venueId(place);
    if (skipIds.has(id)) continue;
    const candidate: VenueCandidate = {
      place,
      id,
      type: venueType(place.tags)!,
      distanceKm: distance,
      score: venueScore(place.tags, distance, radiusKm),
    };
    const previous = byName.get(key);
    if (previous && compareCandidates(previous, candidate) <= 0) continue;
    byName.set(key, candidate);
  }
  // Two names linked to the same Wikidata item: keep the better one.
  const result: VenueCandidate[] = [];
  for (const candidate of [...byName.values()].sort(compareCandidates)) {
    if (byId.has(candidate.id)) continue;
    byId.add(candidate.id);
    result.push(candidate);
  }
  return result;
}

/** Higher score first; ties: closer, then lower OSM id (stable across runs). */
function compareCandidates(a: VenueCandidate, b: VenueCandidate): number {
  return b.score - a.score || a.distanceKm - b.distanceKm || a.place.id - b.place.id;
}

/** The best [max] candidates (already sorted best first) within the per-type caps. */
export function selectVenues(
  candidates: VenueCandidate[],
  max: number = VENUES.maxPerCity,
  caps: typeof VENUE_CAPS = VENUE_CAPS,
): VenueCandidate[] {
  const used = new Map<number, number>();
  const chosen: VenueCandidate[] = [];
  for (const candidate of candidates) {
    if (chosen.length >= max) break;
    const group = caps.findIndex((cap) => cap.types.includes(candidate.type));
    if (group < 0) continue;
    const count = used.get(group) ?? 0;
    if (count >= caps[group].max) continue;
    used.set(group, count + 1);
    chosen.push(candidate);
  }
  return chosen;
}

/** Draft for a selected venue, before photos and texts are added. */
export function venueDraft(city: CityConfig, candidate: VenueCandidate, rank: number): PlaceDraft {
  const { place, type } = candidate;
  const tags = place.tags;
  const names: Localized = { en: tags["name:en"] ?? tags.name, de: tags["name:de"] ?? tags.name };
  const address = osmAddress(tags);
  const website = safeWebsite(tags.website ?? tags["contact:website"]);
  const cuisine = venueCuisine(tags);
  return {
    id: candidate.id,
    kind: "venue",
    ...(isQid(tags.wikidata) ? { wikidataId: tags.wikidata } : {}),
    cityId: city.id,
    rank,
    catalogName: tags.name,
    category: type,
    osm: { type: place.type, id: place.id, url: osmUrl(place) },
    ...(address ? { address } : {}),
    ...(tags.opening_hours ? { openingHours: tags.opening_hours } : {}),
    ...(website ? { website } : {}),
    ...(cuisine ? { cuisine } : {}),
    names,
    descriptions: {},
    wikipediaUrls: {},
    coordinates: place.coordinates,
    types: [type],
    interests: venueInterests(type),
    popularity: venuePopularity(candidate.score),
    distanceKm: Math.round(candidate.distanceKm * 10) / 10,
    photos: [],
  };
}
