/// <reference lib="deno.ns" />

import { consumeQuota, createAdminClient } from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  fetchWithTimeout,
  HttpError,
  isPlainObject,
  jsonResponse,
  requestID,
  requiredEnv,
  secureEqual,
} from "../_shared/http.ts";
import {
  mappedSupabaseUserID,
  mapRevenueCatV2CustomerInfo,
  parseRevenueCatEvent,
  revenueCatCustomerIDs,
  sanitizedAuditPayload,
  transactionalEmailType,
  verifyRevenueCatHMAC,
  voluntaryCancellationSnapshot,
} from "./contract.ts";
import type { RevenueCatCustomerInfo, RevenueCatEvent } from "./contract.ts";

const maximumWebhookBytes = 524_288;
const maximumCustomerInfoBytes = 524_288;
const maximumRevenueCatPages = 5;
const revenueCatAPIBase = "https://api.revenuecat.com";

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
    const expectedAuthorization = Deno.env.get(
      "REVENUECAT_WEBHOOK_AUTHORIZATION",
    )?.trim() || Deno.env.get("REVENUECAT_WEBHOOK_AUTH")?.trim();
    if (!expectedAuthorization) {
      throw new HttpError(
        503,
        "service_unavailable",
        "The service is not configured.",
      );
    }
    const providedAuthorization = req.headers.get("authorization") ?? "";
    if (!await secureEqual(providedAuthorization, expectedAuthorization)) {
      throw new HttpError(
        401,
        "invalid_webhook_authorization",
        "Unauthorized.",
      );
    }

    const declaredLength = Number(req.headers.get("content-length") ?? "0");
    if (
      Number.isFinite(declaredLength) && declaredLength > maximumWebhookBytes
    ) {
      throw new HttpError(413, "body_too_large", "The request is too large.");
    }
    const rawBody = await req.text();
    if (new TextEncoder().encode(rawBody).byteLength > maximumWebhookBytes) {
      throw new HttpError(413, "body_too_large", "The request is too large.");
    }

    const signingSecret = Deno.env.get("REVENUECAT_WEBHOOK_SIGNING_SECRET")
      ?.trim();
    if (signingSecret) {
      const signatureHeader = req.headers.get("x-revenuecat-webhook-signature") ?? "";
      const validSignature = await verifyRevenueCatHMAC(
        rawBody,
        signatureHeader,
        signingSecret,
        Math.floor(Date.now() / 1_000),
      );
      if (!validSignature) {
        throw new HttpError(401, "invalid_webhook_signature", "Unauthorized.");
      }
    }

    let payload: unknown;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      throw new HttpError(400, "invalid_json", "Invalid webhook payload.");
    }
    const event = parseRevenueCatEvent(payload);
    const admin = createAdminClient();

    const auditRow = {
      event_id: event.id,
      event_type: event.type,
      app_user_id: event.appUserID,
      environment: event.environment ?? null,
      payload: sanitizedAuditPayload(event),
    };
    const { error: auditError } = await admin
      .from("kumusta_revenuecat_events")
      .upsert(auditRow, {
        onConflict: "event_id",
        ignoreDuplicates: true,
      });
    if (auditError) {
      console.error("revenuecat_audit_write_failed", {
        request_id: id,
        code: auditError.code,
      });
      throw new HttpError(503, "webhook_storage_unavailable", "Please retry.");
    }

    const { data: existingEvent, error: existingError } = await admin
      .from("kumusta_revenuecat_events")
      .select("processed_at")
      .eq("event_id", event.id)
      .maybeSingle();
    if (existingError) {
      throw new HttpError(503, "webhook_storage_unavailable", "Please retry.");
    }
    if (existingEvent?.processed_at) {
      return jsonResponse(200, { received: true, duplicate: true }, id);
    }

    if (event.type === "TEST") {
      await markProcessed(admin, event.id, null);
      return jsonResponse(200, { received: true, test_event: true }, id);
    }

    const userID = mappedSupabaseUserID(event);
    if (!userID) {
      await markProcessed(admin, event.id, "unmapped_customer_identity");
      return jsonResponse(200, { received: true, mapped: false }, id);
    }

    try {
      // Queue the customer email before refreshing entitlements. A temporary
      // RevenueCat API outage must not make a transactional email disappear.
      // The unique (event_id, email_type) constraint keeps webhook retries
      // idempotent.
      await enqueueTransactionalEmail(admin, event.id, userID, event);
      await consumeQuota(admin, userID, "revenuecat_sync", 120, 60);
      let customerInfo: RevenueCatCustomerInfo | null;
      try {
        customerInfo = await fetchRevenueCatCustomer(event);
      } catch (error) {
        if (
          !(error instanceof HttpError) ||
          error.code !== "revenuecat_customer_not_found"
        ) throw error;
        customerInfo = null;
      }
      if (customerInfo) {
        await mirrorEntitlements(
          admin,
          userID,
          event.id,
          event.environment,
          customerInfo,
        );
      } else {
        await mirrorVoluntaryCancellationSnapshot(admin, userID, event);
      }
      await markProcessed(admin, event.id, null);
      return jsonResponse(200, { received: true, mapped: true }, id);
    } catch (error) {
      const reason = error instanceof HttpError && error.code === "rate_limited"
        ? "rate_limited"
        : "sync_failed";
      await markFailed(admin, event.id, reason);
      throw error;
    }
  } catch (error) {
    return errorResponse(error, id);
  }
});

async function enqueueTransactionalEmail(
  admin: ReturnType<typeof createAdminClient>,
  eventID: string,
  userID: string,
  event: ReturnType<typeof parseRevenueCatEvent>,
): Promise<void> {
  const emailType = transactionalEmailType(event);
  if (!emailType) return;

  const { error } = await admin.from("kumusta_email_jobs").upsert(
    {
      event_id: eventID,
      user_id: userID,
      email_type: emailType,
      status: "pending",
      next_attempt_at: new Date().toISOString(),
    },
    { onConflict: "event_id,email_type", ignoreDuplicates: true },
  );
  if (error) {
    console.error("transactional_email_enqueue_failed", {
      event_id: eventID,
      email_type: emailType,
      code: error.code,
    });
    throw new HttpError(503, "email_queue_unavailable", "Please retry.");
  }
}

async function fetchRevenueCatCustomer(
  event: RevenueCatEvent,
): Promise<RevenueCatCustomerInfo> {
  const secret = requiredEnv("REVENUECAT_SECRET_API_KEY");
  const projectID = requiredEnv("REVENUECAT_PROJECT_ID");
  for (const customerID of revenueCatCustomerIDs(event)) {
    const customerPath = `/v2/projects/${encodeURIComponent(projectID)}/customers/${
      encodeURIComponent(customerID)
    }`;
    try {
      const [activeEntitlements, subscriptions, projectEntitlements] = await Promise.all([
        fetchRevenueCatCollection(`${customerPath}/active_entitlements`, secret),
        fetchRevenueCatCollection(`${customerPath}/subscriptions`, secret),
        // Optional: needs the key's entitlements read permission. Without it,
        // only subscription-backed entitlements can be mapped.
        fetchRevenueCatCollection(
          `/v2/projects/${encodeURIComponent(projectID)}/entitlements`,
          secret,
        ).catch(() => null),
      ]);
      return mapRevenueCatV2CustomerInfo(activeEntitlements, subscriptions, projectEntitlements);
    } catch (error) {
      if (error instanceof HttpError && error.status === 404) continue;
      throw error;
    }
  }
  throw new HttpError(503, "revenuecat_customer_not_found", "Please retry.");
}

async function fetchRevenueCatCollection(
  path: string,
  secret: string,
): Promise<{ items: unknown[] }> {
  let url = new URL(`${path}?limit=100`, revenueCatAPIBase);
  const items: unknown[] = [];

  for (let page = 0; page < maximumRevenueCatPages; page += 1) {
    let response: Response;
    try {
      response = await fetchWithTimeout(
        url.toString(),
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${secret}`,
            Accept: "application/json",
          },
        },
        8_000,
      );
    } catch {
      throw new HttpError(503, "revenuecat_unavailable", "Please retry.");
    }

    const declaredLength = Number(
      response.headers.get("content-length") ?? "0",
    );
    if (!response.ok) {
      console.error("revenuecat_customer_fetch_failed", {
        status: response.status,
      });
      if (response.status === 404) {
        throw new HttpError(
          404,
          "revenuecat_customer_not_found",
          "Please retry.",
        );
      }
      throw new HttpError(503, "revenuecat_unavailable", "Please retry.");
    }
    if (
      Number.isFinite(declaredLength) &&
      declaredLength > maximumCustomerInfoBytes
    ) {
      throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
    }

    const raw = await response.text();
    if (new TextEncoder().encode(raw).byteLength > maximumCustomerInfoBytes) {
      throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
    }
    if (!isPlainObject(parsed) || !Array.isArray(parsed.items)) {
      throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
    }
    items.push(...parsed.items);

    if (parsed.next_page == null) return { items };
    if (typeof parsed.next_page !== "string") {
      throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
    }
    const nextURL = new URL(parsed.next_page, revenueCatAPIBase);
    if (
      nextURL.origin !== revenueCatAPIBase || nextURL.pathname !== path ||
      !nextURL.searchParams.has("starting_after")
    ) {
      throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
    }
    nextURL.searchParams.set("limit", "100");
    url = nextURL;
  }

  throw new HttpError(503, "revenuecat_response_invalid", "Please retry.");
}

async function mirrorEntitlements(
  admin: ReturnType<typeof createAdminClient>,
  userID: string,
  eventID: string,
  environment: "SANDBOX" | "PRODUCTION" | undefined,
  customer: RevenueCatCustomerInfo,
): Promise<void> {
  const now = Date.now();
  const rows = Object.entries(customer.entitlements)
    .filter(([entitlementID, value]) =>
      entitlementID.length >= 1 &&
      entitlementID.length <= 120 &&
      isPlainObject(value)
    )
    .map(([entitlementID, entitlement]) => {
      const expiry = validDate(entitlement.expires_date);
      const graceExpiry = validDate(entitlement.grace_period_expires_date);
      const effectiveExpiry = latestDate(expiry, graceExpiry);
      const productID = typeof entitlement.product_identifier === "string" &&
          entitlement.product_identifier.length <= 200
        ? entitlement.product_identifier
        : null;
      const subscription = productID ? customer.subscriptions[productID] : undefined;
      // RevenueCat uses explicit null for lifetime. Missing or malformed expiry
      // data must never be interpreted as a lifetime grant.
      const isLifetime = entitlement.expires_date === null;
      const isActive = isLifetime ||
        (effectiveExpiry !== null && effectiveExpiry.getTime() > now);
      return {
        user_id: userID,
        entitlement_id: entitlementID,
        is_active: isActive,
        product_id: productID,
        environment: environment?.toLowerCase() ?? null,
        purchased_at: validDate(entitlement.purchase_date)?.toISOString() ??
          null,
        expires_at: effectiveExpiry?.toISOString() ?? null,
        will_renew: isActive && effectiveExpiry !== null
          ? isPlainObject(subscription) &&
            subscription.unsubscribe_detected_at == null
          : false,
        last_revenuecat_event_id: eventID,
        last_synced_at: new Date().toISOString(),
      };
    });

  const { data: existingRows, error: existingError } = await admin
    .from("kumusta_entitlements")
    .select("entitlement_id")
    .eq("user_id", userID);
  if (existingError) {
    throw new HttpError(
      503,
      "entitlement_storage_unavailable",
      "Please retry.",
    );
  }

  if (rows.length > 0) {
    const { error } = await admin
      .from("kumusta_entitlements")
      .upsert(rows, { onConflict: "user_id,entitlement_id" });
    if (error) {
      console.error("entitlement_upsert_failed", { code: error.code });
      throw new HttpError(
        503,
        "entitlement_storage_unavailable",
        "Please retry.",
      );
    }
  }

  const activeIdentifiers = new Set(rows.map((row) => row.entitlement_id));
  const missingIdentifiers = (existingRows ?? [])
    .map((row) => row.entitlement_id)
    .filter((entitlementID): entitlementID is string =>
      typeof entitlementID === "string" && !activeIdentifiers.has(entitlementID)
    );
  for (const entitlementID of missingIdentifiers) {
    const { error } = await admin
      .from("kumusta_entitlements")
      .update({
        is_active: false,
        will_renew: false,
        last_revenuecat_event_id: eventID,
        last_synced_at: new Date().toISOString(),
      })
      .eq("user_id", userID)
      .eq("entitlement_id", entitlementID);
    if (error) {
      throw new HttpError(
        503,
        "entitlement_storage_unavailable",
        "Please retry.",
      );
    }
  }
}

async function mirrorVoluntaryCancellationSnapshot(
  admin: ReturnType<typeof createAdminClient>,
  userID: string,
  event: RevenueCatEvent,
): Promise<void> {
  const snapshot = voluntaryCancellationSnapshot(event);
  if (!snapshot) {
    throw new HttpError(503, "revenuecat_customer_not_found", "Please retry.");
  }

  // Never infer a complete entitlement state from one event if this user already
  // has mirrored entitlements that could belong to another active subscription.
  const { data: existingRows, error: existingError } = await admin
    .from("kumusta_entitlements")
    .select("entitlement_id")
    .eq("user_id", userID);
  if (existingError) {
    throw new HttpError(
      503,
      "entitlement_storage_unavailable",
      "Please retry.",
    );
  }
  if ((existingRows ?? []).length > 0) {
    throw new HttpError(503, "revenuecat_customer_not_found", "Please retry.");
  }

  const now = new Date();
  const rows = snapshot.map((entitlement) => ({
    user_id: userID,
    entitlement_id: entitlement.entitlement_id,
    is_active: new Date(entitlement.expires_at).getTime() > now.getTime(),
    product_id: entitlement.product_id,
    environment: "production",
    purchased_at: entitlement.purchased_at,
    expires_at: entitlement.expires_at,
    will_renew: false,
    last_revenuecat_event_id: event.id,
    last_synced_at: now.toISOString(),
  }));
  const { error } = await admin
    .from("kumusta_entitlements")
    .upsert(rows, { onConflict: "user_id,entitlement_id" });
  if (error) {
    console.error("entitlement_snapshot_upsert_failed", { code: error.code });
    throw new HttpError(
      503,
      "entitlement_storage_unavailable",
      "Please retry.",
    );
  }
}

async function markProcessed(
  admin: ReturnType<typeof createAdminClient>,
  eventID: string,
  processingError: string | null,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_revenuecat_events")
    .update({
      processed_at: new Date().toISOString(),
      processing_error: processingError,
    })
    .eq("event_id", eventID);
  if (error) {
    throw new HttpError(503, "webhook_storage_unavailable", "Please retry.");
  }
}

async function markFailed(
  admin: ReturnType<typeof createAdminClient>,
  eventID: string,
  reason: string,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_revenuecat_events")
    .update({ processing_error: reason })
    .eq("event_id", eventID);
  if (error) {
    console.error("revenuecat_failure_mark_failed", { code: error.code });
  }
}

function validDate(value: unknown): Date | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function latestDate(left: Date | null, right: Date | null): Date | null {
  if (!left) return right;
  if (!right) return left;
  return left > right ? left : right;
}
