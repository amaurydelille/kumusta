import Foundation
import Observation

struct ReviewTask: Identifiable, Equatable, Sendable {
    let id: UUID
    let card: MemoryCard
    var kind: ReviewExerciseKind
    /// A second chance at a card missed earlier in the session.
    let isRetry: Bool
}

/// What the learner did on one exercise, before it becomes a grade.
struct ReviewAnswer: Equatable, Sendable {
    let correctOnFirstAttempt: Bool
    let eventuallyCorrect: Bool
    var gaveUp = false
    let responseSeconds: TimeInterval
}

/// One review session: the queue of exercises, mistakes coming back at the
/// end, and the first-attempt grade of each card. Persisting grades is the
/// caller's job, so this stays a pure, testable state machine.
@MainActor
@Observable
final class DailyReviewSession {
    let pool: [MemoryCard]
    let totalCards: Int
    private(set) var tasks: [ReviewTask]
    private(set) var index = 0
    /// First-attempt grade per card; only these move the schedule.
    private(set) var grades: [String: MemoryGrade] = [:]
    private(set) var clearedCardIDs: Set<String> = []
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var canSpeak: Bool

    init<Generator: RandomNumberGenerator>(
        cards: [MemoryCard],
        pool: [MemoryCard],
        canSpeak: Bool,
        using generator: inout Generator
    ) {
        self.pool = pool
        self.canSpeak = canSpeak
        totalCards = cards.count
        var planned = cards.map { card in
            ReviewTask(
                id: UUID(),
                card: card,
                kind: ReviewExercisePlanner.kind(for: card, pool: pool, canSpeak: canSpeak, using: &generator),
                isRetry: false
            )
        }
        // Open with a listening question when there is one: an easy, audible
        // first win before anything is asked from memory.
        if let warmUp = planned.firstIndex(where: { $0.kind == .listenMeaning }), warmUp > 0 {
            planned.insert(planned.remove(at: warmUp), at: 0)
        }
        tasks = planned
    }

    convenience init(cards: [MemoryCard], pool: [MemoryCard], canSpeak: Bool) {
        var generator = SystemRandomNumberGenerator()
        self.init(cards: cards, pool: pool, canSpeak: canSpeak, using: &generator)
    }

    var current: ReviewTask? {
        tasks.indices.contains(index) ? tasks[index] : nil
    }

    var isFinished: Bool { index >= tasks.count }

    /// Advances only when a card is cleared, so a mistake visibly costs a step.
    var progress: Double {
        guard totalCards > 0 else { return 1 }
        return Double(clearedCardIDs.count) / Double(totalCards)
    }

    var answeredCount: Int { grades.count }

    var rememberedCount: Int {
        grades.values.filter { $0 != .again }.count
    }

    /// Grades the current exercise. Returns the grade the first time a card
    /// is answered in this session, which is the one to persist; nil for a
    /// retry. A missed card comes back once at the end of the session.
    @discardableResult
    func submit(_ answer: ReviewAnswer) -> MemoryGrade? {
        guard let task = current else { return nil }
        let grade = ReviewGrader.grade(
            kind: task.kind,
            correctOnFirstAttempt: answer.correctOnFirstAttempt,
            eventuallyCorrect: answer.eventuallyCorrect,
            gaveUp: answer.gaveUp,
            responseSeconds: answer.responseSeconds
        )

        if answer.correctOnFirstAttempt {
            combo += 1
            bestCombo = max(bestCombo, combo)
        } else {
            combo = 0
        }

        let isFirstAnswer = grades[task.card.id] == nil
        if isFirstAnswer {
            grades[task.card.id] = grade
        }

        if grade == .again, !task.isRetry, task.kind != .speak {
            tasks.append(ReviewTask(id: UUID(), card: task.card, kind: task.kind, isRetry: true))
        } else {
            clearedCardIDs.insert(task.card.id)
        }
        return isFirstAnswer ? grade : nil
    }

    func advance() {
        guard !isFinished else { return }
        index += 1
    }

    /// "Can't speak now": the rest of the session switches to silent
    /// production exercises, including the current one.
    func disableSpeaking() {
        canSpeak = false
        for position in tasks.indices where position >= index && tasks[position].kind == .speak {
            let canBuild = (2...ListenTileBank.maximumSyllables).contains(tasks[position].card.syllableCount)
            tasks[position].kind = canBuild ? .build : .pickVietnamese
        }
    }
}
