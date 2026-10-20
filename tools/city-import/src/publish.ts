import { DEFAULTS } from "./config.js";
import type { ProcessedImage } from "./images.js";
import type { CityCollection, CityDoc, PlaceDoc, PlaceDraft, StoredPhoto } from "./model.js";
import type { DataStore, PhotoStore } from "./stores.js";

export interface PublishDeps {
  photos: PhotoStore;
  data: DataStore;
  download: (url: string, maxBytes: number) => Promise<Buffer>;
  convert: (source: Buffer) => Promise<ProcessedImage>;
  log?: (line: string) => void;
  now?: () => Date;
}

export interface CityPublishResult {
  cityId: string;
  published: number;
  hidden: number;
  photosUploaded: number;
  photosReused: number;
  placesWithoutPhotos: number;
}

/**
 * Publishes one reviewed city: photos to R2 (each uploaded once; reruns
 * reuse them), places to Firestore (doc id = wd_<QID>, so reruns update),
 * and hides curated places that dropped out or were excluded. Nothing is
 * deleted.
 */
export async function publishCity(
  collection: CityCollection,
  excludedWikidataIds: ReadonlySet<string>,
  importRunId: string,
  deps: PublishDeps,
): Promise<CityPublishResult> {
  const log = deps.log ?? (() => undefined);
  const now = (deps.now ?? (() => new Date()))().toISOString();
  const cityId = collection.city.id;
  const result: CityPublishResult = {
    cityId,
    published: 0,
    hidden: 0,
    photosUploaded: 0,
    photosReused: 0,
    placesWithoutPhotos: 0,
  };

  const docs: PlaceDoc[] = [];
  for (const draft of collection.places) {
    if (excludedWikidataIds.has(draft.wikidataId)) continue;
    const photos: StoredPhoto[] = [];
    for (const photo of draft.photos) {
      const key = `places/${cityId}/${draft.id}/${photo.pageId}.webp`;
      try {
        let info = await deps.photos.head(key);
        if (info) {
          result.photosReused += 1;
        } else {
          const image = await deps.convert(await deps.download(photo.thumbnailUrl, DEFAULTS.maxImageBytes));
          info = { width: image.width, height: image.height, sha256: image.sha256 };
          await deps.photos.put(key, image.bytes, info, {
            "commons-page-id": String(photo.pageId),
            license: photo.licenseName,
          });
          result.photosUploaded += 1;
        }
        photos.push({
          publicUrl: deps.photos.publicUrl(key),
          objectKey: key,
          creator: photo.creator,
          licenseName: photo.licenseName,
          ...(photo.licenseUrl ? { licenseUrl: photo.licenseUrl } : {}),
          commonsFilePageUrl: photo.filePageUrl,
          commonsPageId: photo.pageId,
          width: info.width,
          height: info.height,
          sha256: info.sha256,
        });
      } catch (error) {
        log(`  photo skipped (${draft.id}, ${photo.fileTitle}): ${(error as Error).message}`);
      }
    }
    if (photos.length === 0) {
      result.placesWithoutPhotos += 1;
      continue;
    }
    docs.push(toPlaceDoc(draft, photos, importRunId, now));
  }

  await deps.data.writePlaces(docs);
  result.published = docs.length;

  const keep = new Set(docs.map((doc) => doc.id));
  const existing = await deps.data.existingPlaces(cityId);
  const toHide = [...existing.entries()]
    .filter(([id, status]) => !keep.has(id) && status !== "hidden")
    .map(([id]) => id);
  await deps.data.hidePlaces(toHide, importRunId);
  result.hidden = toHide.length;

  const city: CityDoc = {
    id: cityId,
    wikidataId: collection.city.wikidataId,
    nameEn: collection.city.nameEn,
    nameDe: collection.city.nameDe,
    countryCode: collection.city.countryCode,
    lat: collection.city.coordinates.lat,
    lng: collection.city.coordinates.lng,
    placeCount: docs.length,
    status: "active",
    importRunId,
    updatedAt: now,
  };
  await deps.data.writeCity(city);
  log(`${cityId}: ${result.published} published, ${result.hidden} hidden, ` +
    `${result.photosUploaded} photos uploaded, ${result.photosReused} reused`);
  return result;
}

export function toPlaceDoc(draft: PlaceDraft, photos: StoredPhoto[], importRunId: string, updatedAt: string): PlaceDoc {
  return {
    id: draft.id,
    source: "wikidata",
    sourceId: draft.wikidataId,
    cityId: draft.cityId,
    status: "active",
    name: draft.names.en ?? draft.names.de ?? draft.wikidataId,
    description: draft.descriptions.en ?? draft.descriptions.de ?? null,
    names: draft.names,
    descriptions: draft.descriptions,
    wikipediaUrls: draft.wikipediaUrls,
    lat: draft.coordinates.lat,
    lng: draft.coordinates.lng,
    types: draft.types,
    interests: draft.interests,
    popularity: draft.popularity,
    imageUrls: photos.map((photo) => photo.publicUrl),
    photos,
    importRunId,
    updatedAt,
  };
}
