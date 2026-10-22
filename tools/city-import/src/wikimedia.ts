// Reads Wikidata, Wikipedia and Wikimedia Commons. The SPARQL strategy
// (one radius query per class, then exclusion pass) and the Commons photo
// lookup are adapted from the city pipeline's wikimedia.ts.

import { DEFAULTS } from "./config.js";
import type { WikimediaHttp } from "./http.js";
import type { Coordinates, Lang, Localized } from "./model.js";

/** A place whose photos to look up: its Wikidata id and files already known (P18, OSM tags). */
export interface PhotoLookup {
  wikidataId: string;
  knownFiles: string[];
}

export interface EntityInfo {
  labels: Localized;
  descriptions: Localized;
  wikipediaTitles: Localized;
  /** Main image (P18) file titles. */
  imageFiles: string[];
  /** Commons category with more photos (P373), without the "Category:" prefix. */
  commonsCategory?: string;
  coordinates?: Coordinates;
}

export interface WikipediaSummary {
  text: string;
  url: string;
}

export interface PhotoMetadata {
  fileTitle: string;
  pageId: number;
  thumbnailUrl: string;
  width: number;
  height: number;
  mime: string;
  mediaType: string;
  creator: string;
  licenseShortName: string;
  licenseUrl: string;
  description: string;
  categories: string[];
}

/** Depicting files checked per place; most are skipped for size or licence. */
const DEPICTS_PER_PLACE = 12;

export class WikimediaSource {
  constructor(private readonly http: WikimediaHttp) {}

  /** Labels, short descriptions, Wikipedia titles (EN/DE), main image and coordinates. */
  async entityInfo(qids: string[]): Promise<Map<string, EntityInfo>> {
    const result = new Map<string, EntityInfo>();
    for (let i = 0; i < qids.length; i += 50) {
      const url = apiUrl("https://www.wikidata.org/w/api.php", {
        action: "wbgetentities",
        ids: qids.slice(i, i + 50).join("|"),
        props: "labels|descriptions|sitelinks|claims",
        languages: "en|de",
        sitefilter: "enwiki|dewiki",
      });
      const data = await this.http.json<{
        entities?: Record<string, {
          labels?: Record<string, { value?: string }>;
          descriptions?: Record<string, { value?: string }>;
          sitelinks?: Record<string, { title?: string }>;
          claims?: Record<string, Claim[]>;
        }>;
      }>(url, 30_000, 16 * 1024 * 1024);
      for (const [id, entity] of Object.entries(data.entities ?? {})) {
        const coord = bestClaim(entity.claims?.P625)?.mainsnak?.datavalue?.value as
          | { latitude?: number; longitude?: number }
          | undefined;
        result.set(id, {
          labels: pick({ en: entity.labels?.en?.value, de: entity.labels?.de?.value }),
          descriptions: pick({ en: entity.descriptions?.en?.value, de: entity.descriptions?.de?.value }),
          wikipediaTitles: pick({ en: entity.sitelinks?.enwiki?.title, de: entity.sitelinks?.dewiki?.title }),
          imageFiles: (entity.claims?.P18 ?? [])
            .filter((c) => c.rank !== "deprecated")
            .map((c) => c.mainsnak?.datavalue?.value)
            .filter((v): v is string => typeof v === "string")
            .map(normalizeFileTitle),
          ...(typeof bestClaim(entity.claims?.P373)?.mainsnak?.datavalue?.value === "string"
            ? { commonsCategory: bestClaim(entity.claims?.P373)!.mainsnak!.datavalue!.value as string }
            : {}),
          ...(typeof coord?.latitude === "number" && typeof coord.longitude === "number"
            ? { coordinates: { lat: coord.latitude, lng: coord.longitude } }
            : {}),
        });
      }
    }
    return result;
  }

  /** Wikidata items whose label matches [name] (English search), best first. */
  async searchEntities(name: string, limit = 20): Promise<string[]> {
    const url = apiUrl("https://www.wikidata.org/w/api.php", {
      action: "wbsearchentities",
      search: name,
      language: "en",
      uselang: "en",
      type: "item",
      limit: String(limit),
    });
    const data = await this.http.json<{ search?: Array<{ id?: string }> }>(url);
    return (data.search ?? []).map((hit) => hit.id).filter((id): id is string => Boolean(id && /^Q\d+$/.test(id)));
  }

  /** Lead paragraph of a Wikipedia article (CC BY-SA), or null for missing/disambiguation pages. */
  async wikipediaSummary(lang: Lang, title: string): Promise<WikipediaSummary | null> {
    const url = new URL(
      `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title.replace(/ /g, "_"))}`,
    );
    try {
      const data = await this.http.json<{
        type?: string;
        extract?: string;
        content_urls?: { desktop?: { page?: string } };
      }>(url);
      if (data.type !== "standard" || !data.extract?.trim()) return null;
      return {
        text: shortenText(data.extract, DEFAULTS.descriptionMaxChars),
        url: data.content_urls?.desktop?.page ?? `https://${lang}.wikipedia.org/wiki/${encodeURIComponent(title)}`,
      };
    } catch {
      return null;
    }
  }

  /**
   * Commons files per place: its main image (P18), then files tagged as
   * depicting it. One search per place: combined searches let the most
   * photographed place fill all result slots, and every hit of a
   * single-place search depicts that place, so no extra lookup is needed.
   */
  async photoFiles(candidates: PhotoLookup[]): Promise<Map<string, string[]>> {
    const result = new Map(candidates.map((c) => [c.wikidataId, [...c.knownFiles]]));
    for (const candidate of candidates) {
      const url = apiUrl("https://commons.wikimedia.org/w/api.php", {
        action: "query",
        list: "search",
        srsearch: `haswbstatement:P180=${candidate.wikidataId}`,
        srnamespace: "6",
        srlimit: String(DEPICTS_PER_PLACE),
        srprop: "",
      });
      const hits = (await this.http.json<{ query?: { search?: Array<{ title: string }> } }>(url)).query?.search ?? [];
      const files = result.get(candidate.wikidataId)!;
      for (const hit of hits) {
        const title = normalizeFileTitle(hit.title);
        if (!files.includes(title)) files.push(title);
      }
    }
    return result;
  }

  /** Image files in a Commons category (first [limit]), e.g. "Miradouro de Santa Luzia". */
  async categoryFiles(category: string, limit = 15): Promise<string[]> {
    const url = apiUrl("https://commons.wikimedia.org/w/api.php", {
      action: "query",
      list: "categorymembers",
      cmtitle: `Category:${category.replace(/^Category:/, "")}`,
      cmtype: "file",
      cmlimit: String(limit),
    });
    const data = await this.http.json<{ query?: { categorymembers?: Array<{ title: string }> } }>(url);
    return (data.query?.categorymembers ?? [])
      .map((m) => normalizeFileTitle(m.title))
      .filter((t) => /\.(jpe?g|png|webp)$/i.test(t));
  }

  async photoMetadata(fileTitles: string[]): Promise<Map<string, PhotoMetadata>> {
    const result = new Map<string, PhotoMetadata>();
    for (const batch of urlSafeBatches(fileTitles, 50, 6000)) {
      const url = apiUrl("https://commons.wikimedia.org/w/api.php", {
        action: "query",
        titles: batch.join("|"),
        prop: "imageinfo|categories",
        iiprop: "url|size|mime|mediatype|extmetadata",
        iiurlwidth: String(DEFAULTS.outputLongEdge),
        cllimit: "max",
      });
      const data = await this.http.json<{
        query?: { pages?: Array<{
          pageid?: number;
          title?: string;
          categories?: Array<{ title: string }>;
          imageinfo?: Array<{
            url?: string;
            thumburl?: string;
            width?: number;
            height?: number;
            mime?: string;
            mediatype?: string;
            extmetadata?: Record<string, { value?: string }>;
          }>;
        }> };
      }>(url);
      for (const page of data.query?.pages ?? []) {
        const info = page.imageinfo?.[0];
        if (!info || !page.pageid || page.pageid < 0 || !page.title) continue;
        const ext = info.extmetadata ?? {};
        const title = normalizeFileTitle(page.title);
        result.set(title, {
          fileTitle: title,
          pageId: page.pageid,
          thumbnailUrl: info.thumburl ?? info.url ?? "",
          width: info.width ?? 0,
          height: info.height ?? 0,
          mime: info.mime ?? "",
          mediaType: info.mediatype ?? "",
          creator: plainText(ext.Artist?.value),
          licenseShortName: plainText(ext.LicenseShortName?.value),
          licenseUrl: plainText(ext.LicenseUrl?.value),
          description: plainText(ext.ImageDescription?.value),
          categories: (page.categories ?? []).map((c) => c.title),
        });
      }
    }
    return result;
  }

}

interface Claim {
  rank?: "preferred" | "normal" | "deprecated";
  mainsnak?: { snaktype?: string; datavalue?: { value?: unknown } };
}

/**
 * Groups titles so each request has at most [maxCount] of them and stays
 * under [maxEncodedChars] once URL-encoded: long non-Latin file names
 * (Thai, Japanese) otherwise produce "414 URI too long".
 */
export function urlSafeBatches(titles: string[], maxCount: number, maxEncodedChars: number): string[][] {
  const batches: string[][] = [];
  let current: string[] = [];
  let length = 0;
  for (const title of titles) {
    const size = encodeURIComponent(title).length + 3;
    if (current.length > 0 && (current.length >= maxCount || length + size > maxEncodedChars)) {
      batches.push(current);
      current = [];
      length = 0;
    }
    current.push(title);
    length += size;
  }
  if (current.length > 0) batches.push(current);
  return batches;
}

function bestClaim(claims: Claim[] | undefined): Claim | undefined {
  const live = (claims ?? []).filter((c) => c.rank !== "deprecated" && c.mainsnak?.snaktype === "value");
  return live.find((c) => c.rank === "preferred") ?? live[0];
}

function apiUrl(base: string, params: Record<string, string>): URL {
  const url = new URL(base);
  url.searchParams.set("format", "json");
  url.searchParams.set("formatversion", "2");
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return url;
}

function pick(values: Record<Lang, string | undefined>): Localized {
  const result: Localized = {};
  for (const [lang, value] of Object.entries(values) as Array<[Lang, string | undefined]>) {
    const text = plainText(value);
    if (text) result[lang] = text;
  }
  return result;
}

export function plainText(value: string | undefined): string {
  if (!value) return "";
  return value
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#0?39;/gi, "'")
    .replace(/\s+/g, " ")
    .trim();
}

/** Whole sentences up to [maxChars]; falls back to a word boundary. */
export function shortenText(text: string, maxChars: number): string {
  const clean = plainText(text);
  if (clean.length <= maxChars) return clean;
  const sentences = clean.match(/[^.!?]+[.!?]+(\s|$)/g) ?? [];
  let out = "";
  for (const sentence of sentences) {
    if ((out + sentence).trim().length > maxChars) break;
    out += sentence;
  }
  if (out.trim()) return out.trim();
  const cut = clean.slice(0, maxChars);
  return `${cut.slice(0, cut.lastIndexOf(" "))}…`;
}




export function normalizeFileTitle(value: string): string {
  const normalized = value.replace(/_/g, " ").trim();
  return normalized.startsWith("File:") ? normalized : `File:${normalized}`;
}
