import fixtures from "./fixtures/city-entities.json" with { type: "json" };
import { describe, expect, it } from "vitest";
import { WikimediaSource } from "../src/adapters/wikimedia.js";
import type { WikimediaHttpClient } from "../src/adapters/safe-http.js";

describe("Wikidata city normalization fixtures", () => {
  it("uses preferred current country instead of historical normal claims", async () => {
    const city = await new WikimediaSource(fakeHttp()).resolveCity("Q1055");
    expect(city).toMatchObject({ qid: "Q1055", name: "Hamburg", countryQid: "Q183", countryName: "Germany" });
  });

  it("accepts a city-state whose preferred country is itself", async () => {
    const city = await new WikimediaSource(fakeHttp()).resolveCity("Q334");
    expect(city).toMatchObject({ qid: "Q334", name: "Singapore", countryQid: "Q334", countryName: "Singapore" });
  });

  it("accepts a city whose preferred type is not a settlement but a normal-rank type is", async () => {
    // Los Angeles: preferred P31 "charter city", normal-rank "city" and "metropolis".
    const city = await new WikimediaSource(fakeHttp()).resolveCity("Q65");
    expect(city).toMatchObject({ qid: "Q65", name: "Los Angeles", countryQid: "Q30", countryName: "United States" });
  });
});

function fakeHttp(): WikimediaHttpClient {
  return {
    json: async (url: URL) => {
      const ids = url.searchParams.get("ids")?.split("|") ?? [];
      return { entities: Object.fromEntries(ids.map((id) => [id, (fixtures as Record<string, unknown>)[id]])) };
    },
  } as unknown as WikimediaHttpClient;
}
