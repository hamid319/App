import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { assertFails, initializeTestEnvironment, type RulesTestEnvironment } from "@firebase/rules-unit-testing";

const projectId = "demo-swipetrip-city-pipeline";
let environment: RulesTestEnvironment;

describe("city pipeline Firestore rules", () => {
  beforeAll(async () => {
    if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("FIRESTORE_EMULATOR_HOST is required; never run rules tests against a live project");
    environment = await initializeTestEnvironment({ projectId, firestore: { rules: await readFile(resolve(process.cwd(), "../firestore.rules"), "utf8") } });
  });
  afterAll(async () => environment?.cleanup());

  it("denies authenticated clients access to private pipeline documents", async () => {
    const db = environment.authenticatedContext("user-1").firestore();
    await assertFails(db.collection("cityPreparationJobs").doc("job").get());
    await assertFails(db.collection("cityPreparationJobs").doc("job").set({ cityQid: "Q1055" }));
    await assertFails(db.collection("cityPreparationOutbox").doc("job").get());
  });

  it("denies direct reads and writes of server-served publications", async () => {
    const db = environment.authenticatedContext("user-1").firestore();
    await assertFails(db.collection("cityCollections").doc("Q1055").get());
    await assertFails(db.collection("cityCollections").doc("Q1055").set({ publishedVersion: "v1" }));
  });
});

