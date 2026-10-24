import Foundation
import Testing
@testable import Kumusta

struct MemorySchedulerTests {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let scheduler = MemoryScheduler(calendar: Self.utcCalendar)
    private let start = Date(timeIntervalSince1970: 1_790_000_000) // a fixed UTC afternoon

    @Test
    func recallIsNinetyPercentAfterOneStabilityPeriod() {
        let recall = MemoryScheduler.retrievability(elapsedDays: 10, stability: 10)
        #expect(abs(recall - 0.9) < 0.0001)
        #expect(MemoryScheduler.retrievability(elapsedDays: 0, stability: 10) == 1)
    }

    @Test
    func firstReviewUsesTheFSRSInitialStabilities() {
        let again = scheduler.firstReview(grade: .again, at: start)
        let hard = scheduler.firstReview(grade: .hard, at: start)
        let good = scheduler.firstReview(grade: .good, at: start)

        #expect(again.stability < hard.stability)
        #expect(hard.stability < good.stability)
        #expect(abs(good.stability - 3.173) < 0.0001)
        #expect(again.lapses == 1)
        #expect(good.reps == 1)
        #expect(good.difficulty < again.difficulty)
    }

    @Test
    func dueDateIsTheStartOfTheReviewDay() {
        let state = scheduler.firstReview(grade: .hard, at: start)
        let expectedDay = Self.utcCalendar.date(
            byAdding: .day,
            value: 1,
            to: Self.utcCalendar.startOfDay(for: start)
        )
        #expect(state.dueAt == expectedDay)
    }

    @Test
    func successfulReviewsSpreadFurtherApart() {
        var state = scheduler.firstReview(grade: .good, at: start)
        var previousInterval = 0.0
        for _ in 0..<5 {
            let reviewDate = state.dueAt
            state = scheduler.review(state, grade: .good, at: reviewDate)
            let interval = state.dueAt.timeIntervalSince(reviewDate)
            #expect(interval > previousInterval)
            previousInterval = interval
        }
        #expect(state.reps == 6)
        #expect(state.lapses == 0)
        #expect(state.stability > 30)
    }

    @Test
    func forgettingShrinksStabilityAndCountsALapse() {
        var state = scheduler.firstReview(grade: .good, at: start)
        state = scheduler.review(state, grade: .good, at: state.dueAt)
        let beforeLapse = state

        let lapsed = scheduler.review(state, grade: .again, at: state.dueAt)

        #expect(lapsed.stability < beforeLapse.stability)
        #expect(lapsed.lapses == beforeLapse.lapses + 1)
        #expect(lapsed.difficulty > beforeLapse.difficulty)
        #expect(lapsed.dueAt > lapsed.lastReviewedAt)
    }

    @Test
    func reviewingTheNextMorningCountsAsANextDayReview() {
        let evening = start // a fixed UTC afternoon
        let first = scheduler.firstReview(grade: .good, at: evening)
        let nextMorning = Self.utcCalendar.date(
            byAdding: .hour,
            value: 8,
            to: Self.utcCalendar.date(byAdding: .day, value: 1, to: Self.utcCalendar.startOfDay(for: evening))!
        )!
        #expect(nextMorning.timeIntervalSince(evening) < 86_400)

        let nextDay = scheduler.review(first, grade: .good, at: nextMorning)
        let sameDay = scheduler.review(first, grade: .good, at: evening.addingTimeInterval(3_600))

        #expect(nextDay.stability > sameDay.stability)
        #expect(nextDay.stability > first.stability * 1.5)
    }

    @Test
    func hardGrowsLessThanGood() {
        let state = scheduler.firstReview(grade: .good, at: start)
        let reviewDate = state.dueAt
        let hard = scheduler.review(state, grade: .hard, at: reviewDate)
        let good = scheduler.review(state, grade: .good, at: reviewDate)
        let easy = scheduler.review(state, grade: .easy, at: reviewDate)

        #expect(hard.stability < good.stability)
        #expect(good.stability < easy.stability)
    }

    @Test
    func overdueSuccessIsRewardedMoreThanOnTimeSuccess() {
        let state = scheduler.firstReview(grade: .good, at: start)
        let onTime = scheduler.review(state, grade: .good, at: state.dueAt)
        let late = scheduler.review(
            state,
            grade: .good,
            at: state.dueAt.addingTimeInterval(10 * 86_400)
        )
        #expect(late.stability > onTime.stability)
    }

    @Test
    func intervalsStayWithinBounds() {
        #expect(scheduler.intervalDays(for: 0.01) == 1)
        #expect(scheduler.intervalDays(for: 100_000) == 365)
    }

    @Test
    func fuzzIsSmallAndStable() {
        let plain = scheduler.intervalDays(for: 40)
        let fuzzed = scheduler.intervalDays(for: 40, fuzzSeed: 9_999)
        #expect(abs(fuzzed - plain) <= 2)
        #expect(scheduler.intervalDays(for: 40, fuzzSeed: 1_234) == scheduler.intervalDays(for: 40, fuzzSeed: 1_234))
    }

    @Test
    func difficultyStaysInRange() {
        var state = scheduler.firstReview(grade: .again, at: start)
        for _ in 0..<20 {
            state = scheduler.review(state, grade: .again, at: state.dueAt)
            #expect((1...10).contains(state.difficulty))
        }
        for _ in 0..<20 {
            state = scheduler.review(state, grade: .easy, at: state.dueAt)
            #expect((1...10).contains(state.difficulty))
        }
    }
}
