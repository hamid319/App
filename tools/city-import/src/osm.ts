// OpenStreetMap via the Overpass API: one query per city returns every
// named place that could be one of the catalog's attractions. Data ©
// OpenStreetMap contributors, ODbL; the app shows that notice.

import type { WikimediaHttp } from "./http.js";
import type { Coordinates } from "./model.js";

export interface OsmPlace {
  type: "node" | "way" | "relation";
  id: number;
  coordinates: Coordinates;
  tags: Record<string, string>;
}

interface OverpassResponse {
  elements?: Array<{
    type: OsmPlace["type"];
    id: number;
    lat?: number;
    lon?: number;
    center?: { lat: number; lon: number };
    tags?: Record<string, string>;
  }>;
}

/** Overpass QL for a city: notable named places within [radiusKm]. */
export function cityQuery(center: Coordinates, radiusKm: number): string {
  const around = `(around:${Math.round(radiusKm * 1000)},${center.lat},${center.lng})`;
  const filters = [
    `["name"]["tourism"~"^(attraction|museum|gallery|viewpoint|zoo|aquarium|theme_park)$"]`,
    `["name"]["wikidata"]["historic"]`,
    `["name"]["historic"~"^(castle|palace|monument|ruins|archaeological_site|fort|city_gate|tower|monastery|church|manor)$"]`,
    `["name"]["leisure"~"^(park|garden|nature_reserve)$"]`,
    `["name"]["wikidata"]["amenity"~"^(place_of_worship|theatre|arts_centre|marketplace|planetarium)$"]`,
    `["name"]["wikidata"]["building"~"^(cathedral|church|chapel|mosque|temple|synagogue|shrine|palace|castle|tower)$"]`,
    `["name"]["wikidata"]["natural"]`,
    `["name"]["wikidata"]["man_made"]`,
    `["name"]["wikidata"]["bridge"]`,
    `["name"]["wikidata"]["place"~"^(square|neighbourhood|quarter|island|islet)$"]`,
    `["name"]["wikidata"]["highway"~"^(pedestrian|footway)$"]`,
    `["name"]["wikidata"]["landuse"~"^(recreation_ground|cemetery)$"]`,
  ];
  return `[out:json][timeout:240];
(
${filters.map((f) => `  nwr${around}${f};`).join("\n")}
);
out center tags;`;
}

/**
 * Overpass QL for a city's evening/food venues within [radiusKm]: named
 * restaurants, cafés, bars, pubs, beer gardens and night clubs, without
 * branded (chain) ones. A separate request from [cityQuery].
 */
export function venueQuery(center: Coordinates, radiusKm: number): string {
  const around = `(around:${Math.round(radiusKm * 1000)},${center.lat},${center.lng})`;
  return `[out:json][timeout:180];
nwr${around}["name"]["amenity"~"^(restaurant|cafe|bar|pub|biergarten|nightclub)$"][!"brand"][!"brand:wikidata"][!"operator:wikidata"];
out center tags;`;
}

export function fetchCityPlaces(http: WikimediaHttp, center: Coordinates, radiusKm: number): Promise<OsmPlace[]> {
  return overpass(http, cityQuery(center, radiusKm));
}

export function fetchCityVenues(http: WikimediaHttp, center: Coordinates, radiusKm: number): Promise<OsmPlace[]> {
  return overpass(http, venueQuery(center, radiusKm));
}

async function overpass(http: WikimediaHttp, query: string): Promise<OsmPlace[]> {
  const url = new URL("https://overpass-api.de/api/interpreter");
  url.searchParams.set("data", query);
  const data = await http.json<OverpassResponse>(url, 260_000, 120 * 1024 * 1024);
  const places: OsmPlace[] = [];
  for (const element of data.elements ?? []) {
    const lat = element.lat ?? element.center?.lat;
    const lng = element.lon ?? element.center?.lon;
    if (lat === undefined || lng === undefined || !element.tags?.name) continue;
    places.push({ type: element.type, id: element.id, coordinates: { lat, lng }, tags: element.tags });
  }
  return places;
}

/** "Rua Augusta 24, 1100-053 Lisboa" from addr:* tags, or null. */
export function osmAddress(tags: Record<string, string>): string | null {
  const street = [tags["addr:street"] ?? tags["addr:place"], tags["addr:housenumber"]].filter(Boolean).join(" ");
  const city = [tags["addr:postcode"], tags["addr:city"]].filter(Boolean).join(" ");
  const address = [street, city].filter(Boolean).join(", ");
  return address || null;
}

export function osmUrl(place: Pick<OsmPlace, "type" | "id">): string {
  return `https://www.openstreetmap.org/${place.type}/${place.id}`;
}

/** Commons file title from OSM's wikimedia_commons / image tags, or null. */
export function osmCommonsFile(tags: Record<string, string>): string | null {
  const commons = tags.wikimedia_commons;
  if (commons?.startsWith("File:")) return commons.replace(/_/g, " ");
  const image = tags.image;
  if (image) {
    const match = image.match(/(?:commons\.wikimedia\.org\/wiki\/|upload\.wikimedia\.org\/.*\/)(File:)?([^/?#]+\.(?:jpe?g|png|webp))$/i);
    if (match) return `File:${decodeURIComponent(match[2]).replace(/_/g, " ")}`;
  }
  return null;
}

/** http(s) website from a tag value, normalised, or null. */
export function safeWebsite(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value.trim());
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : null;
  } catch {
    return null;
  }
}

export function isQid(value: string | undefined): value is string {
  return Boolean(value && /^Q[1-9]\d*$/.test(value));
}
