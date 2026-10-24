export const APP_STORE_URL =
  "https://apps.apple.com/us/app/vietbuddy-learn-vietnamese/id6796837982";

// Click tracking is configured through the runtime env only; without it the
// redirect still works and tracking is skipped.
const DEFAULT_SUPABASE_URL = "";
const DEFAULT_SUPABASE_PUBLISHABLE_KEY = "";

const CAMPAIGN_PATTERN = /^[a-z0-9_-]{1,80}$/;

type RedirectEnvironment = {
  SUPABASE_URL?: string;
  SUPABASE_PUBLISHABLE_KEY?: string;
  NEXT_PUBLIC_SUPABASE_URL?: string;
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?: string;
};

type WaitUntilContext = {
  waitUntil(promise: Promise<unknown>): void;
};

function truncate(value: string | null, maxLength: number) {
  if (!value) return null;
  return value.slice(0, maxLength);
}

function getQueryParams(url: URL) {
  const queryParams: Record<string, string | string[]> = {};

  for (const [key, value] of url.searchParams) {
    if (Object.keys(queryParams).length >= 30) break;

    const safeKey = truncate(key, 120);
    if (!safeKey) continue;

    const safeValue = value.slice(0, 1000);
    const previousValue = queryParams[safeKey];

    if (previousValue === undefined) {
      queryParams[safeKey] = safeValue;
    } else if (Array.isArray(previousValue)) {
      previousValue.push(safeValue);
    } else {
      queryParams[safeKey] = [previousValue, safeValue];
    }
  }

  return queryParams;
}

function getCampaign(url: URL) {
  const rawCampaign = url.searchParams.get("from")?.trim().toLowerCase();
  if (!rawCampaign) return null;

  // Keep malformed values attributable without violating the table's campaign check.
  return CAMPAIGN_PATTERN.test(rawCampaign) ? rawCampaign : "unattributed";
}

function getCountryCode(request: Request) {
  const country = request.headers.get("cf-ipcountry")?.trim().toUpperCase();
  return country && /^[A-Z]{2}$/.test(country) ? country : null;
}

function getHeader(request: Request, name: string, maxLength: number) {
  return truncate(request.headers.get(name), maxLength);
}

async function recordClick(
  request: Request,
  url: URL,
  campaign: string,
  environment: RedirectEnvironment,
) {
  const supabaseUrl = (
    environment.SUPABASE_URL ??
    environment.NEXT_PUBLIC_SUPABASE_URL ??
    DEFAULT_SUPABASE_URL
  ).trim().replace(/\/$/, "");
  const publishableKey = (
    environment.SUPABASE_PUBLISHABLE_KEY ??
    environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
    DEFAULT_SUPABASE_PUBLISHABLE_KEY
  ).trim();

  if (!supabaseUrl || !publishableKey) {
    console.warn("App Store redirect tracking is not configured.");
    return;
  }

  const payload = {
    campaign,
    requested_url: truncate(url.toString(), 2000) ?? url.origin,
    app_store_url: APP_STORE_URL,
    request_method: truncate(request.method, 16) ?? "GET",
    user_agent: getHeader(request, "user-agent", 1000),
    referer: getHeader(request, "referer", 2000),
    accept_language: getHeader(request, "accept-language", 300),
    country_code: getCountryCode(request),
    region_code: getHeader(request, "cf-region", 120),
    city: getHeader(request, "cf-ipcity", 120),
    source_host: truncate(url.hostname, 255),
    source_path: url.pathname,
    query_params: getQueryParams(url),
  };

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/app_store_redirect_clicks`, {
      method: "POST",
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${publishableKey}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      console.warn(`App Store redirect tracking failed with status ${response.status}.`);
    }
  } catch (error) {
    console.warn("App Store redirect tracking request failed.", error);
  }
}

export function redirectCampaignClick(
  request: Request,
  environment: RedirectEnvironment,
  context: WaitUntilContext,
) {
  const url = new URL(request.url);
  if (url.pathname !== "/") return null;

  const campaign = getCampaign(url);
  if (!campaign) return null;

  context.waitUntil(recordClick(request, url, campaign, environment));
  return Response.redirect(APP_STORE_URL, 302);
}
