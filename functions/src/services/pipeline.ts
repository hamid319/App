import { ATTRACTION_TYPE_ROOTS, LIMITS, PIPELINE_VERSION } from "../domain/config.js";
import { asPipelineError, PipelineError } from "../domain/errors.js";
import type {
  AttractionCandidate,
  AttemptClaim,
  CityIdentity,
  CityPreparationJob,
  JobCounters,
  CommonsPhotoCandidate,
  CommonsPhotoMetadata,
  JobCheckpoint,
  PublicVersion,
  PublishedPlace,
  StoredPhoto,
} from "../domain/types.js";
import {
  assertSafeWikimediaUrl,
  deterministicDescription,
  isKnownNonPhoto,
  normalizeLicense,
  rankCandidates,
  stablePlaceId,
} from "../domain/validation.js";
import type { WikimediaHttpClient } from "../adapters/safe-http.js";
import type { WikimediaSource } from "../adapters/wikimedia.js";
import { processImage } from "../adapters/image-processor.js";
import type { ObjectStore } from "../adapters/r2.js";
import { JobBudget } from "./budget.js";

export interface PipelineRepository {
  getJob(jobId: string): Promise<CityPreparationJob | null>;
  claimAttempt(jobId: string, maxAttempts: number): Promise<AttemptClaim>;
  prepareRetry(jobId: string, checkpoint: JobCheckpoint, expectedAttempt: number): Promise<void>;
  saveCounters(jobId: string, counters: JobCounters, expectedAttempt: number): Promise<void>;
  reserveObject(jobId: string, objectKey: string, bytes: number): Promise<void>;
  saveCityAndCandidates(jobId: string, city: CityIdentity, candidates: AttractionCandidate[], expectedAttempt: number): Promise<void>;
  loadCandidates(jobId: string): Promise<AttractionCandidate[]>;
  saveCheckpoint(jobId: string, checkpoint: JobCheckpoint, qualifiedCount: number, expectedAttempt: number): Promise<void>;
  saveStagedPlace(jobId: string, place: PublishedPlace, expectedAttempt: number): Promise<void>;
  loadStagedPlaces(jobId: string): Promise<PublishedPlace[]>;
  publish(version: PublicVersion, jobId: string, expectedAttempt: number): Promise<void>;
  finishEmpty(jobId: string, checkpoint: JobCheckpoint, expectedAttempt: number): Promise<void>;
  finishFailed(jobId: string, checkpoint: JobCheckpoint, failureCode: string, expectedAttempt: number): Promise<void>;
}

export interface CollectionSource {
  resolveCity(qid: string): Promise<CityIdentity>;
  findAttractions(city: CityIdentity): Promise<AttractionCandidate[]>;
  findPhotoCandidates(candidates: AttractionCandidate[]): Promise<Map<string, CommonsPhotoCandidate[]>>;
  getPhotoMetadata(fileTitles: string[]): Promise<Map<string, CommonsPhotoMetadata>>;
}

export interface PipelineDependencies {
  repository: PipelineRepository;
  source: CollectionSource;
  http: WikimediaHttpClient;
  objects: ObjectStore;
  budget: JobBudget;
  claimedJob?: CityPreparationJob;
  now?: () => Date;
}

const typePriority = new Map(ATTRACTION_TYPE_ROOTS.map((item) => [item.qid, item.priority]));

export async function runCityPipeline(jobId: string, dependencies: PipelineDependencies): Promise<void> {
  const now = dependencies.now ?? (() => new Date());
  const claim = dependencies.claimedJob
    ? { job: dependencies.claimedJob, claimed: true }
    : await dependencies.repository.claimAttempt(jobId, LIMITS.maxAttempts);
  if (!claim.claimed) return;
  let job = claim.job;
  const expectedAttempt = job.checkpoint.attempt;
  const budget = dependencies.budget;
  job.checkpoint.counters = budget.counters;
  let controlledStop = false;
  try {
    let candidates = await dependencies.repository.loadCandidates(jobId);
    let city = job.city;
    if (!city || candidates.length === 0) {
      city = await dependencies.source.resolveCity(job.cityQid);
      candidates = rankCandidates(
        (await dependencies.source.findAttractions(city)).slice(0, LIMITS.candidateLimit),
        typePriority,
      ).map((candidate, rank) => ({ ...candidate, rank }));
      await dependencies.repository.saveCityAndCandidates(jobId, city, candidates, expectedAttempt);
      job = { ...job, city, candidateCount: candidates.length };
    }
    if (!city) throw new PipelineError("missing-city-checkpoint", "City checkpoint is missing");

    const photosByPlace = await dependencies.source.findPhotoCandidates(candidates);
    const allTitles = [...new Set(
      [...photosByPlace.values()].flat().map((photo) => normalizeFileTitle(photo.fileTitle)),
    )];
    const metadata = await dependencies.source.getPhotoMetadata(allTitles);
    const seenPageIds = new Set<number>();
    const seenSourceHashes = new Set<string>();
    const seenOutputHashes = new Set<string>();
    const staged = await dependencies.repository.loadStagedPlaces(jobId);
    for (const place of staged) {
      for (const photo of place.photos) {
        seenPageIds.add(photo.commonsPageId);
        seenSourceHashes.add(photo.sourceSha1);
        seenOutputHashes.add(photo.outputSha256);
      }
    }

    const checkpoint = job.checkpoint;
    for (let index = checkpoint.candidateIndex; index < candidates.length; index += 1) {
      if (staged.length >= LIMITS.targetPlaces) break;
      budget.assertRuntime();
      const candidate = candidates[index];
      const storedPhotos: StoredPhoto[] = [];
      for (const photoCandidate of photosByPlace.get(candidate.qid) ?? []) {
        if (storedPhotos.length >= LIMITS.targetPhotosPerPlace) break;
        if (photoCandidate.origin === "depicts" && !photoCandidate.depictsQids.includes(candidate.qid)) continue;
        const details = metadata.get(normalizeFileTitle(photoCandidate.fileTitle));
        if (!details || !qualifiesMetadata(details)) continue;
        if (seenPageIds.has(details.pageId) || seenSourceHashes.has(details.sourceSha1)) continue;
        try {
          const license = normalizeLicense(details.licenseShortName, details.licenseUrl);
          if (!license) continue;
          const sourceBytes = await dependencies.http.download(details.thumbnailUrl, LIMITS.maxImageBytes);
          const image = await processImage(sourceBytes, LIMITS);
          if (seenOutputHashes.has(image.sha256)) continue;
          const objectKey = [
            "city-collections",
            city.qid,
            stablePlaceId(candidate.qid),
            `${details.pageId}-${image.sha256}.webp`,
          ].join("/");
          await dependencies.repository.reserveObject(jobId, objectKey, image.bytes.length);
          const publicUrl = await dependencies.objects.putImmutable(objectKey, image.bytes, {
            sha256: image.sha256,
            "source-sha1": details.sourceSha1,
            "commons-page-id": String(details.pageId),
            license: license.name,
          });
          await dependencies.objects.verify(objectKey, image.sha256);
          storedPhotos.push({
            objectKey,
            publicUrl,
            commonsFileTitle: details.fileTitle,
            commonsFilePageUrl: `https://commons.wikimedia.org/wiki/${encodeURIComponent(details.fileTitle.replace(/ /g, "_"))}`,
            commonsPageId: details.pageId,
            originalSourceUrl: details.originalUrl,
            creator: details.creator,
            attribution: details.credit || details.creator,
            licenseName: license.name,
            licenseUrl: license.url,
            sourceRevisionId: details.revisionId,
            sourceRevisionTimestamp: details.revisionTimestamp,
            sourceSha1: details.sourceSha1,
            outputSha256: image.sha256,
            width: image.width,
            height: image.height,
            mime: "image/webp",
            modifications: "Auto-rotated, resized to at most 1280 px long edge, and converted to WebP.",
            retrievedAt: now().toISOString(),
          });
          seenPageIds.add(details.pageId);
          seenSourceHashes.add(details.sourceSha1);
          seenOutputHashes.add(image.sha256);
        } catch (error) {
          const failure = asPipelineError(error);
          if (isControlledResourceStop(failure)) {
            controlledStop = true;
            break;
          }
          if (failure.retryable) throw failure;
          if (!isCandidateRejection(failure)) throw failure;
        }
      }
      if (storedPhotos.length > 0) {
        const place: PublishedPlace = {
          id: stablePlaceId(candidate.qid),
          source: "wikidata",
          sourceId: candidate.qid,
          name: candidate.name,
          description: deterministicDescription(candidate, city.name, city.countryName),
          lat: candidate.coordinates.latitude,
          lng: candidate.coordinates.longitude,
          countryQid: candidate.countryQid,
          cityQid: city.qid,
          types: candidate.typeLabels,
          photos: storedPhotos,
          sourceRevisionId: candidate.sourceRevisionId,
          sourceRevisionTimestamp: candidate.sourceRevisionTimestamp,
          retrievedAt: now().toISOString(),
        };
        await dependencies.repository.saveStagedPlace(jobId, place, expectedAttempt);
        staged.push(place);
      }
      checkpoint.candidateIndex = index + 1;
      checkpoint.acceptedPlaceIds = staged.map((place) => place.id);
      await dependencies.repository.saveCheckpoint(jobId, checkpoint, staged.length, expectedAttempt);
      if (controlledStop) break;
    }

    const finalPlaces = (await dependencies.repository.loadStagedPlaces(jobId)).slice(0, LIMITS.targetPlaces);
    await budget.finishAttempt();
    await dependencies.repository.saveCheckpoint(jobId, checkpoint, finalPlaces.length, expectedAttempt);
    if (finalPlaces.length === 0) {
      await dependencies.repository.finishEmpty(jobId, checkpoint, expectedAttempt);
      return;
    }
    await dependencies.repository.publish({
      city,
      versionId: checkpoint.versionId,
      status: finalPlaces.length === LIMITS.targetPlaces ? "ready" : "partial",
      places: finalPlaces,
      createdAt: now(),
      source: "wikidata-commons",
    }, jobId, expectedAttempt);
  } catch (error) {
    await budget.finishAttempt();
    const failure = asPipelineError(error);
    if (failure.retryable && job.checkpoint.attempt < LIMITS.maxAttempts) {
      await dependencies.repository.prepareRetry(jobId, job.checkpoint, expectedAttempt);
      throw failure;
    }
    await dependencies.repository.finishFailed(jobId, job.checkpoint, failure.code, expectedAttempt);
  }
}

function qualifiesMetadata(details: CommonsPhotoMetadata): boolean {
  const longEdge = Math.max(details.width, details.height);
  const shortEdge = Math.min(details.width, details.height);
  if (
    details.pageId <= 0 ||
    !details.sourceSha1 ||
    !details.creator ||
    !details.licenseShortName ||
    !details.licenseUrl ||
    details.revisionId <= 0 ||
    !details.revisionTimestamp ||
    details.mediaType.toUpperCase() !== "BITMAP" ||
    !new Set(["image/jpeg", "image/png", "image/webp"]).has(details.mime.toLowerCase()) ||
    longEdge < LIMITS.minLongEdge ||
    shortEdge < LIMITS.minShortEdge ||
    isKnownNonPhoto(details)
  ) return false;
  try {
    assertSafeWikimediaUrl(details.originalUrl);
    assertSafeWikimediaUrl(details.thumbnailUrl);
  } catch {
    return false;
  }
  return normalizeLicense(details.licenseShortName, details.licenseUrl) !== null;
}

function normalizeFileTitle(title: string): string {
  const value = title.replace(/_/g, " ").trim();
  return value.startsWith("File:") ? value : `File:${value}`;
}

function isControlledResourceStop(error: PipelineError): boolean {
  return new Set([
    "metadata-request-limit",
    "thumbnail-attempt-limit",
    "job-download-limit",
    "job-runtime-limit",
  ]).has(error.code);
}

function isCandidateRejection(error: PipelineError): boolean {
  return new Set([
    "invalid-media-type",
    "empty-media",
    "source-image-too-large",
    "source-image-size",
    "source-resolution",
    "image-processing",
    "upstream-http-400",
    "upstream-http-403",
    "upstream-http-404",
  ]).has(error.code);
}

export const PIPELINE_SOURCE_LABEL = PIPELINE_VERSION;
