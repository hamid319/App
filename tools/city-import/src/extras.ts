// OSM sights outside the curated catalog (cities.json extraSights):
// museums, galleries, viewpoints, castles, theatres, and with a Wikidata
// item also churches, parks and other landmarks. Scored like venues,
// ranked between venues and catalog sights, photos optional.

import { EXTRA_POPULARITY, EXTRA_SIGHT_TYPES, VENUE_MAX_POPULARITY } from "./config.js";
import { interestsFor } from "./mapping.js";
import type { CityConfig, Localized, PlaceDraft } from "./model.js";
import { isQid, osmAddress, osmUrl, safeWebsite } from "./osm.js";
import { venuePopularity, type VenueCandidate } from "./venues.js";

/** App type for a sight outside the catalog, or null. Small memorials (Stolpersteine, plaques) are skipped. */
export function extraType(tags: Record<string, string>): string | null {
  if (/^(stolperstein|plaque|stele|blue_plaque)$/i.test(tags.memorial ?? "")) return null;
  for (const { key, values, type, needsWikidata } of EXTRA_SIGHT_TYPES) {
    const value = tags[key];
    if (!value || !(values.includes("*") || values.includes(value))) continue;
    if (needsWikidata && !isQid(tags.wikidata)) continue;
    return type;
  }
  return null;
}

/** EXTRA_POPULARITY.min..max from the venue score. */
export function extraPopularity(score: number): number {
  const share = venuePopularity(score) / VENUE_MAX_POPULARITY;
  return EXTRA_POPULARITY.min + Math.round(share * (EXTRA_POPULARITY.max - EXTRA_POPULARITY.min));
}

export function extraDraft(city: CityConfig, candidate: VenueCandidate, rank: number): PlaceDraft {
  const { place, type } = candidate;
  const tags = place.tags;
  const names: Localized = { en: tags["name:en"] ?? tags.name, de: tags["name:de"] ?? tags.name };
  const address = osmAddress(tags);
  const website = safeWebsite(tags.website ?? tags["contact:website"]);
  return {
    id: candidate.id,
    kind: "sight",
    ...(isQid(tags.wikidata) ? { wikidataId: tags.wikidata } : {}),
    cityId: city.id,
    rank,
    catalogName: tags.name,
    category: type,
    osm: { type: place.type, id: place.id, url: osmUrl(place) },
    ...(address ? { address } : {}),
    ...(tags.opening_hours ? { openingHours: tags.opening_hours } : {}),
    ...(website ? { website } : {}),
    names,
    descriptions: {},
    wikipediaUrls: {},
    coordinates: place.coordinates,
    types: [type],
    interests: interestsFor([type]),
    popularity: extraPopularity(candidate.score),
    distanceKm: Math.round(candidate.distanceKm * 10) / 10,
    photos: [],
  };
}
