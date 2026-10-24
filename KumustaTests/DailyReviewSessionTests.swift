import Foundation
import Testing
@testable import Kumusta

@MainActor
struct DailyReviewSessionTests {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func card(_ vietnamese: String, _ translation: String, stability: Double) -> MemoryCard {
        MemoryCard(
            id: MemoryCard.key(for: vietnamese, accent: .southern),
            vietnamese: vietnamese,
            translation: translation,
            hint: nil,
            accent: .southern,
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

    private func makeSession(canSpeak: Bool = true) -> DailyReviewSession {
        let cards = [
            card("Cảm ơn bạn.", "Thank you.", stability: 30),
            card("Bao nhiêu tiền?", "How much is it?", stability: 5),
            card("Ngon quá!", "So tasty!", stability: 1),
        ]
        var generator = SeededGenerator(state: 42)
        return DailyReviewSession(cards: cards, pool: cards, canSpeak: canSpeak, using: &generator)
    }

    private let right = ReviewAnswer(correctOnFirstAttempt: true, eventuallyCorrect: true, responseSeconds: 2)
    private let wrong = ReviewAnswer(correctOnFirstAttempt: false, eventuallyCorrect: false, responseSeconds: 2)

    @Test
    func sessionOpensWithAListeningWarmUp() {
        let session = makeSession()
        #expect(session.current?.kind == .listenMeaning)
        #expect(session.current?.card.translation == "So tasty!")
    }

    @Test
    func aMissedCardComesBackOnceAndOnlyTheFirstAnswerCounts() {
        let session = makeSession()
        let missed = session.current!.card

        #expect(session.submit(wrong) == .again)
        #expect(session.progress == 0)
        session.advance()
        while session.current?.isRetry == false {
            session.submit(right)
            session.advance()
        }

        #expect(session.current?.card.id == missed.id)
        #expect(session.submit(right) == nil)
        session.advance()

        #expect(session.isFinished)
        #expect(session.progress == 1)
        #expect(session.grades[missed.id] == .again)
        #expect(session.rememberedCount == 2)
    }

    @Test
    func comboCountsConsecutiveFirstTryAnswers() {
        let session = makeSession()
        session.submit(right); session.advance()
        session.submit(right); session.advance()
        #expect(session.combo == 2)
        session.submit(wrong)
        #expect(session.combo == 0)
        #expect(session.bestCombo == 2)
    }

    @Test
    func cantSpeakNowSwitchesRemainingSpeakingToSilentExercises() {
        let session = makeSession(canSpeak: true)
        session.disableSpeaking()
        #expect(!session.tasks.contains { $0.kind == .speak })
        #expect(!session.canSpeak)
    }

    @Test
    func withoutSpeechNoSpeakingIsPlanned() {
        let session = makeSession(canSpeak: false)
        #expect(!session.tasks.contains { $0.kind == .speak })
    }
}
