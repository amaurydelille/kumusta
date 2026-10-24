import Foundation
import RevenueCat

actor RevenueCatPurchaseService: PurchaseService {
    private let configuration: AppConfiguration
    private let analytics: any AnalyticsTracking
    private var packageLookup: [String: Package] = [:]
    private var isConfigured = false
    private var configuredAppUserID: String?
    private var isAdServicesAttributionEnabled = false

    init(configuration: AppConfiguration, analytics: any AnalyticsTracking) {
        self.configuration = configuration
        self.analytics = analytics

        // RevenueCat must be ready before the paywall is presented. The
        // Supabase identity is attached below when it is available, but a
        // temporary auth/network failure must not prevent RevenueCatUI from
        // loading the dashboard paywall (or its exit offer).
        if configuration.hasRevenueCatConfiguration {
            if !Purchases.isConfigured {
                Purchases.configure(withAPIKey: configuration.revenueCatPublicKey)
                Self.pinPaywallLanguage()
            }
            isConfigured = Purchases.isConfigured
        }
    }

    /// The app ships in English only, so dashboard paywalls never follow a
    /// non-English device language.
    private nonisolated static func pinPaywallLanguage() {
        Purchases.shared.overridePreferredUILocale("en_US")
    }

    func configure(appUserID: String) async throws {
        guard configuration.hasRevenueCatConfiguration else { return }
        guard !appUserID.isEmpty else {
            throw PurchaseServiceError.misconfigured
        }

        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: configuration.revenueCatPublicKey)
            Self.pinPaywallLanguage()
        }
        isConfigured = Purchases.isConfigured

        if !isConfigured {
            throw PurchaseServiceError.misconfigured
        }

        if configuredAppUserID != appUserID {
            _ = try await Purchases.shared.logIn(appUserID)
            configuredAppUserID = appUserID

            // Subscription events that happen while the app is closed
            // (renewals, trial conversions, refunds, billing issues) are only
            // seen by RevenueCat. Its AppsFlyer and Meta integrations forward
            // them, but only for customers carrying the matching network ID.
            // AppsFlyer then relays them to TikTok via postbacks, which is the
            // only route to TikTok for off-device revenue.
            if let appsFlyerID = await AppsFlyerAppEvents.appsFlyerID {
                Purchases.shared.attribution.setAppsflyerID(appsFlyerID)
            }
            if let fbAnonymousID = await MetaAppEvents.anonymousID {
                Purchases.shared.attribution.setFBAnonymousID(fbAnonymousID)
            }
            Purchases.shared.attribution.collectDeviceIdentifiers()
        }

        if !isAdServicesAttributionEnabled {
            // Associate Apple Ads attribution with the stable Supabase user
            // rather than the temporary RevenueCat anonymous user.
            Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()
            isAdServicesAttributionEnabled = true
        }
    }

    /// Re-reads IDFA/IDFV/IP after the ATT prompt resolves. RevenueCat's
    /// docs ask for a second collection once tracking is granted so `$idfa`
    /// is populated for its attribution integrations.
    nonisolated static func refreshDeviceIdentifiersForAttribution() {
        guard Purchases.isConfigured else { return }
        Purchases.shared.attribution.collectDeviceIdentifiers()
    }

    func isConfigured() async -> Bool {
        isConfigured && Purchases.isConfigured
    }

    func hasPremiumAccess() async -> Bool {
        guard isConfigured else {
            #if DEBUG
            return false
            #else
            return false
            #endif
        }
        do {
            let info = try await Purchases.shared.customerInfo()
            return info.entitlements[configuration.entitlementID]?.isActive == true
        } catch {
            return Purchases.shared.cachedCustomerInfo?.entitlements[configuration.entitlementID]?.isActive == true
        }
    }

    func loadOffering() async throws -> PaywallOffering {
        guard isConfigured else {
            #if DEBUG
            return try await PreviewPurchaseService().loadOffering()
            #else
            throw PurchaseServiceError.misconfigured
            #endif
        }

        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else {
            throw PurchaseServiceError.unavailable
        }

        let eligibilityByProductID = await Purchases.shared
            .checkTrialOrIntroDiscountEligibility(
                productIdentifiers: current.availablePackages.map {
                    $0.storeProduct.productIdentifier
                }
            )
        packageLookup = Dictionary(uniqueKeysWithValues: current.availablePackages.map { ($0.identifier, $0) })
        let packages = current.availablePackages.map { package in
            let productID = package.storeProduct.productIdentifier
            let isIntroEligible = eligibilityByProductID[productID]?.status.isEligible == true
            return PaywallPackage(
                id: package.identifier,
                title: package.storeProduct.localizedTitle,
                price: package.storeProduct.localizedPriceString,
                period: Self.periodLabel(for: package),
                introductoryOffer: isIntroEligible
                    ? Self.introductoryOfferLabel(package.storeProduct.introductoryDiscount)
                    : nil,
                savingsText: package.packageType == .annual ? L("Best value") : nil
            )
        }
        return PaywallOffering(id: current.identifier, packages: packages)
    }

    func purchase(packageID: String) async throws -> PurchaseOutcome {
        guard let package = packageLookup[packageID] else {
            throw PurchaseServiceError.unavailable
        }
        analytics.track(.purchaseStarted, properties: ["package_id": packageID, "source": "custom_paywall"])
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                analytics.track(.purchaseCancelled, properties: ["package_id": packageID, "source": "custom_paywall"])
                return .cancelled
            }
            guard let entitlement = result.customerInfo.entitlements[configuration.entitlementID],
                  entitlement.isActive
            else {
                throw PurchaseServiceError.verificationFailed
            }
            analytics.track(.purchaseCompleted, properties: ["package_id": packageID, "source": "custom_paywall"])
            if entitlement.periodType == .trial {
                analytics.track(.trialStarted, properties: ["package_id": packageID, "source": "custom_paywall"])
            }
            await Self.recordForAdAttribution(entitlement: entitlement, product: package.storeProduct)
            return .unlocked
        } catch let error as RevenueCat.ErrorCode where error == .paymentPendingError {
            return .pending
        } catch {
            analytics.track(.purchaseFailed, properties: ["category": "sdk_error"])
            throw PurchaseServiceError.underlying(L("The App Store couldn’t complete that purchase. Please try again."))
        }
    }

    /// RevenueCatUI completes purchases internally, so the normal purchase
    /// service path is bypassed. Recover the product from CustomerInfo and
    /// StoreKit-backed RevenueCat products so AppsFlyer and TikTok receive
    /// the same events for hosted and custom paywalls. PostHog receives
    /// `purchase_completed` here too.
    func recordHostedPurchaseForAttribution() async -> String? {
        guard isConfigured,
              let customerInfo = try? await Purchases.shared.customerInfo(),
              let entitlement = customerInfo.entitlements[configuration.entitlementID],
              entitlement.isActive
        else {
            return nil
        }

        let productID = entitlement.productIdentifier
        analytics.track(
            .purchaseCompleted,
            properties: ["package_id": productID, "source": "hosted_paywall"]
        )
        if entitlement.periodType == .trial {
            analytics.track(.trialStarted, properties: ["package_id": productID, "source": "hosted_paywall"])
        }
        let product = await Purchases.shared.products([productID]).first
        await Self.recordForAdAttribution(entitlement: entitlement, product: product)
        return productID
    }

    /// Single place that decides what the ad networks learn about a
    /// transaction. A free trial is a trial, not a purchase. An intro offer is
    /// charged at the intro price, not the regular one.
    private static func recordForAdAttribution(
        entitlement: EntitlementInfo,
        product: StoreProduct?
    ) async {
        let productID = entitlement.productIdentifier
        switch entitlement.periodType {
        case .trial:
            await AppsFlyerAppEvents.trackTrialStarted(productID: productID)
            TikTokAppEvents.trackTrialStarted(productID: productID)
        case .intro, .normal, .prepaid:
            guard let product else { return }
            let price = entitlement.periodType == .intro
                ? product.introductoryDiscount?.price ?? product.price
                : product.price
            let currencyCode = product.currencyCode
            await AppsFlyerAppEvents.trackPurchase(
                productID: productID,
                revenue: price,
                currencyCode: currencyCode
            )
            TikTokAppEvents.trackPurchase(
                productID: productID,
                price: price,
                currencyCode: currencyCode
            )
        @unknown default:
            return
        }
    }

    func restore() async throws -> Bool {
        try await restore(source: "user_initiated")
    }

    func restore(source: String) async throws -> Bool {
        guard isConfigured else {
            #if DEBUG
            return true
            #else
            throw PurchaseServiceError.misconfigured
            #endif
        }
        analytics.track(.restoreStarted, properties: ["source": source])
        do {
            let info = try await Purchases.shared.restorePurchases()
            let unlocked = info.entitlements[configuration.entitlementID]?.isActive == true
            analytics.track(.restoreCompleted, properties: ["entitlement_found": String(unlocked), "source": source])
            return unlocked
        } catch {
            analytics.track(.restoreFailed, properties: ["source": source, "error_category": "sdk_error"])
            throw error
        }
    }

    private static func periodLabel(for package: Package) -> String {
        switch package.packageType {
        case .annual: L("per year")
        case .monthly: L("per month")
        case .weekly: L("per week")
        case .sixMonth: L("every 6 months")
        case .threeMonth: L("every 3 months")
        case .twoMonth: L("every 2 months")
        default: ""
        }
    }

    private static func introductoryOfferLabel(_ discount: StoreProductDiscount?) -> String? {
        guard let discount else { return nil }
        let count = discount.subscriptionPeriod.value * max(1, discount.numberOfPeriods)
        let duration: String = switch discount.subscriptionPeriod.unit {
        case .day: L(one: "%lld day", other: "%lld days", count: count)
        case .week: L(one: "%lld week", other: "%lld weeks", count: count)
        case .month: L(one: "%lld month", other: "%lld months", count: count)
        case .year: L(one: "%lld year", other: "%lld years", count: count)
        @unknown default: L(one: "%lld period", other: "%lld periods", count: count)
        }

        return switch discount.paymentMode {
        case .freeTrial: L("%@ free", duration)
        case .payAsYouGo: L("%@ for %@", discount.localizedPriceString, duration)
        case .payUpFront: L("%@ for %@", discount.localizedPriceString, duration)
        }
    }
}
