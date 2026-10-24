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
import {
  sanitizeProviderTranscription,
  sonioxTranscriptionRequest,
  validateAudioContentType,
} from "./contract.ts";

const sonioxAPI = "https://api.soniox.com/v1";
const maximumAudioBytes = 1_500_000;
const minimumAudioBytes = 512;
const maximumProviderResponseBytes = 262_144;
const transcriptionDeadlineMs = 18_000;
const pollIntervalMs = 250;

// Transcribes one uploaded speaking take with Soniox's async API: upload the
// file, transcribe it, read the transcript, then delete both so no learner
// audio is kept at the provider. Used when the take could not be streamed.
Deno.serve(async (req: Request) => {
  const id = requestID(req);
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(new HttpError(405, "method_not_allowed", "Use POST."), id);
  }

  let fileID: string | null = null;
  let transcriptionID: string | null = null;
  const key = () => requiredEnv("KUMUSTA_LESSON_STT_API_KEY");
  try {
    const context = await requireAuthenticatedUser(req, { allowAnonymous: true });
    const contentType = validateAudioContentType(req.headers.get("content-type"));
    const audio = await readBoundedRequestBody(req, maximumAudioBytes, minimumAudioBytes);
    await admitSpeechAttempt(req, context);
    const deadline = Date.now() + transcriptionDeadlineMs;

    const providerAudio = new Uint8Array(audio.byteLength);
    providerAudio.set(audio);
    const form = new FormData();
    form.append("file", new Blob([providerAudio.buffer], { type: contentType }), "take.m4a");
    form.append("client_reference_id", id.slice(0, 256));
    const file = await soniox("POST", "/files", key(), id, form);
    fileID = typeof file.id === "string" ? file.id : null;
    if (!fileID) throw unavailable();

    const created = await soniox(
      "POST",
      "/transcriptions",
      key(),
      id,
      JSON.stringify(sonioxTranscriptionRequest(fileID, id)),
    );
    transcriptionID = typeof created.id === "string" ? created.id : null;
    if (!transcriptionID) throw unavailable();

    let status = String(created.status ?? "");
    while (status !== "completed") {
      if (status === "error" || status === "failed") {
        console.error("soniox_stt_failed", { request_id: id, error_type: created.error_type });
        throw unavailable();
      }
      if (Date.now() > deadline) {
        console.error("soniox_stt_timeout", { request_id: id });
        throw unavailable();
      }
      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
      const polled = await soniox("GET", `/transcriptions/${transcriptionID}`, key(), id);
      status = String(polled.status ?? "");
    }

    const transcript = await soniox(
      "GET",
      `/transcriptions/${transcriptionID}/transcript`,
      key(),
      id,
    );
    return jsonResponse(200, sanitizeProviderTranscription(transcript), id);
  } catch (error) {
    return errorResponse(error, id);
  } finally {
    // Delete the transcription before the file it was made from; neither
    // failure affects the learner, so they run after the response.
    const cleanup = (async () => {
      if (transcriptionID) {
        await soniox("DELETE", `/transcriptions/${transcriptionID}`, key(), id).catch(() => {});
      }
      if (fileID) await soniox("DELETE", `/files/${fileID}`, key(), id).catch(() => {});
    })();
    const runtime = (globalThis as { EdgeRuntime?: { waitUntil(promise: Promise<unknown>): void } })
      .EdgeRuntime;
    if (runtime) runtime.waitUntil(cleanup);
  }
});

async function soniox(
  method: string,
  path: string,
  apiKey: string,
  id: string,
  body?: BodyInit,
): Promise<Record<string, unknown>> {
  let response: Response;
  try {
    response = await fetchWithTimeout(
      `${sonioxAPI}${path}`,
      {
        method,
        headers: {
          Authorization: `Bearer ${apiKey}`,
          ...(typeof body === "string" ? { "Content-Type": "application/json" } : {}),
        },
        body,
      },
      8_000,
    );
  } catch {
    console.error("soniox_stt_unreachable", { request_id: id, path: path.split("/")[1] });
    throw unavailable();
  }
  if (!response.ok) {
    console.error("soniox_stt_rejected", {
      request_id: id,
      path: path.split("/")[1],
      status: response.status,
    });
    throw unavailable();
  }
  if (method === "DELETE") return {};
  try {
    const bytes = await readBoundedResponseBody(response, maximumProviderResponseBytes);
    const payload = JSON.parse(new TextDecoder().decode(bytes));
    return payload !== null && typeof payload === "object" ? payload : {};
  } catch {
    throw unavailable();
  }
}

function unavailable(): HttpError {
  return new HttpError(
    502,
    "transcription_unavailable",
    "Speech feedback is temporarily unavailable.",
  );
}
