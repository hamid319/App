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

/** One entry of cities.json: a city the team decided to offer. */
export interface CityConfig {
  id: string;
  /** City id in catalog.json (the curated attraction list). */
  catalogId: string;
  nameEn: string;
  nameDe: string;
  countryCode: string;
  lat: number;
  lng: number;
  /** Overrides DEFAULTS.radiusKm for this city. */
  radiusKm?: number;
  /** Overrides VENUES.radiusKm for this city. */
  venueRadiusKm?: number;
}

/** One curated attraction from catalog.json. */
export interface CatalogAttraction {
  id: string;
  number: number;
  name: string;
  category: string;
  description: string;
  /** German version of [description], for places without a German Wikipedia article. */
  descriptionDe?: string;
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

/** "sight": curated catalog attraction; "venue": restaurant, café, bar ... picked from OSM. */
export type PlaceKind = "sight" | "venue";

/** A place as collected; written to out/<cityId>.json for review. */
export interface PlaceDraft {
  /** wd_<QID> when the place has a Wikidata item, else osm_<type>_<id>. */
  id: string;
  /** Missing in files collected before venues existed: a sight. */
  kind?: PlaceKind;
  /** Venues: first value of the OSM cuisine tag, e.g. "portuguese". */
  cuisine?: string;
  wikidataId?: string;
  cityId: string;
  /** Position in the curated catalog (1 = first); venues: position by score. */
  rank: number;
  /** Venues: the OSM name. */
  catalogName: string;
  /** Venues: the app type (restaurant, cafe, ...). */
  category: string;
  osm?: { type: string; id: number; url: string };
  address?: string;
  openingHours?: string;
  website?: string;
  names: Localized;
  descriptions: Localized;
  wikipediaUrls: Localized;
  coordinates: Coordinates;
  /** App place types (see mapping.ts), e.g. "museum", "park". */
  types: string[];
  /** App interests derived from types, e.g. "culture", "nature". */
  interests: string[];
  /** Sights: 1000 - rank (>= 950). Venues: 0..499 from the notability score. */
  popularity: number;
  distanceKm: number;
  /** Photo candidates, best guess first. publish takes the ones picked in
   *  review (photo-picks.json), else the first DEFAULTS.photosPerPlace. */
  photos: PhotoDraft[];
}

export interface CityCollection {
  city: CityConfig;
  collectedAt: string;
  /** Size of the curated list for this city. */
  candidateCount: number;
  /** How many catalog names were found on OpenStreetMap. */
  osmMatched: number;
  places: PlaceDraft[];
  /** Catalog entries dropped and why, for the report. */
  skipped: Array<{ rank: number; name: string; reason: string }>;
  /** Evening/food venues from OSM (missing in files collected before venues existed). */
  venues?: PlaceDraft[];
  /** How many OSM venues were downloaded and how many survived the chain filter. */
  venueCandidates?: { downloaded: number; eligible: number };
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
  /** "wikidata" for every curated place (also those found only on OSM), so rules treat them alike. */
  source: "wikidata";
  /** Wikidata QID, or the OSM element ("way/123") when there is none. */
  sourceId: string;
  cityId: string;
  status: "active" | "hidden";
  /** The app treats a missing kind as "sight". */
  kind: PlaceKind;
  /** Venues only: OSM cuisine (first value). */
  cuisine?: string;
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
  address: string | null;
  openingHours: string | null;
  website: string | null;
  /** OpenStreetMap element the facts come from; the app credits © OpenStreetMap. */
  osmUrl: string | null;
  imageUrls: string[];
  photos: StoredPhoto[];
  importRunId: string;
  updatedAt: string;
}

/** cities/{cityId}. */
export interface CityDoc {
  id: string;
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
