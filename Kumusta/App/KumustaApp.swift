import PostHog
import OSLog
import SwiftUI

@main
struct KumustaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue

    init() {
        Self.configurePostHog()
        // Resolve the interface text table before any text is built.
        AppLocalization.use(.english)

        // At process launch there cannot be a live take. Clean up only here—not
        // when SwiftUI creates recorder instances—so active recordings are safe.
        SpeakingRecorder.scrubAbandonedRecordings()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ResetLessonEducation") {
            UserDefaults.standard.removeObject(forKey: LessonEducation.formatSeenKey)
        }
        if ProcessInfo.processInfo.arguments.contains("-ResetSavedLessonWords") {
            UserDefaults.standard.removeObject(forKey: SavedLessonWordStore.storageKey)
        }
        #endif
        let dependencies = DependencyContainer.live()
        TikTokAppEvents.initialize()
        AppsFlyerAppEvents.initialize()
        MetaAppEvents.initialize()
        let appState = AppState(dependencies: dependencies)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ResetLessonJourney") {
            dependencies.learningJourneyStore.reset()
            dependencies.lessonProgressStore.reset()
        }
        if ProcessInfo.processInfo.arguments.contains("firstLaunch") {
            appState.resetForTesting()
            dependencies.learningJourneyStore.reset()
            dependencies.lessonProgressStore.reset()
        }
        if ProcessInfo.processInfo.arguments.contains("-SeedDueReviews") {
            Self.seedDueReviews(in: dependencies.memoryStore)
        }
        #endif
        _appState = State(initialValue: appState)
    }

    #if DEBUG
    /// Phrases from a lesson finished months ago, reviewed 0, 1 or 3 times,
    /// so the simulator and UI tests see weak, medium and strong cards due.
    private static func seedDueReviews(in store: MemoryStore) {
        store.reset()
        for accent in VietnameseAccent.allCases {
            store.enroll(
                lesson: SampleContent.dailySession(accent: accent, level: .new, dailyMinutes: 7),
                at: .now.addingTimeInterval(-120 * 86_400)
            )
        }
        for (index, card) in store.cards.values.sorted(by: { $0.id < $1.id }).enumerated() {
            let reviews = [0, 1, 3][index % 3]
            for _ in 0..<reviews {
                guard let dueAt = store.cards[card.id]?.memory.dueAt else { break }
                store.record(cardID: card.id, grade: .good, exercise: .listenMeaning, at: dueAt)
            }
        }
    }
    #endif

    private static func configurePostHog() {
        guard
            let projectToken = configuredValue(for: "POSTHOG_PROJECT_TOKEN"),
            let host = configuredValue(for: "POSTHOG_HOST")
        else {
            let missingKey = configuredValue(for: "POSTHOG_PROJECT_TOKEN") == nil
                ? "POSTHOG_PROJECT_TOKEN"
                : "POSTHOG_HOST"
            Logger(subsystem: "com.kumusta.app", category: "analytics")
                .warning("\(missingKey, privacy: .public) is not configured; PostHog events are not sent.")
            return
        }

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)
    }

    private static func configuredValue(for key: String) -> String? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty,
            !value.hasPrefix("$(")
        else {
            return nil
        }
        return value
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("mascotAnimationReview") {
                    MascotAnimationReview()
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
                .environment(appState)
                .environment(appState.dependencies)
                .environment(\.locale, AppLanguage.english.locale)
                .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .system).colorScheme)
                .tint(KumustaColors.accentDeep)
                .task { await appState.bootstrap() }
                .onChange(of: appState.launchPhase) { _, phase in
                    guard phase != .loading else { return }
                    Task { await prepareTrackingForVisibleExperience() }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task {
                            await appState.validateAuthenticatedSession()
                            await appState.beginAppSession()
                            await appState.dependencies.personalizedLearningService?.reset()
                        }
                    case .background:
                        appState.dependencies.analytics.flush()
                        Task {
                            await appState.endAppSession()
                            await appState.syncCloudState()
                        }
                    default:
                        break
                    }
                }
        }
    }

    @MainActor
    private func prepareTrackingForVisibleExperience() async {
        // Wait until the first usable screen is visible so the system prompt
        // has context. Onboarding and the paywall must also be attributable;
        // waiting for the main tab bar loses install/session coverage.
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        AppsFlyerAppEvents.markTrackingReady()
    }
}
