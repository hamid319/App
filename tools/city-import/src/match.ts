// Matches the catalog's attraction names to OpenStreetMap places.

import type { Coordinates } from "./model.js";
import type { OsmPlace } from "./osm.js";

/** Words that only name the kind of place, in the catalog's and OSM's languages. */
const GENERIC_WORDS = new Set([
  "basilica", "basilique", "basilika", "cathedral", "cathedrale", "catedral", "cattedrale", "dom", "kathedrale",
  "church", "chiesa", "eglise", "iglesia", "igreja", "kirche", "kerk", "kirke", "chapel", "capela", "kapelle",
  "museum", "museu", "museo", "musee", "muzeum", "national", "nacional", "nazionale",
  "palace", "palacio", "palazzo", "palais", "palast", "schloss", "castle", "castelo", "castello", "chateau", "burg",
  "park", "parque", "parco", "parc", "garden", "gardens", "jardim", "jardin", "giardino", "garten",
  "tower", "torre", "tour", "turm", "monastery", "mosteiro", "monasterio", "kloster", "abbey", "convent", "convento",
  "square", "praca", "plaza", "piazza", "place", "platz", "bridge", "ponte", "puente", "pont", "brucke",
  "temple", "templo", "tempio", "mosque", "cami", "synagogue", "memorial", "monument", "monumento", "denkmal",
  "gallery", "galeria", "galleria", "galerie", "viewpoint", "miradouro", "mirador", "belvedere", "aussichtspunkt",
  "old", "new", "historic", "royal", "real", "st", "saint", "san", "santa", "sao",
]);

const STOP_WORDS = new Set(["the", "of", "and", "de", "da", "do", "dos", "das", "di", "del", "della", "la", "le", "les", "el", "der", "die", "das"]);

/** Lower case, no accents or punctuation, single spaces. */
export function normalizeName(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/ß/g, "ss")
    .replace(/&/g, " and ")
    .replace(/['’`]/g, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

/** "Grüngürtel (Cologne Green Belt)" -> ["Grüngürtel (Cologne Green Belt)", "Grüngürtel", "Cologne Green Belt"]. */
export function catalogNameVariants(name: string): string[] {
  const variants = new Set<string>([name]);
  const inParens = [...name.matchAll(/\(([^)]+)\)/g)].map((m) => m[1]);
  const outside = name.replace(/\([^)]*\)/g, " ").trim();
  for (const part of [outside, ...inParens]) {
    for (const piece of part.split(/\s+\/\s+|\s+–\s+|\s+-\s+|;/)) {
      if (piece.trim()) variants.add(piece.trim());
    }
  }
  return [...variants].map(normalizeName).filter(Boolean);
}

function osmNameVariants(tags: Record<string, string>): string[] {
  const keys = ["name", "name:en", "name:de", "int_name", "official_name", "alt_name", "old_name", "short_name", "name:en:alt"];
  const names = keys.flatMap((key) => (tags[key] ?? "").split(";")).map((n) => n.trim()).filter(Boolean);
  return [...new Set(names.map(normalizeName).filter(Boolean))];
}

function tokens(value: string): Set<string> {
  return new Set(value.split(" ").filter((t) => t && !STOP_WORDS.has(t)));
}

/** 1 = same name, ~0.85+ = clearly the same place, below = different. */
export function nameScore(a: string, b: string): number {
  if (a === b) return 1;
  const ta = tokens(a);
  const tb = tokens(b);
  if (ta.size === 0 || tb.size === 0) return 0;
  let common = 0;
  for (const t of ta) if (tb.has(t)) common += 1;
  const jaccard = common / (ta.size + tb.size - common);
  // "Sagrada Familia" vs "Basilica de la Sagrada Familia": all of the
  // shorter name is in the longer one, and the rest only says what kind of
  // place it is. "Parque das Nacoes" vs "Teleferico do Parque das Nacoes"
  // is a different place (a cable car in that park).
  const [shorter, longer] = ta.size <= tb.size ? [ta, tb] : [tb, ta];
  const containment = common / shorter.size;
  if (containment === 1 && shorter.size >= 2) {
    const extra = [...longer].filter((t) => !shorter.has(t));
    if (extra.every((t) => GENERIC_WORDS.has(t))) return Math.max(0.88, jaccard);
  }
  return jaccard;
}

export interface OsmMatch {
  place: OsmPlace;
  score: number;
}

const MIN_SCORE = 0.85;

/** Best OSM place for a catalog name, or null. Prefers places with a Wikidata link, then the more prominent kind, then closeness. */
export function matchAttraction(catalogName: string, places: OsmPlace[], center: Coordinates): OsmMatch | null {
  const wanted = catalogNameVariants(catalogName);
  let best: { place: OsmPlace; score: number; rank: number } | null = null;
  for (const place of places) {
    const names = osmNameVariants(place.tags);
    let score = 0;
    for (const w of wanted) for (const n of names) score = Math.max(score, nameScore(w, n));
    if (score < MIN_SCORE) continue;
    const rank = score * 10 + prominence(place) - distanceKm(center, place.coordinates) / 100;
    if (!best || rank > best.rank) best = { place, score, rank };
  }
  return best ? { place: best.place, score: best.score } : null;
}

function prominence(place: OsmPlace): number {
  let value = 0;
  if (place.tags.wikidata) value += 2;
  if (place.tags.wikipedia) value += 0.5;
  if (place.tags.tourism) value += 1;
  if (place.type !== "node") value += 0.5;
  return value;
}

export function distanceKm(a: Coordinates, b: Coordinates): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLng = (b.lng - a.lng) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
}
