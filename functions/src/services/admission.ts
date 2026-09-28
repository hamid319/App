import { ADMISSION_LIMITS } from "../domain/config.js";
import { PipelineError } from "../domain/errors.js";
import type { CityIdentity, RequestContext, RequestOutcome } from "../domain/types.js";
import { normalizeQid } from "../domain/validation.js";

export interface AdmissionRepository {
  precheck(cityQid: string, now: Date): Promise<RequestOutcome | null>;
  consumeValidationAttempt(uid: string, now: Date): Promise<void>;
  admit(uid: string, cityQid: string, now: Date, city?: CityIdentity): Promise<RequestOutcome>;
}

export async function requestCollection(
  context: RequestContext,
  cityQidInput: unknown,
  repository: AdmissionRepository,
  now = new Date(),
  validateCity?: (qid: string) => Promise<CityIdentity>,
): Promise<RequestOutcome> {
  if (!context.uid) throw new PipelineError("unauthenticated", "Authentication is required");
  if (!context.appCheckValid) throw new PipelineError("failed-precondition", "App Check is required");
  const cityQid = normalizeQid(cityQidInput);
  const existing = await repository.precheck(cityQid, now);
  if (existing) return existing;
  await repository.consumeValidationAttempt(context.uid, now);
  const city = validateCity ? await validateCity(cityQid) : undefined;
  return repository.admit(context.uid, cityQid, now, city);
}

export function utcQuotaKeys(uid: string, now: Date): Array<{ id: string; limit: number }> {
  const day = now.toISOString().slice(0, 10);
  const month = day.slice(0, 7);
  const safeUid = Buffer.from(uid).toString("base64url");
  return [
    { id: `global_day_${day}`, limit: ADMISSION_LIMITS.globalDaily },
    { id: `global_month_${month}`, limit: ADMISSION_LIMITS.globalMonthly },
    { id: `user_${safeUid}_day_${day}`, limit: ADMISSION_LIMITS.userDaily },
    { id: `user_${safeUid}_month_${month}`, limit: ADMISSION_LIMITS.userMonthly },
  ];
}
