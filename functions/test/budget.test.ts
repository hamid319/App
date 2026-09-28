import { describe, expect, it } from "vitest";
import { LIMITS } from "../src/domain/config.js";
import { JobBudget } from "../src/services/budget.js";

describe("durable download budgeting", () => {
  it("reserves the maximum before a request and refunds only after success", async () => {
    const snapshots: number[] = [];
    const counters = { metadataRequests: 0, thumbnailAttempts: 0, downloadedBytes: 0, activeRuntimeMs: 0 };
    const budget = new JobBudget(LIMITS, counters, Date.now(), async (value) => { snapshots.push(value.downloadedBytes); });
    await budget.beforeThumbnailAttempt(LIMITS.maxImageBytes);
    expect(counters.downloadedBytes).toBe(LIMITS.maxImageBytes);
    await budget.completeDownload(LIMITS.maxImageBytes, 128_000);
    expect(counters.downloadedBytes).toBe(128_000);
    expect(snapshots).toEqual([LIMITS.maxImageBytes, 128_000]);
  });

  it("keeps the reservation when a request never completes", async () => {
    const counters = { metadataRequests: 0, thumbnailAttempts: 0, downloadedBytes: 0, activeRuntimeMs: 0 };
    const budget = new JobBudget(LIMITS, counters);
    await budget.beforeThumbnailAttempt(LIMITS.maxImageBytes);
    expect(counters.downloadedBytes).toBe(LIMITS.maxImageBytes);
  });
});
