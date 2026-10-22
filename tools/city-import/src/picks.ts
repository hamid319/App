// Review decisions kept next to the code, so they survive a new collect:
//   photo-picks.json  { "places": { "<placeId>": [commonsPageId, ...] } }
//                     the photos to publish, in order; the first is the cover
//   exclusions.json   { "places": { "<cityId>": ["<placeId>", ...] } }

import { DEFAULTS } from "./config.js";
import type { PhotoDraft, PlaceDraft } from "./model.js";

/** placeId -> Commons page ids picked in review, cover first. */
export type PhotoPicks = Record<string, number[]>;

/**
 * The photos to publish for [place]: the picked candidates in pick order,
 * or the first photosPerPlace candidates when nothing (still available)
 * was picked.
 */
export function selectPhotos(place: PlaceDraft, picks: PhotoPicks): PhotoDraft[] {
  const byPage = new Map(place.photos.map((photo) => [photo.pageId, photo]));
  const picked = (picks[place.id] ?? [])
    .map((pageId) => byPage.get(pageId))
    .filter((photo): photo is PhotoDraft => photo !== undefined)
    .slice(0, DEFAULTS.photosPerPlace);
  return picked.length > 0 ? picked : place.photos.slice(0, DEFAULTS.photosPerPlace);
}

/** A smaller Commons thumbnail of the same file, for review pages. */
export function previewUrl(thumbnailUrl: string, width = 500): string {
  return thumbnailUrl.replace(/\/\d+px-([^/?]+)(\?.*)?$/, `/${width}px-$1`);
}
