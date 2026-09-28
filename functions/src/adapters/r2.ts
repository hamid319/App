import { HeadObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { PipelineError } from "../domain/errors.js";

export interface ObjectStore {
  putImmutable(key: string, bytes: Buffer, metadata: Record<string, string>): Promise<string>;
  verify(key: string, expectedSha256: string): Promise<void>;
}

export interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicBaseUrl: string;
}

export class R2ObjectStore implements ObjectStore {
  private readonly client: S3Client;

  constructor(private readonly config: R2Config) {
    this.client = new S3Client({
      region: "auto",
      endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
    });
  }

  async putImmutable(key: string, bytes: Buffer, metadata: Record<string, string>): Promise<string> {
    await this.client.send(new PutObjectCommand({
      Bucket: this.config.bucket,
      Key: key,
      Body: bytes,
      ContentType: "image/webp",
      CacheControl: "public, max-age=31536000, immutable",
      Metadata: metadata,
      IfNoneMatch: "*",
    })).catch((error: unknown) => {
      const status = (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
      if (status !== 412) {
        const message = error instanceof Error ? error.message : "R2 upload failed";
        throw new PipelineError("r2-upload", message, status === undefined || status === 429 || status >= 500);
      }
    });
    return `${this.config.publicBaseUrl.replace(/\/$/, "")}/${key.split("/").map(encodeURIComponent).join("/")}`;
  }

  async verify(key: string, expectedSha256: string): Promise<void> {
    const response = await this.client.send(new HeadObjectCommand({
      Bucket: this.config.bucket,
      Key: key,
    })).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : "R2 verification failed";
      throw new PipelineError("r2-head", message, true);
    });
    if (response.Metadata?.sha256 !== expectedSha256 || response.ContentType !== "image/webp") {
      throw new PipelineError("r2-object-verification", `Object verification failed for ${key}`, true);
    }
  }
}
