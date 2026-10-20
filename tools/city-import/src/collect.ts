import { DEFAULTS } from "./config.js";
import { normalizeLicense } from "./licenses.js";
import { appTypesFor, interestsFor } from "./mapping.js";
import type { CityCollection, CityConfig, Lang, Localized, PhotoDraft, PlaceDraft } from "./model.js";
import type { Candidate, EntityInfo, PhotoMetadata, WikimediaSource, WikipediaSummary } from "./wikimedia.js";

/** The parts of WikimediaSource collect needs (a fake in tests). */
export type CollectSource = Pick<
  WikimediaSource,
  "cityLocation" | "findCandidates" | "entityInfo" | "wikipediaSummary" | "photoFiles" | "photoMetadata"
>;

const NON_PHOTO = /\b(maps?|locator|logos?|flags?|coats? of arms|diagrams?|plans?|drawings?|engravings?|paintings?|postcards?|stamps?|svg)\b/i;
/** Candidates whose photos are looked up together. */
const PHOTO_ROUND = 30;
const IMAGE_MIMES = new Set(["image/jpeg", "image/png", "image/webp"]);

export async function collectCity(
  city: CityConfig,
  source: CollectSource,
  log: (line: string) => void = () => undefined,
): Promise<CityCollection> {
  const radiusKm = city.radiusKm ?? DEFAULTS.radiusKm;
  const targetPlaces = city.targetPlaces ?? DEFAULTS.targetPlaces;
  const minSitelinks = city.minSitelinks ?? DEFAULTS.minSitelinks;

  const { coordinates, countryQid } = await source.cityLocation(city.wikidataId);
  const candidates = await source.findCandidates(coordinates, countryQid, {
    radiusKm,
    minSitelinks,
    limit: DEFAULTS.candidateLimit,
  });
  log(`${city.id}: ${candidates.length} candidates`);

  const info = await source.entityInfo(candidates.map((c) => c.wikidataId));
  const places: PlaceDraft[] = [];
  const skipped: CityCollection["skipped"] = [];
  const usedPages = new Set<number>();

  // Look up photos in rounds of the best-known candidates and stop once the
  // city is full, so a city costs only the requests it needs.
  const named = candidates.filter((candidate) => {
    const entity = info.get(candidate.wikidataId);
    if (entity?.labels.en ?? entity?.labels.de) return true;
    skipped.push({ wikidataId: candidate.wikidataId, name: candidate.wikidataId, reason: "no name" });
    return false;
  });
  for (let start = 0; start < named.length && places.length < targetPlaces; start += PHOTO_ROUND) {
    const round = named.slice(start, start + PHOTO_ROUND);
    const files = await source.photoFiles(round);
    const metadata = await source.photoMetadata([...new Set([...files.values()].flat())]);
    for (const candidate of round) {
      if (places.length >= targetPlaces) break;
      const entity = info.get(candidate.wikidataId)!;
      const photos = choosePhotos(files.get(candidate.wikidataId) ?? [], metadata, usedPages);
      if (photos.length === 0) {
        skipped.push({ wikidataId: candidate.wikidataId, name: entity.labels.en ?? entity.labels.de!, reason: "no usable photo" });
        continue;
      }
      places.push(toDraft(city.id, candidate, entity, photos));
    }
  }

  // Wikipedia lead paragraphs only for places we keep.
  for (const place of places) {
    const entity = info.get(place.wikidataId)!;
    for (const lang of ["en", "de"] as Lang[]) {
      const title = entity.wikipediaTitles[lang];
      const summary: WikipediaSummary | null = title ? await source.wikipediaSummary(lang, title) : null;
      if (summary) {
        place.descriptions[lang] = summary.text;
        place.wikipediaUrls[lang] = summary.url;
      }
    }
  }
  log(`${city.id}: ${places.length} places, ${skipped.length} skipped`);

  return {
    city: { ...city, coordinates, countryQid },
    collectedAt: new Date().toISOString(),
    candidateCount: candidates.length,
    places,
    skipped,
  };
}

function toDraft(cityId: string, candidate: Candidate, entity: EntityInfo, photos: PhotoDraft[]): PlaceDraft {
  const types = appTypesFor(candidate.classQids);
  // Wikidata's short description is the fallback until a Wikipedia lead is found.
  const descriptions: Localized = {};
  for (const lang of ["en", "de"] as Lang[]) {
    const short = entity.descriptions[lang];
    if (short) descriptions[lang] = capitalize(short);
  }
  return {
    id: `wd_${candidate.wikidataId}`,
    wikidataId: candidate.wikidataId,
    cityId,
    names: entity.labels,
    descriptions,
    wikipediaUrls: {},
    coordinates: candidate.coordinates,
    types,
    interests: interestsFor(types),
    popularity: candidate.sitelinks,
    distanceKm: Math.round(candidate.distanceKm * 10) / 10,
    photos,
  };
}

/** Up to photosPerPlace usable files, main image first, no file used twice in a city. */
export function choosePhotos(
  fileTitles: string[],
  metadata: Map<string, PhotoMetadata>,
  usedPages: Set<number>,
): PhotoDraft[] {
  const chosen: PhotoDraft[] = [];
  for (const title of fileTitles) {
    if (chosen.length >= DEFAULTS.photosPerPlace) break;
    const meta = metadata.get(title);
    if (!meta || usedPages.has(meta.pageId) || !isUsablePhoto(meta)) continue;
    const license = normalizeLicense(meta.licenseShortName, meta.licenseUrl)!;
    usedPages.add(meta.pageId);
    chosen.push({
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

function capitalize(text: string): string {
  return text ? text.charAt(0).toUpperCase() + text.slice(1) : text;
}
