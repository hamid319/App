import type { PipelineLimits } from "./types.js";

export const REGION = "europe-west1";
export const PIPELINE_VERSION = "city-pipeline-v1";

export const LIMITS: Readonly<PipelineLimits> = Object.freeze({
  candidateLimit: 150,
  targetPlaces: 50,
  targetPhotosPerPlace: 3,
  metadataRequests: 200,
  thumbnailAttempts: 200,
  maxImageBytes: 5 * 1024 * 1024,
  maxJobDownloadBytes: 300 * 1024 * 1024,
  attemptRuntimeMs: 20 * 60 * 1000,
  maxAttempts: 3,
  totalRuntimeMs: 60 * 60 * 1000,
  radiusKm: 15,
  // Places with fewer Wikipedia articles are rarely what travellers look for,
  // and the filter keeps the radius queries fast.
  minSitelinks: 3,
  minLongEdge: 640,
  minShortEdge: 320,
  maxOutputLongEdge: 1280,
});

export const ADMISSION_LIMITS = Object.freeze({
  userDaily: 2,
  userMonthly: 10,
  globalDaily: 5,
  globalMonthly: 100,
  freshDays: 30,
  partialEmptyCooldownDays: 7,
  failureCooldownHours: 24,
  storagePauseBytes: 8 * 1024 * 1024 * 1024,
});

export const WIKIMEDIA_USER_AGENT =
  "SwipeTrip/0.1 (https://github.com/hamid319/App; city collection pipeline)";

export const ALLOWED_CITY_ROOT_TYPES = new Set([
  "Q486972", // human settlement
  "Q515", // city
  "Q1549591", // big city
  "Q200250", // metropolis
  "Q1637706", // million city
  "Q133442", // city-state
  "Q5119", // capital
  "Q2264924", // port city
]);

export const ATTRACTION_TYPE_ROOTS = Object.freeze([
  { qid: "Q33506", label: "museum", priority: 0 },
  { qid: "Q4989906", label: "monument", priority: 1 },
  { qid: "Q839954", label: "archaeological site", priority: 2 },
  { qid: "Q24398318", label: "religious building", priority: 3 },
  { qid: "Q1007870", label: "art gallery", priority: 4 },
  { qid: "Q570116", label: "tourist attraction", priority: 5 },
  { qid: "Q22698", label: "park", priority: 6 },
  { qid: "Q1107656", label: "garden", priority: 7 },
  { qid: "Q6017969", label: "viewpoint", priority: 8 },
]);

// Searched in addition to ATTRACTION_TYPE_ROOTS when collecting candidates.
// The radius queries follow one subclass hop for speed, and these sit two
// hops below "religious building" (cathedral -> church building -> religious
// building), so St. Stephen's and Notre-Dame were missed. The classification
// pass still maps them to the attraction roots.
export const EXTRA_DISCOVERY_ROOTS = Object.freeze([
  "Q16970", // church building
  "Q2977", // cathedral
  "Q32815", // mosque
  "Q34627", // synagogue
  "Q44539", // temple
]);

export const EXCLUDED_TYPE_ROOTS = Object.freeze([
  "Q213441", // shop
  "Q11707", // restaurant
  "Q30022", // cafe
  "Q187456", // bar
  "Q27686", // hotel
  "Q11315", // shopping mall
]);
