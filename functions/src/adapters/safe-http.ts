import { PipelineError } from "../domain/errors.js";
import { assertSafeWikimediaUrl } from "../domain/validation.js";
import { WIKIMEDIA_USER_AGENT } from "../domain/config.js";
import type { JobBudget } from "../services/budget.js";

export interface JsonRequestOptions {
  timeoutMs?: number;
  headers?: Record<string, string>;
}

export class WikimediaHttpClient {
  constructor(
    private readonly budget: JobBudget,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async json<T>(url: URL, options: JsonRequestOptions = {}): Promise<T> {
    await this.budget.beforeMetadataRequest();
    this.assertMetadataUrl(url);
    const response = await this.fetchWithTimeout(url, {
      headers: {
        Accept: "application/json",
        "User-Agent": WIKIMEDIA_USER_AGENT,
        ...options.headers,
      },
      redirect: "error",
    }, options.timeoutMs ?? 20_000);
    if (!response.ok) throw this.httpError(response);
    const contentType = response.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("json")) {
      throw new PipelineError("invalid-upstream-content", "Expected JSON response");
    }
    const body = await this.readLimited(response, 2 * 1024 * 1024);
    try {
      return JSON.parse(body.toString("utf8")) as T;
    } catch {
      throw new PipelineError("invalid-upstream-json", "Malformed JSON response");
    }
  }

  async download(rawUrl: string, maxBytes: number): Promise<Buffer> {
    let current = assertSafeWikimediaUrl(rawUrl);
    for (let redirects = 0; redirects <= 3; redirects += 1) {
      await this.budget.beforeThumbnailAttempt(maxBytes);
      const response = await this.fetchWithTimeout(current, {
        headers: { "User-Agent": WIKIMEDIA_USER_AGENT, Accept: "image/*" },
        redirect: "manual",
      }, 30_000);
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get("location");
        await response.body?.cancel();
        if (!location || redirects === 3) {
          throw new PipelineError("unsafe-media-redirect", "Invalid media redirect");
        }
        current = assertSafeWikimediaUrl(new URL(location, current).toString());
        continue;
      }
      if (!response.ok) {
        await response.body?.cancel();
        throw this.httpError(response);
      }
      const contentType = (response.headers.get("content-type") ?? "").split(";")[0].trim();
      if (!new Set(["image/jpeg", "image/png", "image/webp"]).has(contentType)) {
        await response.body?.cancel();
        throw new PipelineError("invalid-media-type", `Rejected content type ${contentType}`);
      }
      const declared = Number(response.headers.get("content-length") ?? "0");
      if (declared > maxBytes) {
        await response.body?.cancel();
        throw new PipelineError("source-image-too-large", "Source image exceeds limit");
      }
      if (!response.body) throw new PipelineError("empty-media", "Media body is empty");
      const chunks: Buffer[] = [];
      let received = 0;
      const reader = response.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        received += value.byteLength;
        this.budget.addDownloadedBytes(received);
        if (received > maxBytes) {
          await reader.cancel();
          throw new PipelineError("source-image-too-large", "Source image exceeds limit");
        }
        chunks.push(Buffer.from(value));
      }
      await this.budget.completeDownload(maxBytes, received);
      return Buffer.concat(chunks);
    }
    throw new PipelineError("unsafe-media-redirect", "Too many redirects");
  }

  private assertMetadataUrl(url: URL): void {
    const host = url.hostname.toLowerCase();
    if (
      url.protocol !== "https:" ||
      !new Set([
        "www.wikidata.org",
        "query.wikidata.org",
        "commons.wikimedia.org",
        "commons-query.wikimedia.org",
      ]).has(host) ||
      url.username ||
      url.password ||
      (url.port && url.port !== "443")
    ) {
      throw new PipelineError("unsafe-metadata-url", "Metadata URL is not allowlisted");
    }
  }

  private async fetchWithTimeout(
    url: URL,
    init: RequestInit,
    timeoutMs: number,
  ): Promise<Response> {
    const signal = AbortSignal.timeout(timeoutMs);
    try {
      return await this.fetchImpl(url, { ...init, signal });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Network failure";
      throw new PipelineError("upstream-network", message, true);
    }
  }

  private httpError(response: Response): PipelineError {
    const status = response.status;
    const retryable = status === 429 || status >= 500;
    const retryAfter = Number(response.headers.get("retry-after") ?? "");
    return new PipelineError(
      `upstream-http-${status}`,
      `Upstream returned ${status}`,
      retryable,
      Number.isFinite(retryAfter) && retryAfter >= 0 ? retryAfter : undefined,
    );
  }

  private async readLimited(response: Response, maxBytes: number): Promise<Buffer> {
    if (!response.body) throw new PipelineError("empty-upstream-body", "Response body is empty");
    const reader = response.body.getReader();
    const chunks: Buffer[] = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > maxBytes) {
          await reader.cancel();
          throw new PipelineError("upstream-body-too-large", "Upstream body exceeds limit");
        }
        chunks.push(Buffer.from(value));
      }
    } catch (error) {
      if (error instanceof PipelineError) throw error;
      throw new PipelineError("upstream-body-read", "Failed to read upstream body", true);
    }
    return Buffer.concat(chunks);
  }
}
