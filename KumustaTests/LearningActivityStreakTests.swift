import Foundation
import Testing
@testable import Kumusta

@MainActor
@Suite("Calendar streaks")
struct LearningActivityStreakTests {
    @Test("Consecutive calendar days form the streak")
    func consecutiveDays() throws {
        let context = try TestActivityContext()
        defer { context.cleanup() }

        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 29))
        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 30))
        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 31))

        #expect(context.store.currentStreak() == 3)
    }

    @Test("A missed day resets the streak")
    func gapResetsStreak() throws {
        let context = try TestActivityContext()
        defer { context.cleanup() }

        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 28))
        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 31))

        #expect(context.store.currentStreak() == 1)
    }

    @Test("A streak remains visible before today's session")
    func yesterdayKeepsStreakAlive() throws {
        let context = try TestActivityContext()
        defer { context.cleanup() }

        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 29))
        context.store.recordLesson(minutes: 7, on: context.date(year: 2026, month: 7, day: 30))

        #expect(context.store.currentStreak() == 2)
        #expect(!context.store.isTodayComplete)
    }

    @Test("Two sessions on one day count once for the streak, but both in activity")
    func sameDayDoesNotInflateStreak() throws {
        let context = try TestActivityContext()
        defer { context.cleanup() }

        let morning = context.date(year: 2026, month: 7, day: 31, hour: 8)
        let evening = context.date(year: 2026, month: 7, day: 31, hour: 20)
        context.store.recordLesson(minutes: 5, on: morning)
        context.store.recordLesson(minutes: 10, on: evening)

        #expect(context.store.currentStreak() == 1)
        #expect(context.store.todayMinutes == 15)
        #expect(context.store.weekSessions == 2)
    }
}

@MainActor
private struct TestActivityContext {
    let suiteName: String
    let defaults: UserDefaults
    let calendar: Calendar
    let referenceDate: Date
    let store: LocalLearningActivityStore

    init() throws {
        suiteName = "KumustaActivityTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        calendar = utcCalendar
        let fixedReferenceDate = try #require(
            utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 12))
        )
        referenceDate = fixedReferenceDate
        store = LocalLearningActivityStore(
            defaults: defaults,
            calendar: utcCalendar,
            now: { fixedReferenceDate }
        )
    }

    func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
