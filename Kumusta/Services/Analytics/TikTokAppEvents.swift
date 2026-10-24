import Foundation
#if canImport(TikTokBusinessSDK)
import TikTokBusinessSDK
#endif

#if canImport(TikTokBusinessSDK)
enum TikTokAppEvents {
    private static let appIDKey = "TIKTOK_APP_ID"
    private static let businessAppIDKey = "TIKTOK_BUSINESS_APP_ID"
    private static let accessTokenKey = "TIKTOK_APP_ACCESS_TOKEN"

    static func initialize() {
        guard
            let appID = value(forKey: appIDKey),
            let businessAppID = value(forKey: businessAppIDKey),
            let accessToken = value(forKey: accessTokenKey)
        else {
            return
        }

        guard let config = TikTokConfig(
            accessToken: accessToken,
            appId: appID,
            tiktokAppId: businessAppID
        ) else {
            return
        }

        // AppsFlyer is the MMP and the single owner of SKAN conversion values.
        // Keep TikTok's direct event SDK for hybrid Events Manager reporting,
        // but prevent it from competing on SKAN or duplicating StoreKit
        // purchase events that the app sends explicitly below.
        config.disableSKAdNetworkSupport()
        config.disablePaymentTracking()

#if DEBUG
        config.enableDebugMode()
#endif
        TikTokBusiness.initializeSdk(config)
    }

    static func identify(
        externalID: UUID,
        externalUserName: String?,
        email: String?
    ) {
        TikTokBusiness.identify(
            withExternalID: externalID.uuidString.lowercased(),
            externalUserName: normalized(externalUserName),
            phoneNumber: nil,
            email: normalized(email)
        )
    }

    static func logout() {
        TikTokBusiness.logout()
    }

    static func trackLogin() {
        track(.login)
    }

    static func trackRegistration() {
        track(.registration)
    }

    static func trackCompleteTutorial() {
        track(.completeTutorial)
    }

    static func trackLessonStarted(lesson: Lesson) {
        let event = TikTokViewContentEvent(eventId: UUID().uuidString)
        event.setContentId(lesson.id.uuidString)
        event.setContentType("lesson")
        event.setDescription(lesson.analyticsScenario)
        TikTokBusiness.trackTTEvent(event)
    }

    static func trackLessonCompleted(lesson: Lesson) {
        track(
            "lesson_completed",
            properties: [
                "lesson_id": lesson.id.uuidString,
                "scenario": lesson.analyticsScenario,
                "round_count": lesson.roundCount
            ]
        )
    }

    static func trackReviewRated(rating: ReviewRating) {
        track(
            .rate,
            properties: ["rating": rating.rawValue]
        )
    }

    static func trackPaywallViewed() {
        let event = TikTokViewContentEvent(eventId: UUID().uuidString)
        event.setContentId("kumusta_subscription")
        event.setContentType("subscription")
        event.setDescription("Kumusta subscription plans")
        TikTokBusiness.trackTTEvent(event)
    }

    /// A free trial is not revenue. TikTok has a dedicated StartTrial event;
    /// sending Purchase here would teach its optimizer to chase trial starts.
    static func trackTrialStarted(productID: String) {
        track(
            .startTrial,
            properties: [
                "content_id": productID,
                "content_type": "subscription"
            ]
        )
    }

    /// One sales event per charged transaction. Value and currency are what
    /// TikTok needs for value-based optimization and ROAS; without them the
    /// Purchase column fills up but revenue stays at zero. Renewals happen
    /// off-device and reach TikTok through AppsFlyer postbacks instead.
    static func trackPurchase(productID: String, price: Decimal, currencyCode: String?) {
        let event = TikTokPurchaseEvent(eventId: UUID().uuidString)
        event.setContentId(productID)
        event.setContentType("subscription")
        event.setValue(NSDecimalNumber(decimal: price).stringValue)
        if let currencyCode = normalized(currencyCode)?.uppercased(), currencyCode.count == 3 {
            event.setCurrency(TTCurrency(rawValue: currencyCode))
        }
        TikTokBusiness.trackTTEvent(event)
    }

    private static func track(
        _ eventName: String,
        properties: [String: Any] = [:]
    ) {
        let event = TikTokBaseEvent(eventName: eventName)
        for (key, value) in properties {
            event.addProperty(withKey: key, value: value)
        }
        TikTokBusiness.trackTTEvent(event)
    }

    private static func track(
        _ eventName: TTEventName,
        properties: [String: Any] = [:]
    ) {
        track(eventName.rawValue, properties: properties)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func value(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}
#else
/// The TikTok SDK is optional for simulator/debug builds. Keep the same API so
/// analytics call sites remain unchanged when the SDK is unavailable.
enum TikTokAppEvents {
    static func initialize() {}
    static func identify(externalID: UUID, externalUserName: String?, email: String?) {}
    static func logout() {}
    static func trackLogin() {}
    static func trackRegistration() {}
    static func trackCompleteTutorial() {}
    static func trackLessonStarted(lesson: Lesson) {}
    static func trackLessonCompleted(lesson: Lesson) {}
    static func trackReviewRated(rating: ReviewRating) {}
    static func trackPaywallViewed() {}
    static func trackTrialStarted(productID: String) {}
    static func trackPurchase(productID: String, price: Decimal, currencyCode: String?) {}
}
#endif
