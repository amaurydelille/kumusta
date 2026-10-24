# ADR 0001: Native SwiftUI

Status: accepted

## Context

The product is iOS-first, depends on precise audio behavior, rich native
accessibility, StoreKit subscriptions, and polished motion. There is no current
requirement for Android parity.

## Decision

Build with SwiftUI on iOS 17+, Swift 6, and Observation. Use native APIs for
navigation, accessibility, audio, storage, and system integration.

## Consequences

The team gains direct access to current Apple platform behavior and a smaller
runtime surface. Android would require a separate client or a later strategic
rewrite; this is accepted until iOS product-market fit is established.
