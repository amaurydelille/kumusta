import AppTrackingTransparency
import AppsFlyerLib
import Foundation

@MainActor
enum AppsFlyerAppEvents {
    private static let devKeyKey = "APPSFLYER_DEV_KEY"
    private static let appIDKey = "APPSFLYER_APP_ID"

    private static var isConfigured = false
    private static var isStarting = false
    private static var isTrackingReady = false
    private static var trackingReadyWaiters: [CheckedContinuation<Void, Never>] = []

    static func initialize() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestScenario") {
            return
        }
        #endif

        guard
            let devKey = value(forKey: devKeyKey),
            let appID = value(forKey: appIDKey)
        else {
            return
        }

        let appsFlyer = AppsFlyerLib.shared()
        #if DEBUG
        appsFlyer.isDebug = true
        #endif
        appsFlyer.initialize(devKey: devKey, appId: appID)
        appsFlyer.registerSessionReadyListener {
            Task { @MainActor in
                await startWhenReady()
            }
        }
        isConfigured = true
    }

    /// Associates future AppsFlyer events with the signed-in product user.
    /// This is intentionally separate from TikTok's identify call so the two
    /// attribution systems retain the same stable first-party identity.
    static func setCustomerUserID(_ userID: UUID) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().customerUserID = userID.uuidString.lowercased()
    }

    /// Allows the SDK to start as soon as any real app experience is visible.
    /// Onboarding and the paywall are valid acquisition experiences too; the
    /// SDK must not wait for a user to reach the main tab bar.
    static func markTrackingReady() {
        guard isConfigured, !isTrackingReady else { return }
        isTrackingReady = true
        let waiters = trackingReadyWaiters
        trackingReadyWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    static func trackLogin() {
        log(AFEventLogin)
    }

    static func trackRegistration(method: String) {
        log(
            AFEventCompleteRegistration,
            values: [AFEventParamRegistrationMethod: method]
        )
    }

    static func trackTutorialCompletion(
        success: Bool,
        tutorialID: String,
        content: String
    ) {
        log(
            AFEventTutorial_completion,
            values: [
                AFEventParamSuccess: success ? "true" : "false",
                AFEventParamTutorialId: tutorialID,
                AFEventParamContent: content
            ]
        )
    }

    static func trackPaywallViewed() {
        log(
            AFEventContentView,
            values: [
                AFEventParamContentId: "kumusta_subscription",
                AFEventParamContentType: "subscription",
                AFEventParamContent: "Kumusta subscription plans"
            ]
        )
    }

    /// The per-install AppsFlyer ID. RevenueCat needs it to send its
    /// server-side subscription events (renewals, trial conversions, refunds)
    /// to AppsFlyer; without it that integration sends nothing.
    static var appsFlyerID: String? {
        guard isConfigured else { return nil }
        let id = AppsFlyerLib.shared().getAppsFlyerUID()
        return id.isEmpty ? nil : id
    }

    /// Free trial start: no revenue. Previously this was logged as a full-price
    /// `af_purchase`, which inflated revenue and trained TikTok/Meta on trial
    /// starts. Sent from the device so SKAN conversion values can count it.
    static func trackTrialStarted(productID: String) {
        log(
            AFEventStartTrial,
            values: [
                AFEventParamContentId: productID,
                AFEventParamContentType: "subscription"
            ]
        )
    }

    /// A charged transaction with real revenue. Kept on-device because SKAN
    /// conversion values are computed by the SDK and ignore server-side
    /// events. RevenueCat's AppsFlyer integration must therefore leave the
    /// initial-purchase and trial-started events off to avoid double revenue.
    static func trackPurchase(
        productID: String,
        revenue: Decimal,
        currencyCode: String?
    ) {
        var values: [AnyHashable: Any] = [
            AFEventParamContentId: productID,
            AFEventParamContentType: "subscription",
            AFEventParamRevenue: NSDecimalNumber(decimal: revenue).doubleValue
        ]
        if let currencyCode, !currencyCode.isEmpty {
            values[AFEventParamCurrency] = currencyCode
        }
        log(
            AFEventPurchase,
            values: values
        )
    }

    static func trackLessonStarted(lesson: Lesson) {
        log(
            "lesson_started",
            values: [
                AFEventParamContentId: lesson.id.uuidString,
                AFEventParamContentType: "lesson",
                AFEventParamContent: lesson.analyticsScenario
            ]
        )
    }

    static func trackLessonCompleted(lesson: Lesson) {
        log(
            "lesson_completed",
            values: [
                AFEventParamContentId: lesson.id.uuidString,
                AFEventParamContentType: "lesson",
                AFEventParamContent: lesson.analyticsScenario,
                "round_count": lesson.roundCount
            ]
        )
    }

    static func trackExerciseCompleted(courseName: String, exerciseName: String) {
        log(
            "complete_exercise",
            values: [
                "course_name": courseName,
                "exercise_name": exerciseName
            ]
        )
    }

    static func trackCourseCompleted(courseName: String) {
        log(
            "course_completed",
            values: [
                "course_name": courseName,
                "course_completed": true
            ]
        )
    }

    private static func startWhenReady() async {
        guard isConfigured, !isStarting else { return }
        isStarting = true
        await waitForTrackingReady()

        if #available(iOS 14, *),
           ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
            // The IDFA only exists after consent. RevenueCat captured
            // identifiers at login, before the prompt; refresh so its
            // AppsFlyer and Meta integrations can match this device.
            RevenueCatPurchaseService.refreshDeviceIdentifiersForAttribution()
        }

        _ = try? await AppsFlyerLib.shared().start()
        isStarting = false
    }

    private static func waitForTrackingReady() async {
        guard !isTrackingReady else { return }
        await withCheckedContinuation { continuation in
            trackingReadyWaiters.append(continuation)
        }
    }

    private static func log(
        _ eventName: String,
        values: [AnyHashable: Any]? = nil
    ) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(eventName, withValues: values)
    }

    private static func value(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}
