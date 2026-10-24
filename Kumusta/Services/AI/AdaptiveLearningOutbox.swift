import Foundation

struct AdaptiveLearnerSnapshot: Codable, Equatable, Sendable {
    let goal: String
    let selfAssessedLevel: String
    let targetLevel: Int
    let challengePreference: String
    let dailyMinutes: Int

    init(profile: UserProfile) {
        goal = profile.goal.rawValue
        selfAssessedLevel = profile.level.rawValue
        targetLevel = profile.adaptiveTargetLevel
        challengePreference = (profile.challengePreference ?? .balanced).rawValue
        dailyMinutes = profile.dailyMinutes
    }

    enum CodingKeys: String, CodingKey {
        case goal
        case selfAssessedLevel = "self_assessed_level"
        case targetLevel = "target_level"
        case challengePreference = "challenge_preference"
        case dailyMinutes = "daily_minutes"
    }
}

struct AdaptiveLearningOutboxEvent: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case lessonCompletion
        case vocabularyReview
    }

    let id: UUID
    let userID: UUID
    let createdAt: Date
    let kind: Kind
    let generatedLessonID: UUID?
    let vocabularyID: UUID?
    let difficultyFeedback: String?
    let paceFeedback: String?
    let nextLessonTopic: String?
    let reviewRating: String?
    let profile: AdaptiveLearnerSnapshot

    static func lessonCompletion(
        userID: UUID,
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) -> Self {
        Self(
            id: id,
            userID: userID,
            createdAt: createdAt,
            kind: .lessonCompletion,
            generatedLessonID: generatedLessonID,
            vocabularyID: nil,
            difficultyFeedback: feedback.difficulty.rawValue,
            paceFeedback: feedback.audioPace.rawValue,
            nextLessonTopic: feedback.nextLessonTopic,
            reviewRating: nil,
            profile: AdaptiveLearnerSnapshot(profile: profile)
        )
    }

    static func vocabularyReview(
        userID: UUID,
        generatedLessonID: UUID,
        vocabularyID: UUID,
        rating: String,
        profile: UserProfile,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) -> Self {
        Self(
            id: id,
            userID: userID,
            createdAt: createdAt,
            kind: .vocabularyReview,
            generatedLessonID: generatedLessonID,
            vocabularyID: vocabularyID,
            difficultyFeedback: nil,
            paceFeedback: nil,
            nextLessonTopic: nil,
            reviewRating: rating,
            profile: AdaptiveLearnerSnapshot(profile: profile)
        )
    }
}

enum AdaptiveLearningOutboxError: Error, Sendable {
    case capacityReached
}

/// A small durable outbox for idempotent adaptive mutations. Events survive
/// process termination and retain the same client event ID across every retry.
// UserDefaults documents thread-safe access. The production instance is also
// owned and serialized by SupabaseAdaptiveLessonService's actor.
struct AdaptiveLearningOutboxStore: @unchecked Sendable {
    static let storageKey = "kumusta.adaptive-learning.outbox.v1"
    static let maximumEventCount = 200

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func events(for userID: UUID) -> [AdaptiveLearningOutboxEvent] {
        allEvents()
            .filter { $0.userID == userID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func enqueue(_ event: AdaptiveLearningOutboxEvent) throws {
        var events = allEvents()
        guard !events.contains(where: { $0.id == event.id }) else { return }
        guard events.count < Self.maximumEventCount else {
            throw AdaptiveLearningOutboxError.capacityReached
        }
        events.append(event)
        try persist(events)
    }

    func remove(id: UUID) throws {
        let events = allEvents().filter { $0.id != id }
        try persist(events)
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func allEvents() -> [AdaptiveLearningOutboxEvent] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        return (try? decoder.decode([AdaptiveLearningOutboxEvent].self, from: data)) ?? []
    }

    private func persist(_ events: [AdaptiveLearningOutboxEvent]) throws {
        if events.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(try encoder.encode(events), forKey: Self.storageKey)
        }
    }
}
