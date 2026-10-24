/// <reference lib="deno.ns" />

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-request-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export function requestID(req: Request): string {
  const candidate = req.headers.get("x-request-id");
  if (candidate && /^[A-Za-z0-9._-]{8,80}$/.test(candidate)) return candidate;
  return crypto.randomUUID();
}

export function jsonResponse(
  status: number,
  body: unknown,
  id?: string,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...(id ? { "x-request-id": id } : {}),
    },
  });
}

export function errorResponse(error: unknown, id: string): Response {
  if (error instanceof HttpError) {
    return jsonResponse(error.status, {
      code: error.code,
      message: error.message,
      request_id: id,
    }, id);
  }
  console.error("unhandled_edge_error", { request_id: id });
  return jsonResponse(500, {
    code: "internal_error",
    message: "The request could not be completed.",
    request_id: id,
  }, id);
}

export async function readJSONBody(
  req: Request,
  maxBytes: number,
): Promise<Record<string, unknown>> {
  const contentType = req.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.startsWith("application/json")) {
    throw new HttpError(415, "content_type_required", "Send a JSON request.");
  }

  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new HttpError(413, "body_too_large", "The request is too large.");
  }

  const raw = await req.text();
  if (new TextEncoder().encode(raw).byteLength > maxBytes) {
    throw new HttpError(413, "body_too_large", "The request is too large.");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new HttpError(400, "invalid_json", "The request is not valid JSON.");
  }
  if (!isPlainObject(parsed)) {
    throw new HttpError(400, "invalid_body", "Send a JSON object.");
  }
  return parsed;
}

export function isPlainObject(
  value: unknown,
): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value || value === "replace_me") {
    throw new HttpError(
      503,
      "service_unavailable",
      "The service is not configured.",
    );
  }
  return value;
}

export async function fetchWithTimeout(
  input: string | URL | Request,
  init: RequestInit,
  timeoutMilliseconds: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMilliseconds);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

export class ResponseBodyTooLargeError extends Error {
  constructor(readonly maximumBytes: number) {
    super(`Response body exceeded ${maximumBytes} bytes.`);
  }
}

/// Reads an inbound binary request without trusting Content-Length and without
/// retaining more than the configured ceiling plus the current network chunk.
/// Use this for short-lived media uploads rather than `arrayBuffer()`, which
/// has no application-level size bound when a client omits Content-Length.
export async function readBoundedRequestBody(
  request: Request,
  maximumBytes: number,
  minimumBytes = 1,
): Promise<Uint8Array> {
  if (
    !Number.isSafeInteger(maximumBytes) || maximumBytes < 1 ||
    !Number.isSafeInteger(minimumBytes) || minimumBytes < 0 ||
    minimumBytes > maximumBytes
  ) {
    throw new TypeError("Request byte limits are invalid");
  }

  const declared = request.headers.get("content-length");
  if (declared !== null) {
    const declaredBytes = Number(declared);
    if (!Number.isSafeInteger(declaredBytes) || declaredBytes < minimumBytes) {
      throw new HttpError(400, "invalid_audio", "Record a short phrase and try again.");
    }
    if (declaredBytes > maximumBytes) {
      throw new HttpError(413, "audio_too_large", "Keep the recording under 20 seconds.");
    }
  }
  if (!request.body) {
    throw new HttpError(400, "invalid_audio", "Record a short phrase and try again.");
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maximumBytes) {
        try {
          await reader.cancel("request_body_too_large");
        } catch {
          // The byte limit remains authoritative if stream cancellation fails.
        }
        throw new HttpError(413, "audio_too_large", "Keep the recording under 20 seconds.");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  if (totalBytes < minimumBytes) {
    throw new HttpError(400, "invalid_audio", "Record a short phrase and try again.");
  }
  const output = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return output;
}

/// Reads a provider response without ever retaining more than the configured
/// ceiling plus the current network chunk. Content-Length is only an early
/// rejection; streamed byte accounting remains authoritative.
export async function readBoundedResponseBody(
  response: Response,
  maximumBytes: number,
): Promise<Uint8Array> {
  if (!Number.isSafeInteger(maximumBytes) || maximumBytes < 1) {
    throw new TypeError("maximumBytes must be a positive safe integer");
  }
  const declared = response.headers.get("content-length");
  if (declared !== null) {
    const declaredBytes = Number(declared);
    if (!Number.isSafeInteger(declaredBytes) || declaredBytes < 0) {
      throw new ResponseBodyTooLargeError(maximumBytes);
    }
    if (declaredBytes > maximumBytes) {
      throw new ResponseBodyTooLargeError(maximumBytes);
    }
  }
  if (!response.body) return new Uint8Array();

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maximumBytes) {
        try {
          await reader.cancel("response_body_too_large");
        } catch {
          // The size violation remains authoritative even when a provider's
          // stream rejects cancellation.
        }
        throw new ResponseBodyTooLargeError(maximumBytes);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const output = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return output;
}

/// Compares hashes rather than raw strings so unequal source lengths do not
/// create an obvious early-return timing signal.
export async function secureEqual(
  left: string,
  right: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const [leftHash, rightHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(left)),
    crypto.subtle.digest("SHA-256", encoder.encode(right)),
  ]);
  const a = new Uint8Array(leftHash);
  const b = new Uint8Array(rightHash);
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}
