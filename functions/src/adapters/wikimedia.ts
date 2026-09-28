import {
  ALLOWED_CITY_ROOT_TYPES,
  ATTRACTION_TYPE_ROOTS,
  EXCLUDED_TYPE_ROOTS,
  LIMITS,
} from "../domain/config.js";
import { PipelineError } from "../domain/errors.js";
import type {
  AttractionCandidate,
  CityIdentity,
  CommonsPhotoCandidate,
  CommonsPhotoMetadata,
  Coordinates,
} from "../domain/types.js";
import { assertCoordinates, assertEarthGlobe, isQid, sanitizePlainText } from "../domain/validation.js";
import type { WikimediaHttpClient } from "./safe-http.js";

interface WikidataSnak {
  snaktype?: string;
  datavalue?: { value?: unknown };
}
interface WikidataClaim {
  rank?: "preferred" | "normal" | "deprecated";
  mainsnak?: WikidataSnak;
}
interface WikidataEntity {
  id?: string;
  lastrevid?: number;
  modified?: string;
  labels?: Record<string, { value?: string }>;
  descriptions?: Record<string, { value?: string }>;
  claims?: Record<string, WikidataClaim[]>;
}
interface EntityResponse { entities?: Record<string, WikidataEntity> }
interface SparqlBinding {
  [key: string]: { value: string } | undefined;
}
interface SparqlResponse { results?: { bindings?: SparqlBinding[] } }

export class WikimediaSource {
  constructor(private readonly http: WikimediaHttpClient) {}

  async resolveCity(qid: string): Promise<CityIdentity> {
    const entity = await this.getEntity(qid);
    const label = sanitizePlainText(entity.labels?.en?.value);
    if (!label) throw new PipelineError("invalid-city-name", "City has no English label");

    const typeQids = this.bestEntityIds(entity.claims?.P31);
    if (!typeQids.some((type) => ALLOWED_CITY_ROOT_TYPES.has(type))) {
      const isSettlement = await this.isSubclassOfAny(typeQids, ALLOWED_CITY_ROOT_TYPES, 4);
      if (!isSettlement) throw new PipelineError("invalid-city-type", "Entity is not a settlement");
    }
    const countries = this.bestEntityIds(entity.claims?.P17);
    if (countries.length !== 1) {
      throw new PipelineError("ambiguous-city-country", "City must have one best-rank country");
    }
    const coordinates = this.bestCoordinates(entity.claims?.P625);
    if (coordinates.length !== 1) {
      throw new PipelineError("ambiguous-city-coordinates", "City must have one best-rank coordinate");
    }
    assertCoordinates(coordinates[0].coordinates);
    assertEarthGlobe(coordinates[0].globeQid);
    const countryName = sanitizePlainText((await this.getEntities([countries[0]], "labels")).get(countries[0])?.labels?.en?.value);
    if (!countryName) throw new PipelineError("invalid-city-country", "Country has no English label");
    return { qid, name: label, countryQid: countries[0], countryName, coordinates: coordinates[0].coordinates };
  }

  async findAttractions(city: CityIdentity): Promise<AttractionCandidate[]> {
    const query = `
SELECT DISTINCT ?item ?coord ?image ?sitelinks ?distance
WHERE {
  SERVICE wikibase:around {
    ?item wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point(${city.coordinates.longitude} ${city.coordinates.latitude})"^^geo:wktLiteral;
                    wikibase:radius "${LIMITS.radiusKm}";
                    wikibase:distance ?distance.
  }
  ?item wdt:P17 wd:${city.countryQid}; wikibase:sitelinks ?sitelinks.
  OPTIONAL { ?item wdt:P18 ?image. }
}
ORDER BY DESC(?sitelinks) ?item
LIMIT ${LIMITS.candidateLimit}`;
    const url = new URL("https://query.wikidata.org/sparql");
    url.searchParams.set("query", query);
    url.searchParams.set("format", "json");
    const response = await this.http.json<SparqlResponse>(url);
    const grouped = new Map<string, AttractionCandidate>();
    for (const row of response.results?.bindings ?? []) {
      const qid = entityId(row.item?.value);
      const coord = parseWktPoint(row.coord?.value);
      if (!qid || !coord || !isQid(qid)) continue;
      const existing = grouped.get(qid);
      const image = commonsTitleFromUri(row.image?.value);
      if (existing) {
        if (image && !existing.p18Files.includes(image)) existing.p18Files.push(image);
        continue;
      }
      grouped.set(qid, {
        rank: 0,
        qid,
        name: qid,
        coordinates: coord,
        countryQid: city.countryQid,
        types: [],
        typeLabels: [],
        sitelinks: Number(row.sitelinks?.value ?? 0),
        distanceKm: Number(row.distance?.value ?? Number.MAX_SAFE_INTEGER),
        p18Files: image ? [image] : [],
        sourceRevisionId: 0,
        sourceRevisionTimestamp: "",
      });
      if (grouped.size >= LIMITS.candidateLimit) break;
    }
    const nearby = [...grouped.values()];
    const allowed = ATTRACTION_TYPE_ROOTS.map((item) => `wd:${item.qid}`).join(" ");
    const excluded = EXCLUDED_TYPE_ROOTS.map((qid) => `wd:${qid}`).join(" ");
    for (let offset = 0; offset < nearby.length; offset += 50) {
      const chunk = nearby.slice(offset, offset + 50);
      const classification = `
SELECT DISTINCT ?item ?rootType WHERE {
  VALUES ?item { ${chunk.map((item) => `wd:${item.qid}`).join(" ")} }
  VALUES ?rootType { ${allowed} }
  ?item wdt:P31/wdt:P279?/wdt:P279?/wdt:P279?/wdt:P279? ?rootType.
  FILTER NOT EXISTS {
    VALUES ?excludedRoot { ${excluded} }
    ?item wdt:P31/wdt:P279?/wdt:P279?/wdt:P279? ?excludedRoot.
  }
}`;
      const classifyUrl = new URL("https://query.wikidata.org/sparql");
      classifyUrl.searchParams.set("query", classification);
      classifyUrl.searchParams.set("format", "json");
      const classified = await this.http.json<SparqlResponse>(classifyUrl);
      for (const row of classified.results?.bindings ?? []) {
        const qid = entityId(row.item?.value);
        const rootType = entityId(row.rootType?.value);
        const candidate = qid ? grouped.get(qid) : undefined;
        if (!candidate || !rootType || candidate.types.includes(rootType)) continue;
        candidate.types.push(rootType);
        candidate.typeLabels.push(ATTRACTION_TYPE_ROOTS.find((item) => item.qid === rootType)?.label ?? "attraction");
      }
    }
    const candidates = nearby.filter((candidate) => candidate.types.length > 0).slice(0, LIMITS.candidateLimit);
    const entities = await this.getEntities(candidates.map((candidate) => candidate.qid), "labels|descriptions|info");
    return candidates.flatMap((candidate) => {
      const entity = entities.get(candidate.qid);
      const name = sanitizePlainText(entity?.labels?.en?.value);
      const sourceRevisionId = entity?.lastrevid ?? 0;
      const sourceRevisionTimestamp = entity?.modified ?? "";
      if (!name || sourceRevisionId <= 0 || !sourceRevisionTimestamp) return [];
      return [{
        ...candidate,
        name,
        ...(sanitizePlainText(entity?.descriptions?.en?.value)
          ? { wikidataDescription: sanitizePlainText(entity?.descriptions?.en?.value) }
          : {}),
        sourceRevisionId,
        sourceRevisionTimestamp,
      }];
    });
  }

  async findPhotoCandidates(candidates: AttractionCandidate[]): Promise<Map<string, CommonsPhotoCandidate[]>> {
    const result = new Map<string, CommonsPhotoCandidate[]>();
    for (const candidate of candidates) {
      result.set(candidate.qid, candidate.p18Files.map((fileTitle) => ({ fileTitle, depictsQids: [], origin: "p18" })));
    }
    for (let offset = 0; offset < candidates.length; offset += 25) {
      const chunk = candidates.slice(offset, offset + 25);
      const search = chunk.map((item) => `haswbstatement:P180=${item.qid}`).join(" OR ");
      if (!search) continue;
      const searchUrl = new URL("https://commons.wikimedia.org/w/api.php");
      searchUrl.searchParams.set("action", "query");
      searchUrl.searchParams.set("format", "json");
      searchUrl.searchParams.set("formatversion", "2");
      searchUrl.searchParams.set("generator", "search");
      searchUrl.searchParams.set("gsrsearch", search);
      searchUrl.searchParams.set("gsrnamespace", "6");
      searchUrl.searchParams.set("gsrlimit", "50");
      const pages = (await this.http.json<CommonsSearchResponse>(searchUrl)).query?.pages ?? [];
      if (pages.length === 0) continue;
      const entityUrl = new URL("https://commons.wikimedia.org/w/api.php");
      entityUrl.searchParams.set("action", "wbgetentities");
      entityUrl.searchParams.set("format", "json");
      entityUrl.searchParams.set("props", "claims");
      entityUrl.searchParams.set("ids", pages.map((page) => `M${page.pageid}`).join("|"));
      const entities = await this.http.json<CommonsEntitiesResponse>(entityUrl);
      for (const page of pages) {
        const claims = entities.entities?.[`M${page.pageid}`]?.statements?.P180 ?? [];
        const depictsQids = claims
          .filter((claim) => claim.rank !== "deprecated")
          .map((claim) => entityValue(claim.mainsnak?.datavalue?.value))
          .filter((value): value is string => Boolean(value && isQid(value)));
        for (const qid of depictsQids) {
          if (!result.has(qid)) continue;
          const entries = result.get(qid)!;
          const fileTitle = normalizeFileTitle(page.title);
          if (!entries.some((entry) => entry.fileTitle === fileTitle)) {
            entries.push({ fileTitle, depictsQids, origin: "depicts" });
          }
        }
      }
    }
    return result;
  }

  async getPhotoMetadata(fileTitles: string[]): Promise<Map<string, CommonsPhotoMetadata>> {
    const result = new Map<string, CommonsPhotoMetadata>();
    for (let offset = 0; offset < fileTitles.length; offset += 50) {
      const titles = fileTitles.slice(offset, offset + 50).map(normalizeFileTitle);
      const url = new URL("https://commons.wikimedia.org/w/api.php");
      url.searchParams.set("action", "query");
      url.searchParams.set("format", "json");
      url.searchParams.set("formatversion", "2");
      url.searchParams.set("prop", "imageinfo|categories|revisions");
      url.searchParams.set("titles", titles.join("|"));
      url.searchParams.set("iiprop", "url|size|mime|mediatype|sha1|timestamp|extmetadata");
      url.searchParams.set("iiurlwidth", String(LIMITS.maxOutputLongEdge));
      url.searchParams.set("cllimit", "max");
      url.searchParams.set("rvprop", "ids|timestamp");
      const data = await this.http.json<CommonsApiResponse>(url);
      for (const page of data.query?.pages ?? []) {
        const info = page.imageinfo?.[0];
        if (!info || typeof page.pageid !== "number" || page.pageid < 0) continue;
        const ext = info.extmetadata ?? {};
        const title = normalizeFileTitle(page.title ?? "");
        result.set(title, {
          fileTitle: title,
          pageId: page.pageid,
          sourceSha1: info.sha1 ?? "",
          originalUrl: info.url ?? "",
          thumbnailUrl: info.thumburl ?? info.url ?? "",
          mime: info.mime ?? "",
          mediaType: info.mediatype ?? "",
          width: info.width ?? 0,
          height: info.height ?? 0,
          revisionId: Number(page.revisions?.[0]?.revid ?? page.lastrevid ?? 0),
          revisionTimestamp: page.revisions?.[0]?.timestamp ?? info.timestamp ?? "",
          creator: sanitizePlainText(ext.Artist?.value),
          credit: sanitizePlainText(ext.Credit?.value),
          licenseShortName: sanitizePlainText(ext.LicenseShortName?.value),
          licenseUrl: sanitizePlainText(ext.LicenseUrl?.value),
          description: sanitizePlainText(ext.ImageDescription?.value) || undefined,
          categories: (page.categories ?? []).map((item) => sanitizePlainText(item.title)),
        });
      }
    }
    return result;
  }

  private async getEntity(qid: string): Promise<WikidataEntity> {
    const entity = (await this.getEntities([qid], "labels|descriptions|claims|info")).get(qid);
    if (!entity || entity.id !== qid) throw new PipelineError("wikidata-not-found", `Missing ${qid}`);
    return entity;
  }

  private async getEntities(qids: string[], props: string): Promise<Map<string, WikidataEntity>> {
    const result = new Map<string, WikidataEntity>();
    for (let offset = 0; offset < qids.length; offset += 50) {
      const url = new URL("https://www.wikidata.org/w/api.php");
      url.searchParams.set("action", "wbgetentities");
      url.searchParams.set("format", "json");
      url.searchParams.set("ids", qids.slice(offset, offset + 50).join("|"));
      url.searchParams.set("props", props);
      url.searchParams.set("languages", "en");
      const response = await this.http.json<EntityResponse>(url);
      for (const [qid, entity] of Object.entries(response.entities ?? {})) result.set(qid, entity);
    }
    return result;
  }

  private bestClaims(claims: WikidataClaim[] | undefined): WikidataClaim[] {
    const live = (claims ?? []).filter((claim) => claim.rank !== "deprecated" && claim.mainsnak?.snaktype === "value");
    const preferred = live.filter((claim) => claim.rank === "preferred");
    return preferred.length > 0 ? preferred : live.filter((claim) => claim.rank !== "deprecated");
  }

  private bestEntityIds(claims: WikidataClaim[] | undefined): string[] {
    const ids = this.bestClaims(claims)
      .map((claim) => entityValue(claim.mainsnak?.datavalue?.value))
      .filter((value): value is string => Boolean(value && isQid(value)));
    return [...new Set(ids)];
  }

  private bestCoordinates(claims: WikidataClaim[] | undefined): Array<{ coordinates: Coordinates; globeQid?: string }> {
    const values = this.bestClaims(claims)
      .map((claim) => coordinateValue(claim.mainsnak?.datavalue?.value))
      .filter((value): value is { coordinates: Coordinates; globeQid?: string } => value !== null);
    const unique = new Map(values.map((value) => [
      `${value.coordinates.latitude},${value.coordinates.longitude},${value.globeQid ?? ""}`,
      value,
    ]));
    return [...unique.values()];
  }

  private async isSubclassOfAny(types: string[], roots: ReadonlySet<string>, maxDepth: number): Promise<boolean> {
    let frontier = [...new Set(types)];
    const seen = new Set(frontier);
    for (let depth = 0; depth <= maxDepth && frontier.length > 0; depth += 1) {
      if (frontier.some((type) => roots.has(type))) return true;
      const next: string[] = [];
      for (const qid of frontier) {
        const entity = await this.getEntity(qid);
        for (const parent of this.bestEntityIds(entity.claims?.P279)) {
          if (!seen.has(parent)) { seen.add(parent); next.push(parent); }
        }
      }
      frontier = next;
    }
    return false;
  }
}

interface CommonsApiResponse {
  query?: { pages?: Array<{
    pageid?: number;
    lastrevid?: number;
    title?: string;
    categories?: Array<{ title: string }>;
    revisions?: Array<{ revid?: number; timestamp?: string }>;
    imageinfo?: Array<{
      url?: string;
      thumburl?: string;
      width?: number;
      height?: number;
      mime?: string;
      mediatype?: string;
      sha1?: string;
      timestamp?: string;
      extmetadata?: Record<string, { value?: string }>;
    }>;
  }> };
}

interface CommonsSearchResponse {
  query?: { pages?: Array<{ pageid: number; title: string }> };
}

interface CommonsEntitiesResponse {
  entities?: Record<string, { statements?: { P180?: WikidataClaim[] } }>;
}

function entityId(uri: string | undefined): string | null {
  if (!uri) return null;
  const match = uri.match(/\/(Q[1-9][0-9]*)$/);
  return match?.[1] ?? null;
}

function entityValue(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as { id?: unknown; "numeric-id"?: unknown };
  if (typeof candidate.id === "string") return candidate.id;
  if (typeof candidate["numeric-id"] === "number") return `Q${candidate["numeric-id"]}`;
  return null;
}

function coordinateValue(value: unknown): { coordinates: Coordinates; globeQid?: string } | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as { latitude?: unknown; longitude?: unknown; globe?: unknown };
  if (typeof candidate.latitude !== "number" || typeof candidate.longitude !== "number") return null;
  const globeQid = typeof candidate.globe === "string" ? entityId(candidate.globe) ?? undefined : undefined;
  return {
    coordinates: { latitude: candidate.latitude, longitude: candidate.longitude },
    globeQid,
  };
}

function parseWktPoint(value: string | undefined): Coordinates | null {
  const match = value?.match(/^Point\((-?[0-9.]+) (-?[0-9.]+)\)$/);
  if (!match) return null;
  return { longitude: Number(match[1]), latitude: Number(match[2]) };
}

function commonsTitleFromUri(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const path = decodeURIComponent(new URL(value).pathname);
    const name = path.split("/").pop()?.replace(/_/g, " ");
    return name ? normalizeFileTitle(name) : null;
  } catch {
    return null;
  }
}

function normalizeFileTitle(value: string): string {
  const normalized = value.replace(/_/g, " ").trim();
  return normalized.startsWith("File:") ? normalized : `File:${normalized}`;
}
