import Foundation

/// How well the learner recalled an item, graded from what they did rather
/// than from a self-rating button.
enum MemoryGrade: Int, Codable, CaseIterable, Sendable {
    /// Failed to recall on the first attempt.
    case again = 1
    /// Recalled, but slowly or only after a correction.
    case hard = 2
    /// Recalled correctly on the first attempt.
    case good = 3
    /// Recalled instantly on a demanding exercise.
    case easy = 4
}

/// The memory model of one item: how long it survives (stability) and how
/// hard it is to make stick (difficulty). Both evolve with every review.
struct MemoryState: Codable, Equatable, Sendable {
    /// Days until the predicted recall probability falls to 90%.
    var stability: Double
    /// 1 (easy) to 10 (hard).
    var difficulty: Double
    var lastReviewedAt: Date
    var dueAt: Date
    var reps: Int
    var lapses: Int
}

/// FSRS-5, the open-source spaced-repetition scheduler Anki ships, with its
/// published default weights. It predicts when each item drops to the target
/// recall probability and schedules the next review for that day.
///
/// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
struct MemoryScheduler: Sendable {
    static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
        2.9898, 0.51655, 0.6621,
    ]

    private static let decay = -0.5
    private static let factor = 19.0 / 81.0
    private static let secondsPerDay = 86_400.0

    let weights: [Double]
    let desiredRetention: Double
    let maximumIntervalDays: Int
    var calendar: Calendar

    init(
        weights: [Double] = MemoryScheduler.defaultWeights,
        desiredRetention: Double = 0.9,
        maximumIntervalDays: Int = 365,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        precondition(weights.count == 19, "FSRS-5 needs 19 weights")
        self.weights = weights
        self.desiredRetention = desiredRetention
        self.maximumIntervalDays = maximumIntervalDays
        self.calendar = calendar
    }

    // MARK: - Prediction

    /// Probability of recalling an item `elapsedDays` after its last review.
    static func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + factor * max(0, elapsedDays) / stability, decay)
    }

    func retrievability(of state: MemoryState, at date: Date) -> Double {
        Self.retrievability(
            elapsedDays: Self.days(from: state.lastReviewedAt, to: date),
            stability: state.stability
        )
    }

    /// Whole days until recall probability reaches the desired retention.
    func intervalDays(for stability: Double, fuzzSeed: UInt64? = nil) -> Int {
        var interval = stability / Self.factor * (pow(desiredRetention, 1 / Self.decay) - 1)
        // A small, stable per-item spread keeps items learned together from
        // always coming due on the same day.
        if let fuzzSeed, interval >= 3 {
            let unit = Double(fuzzSeed % 10_000) / 10_000
            interval *= 0.95 + unit * 0.1
        }
        return min(maximumIntervalDays, max(1, Int(interval.rounded())))
    }

    // MARK: - Scheduling

    /// The state after the first time the learner meets an item.
    func firstReview(grade: MemoryGrade, at date: Date, fuzzSeed: UInt64? = nil) -> MemoryState {
        let stability = initialStability(grade)
        return MemoryState(
            stability: stability,
            difficulty: initialDifficulty(grade),
            lastReviewedAt: date,
            dueAt: dueDate(after: date, stability: stability, fuzzSeed: fuzzSeed),
            reps: 1,
            lapses: grade == .again ? 1 : 0
        )
    }

    /// The state after reviewing an item the learner has seen before.
    func review(
        _ state: MemoryState,
        grade: MemoryGrade,
        at date: Date,
        fuzzSeed: UInt64? = nil
    ) -> MemoryState {
        // FSRS counts whole calendar days: learned in the evening and
        // reviewed the next morning is a next-day review, not a same-day one.
        let elapsed = Double(calendarDays(from: state.lastReviewedAt, to: date))
        let stability: Double
        if elapsed < 1 {
            stability = shortTermStability(state.stability, grade: grade)
        } else {
            let recall = Self.retrievability(elapsedDays: elapsed, stability: state.stability)
            stability = grade == .again
                ? forgetStability(state, retrievability: recall)
                : recallStability(state, retrievability: recall, grade: grade)
        }
        let boundedStability = min(Double(maximumIntervalDays) * 10, max(0.1, stability))
        return MemoryState(
            stability: boundedStability,
            difficulty: nextDifficulty(state.difficulty, grade: grade),
            lastReviewedAt: date,
            dueAt: dueDate(after: date, stability: boundedStability, fuzzSeed: fuzzSeed),
            reps: state.reps + 1,
            lapses: state.lapses + (grade == .again ? 1 : 0)
        )
    }

    // MARK: - FSRS-5 formulas

    private func initialStability(_ grade: MemoryGrade) -> Double {
        max(0.1, weights[grade.rawValue - 1])
    }

    private func initialDifficulty(_ grade: MemoryGrade) -> Double {
        clampDifficulty(rawInitialDifficulty(grade))
    }

    private func rawInitialDifficulty(_ grade: MemoryGrade) -> Double {
        weights[4] - exp(weights[5] * Double(grade.rawValue - 1)) + 1
    }

    private func nextDifficulty(_ difficulty: Double, grade: MemoryGrade) -> Double {
        let delta = -weights[6] * Double(grade.rawValue - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        // Mean reversion toward the difficulty of an item first rated Easy.
        let reverted = weights[7] * rawInitialDifficulty(.easy) + (1 - weights[7]) * damped
        return clampDifficulty(reverted)
    }

    private func recallStability(
        _ state: MemoryState,
        retrievability: Double,
        grade: MemoryGrade
    ) -> Double {
        let hardPenalty = grade == .hard ? weights[15] : 1
        let easyBonus = grade == .easy ? weights[16] : 1
        let growth = exp(weights[8])
            * (11 - state.difficulty)
            * pow(state.stability, -weights[9])
            * (exp(weights[10] * (1 - retrievability)) - 1)
            * hardPenalty
            * easyBonus
        return state.stability * (growth + 1)
    }

    private func forgetStability(_ state: MemoryState, retrievability: Double) -> Double {
        let forgotten = weights[11]
            * pow(state.difficulty, -weights[12])
            * (pow(state.stability + 1, weights[13]) - 1)
            * exp(weights[14] * (1 - retrievability))
        // A lapse can never leave an item more stable than it was.
        return min(forgotten, state.stability / exp(weights[17] * weights[18]))
    }

    private func shortTermStability(_ stability: Double, grade: MemoryGrade) -> Double {
        stability * exp(weights[17] * (Double(grade.rawValue) - 3 + weights[18]))
    }

    private func clampDifficulty(_ value: Double) -> Double {
        min(10, max(1, value))
    }

    /// Due at the start of the target day, so an item learned in the evening
    /// is ready the next morning rather than the next evening.
    private func dueDate(after date: Date, stability: Double, fuzzSeed: UInt64?) -> Date {
        let interval = intervalDays(for: stability, fuzzSeed: fuzzSeed)
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: interval, to: day)
            ?? date.addingTimeInterval(Double(interval) * Self.secondsPerDay)
    }

    private func calendarDays(from start: Date, to end: Date) -> Int {
        max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0)
    }

    static func days(from start: Date, to end: Date) -> Double {
        max(0, end.timeIntervalSince(start) / secondsPerDay)
    }
}
