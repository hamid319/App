import { LIMITS } from "../src/domain/config.js";
import { WikimediaHttpClient } from "../src/adapters/safe-http.js";
import { WikimediaSource } from "../src/adapters/wikimedia.js";
import { JobBudget } from "../src/services/budget.js";
import { normalizeQid } from "../src/domain/validation.js";

const knownCities = ["Q1055", "Q406", "Q334", "Q35381", "Q60"];
const requested = process.argv.slice(2).filter((arg) => arg.startsWith("Q"));
const cityQids = requested.length > 0 ? requested.map(normalizeQid) : knownCities;

for (const cityQid of cityQids) {
  const counters = { metadataRequests: 0, thumbnailAttempts: 0, downloadedBytes: 0, activeRuntimeMs: 0 };
  const source = new WikimediaSource(new WikimediaHttpClient(new JobBudget(LIMITS, counters)));
  const city = await source.resolveCity(cityQid);
  const candidates = await source.findAttractions(city);
  process.stdout.write(`${JSON.stringify({
    checkedAt: new Date().toISOString(),
    city,
    candidateCount: candidates.length,
    firstCandidates: candidates.slice(0, 8).map(({ qid, name, types, sitelinks, distanceKm, p18Files }) => ({ qid, name, types, sitelinks, distanceKm, p18Count: p18Files.length })),
    counters,
  })}\n`);
}

