/// <reference lib="deno.ns" />

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import { HttpError, requiredEnv } from "./http.ts";

export type RateLimitScope =
  | "elevenlabs_tts"
  | "elevenlabs_tts_daily"
  | "elevenlabs_stt"
  | "elevenlabs_stt_daily"
  | "lessons"
  | "lessons_daily"
  | "lessons_mutation"
  | "lessons_mutation_daily"
  | "revenuecat_sync";

export type ProjectRateLimitScope =
  | "elevenlabs_tts_project_daily"
  | "elevenlabs_stt_project_daily";

export interface AuthenticatedContext {
  userID: string;
  isAnonymous: boolean;
  userClient: SupabaseClient;
  admin: SupabaseClient;
}

export function createAdminClient(): SupabaseClient {
  const url = requiredEnv("SUPABASE_URL");
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    Deno.env.get("SUPABASE_SECRET_KEY")?.trim();
  if (!secret) {
    throw new HttpError(
      503,
      "service_unavailable",
      "The service is not configured.",
    );
  }
  return createClient(url, secret, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireAuthenticatedUser(
  req: Request,
  options: { allowAnonymous: boolean } = { allowAnonymous: false },
): Promise<AuthenticatedContext> {
  const authorization = req.headers.get("authorization") ?? "";
  const match = /^Bearer ([^\s]{20,8192})$/.exec(authorization);
  if (!match) {
    throw new HttpError(401, "authentication_required", "Sign in to continue.");
  }

  const url = requiredEnv("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ||
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY")?.trim();
  if (!publishableKey) {
    throw new HttpError(
      503,
      "service_unavailable",
      "The service is not configured.",
    );
  }

  const accessToken = match[1];
  const userClient = createClient(url, publishableKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await userClient.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new HttpError(
      401,
      "invalid_session",
      "Your session has expired. Sign in again.",
    );
  }
  if (data.user.is_anonymous === true && !options.allowAnonymous) {
    throw new HttpError(
      403,
      "registered_account_required",
      "Create an account to use this feature.",
    );
  }

  return {
    userID: data.user.id,
    isAnonymous: data.user.is_anonymous === true,
    userClient,
    admin: createAdminClient(),
  };
}

/// Entitlement checks happen with the service role because anonymous learners
/// intentionally have no direct RLS access. The stored expiry already reflects
/// RevenueCat grace-period expiry when present.
export async function requireActiveEntitlement(
  admin: SupabaseClient,
  userID: string,
  entitlementID = Deno.env.get("KUMUSTA_ENTITLEMENT_ID")?.trim() ||
    "kumusta_pro",
): Promise<void> {
  // This server-only switch exists solely for the isolated development project
  // used by simulator builds. It defaults closed and must never be enabled in
  // staging or production. No client header can influence it.
  if (Deno.env.get("KUMUSTA_DEVELOPMENT_BYPASS_ENTITLEMENT") === "true") {
    if (Deno.env.get("KUMUSTA_ENVIRONMENT") !== "development") {
      throw new HttpError(
        503,
        "entitlement_unavailable",
        "Please try again shortly.",
      );
    }
    return;
  }
  if (
    entitlementID.length < 1 ||
    entitlementID.length > 120 ||
    !/^[A-Za-z0-9._-]+$/.test(entitlementID)
  ) {
    throw new HttpError(
      503,
      "entitlement_unavailable",
      "Please try again shortly.",
    );
  }
  const { data, error } = await admin
    .from("kumusta_entitlements")
    .select("is_active,expires_at")
    .eq("user_id", userID)
    .eq("entitlement_id", entitlementID)
    .maybeSingle();
  if (error) {
    console.error("entitlement_check_failed", { code: error.code });
    throw new HttpError(
      503,
      "entitlement_unavailable",
      "Please try again shortly.",
    );
  }
  const expiry = typeof data?.expires_at === "string" ? new Date(data.expires_at).getTime() : null;
  if (
    data?.is_active !== true ||
    (expiry !== null && (!Number.isFinite(expiry) || expiry <= Date.now()))
  ) {
    throw new HttpError(403, "premium_required", "Kumusta Pro is required.");
  }
}

/// Requires an atomic, service-role-only Postgres function. It intentionally
/// fails closed when quota accounting is unavailable.
export async function consumeQuota(
  admin: SupabaseClient,
  userID: string,
  scope: RateLimitScope,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const { data, error } = await admin.rpc("kumusta_consume_api_quota", {
    p_user_id: userID,
    p_scope: scope,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) {
    console.error("quota_accounting_failed", { scope, code: error.code });
    throw new HttpError(503, "quota_unavailable", "Please try again shortly.");
  }
  if (data !== true) {
    throw new HttpError(
      429,
      "rate_limited",
      "Take a short pause, then try again.",
    );
  }
}

/// Project budgets cap aggregate provider exposure even when many valid paid
/// identities act concurrently. The backing RPC is service-role-only.
export async function consumeProjectQuota(
  admin: SupabaseClient,
  scope: ProjectRateLimitScope,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const { data, error } = await admin.rpc("kumusta_consume_project_api_quota", {
    p_scope: scope,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) {
    console.error("project_quota_accounting_failed", { scope, code: error.code });
    throw new HttpError(503, "quota_unavailable", "Please try again shortly.");
  }
  if (data !== true) {
    throw new HttpError(
      429,
      "project_rate_limited",
      "Voice audio is temporarily at capacity. Please try again later.",
    );
  }
}
