/// <reference lib="deno.ns" />

import { createClient } from "npm:@supabase/supabase-js@2.57.4";

declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
};

import {
  consumeProjectQuota,
  consumeQuota,
  createAdminClient,
  requireActiveEntitlement,
  requireAuthenticatedUser,
} from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  fetchWithTimeout,
  HttpError,
  readBoundedResponseBody,
  readJSONBody,
  requestID,
  requiredEnv,
} from "../_shared/http.ts";
import {
  consistentVoiceSettings,
  deterministicSpeechSeed,
  effectiveAccentForRequest,
  parseTTSRequest,
  sourceSpeechSpeed,
  ttsModelIDForPurpose,
  voiceIDForAccent,
} from "./contract.ts";
import {
  ttsCacheBucket,
  ttsCacheKey,
  ttsObjectPath,
  ttsOutputFormat,
  ttsSettingsVersionForPurpose,
} from "./cache.ts";

const maximumAudioBytes = 3_000_000;
const minimumAudioBytes = 128;
const cacheLeaseWaitAttempts = 40;
const cacheLeaseWaitMilliseconds = 250;
const cacheGenerationLeaseMilliseconds = 10_000;
// Eleven v4 is higher quality but has higher latency than the previous Flash
// model. Give every clip enough time to finish before falling back to Apple.
const ttsProviderTimeoutMilliseconds = 20_000;

type CacheClaim = {
  should_generate: boolean;
  status: "generating" | "ready";
  object_path: string;
};

type CacheStatus = {
  status: "generating" | "ready" | "failed";
  object_path: string;
  generation_started_at: string | null;
};

Deno.serve(async (req: Request) => {
  const id = requestID(req);
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(
      new HttpError(405, "method_not_allowed", "Use POST."),
      id,
    );
  }

  try {
    const operationsPrewarm = await requireOperationsPrewarmAuthorization(req);
    const authenticatedContext = operationsPrewarm
      ? null
      : await requireAuthenticatedUser(req, { allowAnonymous: true });
    const admin = authenticatedContext?.admin ?? createAdminClient();
    const userID = authenticatedContext?.userID ?? null;
    const input = parseTTSRequest(await readJSONBody(req, 4_096));
    // The pre-paywall first conversation may only request fixed onboarding
    // templates, and only while the learner has not finished onboarding.
    const isPrePaywallOnboarding = input.onboardingLine !== undefined &&
      userID !== null &&
      await hasIncompleteOnboarding(admin, userID);
    if (userID && !isPrePaywallOnboarding) await requireActiveEntitlement(admin, userID);
    const storedAccent = userID ? await fetchStoredAccent(admin, userID) : null;
    const effectiveInput = {
      ...input,
      accent: effectiveAccentForRequest(
        input.accent,
        storedAccent,
        input.honorRequestedAccent,
      ),
      speed: sourceSpeechSpeed(input.speed),
    };
    if (input.speed !== effectiveInput.speed) {
      console.info("tts_slow_playback_normalized", {
        request_id: id,
        requested_speed: input.speed,
        source_speed: effectiveInput.speed,
      });
    }
    if (
      storedAccent &&
      storedAccent !== input.accent &&
      !input.honorRequestedAccent
    ) {
      console.warn("tts_request_accent_corrected", {
        request_id: id,
        requested_accent: input.accent,
        stored_accent: storedAccent,
      });
    }
    const voiceID = voiceIDForAccent(effectiveInput.accent);
    const modelID = ttsModelIDForPurpose(effectiveInput.purpose);
    const cacheKey = await ttsCacheKey(effectiveInput, voiceID, modelID);
    const objectPath = ttsObjectPath(cacheKey, effectiveInput.purpose);
    let generationToken = crypto.randomUUID();
    let claim = await claimTTSCache(
      admin,
      effectiveInput,
      voiceID,
      modelID,
      cacheKey,
      objectPath,
      generationToken,
    );

    if (!claim.should_generate) {
      const cached = await waitForCachedAudio(
        admin,
        cacheKey,
      );
      if (cached) {
        console.info("tts_cache_hit", {
          request_id: id,
          accent: effectiveInput.accent,
          requested_speed: input.speed,
          source_speed: effectiveInput.speed,
        });
        return audioResponse(cached, id, "hit");
      }

      // The previous generator failed or left a ready row without its object.
      // Reclaim the row with a new token instead of issuing a duplicate request
      // while a healthy generator is still within its lease.
      generationToken = crypto.randomUUID();
      claim = await claimTTSCache(
        admin,
        effectiveInput,
        voiceID,
        modelID,
        cacheKey,
        objectPath,
        generationToken,
      );
      if (!claim.should_generate) {
        throw new HttpError(
          503,
          "voice_busy",
          "Voice audio is being prepared. Please try again shortly.",
        );
      }
    }

    let audio: Uint8Array;
    try {
      // Only a true cache miss consumes provider quotas. Cache hits are served
      // from Storage and never call ElevenLabs.
      if (userID) {
        await consumeQuota(admin, userID, "elevenlabs_tts", 60, 60);
        await consumeQuota(
          admin,
          userID,
          "elevenlabs_tts_daily",
          isPrePaywallOnboarding
            ? 12
            : boundedIntegerEnv("KUMUSTA_TTS_USER_DAILY_REQUEST_LIMIT", 500, 1, 10_000),
          86_400,
        );
      }
      await consumeProjectQuota(
        admin,
        "elevenlabs_tts_project_daily",
        boundedIntegerEnv(
          "KUMUSTA_TTS_PROJECT_DAILY_REQUEST_LIMIT",
          10_000,
          1,
          1_000_000,
        ),
        86_400,
      );

      const apiKey = requiredEnv("ELEVENLABS_API_KEY");
      audio = await generateTTSAudio(effectiveInput, voiceID, modelID, apiKey, id);
    } catch (error) {
      await failTTSCache(admin, cacheKey, generationToken);
      throw error;
    }

    if (effectiveInput.purpose === "vocabulary") {
      // Vocabulary is pre-generated before a flashcard session begins. Do
      // not report prewarming as complete until the reusable Storage object
      // and its ready metadata row both exist.
      try {
        await storeTTSCache(
          admin,
          cacheKey,
          objectPath,
          generationToken,
          audio,
        );
      } catch (error) {
        await failTTSCache(admin, cacheKey, generationToken);
        throw error;
      }
    } else {
      // Lesson playback can return its valid audio immediately; the shared
      // cache is finalized in a supervised background task.
      scheduleTTSCacheStore(
        admin,
        cacheKey,
        objectPath,
        generationToken,
        audio,
        id,
      );
    }
    console.info("tts_cache_miss_generated", {
      request_id: id,
      onboarding_line: effectiveInput.onboardingLine ?? null,
      accent: effectiveInput.accent,
      speed: effectiveInput.speed,
    });
    return audioResponse(audio, id, "generated");
  } catch (error) {
    return errorResponse(error, id);
  }
});

async function requireOperationsPrewarmAuthorization(req: Request): Promise<boolean> {
  if (req.headers.get("x-kumusta-operations-prewarm") !== "true") return false;
  const authorization = req.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    throw new HttpError(401, "unauthorized", "Operations authorization is required.");
  }
  const suppliedKey = authorization.slice(7);
  const verifier = createClient(requiredEnv("SUPABASE_URL"), suppliedKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const verified = await verifier.rpc("kumusta_curriculum_admin_authorized");
  if (verified.error || verified.data !== true) {
    throw new HttpError(401, "unauthorized", "Operations authorization is required.");
  }
  return true;
}

async function hasIncompleteOnboarding(
  admin: Parameters<typeof requireActiveEntitlement>[0],
  userID: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from("kumusta_profiles")
    .select("onboarding_completed_at")
    .eq("id", userID)
    .maybeSingle();
  if (error) {
    console.error("onboarding_status_check_failed", { code: error.code });
    throw new HttpError(503, "onboarding_unavailable", "Please try again shortly.");
  }
  return data?.onboarding_completed_at == null;
}

async function fetchStoredAccent(
  admin: Parameters<typeof requireActiveEntitlement>[0],
  userID: string,
): Promise<"southern" | "northern" | null> {
  const { data, error } = await admin
    .from("kumusta_learning_preferences")
    .select("accent")
    .eq("user_id", userID)
    .maybeSingle();
  if (error) throw error;
  return data?.accent === "northern" || data?.accent === "southern" ? data.accent : null;
}

async function generateTTSAudio(
  input: ReturnType<typeof parseTTSRequest>,
  voiceID: string,
  modelID: string,
  apiKey: string,
  requestID: string,
): Promise<Uint8Array> {
  // Eleven occasionally renders a lone syllable (e.g. "chút") as an empty
  // clip. The seed is deterministic, so retrying the same request repeats the
  // failure forever. Vary the seed, then end the text with a period, which
  // gives the model a complete utterance to render.
  const seed = deterministicSpeechSeed(voiceID, input);
  const attempts = [
    { text: input.text, seed },
    { text: input.text, seed: (seed + 1) >>> 0 },
  ];
  if (!/[.!?…]$/.test(input.text)) {
    attempts.push({ text: `${input.text}.`, seed });
  }
  for (const [index, attempt] of attempts.entries()) {
    const audio = await requestTTSAudio(
      input,
      attempt.text,
      attempt.seed,
      voiceID,
      modelID,
      apiKey,
      requestID,
    );
    if (audio.byteLength >= minimumAudioBytes) return audio;
    console.warn("elevenlabs_audio_too_short", {
      request_id: requestID,
      attempt: index + 1,
      byte_size: audio.byteLength,
    });
  }
  throw new HttpError(
    502,
    "voice_unavailable",
    "Voice audio is temporarily unavailable.",
  );
}

async function requestTTSAudio(
  input: ReturnType<typeof parseTTSRequest>,
  text: string,
  seed: number,
  voiceID: string,
  modelID: string,
  apiKey: string,
  requestID: string,
): Promise<Uint8Array> {
  const endpoint = new URL(
    `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceID)}`,
  );
  endpoint.searchParams.set("output_format", ttsOutputFormat);

  let providerResponse: Response;
  try {
    providerResponse = await fetchWithTimeout(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "audio/mpeg",
        "xi-api-key": apiKey,
      },
      body: JSON.stringify({
        text,
        model_id: modelID,
        language_code: "vi",
        seed,
        apply_text_normalization: "auto",
        voice_settings: consistentVoiceSettings(input.speed),
      }),
    }, ttsProviderTimeoutMilliseconds);
  } catch {
    console.error("elevenlabs_unreachable", { request_id: requestID });
    throw new HttpError(
      502,
      "voice_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }

  if (
    !providerResponse.ok ||
    !providerResponse.headers.get("content-type")?.toLowerCase().startsWith("audio/")
  ) {
    let providerCode = "unknown";
    try {
      const payload = await providerResponse.clone().json();
      const detail = payload && typeof payload === "object"
        ? (payload as Record<string, unknown>).detail
        : null;
      if (detail && typeof detail === "object") {
        const status = (detail as Record<string, unknown>).status;
        if (typeof status === "string" && status.length <= 80) providerCode = status;
      } else if (payload && typeof payload === "object") {
        const code = (payload as Record<string, unknown>).code;
        if (typeof code === "string" && code.length <= 80) providerCode = code;
      }
    } catch {
      // Provider bodies are best-effort diagnostics; never alter the public error contract.
    }
    console.error("elevenlabs_rejected", {
      request_id: requestID,
      status: providerResponse.status,
      provider_code: providerCode,
    });
    throw new HttpError(
      502,
      "voice_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }

  let audio: Uint8Array;
  try {
    audio = await readBoundedResponseBody(providerResponse, maximumAudioBytes);
  } catch {
    console.error("elevenlabs_response_too_large", { request_id: requestID });
    throw new HttpError(
      502,
      "voice_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }
  return audio;
}

async function claimTTSCache(
  admin: Parameters<typeof consumeQuota>[0],
  input: ReturnType<typeof parseTTSRequest>,
  voiceID: string,
  modelID: string,
  cacheKey: string,
  objectPath: string,
  generationToken: string,
): Promise<CacheClaim> {
  const { data, error } = await admin.rpc("kumusta_claim_tts_cache", {
    p_cache_key: cacheKey,
    p_text_value: input.text,
    p_accent: input.accent,
    p_speed: input.speed,
    p_voice_id: voiceID,
    p_model_id: modelID,
    p_output_format: ttsOutputFormat,
    p_settings_version: ttsSettingsVersionForPurpose(input.purpose),
    p_object_path: objectPath,
    p_generation_token: generationToken,
  });
  if (error || !Array.isArray(data) || data.length !== 1) {
    console.error("tts_cache_claim_failed", { code: error?.code });
    throw new HttpError(
      503,
      "voice_cache_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }
  const row = data[0] as Partial<CacheClaim>;
  if (
    typeof row.should_generate !== "boolean" ||
    (row.status !== "generating" && row.status !== "ready") ||
    typeof row.object_path !== "string"
  ) {
    throw new HttpError(
      503,
      "voice_cache_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }
  return row as CacheClaim;
}

async function waitForCachedAudio(
  admin: Parameters<typeof consumeQuota>[0],
  cacheKey: string,
): Promise<Uint8Array | null> {
  for (let attempt = 0; attempt < cacheLeaseWaitAttempts; attempt += 1) {
    const { data, error } = await admin
      .from("kumusta_tts_cache")
      .select("status,object_path,generation_started_at")
      .eq("cache_key", cacheKey)
      .maybeSingle();
    if (error) {
      console.error("tts_cache_status_failed", { code: error.code });
      throw new HttpError(
        503,
        "voice_cache_unavailable",
        "Voice audio is temporarily unavailable.",
      );
    }
    if (!data || (data as CacheStatus).status === "failed") return null;
    if ((data as CacheStatus).status === "ready") {
      const cached = await downloadCachedAudio(admin, (data as CacheStatus).object_path);
      if (cached) return cached;

      // A ready row with a missing object is inconsistent. Let the caller
      // reclaim it rather than waiting for a status that cannot change.
      await invalidateTTSCache(admin, cacheKey);
      return null;
    }
    const generationStartedAt = Date.parse(
      (data as CacheStatus).generation_started_at ?? "",
    );
    if (
      !Number.isFinite(generationStartedAt) ||
      Date.now() - generationStartedAt >= cacheGenerationLeaseMilliseconds
    ) {
      return null;
    }
    await delay(cacheLeaseWaitMilliseconds);
  }
  return null;
}

function scheduleTTSCacheStore(
  admin: Parameters<typeof consumeQuota>[0],
  cacheKey: string,
  objectPath: string,
  generationToken: string,
  audio: Uint8Array,
  id: string,
): void {
  EdgeRuntime.waitUntil((async () => {
    try {
      await storeTTSCache(admin, cacheKey, objectPath, generationToken, audio);
      console.info("tts_cache_stored", {
        request_id: id,
        byte_size: audio.byteLength,
      });
    } catch (error) {
      console.error("tts_cache_store_best_effort_failed", {
        request_id: id,
        error: error instanceof Error ? error.message : "unknown",
      });
      await failTTSCache(admin, cacheKey, generationToken);
    }
  })());
}

async function downloadCachedAudio(
  admin: Parameters<typeof consumeQuota>[0],
  objectPath: string,
): Promise<Uint8Array | null> {
  const { data, error } = await admin.storage
    .from(ttsCacheBucket)
    .download(objectPath);
  if (error || !data) return null;
  const audio = new Uint8Array(await data.arrayBuffer());
  if (audio.byteLength < 128 || audio.byteLength > maximumAudioBytes) return null;
  return audio;
}

async function storeTTSCache(
  admin: Parameters<typeof consumeQuota>[0],
  cacheKey: string,
  objectPath: string,
  generationToken: string,
  audio: Uint8Array,
): Promise<void> {
  const uploadBuffer = audio.buffer.slice(
    audio.byteOffset,
    audio.byteOffset + audio.byteLength,
  ) as ArrayBuffer;
  const { error: uploadError } = await admin.storage
    .from(ttsCacheBucket)
    .upload(objectPath, new Blob([uploadBuffer], { type: "audio/mpeg" }), {
      cacheControl: "31536000",
      contentType: "audio/mpeg",
      upsert: true,
    });
  if (uploadError) {
    console.error("tts_cache_upload_failed", { code: uploadError.message });
    throw new HttpError(
      503,
      "voice_cache_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }

  const { data, error: completionError } = await admin.rpc(
    "kumusta_complete_tts_cache",
    {
      p_cache_key: cacheKey,
      p_generation_token: generationToken,
      p_byte_size: audio.byteLength,
    },
  );
  if (completionError || data !== true) {
    console.error("tts_cache_complete_failed", { code: completionError?.code });
    throw new HttpError(
      503,
      "voice_cache_unavailable",
      "Voice audio is temporarily unavailable.",
    );
  }
}

async function failTTSCache(
  admin: Parameters<typeof consumeQuota>[0],
  cacheKey: string,
  generationToken: string,
): Promise<void> {
  const { error } = await admin.rpc("kumusta_fail_tts_cache", {
    p_cache_key: cacheKey,
    p_generation_token: generationToken,
  });
  if (error) console.error("tts_cache_failure_update_failed", { code: error.code });
}

async function invalidateTTSCache(
  admin: Parameters<typeof consumeQuota>[0],
  cacheKey: string,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_tts_cache")
    .update({ status: "failed", generation_token: null, generation_started_at: null })
    .eq("cache_key", cacheKey)
    .eq("status", "ready");
  if (error) console.error("tts_cache_invalidation_failed", { code: error.code });
}

function audioResponse(
  audio: Uint8Array,
  id: string,
  cacheStatus: "hit" | "generated",
): Response {
  const responseBody = new Uint8Array(audio.byteLength);
  responseBody.set(audio);
  return new Response(responseBody.buffer, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "audio/mpeg",
      "Content-Length": String(audio.byteLength),
      "Cache-Control": "private, no-store",
      "x-request-id": id,
      "x-kumusta-tts-cache": cacheStatus,
    },
  });
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
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
