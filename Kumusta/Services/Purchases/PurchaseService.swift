import Foundation

struct PaywallPackage: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let price: String
    let period: String
    let introductoryOffer: String?
    let savingsText: String?
}

struct PaywallOffering: Equatable, Sendable {
    let id: String
    let packages: [PaywallPackage]
}

enum PurchaseOutcome: Equatable, Sendable {
    case unlocked
    case cancelled
    case pending
}

enum PurchaseServiceError: LocalizedError {
    case unavailable
    case misconfigured
    case verificationFailed
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: L("The App Store plans aren’t available right now.")
        case .misconfigured: L("Purchases haven’t been configured for this build.")
        case .verificationFailed: L("The purchase finished, but access could not be verified.")
        case let .underlying(message): message
        }
    }
}

protocol PurchaseService: Sendable {
    func configure(appUserID: String) async throws
    /// Detaches the signed-out account so the next learner's purchase can't
    /// land on it.
    func logOut() async
    func isConfigured() async -> Bool
    func hasPremiumAccess() async -> Bool
    func loadOffering() async throws -> PaywallOffering
    func purchase(packageID: String) async throws -> PurchaseOutcome
    func recordHostedPurchaseForAttribution() async -> String?
    func restore() async throws -> Bool
    func restore(source: String) async throws -> Bool
}

extension PurchaseService {
    func restore(source: String) async throws -> Bool { try await restore() }
}

actor PreviewPurchaseService: PurchaseService {
    private var unlocked = false

    func configure(appUserID: String) async throws {}

    func logOut() async { unlocked = false }

    func isConfigured() async -> Bool { true }

    func hasPremiumAccess() async -> Bool { unlocked }

    func loadOffering() async throws -> PaywallOffering {
        PaywallOffering(
            id: "preview_onboarding",
            packages: [
                PaywallPackage(
                    id: "annual",
                    title: "Annual",
                    price: "$49.99",
                    period: "per year",
                    introductoryOffer: "7 days free",
                    savingsText: "Best value"
                ),
                PaywallPackage(
                    id: "monthly",
                    title: "Monthly",
                    price: "$9.99",
                    period: "per month",
                    introductoryOffer: nil,
                    savingsText: nil
                )
            ]
        )
    }

    func purchase(packageID: String) async throws -> PurchaseOutcome {
        unlocked = true
        return .unlocked
    }

    func recordHostedPurchaseForAttribution() async -> String? { nil }

    func restore() async throws -> Bool { unlocked }
}
