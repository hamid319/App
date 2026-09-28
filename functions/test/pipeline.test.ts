import sharp from "sharp";
import { beforeAll, describe, expect, it } from "vitest";
import { LIMITS } from "../src/domain/config.js";
import { PipelineError } from "../src/domain/errors.js";
import type {
  AttemptClaim,
  AttractionCandidate,
  CityIdentity,
  CityPreparationJob,
  CommonsPhotoCandidate,
  CommonsPhotoMetadata,
  JobCheckpoint,
  PublicVersion,
  PublishedPlace,
} from "../src/domain/types.js";
import type { ObjectStore } from "../src/adapters/r2.js";
import type { WikimediaHttpClient } from "../src/adapters/safe-http.js";
import { JobBudget } from "../src/services/budget.js";
import { runCityPipeline, type CollectionSource, type PipelineRepository } from "../src/services/pipeline.js";

let sourceImage: Buffer;
beforeAll(async () => {
  sourceImage = await sharp({ create: { width: 800, height: 640, channels: 3, background: "#336699" } }).jpeg().toBuffer();
});

describe("city pipeline publication", () => {
  for (const count of [0, 1, 30, 50]) {
    it(`produces the correct outcome for ${count} qualified places`, async () => {
      const repository = new FakeRepository(count);
      await runCityPipeline("job", dependencies(repository, count));
      if (count === 0) {
        expect(repository.empty).toBe(true);
        expect(repository.published).toBeNull();
      } else {
        expect(repository.published?.places).toHaveLength(count);
        expect(repository.published?.status).toBe(count === 50 ? "ready" : "partial");
        expect(repository.published?.places[0].photos[0]).toMatchObject({ licenseName: "CC-BY-4.0", creator: "Creator" });
      }
    });
  }

  it("does not reprocess a terminal delivery", async () => {
    const repository = new FakeRepository(1);
    repository.job.status = "ready";
    await runCityPipeline("job", dependencies(repository, 1));
    expect(repository.claims).toBe(1);
    expect(repository.published).toBeNull();
  });

  it("checkpoints and retries an object-store outage without publishing", async () => {
    const repository = new FakeRepository(1);
    const deps = dependencies(repository, 1);
    deps.objects = new FailingObjects();
    await expect(runCityPipeline("job", deps)).rejects.toMatchObject({ code: "r2-upload" });
    expect(repository.retryPrepared).toBe(true);
    expect(repository.published).toBeNull();
  });
});

function dependencies(repository: FakeRepository, count: number) {
  const source = new FakeSource(count);
  const budget = new JobBudget(LIMITS, repository.job.checkpoint.counters);
  return {
    repository,
    source,
    budget,
    objects: new FakeObjects() as ObjectStore,
    http: { download: async () => sourceImage } as unknown as WikimediaHttpClient,
    now: () => new Date("2026-09-13T12:00:00Z"),
  };
}

class FakeSource implements CollectionSource {
  constructor(private readonly count: number) {}
  async resolveCity(): Promise<CityIdentity> { return city; }
  async findAttractions(): Promise<AttractionCandidate[]> { return Array.from({ length: this.count }, (_, index) => candidate(index + 1)); }
  async findPhotoCandidates(candidates: AttractionCandidate[]): Promise<Map<string, CommonsPhotoCandidate[]>> {
    return new Map(candidates.map((item) => [item.qid, [{ fileTitle: `File:${item.qid}.jpg`, depictsQids: [], origin: "p18" }]]));
  }
  async getPhotoMetadata(titles: string[]): Promise<Map<string, CommonsPhotoMetadata>> {
    return new Map(titles.map((title, index) => [title, metadata(title, index + 1)]));
  }
}

class FakeRepository implements PipelineRepository {
  claims = 0;
  empty = false;
  retryPrepared = false;
  published: PublicVersion | null = null;
  staged = new Map<string, PublishedPlace>();
  candidates: AttractionCandidate[] = [];
  job: CityPreparationJob;
  constructor(private readonly count: number) {
    this.job = { id: "job", cityQid: city.qid, requestedBy: "u", status: "queued", createdAt: new Date(), updatedAt: new Date(), qualifiedCount: 0, checkpoint: checkpoint() };
  }
  async getJob(): Promise<CityPreparationJob> { return this.job; }
  async claimAttempt(): Promise<AttemptClaim> {
    this.claims += 1;
    if (["ready", "partial", "empty", "failed", "paused"].includes(this.job.status)) return { job: this.job, claimed: false };
    this.job.checkpoint.attempt += 1;
    this.job.status = "running";
    return { job: this.job, claimed: true };
  }
  async prepareRetry(): Promise<void> { this.retryPrepared = true; this.job.status = "queued"; }
  async saveCounters(_jobId: string, counters: JobCheckpoint["counters"]): Promise<void> { this.job.checkpoint.counters = counters; }
  async reserveObject(): Promise<void> {}
  async saveCityAndCandidates(_jobId: string, resolved: CityIdentity, candidates: AttractionCandidate[]): Promise<void> { this.job.city = resolved; this.candidates = candidates; }
  async loadCandidates(): Promise<AttractionCandidate[]> { return this.candidates; }
  async saveCheckpoint(_jobId: string, value: JobCheckpoint, qualifiedCount: number): Promise<void> { this.job.checkpoint = value; this.job.qualifiedCount = qualifiedCount; }
  async saveStagedPlace(_jobId: string, place: PublishedPlace): Promise<void> { this.staged.set(place.id, place); }
  async loadStagedPlaces(): Promise<PublishedPlace[]> { return [...this.staged.values()]; }
  async publish(version: PublicVersion): Promise<void> { this.published = version; this.job.status = version.status; }
  async finishEmpty(): Promise<void> { this.empty = true; this.job.status = "empty"; }
  async finishFailed(_jobId: string, _checkpoint: JobCheckpoint, failureCode: string): Promise<void> { this.job.status = "failed"; this.job.failureCode = failureCode; }
}

class FakeObjects implements ObjectStore {
  async putImmutable(key: string): Promise<string> { return `https://images.example.test/${key}`; }
  async verify(): Promise<void> {}
}

class FailingObjects implements ObjectStore {
  async putImmutable(): Promise<string> { throw new PipelineError("r2-upload", "outage", true); }
  async verify(): Promise<void> {}
}

const city: CityIdentity = { qid: "Q1055", name: "Hamburg", countryQid: "Q183", countryName: "Germany", coordinates: { latitude: 53.55, longitude: 10 } };

function candidate(number: number): AttractionCandidate {
  return { rank: number - 1, qid: `Q${number}`, name: `Place ${number}`, coordinates: { latitude: 53.55, longitude: 10 }, countryQid: "Q183", types: ["Q33506"], typeLabels: ["museum"], sitelinks: 100 - number, distanceKm: number / 100, p18Files: [`File:Q${number}.jpg`], sourceRevisionId: number, sourceRevisionTimestamp: "2026-09-01T00:00:00Z" };
}

function metadata(fileTitle: string, number: number): CommonsPhotoMetadata {
  return { fileTitle, pageId: number, sourceSha1: `sha${number}`, originalUrl: `https://upload.wikimedia.org/source/${number}.jpg`, thumbnailUrl: `https://upload.wikimedia.org/thumb/${number}.jpg`, mime: "image/jpeg", mediaType: "BITMAP", width: 800, height: 640, revisionId: number, revisionTimestamp: "2026-09-01T00:00:00Z", creator: "Creator", credit: "Creator / Wikimedia Commons", licenseShortName: "CC BY 4.0", licenseUrl: "https://creativecommons.org/licenses/by/4.0/", categories: [] };
}

function checkpoint(): JobCheckpoint {
  return { candidateIndex: 0, acceptedPlaceIds: [], counters: { metadataRequests: 0, thumbnailAttempts: 0, downloadedBytes: 0, activeRuntimeMs: 0 }, attempt: 0, versionId: "v1" };
}
