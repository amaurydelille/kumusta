import Foundation
import Testing
@testable import Kumusta

@MainActor
struct MemoryStoreTests {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private final class Clock {
        var date: Date
        init(_ date: Date) { self.date = date }
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeStore(fileURL: URL, clock: Clock) -> MemoryStore {
        MemoryStore(
            fileURL: fileURL,
            scheduler: MemoryScheduler(calendar: Self.utcCalendar),
            now: { clock.date }
        )
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-tests-\(UUID().uuidString).json")
    }

    private func step(
        _ kind: LessonStepKind,
        _ tagalog: String,
        _ translation: String,
        prompt: String = "Listen"
    ) -> LessonStep {
        LessonStep(
            id: UUID(),
            kind: kind,
            prompt: prompt,
            tagalog: tagalog,
            translation: translation,
            chunks: []
        )
    }

    private func greetingLesson() -> Lesson {
        Lesson(
            id: UUID(),
            scenario: "Greetings",
            minutes: 5,
            steps: [
                step(.coldListen, "Kumusta po, Kuya.", "Hello."),
                step(.decode, "Kumusta po, Kuya.", "Hello."),
                step(.speak, "Kumusta po, Kuya.", "Hello.", prompt: "Greet an older man politely."),
                step(.coldListen, "Kumusta po, Ate.", "Hello."),
                step(.speak, "Kumusta po, Ate.", "Hello.", prompt: "Greet an older woman politely."),
                step(.coldListen, "Salamat sa iyo.", "Thank you."),
            ]
        )
    }

    @Test
    func lessonEnrollsEachDistinctPhraseOnceWithItsSpeakingHint() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = makeStore(fileURL: file, clock: Clock(start))

        store.enroll(lesson: greetingLesson())

        let cards = store.allCards()
        #expect(cards.count == 3)
        let older = store.cards[MemoryCard.key(for: "kumusta po kuya")]
        #expect(older?.hint == "Greet an older man politely.")
        #expect(older?.source == .lesson)
        #expect(store.cards[MemoryCard.key(for: "Salamat sa iyo")]?.hint == nil)
    }

    @Test
    func newPhrasesComeDueTheNextDayNotImmediately() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)

        store.enroll(lesson: greetingLesson())
        #expect(store.dueCount() == 0)

        clock.date = start.addingTimeInterval(86_400)
        #expect(store.dueCount() == 3)
    }

    @Test
    func stressMarksAndCaseDoNotSplitAPhrase() {
        #expect(MemoryCard.key(for: "salamat") == MemoryCard.key(for: "Salámat"))
        #expect(MemoryCard.key(for: "salamat") != MemoryCard.key(for: "salamat po"))
        #expect(MemoryCard.key(for: "  Kumusta   ka! ") == MemoryCard.key(for: "kumusta ka"))
    }

    @Test
    func reconcileBackfillsHistoryWithoutTouchingExistingMemory() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)
        let lesson = greetingLesson()
        let record = CompletedLessonRecord(
            id: UUID(),
            lesson: lesson,
            generatedLessonID: nil,
            source: .authored,
            completedAt: start.addingTimeInterval(-30 * 86_400),
            difficultyFeedback: .justRight,
            paceFeedback: .justRight,
            requestedNextTopic: nil
        )

        store.reconcile(completedLessons: [record], savedWords: [])
        #expect(store.dueCount() == 3)

        let key = MemoryCard.key(for: "Salamat sa iyo")
        store.record(cardID: key, grade: .good, exercise: .listenMeaning)
        let reviewed = store.cards[key]

        store.reconcile(completedLessons: [record], savedWords: [])
        #expect(store.cards[key] == reviewed)
        #expect(store.cards.count == 3)
    }

    @Test
    func savedWordsJoinTheDeck() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = makeStore(fileURL: file, clock: Clock(start))
        let word = SavedLessonWord(
            id: UUID(),
            word: "kaibigan",
            translation: "friend",
            sentence: "Kumusta, kaibigan.",
            sentenceTranslation: "Hi.",
            lessonID: UUID(),
            savedAt: start
        )

        store.enroll(savedWord: word)

        let card = store.cards[MemoryCard.key(for: "kaibigan")]
        #expect(card?.source == .savedWord)
        #expect(card?.hint == "Kumusta, kaibigan.")
    }

    @Test
    func sessionsAreCappedAndStartWithTheMostForgotten() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)
        let steps = (0..<20).map { index in
            step(.coldListen, "pangungusap \(index)", "sentence \(index)")
        }
        let lesson = Lesson(id: UUID(), scenario: "Many", minutes: 5, steps: steps)
        store.enroll(lesson: lesson)
        let forgotten = MemoryCard.key(for: "pangungusap 7")
        // A lapse leaves this card weaker than the rest of the due set.
        store.record(cardID: forgotten, grade: .again, exercise: .listenMeaning, at: start.addingTimeInterval(86_400 * 1.5))
        clock.date = start.addingTimeInterval(86_400 * 4)

        let session = store.sessionCards()

        #expect(session.count == MemoryStore.sessionSize)
        #expect(session.first?.id == forgotten)
        let recalls = session.map { store.recall(of: $0) }
        #expect(recalls == recalls.sorted())
    }

    @Test
    func recordingMovesTheCardOutOfTodaysQueueAndLogsIt() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)
        store.enroll(lesson: greetingLesson())
        clock.date = start.addingTimeInterval(86_400 * 2)
        let key = MemoryCard.key(for: "Kumusta po, Ate")

        let updated = store.record(cardID: key, grade: .good, exercise: .build)

        #expect(updated?.memory.reps == 2)
        #expect(store.dueCards().contains { $0.id == key } == false)
        #expect(store.todaySummary(calendar: Self.utcCalendar) == (reviewed: 1, recalled: 1))
        #expect(store.log.last?.exercise == .build)
    }

    @Test
    func persistsAcrossLaunches() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)
        store.enroll(lesson: greetingLesson())
        let key = MemoryCard.key(for: "Kumusta po, Kuya")
        store.record(cardID: key, grade: .good, exercise: .speak)

        let restored = makeStore(fileURL: file, clock: clock)

        #expect(restored.cards == store.cards)
        #expect(restored.log == store.log)
    }

    @Test
    func mergeKeepsTheMostRecentlyReviewedCopyAndNeverDrops() {
        let fileA = temporaryFile()
        let fileB = temporaryFile()
        defer {
            try? FileManager.default.removeItem(at: fileA)
            try? FileManager.default.removeItem(at: fileB)
        }
        let clock = Clock(start)
        let phone = makeStore(fileURL: fileA, clock: clock)
        let tablet = makeStore(fileURL: fileB, clock: clock)
        let lesson = greetingLesson()
        phone.enroll(lesson: lesson)
        tablet.enroll(lesson: lesson)
        let key = MemoryCard.key(for: "Kumusta po, Kuya")
        clock.date = start.addingTimeInterval(86_400 * 2)
        tablet.record(cardID: key, grade: .good, exercise: .speak)
        phone.enroll(savedWord: SavedLessonWord(
            id: UUID(), word: "tubig", translation: "water", sentence: "", sentenceTranslation: "",
            lessonID: UUID(), savedAt: start
        ))

        phone.merge(tablet.snapshot())
        phone.merge(nil)

        #expect(phone.cards[key] == tablet.cards[key])
        #expect(phone.cards.count == 4)
    }

    @Test
    func cloudStateWithoutMemoryStillDecodes() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = makeStore(fileURL: file, clock: Clock(start))
        store.enroll(lesson: greetingLesson())
        let data = try JSONEncoder().encode(store.snapshot())
        let decoded = try JSONDecoder().decode(MemorySnapshot.self, from: data)
        #expect(decoded == store.snapshot())
    }

    @Test
    func resetClearsEverything() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)
        store.enroll(lesson: greetingLesson())

        store.reset()

        #expect(store.cards.isEmpty)
        #expect(makeStore(fileURL: file, clock: clock).cards.isEmpty)
    }
}
