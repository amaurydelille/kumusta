/// <reference lib="deno.ns" />

import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  fetchWithTimeout,
  HttpError,
  jsonResponse,
  readBoundedResponseBody,
  requestID,
  requiredEnv,
} from "../_shared/http.ts";
import { admitSpeechAttempt } from "../_shared/speech_gate.ts";
import { realtimeSession } from "./contract.ts";

const maximumProviderResponseBytes = 4_096;

// Issues one single-use ElevenLabs realtime Scribe session so the app can
// stream a take while the learner is still speaking. Admission and quotas are
// identical to the upload path; the ElevenLabs key never leaves the server.
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
    await admitSpeechAttempt(req, context);

    let providerResponse: Response;
    try {
      providerResponse = await fetchWithTimeout(
        "https://api.elevenlabs.io/v1/single-use-token/realtime_scribe",
        {
          method: "POST",
          headers: { "xi-api-key": requiredEnv("ELEVENLABS_API_KEY") },
        },
        6_000,
      );
    } catch {
      console.error("elevenlabs_stt_token_unreachable", { request_id: id });
      throw new HttpError(
        502,
        "transcription_unavailable",
        "Speech feedback is temporarily unavailable.",
      );
    }

    if (!providerResponse.ok) {
      console.error("elevenlabs_stt_token_rejected", {
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
    return jsonResponse(200, realtimeSession(providerPayload), id);
  } catch (error) {
    return errorResponse(error, id);
  }
});
