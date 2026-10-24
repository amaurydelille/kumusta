import Foundation

/// Something the learner just finished, scored by how likely it is to leave
/// them proud of their progress. Only wins can arm the native rating request;
/// everything else just adds engagement to the score.
struct ReviewSignal: Equatable, Sendable {
    enum Kind: String, Sendable {
        case lessonCompleted = "lesson_completed"
        case flashcardsCompleted = "flashcards_completed"
        case livePracticeCompleted = "live_practice_completed"
        case subscriptionPurchased = "subscription_purchased"
    }

    let kind: Kind
    let weight: Double
    let isWin: Bool

    /// "Too hard" is honest feedback, not a celebration: it still counts as
    /// engagement but never arms the prompt.
    static func lesson(difficulty: LessonDifficultyFeedback) -> ReviewSignal {
        difficulty == .tooHard
            ? ReviewSignal(kind: .lessonCompleted, weight: 2, isWin: false)
            : ReviewSignal(kind: .lessonCompleted, weight: 6, isWin: true)
    }

    static func flashcards(correctCount: Int, cardCount: Int) -> ReviewSignal {
        isStrongResult(correct: correctCount, total: cardCount, minimumTotal: 3)
            ? ReviewSignal(kind: .flashcardsCompleted, weight: 4, isWin: true)
            : ReviewSignal(kind: .flashcardsCompleted, weight: 1, isWin: false)
    }

    /// A real back-and-forth, not a quick test of the microphone.
    static func livePractice(activeSeconds: Int, userTurns: Int) -> ReviewSignal {
        activeSeconds >= 90 && userTurns >= 3
            ? ReviewSignal(kind: .livePracticeCompleted, weight: 8, isWin: true)
            : ReviewSignal(kind: .livePracticeCompleted, weight: 2, isWin: false)
    }

    /// Paying is commitment, not yet delight: the learner hasn't felt the value
    /// of the purchase, so it raises the score without arming the prompt.
    static let subscriptionPurchased = ReviewSignal(
        kind: .subscriptionPurchased,
        weight: 10,
        isWin: false
    )

    private static func isStrongResult(correct: Int, total: Int, minimumTotal: Int) -> Bool {
        guard total >= minimumTotal, total > 0 else { return false }
        return Double(correct) / Double(total) >= 0.7
    }
}

/// Thresholds for when a learner is engaged and happy enough to be asked.
/// StoreKit independently caps the system prompt at three displays a year, so
/// these rules decide which of those few chances we spend, and when.
struct ReviewPromptPolicy: Sendable {
    var scoreThreshold: Double = 15
    var scoreHalfLife: TimeInterval = 7 * 86_400
    var minimumActiveDays = 2
    var minimumWins = 2
    var cooldown: TimeInterval = 120 * 86_400
    var maximumRequestsPerYear = 3
    var frictionQuietPeriod: TimeInterval = 48 * 3_600
    /// How long a win stays fresh enough to justify the request at the next
    /// natural break.
    var armedLifetime: TimeInterval = 15 * 60
    var eventRetention: TimeInterval = 60 * 86_400
}

struct ReviewPromptState: Codable, Equatable, Sendable {
    struct Event: Codable, Equatable, Sendable {
        var date: Date
        var weight: Double
        var isWin: Bool
    }

    var events: [Event] = []
    /// Local calendar days ("yyyy-MM-dd") on which the main app was used.
    var activeDays: [String] = []
    var requestDates: [Date] = []
    var lastRequestedVersion: String?
    var lastFrictionAt: Date?
    /// Set when an older build already spent a request (the one-time
    /// post-subscription sheet) at a date we no longer know.
    var hasLegacyRequest = false
}

/// Decides when Kumusta asks StoreKit for a rating. The app never shows its
/// own rating UI and never filters learners by sentiment (App Review 5.6.1):
/// it only picks a happy, natural moment to hand control to the system prompt.
@MainActor
final class RatingPromptManager {
    enum Decision: Equatable {
        case eligible(score: Double)
        case ineligible(reason: String)
    }

    struct Request: Equatable {
        let trigger: ReviewSignal.Kind
        let score: Double
        let activeDays: Int
        let priorRequests: Int
    }

    private enum Keys {
        static let state = "kumusta.rating-prompt.state.v2"
        static let legacySubscriptionPromptClaimed = "kumusta.rating-prompt.subscription-completed.v1"
    }

    private let defaults: UserDefaults
    private let policy: ReviewPromptPolicy
    private let appVersion: String?
    private let now: () -> Date
    private let calendar: Calendar
    private let ignoresEngagementThresholds: Bool
    private(set) var state: ReviewPromptState
    private var armed: (trigger: ReviewSignal.Kind, at: Date)?

    init(
        defaults: UserDefaults = .standard,
        policy: ReviewPromptPolicy = ReviewPromptPolicy(),
        appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        calendar: Calendar = .current,
        ignoresEngagementThresholds: Bool = RatingPromptManager.isDemoLaunch,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.policy = policy
        self.appVersion = appVersion
        self.calendar = calendar
        self.ignoresEngagementThresholds = ignoresEngagementThresholds
        self.now = now
        if let data = defaults.data(forKey: Keys.state),
           let decoded = try? JSONDecoder().decode(ReviewPromptState.self, from: data) {
            state = decoded
        } else {
            state = ReviewPromptState()
        }
        if defaults.bool(forKey: Keys.legacySubscriptionPromptClaimed), !state.hasLegacyRequest {
            state.hasLegacyRequest = true
            save()
        }
    }

    /// DEBUG-only launch argument that skips the engagement thresholds so the
    /// flow can be exercised on a simulator. Release builds always use them.
    nonisolated static var isDemoLaunch: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("reviewPromptDemo")
        #else
        false
        #endif
    }

    var hasRequestedReview: Bool {
        state.hasLegacyRequest || !state.requestDates.isEmpty
    }

    /// Kept under the existing cloud-state field name so older synced learner
    /// snapshots remain compatible.
    var hasClaimedFirstExperiencePrompt: Bool {
        hasRequestedReview
    }

    /// Cloud state can only add history, never erase a request made on this
    /// device.
    func replaceClaimedState(_ claimed: Bool) {
        guard claimed, !hasRequestedReview else { return }
        state.hasLegacyRequest = true
        save()
    }

    var isArmed: Bool {
        guard let armed else { return false }
        return now().timeIntervalSince(armed.at) <= policy.armedLifetime
    }

    func noteActiveDay() {
        let date = now()
        markActiveDay(date)
        prune(at: date)
        save()
    }

    /// Records a finished activity and arms the request when it is a win that
    /// pushes an engaged, unfrustrated learner over the threshold.
    @discardableResult
    func record(_ signal: ReviewSignal) -> Decision {
        let date = now()
        state.events.append(.init(date: date, weight: signal.weight, isWin: signal.isWin))
        markActiveDay(date)
        prune(at: date)
        save()

        guard signal.isWin else { return .ineligible(reason: "not_a_win") }
        let decision = evaluate(at: date)
        if case .eligible = decision {
            armed = (signal.kind, date)
        }
        return decision
    }

    /// A failure the learner noticed (dropped connection, unsynced result).
    /// Nobody should be asked for a rating right after the app let them down.
    func recordFriction() {
        state.lastFrictionAt = now()
        armed = nil
        save()
    }

    /// Spends the armed opportunity. Call immediately before asking StoreKit;
    /// re-validates so a stale or superseded arm can never reach the prompt.
    func commitRequest() -> Request? {
        guard isArmed, let armed else {
            self.armed = nil
            return nil
        }
        let date = now()
        guard case let .eligible(score) = evaluate(at: date) else {
            self.armed = nil
            return nil
        }
        let request = Request(
            trigger: armed.trigger,
            score: score,
            activeDays: state.activeDays.count,
            priorRequests: state.requestDates.count + (state.hasLegacyRequest ? 1 : 0)
        )
        state.requestDates.append(date)
        state.lastRequestedVersion = appVersion
        self.armed = nil
        save()
        return request
    }

    func evaluate(at date: Date) -> Decision {
        if let appVersion, state.lastRequestedVersion == appVersion {
            return .ineligible(reason: "already_requested_this_version")
        }
        let lastYear = state.requestDates.filter { date.timeIntervalSince($0) < 365 * 86_400 }
        if lastYear.count >= policy.maximumRequestsPerYear {
            return .ineligible(reason: "yearly_cap")
        }
        if let last = state.requestDates.max(), date.timeIntervalSince(last) < policy.cooldown {
            return .ineligible(reason: "cooldown")
        }
        if let friction = state.lastFrictionAt,
           date.timeIntervalSince(friction) < policy.frictionQuietPeriod {
            return .ineligible(reason: "recent_friction")
        }
        let score = score(at: date)
        if ignoresEngagementThresholds { return .eligible(score: score) }
        if state.activeDays.count < policy.minimumActiveDays {
            return .ineligible(reason: "not_enough_active_days")
        }
        if state.events.filter(\.isWin).count < policy.minimumWins {
            return .ineligible(reason: "not_enough_wins")
        }
        if score < policy.scoreThreshold {
            return .ineligible(reason: "score_below_threshold")
        }
        return .eligible(score: score)
    }

    /// Recent activity counts fully; older activity fades with a half-life so
    /// one busy week months ago cannot trigger a request today.
    func score(at date: Date) -> Double {
        state.events.reduce(0) { total, event in
            let age = max(0, date.timeIntervalSince(event.date))
            return total + event.weight * pow(0.5, age / policy.scoreHalfLife)
        }
    }

    private func markActiveDay(_ date: Date) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let key = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        if !state.activeDays.contains(key) {
            state.activeDays.append(key)
        }
    }

    private func prune(at date: Date) {
        state.events.removeAll { date.timeIntervalSince($0.date) > policy.eventRetention }
        if state.activeDays.count > 60 {
            state.activeDays.removeFirst(state.activeDays.count - 60)
        }
        state.requestDates.removeAll { date.timeIntervalSince($0) > 400 * 86_400 }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Keys.state)
    }
}
