import Foundation
import Observation
import OSLog

/// One answered review, kept on the device for today's stats.
struct MemoryReviewLogEntry: Codable, Equatable, Sendable {
    let cardID: String
    let grade: MemoryGrade
    let exercise: ReviewExerciseKind
    let reviewedAt: Date
    /// The scheduler's recall prediction just before this answer.
    let predictedRecall: Double
}

/// The portable part of the memory deck, stored inside the account's cloud
/// state. Review logs stay on the device.
struct MemorySnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let cards: [MemoryCard]

    init(cards: [MemoryCard]) {
        schemaVersion = Self.currentSchemaVersion
        self.cards = cards
    }
}

/// The learner's long-term memory of everything they have been taught:
/// which phrases exist, how strong each one is, and which are due today.
/// Local-first; every change is written to disk before it is published.
@MainActor
@Observable
final class MemoryStore {
    static let sessionSize = 12
    static let maximumCards = 3_000
    static let maximumLogEntries = 600

    private struct Document: Codable {
        var cards: [MemoryCard]
        var log: [MemoryReviewLogEntry]
    }

    private let logger = Logger(subsystem: "com.kumusta.app", category: "memory")
    private let fileURL: URL
    private let now: () -> Date
    let scheduler: MemoryScheduler

    private(set) var cards: [String: MemoryCard] = [:]
    private(set) var log: [MemoryReviewLogEntry] = []

    init(
        fileURL: URL? = nil,
        scheduler: MemoryScheduler = MemoryScheduler(),
        now: @escaping () -> Date = { .now }
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.scheduler = scheduler
        self.now = now
        if let data = try? Data(contentsOf: self.fileURL),
           let document = try? JSONDecoder().decode(Document.self, from: data) {
            cards = Dictionary(document.cards.map { ($0.id, $0) }, uniquingKeysWith: Self.newer)
            log = document.log
        }
    }

    // MARK: - Enrollment

    /// Adds every phrase from finished lessons and every saved word that is
    /// not in the deck yet. Safe to call repeatedly; it never changes the
    /// memory of a card that already exists. Phrases from older lessons start
    /// as if first met on the day the lesson was finished.
    func reconcile(completedLessons: [CompletedLessonRecord], savedWords: [SavedLessonWord]) {
        var changed = false
        for record in completedLessons.sorted(by: { $0.completedAt < $1.completedAt }) {
            let candidates = MemoryCandidate.phrases(in: record.lesson, accent: record.lesson.accent)
            changed = insertMissing(candidates, metAt: record.completedAt, grade: .hard) || changed
            changed = repairMeaningLanguage(from: candidates) || changed
        }
        for word in savedWords {
            guard let candidate = MemoryCandidate.word(word) else { continue }
            let grade: MemoryGrade = word.mastery >= 0.85 ? .good : .hard
            changed = insertMissing([candidate], metAt: word.savedAt, grade: grade) || changed
        }
        if changed { persist() }
    }

    /// Enrolls a lesson the learner just finished. Phrases they already knew
    /// and that were due count as a successful review: the lesson made them
    /// produce the phrase again.
    func enroll(lesson: Lesson, at date: Date? = nil) {
        let date = date ?? now()
        let candidates = MemoryCandidate.phrases(in: lesson, accent: lesson.accent)
        var changed = insertMissing(candidates, metAt: date, grade: .hard)
        for candidate in candidates {
            guard var card = cards[candidate.key],
                  card.memory.dueAt <= date,
                  card.memory.lastReviewedAt < date
            else { continue }
            card.memory = scheduler.review(card.memory, grade: .good, at: date, fuzzSeed: card.fuzzSeed)
            cards[card.id] = card
            changed = true
        }
        if changed { persist() }
    }

    /// Records each phrase's meaning in the language these lessons are
    /// written in, so a learner who switches language reviews in the new one.
    /// Saved words take their meaning from the lessons' word glosses.
    func learnMeanings(from lessons: [Lesson]) {
        var changed = false
        func learn(_ meaning: MemoryCard.LocalizedMeaning, language: AppLanguage, for key: String) {
            guard var card = cards[key], card.meanings?[language.rawValue] != meaning else { return }
            card.meanings = (card.meanings ?? [:]).merging([language.rawValue: meaning]) { $1 }
            cards[key] = card
            changed = true
        }
        for lesson in lessons {
            let candidates = MemoryCandidate.phrases(in: lesson, accent: lesson.accent)
            guard let language = candidates.first.map({ $0.translationLanguage ?? .english }) else { continue }
            for candidate in candidates {
                learn(.init(translation: candidate.translation, hint: candidate.hint), language: language, for: candidate.key)
            }
            // A word means different things in different phrases ("bộ" is
            // "set" alone, "progress" in "tiến bộ"), so only the gloss from
            // the sentence the word was saved from counts.
            for step in lesson.steps {
                let sentence = MemoryCard.normalized(step.vietnamese)
                for gloss in step.wordGlosses {
                    let key = MemoryCard.key(for: gloss.token, accent: lesson.accent)
                    guard let card = cards[key],
                          card.source == .savedWord,
                          card.hint.map(MemoryCard.normalized) == sentence,
                          !gloss.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else { continue }
                    learn(.init(translation: gloss.translation, hint: nil), language: language, for: key)
                }
            }
        }
        if changed { persist() }
    }

    /// Fixes cards from an earlier build that labelled translated lessons
    /// with the app's language at launch, which could disagree with the text.
    private func repairMeaningLanguage(from candidates: [MemoryCandidate]) -> Bool {
        var changed = false
        for candidate in candidates {
            guard var card = cards[candidate.key],
                  card.source == .lesson,
                  card.translation == candidate.translation,
                  card.meaningLanguage != (candidate.translationLanguage ?? .english)
            else { continue }
            card.translationLanguage = candidate.translationLanguage
            cards[card.id] = card
            changed = true
        }
        return changed
    }

    func enroll(savedWord: SavedLessonWord) {
        guard let candidate = MemoryCandidate.word(savedWord) else { return }
        if insertMissing([candidate], metAt: now(), grade: .hard) {
            persist()
        }
    }

    @discardableResult
    private func insertMissing(_ candidates: [MemoryCandidate], metAt date: Date, grade: MemoryGrade) -> Bool {
        var changed = false
        for candidate in candidates where cards[candidate.key] == nil {
            guard cards.count < Self.maximumCards else { break }
            let key = candidate.key
            let card = MemoryCard(
                id: key,
                vietnamese: candidate.vietnamese,
                translation: candidate.translation,
                hint: candidate.hint,
                accent: candidate.accent,
                translationLanguage: candidate.translationLanguage,
                source: candidate.source,
                sourceID: candidate.sourceID,
                enrolledAt: date,
                memory: scheduler.firstReview(grade: grade, at: date, fuzzSeed: MemoryCard.fuzzSeed(for: key))
            )
            cards[key] = card
            changed = true
        }
        return changed
    }

    // MARK: - Queries

    func cards(for accent: VietnameseAccent) -> [MemoryCard] {
        cards.values.filter { $0.accent == accent }
    }

    /// Cards whose review day has come, the most-forgotten first.
    func dueCards(for accent: VietnameseAccent, at date: Date? = nil) -> [MemoryCard] {
        let date = date ?? now()
        let due: [(card: MemoryCard, recall: Double)] = cards(for: accent)
            .filter { $0.memory.dueAt <= date }
            .map { ($0, scheduler.retrievability(of: $0.memory, at: date)) }
        return due
            .sorted { lhs, rhs in
                lhs.recall == rhs.recall ? lhs.card.id < rhs.card.id : lhs.recall < rhs.recall
            }
            .map(\.card)
    }

    func dueCount(for accent: VietnameseAccent) -> Int {
        let date = now()
        return cards.values.reduce(0) { count, card in
            count + (card.accent == accent && card.memory.dueAt <= date ? 1 : 0)
        }
    }

    /// One short session: the most-forgotten due cards, capped so a backlog
    /// never turns into a wall of reviews.
    func sessionCards(for accent: VietnameseAccent, limit: Int = MemoryStore.sessionSize) -> [MemoryCard] {
        Array(dueCards(for: accent).prefix(limit))
    }

    /// The earliest upcoming review day for cards that are not due yet.
    func nextReviewDate(for accent: VietnameseAccent) -> Date? {
        let date = now()
        return cards(for: accent)
            .map(\.memory.dueAt)
            .filter { $0 > date }
            .min()
    }

    func recall(of card: MemoryCard) -> Double {
        scheduler.retrievability(of: card.memory, at: now())
    }

    /// Today's answered reviews: distinct cards and how many were recalled.
    func todaySummary(calendar: Calendar = .autoupdatingCurrent) -> (reviewed: Int, recalled: Int) {
        let today = now()
        var firstGrades: [String: MemoryGrade] = [:]
        for entry in log where calendar.isDate(entry.reviewedAt, inSameDayAs: today) {
            if firstGrades[entry.cardID] == nil {
                firstGrades[entry.cardID] = entry.grade
            }
        }
        return (firstGrades.count, firstGrades.values.filter { $0 != .again }.count)
    }

    // MARK: - Reviewing

    /// Applies one graded answer. Only the first answer per card per day
    /// moves the schedule; a retry after a mistake is practice, not evidence.
    @discardableResult
    func record(
        cardID: String,
        grade: MemoryGrade,
        exercise: ReviewExerciseKind,
        at date: Date? = nil
    ) -> MemoryCard? {
        let date = date ?? now()
        guard var card = cards[cardID] else { return nil }
        let predictedRecall = scheduler.retrievability(of: card.memory, at: date)
        card.memory = scheduler.review(card.memory, grade: grade, at: date, fuzzSeed: card.fuzzSeed)
        cards[cardID] = card
        log.append(
            MemoryReviewLogEntry(
                cardID: cardID,
                grade: grade,
                exercise: exercise,
                reviewedAt: date,
                predictedRecall: predictedRecall
            )
        )
        if log.count > Self.maximumLogEntries {
            log.removeFirst(log.count - Self.maximumLogEntries)
        }
        persist()
        return card
    }

    // MARK: - Sync

    func snapshot() -> MemorySnapshot {
        MemorySnapshot(cards: cards.values.sorted { $0.id < $1.id })
    }

    /// Combines another device's deck with this one, keeping whichever copy
    /// of each card was reviewed most recently. Nothing is ever dropped, so a
    /// stale or missing snapshot cannot erase progress.
    func merge(_ snapshot: MemorySnapshot?) {
        guard let snapshot, snapshot.schemaVersion == MemorySnapshot.currentSchemaVersion else { return }
        var changed = false
        for remote in snapshot.cards {
            let merged = cards[remote.id].map { Self.newer($0, remote) } ?? remote
            if cards[remote.id] != merged {
                cards[remote.id] = merged
                changed = true
            }
        }
        if changed { persist() }
    }

    func reset() {
        cards = [:]
        log = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    private func persist() {
        let document = Document(cards: Array(cards.values), log: log)
        guard let data = try? JSONEncoder().encode(document) else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Could not persist memory deck: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func newer(_ lhs: MemoryCard, _ rhs: MemoryCard) -> MemoryCard {
        if lhs.memory.lastReviewedAt != rhs.memory.lastReviewedAt {
            return lhs.memory.lastReviewedAt > rhs.memory.lastReviewedAt ? lhs : rhs
        }
        return lhs.memory.reps >= rhs.memory.reps ? lhs : rhs
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Kumusta", isDirectory: true)
            .appendingPathComponent("memory-v1.json", isDirectory: false)
    }
}
