import {
  FieldValue,
  Firestore,
  Timestamp,
  type DocumentData,
  type Transaction,
} from "firebase-admin/firestore";
import { ADMISSION_LIMITS, LIMITS, PIPELINE_VERSION } from "../domain/config.js";
import { PipelineError } from "../domain/errors.js";
import type {
  AttractionCandidate,
  AttemptClaim,
  CityIdentity,
  CityPreparationJob,
  JobCheckpoint,
  JobCounters,
  PublicVersion,
  PublishedPlace,
  RequestOutcome,
} from "../domain/types.js";
import type { AdmissionRepository } from "../services/admission.js";
import { utcQuotaKeys } from "../services/admission.js";
import type { PipelineRepository } from "../services/pipeline.js";

const DAY_MS = 24 * 60 * 60 * 1000;

export class FirestoreCityRepository implements AdmissionRepository, PipelineRepository {
  constructor(private readonly db: Firestore) {}

  async precheck(cityQid: string, now: Date): Promise<RequestOutcome | null> {
    const [control, city, active] = await Promise.all([
      this.db.collection("cityPreparationControl").doc("global").get(),
      this.db.collection("cityCollections").doc(cityQid).get(),
      this.db.collection("cityPreparationActive").doc(cityQid).get(),
    ]);
    if (control.data()?.killSwitch === true) throw new PipelineError("pipeline-paused", "City preparation is paused");
    if (Number(control.data()?.cumulativeImportedBytes ?? 0) >= ADMISSION_LIMITS.storagePauseBytes) {
      throw new PipelineError("storage-pause", "Storage import threshold reached");
    }
    const activeJobId = active.data()?.jobId as string | undefined;
    if (activeJobId) {
      const job = await this.getJob(activeJobId);
      if (job && (job.status === "queued" || job.status === "running")) {
        return { kind: "pending", cityQid, jobId: activeJobId, status: job.status };
      }
    }
    const reuse = this.reusablePublication(city.data(), now);
    return reuse ? { kind: "fresh", cityQid, versionId: reuse.versionId, status: reuse.status } : null;
  }

  async consumeValidationAttempt(uid: string, now: Date): Promise<void> {
    const day = now.toISOString().slice(0, 10);
    const safeUid = Buffer.from(uid).toString("base64url");
    const ref = this.db.collection("cityPreparationValidationCounters").doc(`user_${safeUid}_${day}`);
    await this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (Number(snapshot.data()?.count ?? 0) >= 10) {
        throw new PipelineError("validation-rate-limit", "Too many city validation attempts");
      }
      transaction.set(ref, { count: FieldValue.increment(1), updatedAt: now }, { merge: true });
    });
  }

  async admit(uid: string, cityQid: string, now: Date, city?: CityIdentity): Promise<RequestOutcome> {
    const jobRef = this.db.collection("cityPreparationJobs").doc();
    const activeRef = this.db.collection("cityPreparationActive").doc(cityQid);
    const cityRef = this.db.collection("cityCollections").doc(cityQid);
    const controlRef = this.db.collection("cityPreparationControl").doc("global");
    const quotaKeys = utcQuotaKeys(uid, now);
    const quotaRefs = quotaKeys.map(({ id }) => this.db.collection("cityPreparationQuotaCounters").doc(id));
    return this.db.runTransaction(async (transaction) => {
      const [control, citySnapshot, active, ...quotaSnapshots] = await Promise.all([
        transaction.get(controlRef),
        transaction.get(cityRef),
        transaction.get(activeRef),
        ...quotaRefs.map((ref) => transaction.get(ref)),
      ]);
      const controlData = control.data() ?? {};
      if (controlData.killSwitch === true) throw new PipelineError("pipeline-paused", "City preparation is paused");
      if (Number(controlData.cumulativeImportedBytes ?? 0) >= ADMISSION_LIMITS.storagePauseBytes) {
        throw new PipelineError("storage-pause", "Storage import threshold reached");
      }
      const activeJobId = active.data()?.jobId as string | undefined;
      if (activeJobId) {
        const activeJob = await transaction.get(this.db.collection("cityPreparationJobs").doc(activeJobId));
        const status = activeJob.data()?.status;
        if (status === "queued" || status === "running") {
          return { kind: "pending", cityQid, jobId: activeJobId, status } as RequestOutcome;
        }
      }
      const reuse = this.reusablePublication(citySnapshot.data(), now);
      if (reuse) return { kind: "fresh", cityQid, versionId: reuse.versionId, status: reuse.status };
      this.assertCooldown(citySnapshot.data(), now);
      quotaSnapshots.forEach((snapshot, index) => {
        const count = Number(snapshot.data()?.count ?? 0);
        if (count >= quotaKeys[index].limit) throw new PipelineError("resource-exhausted", "Request quota reached");
      });

      const versionId = `${now.toISOString().replace(/[-:.TZ]/g, "")}-${jobRef.id.slice(0, 8)}`;
      const checkpoint: JobCheckpoint = {
        candidateIndex: 0,
        acceptedPlaceIds: [],
        counters: { metadataRequests: 0, thumbnailAttempts: 0, downloadedBytes: 0, activeRuntimeMs: 0 },
        attempt: 0,
        versionId,
      };
      transaction.create(jobRef, {
        id: jobRef.id,
        cityQid,
        requestedBy: uid,
        status: "queued",
        createdAt: now,
        updatedAt: now,
        checkpoint,
        ...(city ? { city } : {}),
        qualifiedCount: 0,
        pipelineVersion: PIPELINE_VERSION,
      });
      transaction.set(activeRef, { cityQid, jobId: jobRef.id, createdAt: now });
      transaction.create(this.db.collection("cityPreparationOutbox").doc(jobRef.id), {
        jobId: jobRef.id,
        status: "pending",
        attempts: 0,
        createdAt: now,
        updatedAt: now,
      });
      quotaRefs.forEach((ref) => transaction.set(ref, {
        count: FieldValue.increment(1),
        updatedAt: now,
      }, { merge: true }));
      return { kind: "admitted", cityQid, jobId: jobRef.id, status: "queued" };
    });
  }

  async getJob(jobId: string): Promise<CityPreparationJob | null> {
    const snapshot = await this.db.collection("cityPreparationJobs").doc(jobId).get();
    return snapshot.exists ? decodeJob(snapshot.data()!) : null;
  }

  async claimAttempt(jobId: string, maxAttempts: number): Promise<AttemptClaim> {
    const ref = this.db.collection("cityPreparationJobs").doc(jobId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new PipelineError("job-not-found", "Job not found");
      const job = decodeJob(snapshot.data()!);
      if (["ready", "partial", "empty", "failed", "paused"].includes(job.status)) {
        return { job, claimed: false };
      }
      if (job.status === "running" && Date.now() - job.updatedAt.getTime() < 22 * 60 * 1000) {
        return { job, claimed: false };
      }
      const attempt = job.checkpoint.attempt + 1;
      const activeRef = this.db.collection("cityPreparationActive").doc(job.cityQid);
      const cityRef = this.db.collection("cityCollections").doc(job.cityQid);
      const [active, citySnapshot] = attempt > maxAttempts
        ? await Promise.all([transaction.get(activeRef), transaction.get(cityRef)])
        : [null, null];
      if (attempt > maxAttempts) {
        const failedAt = new Date();
        transaction.update(ref, { status: "failed", failureCode: "attempts-exhausted", updatedAt: failedAt });
        transaction.set(cityRef, { lastOutcome: "failed", lastTerminalAt: failedAt }, { merge: true });
        if (active?.data()?.jobId === jobId) transaction.delete(activeRef);
        return { job: { ...job, status: "failed", failureCode: "attempts-exhausted" }, claimed: false };
      }
      transaction.update(ref, {
        status: "running",
        "checkpoint.attempt": attempt,
        updatedAt: new Date(),
      });
      return { job: { ...job, status: "running", checkpoint: { ...job.checkpoint, attempt } }, claimed: true };
    });
  }

  async prepareRetry(jobId: string, checkpoint: JobCheckpoint, expectedAttempt: number): Promise<void> {
    await this.updateFenced(jobId, expectedAttempt, { status: "queued", checkpoint, updatedAt: new Date() });
  }

  async saveCounters(jobId: string, counters: JobCounters, expectedAttempt: number): Promise<void> {
    await this.updateFenced(jobId, expectedAttempt, { "checkpoint.counters": counters, updatedAt: new Date() });
  }

  async reserveObject(jobId: string, objectKey: string, bytes: number): Promise<void> {
    if (!Number.isSafeInteger(bytes) || bytes <= 0) throw new PipelineError("invalid-object-size", "Invalid object size");
    const ledgerId = Buffer.from(objectKey).toString("base64url");
    const ledgerRef = this.db.collection("cityPreparationObjectLedger").doc(ledgerId);
    const controlRef = this.db.collection("cityPreparationControl").doc("global");
    await this.db.runTransaction(async (transaction) => {
      const [ledger, control] = await Promise.all([transaction.get(ledgerRef), transaction.get(controlRef)]);
      if (ledger.exists) return;
      const imported = Number(control.data()?.cumulativeImportedBytes ?? 0);
      if (imported + bytes > ADMISSION_LIMITS.storagePauseBytes) {
        throw new PipelineError("storage-pause", "Storage import threshold reached");
      }
      transaction.create(ledgerRef, { objectKey, bytes, jobId, createdAt: new Date() });
      transaction.set(controlRef, {
        cumulativeImportedBytes: imported + bytes,
        updatedAt: new Date(),
      }, { merge: true });
    });
  }

  async saveCityAndCandidates(jobId: string, city: CityIdentity, candidates: AttractionCandidate[], expectedAttempt: number): Promise<void> {
    const jobRef = this.db.collection("cityPreparationJobs").doc(jobId);
    const job = await jobRef.get();
    this.assertAttempt(job.data(), expectedAttempt);
    const writer = this.db.batch();
    for (const [rank, candidate] of candidates.slice(0, LIMITS.candidateLimit).entries()) {
      writer.set(jobRef.collection("candidates").doc(candidate.qid), stripUndefined({ ...candidate, rank }));
    }
    writer.update(jobRef, { city, candidateCount: candidates.length, updatedAt: new Date() });
    await writer.commit();
  }

  async loadCandidates(jobId: string): Promise<AttractionCandidate[]> {
    const snapshot = await this.db.collection("cityPreparationJobs").doc(jobId).collection("candidates").get();
    return snapshot.docs
      .map((doc) => doc.data() as AttractionCandidate)
      .sort((a, b) => a.rank - b.rank || a.qid.localeCompare(b.qid));
  }

  async saveCheckpoint(jobId: string, checkpoint: JobCheckpoint, qualifiedCount: number, expectedAttempt: number): Promise<void> {
    await this.updateFenced(jobId, expectedAttempt, { checkpoint, qualifiedCount, updatedAt: new Date() });
  }

  async saveStagedPlace(jobId: string, place: PublishedPlace, expectedAttempt: number): Promise<void> {
    const jobRef = this.db.collection("cityPreparationJobs").doc(jobId);
    await this.db.runTransaction(async (transaction) => {
      const job = await transaction.get(jobRef);
      this.assertAttempt(job.data(), expectedAttempt);
      transaction.set(jobRef.collection("stagedPlaces").doc(place.id), stripUndefined(place));
    });
  }

  async loadStagedPlaces(jobId: string): Promise<PublishedPlace[]> {
    const snapshot = await this.db.collection("cityPreparationJobs").doc(jobId).collection("stagedPlaces").get();
    return snapshot.docs.map((doc) => doc.data() as PublishedPlace).sort((a, b) => a.id.localeCompare(b.id));
  }

  async publish(version: PublicVersion, jobId: string, expectedAttempt: number): Promise<void> {
    for (const place of version.places) {
      for (const photo of place.photos) {
        if (!photo.outputSha256 || !photo.objectKey) throw new PipelineError("invalid-publication", "Photo provenance missing");
      }
    }
    const cityRef = this.db.collection("cityCollections").doc(version.city.qid);
    const versionRef = cityRef.collection("versions").doc(version.versionId);
    const jobRef = this.db.collection("cityPreparationJobs").doc(jobId);
    const activeRef = this.db.collection("cityPreparationActive").doc(version.city.qid);
    await this.db.runTransaction(async (transaction) => {
      const [jobSnapshot, versionSnapshot, activeSnapshot] = await Promise.all([
        transaction.get(jobRef),
        transaction.get(versionRef),
        transaction.get(activeRef),
      ]);
      if (versionSnapshot.data()?.publishedAt) {
        if (versionSnapshot.data()?.placeCount === version.places.length && jobSnapshot.data()?.status === version.status) return;
        throw new PipelineError("immutable-version", "Published version cannot be changed");
      }
      this.assertAttempt(jobSnapshot.data(), expectedAttempt);
      if (activeSnapshot.data()?.jobId !== jobId) throw new PipelineError("active-job-changed", "Active city job changed");
      for (const place of version.places) transaction.create(versionRef.collection("places").doc(place.id), stripUndefined(place));
      transaction.create(versionRef, {
        versionId: version.versionId, city: version.city, status: version.status,
        placeCount: version.places.length, source: version.source, createdAt: version.createdAt,
        complete: true, publishedAt: version.createdAt,
      });
      transaction.set(cityRef, {
        city: version.city,
        publishedVersion: version.versionId,
        publishedStatus: version.status,
        publishedPlaceCount: version.places.length,
        publishedAt: version.createdAt,
        lastOutcome: version.status,
        lastTerminalAt: version.createdAt,
      }, { merge: true });
      transaction.update(jobRef, {
        status: version.status,
        qualifiedCount: version.places.length,
        publishedVersion: version.versionId,
        updatedAt: version.createdAt,
      });
      transaction.delete(activeRef);
    });
  }

  async finishEmpty(jobId: string, checkpoint: JobCheckpoint, expectedAttempt: number): Promise<void> {
    await this.finishTerminal(jobId, checkpoint, "empty", expectedAttempt);
  }

  async finishFailed(jobId: string, checkpoint: JobCheckpoint, failureCode: string, expectedAttempt: number): Promise<void> {
    await this.finishTerminal(jobId, checkpoint, "failed", expectedAttempt, failureCode);
  }

  async getPreparationForUser(cityQid: string, _uid: string): Promise<Record<string, unknown> | null> {
    const active = await this.db.collection("cityPreparationActive").doc(cityQid).get();
    if (active.data()?.jobId) {
      const job = await this.getJob(active.data()!.jobId);
      if (job) return publicJobView(job);
    }
    const query = this.db.collection("cityPreparationJobs").where("cityQid", "==", cityQid).limit(50);
    const snapshot = await query.get();
    if (snapshot.empty) return null;
    const latest = snapshot.docs.map((doc) => decodeJob(doc.data())).sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0];
    return latest ? publicJobView(latest) : null;
  }

  async getPublished(cityQid: string, requestedVersion?: string): Promise<Record<string, unknown> | null> {
    const cityRef = this.db.collection("cityCollections").doc(cityQid);
    const city = await cityRef.get();
    const versionId = requestedVersion ?? (city.data()?.publishedVersion as string | undefined);
    if (!versionId || !/^[A-Za-z0-9_-]{1,80}$/.test(versionId)) return null;
    const versionRef = cityRef.collection("versions").doc(versionId);
    const [version, places] = await Promise.all([
      versionRef.get(),
      versionRef.collection("places").limit(LIMITS.targetPlaces).get(),
    ]);
    if (!version.exists || version.data()?.complete !== true || !version.data()?.publishedAt) return null;
    return {
      versionId,
      city: version.data()?.city,
      status: version.data()?.status,
      placeCount: version.data()?.placeCount,
      createdAt: toIso(version.data()?.createdAt),
      places: places.docs.map((doc) => doc.data()),
    };
  }

  async pendingOutbox(limit = 20): Promise<Array<{ jobId: string; refPath: string }>> {
    const snapshot = await this.db.collection("cityPreparationOutbox").where("status", "==", "pending").limit(limit).get();
    return snapshot.docs.map((doc) => ({ jobId: doc.data().jobId as string, refPath: doc.ref.path }));
  }

  async recoverStaleRunning(now = new Date(), limit = 20): Promise<number> {
    const cutoff = new Date(now.getTime() - 22 * 60 * 1000);
    const snapshot = await this.db.collection("cityPreparationJobs")
      .where("status", "==", "running")
      .where("updatedAt", "<", cutoff)
      .limit(limit)
      .get();
    let recovered = 0;
    for (const doc of snapshot.docs) {
      await this.db.runTransaction(async (transaction) => {
        const fresh = await transaction.get(doc.ref);
        if (fresh.data()?.status !== "running" || dateValue(fresh.data()?.updatedAt).getTime() >= cutoff.getTime()) return;
        transaction.update(doc.ref, { status: "queued", updatedAt: now });
        transaction.set(this.db.collection("cityPreparationOutbox").doc(doc.id), {
          jobId: doc.id,
          status: "pending",
          attempts: 0,
          recoveredAt: now,
          updatedAt: now,
        }, { merge: true });
        recovered += 1;
      });
    }
    return recovered;
  }

  async markOutboxEnqueued(refPath: string): Promise<void> {
    await this.db.doc(refPath).update({ status: "enqueued", attempts: FieldValue.increment(1), updatedAt: new Date() });
  }

  async markOutboxAttempt(refPath: string, errorCode: string): Promise<void> {
    await this.db.doc(refPath).update({ attempts: FieldValue.increment(1), lastError: errorCode, updatedAt: new Date() });
  }

  private reusablePublication(data: DocumentData | undefined, now: Date): { versionId: string; status: "ready" | "partial" } | null {
    if (!data?.publishedVersion || !data.publishedAt) return null;
    const status = data.publishedStatus;
    if (status !== "ready" && status !== "partial") return null;
    const age = now.getTime() - dateValue(data.publishedAt).getTime();
    const maxAge = status === "ready" ? ADMISSION_LIMITS.freshDays * DAY_MS : ADMISSION_LIMITS.partialEmptyCooldownDays * DAY_MS;
    return age < maxAge ? { versionId: data.publishedVersion as string, status } : null;
  }

  private assertCooldown(data: DocumentData | undefined, now: Date): void {
    if (!data?.lastTerminalAt) return;
    const outcome = data.lastOutcome;
    const wait = outcome === "failed"
      ? ADMISSION_LIMITS.failureCooldownHours * 60 * 60 * 1000
      : outcome === "empty" || outcome === "partial"
        ? ADMISSION_LIMITS.partialEmptyCooldownDays * DAY_MS
        : 0;
    if (wait > 0 && now.getTime() - dateValue(data.lastTerminalAt).getTime() < wait) {
      throw new PipelineError("city-cooldown", "City retry cooldown is active");
    }
  }

  private async finishTerminal(jobId: string, checkpoint: JobCheckpoint, status: "empty" | "failed", expectedAttempt: number, failureCode?: string): Promise<void> {
    const jobRef = this.db.collection("cityPreparationJobs").doc(jobId);
    await this.db.runTransaction(async (transaction: Transaction) => {
      const job = await transaction.get(jobRef);
      if (!job.exists) return;
      if (["ready", "partial", "empty", "failed", "paused"].includes(job.data()!.status)) return;
      this.assertAttempt(job.data(), expectedAttempt);
      const cityQid = job.data()!.cityQid as string;
      const activeRef = this.db.collection("cityPreparationActive").doc(cityQid);
      const active = await transaction.get(activeRef);
      const now = new Date();
      transaction.update(jobRef, { status, checkpoint, failureCode: failureCode ?? null, updatedAt: now });
      transaction.set(this.db.collection("cityCollections").doc(cityQid), {
        lastOutcome: status,
        lastTerminalAt: now,
      }, { merge: true });
      if (active.data()?.jobId === jobId) transaction.delete(activeRef);
    });
  }

  private assertAttempt(data: DocumentData | undefined, expectedAttempt: number): void {
    if (!data || data.status !== "running" || Number(data.checkpoint?.attempt) !== expectedAttempt) {
      throw new PipelineError("stale-attempt", "Worker attempt no longer owns the job", true);
    }
  }

  private async updateFenced(jobId: string, expectedAttempt: number, update: DocumentData): Promise<void> {
    const ref = this.db.collection("cityPreparationJobs").doc(jobId);
    await this.db.runTransaction(async (transaction) => {
      const job = await transaction.get(ref);
      this.assertAttempt(job.data(), expectedAttempt);
      transaction.update(ref, update);
    });
  }
}

function decodeJob(data: DocumentData): CityPreparationJob {
  return {
    ...(data as CityPreparationJob),
    createdAt: dateValue(data.createdAt),
    updatedAt: dateValue(data.updatedAt),
  };
}

function dateValue(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") return new Date(value);
  return new Date(0);
}

function toIso(value: unknown): string | null {
  const date = dateValue(value);
  return date.getTime() > 0 ? date.toISOString() : null;
}

function publicJobView(job: CityPreparationJob): Record<string, unknown> {
  return {
    jobId: job.id,
    cityQid: job.cityQid,
    status: job.status,
    qualifiedCount: job.qualifiedCount,
    candidateCount: job.candidateCount ?? null,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
    failureCode: job.failureCode ?? null,
    publishedVersion: job.publishedVersion ?? null,
  };
}

function stripUndefined<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}
