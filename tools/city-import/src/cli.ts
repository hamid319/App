// SwipeTrip city import.
//
//   npm run collect -- [--city pt_lisbon]   Wikidata/Wikipedia/Commons -> out/<cityId>.json
//   npm run report                          out/*.json -> out/report.html (review)
//   npm run publish -- [--city pt_lisbon] [--dry-run]
//                                           out/*.json -> R2 photos + Firestore
//
// collect and report need no credentials. publish reads R2 settings from
// .env (see .env.example) and uses Google application default credentials
// (or GOOGLE_APPLICATION_CREDENTIALS) for Firestore.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { collectCity } from "./collect.js";
import { WikimediaHttp } from "./http.js";
import { toWebp } from "./images.js";
import type { CityCollection, CityConfig } from "./model.js";
import { publishCity } from "./publish.js";
import { renderReport } from "./report.js";
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
  return {
    command,
    cityIds: cityIndex >= 0 ? (argv[cityIndex + 1] ?? "").split(",").filter(Boolean) : [],
    dryRun: argv.includes("--dry-run"),
  };
}

function selectedCities(cityIds: string[]): CityConfig[] {
  const all = readJson<CityConfig[]>(join(ROOT, "cities.json"));
  if (cityIds.length === 0) return all;
  const unknown = cityIds.filter((id) => !all.some((c) => c.id === id));
  if (unknown.length) throw new Error(`Not in cities.json: ${unknown.join(", ")}`);
  return all.filter((c) => cityIds.includes(c.id));
}

function exclusions(): Record<string, string[]> {
  return readJson<{ places: Record<string, string[]> }>(join(ROOT, "exclusions.json")).places ?? {};
}

function loadCollection(cityId: string): CityCollection {
  const path = join(OUT, `${cityId}.json`);
  if (!existsSync(path)) throw new Error(`${cityId}: run "npm run collect -- --city ${cityId}" first`);
  return readJson<CityCollection>(path);
}

async function collect(cities: CityConfig[]) {
  mkdirSync(OUT, { recursive: true });
  const http = new WikimediaHttp();
  const source = new WikimediaSource(http);
  for (const city of cities) {
    try {
      const collection = await collectCity(city, source, console.log);
      writeFileSync(join(OUT, `${city.id}.json`), JSON.stringify(collection, null, 2));
    } catch (error) {
      console.error(`${city.id}: failed – ${(error as Error).message}`);
      process.exitCode = 1;
    }
  }
  console.log(`${http.requestCount} requests to Wikimedia`);
}

function report(cities: CityConfig[]) {
  const collections = cities
    .filter((c) => existsSync(join(OUT, `${c.id}.json`)))
    .map((c) => loadCollection(c.id));
  const path = join(OUT, "report.html");
  writeFileSync(path, renderReport(collections, exclusions()));
  console.log(`Report: ${path}`);
}

function requireEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is missing (see .env.example)`);
  return value;
}

async function publish(cities: CityConfig[], dryRun: boolean) {
  const excluded = exclusions();
  const collections = cities.map((c) => loadCollection(c.id));
  if (dryRun) {
    for (const c of collections) {
      const skip = new Set(excluded[c.city.id] ?? []);
      const places = c.places.filter((p) => !skip.has(p.wikidataId));
      const photos = places.reduce((sum, p) => sum + p.photos.length, 0);
      console.log(`${c.city.id}: would publish ${places.length} places with up to ${photos} photos`);
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
        log: console.log,
      }));
    }
    await data.writeRun(runId, { finishedAt: new Date().toISOString(), status: "done", results });
  } catch (error) {
    await data.writeRun(runId, { finishedAt: new Date().toISOString(), status: "failed", error: (error as Error).message, results });
    throw error;
  }
  console.log(`Import run ${runId} done.`);
}

async function main() {
  const { command, cityIds, dryRun } = args();
  const cities = selectedCities(cityIds);
  if (command === "collect") await collect(cities);
  else if (command === "report") report(cities);
  else if (command === "publish") await publish(cities, dryRun);
  else throw new Error("Usage: cli.ts collect|report|publish [--city id,id] [--dry-run]");
}

main().catch((error) => {
  console.error((error as Error).message);
  process.exit(1);
});
