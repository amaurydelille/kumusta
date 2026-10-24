import Foundation

/// The local, deterministic scheduling policy shown in the practice UI.
///
/// The repository remains the source of truth after a review is recorded. This
/// helper gives the learner an immediate, date-aware preview of what each rating
/// means without relying on hard-coded presentation strings.
struct PracticeSchedule: Equatable, Sendable {
    let rating: ReviewRating
    let reviewedAt: Date
    let nextReviewAt: Date
    let intervalLabel: String
}

enum PracticeScheduler {
    static func schedule(
        for rating: ReviewRating,
        reviewedAt: Date = .now,
        calendar: Calendar = .current
    ) -> PracticeSchedule {
        let nextReviewAt: Date

        switch rating {
        case .again:
            nextReviewAt = reviewedAt.addingTimeInterval(30)
        case .almost:
            nextReviewAt = calendar.date(byAdding: .day, value: 1, to: reviewedAt)
                ?? reviewedAt.addingTimeInterval(86_400)
        case .gotIt:
            nextReviewAt = calendar.date(byAdding: .day, value: 4, to: reviewedAt)
                ?? reviewedAt.addingTimeInterval(345_600)
        }

        return PracticeSchedule(
            rating: rating,
            reviewedAt: reviewedAt,
            nextReviewAt: nextReviewAt,
            intervalLabel: intervalLabel(
                for: nextReviewAt,
                reviewedAt: reviewedAt,
                calendar: calendar
            )
        )
    }

    private static func intervalLabel(
        for nextReviewAt: Date,
        reviewedAt: Date,
        calendar: Calendar
    ) -> String {
        let seconds = nextReviewAt.timeIntervalSince(reviewedAt)
        if seconds < 60 {
            let secondsCount = max(1, Int(seconds.rounded()))
            return L(one: "%lld second", other: "%lld seconds", count: secondsCount)
        }

        if calendar.isDate(nextReviewAt, inSameDayAs: reviewedAt) {
            let minutes = max(1, Int((seconds / 60).rounded()))
            return L(one: "%lld minute", other: "%lld minutes", count: minutes)
        }

        let reviewedDay = calendar.startOfDay(for: reviewedAt)
        let nextDay = calendar.startOfDay(for: nextReviewAt)
        let days = max(
            1,
            calendar.dateComponents([.day], from: reviewedDay, to: nextDay).day ?? 1
        )
        if days == 1 {
            return L("Tomorrow")
        }
        return L(one: "%lld day", other: "%lld days", count: days)
    }
}
