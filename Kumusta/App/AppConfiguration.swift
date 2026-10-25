import Foundation

struct AppConfiguration: Sendable {
    let supabaseURL: URL?
    let supabasePublishableKey: String
    let revenueCatPublicKey: String
    let entitlementID: String

    init(bundle: Bundle) {
        supabaseURL = (bundle.object(forInfoDictionaryKey: "SUPABASE_PROJECT_URL") as? String).flatMap(URL.init)
        supabasePublishableKey = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
        revenueCatPublicKey = bundle.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_SDK_KEY") as? String ?? ""
        entitlementID = bundle.object(forInfoDictionaryKey: "KUMUSTA_ENTITLEMENT_ID") as? String ?? "premium"
    }

    init(
        supabaseURL: URL?,
        supabasePublishableKey: String,
        revenueCatPublicKey: String,
        entitlementID: String
    ) {
        self.supabaseURL = supabaseURL
        self.supabasePublishableKey = supabasePublishableKey
        self.revenueCatPublicKey = revenueCatPublicKey
        self.entitlementID = entitlementID
    }

    static let preview = AppConfiguration(
        supabaseURL: URL(string: "https://example.supabase.co"),
        supabasePublishableKey: "",
        revenueCatPublicKey: "",
        entitlementID: "premium"
    )

    var hasSupabaseConfiguration: Bool {
        supabaseURL != nil && !supabasePublishableKey.isEmpty
    }

    var hasRevenueCatConfiguration: Bool {
        #if DEBUG
        !revenueCatPublicKey.isEmpty
        #else
        // A RevenueCat Test Store key fakes every purchase; it must never
        // configure a Release build.
        !revenueCatPublicKey.isEmpty && !revenueCatPublicKey.hasPrefix("test_")
        #endif
    }
}

/// Public pages on the Kumusta website.
enum KumustaLinks {
    private static let base = URL(string: "https://kumusta-site.vercel.app/")!
    static let privacy = base.appendingPathComponent("privacy")
    static let terms = base.appendingPathComponent("terms")
    static let support = base.appendingPathComponent("support")
}
