import Foundation
import Supabase

enum SupabaseSyncError: LocalizedError, Sendable {
    case invalidDisplayName
    case invalidOnboardingInput
    case invalidSessionInput
    case invalidProgressInput
    case invalidReviewInput
    case invalidAnalyticsEvent
    case unsafeAnalyticsProperty
    case invalidCancellationFeedback
    case invalidLeaderboardRequest

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            L("Your name must be 60 characters or fewer.")
        case .invalidOnboardingInput:
            L("The onboarding answers could not be synced.")
        case .invalidSessionInput:
            L("The learning session could not be synced.")
        case .invalidProgressInput:
            L("The daily learning progress could not be synced.")
        case .invalidReviewInput:
            L("The review result could not be synced.")
        case .invalidAnalyticsEvent:
            L("The analytics event is not valid.")
        case .unsafeAnalyticsProperty:
            L("The analytics event contains a property that is not allowed.")
        case .invalidCancellationFeedback:
            L("Your cancellation feedback could not be saved.")
        case .invalidLeaderboardRequest:
            L("The leaderboard request is not valid.")
        }
    }
}

protocol SignedInKumustaSyncing: Sendable {
    func fetchProfile() async throws -> RemoteProfile?
    func fetchLeaderboard(periodKind: String, periodKey: String, limit: Int) async throws -> RemoteLeaderboardSnapshot
    func leaderboardChanges() async -> AsyncStream<Void>
    func fetchUserState() async throws -> CloudUserState?
    func syncProfile(_ profile: UserProfile, onboardingCompletedAt: Date?) async throws
    func syncUserState(_ state: CloudUserState) async throws
    func syncOnboarding(_ input: OnboardingSyncInput) async throws
    func syncLearningPreferences(from profile: UserProfile) async throws
    func syncAppSession(_ input: AppSessionSyncInput) async throws -> RemoteAppSession
    func syncLearningSession(_ input: LearningSessionSyncInput) async throws -> RemoteLearningSession
    func syncFlashcardSession(_ input: FlashcardSessionSyncInput) async throws -> RemoteFlashcardSession
    func syncReview(_ input: ReviewSyncInput) async throws
    func syncDailyProgress(_ input: DailyProgressSyncInput) async throws
    func awardXP(_ request: XPAwardRequest) async throws -> XPAwardResponse
    func insertAnalytics(_ input: AnalyticsSyncInput) async throws
    func submitCancellationFeedback(_ reason: String) async throws
    func fetchEntitlement(id: String) async throws -> RemoteEntitlement?
}

/// RLS-safe remote mutation boundary. Public methods never accept a user ID;
/// private learner rows use the refreshed non-anonymous session user, while
/// cancellation feedback and analytics use the refreshed owner-scoped identity
/// (including anonymous sessions for those two user-initiated flows).
actor SupabaseSignedInRepository: SignedInKumustaSyncing {
    private let client: SupabaseClient
    private let authSessionProvider: any AuthSessionProviding

    init(client: SupabaseClient, authSessionProvider: any AuthSessionProviding) {
        self.client = client
        self.authSessionProvider = authSessionProvider
    }

    func fetchProfile() async throws -> RemoteProfile? {
        let userID = try await authenticatedUserID()
        let rows: [RemoteProfile] = try await client
            .from("kumusta_profiles")
            .select("id,display_name,locale,timezone,onboarding_completed_at,avatar_seed")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        guard let profile = rows.first else { return nil }
        guard profile.avatarSeed == nil else { return profile }

        // Backfill older rows without ever replacing a persisted/custom value.
        // The UUID is opaque and stable, so it keeps the avatar consistent
        // without putting an email address or display name in a public URL.
        let seed = DiceBearAvatar.seed(for: profile.id)
        let patch = ProfileAvatarSeedMutation(avatarSeed: seed)
        _ = try? await client
            .from("kumusta_profiles")
            .update(patch)
            .eq("id", value: userID)
            .is("avatar_seed", value: nil)
            .execute()

        return RemoteProfile(
            id: profile.id,
            displayName: profile.displayName,
            locale: profile.locale,
            timezone: profile.timezone,
            onboardingCompletedAt: profile.onboardingCompletedAt,
            avatarSeed: seed
        )
    }

    func fetchLeaderboard(
        periodKind: String,
        periodKey: String,
        limit: Int = 50
    ) async throws -> RemoteLeaderboardSnapshot {
        // Supabase anonymous sessions use the `authenticated` database role,
        // and the leaderboard view exposes only its privacy-safe projection.
        // Allow that session to read the real board while private learner
        // tables continue to require a non-anonymous account.
        let userID = try await authSessionProvider.currentBackendIdentity().id
        let allowedPeriodKinds = ["all_time"]
        guard
            allowedPeriodKinds.contains(periodKind),
            !periodKey.isEmpty,
            (1 ... 1_000).contains(limit)
        else {
            throw SupabaseSyncError.invalidLeaderboardRequest
        }

        let columns = "period_kind,period_key,leaderboard_rank,user_id,display_name,avatar_seed,xp,updated_at"
        let topRows: [RemoteLeaderboardEntry] = try await client
            .from("kumusta_xp_leaderboard")
            .select(columns)
            .eq("period_kind", value: periodKind)
            .eq("period_key", value: periodKey)
            .order("leaderboard_rank", ascending: true)
            .limit(limit)
            .execute()
            .value

        var entries = topRows
        if !entries.contains(where: { $0.userID == userID }) {
            let ownRows: [RemoteLeaderboardEntry] = try await client
                .from("kumusta_xp_leaderboard")
                .select(columns)
                .eq("period_kind", value: periodKind)
                .eq("period_key", value: periodKey)
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            entries.append(contentsOf: ownRows)
        }

        return RemoteLeaderboardSnapshot(
            entries: entries.sorted { $0.leaderboardRank < $1.leaderboardRank },
            currentUserID: userID
        )
    }

    func leaderboardChanges() async -> AsyncStream<Void> {
        let channel = client.realtimeV2.channel("kumusta-leaderboard")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "kumusta_xp_leaderboard_signal"
        )
        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let observationTask = Task {
            do {
                try await channel.subscribeWithError()
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    continuation.yield(())
                }
            } catch {
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in
            observationTask.cancel()
            Task {
                await channel.unsubscribe()
            }
        }

        return stream
    }

    func fetchUserState() async throws -> CloudUserState? {
        let userID = try await authenticatedUserID()
        let rows: [RemoteUserState] = try await client
            .from("kumusta_user_state")
            .select("user_id,schema_version,state,updated_at")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first,
              row.schemaVersion == CloudUserState.currentSchemaVersion,
              row.state.schemaVersion == CloudUserState.currentSchemaVersion
        else { return nil }
        return row.state
    }

    func syncProfile(_ profile: UserProfile, onboardingCompletedAt: Date?) async throws {
        let userID = try await authenticatedUserID()
        let displayName = Self.normalizedOptional(profile.name)
        guard displayName.map({ $0.count <= 60 }) ?? true else {
            throw SupabaseSyncError.invalidDisplayName
        }

        let row = ProfileMutation(
            id: userID,
            displayName: displayName,
            locale: "en",
            timezone: TimeZone.current.identifier,
            onboardingCompletedAt: onboardingCompletedAt,
            avatarSeed: profile.avatarSeed ?? DiceBearAvatar.seed(for: userID)
        )
        try await client
            .from("kumusta_profiles")
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()
    }

    func syncUserState(_ state: CloudUserState) async throws {
        let userID = try await authenticatedUserID()
        guard state.schemaVersion == CloudUserState.currentSchemaVersion else { return }
        let encodedState = try JSONEncoder().encode(state)
        guard encodedState.count <= 2_000_000 else { return }

        let row = UserStateMutation(
            userID: userID,
            schemaVersion: CloudUserState.currentSchemaVersion,
            state: state
        )
        try await client
            .from("kumusta_user_state")
            .upsert(row, onConflict: "user_id", returning: .minimal)
            .execute()
    }

    func syncOnboarding(_ input: OnboardingSyncInput) async throws {
        let userID = try await authenticatedUserID()
        let motivation = Self.normalizedOptional(input.motivation)
        let desiredOutcome = Self.normalizedOptional(input.desiredOutcome)
        let referralSource = Self.normalizedOptional(input.referralSource)
        guard
            (0 ... 20).contains(input.currentStep),
            motivation.map({ $0.count <= 500 }) ?? true,
            desiredOutcome.map({ $0.count <= 300 }) ?? true,
            referralSource.map({ $0.count <= 80 }) ?? true
        else {
            throw SupabaseSyncError.invalidOnboardingInput
        }

        let row = OnboardingMutation(
            userID: userID,
            motivation: motivation,
            desiredOutcome: desiredOutcome,
            referralSource: referralSource,
            currentStep: input.currentStep,
            demoCompleted: input.demoCompleted,
            paywallSeenAt: input.paywallSeenAt,
            completedAt: input.completedAt,
            responseVersion: 1
        )
        try await client
            .from("kumusta_onboarding_responses")
            .upsert(row, onConflict: "user_id", returning: .minimal)
            .execute()
    }

    func syncLearningPreferences(from profile: UserProfile) async throws {
        let userID = try await authenticatedUserID()
        let row = LearningPreferencesMutation(
            userID: userID,
            goal: Self.remoteGoal(profile.goal),
            selfAssessedLevel: Self.remoteLevel(profile.level),
            targetLevel: profile.adaptiveTargetLevel,
            challengePreference: (profile.challengePreference ?? .balanced).rawValue,
            dailyMinutes: Self.supportedDailyMinutes(closestTo: profile.dailyMinutes),
            reminderEnabled: false
        )
        try await client
            .from("kumusta_learning_preferences")
            .upsert(row, onConflict: "user_id", returning: .minimal)
            .execute()
    }

    func syncAppSession(_ input: AppSessionSyncInput) async throws -> RemoteAppSession {
        let userID = try await authenticatedUserID()
        guard
            (0 ... 86_400).contains(input.activeSeconds),
            input.endedAt.map({ $0 >= input.startedAt }) ?? true,
            input.appVersion.map({ $0.count <= 40 }) ?? true
        else {
            throw SupabaseSyncError.invalidSessionInput
        }

        let row = AppSessionMutation(
            userID: userID,
            clientSessionID: input.clientSessionID,
            startedAt: input.startedAt,
            endedAt: input.endedAt,
            activeSeconds: input.activeSeconds,
            appVersion: input.appVersion,
            installID: input.installID
        )
        return try await client
            .from("kumusta_app_sessions")
            .upsert(row, onConflict: "user_id,client_session_id", returning: .representation)
            .select("id,client_session_id")
            .single()
            .execute()
            .value
    }

    func syncLearningSession(_ input: LearningSessionSyncInput) async throws -> RemoteLearningSession {
        let userID = try await authenticatedUserID()
        guard
            (0 ... 14_400).contains(input.activeSeconds),
            input.score.map({ (0 ... 1).contains($0) }) ?? true,
            input.endedAt.map({ $0 >= input.startedAt }) ?? true,
            input.appVersion.map({ $0.count <= 40 }) ?? true
        else {
            throw SupabaseSyncError.invalidSessionInput
        }

        let row = LearningSessionMutation(
            userID: userID,
            lessonID: input.contentKind == .authored ? input.lessonID : nil,
            contentID: input.lessonID,
            contentKind: input.contentKind.rawValue,
            entryPoint: input.entryPoint,
            isReplay: input.isReplay,
            sessionKind: input.kind.rawValue,
            startedAt: input.startedAt,
            endedAt: input.endedAt,
            activeSeconds: input.activeSeconds,
            completed: input.completed,
            score: input.score,
            clientSessionID: input.clientSessionID,
            appVersion: input.appVersion
        )
        let saved: RemoteLearningSession = try await client
            .from("kumusta_learning_sessions")
            .upsert(row, onConflict: "user_id,client_session_id", returning: .representation)
            .select("id,client_session_id")
            .single()
            .execute()
            .value
        return saved
    }

    func syncFlashcardSession(_ input: FlashcardSessionSyncInput) async throws -> RemoteFlashcardSession {
        let userID = try await authenticatedUserID()
        guard
            (0 ... 100).contains(input.totalCards),
            (0 ... input.totalCards).contains(input.cardsPresented),
            (0 ... input.cardsPresented).contains(input.cardsAnswered),
            (0 ... input.cardsAnswered).contains(input.correctCount),
            (0 ... 14_400).contains(input.activeSeconds),
            input.score.map({ (0 ... 1).contains($0) }) ?? true,
            input.endedAt.map({ $0 >= input.startedAt }) ?? true,
            input.appVersion.map({ $0.count <= 40 }) ?? true
        else {
            throw SupabaseSyncError.invalidSessionInput
        }

        let row = FlashcardSessionMutation(
            userID: userID,
            clientSessionID: input.clientSessionID,
            startedAt: input.startedAt,
            endedAt: input.endedAt,
            completed: input.completed,
            totalCards: input.totalCards,
            cardsPresented: input.cardsPresented,
            cardsAnswered: input.cardsAnswered,
            correctCount: input.correctCount,
            activeSeconds: input.activeSeconds,
            score: input.score,
            appVersion: input.appVersion
        )
        return try await client
            .from("kumusta_flashcard_sessions")
            .upsert(row, onConflict: "user_id,client_session_id", returning: .representation)
            .select("id,client_session_id")
            .single()
            .execute()
            .value
    }

    func syncReview(_ input: ReviewSyncInput) async throws {
        let userID = try await authenticatedUserID()
        guard
            (0 ... 3_650).contains(input.intervalDays),
            (0 ... 1).contains(input.mastery),
            input.responseMilliseconds.map({ (0 ... 600_000).contains($0) }) ?? true
        else {
            throw SupabaseSyncError.invalidReviewInput
        }

        let sessionID = try await resolveOwnedSessionID(
            clientSessionID: input.clientSessionID,
            userID: userID
        )
        let event = ReviewEventMutation(
            userID: userID,
            vocabularyID: input.vocabularyID,
            sessionID: sessionID,
            rating: Self.remoteRating(input.rating),
            responseMilliseconds: input.responseMilliseconds,
            previousDueAt: input.previousDueAt,
            nextDueAt: input.nextDueAt,
            intervalDays: input.intervalDays,
            occurredAt: .now,
            clientEventID: input.clientEventID
        )
        try await client
            .from("kumusta_review_events")
            .upsert(
                event,
                onConflict: "user_id,client_event_id",
                returning: .minimal,
                ignoreDuplicates: true
            )
            .execute()

        let vocabularyState = UserVocabularyMutation(
            userID: userID,
            vocabularyID: input.vocabularyID,
            state: input.mastery >= 0.9 ? "mastered" : "review",
            mastery: input.mastery,
            intervalDays: input.intervalDays,
            dueAt: input.nextDueAt,
            lastReviewedAt: .now
        )
        try await client
            .from("kumusta_user_vocabulary")
            .upsert(
                vocabularyState,
                onConflict: "user_id,vocabulary_id",
                returning: .minimal
            )
            .execute()
    }

    func syncDailyProgress(_ input: DailyProgressSyncInput) async throws {
        let userID = try await authenticatedUserID()
        guard
            input.progressDate.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil,
            (0 ... 86_400).contains(input.activeSeconds),
            input.lessonsCompleted >= 0,
            input.wordsLearned >= 0,
            input.wordsReviewed >= 0,
            input.xp >= 0
        else {
            throw SupabaseSyncError.invalidProgressInput
        }

        let row = DailyProgressMutation(
            userID: userID,
            progressDate: input.progressDate,
            activeSeconds: input.activeSeconds,
            lessonsCompleted: input.lessonsCompleted,
            wordsLearned: input.wordsLearned,
            wordsReviewed: input.wordsReviewed,
            xp: input.xp,
            dailyGoalMet: input.dailyGoalMet
        )
        try await client
            .from("kumusta_daily_progress")
            .upsert(row, onConflict: "user_id,progress_date", returning: .minimal)
            .execute()
    }

    func awardXP(_ request: XPAwardRequest) async throws -> XPAwardResponse {
        _ = try await authenticatedUserID()
        return try await client.functions.invoke(
            "kumusta-award-xp",
            options: FunctionInvokeOptions(body: request, timeoutInterval: 15)
        )
    }

    func insertAnalytics(_ input: AnalyticsSyncInput) async throws {
        // Analytics is also collected during pre-account onboarding. An
        // anonymous Supabase identity is still a stable, owner-scoped UUID,
        // so it can safely receive validated events without unlocking any
        // other private data tables.
        let identity = try await authSessionProvider.currentBackendIdentity()
        let userID = identity.id
        guard
            AnalyticsEvent(rawValue: input.eventName) != nil,
            (1 ... 32_767).contains(input.eventVersion),
            input.occurredAt >= .now.addingTimeInterval(-604_800),
            input.occurredAt <= .now.addingTimeInterval(300),
            input.properties.count <= 30,
            input.screenName.map({ (1 ... 120).contains($0.count) }) ?? true,
            input.appVersion.map({ (1 ... 40).contains($0.count) }) ?? true,
            input.platform == "ios"
        else {
            throw SupabaseSyncError.invalidAnalyticsEvent
        }
        try Self.validateAnalyticsProperties(input.properties)

        let sessionID: UUID?
        if identity.isAnonymous {
            // Anonymous learners cannot create learning sessions. Avoid the
            // private session lookup and keep onboarding events ungrouped.
            sessionID = nil
        } else {
            sessionID = try await resolveOwnedSessionID(
                clientSessionID: input.clientSessionID,
                userID: userID
            )
        }
        let row = AnalyticsEventMutation(
            userID: userID,
            eventName: input.eventName,
            eventVersion: input.eventVersion,
            sessionID: sessionID,
            properties: input.clientSessionID.map {
                input.properties.merging(["client_session_id": $0.uuidString], uniquingKeysWith: { _, new in new })
            } ?? input.properties,
            occurredAt: input.occurredAt,
            clientEventID: input.clientEventID,
            screenName: input.screenName,
            appVersion: input.appVersion,
            platform: input.platform,
            installID: input.installID
        )
        try await client
            .from("kumusta_analytics_events")
            .upsert(
                row,
                onConflict: "user_id,client_event_id",
                returning: .minimal,
                ignoreDuplicates: true
            )
            .execute()
    }

    func submitCancellationFeedback(_ reason: String) async throws {
        // The cancellation flow is available to subscribers before they have
        // created an account, so anonymous Supabase sessions must be able to
        // submit feedback too. RLS still binds the row to the current user.
        let identity = try await authSessionProvider.currentBackendIdentity()
        let userID = identity.id
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1 ... 500).contains(normalizedReason.count) else {
            throw SupabaseSyncError.invalidCancellationFeedback
        }

        let row = CancellationFeedbackMutation(
            userID: userID,
            reason: normalizedReason
        )
        try await client
            .from("kumusta_subscription_cancellation_feedback")
            .insert(row, returning: .minimal)
            .execute()
    }

    func fetchEntitlement(id: String) async throws -> RemoteEntitlement? {
        let userID = try await authenticatedUserID()
        guard (1 ... 120).contains(id.count) else { return nil }
        let rows: [RemoteEntitlement] = try await client
            .from("kumusta_entitlements")
            .select("entitlement_id,is_active,product_id,expires_at,will_renew")
            .eq("user_id", value: userID)
            .eq("entitlement_id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private func authenticatedUserID() async throws -> UUID {
        try await authSessionProvider.currentAuthenticatedUser().id
    }

    /// The UI may know only its own idempotency ID. Resolving the database ID
    /// through an own-user filter prevents attaching an event to another
    /// learner's session even if a UUID is guessed.
    private func resolveOwnedSessionID(clientSessionID: UUID?, userID: UUID) async throws -> UUID? {
        guard let clientSessionID else { return nil }
        let rows: [SessionIdentity] = try await client
            .from("kumusta_learning_sessions")
            .select("id")
            .eq("user_id", value: userID)
            .eq("client_session_id", value: clientSessionID)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    private static func remoteGoal(_ goal: LearningGoal) -> String {
        goal.rawValue
    }

    private static func remoteLevel(_ level: ProficiencyLevel) -> String {
        level.rawValue
    }

    private static func supportedDailyMinutes(closestTo minutes: Int) -> Int {
        [3, 5, 7, 10].min {
            abs($0 - minutes) < abs($1 - minutes)
        } ?? 10
    }

    private static func remoteRating(_ rating: ReviewRating) -> String {
        switch rating {
        case .again: "again"
        case .almost: "almost"
        case .gotIt: "got_it"
        }
    }

    static func validateAnalyticsProperties(_ properties: [String: String]) throws {
        let allowedKeys = [
            "app_build", "app_version", "onboarding_flow_version", "client_session_id", "offering",
            "active_seconds", "answer_id", "assistant_fragments", "attempt",
            "audio_duration_ms", "autoplay", "availability", "card_id", "card_index",
            "cards_answered", "cards_presented", "catalog_count", "category", "choice_id",
            "content_kind", "correct_count", "daily_limit_seconds",
            "daily_minutes", "difficulty_feedback", "end_reason", "entitlement_found",
            "entry_point", "error_category", "feedback_requested", "goal", "got_it_count",
            "has_topic_preference", "hint_revealed", "hint_visible", "is_correct",
            "is_first_attempt", "is_replay", "lesson_id", "level", "live_engine", "matched_target",
            "mode", "muted", "package_id", "pace_feedback", "personality", "platform", "playback_result",
            "playback_source", "playback_speed", "position",
            "question_id", "question_index", "recording_duration_ms", "remaining_seconds",
            "replay_count", "response_ms", "reveal_type", "round_count", "score",
            "screen_name", "skipped_reason", "source", "source_lesson_id", "started",
            "start_error", "step", "step_count", "step_id", "step_index", "step_kind", "text_kind",
            "total_cards", "user_fragments", "value", "vocabulary_id"
        ]
        for (key, value) in properties {
            guard
                allowedKeys.contains(key),
                value.count <= 100
            else {
                throw SupabaseSyncError.unsafeAnalyticsProperty
            }
        }
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

private struct ProfileMutation: Encodable {
    let id: UUID
    let displayName: String?
    let locale: String
    let timezone: String
    let onboardingCompletedAt: Date?
    let avatarSeed: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case locale
        case timezone
        case onboardingCompletedAt = "onboarding_completed_at"
        case avatarSeed = "avatar_seed"
    }
}

private struct ProfileAvatarSeedMutation: Encodable {
    let avatarSeed: String

    enum CodingKeys: String, CodingKey {
        case avatarSeed = "avatar_seed"
    }
}

private struct UserStateMutation: Encodable {
    let userID: UUID
    let schemaVersion: Int
    let state: CloudUserState

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case schemaVersion = "schema_version"
        case state
    }
}

private struct OnboardingMutation: Encodable {
    let userID: UUID
    let motivation: String?
    let desiredOutcome: String?
    let referralSource: String?
    let currentStep: Int
    let demoCompleted: Bool
    let paywallSeenAt: Date?
    let completedAt: Date?
    let responseVersion: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case motivation
        case desiredOutcome = "desired_outcome"
        case referralSource = "referral_source"
        case currentStep = "current_step"
        case demoCompleted = "demo_completed"
        case paywallSeenAt = "paywall_seen_at"
        case completedAt = "completed_at"
        case responseVersion = "response_version"
    }
}

private struct LearningPreferencesMutation: Encodable {
    let userID: UUID
    let goal: String
    let selfAssessedLevel: String
    let targetLevel: Int
    let challengePreference: String
    let dailyMinutes: Int
    let reminderEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case goal
        case selfAssessedLevel = "self_assessed_level"
        case targetLevel = "target_level"
        case challengePreference = "challenge_preference"
        case dailyMinutes = "daily_minutes"
        case reminderEnabled = "reminder_enabled"
    }
}

private struct AppSessionMutation: Encodable {
    let userID: UUID
    let clientSessionID: UUID
    let startedAt: Date
    let endedAt: Date?
    let activeSeconds: Int
    let appVersion: String?
    let platform = "ios"
    let installID: UUID?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case clientSessionID = "client_session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case activeSeconds = "active_seconds"
        case appVersion = "app_version"
        case platform
        case installID = "install_id"
    }
}

private struct LearningSessionMutation: Encodable {
    let userID: UUID
    let lessonID: UUID?
    let contentID: UUID?
    let contentKind: String
    let entryPoint: String?
    let isReplay: Bool
    let sessionKind: String
    let startedAt: Date
    let endedAt: Date?
    let activeSeconds: Int
    let completed: Bool
    let score: Double?
    let clientSessionID: UUID
    let appVersion: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case lessonID = "lesson_id"
        case contentID = "content_id"
        case contentKind = "content_kind"
        case entryPoint = "entry_point"
        case isReplay = "is_replay"
        case sessionKind = "session_kind"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case activeSeconds = "active_seconds"
        case completed
        case score
        case clientSessionID = "client_session_id"
        case appVersion = "app_version"
    }
}

private struct FlashcardSessionMutation: Encodable {
    let userID: UUID
    let clientSessionID: UUID
    let startedAt: Date
    let endedAt: Date?
    let completed: Bool
    let totalCards: Int
    let cardsPresented: Int
    let cardsAnswered: Int
    let correctCount: Int
    let activeSeconds: Int
    let score: Double?
    let appVersion: String?
    let platform = "ios"

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case clientSessionID = "client_session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case completed
        case totalCards = "total_cards"
        case cardsPresented = "cards_presented"
        case cardsAnswered = "cards_answered"
        case correctCount = "correct_count"
        case activeSeconds = "active_seconds"
        case score
        case appVersion = "app_version"
        case platform
    }
}

private struct ReviewEventMutation: Encodable {
    let userID: UUID
    let vocabularyID: UUID
    let sessionID: UUID?
    let rating: String
    let responseMilliseconds: Int?
    let previousDueAt: Date?
    let nextDueAt: Date
    let intervalDays: Int
    let occurredAt: Date
    let clientEventID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case vocabularyID = "vocabulary_id"
        case sessionID = "session_id"
        case rating
        case responseMilliseconds = "response_ms"
        case previousDueAt = "previous_due_at"
        case nextDueAt = "next_due_at"
        case intervalDays = "interval_days"
        case occurredAt = "occurred_at"
        case clientEventID = "client_event_id"
    }
}

private struct UserVocabularyMutation: Encodable {
    let userID: UUID
    let vocabularyID: UUID
    let state: String
    let mastery: Double
    let intervalDays: Int
    let dueAt: Date
    let lastReviewedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case vocabularyID = "vocabulary_id"
        case state
        case mastery
        case intervalDays = "interval_days"
        case dueAt = "due_at"
        case lastReviewedAt = "last_reviewed_at"
    }
}

private struct DailyProgressMutation: Encodable {
    let userID: UUID
    let progressDate: String
    let activeSeconds: Int
    let lessonsCompleted: Int
    let wordsLearned: Int
    let wordsReviewed: Int
    let xp: Int
    let dailyGoalMet: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case progressDate = "progress_date"
        case activeSeconds = "active_seconds"
        case lessonsCompleted = "lessons_completed"
        case wordsLearned = "words_learned"
        case wordsReviewed = "words_reviewed"
        case xp
        case dailyGoalMet = "daily_goal_met"
    }
}

struct AnalyticsEventMutation: Encodable {
    let userID: UUID
    let eventName: String
    let eventVersion: Int
    let sessionID: UUID?
    let properties: [String: String]
    let occurredAt: Date
    let clientEventID: UUID
    let screenName: String?
    let appVersion: String?
    let platform: String
    let installID: UUID?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case eventName = "event_name"
        case eventVersion = "event_version"
        case sessionID = "session_id"
        case properties
        case occurredAt = "occurred_at"
        case clientEventID = "client_event_id"
        case screenName = "screen_name"
        case appVersion = "app_version"
        case platform
        case installID = "install_id"
    }
}

private struct CancellationFeedbackMutation: Encodable {
    let userID: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case reason
    }
}

private struct SessionIdentity: Decodable {
    let id: UUID
}
