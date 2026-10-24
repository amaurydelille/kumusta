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
        _ vietnamese: String,
        _ translation: String,
        prompt: String = "Listen"
    ) -> LessonStep {
        LessonStep(
            id: UUID(),
            kind: kind,
            prompt: prompt,
            vietnamese: vietnamese,
            translation: translation,
            chunks: []
        )
    }

    private func greetingLesson(accent: VietnameseAccent = .southern) -> Lesson {
        Lesson(
            id: UUID(),
            scenario: "Greetings",
            minutes: 5,
            accent: accent,
            steps: [
                step(.coldListen, "Chào anh ạ.", "Hello."),
                step(.decode, "Chào anh ạ.", "Hello."),
                step(.speak, "Chào anh ạ.", "Hello.", prompt: "Greet an older man politely."),
                step(.coldListen, "Chào chị ạ.", "Hello."),
                step(.speak, "Chào chị ạ.", "Hello.", prompt: "Greet an older woman politely."),
                step(.coldListen, "Cảm ơn bạn.", "Thank you."),
            ]
        )
    }

    @Test
    func lessonEnrollsEachDistinctPhraseOnceWithItsSpeakingHint() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = makeStore(fileURL: file, clock: Clock(start))

        store.enroll(lesson: greetingLesson())

        let cards = store.cards(for: .southern)
        #expect(cards.count == 3)
        let older = store.cards[MemoryCard.key(for: "chào anh ạ", accent: .southern)]
        #expect(older?.hint == "Greet an older man politely.")
        #expect(older?.source == .lesson)
        #expect(store.cards[MemoryCard.key(for: "Cảm ơn bạn", accent: .southern)]?.hint == nil)
    }

    @Test
    func newPhrasesComeDueTheNextDayNotImmediately() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)

        store.enroll(lesson: greetingLesson())
        #expect(store.dueCount(for: .southern) == 0)

        clock.date = start.addingTimeInterval(86_400)
        #expect(store.dueCount(for: .southern) == 3)
        #expect(store.dueCount(for: .northern) == 0)
    }

    @Test
    func toneMarksKeepPhrasesApart() {
        #expect(MemoryCard.key(for: "ma", accent: .southern) != MemoryCard.key(for: "má", accent: .southern))
        #expect(MemoryCard.key(for: "  Chào   bạn! ", accent: .southern) == MemoryCard.key(for: "chào bạn", accent: .southern))
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
        #expect(store.dueCount(for: .southern) == 3)

        let key = MemoryCard.key(for: "Cảm ơn bạn", accent: .southern)
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
            word: "bạn",
            translation: "friend",
            sentence: "Chào bạn.",
            sentenceTranslation: "Hi.",
            accent: .northern,
            lessonID: UUID(),
            savedAt: start
        )

        store.enroll(savedWord: word)

        let card = store.cards[MemoryCard.key(for: "bạn", accent: .northern)]
        #expect(card?.source == .savedWord)
        #expect(card?.hint == "Chào bạn.")
    }

    @Test
    func sessionsAreCappedAndStartWithTheMostForgotten() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let clock = Clock(start)
        let store = makeStore(fileURL: file, clock: clock)
        let steps = (0..<20).map { index in
            step(.coldListen, "câu số \(index)", "sentence \(index)")
        }
        let lesson = Lesson(id: UUID(), scenario: "Many", minutes: 5, accent: .southern, steps: steps)
        store.enroll(lesson: lesson)
        let forgotten = MemoryCard.key(for: "câu số 7", accent: .southern)
        // A lapse leaves this card weaker than the rest of the due set.
        store.record(cardID: forgotten, grade: .again, exercise: .listenMeaning, at: start.addingTimeInterval(86_400 * 1.5))
        clock.date = start.addingTimeInterval(86_400 * 4)

        let session = store.sessionCards(for: .southern)

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
        let key = MemoryCard.key(for: "Chào chị ạ", accent: .southern)

        let updated = store.record(cardID: key, grade: .good, exercise: .build)

        #expect(updated?.memory.reps == 2)
        #expect(store.dueCards(for: .southern).contains { $0.id == key } == false)
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
        let key = MemoryCard.key(for: "Chào anh ạ", accent: .southern)
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
        let key = MemoryCard.key(for: "Chào anh ạ", accent: .southern)
        clock.date = start.addingTimeInterval(86_400 * 2)
        tablet.record(cardID: key, grade: .good, exercise: .speak)
        phone.enroll(savedWord: SavedLessonWord(
            id: UUID(), word: "nước", translation: "water", sentence: "", sentenceTranslation: "",
            accent: .southern, lessonID: UUID(), savedAt: start
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
