// Keeps the import inside Cloudflare R2's free tier.
//
// Free tier (per month, as of 2026, check https://developers.cloudflare.com/r2/pricing/):
// 10 GB-month storage, 1 million Class A operations (writes, lists),
// 10 million Class B operations (reads, HEAD); egress is free.
// The defaults below stay far under that; .env can lower or raise them.

export class BudgetExceeded extends Error {}

export interface UploadBudgetLimits {
  /** Max total bytes in the bucket after this run. */
  maxBucketBytes: number;
  /** Max objects uploaded in one run (each is a Class A operation). */
  maxUploadsPerRun: number;
}

export const DEFAULT_LIMITS: UploadBudgetLimits = {
  maxBucketBytes: 5 * 1024 ** 3, // 5 GB, half of the free 10 GB
  maxUploadsPerRun: 20_000, // 2 % of the free 1 million Class A operations
};

export class UploadBudget {
  private bytes: number;
  private uploads = 0;

  constructor(bucketBytesNow: number, private readonly limits: UploadBudgetLimits = DEFAULT_LIMITS) {
    this.bytes = bucketBytesNow;
    if (bucketBytesNow > limits.maxBucketBytes) {
      throw new BudgetExceeded(`Bucket already holds ${gb(bucketBytesNow)}, above the limit of ${gb(limits.maxBucketBytes)}`);
    }
  }

  /** Call before each upload; throws instead of going over a limit. */
  reserve(bytes: number): void {
    if (this.uploads + 1 > this.limits.maxUploadsPerRun) {
      throw new BudgetExceeded(`Upload limit of ${this.limits.maxUploadsPerRun} objects per run reached`);
    }
    if (this.bytes + bytes > this.limits.maxBucketBytes) {
      throw new BudgetExceeded(`Bucket would exceed ${gb(this.limits.maxBucketBytes)}`);
    }
    this.uploads += 1;
    this.bytes += bytes;
  }

  get usedBytes(): number {
    return this.bytes;
  }

  get uploadCount(): number {
    return this.uploads;
  }
}

export function gb(bytes: number): string {
  return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
}
