// HTTP client for Wikimedia APIs. Adapted from the city pipeline's
// safe-http.ts (functions/src/adapters on feature/city-collection-pipeline):
// host allowlist, size limits, no credentials in URLs. Added: retries with
// backoff for 429/5xx and a small pause between requests, as the Wikimedia
// API etiquette asks for.

import { USER_AGENT } from "./config.js";

const METADATA_HOSTS = new Set([
  "www.wikidata.org",
  "query.wikidata.org",
  "commons.wikimedia.org",
  "en.wikipedia.org",
  "de.wikipedia.org",
  "overpass-api.de",
]);
const MEDIA_HOSTS = new Set(["upload.wikimedia.org", "thumb.wikimedia.org"]);
const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

export class HttpError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
  }
}

export interface HttpOptions {
  fetchImpl?: typeof fetch;
  /** Pause between requests in ms (default 150). */
  pauseMs?: number;
  retries?: number;
  sleep?: (ms: number) => Promise<void>;
}

export class WikimediaHttp {
  private readonly fetchImpl: typeof fetch;
  private readonly pauseMs: number;
  private readonly retries: number;
  private readonly sleep: (ms: number) => Promise<void>;
  requestCount = 0;

  constructor(options: HttpOptions = {}) {
    this.fetchImpl = options.fetchImpl ?? fetch;
    this.pauseMs = options.pauseMs ?? 150;
    this.retries = options.retries ?? 3;
    this.sleep = options.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  }

  async json<T>(url: URL, timeoutMs = 30_000, maxBytes = 4 * 1024 * 1024): Promise<T> {
    assertHost(url, METADATA_HOSTS);
    const response = await this.request(url, { Accept: "application/json" }, timeoutMs);
    const text = await readLimited(response, maxBytes);
    try {
      return JSON.parse(text.toString("utf8")) as T;
    } catch {
      throw new HttpError(`Malformed JSON from ${url.hostname}`);
    }
  }

  async image(rawUrl: string, maxBytes: number): Promise<Buffer> {
    const url = new URL(rawUrl);
    assertHost(url, MEDIA_HOSTS);
    const response = await this.request(url, { Accept: "image/*" }, 60_000);
    const type = (response.headers.get("content-type") ?? "").split(";")[0].trim();
    if (!IMAGE_TYPES.has(type)) {
      await response.body?.cancel();
      throw new HttpError(`Unexpected content type ${type}`);
    }
    return readLimited(response, maxBytes);
  }

  private async request(url: URL, headers: Record<string, string>, timeoutMs: number): Promise<Response> {
    for (let attempt = 0; ; attempt += 1) {
      if (this.pauseMs > 0) await this.sleep(this.pauseMs);
      this.requestCount += 1;
      let response: Response;
      try {
        response = await this.fetchImpl(url, {
          headers: { "User-Agent": USER_AGENT, ...headers },
          redirect: "follow",
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (error) {
        if (attempt < this.retries) {
          await this.sleep(backoffMs(attempt));
          continue;
        }
        throw new HttpError(`Network error for ${url.hostname}: ${(error as Error).message}`);
      }
      if (response.ok) return response;
      const retryable = response.status === 429 || response.status >= 500;
      await response.body?.cancel();
      if (retryable && attempt < this.retries) {
        const retryAfter = Number(response.headers.get("retry-after"));
        await this.sleep(Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : backoffMs(attempt));
        continue;
      }
      throw new HttpError(`${url.hostname} returned ${response.status}`, response.status);
    }
  }
}

function backoffMs(attempt: number): number {
  return 2_000 * 2 ** attempt;
}

function assertHost(url: URL, allowed: Set<string>): void {
  if (url.protocol !== "https:" || !allowed.has(url.hostname) || url.username || url.password) {
    throw new HttpError(`Host not allowed: ${url.hostname}`);
  }
}

async function readLimited(response: Response, maxBytes: number): Promise<Buffer> {
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (declared > maxBytes) {
    await response.body?.cancel();
    throw new HttpError("Response too large");
  }
  if (!response.body) throw new HttpError("Empty response body");
  const reader = response.body.getReader();
  const chunks: Buffer[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      throw new HttpError("Response too large");
    }
    chunks.push(Buffer.from(value));
  }
  return Buffer.concat(chunks);
}
