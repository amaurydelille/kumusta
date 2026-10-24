import Foundation

enum MemoryCardSource: String, Codable, Sendable {
    case lesson
    case savedWord
}

/// One phrase or word the learner has met and should keep. Lessons enroll
/// their phrases automatically; saving a word enrolls it too.
struct MemoryCard: Identifiable, Codable, Equatable, Sendable {
    /// Accent plus the normalized Vietnamese, so the same phrase met in two
    /// lessons is one memory. Tones are kept: "ma" and "má" are different.
    let id: String
    let vietnamese: String
    var translation: String
    /// A cue that disambiguates the translation, such as "Greet a woman
    /// slightly older than you" for "Hello.".
    var hint: String?
    let accent: VietnameseAccent
    /// Language of `translation` and `hint`; nil for English.
    var translationLanguage: AppLanguage?
    let source: MemoryCardSource
    let sourceID: UUID
    let enrolledAt: Date
    var memory: MemoryState
    /// The meaning in other interface languages, keyed by `AppLanguage`
    /// raw value, learned whenever lessons load in that language.
    var meanings: [String: LocalizedMeaning]? = nil

    struct LocalizedMeaning: Codable, Equatable, Sendable {
        let translation: String
        let hint: String?
    }

    /// This card as shown to a learner using `language`: the meaning in that
    /// language when known, otherwise the one it was enrolled with.
    func displayed(in language: AppLanguage) -> MemoryCard {
        guard meaningLanguage != language, let meaning = meanings?[language.rawValue] else { return self }
        var copy = self
        copy.translation = meaning.translation
        // A saved word's hint is its Vietnamese example sentence.
        if source == .lesson { copy.hint = meaning.hint }
        copy.translationLanguage = language == .english ? nil : language
        return copy
    }

    static func key(for vietnamese: String, accent: VietnameseAccent) -> String {
        "\(accent.rawValue):\(normalized(vietnamese))"
    }

    /// Lowercased, NFC, punctuation trimmed and spaces collapsed; diacritics
    /// stay because every tone mark changes the word.
    static func normalized(_ vietnamese: String) -> String {
        vietnamese
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "vi"))
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols)) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The language `translation` is written in; older cards store English
    /// as nil, newer ones may say `.english` explicitly.
    var meaningLanguage: AppLanguage { translationLanguage ?? .english }

    /// Stable per-card number for the scheduler's interval spread.
    var fuzzSeed: UInt64 { Self.fuzzSeed(for: id) }

    /// FNV-1a of the key: stable across launches, unlike `hashValue`.
    static func fuzzSeed(for key: String) -> UInt64 {
        key.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { hash, scalar in
            (hash ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
    }

    var syllableCount: Int {
        ListenTileBank.tileTexts(in: vietnamese).count
    }
}

/// What a lesson or a saved word contributes to the learner's memory.
struct MemoryCandidate: Equatable, Sendable {
    let vietnamese: String
    let translation: String
    let hint: String?
    let accent: VietnameseAccent
    let translationLanguage: AppLanguage?
    let source: MemoryCardSource
    let sourceID: UUID

    var key: String { MemoryCard.key(for: vietnamese, accent: accent) }

    /// Longer sentences are fine in a lesson but too much for a quick review.
    static let maximumSyllables = 12

    /// The distinct phrases a lesson taught, in lesson order. The speaking
    /// prompt becomes the hint because sentence translations repeat ("Hello."
    /// for both "Chào anh ạ." and "Chào chị ạ.").
    static func phrases(in lesson: Lesson, accent: VietnameseAccent) -> [MemoryCandidate] {
        // Read the language off the lesson's own text: the app's language
        // setting can differ from the content (a deck rebuilt at launch, a
        // lesson finished before switching languages).
        let translationLanguage = MeaningLanguageDetector.language(
            of: lesson.steps.map(\.translation)
        )
        var seen: Set<String> = []
        var candidates: [MemoryCandidate] = []
        for step in lesson.steps {
            let normalized = MemoryCard.normalized(step.vietnamese)
            let syllables = ListenTileBank.tileTexts(in: step.vietnamese).count
            let translation = step.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !normalized.isEmpty,
                !translation.isEmpty,
                (1...maximumSyllables).contains(syllables),
                seen.insert(normalized).inserted
            else { continue }

            let speakPrompt = lesson.steps
                .first { $0.kind == .speak && MemoryCard.normalized($0.vietnamese) == normalized }?
                .prompt
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = speakPrompt.flatMap { prompt in
                prompt.isEmpty || prompt.caseInsensitiveCompare(translation) == .orderedSame
                    ? nil
                    : prompt
            }
            candidates.append(
                MemoryCandidate(
                    vietnamese: step.vietnamese.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: translation,
                    hint: hint,
                    accent: accent,
                    translationLanguage: translationLanguage,
                    source: .lesson,
                    sourceID: lesson.id
                )
            )
        }
        return candidates
    }

    static func word(_ saved: SavedLessonWord) -> MemoryCandidate? {
        let translation = saved.translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !MemoryCard.normalized(saved.word).isEmpty,
            !translation.isEmpty
        else { return nil }
        let sentence = saved.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        return MemoryCandidate(
            vietnamese: saved.word,
            translation: translation,
            hint: sentence.isEmpty || MemoryCard.normalized(sentence) == MemoryCard.normalized(saved.word)
                ? nil
                : sentence,
            accent: saved.accent,
            translationLanguage: saved.translationLanguage,
            source: .savedWord,
            sourceID: saved.id
        )
    }
}

/// Which interface language a lesson's translations are written in.
enum MeaningLanguageDetector {
    /// Nil for English, matching how cards store it. Kumusta ships English only.
    static func language(of texts: [String]) -> AppLanguage? { nil }
}

// MARK: - Exercises

/// The review exercises, from recognising a phrase to producing it.
enum ReviewExerciseKind: String, Codable, CaseIterable, Sendable {
    /// Hear the Vietnamese, pick its meaning.
    case listenMeaning
    /// See the meaning, pick the Vietnamese among tone look-alikes.
    case pickVietnamese
    /// See the meaning, build the Vietnamese from syllable tiles.
    case build
    /// See the meaning, say the Vietnamese out loud.
    case speak

    /// Harder exercises earn a little more when answered on the first try.
    var isProduction: Bool {
        self == .build || self == .speak
    }
}

struct ReviewExerciseChoice: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let isCorrect: Bool
}

/// Chooses each review's exercise and its answer options. Pure and seeded
/// so a session can be reproduced in tests.
enum ReviewExercisePlanner {
    /// Stability, in days, from which an item is asked for in production
    /// form rather than recognition.
    static let productionStability = 3.0
    /// Stability from which speaking is the default.
    static let speakingStability = 9.0

    static func kind<Generator: RandomNumberGenerator>(
        for card: MemoryCard,
        pool: [MemoryCard],
        canSpeak: Bool,
        using generator: inout Generator
    ) -> ReviewExerciseKind {
        let stability = card.memory.stability
        let canBuild = (2...ListenTileBank.maximumSyllables).contains(card.syllableCount)

        if stability < productionStability {
            // A small deck may hold no other meanings in this card's language;
            // a one-option question tests nothing, so ask for the Vietnamese.
            return meaningDistractors(for: card, in: pool).count >= 2 ? .listenMeaning : .pickVietnamese
        }
        if stability >= speakingStability, canSpeak {
            // Mostly speak, sometimes build, so strong items stay varied.
            return Double.random(in: 0..<1, using: &generator) < 0.75 || !canBuild ? .speak : .build
        }
        if canBuild, Double.random(in: 0..<1, using: &generator) < 0.6 {
            return .build
        }
        return .pickVietnamese
    }

    /// The correct meaning plus up to three others. Meanings that read the
    /// same as the answer are excluded so every question has one right answer.
    static func meaningChoices<Generator: RandomNumberGenerator>(
        for card: MemoryCard,
        pool: [MemoryCard],
        using generator: inout Generator
    ) -> [ReviewExerciseChoice] {
        let distractors = meaningDistractors(for: card, in: pool.shuffled(using: &generator), limit: 3)
        return shuffledChoices(answer: card.translation, distractors: distractors, using: &generator)
    }

    /// Fair wrong meanings, in pool order: same language as the answer,
    /// distinct, and never a fragment of it ("use the taxi meter" is not a
    /// fair wrong answer for "Please use the taxi meter for me.").
    private static func meaningDistractors(for card: MemoryCard, in pool: [MemoryCard], limit: Int = 3) -> [String] {
        let answer = comparable(card.translation)
        var seen: Set<String> = [answer]
        var distractors: [String] = []
        for other in pool where other.id != card.id && other.meaningLanguage == card.meaningLanguage {
            let normalized = comparable(other.translation)
            guard !normalized.isEmpty,
                  !overlaps(normalized, answer),
                  seen.insert(normalized).inserted
            else { continue }
            distractors.append(other.translation)
            if distractors.count == limit { break }
        }
        return distractors
    }

    /// The correct Vietnamese plus look-alikes: the same phrase with one
    /// tone changed, then other phrases. Tone traps are what Vietnamese
    /// learners actually confuse.
    static func vietnameseChoices<Generator: RandomNumberGenerator>(
        for card: MemoryCard,
        pool: [MemoryCard],
        using generator: inout Generator
    ) -> [ReviewExerciseChoice] {
        let answer = card.vietnamese
        var seen: Set<String> = [MemoryCard.normalized(answer)]
        var distractors: [String] = []

        for variant in toneVariants(of: answer, using: &generator) {
            guard seen.insert(MemoryCard.normalized(variant)).inserted else { continue }
            distractors.append(variant)
            if distractors.count == 2 { break }
        }
        let answerMeaning = comparable(card.translation)
        for other in pool.shuffled(using: &generator) where other.id != card.id {
            guard distractors.count < 3 else { break }
            // Skip phrases that would also be a correct answer.
            guard !overlaps(comparable(other.translation), answerMeaning),
                  !overlaps(MemoryCard.normalized(other.vietnamese), MemoryCard.normalized(answer)),
                  seen.insert(MemoryCard.normalized(other.vietnamese)).inserted
            else { continue }
            distractors.append(other.vietnamese)
        }
        return shuffledChoices(answer: answer, distractors: distractors, using: &generator)
    }

    /// The phrase with a single syllable's tone swapped, e.g. "Cảm ơn" →
    /// "Cám ơn". Keeps the original casing and punctuation around the word.
    static func toneVariants<Generator: RandomNumberGenerator>(
        of phrase: String,
        using generator: inout Generator
    ) -> [String] {
        let words = phrase.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var variants: [String] = []
        for index in words.indices.shuffled(using: &generator) {
            let word = words[index]
            let core = word.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            guard !core.isEmpty, let range = word.range(of: core) else { continue }
            let isCapitalized = core.first?.isUppercase == true
            let swapped = VietnameseTone.variants(of: core.lowercased(with: Locale(identifier: "vi")))
                .shuffled(using: &generator)
            guard let replacement = swapped.first else { continue }
            let cased = isCapitalized ? replacement.prefix(1).uppercased() + replacement.dropFirst() : replacement
            var updated = words
            updated[index] = word.replacingCharacters(in: range, with: cased)
            variants.append(updated.joined(separator: " "))
        }
        return variants
    }

    private static func shuffledChoices<Generator: RandomNumberGenerator>(
        answer: String,
        distractors: [String],
        using generator: inout Generator
    ) -> [ReviewExerciseChoice] {
        ([(answer, true)] + distractors.map { ($0, false) })
            .shuffled(using: &generator)
            .enumerated()
            .map { ReviewExerciseChoice(id: $0.offset, text: $0.element.0, isCorrect: $0.element.1) }
    }

    /// Equal, or one contains the other as a whole phrase.
    private static func overlaps(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private static func comparable(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}

/// Turns what happened in an exercise into a memory grade.
enum ReviewGrader {
    /// Slower than this on a multiple-choice question reads as effortful recall.
    static let slowRecognitionSeconds: TimeInterval = 12

    static func grade(
        kind: ReviewExerciseKind,
        correctOnFirstAttempt: Bool,
        eventuallyCorrect: Bool,
        gaveUp: Bool = false,
        responseSeconds: TimeInterval
    ) -> MemoryGrade {
        if gaveUp {
            return .again
        }
        if correctOnFirstAttempt {
            if !kind.isProduction, responseSeconds > slowRecognitionSeconds {
                return .hard
            }
            return .good
        }
        // Speech recognition misses some correct takes, so a speaker who
        // keeps going is treated as recalling with effort, not forgetting.
        if kind == .speak || eventuallyCorrect && kind.isProduction {
            return .hard
        }
        return .again
    }
}
