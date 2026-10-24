import Foundation

protocol LearningRepository: Sendable {
    func todayLesson(
        accent: VietnameseAccent,
        level: ProficiencyLevel,
        dailyMinutes: Int
    ) async throws -> Lesson
    func vocabulary(accent: VietnameseAccent) async throws -> [VocabularyItem]
    func setVocabularySaved(itemID: UUID, isSaved: Bool) async throws
    func recordReview(itemID: UUID, rating: ReviewRating) async throws
    func authoredVocabularySnapshot() async -> [String: AuthoredVocabularyState]
    func replaceAuthoredVocabulary(with states: [String: AuthoredVocabularyState]) async
    func reset() async
}

struct AuthoredVocabularyState: Codable, Equatable, Sendable {
    let mastery: Double
    let nextReviewAt: Date
    let isSaved: Bool
}

extension LearningRepository {
    func authoredVocabularySnapshot() async -> [String: AuthoredVocabularyState] { [:] }
    func replaceAuthoredVocabulary(with states: [String: AuthoredVocabularyState]) async { _ = states }
    func reset() async {}
}

enum LearningRepositoryError: LocalizedError, Equatable, Sendable {
    case vocabularyNotFound

    var errorDescription: String? {
        switch self {
        case .vocabularyNotFound:
            L("That phrase is no longer available.")
        }
    }
}

actor SeededLearningRepository: LearningRepository {
    static let persistedStateKey = "kumusta.authored-vocabulary-state.v1"

    private let defaults: UserDefaults
    private let referenceDate: Date
    private var items: [VocabularyItem]

    init(
        defaultsSuiteName: String? = nil,
        referenceDate: Date = .now
    ) {
        let defaults: UserDefaults
        if let defaultsSuiteName {
            defaults = UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        } else {
            defaults = .standard
        }
        self.referenceDate = referenceDate
        self.defaults = defaults
        var items = VietnameseAccent.allCases.flatMap {
            SampleContent.vocabulary(for: $0, referenceDate: referenceDate)
        }
        if
            let data = defaults.data(forKey: Self.persistedStateKey),
            let states = try? JSONDecoder().decode(
                [String: AuthoredVocabularyState].self,
                from: data
            )
        {
            for index in items.indices {
                guard let state = states[items[index].id.uuidString] else { continue }
                items[index].mastery = min(1, max(0, state.mastery))
                items[index].nextReviewAt = state.nextReviewAt
                items[index].isSaved = state.isSaved
            }
        }
        self.items = items
    }

    func todayLesson(
        accent: VietnameseAccent,
        level: ProficiencyLevel,
        dailyMinutes: Int
    ) async throws -> Lesson {
        SampleContent.dailySession(
            accent: accent,
            level: level,
            dailyMinutes: dailyMinutes
        )
    }

    func vocabulary(accent: VietnameseAccent) async throws -> [VocabularyItem] {
        items.filter { $0.accent == accent }
    }

    func setVocabularySaved(itemID: UUID, isSaved: Bool) async throws {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw LearningRepositoryError.vocabularyNotFound
        }
        items[index].isSaved = isSaved
        persistState()
    }

    func recordReview(itemID: UUID, rating: ReviewRating) async throws {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw LearningRepositoryError.vocabularyNotFound
        }
        let interval: TimeInterval = switch rating {
        case .again: 30
        case .almost: 86_400
        case .gotIt: 345_600
        }
        items[index].nextReviewAt = .now.addingTimeInterval(interval)
        items[index].mastery = min(
            1,
            max(0, items[index].mastery + (rating == .gotIt ? 0.12 : rating == .almost ? 0.03 : -0.08))
        )
        persistState()
    }

    func authoredVocabularySnapshot() -> [String: AuthoredVocabularyState] {
        Dictionary(uniqueKeysWithValues: items.map { item in
            (
                item.id.uuidString,
                AuthoredVocabularyState(
                    mastery: item.mastery,
                    nextReviewAt: item.nextReviewAt,
                    isSaved: item.isSaved
                )
            )
        })
    }

    func replaceAuthoredVocabulary(with states: [String: AuthoredVocabularyState]) {
        for index in items.indices {
            guard let state = states[items[index].id.uuidString] else { continue }
            items[index].mastery = min(1, max(0, state.mastery))
            items[index].nextReviewAt = state.nextReviewAt
            items[index].isSaved = state.isSaved
        }
        persistState()
    }

    func reset() async {
        defaults.removeObject(forKey: Self.persistedStateKey)
        items = VietnameseAccent.allCases.flatMap {
            SampleContent.vocabulary(for: $0, referenceDate: referenceDate)
        }
    }

    private func persistState() {
        let states = Dictionary(uniqueKeysWithValues: items.map { item in
            (
                item.id.uuidString,
                AuthoredVocabularyState(
                    mastery: item.mastery,
                    nextReviewAt: item.nextReviewAt,
                    isSaved: item.isSaved
                )
            )
        })
        guard let data = try? JSONEncoder().encode(states) else { return }
        defaults.set(data, forKey: Self.persistedStateKey)
    }
}
