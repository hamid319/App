import { describe, expect, it } from "vitest";
import type { PlaceDoc } from "../src/model.js";
import { SEARCH, buildSearchDocs } from "../src/search.js";

const doc = (id: string, popularity: number, extra: Partial<PlaceDoc> = {}) =>
  ({ id, popularity, name: `Name ${id}`, names: { en: `Name ${id}` }, kind: "sight", types: ["museum"], status: "active", ...extra }) as PlaceDoc;

describe("search index", () => {
  it("keeps active places, best first, with a German name only when it differs", () => {
    const docs = [
      doc("a", 1),
      doc("b", 9, { names: { en: "Name b", de: "Name B DE" }, kind: "venue", types: ["cafe"] }),
      doc("gone", 99, { status: "hidden" }),
    ];
    const [part] = buildSearchDocs("de_hamburg", docs, "run", "now");
    expect(part.id).toBe("de_hamburg_0");
    expect(part.parts).toBe(1);
    expect(part.entries).toEqual([
      { i: "b", n: "Name b", d: "Name B DE", k: "v", t: "cafe" },
      { i: "a", n: "Name a", k: "s", t: "museum" },
    ]);
  });

  it("splits into parts below the document size limit", () => {
    const long = "x".repeat(1000);
    const docs = Array.from({ length: 1500 }, (_, i) => doc(`p${i}`, i, { name: long }));
    const parts = buildSearchDocs("c", docs, "run", "now");
    expect(parts.length).toBeGreaterThan(1);
    expect(parts.every((p) => p.parts === parts.length)).toBe(true);
    expect(parts.every((p) => Buffer.byteLength(JSON.stringify(p.entries)) <= SEARCH.maxBytes + 2)).toBe(true);
    expect(parts.flatMap((p) => p.entries)).toHaveLength(1500);
  });
});
