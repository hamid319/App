// SwipeTrip city import: the curated catalog (catalog.json) placed on
// OpenStreetMap and enriched from Wikidata, Wikipedia and Commons.
//
//   npm run collect -- [--city pt_lisbon]   Wikidata/Wikipedia/Commons -> out/<cityId>.json
//   npm run report                          out/*.json -> out/report.html (review)
//   npm run review -- [--port 4173]         local page to pick photos and exclude
//                                           places -> photo-picks.json, exclusions.json
//   npm run publish -- [--city pt_lisbon] [--dry-run]
//                                           out/*.json -> R2 photos + Firestore
//
// collect, report and review need no credentials. publish reads R2 settings from
// .env (see .env.example) and uses Google application default credentials
// (or GOOGLE_APPLICATION_CREDENTIALS) for Firestore.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { collectCity } from "./collect.js";
import { WikimediaHttp } from "./http.js";
import { DEFAULT_LIMITS, UploadBudget, gb } from "./budget.js";
import { toWebp } from "./images.js";
import type { CatalogAttraction, CityCollection, CityConfig } from "./model.js";
import { fetchCityPlaces, fetchCityVenues } from "./osm.js";
import type { OvertureRow } from "./overture.js";
import { selectPhotos } from "./picks.js";
import { publishCity, toPlaceDoc } from "./publish.js";
import { buildSearchDocs } from "./search.js";
import { buildTiles } from "./tiles.js";
import { renderReport } from "./report.js";
import { readPicks, startReview } from "./review.js";
import { FirestoreDataStore, R2PhotoStore } from "./stores.js";
import { WikimediaSource } from "./wikimedia.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "out");
const FIREBASE_PROJECT_ID = "travelapp-31255";

const readJson = <T>(path: string): T => JSON.parse(readFileSync(path, "utf8")) as T;

function args() {
  const argv = process.argv.slice(2);
  const command = argv[0];
  const cityIndex = argv.indexOf("--city");
  const portIndex = argv.indexOf("--port");
  return {
    command,
    cityIds: cityIndex >= 0 ? (argv[cityIndex + 1] ?? "").split(",").filter(Boolean) : [],
    dryRun: argv.includes("--dry-run"),
    port: portIndex >= 0 ? Number(argv[portIndex + 1]) : 4173,
  };
}

function selectedCities(cityIds: string[]): CityConfig[] {
  const all = readJson<CityConfig[]>(join(ROOT, "cities.json"));
  if (cityIds.length === 0) return all;
  const unknown = cityIds.filter((id) => !all.some((c) => c.id === id));
  if (unknown.length) throw new Error(`Not in cities.json: ${unknown.join(", ")}`);
  return all.filter((c) => cityIds.includes(c.id));
}

const EXCLUSIONS = join(ROOT, "exclusions.json");
const PICKS = join(ROOT, "photo-picks.json");

function exclusions(): Record<string, string[]> {
  return readJson<{ places: Record<string, string[]> }>(EXCLUSIONS).places ?? {};
}

function collectedCities(cities: CityConfig[]): CityCollection[] {
  return cities
    .filter((c) => existsSync(join(OUT, `${c.id}.json`)))
    .map((c) => loadCollection(c.id));
}

function loadCollection(cityId: string): CityCollection {
  const path = join(OUT, `${cityId}.json`);
  if (!existsSync(path)) throw new Error(`${cityId}: run "npm run collect -- --city ${cityId}" first`);
  return readJson<CityCollection>(path);
}

async function collect(cities: CityConfig[]) {
  mkdirSync(OUT, { recursive: true });
  const http = new WikimediaHttp();
  const wikimedia = new WikimediaSource(http);
  const catalog = readJson<{ cities: Array<{ id: string; attractions: CatalogAttraction[] }> }>(join(ROOT, "catalog.json"));
  const excluded = exclusions();
  for (const city of cities) {
    try {
      const attractions = catalog.cities.find((c) => c.id === city.catalogId)?.attractions;
      if (!attractions) throw new Error(`catalog.json has no city "${city.catalogId}"`);
      // Optional second venue source, exported by scripts/overture.sh.
      const overturePath = join(ROOT, "data", "overture", `${city.id}.json`);
      const overtureRows = existsSync(overturePath) ? readJson<OvertureRow[]>(overturePath) : undefined;
      const collection = await collectCity(city, attractions, {
        wikimedia,
        overtureRows,
        osmPlaces: (center, radiusKm) => fetchCityPlaces(http, center, radiusKm),
        osmVenues: (center, radiusKm) => fetchCityVenues(http, center, radiusKm),
      }, console.log, new Set(excluded[city.id] ?? []));
      writeFileSync(join(OUT, `${city.id}.json`), JSON.stringify(collection, null, 2));
    } catch (error) {
      console.error(`${city.id}: failed – ${(error as Error).message}`);
      process.exitCode = 1;
    }
  }
  console.log(`${http.requestCount} requests to Wikimedia`);
}

function report(cities: CityConfig[]) {
  const path = join(OUT, "report.html");
  writeFileSync(path, renderReport(collectedCities(cities), exclusions(), readPicks(PICKS)));
  console.log(`Report: ${path}`);
}

async function review(cities: CityConfig[], port: number) {
  if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error(`Invalid --port ${port}`);
  const url = await startReview({ picksPath: PICKS, exclusionsPath: EXCLUSIONS, loadCollections: () => collectedCities(cities) }, port);
  console.log(`Review: ${url}  (Ctrl+C to stop)`);
}

function requireEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is missing (see .env.example)`);
  return value;
}

async function publish(cities: CityConfig[], dryRun: boolean) {
  const excluded = exclusions();
  const picks = readPicks(PICKS);
  const collections = cities.map((c) => loadCollection(c.id));
  if (dryRun) {
    for (const c of collections) {
      const skip = new Set(excluded[c.city.id] ?? []);
      const places = c.places.filter((p) => !skip.has(p.id));
      const sightIds = new Set(c.places.map((p) => p.id));
      const extras = (c.extras ?? []).filter((e) => !skip.has(e.id) && !sightIds.has(e.id));
      for (const e of extras) sightIds.add(e.id);
      const venues = (c.venues ?? []).filter((v) => !skip.has(v.id) && !sightIds.has(v.id));
      const photos = [...places, ...extras, ...venues].reduce((sum, p) => sum + selectPhotos(p, picks).length, 0);
      const picked = [...places, ...venues].filter((p) => picks[p.id]?.length).length;
      const byType = Object.entries(
        venues.reduce<Record<string, number>>((acc, v) => ({ ...acc, [v.category]: (acc[v.category] ?? 0) + 1 }), {}),
      ).map(([type, n]) => `${n} ${type}`).join(", ");
      const venuePhotos = venues.filter((v) => v.photos.length > 0).length;
      const fromOverture = venues.filter((v) => v.overtureId).length;
      const tiles = buildTiles(c.city.id, [...places, ...extras, ...venues].map((d) => toPlaceDoc(d, [], "dry-run", "")), "dry-run", "");
      const tileKb = tiles.map((t) => Math.round(Buffer.byteLength(JSON.stringify(t)) / 1024));
      console.log(`${c.city.id}: ${tiles.length} tiles, largest ${Math.max(0, ...tileKb)} KB, total ${tileKb.reduce((a, b) => a + b, 0)} KB`);
      console.log(`${c.city.id}: would publish ${places.length} places, ${extras.length} extra sights ` +
        `(${extras.filter((e) => e.photos.length).length} with photos) and ${venues.length} venues ` +
        `(${fromOverture} from Overture) ` +
        `(${venuePhotos} with photos${byType ? `; ${byType}` : ""}) with up to ${photos} photos ` +
        `(${picked} with photos picked in review)` +
        (c.venues ? "" : " – no venues collected yet, run collect again"));
    }
    return;
  }

  if (existsSync(join(ROOT, ".env"))) process.loadEnvFile(join(ROOT, ".env"));
  const photos = new R2PhotoStore({
    accountId: requireEnv("R2_ACCOUNT_ID"),
    accessKeyId: requireEnv("R2_ACCESS_KEY_ID"),
    secretAccessKey: requireEnv("R2_SECRET_ACCESS_KEY"),
    bucket: requireEnv("R2_BUCKET"),
    publicBaseUrl: requireEnv("R2_PUBLIC_BASE_URL"),
  });
  const { initializeApp, applicationDefault } = await import("firebase-admin/app");
  const { getFirestore } = await import("firebase-admin/firestore");
  const app = initializeApp({ credential: applicationDefault(), projectId: FIREBASE_PROJECT_ID });
  const data = new FirestoreDataStore(getFirestore(app));
  const http = new WikimediaHttp();

  const limits = {
    maxBucketBytes: Number(process.env.R2_MAX_BUCKET_GB ?? 5) * 1024 ** 3,
    maxUploadsPerRun: Number(process.env.R2_MAX_UPLOADS_PER_RUN ?? DEFAULT_LIMITS.maxUploadsPerRun),
  };
  const budget = new UploadBudget(await photos.totalBytes(), limits);
  console.log(`R2 bucket holds ${gb(budget.usedBytes)} (limit ${gb(limits.maxBucketBytes)})`);

  const runId = new Date().toISOString().replace(/[:.]/g, "-");
  await data.writeRun(runId, { startedAt: new Date().toISOString(), cities: cities.map((c) => c.id), status: "running" });
  const results = [];
  try {
    for (const collection of collections) {
      results.push(await publishCity(collection, new Set(excluded[collection.city.id] ?? []), runId, {
        photos,
        data,
        download: (url, max) => http.image(url, max),
        convert: toWebp,
        picks,
        log: console.log,
        reserveUpload: (bytes) => budget.reserve(bytes),
      }));
    }
    await data.writeRun(runId, { finishedAt: new Date().toISOString(), status: "done", results });
    console.log(`Uploaded ${budget.uploadCount} photos; bucket now holds ${gb(budget.usedBytes)}`);
  } catch (error) {
    await data.writeRun(runId, { finishedAt: new Date().toISOString(), status: "failed", error: (error as Error).message, results });
    throw error;
  }
  console.log(`Import run ${runId} done.`);
}

/** Writes the search index from the places already in Firestore (no photo work). */
async function searchIndex(cities: Array<{ id: string }>) {
  const { initializeApp, applicationDefault } = await import("firebase-admin/app");
  const { getFirestore } = await import("firebase-admin/firestore");
  const app = initializeApp({ credential: applicationDefault(), projectId: FIREBASE_PROJECT_ID });
  const data = new FirestoreDataStore(getFirestore(app));
  const now = new Date().toISOString();
  for (const city of cities) {
    const parts = buildSearchDocs(city.id, await data.placesForSearch(city.id), `search-${now}`, now);
    await data.replaceSearch(city.id, parts);
    console.log(`${city.id}: ${parts.reduce((n, p) => n + p.entries.length, 0)} places in ${parts.length} search parts`);
  }
}

async function main() {
  const { command, cityIds, dryRun, port } = args();
  const cities = selectedCities(cityIds);
  if (command === "collect") await collect(cities);
  else if (command === "report") report(cities);
  else if (command === "review") await review(cities, port);
  else if (command === "publish") await publish(cities, dryRun);
  else if (command === "search-index") await searchIndex(cities);
  else throw new Error("Usage: cli.ts collect|report|review|publish|search-index [--city id,id] [--dry-run] [--port 4173]");
}

main().catch((error) => {
  console.error((error as Error).message);
  process.exit(1);
});
