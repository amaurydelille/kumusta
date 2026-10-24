# ADR 0004: Custom hard paywall with RevenueCat

Status: accepted

## Context

The product needs a distinctive conversion flow tied to the learning demo while
retaining reliable StoreKit state and server-side lifecycle events.

## Decision

Use a custom SwiftUI paywall over an internal purchase protocol backed by
RevenueCat. The initial free-user route has no close action, but always exposes
restore, legal links, plan choice, retry, and recovery.

## Consequences

The app controls design and accessibility while RevenueCat owns StoreKit
wrapping and entitlement lifecycle. Every price/trial claim must come from the
current product metadata; paywall UI tests must cover every explicit state.
