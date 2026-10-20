// Data model shared by the three steps: collect -> report -> publish.
//
// Firestore (written only by `publish`, read by the app):
//   cities/{cityId}   one document per curated city (CityDoc)
//   places/{placeId}  flat collection, placeId = "wd_<QID>" (PlaceDoc)
//   importRuns/{id}   audit log of every publish run (not readable by clients)
//
// cityId matches the app's PopularCity ids (e.g. "pt_lisbon"), so the city
// picker, groups and the import all use the same key.

export type Lang = "en" | "de";
export type Localized = Partial<Record<Lang, string>>;

/** One entry of cities.json: what the team decided to import. */
export interface CityConfig {
  id: string;
  wikidataId: string;
  nameEn: string;
  nameDe: string;
  countryCode: string;
  /** Overrides the defaults in config.ts for this city. */
  radiusKm?: number;
  targetPlaces?: number;
  minSitelinks?: number;
}

export interface Coordinates {
  lat: number;
  lng: number;
}

/** A photo chosen during collect (metadata only, nothing downloaded yet). */
export interface PhotoDraft {
  fileTitle: string;
  pageId: number;
  thumbnailUrl: string;
  filePageUrl: string;
  creator: string;
  licenseName: string;
  licenseUrl?: string;
  width: number;
  height: number;
}

/** A place as collected; written to out/<cityId>.json for review. */
export interface PlaceDraft {
  id: string;
  wikidataId: string;
  cityId: string;
  names: Localized;
  descriptions: Localized;
  wikipediaUrls: Localized;
  coordinates: Coordinates;
  /** App place types (see mapping.ts), e.g. "museum", "park". */
  types: string[];
  /** App interests derived from types, e.g. "culture", "nature". */
  interests: string[];
  /** Number of Wikipedia language editions: our popularity signal. */
  popularity: number;
  distanceKm: number;
  photos: PhotoDraft[];
}

export interface CityCollection {
  city: CityConfig & { coordinates: Coordinates; countryQid: string };
  collectedAt: string;
  candidateCount: number;
  places: PlaceDraft[];
  /** Candidates dropped and why, for the report. */
  skipped: Array<{ wikidataId: string; name: string; reason: string }>;
}

/** Stored photo, as read by the app's PhotoCredit (lib/common/models/photo_credit.dart). */
export interface StoredPhoto {
  publicUrl: string;
  objectKey: string;
  creator: string;
  licenseName: string;
  licenseUrl?: string;
  commonsFilePageUrl: string;
  commonsPageId: number;
  width: number;
  height: number;
  sha256: string;
}

/** places/{placeId}. Field names follow the app's PlaceModel. */
export interface PlaceDoc {
  id: string;
  source: "wikidata";
  sourceId: string;
  cityId: string;
  status: "active" | "hidden";
  /** English name/description for older app versions; names/descriptions per language. */
  name: string;
  description: string | null;
  names: Localized;
  descriptions: Localized;
  /** Wikipedia article per language; the description text comes from there (CC BY-SA). */
  wikipediaUrls: Localized;
  lat: number;
  lng: number;
  types: string[];
  interests: string[];
  popularity: number;
  imageUrls: string[];
  photos: StoredPhoto[];
  importRunId: string;
  updatedAt: string;
}

/** cities/{cityId}. */
export interface CityDoc {
  id: string;
  wikidataId: string;
  nameEn: string;
  nameDe: string;
  countryCode: string;
  lat: number;
  lng: number;
  placeCount: number;
  status: "active";
  importRunId: string;
  updatedAt: string;
}
