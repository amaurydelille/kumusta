import Foundation
import Observation

struct LearningActivityDay: Identifiable, Equatable, Sendable {
    let date: Date
    let minutes: Int
    let sessions: Int

    var id: Date { date }
}

struct LearningActivitySnapshot: Codable, Equatable, Sendable {
    let date: Date
    let minutes: Int
    let sessions: Int
}

struct LearningActivityStoreSnapshot: Codable, Equatable, Sendable {
    let days: [LearningActivitySnapshot]
    let streakFreezes: Int
    let lastFreezeAwardDay: Date?
}

@MainActor
@Observable
final class LocalLearningActivityStore {
    private struct Entry: Codable, Equatable {
        let date: Date
        var minutes: Int
        var sessions: Int
    }

    private enum Keys {
        static let entries = "kumusta.learning-activity.v1"
        static let freezeCount = "kumusta.streak-freezes.v1"
        static let lastFreezeAwardDay = "kumusta.streak-freezes.last-award-day.v1"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private var entries: [Entry] = []

    private(set) var streakFreezes: Int = 0
    private var lastFreezeAwardDay: Date = .distantPast

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        reload()
    }

    var isTodayComplete: Bool {
        entries.contains { calendar.isDate($0.date, inSameDayAs: now()) }
    }

    var todayMinutes: Int {
        entries.first(where: { calendar.isDate($0.date, inSameDayAs: now()) })?.minutes ?? 0
    }

    var lastSevenDays: [LearningActivityDay] {
        let today = calendar.startOfDay(for: now())
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let entry = entries.first { calendar.isDate($0.date, inSameDayAs: date) }
            return LearningActivityDay(
                date: date,
                minutes: entry?.minutes ?? 0,
                sessions: entry?.sessions ?? 0
            )
        }
    }

    var weekMinutes: Int {
        lastSevenDays.reduce(0) { $0 + $1.minutes }
    }

    var weekSessions: Int {
        lastSevenDays.reduce(0) { $0 + $1.sessions }
    }

    func snapshot() -> LearningActivityStoreSnapshot {
        LearningActivityStoreSnapshot(
            days: entries.map {
                LearningActivitySnapshot(
                    date: $0.date,
                    minutes: $0.minutes,
                    sessions: $0.sessions
                )
            },
            streakFreezes: streakFreezes,
            lastFreezeAwardDay: lastFreezeAwardDay == .distantPast ? nil : lastFreezeAwardDay
        )
    }

    func replace(with snapshot: LearningActivityStoreSnapshot) {
        let cutoff = calendar.date(byAdding: .day, value: -120, to: now()) ?? .distantPast
        entries = snapshot.days
            .filter { $0.date >= cutoff }
            .map {
                Entry(
                    date: $0.date,
                    minutes: max(0, $0.minutes),
                    sessions: max(0, $0.sessions)
                )
            }
            .sorted { $0.date < $1.date }
        streakFreezes = min(3, max(0, snapshot.streakFreezes))
        lastFreezeAwardDay = snapshot.lastFreezeAwardDay ?? .distantPast
        persist()
        persistFreezeState()
    }

    func recordLesson(minutes: Int, on date: Date? = nil) {
        let today = calendar.startOfDay(for: date ?? now())
        if let index = entries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            entries[index].minutes += max(0, minutes)
            entries[index].sessions += 1
        } else {
            entries.append(Entry(date: today, minutes: max(0, minutes), sessions: 1))
        }
        persist()
    }

    func reconcile(with completedLessons: [CompletedLessonRecord]) {
        var canonical: [Date: Entry] = [:]
        for record in completedLessons {
            let day = calendar.startOfDay(for: record.completedAt)
            var entry = canonical[day] ?? Entry(date: day, minutes: 0, sessions: 0)
            entry.minutes += max(0, record.lesson.minutes)
            entry.sessions += 1
            canonical[day] = entry
        }
        entries = canonical.values.sorted { $0.date < $1.date }
        persist()
    }

    /// Counts consecutive completed calendar days ending today, or yesterday
    /// when the learner has not completed today's session yet.
    func currentStreak(asOf date: Date? = nil) -> Int {
        let referenceDay = calendar.startOfDay(for: date ?? now())
        let completedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

        let startingDay: Date
        if completedDays.contains(referenceDay) {
            startingDay = referenceDay
        } else if
            let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDay),
            completedDays.contains(yesterday)
        {
            startingDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = startingDay
        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    func reload() {
        guard
            let data = defaults.data(forKey: Keys.entries),
            let saved = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            entries = []
            loadFreezeState()
            return
        }
        let cutoff = calendar.date(byAdding: .day, value: -120, to: now()) ?? .distantPast
        entries = saved.filter { $0.date >= cutoff }
        loadFreezeState()
    }

    func reset() {
        entries = []
        streakFreezes = 0
        lastFreezeAwardDay = .distantPast
        defaults.removeObject(forKey: Keys.entries)
        defaults.removeObject(forKey: Keys.freezeCount)
        defaults.removeObject(forKey: Keys.lastFreezeAwardDay)
    }

    // MARK: - Streak Freeze

    /// Awards one streak freeze per completed week of streak (max 3).
    /// Called after each day's activity is recorded.
    func awardFreezeIfEligible() {
        let today = calendar.startOfDay(for: now())
        let streak = currentStreak()

        // Award one freeze per 7-day streak milestone, at most once per day
        let earnedFreezes = streak / 7
        let cap = min(earnedFreezes, 3)

        guard streakFreezes < cap,
              !calendar.isDate(lastFreezeAwardDay, inSameDayAs: today) else { return }

        streakFreezes = min(cap, streakFreezes + 1)
        lastFreezeAwardDay = today
        persistFreezeState()
    }

    /// Consumes a streak freeze if the user missed yesterday.
    /// Returns true if a freeze was used.
    func applyFreezeIfNeeded() -> Bool {
        let today = calendar.startOfDay(for: now())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return false
        }

        let completedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        let yesterdayCompleted = completedDays.contains(yesterday)
        let todayCompleted = completedDays.contains(today)

        // Freeze is only needed if yesterday was missed and today has activity
        guard !yesterdayCompleted, todayCompleted, streakFreezes > 0 else {
            return false
        }

        // Insert a synthetic freeze entry for yesterday
        entries.append(Entry(date: yesterday, minutes: 1, sessions: 1))
        entries.sort { $0.date < $1.date }
        streakFreezes -= 1
        persist()
        persistFreezeState()
        return true
    }

    private func loadFreezeState() {
        streakFreezes = defaults.integer(forKey: Keys.freezeCount)
        if let date = defaults.object(forKey: Keys.lastFreezeAwardDay) as? Date {
            lastFreezeAwardDay = date
        }
    }

    private func persistFreezeState() {
        defaults.set(streakFreezes, forKey: Keys.freezeCount)
        defaults.set(lastFreezeAwardDay, forKey: Keys.lastFreezeAwardDay)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Keys.entries)
    }
}
