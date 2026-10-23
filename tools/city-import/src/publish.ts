import { BudgetExceeded } from "./budget.js";
import { DEFAULTS } from "./config.js";
import type { ProcessedImage } from "./images.js";
import type { CityCollection, CityDoc, PlaceDoc, PlaceDraft, StoredPhoto } from "./model.js";
import { selectPhotos, type PhotoPicks } from "./picks.js";
import type { DataStore, PhotoStore } from "./stores.js";

export interface PublishDeps {
  photos: PhotoStore;
  data: DataStore;
  download: (url: string, maxBytes: number) => Promise<Buffer>;
  convert: (source: Buffer) => Promise<ProcessedImage>;
  /** Photos picked in review (photo-picks.json); unpicked places use the first candidates. */
  picks?: PhotoPicks;
  log?: (line: string) => void;
  now?: () => Date;
  /** Throws BudgetExceeded before an upload would leave the R2 free tier. */
  reserveUpload?: (bytes: number) => void;
}

export interface CityPublishResult {
  cityId: string;
  published: number;
  hidden: number;
  photosUploaded: number;
  photosReused: number;
  placesWithoutPhotos: number;
  /** Venues published (included in [published]) and how many of them have no photo. */
  venues: number;
  venuesWithoutPhotos: number;
}

/**
 * Publishes one reviewed city: photos to R2 (each uploaded once; reruns
 * reuse them), places to Firestore (doc id = wd_<QID>, so reruns update),
 * and hides curated places that dropped out or were excluded. Nothing is
 * deleted.
 */
export async function publishCity(
  collection: CityCollection,
  /** Place ids (wd_Q123 / osm_way_456) the team removed after review. */
  excludedIds: ReadonlySet<string>,
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
    venues: 0,
    venuesWithoutPhotos: 0,
  };

  const docs: PlaceDoc[] = [];
  const venueIds = new Set((collection.venues ?? []).map((v) => v.id));
  const sightIds = new Set(collection.places.map((p) => p.id));
  const drafts = [
    ...collection.places,
    // A venue that is also a sight is published once, as the sight.
    ...(collection.venues ?? []).filter((v) => !sightIds.has(v.id)),
  ];
  for (const draft of drafts) {
    if (excludedIds.has(draft.id)) continue;
    const isVenue = draft.kind === "venue" && venueIds.has(draft.id);
    const photos: StoredPhoto[] = [];
    for (const photo of selectPhotos(draft, deps.picks ?? {})) {
      const key = `places/${cityId}/${draft.id}/${photo.pageId}.webp`;
      try {
        let info = await deps.photos.head(key);
        if (info) {
          result.photosReused += 1;
        } else {
          const image = await deps.convert(await deps.download(photo.thumbnailUrl, DEFAULTS.maxImageBytes));
          info = { width: image.width, height: image.height, sha256: image.sha256 };
          deps.reserveUpload?.(image.bytes.length);
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
        if (error instanceof BudgetExceeded) throw error;
        log(`  photo skipped (${draft.id}, ${photo.fileTitle}): ${(error as Error).message}`);
      }
    }
    if (isVenue) {
      // The app draws a placeholder for venues without a photo.
      result.venues += 1;
      if (photos.length === 0) result.venuesWithoutPhotos += 1;
    } else if (photos.length === 0) {
      result.placesWithoutPhotos += 1;
      continue;
    }
    docs.push(toPlaceDoc(draft, photos, importRunId, now));
  }

  await deps.data.writePlaces(docs);
  result.published = docs.length;
  const sightCount = docs.filter((d) => d.kind === "sight").length;

  const keep = new Set(docs.map((doc) => doc.id));
  const existing = await deps.data.existingPlaces(cityId);
  const toHide = [...existing.entries()]
    .filter(([id, status]) => !keep.has(id) && status !== "hidden")
    .map(([id]) => id);
  await deps.data.hidePlaces(toHide, importRunId);
  result.hidden = toHide.length;

  const city: CityDoc = {
    id: cityId,
    nameEn: collection.city.nameEn,
    nameDe: collection.city.nameDe,
    countryCode: collection.city.countryCode,
    lat: collection.city.lat,
    lng: collection.city.lng,
    placeCount: sightCount,
    status: "active",
    importRunId,
    updatedAt: now,
  };
  await deps.data.writeCity(city);
  log(`${cityId}: ${result.published} published (${result.venues} venues), ${result.hidden} hidden, ` +
    `${result.photosUploaded} photos uploaded, ${result.photosReused} reused`);
  return result;
}

export function toPlaceDoc(draft: PlaceDraft, photos: StoredPhoto[], importRunId: string, updatedAt: string): PlaceDoc {
  return {
    id: draft.id,
    source: "wikidata",
    sourceId: draft.wikidataId ?? `${draft.osm?.type}/${draft.osm?.id}`,
    cityId: draft.cityId,
    status: "active",
    kind: draft.kind ?? "sight",
    // No undefined fields: Firestore rejects them.
    ...(draft.kind === "venue" && draft.cuisine ? { cuisine: draft.cuisine } : {}),
    name: draft.names.en ?? draft.names.de ?? draft.catalogName,
    description: draft.descriptions.en ?? draft.descriptions.de ?? null,
    names: draft.names,
    descriptions: draft.descriptions,
    wikipediaUrls: draft.wikipediaUrls,
    lat: draft.coordinates.lat,
    lng: draft.coordinates.lng,
    types: draft.types,
    interests: draft.interests,
    popularity: draft.popularity,
    address: draft.address ?? null,
    openingHours: draft.openingHours ?? null,
    website: draft.website ?? null,
    osmUrl: draft.osm?.url ?? null,
    imageUrls: photos.map((photo) => photo.publicUrl),
    photos,
    importRunId,
    updatedAt,
  };
}
