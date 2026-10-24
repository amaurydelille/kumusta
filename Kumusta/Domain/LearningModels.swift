import Foundation

struct Lesson: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let scenario: String
    let minutes: Int
    let steps: [LessonStep]
    /// The English title when `scenario` holds a translation. Ad SDK events
    /// keep reporting the English title so campaigns don't split by language.
    /// Nil (and never encoded) for untranslated lessons.
    var sourceScenario: String? = nil

    var analyticsScenario: String { sourceScenario ?? scenario }

    var roundCount: Int {
        max(1, Int(ceil(Double(steps.count) / Double(LessonSessionPlan.stagesPerRound))))
    }

    var decodedChunkCount: Int {
        steps
            .filter { $0.kind == .decode }
            .reduce(0) { $0 + $1.chunks.count }
    }
}

enum LessonSessionPlan {
    static let stagesPerRound = 3

    /// One distinct oral round per selected minute keeps short plans honest.
    /// The longest plan uses twelve substantial rounds rather than padding the
    /// session with repeated copy; recording and feedback bring it near the
    /// selected fifteen-minute budget.
    static func roundCount(for dailyMinutes: Int) -> Int {
        min(12, max(5, dailyMinutes))
    }

    static func hearRespondRoundIndexes(for roundCount: Int) -> Set<Int> {
        switch roundCount {
        case 10...:
            [4, 7]
        default:
            [2, 4]
        }
    }

    /// Prompt v11 lessons contained one response round for 7–9 minute plans.
    /// Keep that layout readable while the generator rolls out the two-round plan.
    static func legacyHearRespondRoundIndexes(for roundCount: Int) -> Set<Int> {
        switch roundCount {
        case 10...:
            [4, 7]
        case 7...:
            [4]
        default:
            [2]
        }
    }
}

enum LessonStepKind: String, Codable, Sendable {
    case coldListen
    case decode
    case hearRespond
    case speak
}

struct HearRespondExercise: Codable, Equatable, Sendable {
    let promptTagalog: String
    let promptTranslation: String
    let options: [HearRespondOption]
    let correctOptionID: UUID

    var correctOption: HearRespondOption? {
        options.first { $0.id == correctOptionID }
    }

    func randomizedOptions<R: RandomNumberGenerator>(using generator: inout R) -> [HearRespondOption] {
        var randomized = options
        randomized.shuffle(using: &generator)
        if randomized.first?.id == correctOptionID,
           let firstIncorrectIndex = randomized.firstIndex(where: { $0.id != correctOptionID }) {
            randomized.swapAt(0, firstIncorrectIndex)
        }
        return randomized
    }

    private enum CodingKeys: String, CodingKey {
        case promptTagalog = "prompt_tagalog"
        case promptTranslation = "prompt_translation"
        case options
        case correctOptionID = "correct_option_id"
    }
}

struct HearRespondOption: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let englishTranslation: String

    private enum CodingKeys: String, CodingKey {
        case id
        case englishTranslation = "english_translation"
    }
}

struct LessonStep: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: LessonStepKind
    let prompt: String
    let tagalog: String
    let translation: String
    let chunks: [PhraseChunk]
    let wordGlosses: [LessonWordGloss]
    let hearRespond: HearRespondExercise?

    init(
        id: UUID,
        kind: LessonStepKind,
        prompt: String,
        tagalog: String,
        translation: String,
        chunks: [PhraseChunk],
        wordGlosses: [LessonWordGloss] = [],
        hearRespond: HearRespondExercise? = nil
    ) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.tagalog = tagalog
        self.translation = translation
        self.chunks = chunks
        self.wordGlosses = wordGlosses
        self.hearRespond = hearRespond
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, prompt, tagalog, translation, chunks, wordGlosses, hearRespond
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(LessonStepKind.self, forKey: .kind)
        prompt = try container.decode(String.self, forKey: .prompt)
        tagalog = try container.decode(String.self, forKey: .tagalog)
        translation = try container.decode(String.self, forKey: .translation)
        chunks = try container.decode([PhraseChunk].self, forKey: .chunks)
        wordGlosses = try container.decodeIfPresent(
            [LessonWordGloss].self,
            forKey: .wordGlosses
        ) ?? []
        hearRespond = try container.decodeIfPresent(
            HearRespondExercise.self,
            forKey: .hearRespond
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(tagalog, forKey: .tagalog)
        try container.encode(translation, forKey: .translation)
        try container.encode(chunks, forKey: .chunks)
        try container.encode(wordGlosses, forKey: .wordGlosses)
        try container.encodeIfPresent(hearRespond, forKey: .hearRespond)
    }
}

struct LessonWordGloss: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let token: String
    let translation: String
}

struct PhraseChunk: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let tagalog: String
    let english: String
    let note: String
}

enum ReviewRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case again
    case almost
    case gotIt

    var id: Self { self }

    var title: String {
        switch self {
        case .again: L("Again")
        case .almost: L("Almost got it")
        case .gotIt: L("Got it")
        }
    }

    var intervalLabel: String {
        switch self {
        case .again: L("30 seconds")
        case .almost: L("Tomorrow")
        case .gotIt: L("4 days")
        }
    }

    var systemImage: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .almost: "circle.lefthalf.filled"
        case .gotIt: "checkmark"
        }
    }
}

struct VocabularyItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let tagalog: String
    let english: String
    let example: String
    let exampleTranslation: String
    var mastery: Double
    var nextReviewAt: Date
    var isSaved: Bool
}

enum AnalyticsEvent: String, CaseIterable, Sendable {
    case appOpened = "app_opened"
    case screenViewed = "screen_viewed"
    case tabSelected = "tab_selected"
    case accountActionStarted = "account_action_started"
    case accountActionCompleted = "account_action_completed"
    case accountActionFailed = "account_action_failed"
    case profileUpdated = "profile_updated"
    case settingChanged = "setting_changed"
    case featureAction = "feature_action"
    case paywallDismissed = "paywall_dismissed"
    case purchaseStarted = "purchase_started"
    case purchaseCancelled = "purchase_cancelled"
    case restoreStarted = "restore_started"
    case restoreFailed = "restore_failed"
    case onboardingStarted = "onboarding_started"
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingOptionSelected = "onboarding_option_selected"
    case onboardingStepCompleted = "onboarding_step_completed"
    case onboardingAbandoned = "onboarding_abandoned"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSaveFailed = "onboarding_save_failed"
    case valueDemoCompleted = "value_demo_completed"
    case paywallViewed = "paywall_viewed"
    case trialStarted = "trial_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case restoreCompleted = "restore_completed"
    case lessonStarted = "lesson_started"
    case lessonOpened = "lesson_opened"
    case lessonStepViewed = "lesson_step_viewed"
    case lessonStepCompleted = "lesson_step_completed"
    case lessonAudioPlayed = "lesson_audio_played"
    case lessonPhraseRevealed = "lesson_phrase_revealed"
    case lessonAnswerSubmitted = "lesson_answer_submitted"
    case lessonRecordingStarted = "lesson_recording_started"
    case lessonRecordingCompleted = "lesson_recording_completed"
    case lessonPronunciationEvaluated = "lesson_pronunciation_evaluated"
    case lessonSpeakingSkipped = "lesson_speaking_skipped"
    case lessonVocabularyOpened = "lesson_vocabulary_opened"
    case lessonVocabularySaved = "lesson_vocabulary_saved"
    case lessonExercisesCompleted = "lesson_exercises_completed"
    case lessonAbandoned = "lesson_abandoned"
    case lessonCompleted = "lesson_completed"
    case sessionFeedbackSubmitted = "session_feedback_submitted"
    case practiceOpened = "practice_opened"
    case practiceModeSelected = "practice_mode_selected"
    case flashcardSessionStarted = "flashcard_session_started"
    case flashcardPresented = "flashcard_presented"
    case flashcardAnswered = "flashcard_answered"
    case flashcardAudioPlayed = "flashcard_audio_played"
    case flashcardSessionAbandoned = "flashcard_session_abandoned"
    case flashcardSessionCompleted = "flashcard_session_completed"
    case vocabularyOpened = "vocabulary_opened"
    case vocabularySaved = "vocabulary_saved"
    case vocabularyRemoved = "vocabulary_removed"
    case vocabularyAudioPlayed = "vocabulary_audio_played"
    case reviewSessionStarted = "review_session_started"
    case reviewSessionAbandoned = "review_session_abandoned"
    case reviewSessionCompleted = "review_session_completed"
    case appReviewPromptShown = "app_review_prompt_shown"
    case appReviewRequested = "app_review_requested"
    case appReviewPromptDismissed = "app_review_prompt_dismissed"
    case reviewRated = "review_rated"
    case livePracticeOpened = "live_practice_opened"
    case livePracticeStartRequested = "live_practice_start_requested"
    case livePracticeStarted = "live_practice_started"
    case livePracticeStartFailed = "live_practice_start_failed"
    case livePracticeMuteChanged = "live_practice_mute_changed"
    case livePracticeEnded = "live_practice_ended"
    case lessonHistoryOpened = "lesson_history_opened"
    case lessonHistoryAudioPlayed = "lesson_history_audio_played"
}
