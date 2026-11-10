// Search index: every active place of a city as a tiny entry, split over a
// few Firestore documents (placeSearch/{cityId}_{part}). The app reads
// these 1-3 documents once per city and searches on the device, instead
// of one read per place. Must match lib/common/models/place_search_entry.dart.

import type { PlaceDoc } from "./model.js";

export const SEARCH = Object.freeze({
  /** Firestore's limit is 1 MiB per document; stay well below. */
  maxBytes: 700_000,
});

/** One place: id, English (or default) name, German name if different, kind and main type. */
export interface SearchEntry {
  i: string;
  n: string;
  d?: string;
  k: "s" | "v";
  t?: string;
}

/** placeSearch/{cityId}_{part}; every part knows how many there are. */
export interface SearchDoc {
  id: string;
  cityId: string;
  part: number;
  parts: number;
  entries: SearchEntry[];
  importRunId: string;
  updatedAt: string;
}

type Indexed = Pick<PlaceDoc, "id" | "name" | "names" | "kind" | "types" | "popularity" | "status">;

function entry(doc: Indexed): SearchEntry {
  const de = doc.names?.de;
  return {
    i: doc.id,
    n: doc.name,
    ...(de && de !== doc.name ? { d: de } : {}),
    k: doc.kind === "venue" ? "v" : "s",
    ...(doc.types?.[0] ? { t: doc.types[0] } : {}),
  };
}

/** Index parts for a city's active places, best-known first. */
export function buildSearchDocs(cityId: string, docs: Indexed[], importRunId: string, updatedAt: string): SearchDoc[] {
  const entries = docs
    .filter((d) => d.status === "active")
    .sort((a, b) => b.popularity - a.popularity || a.id.localeCompare(b.id))
    .map(entry);
  const chunks: SearchEntry[][] = [[]];
  let bytes = 0;
  for (const e of entries) {
    const size = Buffer.byteLength(JSON.stringify(e)) + 1;
    if (bytes + size > SEARCH.maxBytes && chunks[chunks.length - 1].length) {
      chunks.push([]);
      bytes = 0;
    }
    chunks[chunks.length - 1].push(e);
    bytes += size;
  }
  return chunks.map((list, part) => ({
    id: `${cityId}_${part}`,
    cityId,
    part,
    parts: chunks.length,
    entries: list,
    importRunId,
    updatedAt,
  }));
}
