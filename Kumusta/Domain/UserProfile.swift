import Foundation

enum VietnameseAccent: String, Codable, CaseIterable, Identifiable, Sendable {
    case southern
    case northern

    var id: Self { self }
    var title: String {
        switch self {
        case .southern: L("Southern")
        case .northern: L("Northern")
        }
    }

    var region: String {
        switch self {
        case .southern: L("Ho Chi Minh City and the South")
        case .northern: L("Hanoi and the North")
        }
    }

    var sampleAudioResourceName: String {
        rawValue
    }

    var sample: String {
        switch self {
        case .southern: "Hãy nói giọng miền Nam nhe!"
        case .northern: "Hãy nói giọng miền Bắc nhé!"
        }
    }

    var elevenLabsVoiceID: String {
        switch self {
        case .southern: "6Xq32rHt6oAu98TBDKfr"
        case .northern: "LD1UihCXvSlUL4h8DOmk"
        }
    }
}

enum LearningGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case family
    case lifeInVietnam
    case travel
    case partner
    case work
    case culture

    var id: Self { self }

    var title: String {
        switch self {
        case .family: L("Talk with family")
        case .lifeInVietnam: L("Live in Vietnam")
        case .travel: L("Travel with confidence")
        case .partner: L("Connect with my partner")
        case .work: L("Use Vietnamese at work")
        case .culture: L("Reconnect with my roots")
        }
    }

    var systemImage: String {
        switch self {
        case .family: "house.and.flag.fill"
        case .lifeInVietnam: "building.2.fill"
        case .travel: "airplane"
        case .partner: "heart.fill"
        case .work: "briefcase.fill"
        case .culture: "sparkles"
        }
    }

    var commitmentCopy: String {
        switch self {
        case .family: "I want family conversations to feel natural."
        case .lifeInVietnam: "I want daily life in Vietnam to feel like mine."
        case .travel: "I want to speak up instead of pointing."
        case .partner: "I want to share more of their world."
        case .work: "I want Vietnamese to open real opportunities."
        case .culture: "I want Vietnamese to feel like home."
        }
    }
}

enum ProficiencyLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case new
    case familiar
    case conversational
    case rusty

    var id: Self { self }

    var title: String {
        switch self {
        case .new: L("Starting fresh")
        case .familiar: L("I know some words")
        case .conversational: L("I can handle basics")
        case .rusty: L("I grew up around Vietnamese")
        }
    }

    var detail: String {
        switch self {
        case .new: L("Build your ear from the first phrase")
        case .familiar: L("Turn vocabulary into quick responses")
        case .conversational: L("Sound more natural in real situations")
        case .rusty: L("Bring passive Vietnamese back into your voice")
        }
    }

    var systemImage: String {
        switch self {
        case .new: "leaf.fill"
        case .familiar: "text.bubble.fill"
        case .conversational: "person.wave.2.fill"
        case .rusty: "arrow.counterclockwise.circle.fill"
        }
    }

    /// Authored roadmap progression. Rusty is a separate heritage-entry track,
    /// not the level that follows conversational Vietnamese.
    var nextRoadmapLevel: Self? {
        switch self {
        case .new: .familiar
        case .familiar: .conversational
        case .conversational, .rusty: nil
        }
    }
}

enum DesiredProficiency: String, Codable, CaseIterable, Identifiable, Sendable {
    case practical
    case confident
    case natural

    var id: Self { self }

    var title: String {
        switch self {
        case .practical: L("Handle everyday life")
        case .confident: L("Speak with confidence")
        case .natural: L("Sound natural and flexible")
        }
    }

    var adaptiveLevel: Int {
        switch self {
        case .practical: 3
        case .confident: 4
        case .natural: 5
        }
    }
}

enum LearningChallengePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case gentle
    case balanced
    case stretch

    var id: Self { self }

    var title: String {
        switch self {
        case .gentle: L("Gentle")
        case .balanced: L("Balanced")
        case .stretch: L("Stretch me")
        }
    }
}

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var accent: VietnameseAccent
    var goal: LearningGoal
    var dailyMinutes: Int
    var level: ProficiencyLevel
    var hasCompletedOnboarding: Bool
    var currentStreak: Int
    var totalWordsLearned: Int
    /// Optional for backwards-compatible decoding of profiles saved by older builds.
    var desiredProficiency: DesiredProficiency? = nil
    var challengePreference: LearningChallengePreference? = nil
    /// A persisted, privacy-safe DiceBear seed. Older local profiles receive
    /// the deterministic fallback derived from their account ID at bootstrap.
    var avatarSeed: String? = nil

    var adaptiveTargetLevel: Int {
        let minimum: Int = switch level {
        case .new: 2
        case .familiar: 3
        case .conversational, .rusty: 4
        }
        return max(minimum, (desiredProficiency ?? .confident).adaptiveLevel)
    }

    static let newUser = UserProfile(
        id: UUID(),
        name: "",
        accent: .southern,
        goal: .family,
        dailyMinutes: 7,
        level: .new,
        hasCompletedOnboarding: false,
        currentStreak: 0,
        totalWordsLearned: 0
    )

    static let preview = UserProfile(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Alex",
        accent: .southern,
        goal: .lifeInVietnam,
        dailyMinutes: 7,
        level: .familiar,
        hasCompletedOnboarding: true,
        currentStreak: 6,
        totalWordsLearned: 84
    )
}

struct OnboardingDraft: Equatable, Sendable {
    var name = ""
    var accent: VietnameseAccent = .southern
    var goal: LearningGoal = .family
    var dailyMinutes = 7
    var level: ProficiencyLevel = .new
}
