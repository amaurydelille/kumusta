import FacebookCore
import Foundation

@MainActor
enum MetaAppEvents {
    private static let appIDKey = "FacebookAppID"
    private static let clientTokenKey = "FacebookClientToken"

    private static var isConfigured = false

    static func initialize() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestScenario") {
            return
        }
        #endif

        // The SDK raises on missing credentials, so stay inert until both
        // values are provided by Secrets.xcconfig.
        guard
            value(forKey: appIDKey) != nil,
            value(forKey: clientTokenKey) != nil
        else {
            return
        }

        // Installs, launches and StoreKit 2 subscription purchases are logged
        // automatically by the SDK, so purchases are not sent manually here.
        // AppsFlyer owns SKAN conversion values; FacebookSKAdNetworkReportEnabled
        // is disabled in Info.plist. ATT consent is read from
        // ATTrackingManager by the SDK (v17+ on iOS 17+).
        ApplicationDelegate.shared.initializeSDK()
        isConfigured = true
    }

    /// Meta's per-install anonymous ID, forwarded to RevenueCat so its Meta
    /// integration can attribute renewals and trial conversions server-side.
    static var anonymousID: String? {
        guard isConfigured else { return nil }
        return AppEvents.shared.anonymousID
    }

    static func setUserID(_ userID: UUID) {
        guard isConfigured else { return }
        AppEvents.shared.userID = userID.uuidString.lowercased()
    }

    static func logout() {
        guard isConfigured else { return }
        AppEvents.shared.userID = nil
    }

    static func trackRegistration(method: String) {
        log(.completedRegistration, parameters: [.registrationMethod: method])
    }

    static func trackLogin() {
        log(AppEvents.Name("login"))
    }

    static func trackTutorialCompletion(success: Bool, tutorialID: String, content: String) {
        log(
            .completedTutorial,
            parameters: [
                .success: success ? "1" : "0",
                .contentID: tutorialID,
                .content: content
            ]
        )
    }

    static func trackPaywallViewed() {
        log(
            .viewedContent,
            parameters: [
                .contentID: "kumusta_subscription",
                .contentType: "subscription",
                .content: "Kumusta subscription plans"
            ]
        )
    }

    static func trackLessonStarted(lesson: Lesson) {
        log(
            .viewedContent,
            parameters: [
                .contentID: lesson.id.uuidString,
                .contentType: "lesson",
                .content: lesson.analyticsScenario
            ]
        )
    }

    static func trackLessonCompleted(lesson: Lesson) {
        log(
            AppEvents.Name("lesson_completed"),
            parameters: [
                .contentID: lesson.id.uuidString,
                .contentType: "lesson",
                .content: lesson.analyticsScenario,
                AppEvents.ParameterName("round_count"): lesson.roundCount
            ]
        )
    }

    private static func log(
        _ eventName: AppEvents.Name,
        parameters: [AppEvents.ParameterName: Any] = [:]
    ) {
        guard isConfigured else { return }
        AppEvents.shared.logEvent(eventName, parameters: parameters)
    }

    private static func value(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}
