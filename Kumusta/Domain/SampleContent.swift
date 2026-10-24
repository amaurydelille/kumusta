import CryptoKit
import Foundation

/// Offline, preview and test content. It is derived from the bundled authored
/// Tagalog roadmap so the app never carries a second, hand-maintained copy of
/// lesson text.
enum SampleContent {
    /// The first beginner roadmap lesson, used by previews.
    static var coffeeLesson: Lesson { lessonCatalog().first! }

    /// A session sized to the learner's daily minutes, assembled from the
    /// level's roadmap rounds in order.
    static func dailySession(
        level: ProficiencyLevel,
        dailyMinutes: Int
    ) -> Lesson {
        let supportedMinutes = min(15, max(5, dailyMinutes))
        let targetRounds = LessonSessionPlan.roundCount(for: supportedMinutes)
        let lessons = lessonCatalog(level: level)
        let rounds = lessons.flatMap { lesson in
            stride(from: 0, to: lesson.steps.count, by: LessonSessionPlan.stagesPerRound).map {
                Array(lesson.steps[$0..<min($0 + LessonSessionPlan.stagesPerRound, lesson.steps.count)])
            }
        }
        return Lesson(
            id: deterministicUUID("daily-session:\(level.rawValue):\(supportedMinutes)"),
            scenario: lessons.first?.scenario ?? L("First conversations"),
            minutes: supportedMinutes,
            steps: rounds.prefix(targetRounds).flatMap { $0 }
        )
    }

    static func lessonCatalog(level: ProficiencyLevel = .beginner) -> [Lesson] {
        ((try? RoadmapCatalog.load(level: level)) ?? []).map(\.lesson)
    }

    static var vocabulary: [VocabularyItem] {
        vocabulary()
    }

    /// Every unique vocabulary item of the beginner roadmap, due for review
    /// at `referenceDate`.
    static func vocabulary(referenceDate: Date = .now) -> [VocabularyItem] {
        var seen = Set<String>()
        return bundledVocabulary.compactMap { entry in
            let key = entry.tagalog.lowercased(with: Locale(identifier: "fil"))
            guard seen.insert(key).inserted else { return nil }
            return VocabularyItem(
                id: deterministicUUID("vocabulary:\(key)"),
                tagalog: entry.tagalog,
                english: entry.english,
                example: entry.example,
                exampleTranslation: entry.exampleTranslation,
                mastery: 0.05,
                nextReviewAt: referenceDate,
                isSaved: false
            )
        }
    }

    private static let bundledVocabulary: [VocabularyEntry] = {
        guard
            let url = Bundle.main.url(forResource: "beginner-tagalog-v1", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONDecoder().decode(VocabularyRoot.self, from: data)
        else { return [] }
        return root.lessons
            .sorted { $0.lessonOrder < $1.lessonOrder }
            .flatMap(\.content.vocabulary)
    }()

    private static func deterministicUUID(_ seed: String) -> UUID {
        let digest = SHA256.hash(data: Data("kumusta.sample:\(seed)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let characters = Array(hex)
        let value = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32]
            .map { String(characters[$0]) }
            .joined(separator: "-")
        return UUID(uuidString: value)!
    }
}

private struct VocabularyRoot: Decodable {
    let lessons: [VocabularyLesson]
}

private struct VocabularyLesson: Decodable {
    let lessonOrder: Int
    let content: VocabularyContent
}

private struct VocabularyContent: Decodable {
    let vocabulary: [VocabularyEntry]
}

private struct VocabularyEntry: Decodable {
    let tagalog: String
    let english: String
    let example: String
    let exampleTranslation: String
}
