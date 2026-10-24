import Foundation
import Observation

struct SavedLessonWord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let word: String
    let translation: String
    let sentence: String
    let sentenceTranslation: String
    let lessonID: UUID
    let savedAt: Date
    var mastery: Double
    var nextReviewAt: Date
    var isInFlashcards: Bool
    /// Language of `translation` and `sentenceTranslation` when they are not
    /// English. Nil for English, which is also every word saved before French.
    let translationLanguage: AppLanguage?

    init(
        id: UUID,
        word: String,
        translation: String,
        sentence: String,
        sentenceTranslation: String,
        lessonID: UUID,
        savedAt: Date,
        mastery: Double = 0.05,
        nextReviewAt: Date = .now,
        isInFlashcards: Bool = true,
        translationLanguage: AppLanguage? = nil
    ) {
        self.id = id
        self.word = word
        self.translation = translation
        self.sentence = sentence
        self.sentenceTranslation = sentenceTranslation
        self.lessonID = lessonID
        self.savedAt = savedAt
        self.mastery = min(1, max(0, mastery))
        self.nextReviewAt = nextReviewAt
        self.isInFlashcards = isInFlashcards
        self.translationLanguage = translationLanguage == .english ? nil : translationLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case word
        case translation
        case sentence
        case sentenceTranslation
        case lessonID
        case savedAt
        case mastery
        case nextReviewAt
        case isInFlashcards
        case translationLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            word: try container.decode(String.self, forKey: .word),
            translation: try container.decode(String.self, forKey: .translation),
            sentence: try container.decode(String.self, forKey: .sentence),
            sentenceTranslation: try container.decode(String.self, forKey: .sentenceTranslation),
            lessonID: try container.decode(UUID.self, forKey: .lessonID),
            savedAt: try container.decode(Date.self, forKey: .savedAt),
            mastery: try container.decodeIfPresent(Double.self, forKey: .mastery) ?? 0.05,
            nextReviewAt: try container.decodeIfPresent(Date.self, forKey: .nextReviewAt) ?? .now,
            isInFlashcards: try container.decodeIfPresent(Bool.self, forKey: .isInFlashcards) ?? true,
            translationLanguage: try? container.decodeIfPresent(AppLanguage.self, forKey: .translationLanguage)
        )
    }

    var normalizedWord: String {
        word.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "fil")
        )
        .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}

@MainActor
@Observable
final class SavedLessonWordStore {
    static let storageKey = "kumusta.saved-lesson-words.v1"

    private let defaults: UserDefaults
    private var onWordSaved: (@MainActor (SavedLessonWord) -> Void)?
    private var onWordEnrolled: (@MainActor (SavedLessonWord) -> Void)?
    private(set) var words: [SavedLessonWord]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([SavedLessonWord].self, from: data)
        {
            words = decoded.sorted { $0.savedAt > $1.savedAt }
        } else {
            words = []
        }
    }

    /// Installs the app-level audio prewarmer without making this local-first
    /// store depend on Supabase or ElevenLabs. The callback runs only after a
    /// word has been persisted locally, so saving vocabulary never waits on
    /// the network.
    func configureAudioPrewarming(
        _ handler: @escaping @MainActor (SavedLessonWord) -> Void
    ) {
        onWordSaved = handler
    }

    /// Adds every newly saved word to the memory deck so it is reviewed.
    func configureMemoryEnrollment(
        _ handler: @escaping @MainActor (SavedLessonWord) -> Void
    ) {
        onWordEnrolled = handler
    }

    @discardableResult
    func save(
        gloss: LessonWordGloss,
        sentence: String,
        sentenceTranslation: String,
        lessonID: UUID,
        translationLanguage: AppLanguage? = nil
    ) -> SavedLessonWord {
        save(
            word: gloss.token,
            translation: gloss.translation,
            sentence: sentence,
            sentenceTranslation: sentenceTranslation,
            lessonID: lessonID,
            translationLanguage: translationLanguage
        )
    }

    @discardableResult
    func save(vocabularyItem: VocabularyItem) -> SavedLessonWord {
        save(
            word: vocabularyItem.tagalog,
            translation: vocabularyItem.english,
            sentence: vocabularyItem.example,
            sentenceTranslation: vocabularyItem.exampleTranslation,
            lessonID: vocabularyItem.id
        )
    }

    private func save(
        word: String,
        translation: String,
        sentence: String,
        sentenceTranslation: String,
        lessonID: UUID,
        translationLanguage: AppLanguage? = nil
    ) -> SavedLessonWord {
        let displayWord = Self.displayWord(from: word)
        let normalized = Self.normalized(displayWord)
        if let existingIndex = words.firstIndex(where: {
            $0.normalizedWord == normalized
        }) {
            if !words[existingIndex].isInFlashcards {
                words[existingIndex].isInFlashcards = true
                words[existingIndex].nextReviewAt = .now
                persist()
                onWordSaved?(words[existingIndex])
                onWordEnrolled?(words[existingIndex])
            }
            return words[existingIndex]
        }

        let saved = SavedLessonWord(
            id: UUID(),
            word: displayWord,
            translation: translation,
            sentence: sentence,
            sentenceTranslation: sentenceTranslation,
            lessonID: lessonID,
            savedAt: .now,
            translationLanguage: translationLanguage
        )
        words.insert(saved, at: 0)
        persist()
        onWordSaved?(saved)
        onWordEnrolled?(saved)
        return saved
    }

    func contains(token: String) -> Bool {
        let normalized = Self.normalized(Self.displayWord(from: token))
        return words.contains {
            $0.normalizedWord == normalized
        }
    }

    func recordReview(id: UUID, rating: ReviewRating) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }

        let interval: TimeInterval
        let masteryDelta: Double
        switch rating {
        case .again:
            interval = 30
            masteryDelta = -0.08
        case .almost:
            interval = 86_400
            masteryDelta = 0.03
        case .gotIt:
            interval = 345_600
            masteryDelta = 0.12
        }

        words[index].nextReviewAt = .now.addingTimeInterval(interval)
        words[index].mastery = min(
            1,
            max(0, words[index].mastery + masteryDelta)
        )
        persist()
    }

    /// Keeps a missed card in the user's flashcard deck while recording a
    /// small lapse. The answer remains available for another attempt now.
    func recordFlashcardMiss(id: UUID) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }

        words[index].isInFlashcards = true
        words[index].nextReviewAt = .now
        words[index].mastery = max(0, words[index].mastery - 0.05)
        persist()
    }

    /// A correct flashcard answer removes the card from the active deck but
    /// deliberately keeps it in the saved vocabulary library.
    func retireFromFlashcards(id: UUID) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }

        words[index].isInFlashcards = false
        words[index].mastery = max(words[index].mastery, 0.92)
        words[index].nextReviewAt = .now.addingTimeInterval(345_600)
        persist()
    }

    /// Re-adds a saved phrase to the active review deck from its detail row.
    func restoreToFlashcards(id: UUID) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }

        words[index].isInFlashcards = true
        words[index].nextReviewAt = .now
        persist()
    }

    func remove(id: UUID) {
        words.removeAll { $0.id == id }
        persist()
    }

    func replace(with words: [SavedLessonWord]) {
        self.words = words.sorted { $0.savedAt > $1.savedAt }
        persist()
    }

    func reset() {
        words = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(words) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func displayWord(from token: String) -> String {
        let trimmed = token.trimmingCharacters(
            in: .punctuationCharacters.union(.whitespacesAndNewlines)
        )
        return trimmed.isEmpty ? token : trimmed
    }

    private static func normalized(_ word: String) -> String {
        word.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "fil")
        )
        .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
