import Foundation
import Testing
@testable import Kumusta

struct ReviewExercisePlannerTests {
    /// Deterministic generator so choice order is reproducible.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func card(_ tagalog: String, _ translation: String, stability: Double = 1) -> MemoryCard {
        MemoryCard(
            id: MemoryCard.key(for: tagalog),
            tagalog: tagalog,
            translation: translation,
            hint: nil,
            translationLanguage: nil,
            source: .lesson,
            sourceID: UUID(),
            enrolledAt: start,
            memory: MemoryState(
                stability: stability,
                difficulty: 5,
                lastReviewedAt: start,
                dueAt: start,
                reps: 1,
                lapses: 0
            )
        )
    }

    private var pool: [MemoryCard] {
        [
            card("Magandang umaga sa iyo.", "Good morning."),
            card("Magandang umaga po.", "Good morning."),
            card("Salamat sa iyo.", "Thank you."),
            card("Magkano ito?", "How much is it?"),
            card("Hindi ko maintindihan.", "I don't understand."),
            card("Ngon quá!", "So tasty!"),
        ]
    }

    @Test
    func weakItemsAreRecognitionAndStrongItemsAreProduction() {
        var generator = SeededGenerator(state: 1)
        let weak = card("Salamat sa iyo.", "Thank you.", stability: 1)
        let medium = card("Salamat sa iyo.", "Thank you.", stability: 5)
        let strong = card("Salamat sa iyo.", "Thank you.", stability: 30)

        #expect(ReviewExercisePlanner.kind(for: weak, pool: pool, canSpeak: true, using: &generator) == .listenMeaning)
        for _ in 0..<20 {
            let mediumKind = ReviewExercisePlanner.kind(for: medium, pool: pool, canSpeak: true, using: &generator)
            #expect([.pickTagalog, .build].contains(mediumKind))
            let strongKind = ReviewExercisePlanner.kind(for: strong, pool: pool, canSpeak: false, using: &generator)
            #expect(strongKind != .speak)
        }
    }

    @Test
    func singleSyllableWordsAreNeverBuiltFromTiles() {
        var generator = SeededGenerator(state: 3)
        let word = card("tubig", "water", stability: 5)
        for _ in 0..<30 {
            #expect(ReviewExercisePlanner.kind(for: word, pool: pool, canSpeak: false, using: &generator) == .pickTagalog)
        }
    }

    @Test
    func meaningChoicesHaveExactlyOneRightAnswerAndNoSynonyms() {
        var generator = SeededGenerator(state: 7)
        let target = pool[0]

        let choices = ReviewExercisePlanner.meaningChoices(for: target, pool: pool, using: &generator)

        #expect(choices.count == 4)
        #expect(choices.filter(\.isCorrect).map(\.text) == ["Good morning."])
        #expect(Set(choices.map(\.text)).count == choices.count)
    }

    @Test
    func tagalogChoicesIncludeLookAlikesAndExcludeOtherCorrectAnswers() {
        var generator = SeededGenerator(state: 11)
        let target = pool[0]

        let choices = ReviewExercisePlanner.tagalogChoices(for: target, pool: pool, using: &generator)

        #expect(choices.count == 4)
        #expect(choices.filter(\.isCorrect).map(\.text) == ["Magandang umaga sa iyo."])
        // "Magandang umaga po." also means "Good morning." and must not appear as a wrong answer.
        #expect(!choices.contains { $0.text == "Magandang umaga po." })
        let answerWords = ListenTileBank.tileTexts(in: "Magandang umaga sa iyo.")
        let lookAlikes = choices.filter { !$0.isCorrect }.filter { choice in
            let words = ListenTileBank.tileTexts(in: choice.text)
            return words.count == answerWords.count && zip(words, answerWords).filter { $0 != $1 }.count == 1
        }
        #expect(lookAlikes.count == 2)
    }

    @Test
    func optionsThatContainTheAnswerAreNeverWrongAnswers() {
        let target = card("Kuya, gamitin po natin ang metro.", "Please use the taxi meter.")
        let fragment = card("ang metro", "the taxi meter")
        let pool = [target, fragment] + self.pool
        for seed in 0..<30 {
            var generator = SeededGenerator(state: UInt64(seed))
            let meanings = ReviewExercisePlanner.meaningChoices(for: target, pool: pool, using: &generator)
            #expect(!meanings.contains { $0.text == "the taxi meter" })
            let tagalog = ReviewExercisePlanner.tagalogChoices(for: target, pool: pool, using: &generator)
            #expect(!tagalog.contains { $0.text == "ang metro" })
        }
    }

    @Test
    func lookAlikeVariantsChangeExactlyOneWord() {
        var generator = SeededGenerator(state: 5)
        let variants = ReviewExercisePlanner.lookAlikeVariants(of: "Salamat sa iyo.", using: &generator)

        #expect(!variants.isEmpty)
        for variant in variants {
            let original = ListenTileBank.tileTexts(in: "Salamat sa iyo.")
            let changed = ListenTileBank.tileTexts(in: variant)
            #expect(changed.count == original.count)
            #expect(zip(original, changed).filter { $0 != $1 }.count == 1)
            #expect(variant.hasSuffix("."))
        }
    }

    @Test
    func gradingReflectsWhatTheLearnerDid() {
        #expect(ReviewGrader.grade(kind: .listenMeaning, correctOnFirstAttempt: true, eventuallyCorrect: true, responseSeconds: 3) == .good)
        #expect(ReviewGrader.grade(kind: .listenMeaning, correctOnFirstAttempt: true, eventuallyCorrect: true, responseSeconds: 30) == .hard)
        #expect(ReviewGrader.grade(kind: .pickTagalog, correctOnFirstAttempt: false, eventuallyCorrect: true, responseSeconds: 3) == .again)
        #expect(ReviewGrader.grade(kind: .build, correctOnFirstAttempt: false, eventuallyCorrect: true, responseSeconds: 20) == .hard)
        #expect(ReviewGrader.grade(kind: .build, correctOnFirstAttempt: false, eventuallyCorrect: false, responseSeconds: 20) == .again)
        #expect(ReviewGrader.grade(kind: .build, correctOnFirstAttempt: true, eventuallyCorrect: true, responseSeconds: 40) == .good)
        #expect(ReviewGrader.grade(kind: .speak, correctOnFirstAttempt: false, eventuallyCorrect: false, responseSeconds: 10) == .hard)
        #expect(ReviewGrader.grade(kind: .speak, correctOnFirstAttempt: false, eventuallyCorrect: false, gaveUp: true, responseSeconds: 10) == .again)
    }
}
