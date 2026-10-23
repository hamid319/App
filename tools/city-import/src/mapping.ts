import { CATEGORY_TYPES, INTEREST_TYPES, OSM_TAG_TYPES } from "./config.js";

/** App place types for a catalog category plus what the OSM tags add. */
export function typesFor(category: string, osmTags: Record<string, string> = {}): string[] {
  const types = [...(CATEGORY_TYPES[category] ?? ["tourist_attraction"])];
  for (const { key, value, type } of OSM_TAG_TYPES) {
    if (osmTags[key] === value && !types.includes(type)) types.push(type);
  }
  return types;
}

/** App interests covered by [types]. */
export function interestsFor(types: Iterable<string>): string[] {
  const set = new Set(types);
  return Object.entries(INTEREST_TYPES)
    .filter(([, interestTypes]) => interestTypes.some((t) => set.has(t)))
    .map(([interest]) => interest);
}
