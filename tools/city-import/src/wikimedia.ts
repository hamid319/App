// Reads Wikidata, Wikipedia and Wikimedia Commons. The SPARQL strategy
// (one radius query per class, then exclusion pass) and the Commons photo
// lookup are adapted from the city pipeline's wikimedia.ts.

import { DEFAULTS, DISCOVERY_CLASSES, EXCLUDED_CLASSES } from "./config.js";
import type { WikimediaHttp } from "./http.js";
import type { Coordinates, Lang, Localized } from "./model.js";

export interface Candidate {
  wikidataId: string;
  coordinates: Coordinates;
  sitelinks: number;
  distanceKm: number;
  classQids: string[];
  p18Files: string[];
}

export interface EntityInfo {
  labels: Localized;
  descriptions: Localized;
  wikipediaTitles: Localized;
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

interface SparqlResponse {
  results?: { bindings?: Array<Record<string, { value: string } | undefined>> };
}

export class WikimediaSource {
  constructor(private readonly http: WikimediaHttp) {}

  async cityLocation(qid: string): Promise<{ coordinates: Coordinates; countryQid: string }> {
    const url = apiUrl("https://www.wikidata.org/w/api.php", {
      action: "wbgetentities",
      ids: qid,
      props: "claims",
    });
    const data = await this.http.json<{ entities?: Record<string, { claims?: Record<string, Claim[]> }> }>(url);
    const claims = data.entities?.[qid]?.claims ?? {};
    const coord = bestClaim(claims.P625)?.mainsnak?.datavalue?.value as
      | { latitude?: number; longitude?: number }
      | undefined;
    const country = (bestClaim(claims.P17)?.mainsnak?.datavalue?.value as { id?: string } | undefined)?.id;
    if (typeof coord?.latitude !== "number" || typeof coord.longitude !== "number" || !country) {
      throw new Error(`${qid} has no coordinates or country on Wikidata`);
    }
    return { coordinates: { lat: coord.latitude, lng: coord.longitude }, countryQid: country };
  }

  /** Places of the configured classes around a city, best-known first. */
  async findCandidates(
    center: Coordinates,
    countryQid: string,
    options: { radiusKm: number; minSitelinks: number; limit: number },
  ): Promise<Candidate[]> {
    const byId = new Map<string, Candidate>();
    for (const cls of DISCOVERY_CLASSES) {
      const query = `
SELECT DISTINCT ?item ?coord ?image ?sitelinks ?distance WHERE {
  SERVICE wikibase:around {
    ?item wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point(${center.lng} ${center.lat})"^^geo:wktLiteral;
                    wikibase:radius "${options.radiusKm}";
                    wikibase:distance ?distance.
  }
  ?item wdt:P31/wdt:P279? wd:${cls.qid}.
  ?item wikibase:sitelinks ?sitelinks.
  FILTER(?sitelinks >= ${options.minSitelinks})
  ?item wdt:P17 wd:${countryQid}.
  OPTIONAL { ?item wdt:P18 ?image. }
}
ORDER BY DESC(?sitelinks)
LIMIT ${options.limit}`;
      for (const row of await this.sparql(query)) {
        const id = entityId(row.item?.value);
        const coordinates = parseWktPoint(row.coord?.value);
        if (!id || !coordinates) continue;
        const image = commonsTitleFromUri(row.image?.value);
        const existing = byId.get(id);
        if (existing) {
          if (!existing.classQids.includes(cls.qid)) existing.classQids.push(cls.qid);
          if (image && !existing.p18Files.includes(image)) existing.p18Files.push(image);
          continue;
        }
        byId.set(id, {
          wikidataId: id,
          coordinates,
          sitelinks: Number(row.sitelinks?.value ?? 0),
          distanceKm: Number(row.distance?.value ?? 0),
          classQids: [cls.qid],
          p18Files: image ? [image] : [],
        });
      }
    }
    const ranked = [...byId.values()]
      .sort((a, b) => b.sitelinks - a.sitelinks || a.distanceKm - b.distanceKm)
      .slice(0, options.limit);
    const excluded = await this.excludedIds(ranked.map((c) => c.wikidataId));
    return ranked.filter((c) => !excluded.has(c.wikidataId));
  }

  /** Labels, short descriptions and Wikipedia titles in English and German. */
  async entityInfo(qids: string[]): Promise<Map<string, EntityInfo>> {
    const result = new Map<string, EntityInfo>();
    for (let i = 0; i < qids.length; i += 50) {
      const url = apiUrl("https://www.wikidata.org/w/api.php", {
        action: "wbgetentities",
        ids: qids.slice(i, i + 50).join("|"),
        props: "labels|descriptions|sitelinks",
        languages: "en|de",
        sitefilter: "enwiki|dewiki",
      });
      const data = await this.http.json<{
        entities?: Record<string, {
          labels?: Record<string, { value?: string }>;
          descriptions?: Record<string, { value?: string }>;
          sitelinks?: Record<string, { title?: string }>;
        }>;
      }>(url);
      for (const [id, entity] of Object.entries(data.entities ?? {})) {
        result.set(id, {
          labels: pick({ en: entity.labels?.en?.value, de: entity.labels?.de?.value }),
          descriptions: pick({ en: entity.descriptions?.en?.value, de: entity.descriptions?.de?.value }),
          wikipediaTitles: pick({ en: entity.sitelinks?.enwiki?.title, de: entity.sitelinks?.dewiki?.title }),
        });
      }
    }
    return result;
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
  async photoFiles(candidates: Candidate[]): Promise<Map<string, string[]>> {
    const result = new Map(candidates.map((c) => [c.wikidataId, [...c.p18Files]]));
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

  async photoMetadata(fileTitles: string[]): Promise<Map<string, PhotoMetadata>> {
    const result = new Map<string, PhotoMetadata>();
    for (let i = 0; i < fileTitles.length; i += 50) {
      const url = apiUrl("https://commons.wikimedia.org/w/api.php", {
        action: "query",
        titles: fileTitles.slice(i, i + 50).join("|"),
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

  private async excludedIds(qids: string[]): Promise<Set<string>> {
    const excluded = new Set<string>();
    const roots = EXCLUDED_CLASSES.map((q) => `wd:${q}`).join(" ");
    for (let i = 0; i < qids.length; i += 80) {
      const query = `
SELECT DISTINCT ?item WHERE {
  VALUES ?item { ${qids.slice(i, i + 80).map((q) => `wd:${q}`).join(" ")} }
  VALUES ?root { ${roots} }
  ?item wdt:P31/wdt:P279?/wdt:P279?/wdt:P279? ?root.
}`;
      for (const row of await this.sparql(query)) {
        const id = entityId(row.item?.value);
        if (id) excluded.add(id);
      }
    }
    return excluded;
  }

  private async sparql(query: string) {
    const url = new URL("https://query.wikidata.org/sparql");
    url.searchParams.set("query", query);
    url.searchParams.set("format", "json");
    const data = await this.http.json<SparqlResponse>(url, 65_000);
    return data.results?.bindings ?? [];
  }
}

interface Claim {
  rank?: "preferred" | "normal" | "deprecated";
  mainsnak?: { snaktype?: string; datavalue?: { value?: unknown } };
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

function entityId(uri: string | undefined): string | null {
  return uri?.match(/\/(Q[1-9][0-9]*)$/)?.[1] ?? null;
}

function parseWktPoint(value: string | undefined): Coordinates | null {
  const match = value?.match(/^Point\((-?[0-9.]+) (-?[0-9.]+)\)$/);
  return match ? { lng: Number(match[1]), lat: Number(match[2]) } : null;
}

function commonsTitleFromUri(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const name = decodeURIComponent(new URL(value).pathname).split("/").pop();
    return name ? normalizeFileTitle(name) : null;
  } catch {
    return null;
  }
}

export function normalizeFileTitle(value: string): string {
  const normalized = value.replace(/_/g, " ").trim();
  return normalized.startsWith("File:") ? normalized : `File:${normalized}`;
}
