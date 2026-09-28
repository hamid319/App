import { PipelineError } from "../domain/errors.js";
import type { JobCounters, PipelineLimits } from "../domain/types.js";

export class JobBudget {
  constructor(
    private readonly limits: PipelineLimits,
    public readonly counters: JobCounters,
    private readonly attemptStartedAt = Date.now(),
    private readonly persist: (counters: JobCounters) => Promise<void> = async () => undefined,
  ) {}

  async beforeMetadataRequest(): Promise<void> {
    this.assertRuntime();
    if (this.counters.metadataRequests >= this.limits.metadataRequests) {
      throw new PipelineError("metadata-request-limit", "Metadata request limit reached");
    }
    this.counters.metadataRequests += 1;
    await this.persist(this.counters);
  }

  async beforeThumbnailAttempt(maxReservedBytes: number): Promise<void> {
    this.assertRuntime();
    if (this.counters.thumbnailAttempts >= this.limits.thumbnailAttempts) {
      throw new PipelineError("thumbnail-attempt-limit", "Thumbnail attempt limit reached");
    }
    this.counters.thumbnailAttempts += 1;
    if (this.counters.downloadedBytes + maxReservedBytes > this.limits.maxJobDownloadBytes) {
      throw new PipelineError("job-download-limit", "Job download limit reached");
    }
    this.counters.downloadedBytes += maxReservedBytes;
    await this.persist(this.counters);
  }

  addDownloadedBytes(bytes: number): void {
    if (!Number.isSafeInteger(bytes) || bytes < 0) {
      throw new PipelineError("invalid-byte-count", "Invalid downloaded byte count");
    }
    // Download capacity is reserved durably before each request. This method
    // validates observed byte counts without charging them a second time.
    if (bytes > this.limits.maxImageBytes) throw new PipelineError("source-image-too-large", "Source image exceeds limit");
  }

  async completeDownload(reservedBytes: number, actualBytes: number): Promise<void> {
    if (actualBytes < 0 || actualBytes > reservedBytes) {
      throw new PipelineError("invalid-byte-count", "Invalid completed download size");
    }
    this.counters.downloadedBytes -= reservedBytes - actualBytes;
    await this.persist(this.counters);
  }

  async finishAttempt(): Promise<void> {
    this.counters.activeRuntimeMs += Date.now() - this.attemptStartedAt;
    await this.persist(this.counters);
  }

  assertRuntime(now = Date.now()): void {
    if (now - this.attemptStartedAt >= this.limits.attemptRuntimeMs) {
      throw new PipelineError("attempt-runtime-limit", "Attempt runtime limit reached", true);
    }
    if (
      this.counters.activeRuntimeMs + (now - this.attemptStartedAt) >=
      this.limits.totalRuntimeMs
    ) {
      throw new PipelineError("job-runtime-limit", "Job runtime limit reached");
    }
  }
}
