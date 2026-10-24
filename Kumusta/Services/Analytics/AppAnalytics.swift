import Foundation
import OSLog
import PostHog
import Supabase

protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent, properties: [String: String])
    func track(
        _ event: AnalyticsEvent,
        properties: [String: String],
        clientSessionID: UUID?
    )
    /// Enqueues an event before attempting delivery. Lifecycle-critical events
    /// use this to avoid losing the event between a scene transition and the
    /// next run loop.
    func trackAndFlush(_ event: AnalyticsEvent, properties: [String: String]) async
    func flush()
}

extension AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }

    func flush() {}
}

final class AppAnalytics: AnalyticsTracking, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.kumusta.app", category: "analytics")
    private let lock = NSLock()
    private var remoteRepository: (any SignedInKumustaSyncing)?
    private let outbox = AnalyticsOutbox()
    private let appVersion: String?
    private let appBuild: String?
    private let installID: UUID

    init() {
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let key = "kumusta.analytics.install-id.v1"
        if let raw = UserDefaults.standard.string(forKey: key), let existing = UUID(uuidString: raw) {
            installID = existing
        } else {
            let created = UUID()
            UserDefaults.standard.set(created.uuidString, forKey: key)
            installID = created
        }
    }

    func attachRemoteRepository(_ repository: any SignedInKumustaSyncing) {
        lock.withLock {
            remoteRepository = repository
        }
        flushOutbox()
    }

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        track(event, properties: properties, clientSessionID: nil)
    }

    func track(
        _ event: AnalyticsEvent,
        properties: [String: String] = [:],
        clientSessionID: UUID? = nil
    ) {
        let input = makeInput(
            event,
            properties: properties,
            clientSessionID: clientSessionID
        )

        #if DEBUG
        logger.debug("Event: \(event.rawValue, privacy: .public), properties: \(String(describing: properties), privacy: .private)")
        #endif

        capturePostHog(input)

        Task {
            await outbox.enqueue(input)
            await flushOutbox()
        }
    }

    func trackAndFlush(
        _ event: AnalyticsEvent,
        properties: [String: String] = [:]
    ) async {
        let input = makeInput(event, properties: properties, clientSessionID: nil)

        #if DEBUG
        logger.debug("Event: \(event.rawValue, privacy: .public), properties: \(String(describing: properties), privacy: .private)")
        #endif

        capturePostHog(input)

        await outbox.enqueue(input)
        await flushOutbox()
    }

    func flush() {
        PostHogSDK.shared.flush()
        flushOutbox()
    }

    private func capturePostHog(_ input: AnalyticsSyncInput) {
        var properties = input.properties
        properties["client_event_id"] = input.clientEventID.uuidString
        if let screenName = input.screenName {
            properties["$screen_name"] = screenName
        }
        if let clientSessionID = input.clientSessionID {
            properties["client_session_id"] = clientSessionID.uuidString
        }
        PostHogSDK.shared.capture(input.eventName, properties: properties)
    }

    static let onboardingFlowVersion = "first_lesson_v2"

    private func commonProperties(
        for event: AnalyticsEvent,
        properties: [String: String]
    ) -> [String: String] {
        var result = properties
        result["platform"] = "ios"
        if let appVersion {
            result["app_version"] = appVersion
        }
        if let appBuild {
            result["app_build"] = appBuild
        }
        if event.rawValue.hasPrefix("onboarding_") ||
            properties["screen_name"]?.hasPrefix("onboarding_") == true {
            result["onboarding_flow_version"] = Self.onboardingFlowVersion
        }
        return result
    }

    private func flushOutbox() {
        Task { await flushOutbox() }
    }

    private func flushOutbox() async {
        guard let repository = lock.withLock({ remoteRepository }) else { return }
        guard await outbox.beginFlush() else { return }
        while let input = await outbox.nextForDelivery() {
            do {
                // Anonymous identities can write only their validated,
                // owner-scoped analytics rows; onboarding does not wait for
                // account creation before reaching the first-party stream.
                try await repository.insertAnalytics(input)
                await outbox.remove(input.clientEventID)
            } catch where Self.isPermanentRejection(error) {
                // A rejected event will be rejected again on every retry. Drop
                // it so it cannot block every later event from this install.
                logger.error("Dropped rejected analytics event \(input.eventName, privacy: .public)")
                await outbox.remove(input.clientEventID)
            } catch {
                // Preserve ordering and retry on the next event or app launch.
                let category = (error as? PostgrestError)?.code ?? String(describing: type(of: error))
                logger.error("Analytics delivery deferred for \(input.eventName, privacy: .public): \(category, privacy: .public)")
                await outbox.finishFlush()
                break
            }
        }
    }

    /// Validation failures (client-side or from the database trigger) are
    /// deterministic. Network, auth, and RLS failures stay retryable.
    static func isPermanentRejection(_ error: any Error) -> Bool {
        if let syncError = error as? SupabaseSyncError {
            switch syncError {
            case .invalidAnalyticsEvent, .unsafeAnalyticsProperty: return true
            default: return false
            }
        }
        if let postgrestError = error as? PostgrestError, let code = postgrestError.code {
            // P0001: raised by kumusta_validate_analytics_event.
            // 22xxx/23xxx: data exceptions and check-constraint violations.
            return code == "P0001" || code.hasPrefix("22") || code.hasPrefix("23")
        }
        return false
    }

    private func makeInput(
        _ event: AnalyticsEvent,
        properties: [String: String],
        clientSessionID: UUID?
    ) -> AnalyticsSyncInput {
        AnalyticsSyncInput(
            eventName: event.rawValue,
            clientSessionID: clientSessionID,
            properties: commonProperties(for: event, properties: properties),
            screenName: properties["screen_name"],
            appVersion: appVersion,
            installID: installID
        )
    }
}

actor AnalyticsOutbox {
    private let fileURL: URL
    private var events: [AnalyticsSyncInput]
    private let maximumCount = 500
    private var isFlushing = false

    init(fileURL suppliedURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = base.appendingPathComponent("Kumusta", isDirectory: true)
        fileURL = suppliedURL ?? directory.appendingPathComponent("analytics-outbox.json")
        if
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([AnalyticsSyncInput].self, from: data)
        {
            events = decoded
        } else {
            events = []
        }
    }

    func enqueue(_ event: AnalyticsSyncInput) {
        guard !events.contains(where: { $0.clientEventID == event.clientEventID }) else { return }
        events.append(event)
        if events.count > maximumCount {
            events.removeFirst(events.count - maximumCount)
        }
        persist()
    }

    func beginFlush() -> Bool {
        guard !isFlushing else { return false }
        isFlushing = true
        return true
    }

    func nextForDelivery() -> AnalyticsSyncInput? {
        guard let input = pending().first else {
            isFlushing = false
            return nil
        }
        return input
    }

    func finishFlush() {
        isFlushing = false
    }

    func pending() -> [AnalyticsSyncInput] {
        let cutoff = Date.now.addingTimeInterval(-604_800)
        let freshEvents = events.filter { $0.occurredAt >= cutoff }
        if freshEvents.count != events.count {
            events = freshEvents
            persist()
        }
        return events
    }

    func remove(_ clientEventID: UUID) {
        events.removeAll { $0.clientEventID == clientEventID }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
