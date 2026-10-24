/// <reference lib="deno.ns" />

import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  errorResponse,
  HttpError,
  jsonResponse,
  readJSONBody,
  requestID,
} from "../_shared/http.ts";
import { deleteAccountData, exportAccountData } from "./account_data.ts";
import {
  allowsAnonymousAccountDataRequest,
  maximumRequestBytes,
  parseAccountDataRequest,
} from "./contract.ts";

Deno.serve(async (req: Request) => {
  const id = requestID(req);
  try {
    const origin = requireAllowedOrigin(req);
    if (req.method === "OPTIONS") {
      return withAccountCORS(new Response(null, { status: 204 }), origin);
    }
    if (req.method !== "POST") {
      throw new HttpError(405, "method_not_allowed", "Use POST.");
    }

    const input = parseAccountDataRequest(
      await readJSONBody(req, maximumRequestBytes),
    );
    const context = await requireAuthenticatedUser(req, {
      allowAnonymous: allowsAnonymousAccountDataRequest(input),
    });
    const result = input.action === "export"
      ? await exportAccountData(context.admin, context.userID)
      : await deleteAccountData(context.admin, context.userID);
    return withAccountCORS(jsonResponse(200, result, id), origin);
  } catch (error) {
    return withAccountCORS(errorResponse(error, id), allowedOrigin(req));
  }
});

function requireAllowedOrigin(req: Request): string | null {
  const origin = req.headers.get("origin");
  if (!origin) return null;
  const allowed = configuredOrigins();
  if (!allowed.has(origin)) {
    throw new HttpError(
      403,
      "origin_not_allowed",
      "This origin is not allowed.",
    );
  }
  return origin;
}

function allowedOrigin(req: Request): string | null {
  const origin = req.headers.get("origin");
  return origin && configuredOrigins().has(origin) ? origin : null;
}

function configuredOrigins(): Set<string> {
  return new Set(
    (Deno.env.get("KUMUSTA_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter((value) => /^https:\/\/[^/\s]+(?::\d{1,5})?$/.test(value)),
  );
}

function withAccountCORS(response: Response, origin: string | null): Response {
  const headers = new Headers(response.headers);
  headers.delete("Access-Control-Allow-Origin");
  headers.set(
    "Access-Control-Allow-Headers",
    "authorization, apikey, content-type, x-request-id",
  );
  headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  headers.set("Access-Control-Max-Age", "86400");
  headers.set("Vary", "Origin");
  if (origin) headers.set("Access-Control-Allow-Origin", origin);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
