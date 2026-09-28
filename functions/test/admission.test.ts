import { describe, expect, it } from "vitest";
import { requestCollection, type AdmissionRepository } from "../src/services/admission.js";
import type { CityIdentity, RequestOutcome } from "../src/domain/types.js";

class FakeAdmission implements AdmissionRepository {
  validations = 0;
  admissions = 0;
  existing: RequestOutcome | null = null;
  async precheck(): Promise<RequestOutcome | null> { return this.existing; }
  async consumeValidationAttempt(): Promise<void> { this.validations += 1; }
  async admit(_uid: string, cityQid: string, _now: Date, _city?: CityIdentity): Promise<RequestOutcome> {
    this.admissions += 1;
    return { kind: "admitted", cityQid, jobId: "job1", status: "queued" };
  }
}

describe("request admission", () => {
  it("requires auth before any repository work", async () => {
    const repository = new FakeAdmission();
    await expect(requestCollection({ appCheckValid: true }, "Q1055", repository)).rejects.toMatchObject({ code: "unauthenticated" });
    expect(repository.validations).toBe(0);
  });

  it("requires App Check", async () => {
    const repository = new FakeAdmission();
    await expect(requestCollection({ uid: "u", appCheckValid: false }, "Q1055", repository)).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("validates the entity after cheap throttling and before build admission", async () => {
    const repository = new FakeAdmission();
    const city: CityIdentity = { qid: "Q1055", name: "Hamburg", countryQid: "Q183", countryName: "Germany", coordinates: { latitude: 53.55, longitude: 10 } };
    await requestCollection({ uid: "u", appCheckValid: true }, "Q1055", repository, new Date(), async () => city);
    expect(repository.validations).toBe(1);
    expect(repository.admissions).toBe(1);
  });

  it("returns fresh content before spending validation traffic", async () => {
    const repository = new FakeAdmission();
    repository.existing = { kind: "fresh", cityQid: "Q1055", versionId: "v1", status: "ready" };
    const result = await requestCollection({ uid: "u", appCheckValid: true }, "Q1055", repository);
    expect(result.kind).toBe("fresh");
    expect(repository.validations).toBe(0);
  });
});
