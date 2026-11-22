import { describe, expect, it } from "vitest";
import { parseArgs } from "../src/args.js";

describe("parseArgs", () => {
  it("reads cities, dry run and port", () => {
    expect(parseArgs(["publish", "--city", "pt_lisbon,at_vienna", "--dry-run"])).toEqual({
      command: "publish", cityIds: ["pt_lisbon", "at_vienna"], dryRun: true, port: 4173,
    });
    expect(parseArgs(["review", "--port", "5000"]).port).toBe(5000);
    expect(parseArgs(["publish"]).cityIds).toEqual([]);
  });

  it("stops on typos instead of publishing every city for real", () => {
    expect(() => parseArgs(["publish", "--city=pt_lisbon"])).toThrow(/Unknown argument/);
    expect(() => parseArgs(["publish", "--dryrun"])).toThrow(/Unknown argument/);
    expect(() => parseArgs(["publish", "--city"])).toThrow(/--city needs/);
    expect(() => parseArgs(["publish", "--city", "--dry-run"])).toThrow(/--city needs/);
    expect(() => parseArgs(["publish", "--city", ","])).toThrow(/--city needs/);
    expect(() => parseArgs(["review", "--port", "abc"])).toThrow(/--port needs/);
  });
});
