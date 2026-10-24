/// <reference lib="deno.ns" />

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

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("RevenueCat identity maps only a UUID alias", () => {
  const event = parseRevenueCatEvent({
    event: {
      id: "event-1",
      type: "INITIAL_PURCHASE",
      app_user_id: "$RCAnonymousID:123",
      aliases: ["11111111-1111-4111-8111-111111111111"],
    },
  });
  assert(
    mappedSupabaseUserID(event) === "11111111-1111-4111-8111-111111111111",
    "Supabase UUID was not found",
  );
});

Deno.test("RevenueCat customer lookup tries each unique event identity", () => {
  const event = parseRevenueCatEvent({
    event: {
      id: "event-identities",
      type: "CANCELLATION",
      app_user_id: "$RCAnonymousID:anonymous",
      original_app_user_id: "11111111-1111-4111-8111-111111111111",
      aliases: [
        "$RCAnonymousID:anonymous",
        "11111111-1111-4111-8111-111111111111",
        "customer-alias",
      ],
    },
  });
  assert(
    revenueCatCustomerIDs(event).join(",") ===
      "$RCAnonymousID:anonymous,11111111-1111-4111-8111-111111111111,customer-alias",
    "RevenueCat customer identities were not deduplicated in priority order",
  );
});

Deno.test("RevenueCat audit payload drops subscriber attributes", () => {
  const event = parseRevenueCatEvent({
    event: {
      id: "event-2",
      type: "RENEWAL",
      app_user_id: "11111111-1111-4111-8111-111111111111",
      subscriber_attributes: { email: { value: "private@example.com" } },
    },
  });
  assert(
    !("subscriber_attributes" in sanitizedAuditPayload(event)),
    "Subscriber attributes must not be stored",
  );
});

Deno.test("RevenueCat v2 customer resources map to the app entitlement key", () => {
  const customer = mapRevenueCatV2CustomerInfo(
    {
      items: [{ entitlement_id: "entl-premium", expires_at: 1_800_000_000_000 }],
    },
    {
      items: [{
        product_id: "kumusta_monthly",
        starts_at: 1_797_408_000_000,
        current_period_ends_at: 1_800_000_000_000,
        gives_access: true,
        auto_renewal_status: "will_renew",
        entitlements: {
          items: [{ id: "entl-premium", lookup_key: "premium" }],
        },
      }],
    },
  );
  assert(
    customer.entitlements.premium?.product_identifier === "kumusta_monthly",
    "The RevenueCat lookup key was not mapped to the app entitlement",
  );
  assert(
    customer.entitlements.premium?.expires_date ===
      "2027-01-15T08:00:00.000Z",
    "The v2 millisecond expiry was not converted to ISO",
  );
  assert(
    customer.subscriptions.kumusta_monthly?.unsubscribe_detected_at === null,
    "A renewing subscription was marked as cancelled",
  );
});

Deno.test("RevenueCat v2 customer mapping fails closed on unknown entitlements", () => {
  let rejected = false;
  try {
    mapRevenueCatV2CustomerInfo(
      { items: [{ entitlement_id: "entl-unknown", expires_at: null }] },
      { items: [] },
    );
  } catch {
    rejected = true;
  }
  assert(rejected, "An unmapped active entitlement must not be mirrored");
});

Deno.test("Transactional email types only trigger for production lifecycle events", () => {
  const baseEvent = {
    id: "event-email",
    app_user_id: "11111111-1111-4111-8111-111111111111",
    environment: "PRODUCTION",
  };
  assert(
    transactionalEmailType(parseRevenueCatEvent({
      event: { ...baseEvent, type: "INITIAL_PURCHASE" },
    })) === "subscription_welcome",
    "Initial purchase should enqueue a welcome email",
  );
  assert(
    transactionalEmailType(parseRevenueCatEvent({
      event: { ...baseEvent, type: "CANCELLATION", cancel_reason: "UNSUBSCRIBE" },
    })) === "subscription_cancellation_feedback",
    "Voluntary cancellation should enqueue feedback email",
  );
  assert(
    transactionalEmailType(parseRevenueCatEvent({
      event: { ...baseEvent, type: "CANCELLATION", cancel_reason: "CUSTOMER_SUPPORT" },
    })) === "subscription_refund",
    "Customer-support cancellation should enqueue refund email",
  );
  assert(
    transactionalEmailType(parseRevenueCatEvent({
      event: { ...baseEvent, type: "CANCELLATION", cancel_reason: "BILLING_ERROR" },
    })) === null,
    "Billing errors should not enqueue cancellation feedback",
  );
  assert(
    transactionalEmailType(parseRevenueCatEvent({
      event: { ...baseEvent, type: "INITIAL_PURCHASE", environment: "SANDBOX" },
    })) === null,
    "Sandbox events must not send customer email",
  );
  assert(
    transactionalEmailType(parseRevenueCatEvent({
      event: { ...baseEvent, type: "TEST" },
    })) === null,
    "Dashboard test events must not send customer email",
  );
});

Deno.test("Complete production unsubscribe event provides a safe entitlement snapshot", () => {
  const event = parseRevenueCatEvent({
    event: {
      id: "event-snapshot",
      type: "CANCELLATION",
      app_user_id: "11111111-1111-4111-8111-111111111111",
      environment: "PRODUCTION",
      cancel_reason: "UNSUBSCRIBE",
      product_id: "kumusta_monthly",
      entitlement_ids: ["premium", "premium"],
      purchased_at_ms: 1_797_408_000_000,
      expiration_at_ms: 1_800_000_000_000,
    },
  });
  const snapshot = voluntaryCancellationSnapshot(event);
  assert(snapshot?.length === 1, "Snapshot should deduplicate entitlement IDs");
  assert(
    snapshot[0].entitlement_id === "premium" &&
      snapshot[0].product_id === "kumusta_monthly" &&
      snapshot[0].expires_at === "2027-01-15T08:00:00.000Z" &&
      snapshot[0].purchased_at === "2026-12-16T08:00:00.000Z",
    "Snapshot fields were not mapped correctly",
  );
});

Deno.test("Incomplete and refunded events cannot use the cancellation snapshot fallback", () => {
  const baseEvent = {
    id: "event-snapshot-unsafe",
    type: "CANCELLATION",
    app_user_id: "11111111-1111-4111-8111-111111111111",
    environment: "PRODUCTION",
    cancel_reason: "UNSUBSCRIBE",
    product_id: "kumusta_monthly",
    entitlement_ids: ["premium"],
    expiration_at_ms: 1_800_000_000_000,
  };
  assert(
    voluntaryCancellationSnapshot(parseRevenueCatEvent({
      event: { ...baseEvent, cancel_reason: "CUSTOMER_SUPPORT" },
    })) === null,
    "Refund events must not use the unsubscribe fallback",
  );
  assert(
    voluntaryCancellationSnapshot(parseRevenueCatEvent({
      event: { ...baseEvent, entitlement_ids: [] },
    })) === null,
    "Events without entitlement IDs must fail closed",
  );
});

Deno.test("RevenueCat HMAC validates exact raw body", async () => {
  const body = '{"event":{"id":"1"}}';
  const secret = "test-signing-secret";
  const timestamp = 1_800_000_000;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const rawSignature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${body}`),
  );
  const signature = Array.from(new Uint8Array(rawSignature))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
  assert(
    await verifyRevenueCatHMAC(
      body,
      `t=${timestamp},v1=${signature}`,
      secret,
      timestamp,
    ),
    "Valid HMAC was rejected",
  );
  assert(
    !await verifyRevenueCatHMAC(
      `${body} `,
      `t=${timestamp},v1=${signature}`,
      secret,
      timestamp,
    ),
    "Modified payload was accepted",
  );
});
