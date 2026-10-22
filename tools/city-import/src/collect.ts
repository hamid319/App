// Turns one city of the curated catalog into place drafts for review:
//   catalog name -> OpenStreetMap place (coordinates, address, hours,
//   website, Wikidata link) -> Wikidata/Commons/Wikipedia (photos, EN/DE
//   names and texts). Catalog entries that cannot be placed on the map or
//   have no usable photo are reported as skipped.

import { DEFAULTS } from "./config.js";
import { normalizeLicense } from "./licenses.js";
import { interestsFor, typesFor } from "./mapping.js";
import { distanceKm, matchAttraction } from "./match.js";
import type {
  CatalogAttraction,
  CityCollection,
  CityConfig,
  Coordinates,
  Lang,
  Localized,
  PhotoDraft,
  PlaceDraft,
} from "./model.js";
import { osmAddress, osmCommonsFile, osmUrl, type OsmPlace } from "./osm.js";
import type { EntityInfo, PhotoMetadata, WikimediaSource } from "./wikimedia.js";

/** What collect needs from the outside world (fakes in tests). */
export interface CollectSources {
  osmPlaces(center: Coordinates, radiusKm: number): Promise<OsmPlace[]>;
  wikimedia: Pick<
    WikimediaSource,
    "entityInfo" | "searchEntities" | "wikipediaSummary" | "photoFiles" | "photoMetadata" | "categoryFiles"
  >;
}

const NON_PHOTO = /\b(maps?|locator|logos?|flags?|coats? of arms|diagrams?|plans?|drawings?|engravings?|paintings?|postcards?|stamps?|svg)\b/i;
const IMAGE_MIMES = new Set(["image/jpeg", "image/png", "image/webp"]);

interface Located {
  seed: CatalogAttraction;
  coordinates: Coordinates;
  qid?: string;
  osm?: OsmPlace;
}

export async function collectCity(
  city: CityConfig,
  catalog: CatalogAttraction[],
  sources: CollectSources,
  log: (line: string) => void = () => undefined,
): Promise<CityCollection> {
  const center = { lat: city.lat, lng: city.lng };
  const radiusKm = city.radiusKm ?? DEFAULTS.radiusKm;
  const seeds = [...catalog].sort((a, b) => a.number - b.number);
  const skipped: CityCollection["skipped"] = [];

  // 1. Find every catalog name on OpenStreetMap.
  const osmPlaces = await sources.osmPlaces(center, radiusKm);
  log(`${city.id}: ${osmPlaces.length} OSM places within ${radiusKm} km`);
  const located: Located[] = [];
  const unmatched: CatalogAttraction[] = [];
  for (const seed of seeds) {
    const match = matchAttraction(seed.name, osmPlaces, center);
    if (!match) {
      unmatched.push(seed);
      continue;
    }
    const qid = match.place.tags.wikidata;
    located.push({
      seed,
      coordinates: match.place.coordinates,
      osm: match.place,
      ...(isQid(qid) ? { qid } : {}),
    });
  }
  const osmMatched = located.length;

  // OSM place without a Wikidata link: look the name up near that spot, so
  // it still gets photos and texts.
  for (const l of located) {
    if (l.qid) continue;
    const hit = await findOnWikidata(l.seed.name, city.nameEn, l.coordinates, 1.5, sources.wikimedia);
    if (hit) l.qid = hit.id;
  }

  // 2. Not on OSM under that name: Wikidata's search, nearest hit in range.
  for (const seed of unmatched) {
    const hit = await findOnWikidata(seed.name, city.nameEn, center, radiusKm, sources.wikimedia);
    if (hit) located.push({ seed, qid: hit.id, coordinates: hit.coordinates });
    else skipped.push({ rank: seed.number, name: seed.name, reason: "not found on the map" });
  }
  log(`${city.id}: ${osmMatched} on OSM, ${located.length - osmMatched} via Wikidata, ${skipped.length} not found`);

  // 3. Wikidata details for everything with a QID (names, main image).
  const qids = [...new Set(located.flatMap((l) => (l.qid ? [l.qid] : [])))];
  const info = await sources.wikimedia.entityInfo(qids);

  // 4. Photos: main image, OSM image tag, then files depicting the place.
  const files = await sources.wikimedia.photoFiles(
    located
      .filter((l) => l.qid)
      .map((l) => ({ wikidataId: l.qid!, knownFiles: knownFiles(l, info.get(l.qid!)) })),
  );
  // Commons category of the place (from OSM or Wikidata): more photos for
  // places with few tagged ones, e.g. viewpoints.
  for (const l of located) {
    const category = commonsCategory(l, l.qid ? info.get(l.qid) : undefined);
    if (!category) continue;
    const key = l.qid ?? `osm_${l.osm!.type}_${l.osm!.id}`;
    const list = files.get(key) ?? knownFiles(l, l.qid ? info.get(l.qid) : undefined);
    for (const f of await sources.wikimedia.categoryFiles(category)) if (!list.includes(f)) list.push(f);
    files.set(key, list);
  }
  const allFiles = new Set<string>();
  for (const l of located) for (const f of filesFor(l, files, info)) allFiles.add(f);
  const metadata = await sources.wikimedia.photoMetadata([...allFiles]);

  const places: PlaceDraft[] = [];
  const usedPages = new Set<number>();
  const usedIds = new Set<string>();
  for (const l of located) {
    const id = l.qid ? `wd_${l.qid}` : `osm_${l.osm!.type}_${l.osm!.id}`;
    if (usedIds.has(id)) {
      skipped.push({ rank: l.seed.number, name: l.seed.name, reason: "same place as an earlier entry" });
      continue;
    }
    const photos = choosePhotos(filesFor(l, files, info), metadata, usedPages);
    if (photos.length === 0) {
      skipped.push({ rank: l.seed.number, name: l.seed.name, reason: "no usable photo" });
      continue;
    }
    usedIds.add(id);
    places.push(toDraft(city, l, id, l.qid ? info.get(l.qid) : undefined, photos, center));
  }

  // 5. Wikipedia lead paragraphs (EN/DE) for the places we keep.
  for (const place of places) {
    const entity = place.wikidataId ? info.get(place.wikidataId) : undefined;
    for (const lang of ["en", "de"] as Lang[]) {
      const title = entity?.wikipediaTitles[lang];
      const summary = title ? await sources.wikimedia.wikipediaSummary(lang, title) : null;
      if (summary) {
        place.descriptions[lang] = summary.text;
        place.wikipediaUrls[lang] = summary.url;
      }
    }
  }
  skipped.sort((a, b) => a.rank - b.rank);
  places.sort((a, b) => a.rank - b.rank);
  log(`${city.id}: ${places.length} places, ${skipped.length} skipped`);

  return {
    city,
    collectedAt: new Date().toISOString(),
    candidateCount: seeds.length,
    osmMatched,
    places,
    skipped,
  };
}

/**
 * Searches Wikidata for the catalog name and its variants ("Pantheon
 * (National Pantheon)" -> "Pantheon", "National Pantheon", then with the
 * city name) and returns the first item within [radiusKm] of [near].
 */
async function findOnWikidata(
  name: string,
  cityName: string,
  near: Coordinates,
  radiusKm: number,
  wikimedia: CollectSources["wikimedia"],
): Promise<{ id: string; coordinates: Coordinates } | null> {
  const parts = [
    name.replace(/\([^)]*\)/g, " ").replace(/\s+/g, " ").trim(),
    ...[...name.matchAll(/\(([^)]+)\)/g)].map((m) => m[1].trim()),
  ].filter(Boolean);
  const queries = [...new Set([...parts, ...parts.map((p) => `${p} ${cityName}`)])];
  for (const query of queries) {
    const ids = await wikimedia.searchEntities(query);
    if (ids.length === 0) continue;
    const info = await wikimedia.entityInfo(ids);
    for (const id of ids) {
      const coordinates = info.get(id)?.coordinates;
      if (coordinates && distanceKm(near, coordinates) <= radiusKm) return { id, coordinates };
    }
  }
  return null;
}

function commonsCategory(l: Located, entity: EntityInfo | undefined): string | null {
  const tag = l.osm?.tags.wikimedia_commons;
  if (tag?.startsWith("Category:")) return tag.slice("Category:".length);
  return entity?.commonsCategory ?? null;
}

function knownFiles(l: Located, entity: EntityInfo | undefined): string[] {
  const files = [...(entity?.imageFiles ?? [])];
  const osmFile = l.osm ? osmCommonsFile(l.osm.tags) : null;
  if (osmFile && !files.includes(osmFile)) files.push(osmFile);
  return files;
}

function filesFor(l: Located, files: Map<string, string[]>, info: Map<string, EntityInfo>): string[] {
  const key = l.qid ?? `osm_${l.osm!.type}_${l.osm!.id}`;
  return files.get(key) ?? knownFiles(l, l.qid ? info.get(l.qid) : undefined);
}

function toDraft(
  city: CityConfig,
  l: Located,
  id: string,
  entity: EntityInfo | undefined,
  photos: PhotoDraft[],
  center: Coordinates,
): PlaceDraft {
  const tags = l.osm?.tags ?? {};
  const names: Localized = {
    en: entity?.labels.en ?? tags["name:en"] ?? l.seed.name.replace(/\s*\([^)]*\)\s*/g, " ").trim(),
  };
  const de = entity?.labels.de ?? tags["name:de"];
  if (de) names.de = de;
  const types = typesFor(l.seed.category, tags);
  const address = l.osm ? osmAddress(tags) : null;
  const website = safeWebsite(tags.website ?? tags["contact:website"]);
  return {
    id,
    ...(l.qid ? { wikidataId: l.qid } : {}),
    cityId: city.id,
    rank: l.seed.number,
    catalogName: l.seed.name,
    category: l.seed.category,
    ...(l.osm ? { osm: { type: l.osm.type, id: l.osm.id, url: osmUrl(l.osm) } } : {}),
    ...(address ? { address } : {}),
    ...(tags.opening_hours ? { openingHours: tags.opening_hours } : {}),
    ...(website ? { website } : {}),
    names,
    // The catalog's short English text until a Wikipedia lead is found.
    descriptions: { en: l.seed.description },
    wikipediaUrls: {},
    coordinates: l.coordinates,
    types,
    interests: interestsFor(types),
    popularity: 1000 - l.seed.number,
    distanceKm: Math.round(distanceKm(center, l.coordinates) * 10) / 10,
    photos,
  };
}

function safeWebsite(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value.trim());
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function isQid(value: string | undefined): value is string {
  return Boolean(value && /^Q[1-9]\d*$/.test(value));
}

/**
 * Up to photoCandidates usable files, main image first. Files already used
 * by an earlier place in the city go last, and only the first
 * photosPerPlace (the default selection) are marked as used.
 */
export function choosePhotos(
  fileTitles: string[],
  metadata: Map<string, PhotoMetadata>,
  usedPages: Set<number>,
): PhotoDraft[] {
  const fresh: PhotoDraft[] = [];
  const reused: PhotoDraft[] = [];
  const seen = new Set<number>();
  for (const title of fileTitles) {
    const meta = metadata.get(title);
    if (!meta || seen.has(meta.pageId) || !isUsablePhoto(meta)) continue;
    seen.add(meta.pageId);
    const license = normalizeLicense(meta.licenseShortName, meta.licenseUrl)!;
    (usedPages.has(meta.pageId) ? reused : fresh).push({
      fileTitle: meta.fileTitle,
      pageId: meta.pageId,
      thumbnailUrl: meta.thumbnailUrl,
      filePageUrl: `https://commons.wikimedia.org/wiki/${encodeURIComponent(meta.fileTitle.replace(/ /g, "_"))}`,
      creator: meta.creator || "Unknown",
      licenseName: license.name,
      licenseUrl: license.url,
      width: meta.width,
      height: meta.height,
    });
  }
  const chosen = [...fresh, ...reused].slice(0, DEFAULTS.photoCandidates);
  for (const photo of chosen.slice(0, DEFAULTS.photosPerPlace)) usedPages.add(photo.pageId);
  return chosen;
}

export function isUsablePhoto(meta: PhotoMetadata): boolean {
  const long = Math.max(meta.width, meta.height);
  const short = Math.min(meta.width, meta.height);
  const license = normalizeLicense(meta.licenseShortName, meta.licenseUrl);
  if (!license) return false;
  // Attribution licences need an author to credit.
  if (license.name.startsWith("CC BY") && !meta.creator) return false;
  if (meta.mediaType.toUpperCase() !== "BITMAP" || !IMAGE_MIMES.has(meta.mime.toLowerCase())) return false;
  if (long < DEFAULTS.minLongEdge || short < DEFAULTS.minShortEdge) return false;
  if (!/^https:\/\/(upload|thumb)\.wikimedia\.org\//.test(meta.thumbnailUrl)) return false;
  const text = [meta.fileTitle, meta.description, ...meta.categories].join(" ");
  return !NON_PHOTO.test(text);
}
