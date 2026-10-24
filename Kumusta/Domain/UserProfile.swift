import Foundation

enum LearningGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case family
    case lifeInThePhilippines
    case travel
    case partner
    case work
    case culture

    var id: Self { self }

    var title: String {
        switch self {
        case .family: L("Talk with family")
        case .lifeInThePhilippines: L("Live in the Philippines")
        case .travel: L("Travel with confidence")
        case .partner: L("Connect with my partner")
        case .work: L("Use Tagalog at work")
        case .culture: L("Reconnect with my roots")
        }
    }

    var systemImage: String {
        switch self {
        case .family: "house.and.flag.fill"
        case .lifeInThePhilippines: "building.2.fill"
        case .travel: "airplane"
        case .partner: "heart.fill"
        case .work: "briefcase.fill"
        case .culture: "sparkles"
        }
    }

    var commitmentCopy: String {
        switch self {
        case .family: "I want family conversations to feel natural."
        case .lifeInThePhilippines: "I want daily life in the Philippines to feel like mine."
        case .travel: "I want to speak up instead of pointing."
        case .partner: "I want to share more of their world."
        case .work: "I want Tagalog to open real opportunities."
        case .culture: "I want Tagalog to feel like home."
        }
    }
}

enum ProficiencyLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner
    case intermediate
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .beginner: L("Starting fresh")
        case .intermediate: L("I can handle basics")
        case .advanced: L("I can hold a conversation")
        }
    }

    var detail: String {
        switch self {
        case .beginner: L("Build your ear from the first phrase")
        case .intermediate: L("Turn what you know into quick responses")
        case .advanced: L("Sound more natural in real situations")
        }
    }

    var systemImage: String {
        switch self {
        case .beginner: "leaf.fill"
        case .intermediate: "text.bubble.fill"
        case .advanced: "person.wave.2.fill"
        }
    }

    /// Authored roadmap progression: beginner, then intermediate, then advanced.
    var nextRoadmapLevel: Self? {
        switch self {
        case .beginner: .intermediate
        case .intermediate: .advanced
        case .advanced: nil
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
        case .beginner: 2
        case .intermediate: 3
        case .advanced: 4
        }
        return max(minimum, (desiredProficiency ?? .confident).adaptiveLevel)
    }

    static let newUser = UserProfile(
        id: UUID(),
        name: "",
        goal: .family,
        dailyMinutes: 7,
        level: .beginner,
        hasCompletedOnboarding: false,
        currentStreak: 0,
        totalWordsLearned: 0
    )

    static let preview = UserProfile(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Alex",
        goal: .lifeInThePhilippines,
        dailyMinutes: 7,
        level: .intermediate,
        hasCompletedOnboarding: true,
        currentStreak: 6,
        totalWordsLearned: 84
    )
}

struct OnboardingDraft: Equatable, Sendable {
    var name = ""
    var goal: LearningGoal = .family
    var dailyMinutes = 7
    var level: ProficiencyLevel = .beginner
}
