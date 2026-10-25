import SwiftUI
import RevenueCat
import RevenueCatUI

/// Displays a paywall authored in the RevenueCat dashboard. Purchase and
/// restore stay owned by RevenueCatUI; closing it is the app's, so the learner
/// always gets the exit screen.
struct RevenueCatHostedPaywallView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var routingGate = HostedPaywallRoutingGate()
    @State private var sdkState: SDKState = .loading
    @State private var hasTrackedView = false
    @State private var offering: Offering?

    private enum SDKState {
        case loading
        case ready
        case unavailable
    }

    let offeringIdentifier: String?
    let onPremiumAccess: () async -> Void
    let onSubscriptionPurchased: () async -> Void
    let onDismissed: () -> Void

    init(
        offeringIdentifier: String? = nil,
        onPremiumAccess: @escaping () async -> Void,
        onSubscriptionPurchased: @escaping () async -> Void = {},
        onDismissed: @escaping () -> Void
    ) {
        self.offeringIdentifier = offeringIdentifier
        self.onPremiumAccess = onPremiumAccess
        self.onSubscriptionPurchased = onSubscriptionPurchased
        self.onDismissed = onDismissed
    }

    var body: some View {
        Group {
            if !dependencies.configuration.hasRevenueCatConfiguration {
                PaywallConfigurationView(
                    title: L("RevenueCat isn’t configured"),
                    message: L("This build is missing the RevenueCat public SDK key.")
                )
            } else if sdkState == .ready, offeringIdentifier == nil || offering != nil {
                // Embedded rather than presented, so the app's own close
                // button sits above every dashboard design.
                hostedPaywall
                    .onPurchaseStarted { package in
                        dependencies.analytics.track(.purchaseStarted, properties: ["package_id": package.identifier, "source": "hosted_paywall"])
                    }
                    .onPurchaseCompleted { _ in
                        // Claim the route synchronously so a dismissal request
                        // cannot open the exit screen before the async account
                        // transition runs.
                        guard routingGate.beginPremiumAccess() else { return }
                        Task {
                            _ = await dependencies.purchaseService
                                .recordHostedPurchaseForAttribution()
                            await onPremiumAccess()
                            await onSubscriptionPurchased()
                        }
                    }
                    .onPurchaseCancelled {
                        dependencies.analytics.track(.purchaseCancelled, properties: ["source": "hosted_paywall"])
                    }
                    .onRestoreStarted {
                        dependencies.analytics.track(.restoreStarted, properties: ["source": "hosted_paywall"])
                    }
                    .onRestoreCompleted { customerInfo in
                        let active = customerInfo.entitlements[dependencies.configuration.entitlementID]?.isActive == true
                        dependencies.analytics.track(.restoreCompleted, properties: ["entitlement_found": String(active), "source": "hosted_paywall"])
                        guard active else { return }
                        guard routingGate.beginPremiumAccess() else { return }
                        Task { await onPremiumAccess() }
                    }
                    .onPurchaseFailure { _ in
                        dependencies.analytics.track(.purchaseFailed, properties: ["error_category": "sdk_error", "source": "hosted_paywall"])
                    }
                    .onRestoreFailure { _ in
                        dependencies.analytics.track(.restoreFailed, properties: ["error_category": "sdk_error", "source": "hosted_paywall"])
                    }
                    // A close button placed in the dashboard design routes the same way.
                    .onRequestedDismissal(dismiss)
                    .overlay(alignment: .topTrailing) {
                        closeButton
                    }
            } else if sdkState == .loading {
                ProgressView(L("Loading subscription plans…"))
                    .tint(KumustaColors.accent)
            } else {
                PaywallConfigurationView(
                    title: L("Subscription plans unavailable"),
                    message: L("Kumusta could not initialize the App Store subscription service. Please try again later.")
                )
            }
        }
        .task {
            guard dependencies.configuration.hasRevenueCatConfiguration else { return }
            guard await dependencies.purchaseService.isConfigured() else {
                sdkState = .unavailable
                return
            }

            if let offeringIdentifier {
                guard let offering = await loadOffering(identifier: offeringIdentifier) else {
                    sdkState = .unavailable
                    return
                }
                self.offering = offering
            }

            sdkState = .ready
            if !hasTrackedView {
                hasTrackedView = true
                dependencies.analytics.track(
                    .paywallViewed,
                    properties: ["offering": offeringIdentifier ?? "default", "screen_name": "paywall"]
                )
                TikTokAppEvents.trackPaywallViewed()
                AppsFlyerAppEvents.trackPaywallViewed()
                MetaAppEvents.trackPaywallViewed()
            }

        }
    }

    @ViewBuilder
    private var hostedPaywall: some View {
        if let offering {
            PaywallView(offering: offering)
        } else {
            PaywallView()
        }
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .scaledFont(14, weight: .bold)
                .foregroundStyle(KumustaColors.ink)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
        .padding(.top, 2)
        .accessibilityLabel(L("Close"))
        .accessibilityIdentifier("paywall-close")
    }

    private func dismiss() {
        guard routingGate.shouldRouteDismissal else { return }
        dependencies.analytics.track(.paywallDismissed, properties: ["offering": offeringIdentifier ?? "default", "screen_name": "paywall"])
        onDismissed()
    }

    private func loadOffering(identifier: String) async -> Offering? {
        if let cachedOfferings = Purchases.shared.cachedOfferings,
           let cachedOffering = offering(identifier: identifier, in: cachedOfferings) {
            return cachedOffering
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            return offering(identifier: identifier, in: offerings)
        } catch {
            return nil
        }
    }

    private func offering(identifier: String, in offerings: Offerings) -> Offering? {
        offerings.offering(identifier: identifier)
            ?? offerings.all.first {
                $0.key.caseInsensitiveCompare(identifier) == .orderedSame
            }?.value
    }

}

/// Coordinates RevenueCat's synchronous dismissal callback with the app's
/// asynchronous post-purchase route. The first successful purchase or restore
/// permanently owns the route for this paywall instance.
struct HostedPaywallRoutingGate {
    private(set) var isCompletingPremiumAccess = false

    mutating func beginPremiumAccess() -> Bool {
        guard !isCompletingPremiumAccess else { return false }
        isCompletingPremiumAccess = true
        return true
    }

    var shouldRouteDismissal: Bool {
        !isCompletingPremiumAccess
    }
}

private struct PaywallConfigurationView: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            PaperBackground()
            ContentUnavailableView(
                title,
                systemImage: "creditcard.trianglebadge.exclamationmark",
                description: Text(message)
            )
            .padding(24)
        }
    }
}
