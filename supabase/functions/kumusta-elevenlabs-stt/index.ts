/// <reference lib="deno.ns" />

import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  fetchWithTimeout,
  HttpError,
  jsonResponse,
  readBoundedRequestBody,
  readBoundedResponseBody,
  requestID,
  requiredEnv,
} from "../_shared/http.ts";
import { admitSpeechAttempt } from "../_shared/speech_gate.ts";
import { sanitizeProviderTranscription, validateAudioContentType } from "./contract.ts";

const maximumAudioBytes = 1_500_000;
const minimumAudioBytes = 512;
const maximumProviderResponseBytes = 262_144;

Deno.serve(async (req: Request) => {
  const id = requestID(req);
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(new HttpError(405, "method_not_allowed", "Use POST."), id);
  }

  try {
    const context = await requireAuthenticatedUser(req, { allowAnonymous: true });
    const contentType = validateAudioContentType(req.headers.get("content-type"));
    const audio = await readBoundedRequestBody(req, maximumAudioBytes, minimumAudioBytes);
    await admitSpeechAttempt(req, context);

    const providerAudio = new Uint8Array(audio.byteLength);
    providerAudio.set(audio);
    const form = new FormData();
    form.append(
      "file",
      new Blob([providerAudio.buffer], { type: contentType }),
      "speaking-attempt.m4a",
    );
    form.append("model_id", "scribe_v2");
    form.append("language_code", "fil");
    form.append("diarize", "false");
    form.append("tag_audio_events", "false");

    let providerResponse: Response;
    try {
      providerResponse = await fetchWithTimeout(
        "https://api.elevenlabs.io/v1/speech-to-text",
        {
          method: "POST",
          headers: { "xi-api-key": requiredEnv("ELEVENLABS_API_KEY") },
          body: form,
        },
        20_000,
      );
    } catch {
      console.error("elevenlabs_stt_unreachable", { request_id: id });
      throw new HttpError(
        502,
        "transcription_unavailable",
        "Speech feedback is temporarily unavailable.",
      );
    }

    if (!providerResponse.ok) {
      console.error("elevenlabs_stt_rejected", {
        request_id: id,
        status: providerResponse.status,
      });
      throw new HttpError(
        502,
        "transcription_unavailable",
        "Speech feedback is temporarily unavailable.",
      );
    }

    let providerPayload: unknown;
    try {
      const bytes = await readBoundedResponseBody(providerResponse, maximumProviderResponseBytes);
      providerPayload = JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      throw new HttpError(
        502,
        "transcription_unavailable",
        "Speech feedback is temporarily unavailable.",
      );
    }
    return jsonResponse(200, sanitizeProviderTranscription(providerPayload), id);
  } catch (error) {
    return errorResponse(error, id);
  }
});
