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
  nightlife: ["nightlife", "bar", "pub", "night_club"],
  food: ["restaurant", "cafe", "biergarten"],
  shopping: ["shopping", "market", "shopping_mall"],
};

export const LANGUAGES = ["en", "de"] as const;

/**
 * Evening and food venues ("Heute Abend" in the app), picked from
 * OpenStreetMap by a notability score instead of a hand-made catalog.
 */
export const VENUES = Object.freeze({
  /** At most this many venues per city. */
  maxPerCity: 40,
  /** Only venues this close to the city centre (cities.json venueRadiusKm overrides). */
  radiusKm: 5,
  /** A name found this often in the area is treated as a chain without brand tags. */
  chainNameCount: 3,
});

/** App place type per OSM amenity value. */
export const VENUE_AMENITY_TYPES: Readonly<Record<string, string>> = {
  restaurant: "restaurant",
  cafe: "cafe",
  bar: "bar",
  pub: "pub",
  biergarten: "biergarten",
  nightclub: "night_club",
};

/** App interest per venue type. */
export const VENUE_TYPE_INTERESTS: Readonly<Record<string, string>> = {
  restaurant: "food",
  cafe: "food",
  biergarten: "food",
  bar: "nightlife",
  pub: "nightlife",
  night_club: "nightlife",
};

/** Caps per group of venue types, so a city is not 40 restaurants. */
export const VENUE_CAPS: ReadonlyArray<{ types: ReadonlyArray<string>; max: number }> = [
  { types: ["restaurant"], max: 15 },
  { types: ["cafe"], max: 10 },
  { types: ["bar", "pub"], max: 12 },
  { types: ["biergarten"], max: 5 },
  { types: ["night_club"], max: 5 },
];

/**
 * Notability points; the sum maps to popularity 0..VENUE_MAX_POPULARITY.
 * Each criterion outweighs all the later ones together, so the order is
 * strict: Wikidata item > Commons photo > opening hours > website >
 * cuisine or description > closeness.
 */
export const VENUE_SCORE = Object.freeze({
  wikidata: 200,
  photo: 60,
  openingHours: 25,
  website: 12,
  /** cuisine or description tag (once). */
  details: 6,
  /** Full points at the centre, none at the radius. */
  closeness: 5,
});

/** Venues always rank below sights (sights use 1000 - rank, so >= 950). */
export const VENUE_MAX_POPULARITY = 499;
