import { DISCOVERY_CLASSES, INTEREST_TYPES } from "./config.js";

/** App place types for the Wikidata classes a place matched, in config order. */
export function appTypesFor(classQids: Iterable<string>): string[] {
  const matched = new Set(classQids);
  const types: string[] = [];
  for (const entry of DISCOVERY_CLASSES) {
    if (matched.has(entry.qid) && !types.includes(entry.appType)) types.push(entry.appType);
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
