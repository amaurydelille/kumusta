import Foundation
import Testing
@testable import Kumusta

@Suite("Review scheduling")
struct ReviewSchedulingTests {
    @Test("All ratings expose readable labels")
    func labelsAreReadable() {
        for rating in ReviewRating.allCases {
            #expect(!rating.title.isEmpty)
            #expect(!rating.intervalLabel.isEmpty)
        }
    }

    @Test("Accent maps to approved female voices")
    func voiceAllowlist() {
        #expect(VietnameseAccent.southern.elevenLabsVoiceID == "6Xq32rHt6oAu98TBDKfr")
        #expect(VietnameseAccent.northern.elevenLabsVoiceID == "LD1UihCXvSlUL4h8DOmk")
    }

    @Test("Onboarding uses the authored accent samples")
    func accentSamples() {
        #expect(VietnameseAccent.southern.sample == "Hãy nói giọng miền Nam nhe!")
        #expect(VietnameseAccent.northern.sample == "Hãy nói giọng miền Bắc nhé!")
        #expect(VietnameseAccent.southern.sampleAudioResourceName == "southern")
        #expect(VietnameseAccent.northern.sampleAudioResourceName == "northern")
    }

    @Test("Review intervals match the learner-facing promise")
    func deterministicIntervals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reviewedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let again = PracticeScheduler.schedule(
            for: .again,
            reviewedAt: reviewedAt,
            calendar: calendar
        )
        let almost = PracticeScheduler.schedule(
            for: .almost,
            reviewedAt: reviewedAt,
            calendar: calendar
        )
        let gotIt = PracticeScheduler.schedule(
            for: .gotIt,
            reviewedAt: reviewedAt,
            calendar: calendar
        )

        #expect(again.nextReviewAt.timeIntervalSince(reviewedAt) == 30)
        #expect(again.intervalLabel == "30 seconds")
        #expect(almost.intervalLabel == "Tomorrow")
        #expect(gotIt.intervalLabel == "4 days")
    }
}

@MainActor
@Suite("Rating prompt policy")
struct RatingPromptPolicyTests {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(days: Double) { date += days * 86_400 }
        func advance(minutes: Double) { date += minutes * 60 }
    }

    private func makeManager(
        defaults: UserDefaults,
        clock: Clock,
        version: String = "1.3.0"
    ) -> RatingPromptManager {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return RatingPromptManager(
            defaults: defaults,
            appVersion: version,
            calendar: calendar,
            ignoresEngagementThresholds: false,
            now: { clock.date }
        )
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "kumusta.tests.rating-prompt.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    /// Subscribed learner, a good lesson today and another tomorrow.
    private func engage(_ manager: RatingPromptManager, clock: Clock) {
        manager.noteActiveDay()
        manager.record(.subscriptionPurchased)
        manager.record(.lesson(difficulty: .justRight))
        clock.advance(days: 1)
        manager.noteActiveDay()
    }

    @Test("A brand-new learner is never asked, even after a win")
    func newLearnerIsNotAsked() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            manager.record(.subscriptionPurchased)
            manager.record(.lesson(difficulty: .justRight))
            #expect(!manager.isArmed)
            #expect(manager.commitRequest() == nil)
        }
    }

    @Test("Purchasing alone never arms the request")
    func subscriptionIsNotAWin() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            engage(manager, clock: clock)
            manager.record(.subscriptionPurchased)
            #expect(!manager.isArmed)
        }
    }

    @Test("An engaged learner is asked after a win, once per version")
    func engagedLearnerIsAskedOncePerVersion() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            engage(manager, clock: clock)
            manager.record(.lesson(difficulty: .justRight))
            #expect(manager.isArmed)
            let request = try #require(manager.commitRequest())
            #expect(request.trigger == .lessonCompleted)
            #expect(manager.commitRequest() == nil)

            clock.advance(days: 200)
            manager.record(.lesson(difficulty: .justRight))
            #expect(!manager.isArmed)
        }
    }

    @Test("A new version after the cooldown can ask again")
    func newVersionAfterCooldownCanAsk() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let first = makeManager(defaults: defaults, clock: clock, version: "1.3.0")
            engage(first, clock: clock)
            first.record(.lesson(difficulty: .justRight))
            #expect(first.commitRequest() != nil)

            clock.advance(days: 30)
            let soon = makeManager(defaults: defaults, clock: clock, version: "1.4.0")
            engage(soon, clock: clock)
            soon.record(.lesson(difficulty: .justRight))
            #expect(!soon.isArmed)

            clock.advance(days: 100)
            let later = makeManager(defaults: defaults, clock: clock, version: "1.5.0")
            engage(later, clock: clock)
            later.record(.lesson(difficulty: .justRight))
            #expect(later.isArmed)
        }
    }

    @Test("Friction blocks the request for the quiet period")
    func frictionBlocksRequest() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            engage(manager, clock: clock)
            manager.recordFriction()
            manager.record(.lesson(difficulty: .justRight))
            #expect(!manager.isArmed)

            clock.advance(days: 3)
            manager.record(.lesson(difficulty: .justRight))
            #expect(manager.isArmed)
        }
    }

    @Test("Weak results never arm the request")
    func weakResultsAreNotWins() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            engage(manager, clock: clock)
            manager.record(.lesson(difficulty: .tooHard))
            manager.record(.flashcards(correctCount: 2, cardCount: 10))
            manager.record(.livePractice(activeSeconds: 20, userTurns: 1))
            #expect(!manager.isArmed)
        }
    }

    @Test("An armed request expires if no natural break follows")
    func armedRequestExpires() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            engage(manager, clock: clock)
            manager.record(.livePractice(activeSeconds: 240, userTurns: 8))
            #expect(manager.isArmed)
            clock.advance(minutes: 16)
            #expect(!manager.isArmed)
            #expect(manager.commitRequest() == nil)
        }
    }

    @Test("History survives relaunch and cloud state never erases it")
    func historyPersists() throws {
        try withDefaults { defaults in
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            engage(manager, clock: clock)
            manager.record(.lesson(difficulty: .justRight))
            #expect(manager.commitRequest() != nil)

            let relaunched = makeManager(defaults: defaults, clock: clock)
            relaunched.replaceClaimedState(false)
            #expect(relaunched.hasClaimedFirstExperiencePrompt)
            relaunched.record(.lesson(difficulty: .justRight))
            #expect(!relaunched.isArmed)
        }
    }

    @Test("Learners who saw the old subscription sheet can still be asked")
    func legacyClaimDoesNotBlock() throws {
        try withDefaults { defaults in
            defaults.set(true, forKey: "kumusta.rating-prompt.subscription-completed.v1")
            let clock = Clock()
            let manager = makeManager(defaults: defaults, clock: clock)
            #expect(manager.hasClaimedFirstExperiencePrompt)
            engage(manager, clock: clock)
            manager.record(.lesson(difficulty: .justRight))
            let request = try #require(manager.commitRequest())
            #expect(request.priorRequests == 1)
        }
    }
}

@Suite("Hosted paywall routing")
struct HostedPaywallRoutingTests {
    @Test("A successful purchase suppresses the following dismissal route")
    func purchaseThenDismissDoesNotOpenFallbackPaywall() {
        var gate = HostedPaywallRoutingGate()

        #expect(gate.shouldRouteDismissal)
        let didBeginPremiumAccess = gate.beginPremiumAccess()
        #expect(didBeginPremiumAccess)
        #expect(!gate.shouldRouteDismissal)
    }

    @Test("Only one premium route can be started")
    func duplicatePurchaseCallbacksDoNotRouteTwice() {
        var gate = HostedPaywallRoutingGate()

        let firstAttempt = gate.beginPremiumAccess()
        let secondAttempt = gate.beginPremiumAccess()
        #expect(firstAttempt)
        #expect(!secondAttempt)
    }
}
