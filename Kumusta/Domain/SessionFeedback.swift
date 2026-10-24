import Foundation

enum LessonDifficultyFeedback: String, Codable, CaseIterable, Identifiable, Sendable {
    case tooEasy = "too_easy"
    case justRight = "just_right"
    case tooHard = "too_hard"

    var id: Self { self }

    var title: String {
        switch self {
        case .tooEasy: L("Too easy")
        case .justRight: L("Just right")
        case .tooHard: L("Too hard")
        }
    }
}

enum AudioPaceFeedback: String, Codable, CaseIterable, Identifiable, Sendable {
    case tooSlow = "too_slow"
    case justRight = "pace_right"
    case tooFast = "too_fast"

    var id: Self { self }

    var title: String {
        switch self {
        case .tooSlow: L("Too slow")
        case .justRight: L("Just right")
        case .tooFast: L("Too fast")
        }
    }
}

struct SessionFeedback: Equatable, Sendable {
    let difficulty: LessonDifficultyFeedback
    let audioPace: AudioPaceFeedback
    let nextLessonTopic: String?

    init(
        difficulty: LessonDifficultyFeedback,
        audioPace: AudioPaceFeedback,
        nextLessonTopic: String? = nil
    ) {
        self.difficulty = difficulty
        self.audioPace = audioPace
        self.nextLessonTopic = nextLessonTopic
    }

    static let neutral = SessionFeedback(
        difficulty: .justRight,
        audioPace: .justRight
    )
}

enum NextLessonTopicPreference {
    static let maximumLength = 200

    enum ValidationError: LocalizedError, Equatable {
        case tooShort
        case tooLong
        case unsupportedCharacters
        case instructionLikeContent

        var errorDescription: String? {
            switch self {
            case .tooShort:
                L("Add a little more detail, or leave this blank.")
            case .tooLong:
                L("Keep the topic under %lld characters.", maximumLength)
            case .unsupportedCharacters:
                L("Use a simple topic, without code or special formatting.")
            case .instructionLikeContent:
                L("Describe a real-life situation, not instructions for the lesson generator.")
            }
        }
    }

    static func validated(_ rawValue: String) throws -> String? {
        let normalized = rawValue
            .precomposedStringWithCompatibilityMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !normalized.isEmpty else { return nil }
        guard normalized.count >= 3 else { throw ValidationError.tooShort }
        guard normalized.count <= maximumLength else { throw ValidationError.tooLong }
        guard normalized.unicodeScalars.allSatisfy(isAllowed) else {
            throw ValidationError.unsupportedCharacters
        }

        let folded = normalized.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let blockedFragments = [
            "ignore previous", "ignore all", "disregard previous",
            "system prompt", "developer message", "assistant message",
            "return json", "output schema", "jailbreak", "prompt injection"
        ]
        guard !blockedFragments.contains(where: folded.contains) else {
            throw ValidationError.instructionLikeContent
        }
        return normalized
    }

    private static func isAllowed(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet.letters.contains(scalar)
            || CharacterSet.decimalDigits.contains(scalar)
            || CharacterSet.whitespaces.contains(scalar)
            || ",.'’&/()-".unicodeScalars.contains(scalar)
    }
}
