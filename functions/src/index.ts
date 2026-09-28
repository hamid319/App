import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getFunctions } from "firebase-admin/functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret, defineString } from "firebase-functions/params";
import { FirestoreCityRepository } from "./adapters/firestore-repository.js";
import { WikimediaHttpClient } from "./adapters/safe-http.js";
import { WikimediaSource } from "./adapters/wikimedia.js";
import { R2ObjectStore } from "./adapters/r2.js";
import { LIMITS, REGION } from "./domain/config.js";
import { asPipelineError, PipelineError } from "./domain/errors.js";
import { normalizeQid } from "./domain/validation.js";
import { requestCollection } from "./services/admission.js";
import { JobBudget } from "./services/budget.js";
import { runCityPipeline } from "./services/pipeline.js";

initializeApp();

const r2AccessKeyId = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretAccessKey = defineSecret("R2_SECRET_ACCESS_KEY");
const r2AccountId = defineString("R2_ACCOUNT_ID");
const r2Bucket = defineString("R2_BUCKET");
const r2PublicBaseUrl = defineString("R2_PUBLIC_BASE_URL");

const callableOptions = {
  region: REGION,
  enforceAppCheck: true,
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 3,
  concurrency: 10,
} as const;

export const requestCityCollection = onCall(callableOptions, async (request) => {
  try {
    const repository = new FirestoreCityRepository(getFirestore());
    const preflightBudget = new JobBudget(LIMITS, {
      metadataRequests: 0,
      thumbnailAttempts: 0,
      downloadedBytes: 0,
      activeRuntimeMs: 0,
    });
    const source = new WikimediaSource(new WikimediaHttpClient(preflightBudget));
    const outcome = await requestCollection(
      { uid: request.auth?.uid, appCheckValid: Boolean(request.app) },
      request.data?.cityQid,
      repository,
      new Date(),
      (qid) => source.resolveCity(qid),
    );
    if (outcome.kind === "admitted" && outcome.jobId) {
      await enqueueJob(outcome.jobId).catch(() => undefined);
    }
    return outcome;
  } catch (error) {
    throw callableError(error);
  }
});

export const getCityPreparation = onCall(callableOptions, async (request) => {
  try {
    if (!request.auth?.uid) throw new PipelineError("unauthenticated", "Authentication is required");
    const cityQid = normalizeQid(request.data?.cityQid);
    return { preparation: await new FirestoreCityRepository(getFirestore()).getPreparationForUser(cityQid, request.auth.uid) };
  } catch (error) {
    throw callableError(error);
  }
});

export const getCityCollection = onCall(callableOptions, async (request) => {
  try {
    if (!request.auth?.uid) throw new PipelineError("unauthenticated", "Authentication is required");
    const cityQid = normalizeQid(request.data?.cityQid);
    const versionId = request.data?.versionId;
    if (versionId !== undefined && (typeof versionId !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(versionId))) {
      throw new PipelineError("invalid-argument", "Invalid versionId");
    }
    return { collection: await new FirestoreCityRepository(getFirestore()).getPublished(cityQid, versionId) };
  } catch (error) {
    throw callableError(error);
  }
});

export const prepareCityCollection = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: LIMITS.maxAttempts, minBackoffSeconds: 60, maxBackoffSeconds: 900, maxDoublings: 4 },
    rateLimits: { maxConcurrentDispatches: 1, maxDispatchesPerSecond: 1 },
    timeoutSeconds: LIMITS.attemptRuntimeMs / 1000,
    memory: "1GiB",
    cpu: 1,
    minInstances: 0,
    maxInstances: 1,
    invoker: "private",
    secrets: [r2AccessKeyId, r2SecretAccessKey],
  },
  async (request) => {
    const jobId = request.data?.jobId;
    if (typeof jobId !== "string" || !/^[A-Za-z0-9]{1,80}$/.test(jobId)) {
      throw new PipelineError("invalid-task", "Invalid job ID");
    }
    const repository = new FirestoreCityRepository(getFirestore());
    const claim = await repository.claimAttempt(jobId, LIMITS.maxAttempts);
    if (!claim.claimed) return;
    const claimed = claim.job;
    const budget = new JobBudget(
      LIMITS,
      claimed.checkpoint.counters,
      Date.now(),
      async (counters) => {
        await repository.saveCounters(jobId, { ...counters }, claimed.checkpoint.attempt);
      },
    );
    const http = new WikimediaHttpClient(budget);
    await runCityPipeline(jobId, {
      repository,
      claimedJob: claimed,
      budget,
      http,
      source: new WikimediaSource(http),
      objects: new R2ObjectStore({
        accountId: r2AccountId.value(),
        accessKeyId: r2AccessKeyId.value(),
        secretAccessKey: r2SecretAccessKey.value(),
        bucket: r2Bucket.value(),
        publicBaseUrl: r2PublicBaseUrl.value(),
      }),
    });
  },
);

export const recoverCityPreparationOutbox = onSchedule(
  { region: REGION, schedule: "every 5 minutes", timeoutSeconds: 60, maxInstances: 1 },
  async () => {
    const repository = new FirestoreCityRepository(getFirestore());
    await repository.recoverStaleRunning();
    for (const item of await repository.pendingOutbox(20)) {
      try {
        await enqueueJob(item.jobId);
      } catch (error) {
        await repository.markOutboxAttempt(item.refPath, asPipelineError(error).code);
      }
    }
  },
);

async function enqueueJob(jobId: string): Promise<void> {
  await getFunctions()
    .taskQueue(`locations/${REGION}/functions/prepareCityCollection`)
    .enqueue({ jobId }, { dispatchDeadlineSeconds: LIMITS.attemptRuntimeMs / 1000 });
  await new FirestoreCityRepository(getFirestore()).markOutboxEnqueued(`cityPreparationOutbox/${jobId}`);
}

function callableError(error: unknown): HttpsError {
  const failure = asPipelineError(error);
  const code = failure.code === "unauthenticated"
    ? "unauthenticated"
    : failure.code === "invalid-argument"
      ? "invalid-argument"
      : failure.code.includes("limit") || failure.code === "resource-exhausted"
        ? "resource-exhausted"
        : failure.code.includes("paused") || failure.code.includes("cooldown")
          ? "failed-precondition"
          : "internal";
  return new HttpsError(code, failure.message, { code: failure.code });
}
