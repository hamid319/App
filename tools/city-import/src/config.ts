export const USER_AGENT =
  "SwipeTrip-CityImport/1.0 (https://github.com/hamid319/App; curated city import)";

/** Defaults; cities.json can override radiusKm, targetPlaces and minSitelinks per city. */
export const DEFAULTS = Object.freeze({
  radiusKm: 15,
  targetPlaces: 60,
  /** Candidates kept per city before photos are checked. */
  candidateLimit: 250,
  /** Minimum Wikipedia language editions: filters out obscure places. */
  minSitelinks: 3,
  photosPerPlace: 3,
  /** Commons files smaller than this are skipped (blurry on a phone). */
  minLongEdge: 800,
  minShortEdge: 500,
  /** Thumbnail width requested from Commons and the stored WebP size. */
  outputLongEdge: 1280,
  maxImageBytes: 8 * 1024 * 1024,
  descriptionMaxChars: 420,
});

/**
 * Wikidata classes we search for, each mapped to the app's place type
 * (the strings Interest in lib/common/models/interest.dart understands).
 * Order is the tie-breaker when a place matches several classes.
 */
export const DISCOVERY_CLASSES: ReadonlyArray<{ qid: string; label: string; appType: string }> = [
  { qid: "Q33506", label: "museum", appType: "museum" },
  { qid: "Q1007870", label: "art gallery", appType: "art_gallery" },
  { qid: "Q24354", label: "theatre", appType: "performing_arts_theater" },
  { qid: "Q23413", label: "castle", appType: "historical_landmark" },
  { qid: "Q16560", label: "palace", appType: "historical_landmark" },
  { qid: "Q839954", label: "archaeological site", appType: "historical_landmark" },
  { qid: "Q57821", label: "fortification", appType: "historical_landmark" },
  { qid: "Q44613", label: "monastery", appType: "historical_landmark" },
  { qid: "Q4989906", label: "monument", appType: "monument" },
  { qid: "Q2977", label: "cathedral", appType: "church" },
  { qid: "Q16970", label: "church", appType: "church" },
  { qid: "Q32815", label: "mosque", appType: "church" },
  { qid: "Q34627", label: "synagogue", appType: "church" },
  { qid: "Q44539", label: "temple", appType: "church" },
  { qid: "Q12280", label: "bridge", appType: "landmark" },
  { qid: "Q12518", label: "tower", appType: "landmark" },
  { qid: "Q174782", label: "square", appType: "landmark" },
  { qid: "Q22698", label: "park", appType: "park" },
  { qid: "Q1107656", label: "garden", appType: "garden" },
  { qid: "Q6017969", label: "viewpoint", appType: "viewpoint" },
  { qid: "Q40080", label: "beach", appType: "beach" },
  { qid: "Q43501", label: "zoo", appType: "zoo" },
  { qid: "Q2281788", label: "aquarium", appType: "aquarium" },
  { qid: "Q194195", label: "amusement park", appType: "amusement_park" },
  { qid: "Q132510", label: "market", appType: "market" },
  { qid: "Q570116", label: "tourist attraction", appType: "tourist_attraction" },
];

/** Never imported even when they match a class above (businesses). */
export const EXCLUDED_CLASSES: ReadonlyArray<string> = [
  "Q213441", // shop
  "Q11707", // restaurant
  "Q30022", // cafe
  "Q187456", // bar
  "Q27686", // hotel
  "Q11315", // shopping mall
  "Q3914", // school
  "Q3918", // university
  "Q16917", // hospital
  "Q55488", // railway station
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
