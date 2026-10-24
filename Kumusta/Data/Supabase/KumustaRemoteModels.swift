import Foundation

struct CloudUserState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let updatedAt: Date
    let profile: UserProfile
    let learningJourney: LearningJourneySnapshot
    let savedLessonWords: [SavedLessonWord]
    let lessonProgress: [LessonProgressRecord]
    let learningActivity: LearningActivityStoreSnapshot
    let firstSteps: FirstStepsCourseSnapshot
    let achievements: [Achievement]
    let authoredVocabulary: [String: AuthoredVocabularyState]
    let audioPreferences: AudioPreferences
    let notificationPreferences: NotificationPreferencesSnapshot
    let hasClaimedFirstExperiencePrompt: Bool
    let hasSeenLessonFormatEducation: Bool
    /// Review memory. Optional so states written by older builds, which do
    /// not have it, still decode; those builds also ignore it when reading.
    let memory: MemorySnapshot?

    init(
        profile: UserProfile,
        learningJourney: LearningJourneySnapshot,
        savedLessonWords: [SavedLessonWord],
        lessonProgress: [LessonProgressRecord],
        learningActivity: LearningActivityStoreSnapshot,
        firstSteps: FirstStepsCourseSnapshot,
        achievements: [Achievement],
        authoredVocabulary: [String: AuthoredVocabularyState],
        audioPreferences: AudioPreferences,
        notificationPreferences: NotificationPreferencesSnapshot,
        hasClaimedFirstExperiencePrompt: Bool,
        hasSeenLessonFormatEducation: Bool,
        memory: MemorySnapshot? = nil,
        updatedAt: Date = .now
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.updatedAt = updatedAt
        self.profile = profile
        self.learningJourney = learningJourney
        self.savedLessonWords = savedLessonWords
        self.lessonProgress = lessonProgress
        self.learningActivity = learningActivity
        self.firstSteps = firstSteps
        self.achievements = achievements
        self.authoredVocabulary = authoredVocabulary
        self.audioPreferences = audioPreferences
        self.notificationPreferences = notificationPreferences
        self.hasClaimedFirstExperiencePrompt = hasClaimedFirstExperiencePrompt
        self.hasSeenLessonFormatEducation = hasSeenLessonFormatEducation
        self.memory = memory
    }
}

struct RemoteUserState: Codable, Equatable, Sendable {
    let userID: UUID
    let schemaVersion: Int
    let state: CloudUserState
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case schemaVersion = "schema_version"
        case state
        case updatedAt = "updated_at"
    }
}

struct RemoteProfile: Codable, Equatable, Sendable {
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

struct RemoteLearningPreferences: Codable, Equatable, Sendable {
    let accent: String

    enum CodingKeys: String, CodingKey {
        case accent
    }
}

struct OnboardingSyncInput: Equatable, Sendable {
    let motivation: String?
    let desiredOutcome: String?
    let referralSource: String?
    let currentStep: Int
    let demoCompleted: Bool
    let paywallSeenAt: Date?
    let completedAt: Date?

    init(
        motivation: String? = nil,
        desiredOutcome: String? = nil,
        referralSource: String? = nil,
        currentStep: Int,
        demoCompleted: Bool,
        paywallSeenAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.motivation = motivation
        self.desiredOutcome = desiredOutcome
        self.referralSource = referralSource
        self.currentStep = currentStep
        self.demoCompleted = demoCompleted
        self.paywallSeenAt = paywallSeenAt
        self.completedAt = completedAt
    }
}

enum RemoteSessionKind: String, Codable, Sendable {
    case today
    case lesson
    case practice
    case words
}

enum RemoteLearningContentKind: String, Codable, Sendable {
    case authored
    case goal
    case generated
    case unknown
}

struct LearningSessionSyncInput: Equatable, Sendable {
    let clientSessionID: UUID
    let lessonID: UUID?
    let contentKind: RemoteLearningContentKind
    let entryPoint: String?
    let isReplay: Bool
    let kind: RemoteSessionKind
    let startedAt: Date
    let endedAt: Date?
    let activeSeconds: Int
    let completed: Bool
    let score: Double?
    let appVersion: String?

    init(
        clientSessionID: UUID,
        lessonID: UUID? = nil,
        contentKind: RemoteLearningContentKind = .unknown,
        entryPoint: String? = nil,
        isReplay: Bool = false,
        kind: RemoteSessionKind,
        startedAt: Date,
        endedAt: Date? = nil,
        activeSeconds: Int,
        completed: Bool,
        score: Double? = nil,
        appVersion: String? = nil
    ) {
        self.clientSessionID = clientSessionID
        self.lessonID = lessonID
        self.contentKind = contentKind
        self.entryPoint = entryPoint
        self.isReplay = isReplay
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.completed = completed
        self.score = score
        self.appVersion = appVersion
    }
}

struct RemoteLearningSession: Codable, Equatable, Sendable {
    let id: UUID
    let clientSessionID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case clientSessionID = "client_session_id"
    }
}

struct RemoteLeaderboardEntry: Codable, Equatable, Identifiable, Sendable {
    let periodKind: String
    let periodKey: String
    let leaderboardRank: Int64
    let userID: UUID
    let displayName: String?
    let avatarSeed: String?
    let xp: Int64
    let updatedAt: Date

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case periodKind = "period_kind"
        case periodKey = "period_key"
        case leaderboardRank = "leaderboard_rank"
        case userID = "user_id"
        case displayName = "display_name"
        case avatarSeed = "avatar_seed"
        case xp
        case updatedAt = "updated_at"
    }
}

struct RemoteLeaderboardSnapshot: Equatable, Sendable {
    let entries: [RemoteLeaderboardEntry]
    let currentUserID: UUID
}

struct ReviewSyncInput: Equatable, Sendable {
    let clientEventID: UUID
    let vocabularyID: UUID
    let clientSessionID: UUID?
    let rating: ReviewRating
    let responseMilliseconds: Int?
    let previousDueAt: Date?
    let nextDueAt: Date
    let intervalDays: Int
    let mastery: Double
}

struct AppSessionSyncInput: Equatable, Sendable {
    let clientSessionID: UUID
    let startedAt: Date
    let endedAt: Date?
    let activeSeconds: Int
    let appVersion: String?
    let installID: UUID?

    init(
        clientSessionID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        activeSeconds: Int = 0,
        appVersion: String? = nil,
        installID: UUID? = nil
    ) {
        self.clientSessionID = clientSessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.appVersion = appVersion
        self.installID = installID
    }
}

struct RemoteAppSession: Codable, Equatable, Sendable {
    let id: UUID
    let clientSessionID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case clientSessionID = "client_session_id"
    }
}

struct FlashcardSessionSyncInput: Equatable, Sendable {
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

    init(
        clientSessionID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        completed: Bool = false,
        totalCards: Int,
        cardsPresented: Int,
        cardsAnswered: Int,
        correctCount: Int,
        activeSeconds: Int,
        score: Double? = nil,
        appVersion: String? = nil
    ) {
        self.clientSessionID = clientSessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completed = completed
        self.totalCards = totalCards
        self.cardsPresented = cardsPresented
        self.cardsAnswered = cardsAnswered
        self.correctCount = correctCount
        self.activeSeconds = activeSeconds
        self.score = score
        self.appVersion = appVersion
    }
}

struct RemoteFlashcardSession: Codable, Equatable, Sendable {
    let id: UUID
    let clientSessionID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case clientSessionID = "client_session_id"
    }
}

struct DailyProgressSyncInput: Equatable, Sendable {
    let progressDate: String
    let activeSeconds: Int
    let lessonsCompleted: Int
    let wordsLearned: Int
    let wordsReviewed: Int
    let xp: Int
    let dailyGoalMet: Bool
}

struct XPAwardRequest: Encodable, Sendable {
    let reasonCode: String
    let sourceID: String?
    let idempotencyKey: String
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case reasonCode = "reason_code"
        case sourceID = "source_id"
        case idempotencyKey = "idempotency_key"
        case metadata
    }
}

struct XPAwardResponse: Decodable, Equatable, Sendable {
    let eventID: UUID?
    let amount: Int
    let lifetimeXP: Int64
    let weekXP: Int64
    let monthXP: Int64
    let wasDuplicate: Bool

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case amount
        case lifetimeXP = "lifetime_xp"
        case weekXP = "week_xp"
        case monthXP = "month_xp"
        case wasDuplicate = "was_duplicate"
    }
}

struct AnalyticsSyncInput: Codable, Equatable, Sendable {
    let clientEventID: UUID
    let eventName: String
    let eventVersion: Int
    let clientSessionID: UUID?
    let properties: [String: String]
    let occurredAt: Date
    let screenName: String?
    let appVersion: String?
    let platform: String
    let installID: UUID?

    init(
        clientEventID: UUID = UUID(),
        eventName: String,
        eventVersion: Int = 1,
        clientSessionID: UUID? = nil,
        properties: [String: String] = [:],
        occurredAt: Date = .now,
        screenName: String? = nil,
        appVersion: String? = nil,
        platform: String = "ios",
        installID: UUID? = nil
    ) {
        self.clientEventID = clientEventID
        self.eventName = eventName
        self.eventVersion = eventVersion
        self.clientSessionID = clientSessionID
        self.properties = properties
        self.occurredAt = occurredAt
        self.screenName = screenName
        self.appVersion = appVersion
        self.platform = platform
        self.installID = installID
    }
}

struct RemoteEntitlement: Codable, Equatable, Sendable {
    let entitlementID: String
    let isActive: Bool
    let productID: String?
    let expiresAt: Date?
    let willRenew: Bool?

    enum CodingKeys: String, CodingKey {
        case entitlementID = "entitlement_id"
        case isActive = "is_active"
        case productID = "product_id"
        case expiresAt = "expires_at"
        case willRenew = "will_renew"
    }
}
