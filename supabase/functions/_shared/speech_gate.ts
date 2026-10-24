/// <reference lib="deno.ns" />

import {
  type AuthenticatedContext,
  consumeProjectQuota,
  consumeQuota,
  requireActiveEntitlement,
} from "./auth.ts";
import { HttpError } from "./http.ts";

/// Admits one speaking attempt, whether it is uploaded whole or streamed with a
/// single-use realtime token. Both paths spend the same quotas so a client
/// cannot widen its allowance by switching transport.
export async function admitSpeechAttempt(
  req: Request,
  context: AuthenticatedContext,
): Promise<void> {
  let isPrePaywallLesson = false;
  if (req.headers.get("x-kumusta-onboarding") === "first-lesson") {
    const { data: profile, error } = await context.admin
      .from("kumusta_profiles")
      .select("onboarding_completed_at")
      .eq("id", context.userID)
      .maybeSingle();
    if (error) {
      console.error("onboarding_status_check_failed", { code: error.code });
      throw new HttpError(503, "onboarding_unavailable", "Please try again shortly.");
    }
    isPrePaywallLesson = profile?.onboarding_completed_at == null;
  }
  if (!isPrePaywallLesson) {
    await requireActiveEntitlement(context.admin, context.userID);
  }
  await consumeQuota(context.admin, context.userID, "elevenlabs_stt", 20, 60);
  await consumeQuota(
    context.admin,
    context.userID,
    "elevenlabs_stt_daily",
    isPrePaywallLesson
      ? 3
      : boundedIntegerEnv("KUMUSTA_STT_USER_DAILY_REQUEST_LIMIT", 300, 1, 10_000),
    86_400,
  );
  await consumeProjectQuota(
    context.admin,
    "elevenlabs_stt_project_daily",
    boundedIntegerEnv("KUMUSTA_STT_PROJECT_DAILY_REQUEST_LIMIT", 8_000, 1, 1_000_000),
    86_400,
  );
}

function boundedIntegerEnv(
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const raw = Deno.env.get(name)?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new HttpError(503, "service_unavailable", "The service is not configured.");
  }
  return value;
}
