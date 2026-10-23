export const USER_AGENT =
  "SwipeTrip-CityImport/1.0 (https://github.com/hamid319/App; curated city import)";

/** Defaults; cities.json can override radiusKm per city. */
export const DEFAULTS = Object.freeze({
  /** Catalog places farther than this from the city centre are not matched. */
  radiusKm: 25,
  photosPerPlace: 3,
  /** Usable photos kept per place for the review to choose from. */
  photoCandidates: 10,
  /** Commons files smaller than this are skipped (blurry on a phone). */
  minLongEdge: 800,
  minShortEdge: 500,
  /** Thumbnail width requested from Commons and the stored WebP size. */
  outputLongEdge: 1280,
  maxImageBytes: 8 * 1024 * 1024,
  descriptionMaxChars: 420,
});

/**
 * App place types for the catalog's categories (strings the Interest enum
 * in lib/common/models/interest.dart understands).
 */
export const CATEGORY_TYPES: Readonly<Record<string, ReadonlyArray<string>>> = {
  "Museum": ["museum"],
  "Gallery": ["art_gallery"],
  "Historic Site": ["historical_landmark"],
  "Religious Site": ["church"],
  "Monument": ["monument"],
  "Park": ["park"],
  "Garden": ["garden"],
  "Viewpoint": ["viewpoint"],
  "Natural Scenery": ["natural_feature"],
};

/** Extra app types from OSM tags, e.g. a park that is also a zoo. */
export const OSM_TAG_TYPES: ReadonlyArray<{ key: string; value: string; type: string }> = [
  { key: "tourism", value: "zoo", type: "zoo" },
  { key: "tourism", value: "aquarium", type: "aquarium" },
  { key: "tourism", value: "theme_park", type: "amusement_park" },
  { key: "tourism", value: "viewpoint", type: "viewpoint" },
  { key: "natural", value: "beach", type: "beach" },
  { key: "amenity", value: "marketplace", type: "market" },
  { key: "amenity", value: "theatre", type: "performing_arts_theater" },
];

/**
 * App interests per place type. Must stay in sync with the Interest enum
 * in lib/common/models/interest.dart (checked by test/mapping.test.ts).
 */
export const INTEREST_TYPES: Readonly<Record<string, ReadonlyArray<string>>> = {
  culture: ["museum", "art_gallery", "art", "culture", "cultural_landmark", "music", "science", "performing_arts_theater"],
  nature: ["park", "nature", "natural_feature", "outdoors", "hiking", "garden", "national_park"],
  history: ["historical_landmark", "landmark", "history", "church", "monument", "architecture", "tourist_attraction"],
  beach: ["beach"],
  views: ["viewpoint", "observation_deck", "photo_spot"],
  family: ["family", "zoo", "aquarium", "amusement_park", "playground"],
  nightlife: ["nightlife", "bar", "night_club"],
  shopping: ["shopping", "market", "shopping_mall"],
};

export const LANGUAGES = ["en", "de"] as const;
