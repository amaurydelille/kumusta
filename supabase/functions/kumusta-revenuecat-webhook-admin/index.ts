/// <reference lib="deno.ns" />

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
import { createAdminClient } from "../_shared/auth.ts";

const revenueCatAPIBase = "https://api.revenuecat.com/v2";
const webhookURL =
  "https://vpitjvtfzpqfnqgzcpla.supabase.co/functions/v1/kumusta-revenuecat-webhook";

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
    const expectedAuthorization = requiredEnv("EMAIL_WORKER_AUTHORIZATION");
    const providedAuthorization = req.headers.get("authorization") ?? "";
    if (
      !await secureEqual(
        providedAuthorization,
        `Bearer ${expectedAuthorization}`,
      )
    ) {
      throw new HttpError(401, "unauthorized", "Unauthorized.");
    }

    let payload: unknown = {};
    try {
      payload = await req.json();
    } catch {
      payload = {};
    }
    const requestedAction = isPlainObject(payload) ? payload.action : null;
    const action = requestedAction === "reconcile"
      ? "reconcile"
      : requestedAction === "healthcheck"
      ? "healthcheck"
      : requestedAction === "retry_failed_sync"
      ? "retry_failed_sync"
      : "inspect";

    if (action === "healthcheck") {
      const webhookAuthorization = Deno.env.get(
        "REVENUECAT_WEBHOOK_AUTHORIZATION",
      )?.trim() || Deno.env.get("REVENUECAT_WEBHOOK_AUTH")?.trim();
      if (!webhookAuthorization) {
        throw new HttpError(
          503,
          "service_unavailable",
          "RevenueCat webhook authorization is not configured.",
        );
      }
      const eventID = `kumusta-healthcheck-${crypto.randomUUID()}`;
      const response = await fetchWithTimeout(
        webhookURL,
        {
          method: "POST",
          headers: {
            Authorization: webhookAuthorization,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            api_version: "1.0",
            event: {
              id: eventID,
              type: "TEST",
              app_user_id: "kumusta-internal-healthcheck",
              aliases: [],
              environment: "SANDBOX",
              event_timestamp_ms: Date.now(),
            },
          }),
        },
        10_000,
      );
      if (!response.ok) {
        throw new HttpError(
          502,
          "webhook_healthcheck_failed",
          `Webhook returned ${response.status}.`,
        );
      }
      return jsonResponse(200, {
        healthy: true,
        event_id: eventID,
        webhook_status: response.status,
      }, id);
    }

    if (action === "retry_failed_sync") {
      const results = await retryFailedWebhookEvents();
      return jsonResponse(200, {
        retried: results.length,
        results,
      }, id);
    }

    const integrations = await listWebhookIntegrations();
    if (action === "inspect") {
      return jsonResponse(200, {
        integrations: integrations.map(sanitizeIntegration),
        expected_url: webhookURL,
      }, id);
    }

    const candidate = integrations.find((integration) => integration.url === webhookURL) ??
      integrations.find((integration) =>
        integration.url?.endsWith("/functions/v1/revenuecat-webhook") ||
        integration.url?.endsWith("/functions/v1/kumusta-revenuecat-webhook")
      );

    const webhookAuthorization = Deno.env.get(
      "REVENUECAT_WEBHOOK_AUTHORIZATION",
    )?.trim() || Deno.env.get("REVENUECAT_WEBHOOK_AUTH")?.trim();
    if (!webhookAuthorization) {
      throw new HttpError(
        503,
        "service_unavailable",
        "RevenueCat webhook authorization is not configured.",
      );
    }

    const desiredConfiguration = {
      name: "Kumusta Supabase production",
      url: webhookURL,
      authorization_header: webhookAuthorization,
      environment: "production",
      event_types: null,
      app_id: null,
    };

    const configured = candidate?.id
      ? await revenueCatRequest(
        `/projects/${
          encodeURIComponent(requiredEnv("REVENUECAT_PROJECT_ID"))
        }/integrations/webhooks/${encodeURIComponent(candidate.id)}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(desiredConfiguration),
        },
      )
      : await revenueCatRequest(
        `/projects/${
          encodeURIComponent(requiredEnv("REVENUECAT_PROJECT_ID"))
        }/integrations/webhooks`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(desiredConfiguration),
        },
      );

    return jsonResponse(200, {
      action: candidate?.id ? "updated" : "created",
      integration: sanitizeIntegration(configured),
    }, id);
  } catch (error) {
    return errorResponse(error, id);
  }
});

async function retryFailedWebhookEvents(): Promise<{
  event_id: string;
  status: number | null;
}[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("kumusta_revenuecat_events")
    .select("event_id,payload")
    .eq("environment", "PRODUCTION")
    .is("processed_at", null)
    .not("processing_error", "is", null)
    .order("received_at", { ascending: true })
    .limit(20);
  if (error) {
    throw new HttpError(503, "webhook_storage_unavailable", "Please retry.");
  }

  const webhookAuthorization = Deno.env.get(
    "REVENUECAT_WEBHOOK_AUTHORIZATION",
  )?.trim() || Deno.env.get("REVENUECAT_WEBHOOK_AUTH")?.trim();
  if (!webhookAuthorization) {
    throw new HttpError(
      503,
      "service_unavailable",
      "RevenueCat webhook authorization is not configured.",
    );
  }

  const rows = (data ?? []).filter((row) =>
    typeof row.event_id === "string" && isPlainObject(row.payload)
  );
  const results: { event_id: string; status: number | null }[] = [];
  for (let offset = 0; offset < rows.length; offset += 4) {
    const batch = rows.slice(offset, offset + 4);
    const batchResults = await Promise.all(batch.map(async (row) => {
      let status: number | null = null;
      try {
        const response = await fetchWithTimeout(
          webhookURL,
          {
            method: "POST",
            headers: {
              Authorization: webhookAuthorization,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ api_version: "1.0", event: row.payload }),
          },
          10_000,
        );
        status = response.status;
      } catch {
        status = null;
      }
      return { event_id: row.event_id, status };
    }));
    results.push(...batchResults);
  }
  return results;
}

interface WebhookIntegration {
  id?: string;
  name?: string;
  url?: string;
  environment?: string | null;
  event_types?: string[] | null;
  app_id?: string | null;
}

async function listWebhookIntegrations(): Promise<WebhookIntegration[]> {
  const projectID = requiredEnv("REVENUECAT_PROJECT_ID");
  const response = await revenueCatRequest(
    `/projects/${encodeURIComponent(projectID)}/integrations/webhooks?limit=100`,
  );
  if (!isPlainObject(response) || !Array.isArray(response.items)) {
    throw new HttpError(502, "revenuecat_response_invalid", "Invalid response.");
  }
  return response.items.filter(isPlainObject) as WebhookIntegration[];
}

async function revenueCatRequest(
  path: string,
  init: RequestInit = {},
): Promise<unknown> {
  const secret = requiredEnv("REVENUECAT_SECRET_API_KEY");
  let response: Response;
  try {
    response = await fetchWithTimeout(
      `${revenueCatAPIBase}${path}`,
      {
        ...init,
        headers: {
          Authorization: `Bearer ${secret}`,
          Accept: "application/json",
          ...(init.headers ?? {}),
        },
      },
      10_000,
    );
  } catch {
    throw new HttpError(503, "revenuecat_unavailable", "Please retry.");
  }
  if (!response.ok) {
    console.error("revenuecat_admin_request_failed", { status: response.status });
    throw new HttpError(
      response.status === 401 || response.status === 403 ? 503 : 502,
      "revenuecat_admin_request_failed",
      `RevenueCat API returned ${response.status}.`,
    );
  }
  try {
    return await response.json();
  } catch {
    throw new HttpError(502, "revenuecat_response_invalid", "Invalid response.");
  }
}

function sanitizeIntegration(
  value: unknown,
): Record<string, unknown> {
  if (!isPlainObject(value)) return {};
  return {
    id: typeof value.id === "string" ? value.id : null,
    name: typeof value.name === "string" ? value.name : null,
    url: typeof value.url === "string" ? value.url : null,
    environment: typeof value.environment === "string" ? value.environment : null,
    event_types: Array.isArray(value.event_types) ? value.event_types : null,
    app_id: typeof value.app_id === "string" ? value.app_id : null,
  };
}
