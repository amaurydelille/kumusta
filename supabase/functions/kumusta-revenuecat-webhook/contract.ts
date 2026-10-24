import { HttpError, isPlainObject, secureEqual } from "../_shared/http.ts";

export interface RevenueCatEvent {
  id: string;
  type: string;
  appUserID: string;
  originalAppUserID?: string;
  aliases: string[];
  environment?: "SANDBOX" | "PRODUCTION";
  raw: Record<string, unknown>;
}

export type TransactionalEmailType =
  | "subscription_welcome"
  | "subscription_cancellation_feedback"
  | "subscription_refund";

export interface CustomerEntitlement {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
  product_identifier?: string | null;
  purchase_date?: string | null;
}

export interface CustomerSubscription {
  expires_date?: string | null;
  unsubscribe_detected_at?: string | null;
}

export interface RevenueCatCustomerInfo {
  entitlements: Record<string, CustomerEntitlement>;
  subscriptions: Record<string, CustomerSubscription>;
}

export interface RevenueCatCancellationEntitlementSnapshot {
  entitlement_id: string;
  product_id: string;
  purchased_at: string | null;
  expires_at: string;
}

export function revenueCatCustomerIDs(event: RevenueCatEvent): string[] {
  const candidates = [
    event.appUserID,
    event.originalAppUserID,
    ...event.aliases,
  ];
  return [
    ...new Set(
      candidates.filter((value): value is string =>
        typeof value === "string" && value.length >= 1 && value.length <= 200
      ),
    ),
  ].slice(0, 22);
}

/** A voluntary cancellation snapshot is safe only with complete event data. */
export function voluntaryCancellationSnapshot(
  event: RevenueCatEvent,
): RevenueCatCancellationEntitlementSnapshot[] | null {
  if (
    event.type !== "CANCELLATION" || event.environment !== "PRODUCTION" ||
    event.raw.cancel_reason !== "UNSUBSCRIBE"
  ) return null;

  const productID = typeof event.raw.product_id === "string" &&
      event.raw.product_id.length >= 1 && event.raw.product_id.length <= 200
    ? event.raw.product_id
    : null;
  const expiresAt = unixMillisecondsToISO(event.raw.expiration_at_ms);
  const entitlementIDs = Array.isArray(event.raw.entitlement_ids)
    ? [
      ...new Set(event.raw.entitlement_ids.filter((value): value is string =>
        typeof value === "string" && value.length >= 1 && value.length <= 120
      )),
    ]
    : [];
  if (!productID || !expiresAt || entitlementIDs.length === 0) return null;

  const purchasedAt = unixMillisecondsToISO(event.raw.purchased_at_ms);
  return entitlementIDs.map((entitlementID) => ({
    entitlement_id: entitlementID,
    product_id: productID,
    purchased_at: purchasedAt,
    expires_at: expiresAt,
  }));
}

/** Maps RevenueCat API v2 customer resources to the shape used by the mirror. */
export function mapRevenueCatV2CustomerInfo(
  activePayload: unknown,
  subscriptionsPayload: unknown,
): RevenueCatCustomerInfo {
  if (
    !isPlainObject(activePayload) || !Array.isArray(activePayload.items) ||
    !isPlainObject(subscriptionsPayload) ||
    !Array.isArray(subscriptionsPayload.items)
  ) {
    throw new HttpError(
      503,
      "revenuecat_response_invalid",
      "Please retry.",
    );
  }

  const entitlementLookups = new Map<string, string>();
  const subscriptions: Record<string, CustomerSubscription> = {};
  const productsByEntitlement = new Map<string, {
    productID: string;
    purchaseDate?: string;
  }>();

  for (const value of subscriptionsPayload.items) {
    if (!isPlainObject(value)) continue;
    const productID = typeof value.product_id === "string" &&
        value.product_id.length <= 200
      ? value.product_id
      : null;
    if (!productID) continue;

    const periodEnd = unixMillisecondsToISO(value.current_period_ends_at);
    const willRenew = value.auto_renewal_status === "will_renew";
    subscriptions[productID] = {
      expires_date: periodEnd,
      unsubscribe_detected_at: willRenew ? null : "not_renewing",
    };

    if (value.gives_access !== true || !isPlainObject(value.entitlements)) {
      continue;
    }
    const items = value.entitlements.items;
    if (!Array.isArray(items)) continue;
    for (const entitlement of items) {
      if (!isPlainObject(entitlement)) continue;
      const id = typeof entitlement.id === "string" ? entitlement.id : null;
      const lookupKey = typeof entitlement.lookup_key === "string" &&
          entitlement.lookup_key.length >= 1 &&
          entitlement.lookup_key.length <= 120
        ? entitlement.lookup_key
        : null;
      if (!id || !lookupKey) continue;
      entitlementLookups.set(id, lookupKey);
      productsByEntitlement.set(id, {
        productID,
        purchaseDate: unixMillisecondsToISO(value.starts_at) ?? undefined,
      });
    }
  }

  const entitlements: Record<string, CustomerEntitlement> = {};
  for (const value of activePayload.items) {
    if (!isPlainObject(value)) continue;
    const id = typeof value.entitlement_id === "string" ? value.entitlement_id : null;
    if (!id) {
      throw new HttpError(
        503,
        "revenuecat_response_invalid",
        "Please retry.",
      );
    }
    const lookupKey = entitlementLookups.get(id);
    // Without the configured entitlement lookup key, we cannot safely map this
    // active v2 entitlement to the app's stable `premium` identifier.
    if (!lookupKey) {
      throw new HttpError(
        503,
        "revenuecat_response_invalid",
        "Please retry.",
      );
    }
    const expiry = unixMillisecondsToISO(value.expires_at);
    if (value.expires_at !== null && expiry === null) {
      throw new HttpError(
        503,
        "revenuecat_response_invalid",
        "Please retry.",
      );
    }
    const product = productsByEntitlement.get(id);
    entitlements[lookupKey] = {
      expires_date: expiry,
      product_identifier: product?.productID ?? null,
      purchase_date: product?.purchaseDate ?? null,
    };
  }

  return { entitlements, subscriptions };
}

function unixMillisecondsToISO(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function parseRevenueCatEvent(payload: unknown): RevenueCatEvent {
  if (!isPlainObject(payload) || !isPlainObject(payload.event)) {
    throw new HttpError(400, "invalid_webhook", "Invalid webhook payload.");
  }
  const event = payload.event;
  if (
    typeof event.id !== "string" ||
    event.id.length < 1 ||
    event.id.length > 200 ||
    typeof event.type !== "string" ||
    event.type.length < 1 ||
    event.type.length > 100 ||
    typeof event.app_user_id !== "string" ||
    event.app_user_id.length < 1 ||
    event.app_user_id.length > 200
  ) {
    throw new HttpError(400, "invalid_webhook", "Invalid webhook event.");
  }
  const aliases = Array.isArray(event.aliases)
    ? event.aliases.filter((value): value is string =>
      typeof value === "string" && value.length <= 200
    ).slice(0, 20)
    : [];
  const environment = event.environment === "SANDBOX" ||
      event.environment === "PRODUCTION"
    ? event.environment
    : undefined;
  return {
    id: event.id,
    type: event.type,
    appUserID: event.app_user_id,
    originalAppUserID: typeof event.original_app_user_id === "string"
      ? event.original_app_user_id
      : undefined,
    aliases,
    environment,
    raw: event,
  };
}

export function mappedSupabaseUserID(event: RevenueCatEvent): string | null {
  const candidates = [
    event.appUserID,
    event.originalAppUserID,
    ...event.aliases,
  ];
  for (const candidate of candidates) {
    if (candidate && isUUID(candidate)) return candidate.toLowerCase();
  }
  return null;
}

export function transactionalEmailType(
  event: RevenueCatEvent,
): TransactionalEmailType | null {
  if (event.environment !== "PRODUCTION") return null;

  if (event.type === "INITIAL_PURCHASE") return "subscription_welcome";
  if (event.type !== "CANCELLATION") return null;

  if (event.raw.cancel_reason === "UNSUBSCRIBE") {
    return "subscription_cancellation_feedback";
  }
  if (event.raw.cancel_reason === "CUSTOMER_SUPPORT") {
    return "subscription_refund";
  }
  return null;
}

export function sanitizedAuditPayload(
  event: RevenueCatEvent,
): Record<string, unknown> {
  const allowedKeys = [
    "id",
    "type",
    "app_id",
    "app_user_id",
    "original_app_user_id",
    "aliases",
    "product_id",
    "entitlement_id",
    "entitlement_ids",
    "environment",
    "cancel_reason",
    "expiration_reason",
    "event_timestamp_ms",
    "purchased_at_ms",
    "expiration_at_ms",
    "store",
    "period_type",
    "transferred_from",
    "transferred_to",
  ];
  const sanitized: Record<string, unknown> = {};
  for (const key of allowedKeys) {
    const value = event.raw[key];
    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean" ||
      value === null
    ) {
      sanitized[key] = value;
    } else if (
      Array.isArray(value) &&
      value.length <= 50 &&
      value.every((item) => typeof item === "string" && item.length <= 200)
    ) {
      sanitized[key] = value;
    }
  }
  return sanitized;
}

export async function verifyRevenueCatHMAC(
  rawBody: string,
  signatureHeader: string,
  secret: string,
  nowSeconds: number,
  toleranceSeconds = 300,
): Promise<boolean> {
  const parts: Record<string, string> = {};
  for (const part of signatureHeader.split(",")) {
    const separator = part.indexOf("=");
    if (separator > 0) {
      parts[part.slice(0, separator).trim()] = part.slice(separator + 1).trim();
    }
  }
  const timestamp = parts.t;
  const expectedSignature = parts.v1?.toLowerCase();
  if (
    !timestamp ||
    !expectedSignature ||
    !/^[0-9a-f]{64}$/.test(expectedSignature)
  ) return false;
  const timestampNumber = Number(timestamp);
  if (
    !Number.isSafeInteger(timestampNumber) ||
    Math.abs(nowSeconds - timestampNumber) > toleranceSeconds
  ) return false;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${rawBody}`),
  );
  const computed = Array.from(new Uint8Array(signature))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
  return secureEqual(computed, expectedSignature);
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
