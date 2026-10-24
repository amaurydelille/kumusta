/// <reference lib="deno.ns" />
import Anthropic from "npm:@anthropic-ai/sdk@0.135.0";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import { createAdminClient, requireActiveEntitlement } from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  fetchWithTimeout,
  HttpError,
  jsonResponse,
  requestID,
  requiredEnv,
} from "../_shared/http.ts";
import { voiceIDForAccent } from "../kumusta-elevenlabs-tts/contract.ts";
import * as sessions from "./sessions.ts";
import { agentPrompt, contextFrom, firstMessage, sessionIDFrom } from "./coaching.ts";
import {
  base64,
  type ChatMessage,
  encodeEvent,
  engineLabel,
  GRUMPY_VOCABULARY_PROMPT,
  hasSpeakableText,
  historyFrom,
  PIPELINE_LLM_MODEL,
  PIPELINE_SAMPLE_RATE,
  PIPELINE_TTS_MODEL,
  PIPELINE_VOICE_PROMPT,
  PLAYBACK_SAMPLE_RATE,
  type ReplyEvent,
  SampleAligner,
  SONIOX_ENDPOINT,
  sonioxConfig,
  speechLanguage,
  takeSentences,
  type TranscriberProvider,
  transcriberProvider,
  transcriberURL,
} from "./contract.ts";

const REQUEST_BODY_LIMIT = 64_000;
const PROVIDER_TIMEOUT_MS = 8_000;
const REPLY_MAX_TOKENS = 400;
/** Grace after the reservation ends, so the last reply can still be spoken. */
const SESSION_GRACE_MS = 20_000;

type Admin = SupabaseClient;

// STT -> LLM -> TTS live practice. This function owns the pipeline's sessions
// (allowance / start / finish, without a daily limit) and serves an open
// session of the caller: a single-use Scribe realtime session for
// the microphone, and each spoken reply streamed back as NDJSON text and
// 24 kHz PCM16 audio events. Provider keys never leave the server.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  const id = requestID(req);
  try {
    if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");
    const [{ admin, userID }, body] = await Promise.all([authenticate(req), readBody(req)]);
    switch (body.action) {
      // The pipeline owns its sessions: no daily allowance, unlike the
      // agent's `kumusta-live`, which older app versions keep using.
      case "allowance":
        await requireActiveEntitlement(admin, userID);
        await sessions.settleOpen(admin, userID);
        return jsonResponse(200, sessions.allowance(providersConfigured()), id);
      case "start":
        await requireActiveEntitlement(admin, userID);
        if (!providersConfigured()) {
          throw new HttpError(
            503,
            "voice_unavailable",
            "Live voice is unavailable. Please try again shortly.",
          );
        }
        return jsonResponse(200, await sessions.start(admin, userID, body), id);
      case "finish":
        // No entitlement check: a subscription ending mid-call still settles.
        return jsonResponse(200, await sessions.finish(admin, userID, body), id);
      case "transcriber": {
        const [, session] = await Promise.all([
          requireActiveEntitlement(admin, userID),
          requireOpenSession(admin, userID, body, { activated: false }),
        ]);
        const provider = transcriberProvider(
          Deno.env.get("KUMUSTA_LIVE_STT_PROVIDER"),
          Boolean(Deno.env.get("SONIOX_API_KEY")?.trim()),
          body.providers,
        );
        await labelSession(admin, session, provider);
        const grant = provider === "soniox"
          ? await sonioxTranscriber(session.id)
          : await transcriber();
        // iOS echo cancellation lets learners interrupt Bé Trâu on the
        // speaker; off until verified on devices.
        const echoCancellation = Deno.env.get("KUMUSTA_LIVE_ECHO_CANCELLATION")?.trim() === "on";
        return jsonResponse(200, { ...grant, echoCancellation }, id);
      }
      case "reply": {
        // The reply starts generating while access is still being checked;
        // nothing is spoken unless both checks pass.
        const access = Promise.all([
          requireActiveEntitlement(admin, userID),
          requireOpenSession(admin, userID, body, { activated: true }),
        ]).then(() => undefined);
        access.catch(() => {});
        return reply(body, access, id);
      }
      default:
        throw new HttpError(400, "invalid_action", "Unsupported live practice action.");
    }
  } catch (error) {
    if (error instanceof HttpError && error.status >= 500) {
      console.error("live_pipeline_request_failed", { request_id: id, code: error.code });
    }
    return errorResponse(error, id);
  }
});

function providersConfigured(): boolean {
  return ["ANTHROPIC_API_KEY", "ELEVENLABS_API_KEY"].every((name) =>
    Boolean(Deno.env.get(name)?.trim())
  );
}

// Kept for the worker's lifetime so the signing keys are fetched once.
let authClient: SupabaseClient | null = null;

/**
 * Verifies the Supabase access token's signature locally against the
 * project's published signing keys. The shared helper's `auth.getUser()` is a
 * network round trip to Auth that intermittently takes over ten seconds, which
 * a spoken turn cannot afford. Anonymous learners are allowed, as before.
 */
async function authenticate(req: Request): Promise<{ admin: Admin; userID: string }> {
  const match = /^Bearer ([^\s]{20,8192})$/.exec(req.headers.get("authorization") ?? "");
  if (!match) throw new HttpError(401, "authentication_required", "Sign in to continue.");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ||
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY")?.trim();
  if (!publishableKey) {
    throw new HttpError(503, "service_unavailable", "The service is not configured.");
  }
  authClient ??= createClient(requiredEnv("SUPABASE_URL"), publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  // A malformed token throws instead of returning an error.
  const verified = await authClient.auth.getClaims(match[1]).catch(() => null);
  const claims = verified?.error ? null : verified?.data?.claims;
  if (!claims?.sub || claims.role !== "authenticated") {
    throw new HttpError(401, "invalid_session", "Your session has expired. Sign in again.");
  }
  return { admin: createAdminClient(), userID: claims.sub };
}

async function readBody(req: Request): Promise<Record<string, unknown>> {
  const text = await req.text();
  if (text.length > REQUEST_BODY_LIMIT) {
    throw new HttpError(413, "payload_too_large", "This request is too large.");
  }
  try {
    const value = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error();
    return value as Record<string, unknown>;
  } catch {
    throw new HttpError(400, "invalid_body", "This request could not be read.");
  }
}

async function requireOpenSession(
  admin: Admin,
  userID: string,
  body: Record<string, unknown>,
  options: { activated: boolean },
) {
  let sessionID: string;
  try {
    sessionID = sessionIDFrom(body.session_id);
  } catch {
    throw new HttpError(400, "invalid_session", "This conversation could not be found.");
  }
  const { data, error } = await admin.from("kumusta_live_sessions")
    .select("id, round_id, reserved_seconds, started_at, created_at")
    .eq("id", sessionID)
    .eq("user_id", userID)
    .is("ended_at", null)
    .maybeSingle();
  if (error) {
    throw new HttpError(503, "usage_unavailable", "Your practice time could not be loaded.");
  }
  if (!data) throw new HttpError(409, "session_closed", "This conversation has already ended.");
  if (!options.activated) return data;
  // The greeting can be requested while activation is still in flight; an
  // unactivated reservation is bounded from its creation instead.
  const started = Date.parse(data.started_at ?? data.created_at);
  if (
    !Number.isFinite(started) ||
    started + data.reserved_seconds * 1000 + SESSION_GRACE_MS < Date.now()
  ) {
    throw new HttpError(409, "session_closed", "This conversation has already ended.");
  }
  return data;
}

/**
 * `kumusta-live` labels every reservation as the agent; relabel this one so
 * usage can be split by engine. Reporting metadata only: never blocks a call.
 */
async function labelSession(
  admin: Admin,
  session: { id: string; round_id: string },
  provider: TranscriberProvider,
) {
  const label = engineLabel(provider);
  const results = await Promise.all([
    admin.from("kumusta_live_sessions").update({ model: label })
      .eq("id", session.id),
    admin.from("kumusta_live_rounds").update({ model: label })
      .eq("id", session.round_id),
  ]);
  for (const { error } of results) {
    if (error) {
      console.warn("live_pipeline_label_skipped", { session_id: session.id, code: error.code });
    }
  }
}

/**
 * Kill switch without a redeploy: set KUMUSTA_LIVE_STT_SECONDARY_LANGUAGES
 * to "none" to transcribe Vietnamese only, or to a comma-separated list.
 */
function secondaryLanguages(): string[] | undefined {
  const value = Deno.env.get("KUMUSTA_LIVE_STT_SECONDARY_LANGUAGES")?.trim();
  if (!value) return undefined;
  if (value === "none") return [];
  return value.split(",").map((language) => language.trim());
}

/** A short-lived, single-use Soniox key; the real key never leaves the server. */
async function sonioxTranscriber(sessionID: string) {
  let response: Response;
  try {
    response = await fetchWithTimeout(
      "https://api.soniox.com/v1/auth/temporary-api-key",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${requiredEnv("SONIOX_API_KEY")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          usage_type: "transcribe_websocket",
          expires_in_seconds: 60,
          single_use: true,
          max_session_duration_seconds: 3700,
          client_reference_id: sessionID,
        }),
      },
      PROVIDER_TIMEOUT_MS,
    );
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(502, "transcription_unavailable", "Live voice is unavailable.");
  }
  const payload = response.ok ? await response.json().catch(() => null) : null;
  const key = typeof payload?.api_key === "string" ? payload.api_key : "";
  if (!key) {
    console.error("live_pipeline_soniox_key_rejected", { status: response.status });
    throw new HttpError(502, "transcription_unavailable", "Live voice is unavailable.");
  }
  return {
    version: 1,
    provider: "soniox",
    url: SONIOX_ENDPOINT,
    token: key,
    config: sonioxConfig(sessionID),
    sampleRate: PIPELINE_SAMPLE_RATE,
  };
}

async function transcriber() {
  let response: Response;
  try {
    response = await fetchWithTimeout(
      "https://api.elevenlabs.io/v1/single-use-token/realtime_scribe",
      { method: "POST", headers: { "xi-api-key": requiredEnv("ELEVENLABS_API_KEY") } },
      PROVIDER_TIMEOUT_MS,
    );
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(502, "transcription_unavailable", "Live voice is unavailable.");
  }
  const payload = response.ok ? await response.json().catch(() => null) : null;
  try {
    return {
      version: 1,
      url: transcriberURL(String(payload?.token ?? ""), secondaryLanguages()),
      sampleRate: PIPELINE_SAMPLE_RATE,
    };
  } catch {
    console.error("live_pipeline_stt_token_rejected", { status: response.status });
    throw new HttpError(502, "transcription_unavailable", "Live voice is unavailable.");
  }
}

function reply(body: Record<string, unknown>, access: Promise<void>, id: string): Response {
  let context: ReturnType<typeof contextFrom>;
  let history: ChatMessage[] | null = null;
  try {
    context = contextFrom(body.context);
    if (body.greeting !== true) history = historyFrom(body.history);
  } catch {
    throw new HttpError(400, "invalid_context", "Your message couldn’t be sent.");
  }
  const anthropicKey = requiredEnv("ANTHROPIC_API_KEY");
  const elevenLabsKey = requiredEnv("ELEVENLABS_API_KEY");
  const voiceID = voiceIDForAccent(context.accent === "northern" ? "northern" : "southern");

  const begun = performance.now();
  const timing: Record<string, number> = {};
  const usage = { tts_characters: 0 } as Record<string, number>;
  const mark = (name: string) => {
    timing[name] ??= Math.round(performance.now() - begun);
  };
  // The greeting is the server-owned first message; every other reply is
  // generated from the learner's transcript. Generation starts right away.
  const generation = history ? startGeneration(anthropicKey, systemPrompt(context), history) : null;
  const sentences: AsyncIterable<string> = generation
    ? generatedSentences(generation, mark, usage)
    : (async function* () {
      yield firstMessage(context.accent, context.personality);
    })();

  // The app cancels a reply when the learner keeps talking; stop paying for
  // generation and speech nobody will hear.
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    cancel() {
      cancelled = true;
      generation?.abort();
    },
    async start(controller) {
      const send = (event: ReplyEvent) => {
        if (cancelled) throw new Error("client_cancelled");
        controller.enqueue(encodeEvent(event));
      };
      try {
        await access;
      } catch (error) {
        generation?.abort();
        if (!cancelled) {
          send({ type: "error", code: error instanceof HttpError ? error.code : "reply_failed" });
          controller.close();
        }
        return;
      }
      mark("access_ms");
      try {
        // Each sentence's speech is requested as soon as its text is known,
        // while earlier sentences are still being streamed to the app.
        const pending: { text: string; audio: Promise<Response> }[] = [];
        let spoken = "";
        const drain = async (all: boolean) => {
          while (pending.length > (all ? 0 : 1)) {
            const next = pending.shift()!;
            send({ type: "text", text: next.text });
            await streamSpeech(await next.audio, send, () => mark("first_audio_ms"));
          }
        };
        for await (const sentence of sentences) {
          mark("first_sentence_ms");
          usage.tts_characters += sentence.length;
          pending.push({
            text: sentence,
            audio: speech(elevenLabsKey, voiceID, sentence, spoken),
          });
          spoken = `${spoken} ${sentence}`.trim().slice(-500);
          await drain(false);
        }
        await drain(true);
        send({ type: "done" });
        mark("total_ms");
        // One line per reply: latency and the usage it was billed for.
        console.log("live_pipeline_turn", {
          request_id: id,
          session_id: String(body.session_id),
          greeting: !history,
          ...timing,
          ...usage,
        });
      } catch (error) {
        generation?.abort();
        if (cancelled) {
          console.log("live_pipeline_turn", {
            request_id: id,
            cancelled: true,
            ...timing,
            ...usage,
          });
          return;
        }
        console.error("live_pipeline_reply_failed", {
          request_id: id,
          reason: error instanceof Error ? error.message.slice(0, 400) : "unknown",
        });
        send({ type: "error", code: "reply_failed" });
      } finally {
        if (!cancelled) controller.close();
      }
    },
  });
  return new Response(stream, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/x-ndjson; charset=utf-8",
      "Cache-Control": "no-store",
      "x-request-id": id,
    },
  });
}

function systemPrompt(context: ReturnType<typeof contextFrom>): string {
  const grumpy = context.personality === "grumpy" ? `\n\n${GRUMPY_VOCABULARY_PROMPT}` : "";
  return `${agentPrompt(context)}${grumpy}\n\n${PIPELINE_VOICE_PROMPT}`;
}

function startGeneration(apiKey: string, system: string, messages: ChatMessage[]) {
  // An organization-level key must name the workspace it bills to.
  const workspace = Deno.env.get("ANTHROPIC_WORKSPACE_ID")?.trim();
  const client = new Anthropic({
    apiKey,
    maxRetries: 1,
    timeout: 15_000,
    ...(workspace ? { defaultHeaders: { "anthropic-workspace-id": workspace } } : {}),
  });
  // The request is sent as soon as the stream is created.
  return client.messages.stream({
    model: Deno.env.get("KUMUSTA_LIVE_LLM_MODEL")?.trim() || PIPELINE_LLM_MODEL,
    max_tokens: REPLY_MAX_TOKENS,
    // A spoken turn is short chat: no thinking, lowest effort, first token fast.
    thinking: { type: "disabled" },
    output_config: { effort: "low" },
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    messages,
  });
}

async function* generatedSentences(
  stream: ReturnType<typeof startGeneration>,
  mark: (name: string) => void,
  usage: Record<string, number>,
): AsyncGenerator<string> {
  let buffer = "";
  let first = true;
  for await (const event of stream) {
    if (event.type !== "content_block_delta" || event.delta.type !== "text_delta") continue;
    mark("llm_first_token_ms");
    buffer += event.delta.text;
    const { sentences, rest } = takeSentences(buffer, { eager: first });
    buffer = rest;
    if (sentences.length > 0) first = false;
    yield* sentences;
  }
  const final = await stream.finalMessage();
  usage.llm_input_tokens = final.usage.input_tokens;
  usage.llm_cache_read_tokens = final.usage.cache_read_input_tokens ?? 0;
  usage.llm_cache_write_tokens = final.usage.cache_creation_input_tokens ?? 0;
  usage.llm_output_tokens = final.usage.output_tokens;
  if (final.stop_reason === "refusal") throw new Error("llm_refusal");
  const { sentences, rest } = takeSentences(`${buffer}\n`);
  yield* sentences;
  const tail = rest.trim();
  if (tail && hasSpeakableText(tail)) yield tail;
}

function speech(apiKey: string, voiceID: string, text: string, previous: string) {
  const language = speechLanguage(text.replace(/\[[^\]\n]{1,40}\]/g, " "));
  const endpoint = new URL(
    `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceID)}/stream`,
  );
  endpoint.searchParams.set("output_format", `pcm_${PLAYBACK_SAMPLE_RATE}`);
  return fetchWithTimeout(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json", "xi-api-key": apiKey },
    body: JSON.stringify({
      text,
      model_id: PIPELINE_TTS_MODEL,
      // Bé Trâu also explains in English or French; each sentence is read
      // with its own language's pronunciation.
      ...(language ? { language_code: language } : {}),
      // Expressive enough for audio tags while keeping the approved voice.
      // Speaker boost is left off: it adds latency.
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.85,
        style: 0,
        use_speaker_boost: false,
      },
      // Keeps intonation continuous across the reply's separate requests.
      ...(previous ? { previous_text: previous } : {}),
    }),
  }, 20_000);
}

async function streamSpeech(
  response: Response,
  send: (event: ReplyEvent) => void,
  started: () => void,
) {
  if (!response.ok || !response.body) {
    const detail = await response.text().catch(() => "");
    throw new Error(`tts_status_${response.status} ${detail.slice(0, 200)}`);
  }
  started();
  const aligner = new SampleAligner();
  for await (const chunk of response.body) {
    const samples = aligner.push(chunk);
    if (samples.length > 0) send({ type: "audio", data: base64(samples) });
  }
}
