import Foundation
import Observation

struct Achievement: Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case firstLesson = "first_lesson"
        case streak7 = "streak_7"
        case streak30 = "streak_30"
        case streak100 = "streak_100"
        case words10 = "words_10"
        case words50 = "words_50"
        case lessons5 = "lessons_5"
        case lessons20 = "lessons_20"
        case firstPronunciation = "first_pronunciation"
        case weekComplete = "week_complete"
    }

    let kind: Kind
    let unlockedAt: Date

    var id: String { kind.rawValue }

    var isUnlocked: Bool { unlockedAt != .distantFuture }

    var title: String {
        switch kind {
        case .firstLesson: L("First lesson completed")
        case .streak7: L("One week strong")
        case .streak30: L("Monthly rhythm")
        case .streak100: L("Century mark")
        case .words10: L("10 words")
        case .words50: L("50 words")
        case .lessons5: L("5 lessons")
        case .lessons20: L("20 lessons")
        case .firstPronunciation: L("Found your voice")
        case .weekComplete: L("Full week")
        }
    }

    var celebrationCopy: String {
        switch kind {
        case .firstLesson: L("Your Vietnamese journey is officially underway.")
        case .streak7: L("Seven days of showing up. That is how fluency starts.")
        case .streak30: L("A whole month of listening is now part of your rhythm.")
        case .streak100: L("One hundred days. You built a real Vietnamese habit.")
        case .words10: L("Ten useful words are ready to come back when you need them.")
        case .words50: L("Fifty words in your sound map. Your ear is getting stronger.")
        case .lessons5: L("Five focused lessons completed. You are finding your pace.")
        case .lessons20: L("Twenty lessons down. That is serious listening mileage.")
        case .firstPronunciation: L("You put Vietnamese into your own voice.")
        case .weekComplete: L("Seven lessons in one week. You are in the groove.")
        }
    }

    var xpValue: Int {
        switch kind {
        case .firstLesson: 50
        case .streak7, .words10, .lessons5: 100
        case .firstPronunciation: 125
        case .streak30, .words50, .lessons20: 250
        case .weekComplete: 300
        case .streak100: 1_000
        }
    }

    var symbol: String {
        switch kind {
        case .firstLesson: "checkmark.seal.fill"
        case .streak7: "flame.fill"
        case .streak30: "flame.circle.fill"
        case .streak100: "crown.fill"
        case .words10: "character.book.closed.fill"
        case .words50: "books.vertical.fill"
        case .lessons5: "headphones"
        case .lessons20: "ear.fill"
        case .firstPronunciation: "mic.fill"
        case .weekComplete: "calendar.badge.checkmark"
        }
    }
}

@MainActor
@Observable
final class AchievementStore {
    private enum Keys {
        static let unlocked = "kumusta.achievements.v1"
    }

    private let defaults: UserDefaults
    private(set) var achievements: [Achievement] = []

    /// All possible achievements, with locked ones included for motivation.
    var allAchievements: [Achievement] {
        Achievement.Kind.allCases.map { kind in
            achievements.first { $0.kind == kind } ?? Achievement(kind: kind, unlockedAt: .distantFuture)
        }.sorted { a, b in
            let aUnlocked = a.unlockedAt != .distantFuture
            let bUnlocked = b.unlockedAt != .distantFuture
            if aUnlocked != bUnlocked { return aUnlocked }
            return a.unlockedAt > b.unlockedAt
        }
    }

    var unlockedCount: Int { achievements.count }
    var totalCount: Int { Achievement.Kind.allCases.count }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func replace(with achievements: [Achievement]) {
        self.achievements = achievements
            .filter { $0.isUnlocked }
            .reduce(into: [Achievement]()) { result, achievement in
                guard !result.contains(where: { $0.kind == achievement.kind }) else { return }
                result.append(achievement)
            }
        persist()
    }

    /// Check and unlock any newly earned achievements.
    /// Call after relevant user actions.
    @discardableResult
    func evaluate(
        streak: Int,
        lessonsCompleted: Int,
        wordsMastered: Int,
        hasDonePronunciation: Bool
    ) -> [Achievement] {
        let now = Date.now
        var newAchievements: [Achievement] = []

        func unlock(_ kind: Achievement.Kind) {
            guard !achievements.contains(where: { $0.kind == kind }) else { return }
            newAchievements.append(Achievement(kind: kind, unlockedAt: now))
        }

        if lessonsCompleted >= 1 { unlock(.firstLesson) }
        if streak >= 7 { unlock(.streak7) }
        if streak >= 30 { unlock(.streak30) }
        if streak >= 100 { unlock(.streak100) }
        if wordsMastered >= 10 { unlock(.words10) }
        if wordsMastered >= 50 { unlock(.words50) }
        if lessonsCompleted >= 5 { unlock(.lessons5) }
        if lessonsCompleted >= 20 { unlock(.lessons20) }
        if hasDonePronunciation { unlock(.firstPronunciation) }
        if streak >= 7, lessonsCompleted >= 7 { unlock(.weekComplete) }

        if !newAchievements.isEmpty {
            achievements.append(contentsOf: newAchievements)
            persist()
        }

        return newAchievements
    }

    func reset() {
        achievements = []
        defaults.removeObject(forKey: Keys.unlocked)
    }

    private func load() {
        guard
            let data = defaults.data(forKey: Keys.unlocked),
            let saved = try? JSONDecoder().decode([Achievement].self, from: data)
        else { return }
        achievements = saved
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(achievements) else { return }
        defaults.set(data, forKey: Keys.unlocked)
    }
}

extension Achievement: Codable {
    enum CodingKeys: String, CodingKey {
        case kind, unlockedAt
    }
}
