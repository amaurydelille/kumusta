import Foundation
import Testing
@testable import Kumusta

struct LearningJourneyStoreTests {
    @MainActor @Test
    func completionIDsSurviveHistoryTrimmingSyncAndReset() throws {
        let suite = "kumusta.tests.goal-progress.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: url)
        var ids = Set<UUID>()
        for index in 0..<105 {
            let id = UUID()
            ids.insert(id)
            store.recordCompletion(lesson: Lesson(id: id, scenario: "Lesson \(index)", minutes: 5,
                accent: .southern, steps: []), generatedLessonID: nil,
                feedback: SessionFeedback(difficulty: .justRight, audioPace: .justRight, nextLessonTopic: nil))
        }
        #expect(store.completedLessons.count == 100)
        #expect(store.completedLessonIDs == ids)
        let restored = LearningJourneyStore(defaults: defaults, historyFileURL: url)
        #expect(restored.completedLessonIDs == ids)
        let snapshot = try JSONDecoder().decode(LearningJourneySnapshot.self, from: JSONEncoder().encode(store.snapshot()))
        restored.replace(with: snapshot)
        #expect(restored.completedLessonIDs == ids)
        restored.reset()
        #expect(restored.completedLessonIDs.isEmpty)
        #expect(LearningJourneyStore(defaults: defaults, historyFileURL: url).completedLessonIDs.isEmpty)
    }
    @MainActor
    @Test
    func completedLessonSurvivesStoreRecreation() throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let lesson = SampleContent.dailySession(
            accent: .southern,
            level: .familiar,
            dailyMinutes: 5
        )
        let generatedID = UUID()

        LearningJourneyStore(defaults: defaults, historyFileURL: historyURL).recordCompletion(
            lesson: lesson,
            generatedLessonID: generatedID,
            feedback: SessionFeedback(
                difficulty: .justRight,
                audioPace: .tooFast,
                nextLessonTopic: "Renewing my papers"
            )
        )

        let restored = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)
        let record = try #require(restored.completedLessons.first)
        #expect(record.lesson == lesson)
        #expect(record.generatedLessonID == generatedID)
        #expect(record.requestedNextTopic == "Renewing my papers")
        #expect(record.paceFeedback == .tooFast)
    }

    @MainActor
    @Test
    func explicitTopicWaitsForPriorityDeliveryAndRejectsCompletedLesson() async throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let completed = SampleContent.dailySession(
            accent: .southern,
            level: .familiar,
            dailyMinutes: 5
        )
        let stale = lessonCopy(completed, id: UUID(), title: "Older queue lesson")
        let requested = lessonCopy(completed, id: UUID(), title: "Renewing papers")
        let service = JourneyLearningServiceStub(contents: [
            content(lesson: completed, priority: 100),
            content(lesson: stale, priority: 0),
            content(lesson: requested, priority: 100),
        ])
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)
        store.beginPreparingNextLesson(
            after: completed.id,
            requestedTopic: "Renewing my papers"
        )

        await store.pollForPreparedLesson(
            using: service,
            profile: .newUser,
            maximumAttempts: 3
        )

        #expect(store.preparedContent?.lesson.id == requested.id)
        #expect(store.isPreparingNextLesson == false)
        #expect(store.consumePreparedContent(accent: .northern) == nil)
        #expect(store.consumePreparedContent(accent: .southern)?.lesson.id == requested.id)
        // Switching accents must not delete a prepared lesson or its progress.
        #expect(store.preparedContent?.lesson.id == requested.id)
    }

    @MainActor
    @Test
    func newlyPreparedLessonDoesNotInheritPriorDailyCompletion() throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let completed = SampleContent.dailySession(
            accent: .southern,
            level: .familiar,
            dailyMinutes: 5
        )
        let nextLesson = lessonCopy(completed, id: UUID(), title: "A fresh lesson")
        let completedGeneratedID = UUID()
        let nextGeneratedID = UUID()
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)

        store.recordCompletion(
            lesson: completed,
            generatedLessonID: completedGeneratedID,
            feedback: SessionFeedback(
                difficulty: .justRight,
                audioPace: .justRight,
                nextLessonTopic: nil
            )
        )

        #expect(store.isLessonCompleted(completed, generatedLessonID: completedGeneratedID))
        #expect(store.isLessonCompleted(nextLesson, generatedLessonID: nextGeneratedID) == false)
    }

    @MainActor
    @Test
    func terminalGenerationFailureStopsPollingImmediately() async throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let service = JourneyLearningServiceStub(
            contents: [],
            error: PersonalizedLearningError.requestRejected
        )
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)
        store.beginPreparingNextLesson(
            after: UUID(),
            requestedTopic: "A natural conversation"
        )

        await store.pollForPreparedLesson(
            using: service,
            profile: .newUser,
            maximumAttempts: 42
        )

        #expect(store.preparationPhase == .failed)
        #expect(store.isPreparingNextLesson)
        #expect(await service.requestCount == 1)
    }

    @MainActor
    @Test
    func rejectedSubmissionPreservesRequestForRetry() throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)
        store.beginPreparingNextLesson(after: UUID(), requestedTopic: "House furniture")

        store.failPendingPreparation(with: PersonalizedLearningError.requestRejected)

        #expect(store.preparationPhase == .failed)
        #expect(store.isPreparingNextLesson)
        #expect(store.preparationFailure == .requestRejected)
        #expect(store.preparationErrorMessage?.isEmpty == false)
    }

    @MainActor
    @Test
    func stalePreparationIsDiscardedWhenStoreIsRestored() throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)
        store.beginPreparingNextLesson(
            after: UUID(),
            requestedTopic: "History of Vietnam",
            requestedAt: .now.addingTimeInterval(-LearningJourneyStore.maximumPreparationAge - 1)
        )

        let restored = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)

        #expect(restored.isPreparingNextLesson == false)
        #expect(restored.preparationPhase == .idle)
        #expect(defaults.data(forKey: LearningJourneyStore.pendingStorageKey) == nil)
    }

    @MainActor
    @Test
    func exhaustedPollingPreservesRequestForRetry() async throws {
        let suiteName = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let service = JourneyLearningServiceStub(contents: [])
        let store = LearningJourneyStore(defaults: defaults, historyFileURL: historyURL)
        store.beginPreparingNextLesson(after: UUID(), requestedTopic: "History of Vietnam")

        await store.pollForPreparedLesson(
            using: service,
            profile: .newUser,
            maximumAttempts: 1
        )

        #expect(store.isPreparingNextLesson)
        #expect(store.preparationPhase == .failed)
        #expect(defaults.data(forKey: LearningJourneyStore.pendingStorageKey) != nil)
    }

    @MainActor
    @Test
    func generationCanFinishAfterTheOld45SecondDeadline() async throws {
        let suite = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LearningJourneyStore(defaults: defaults)
        let lesson = SampleContent.dailySession(accent: .southern, level: .familiar, dailyMinutes: 5)
        let service = JourneyLearningServiceStub(contents: [content(lesson: lesson, priority: 100)])
        store.beginPreparingNextLesson(after: UUID(), requestedTopic: "Coffee", requestedAt: .now.addingTimeInterval(-90))
        await store.pollForPreparedLesson(using: service, profile: .newUser, maximumAttempts: 1)
        #expect(store.preparedContent?.lesson.id == lesson.id)
        #expect(await service.freshRequestCount == 1)
    }

    @MainActor
    @Test
    func failedPreparationCanActuallyBeRetried() async throws {
        let suite = "kumusta.tests.journey.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LearningJourneyStore(defaults: defaults)
        let lesson = SampleContent.dailySession(accent: .southern, level: .familiar, dailyMinutes: 5)
        let service = JourneyLearningServiceStub(contents: [content(lesson: lesson, priority: 100)])
        store.beginPreparingNextLesson(after: UUID(), requestedTopic: "Coffee", requiresFreshGeneration: true)
        store.failPendingPreparation(with: PersonalizedLearningError.generationFailed)
        await store.retryPreparedLesson(using: service, profile: .newUser)
        #expect(store.preparedContent?.lesson.id == lesson.id)
        #expect(await service.retryCount == 1)
        #expect(await service.receivedFreshnessBoundary)
    }

    private func lessonCopy(_ lesson: Lesson, id: UUID, title: String) -> Lesson {
        Lesson(
            id: id,
            scenario: title,
            minutes: lesson.minutes,
            accent: lesson.accent,
            steps: lesson.steps
        )
    }

    private func content(lesson: Lesson, priority: Int) -> PersonalizedLearningContent {
        PersonalizedLearningContent(
            lesson: lesson,
            vocabulary: [],
            generatedLessonID: lesson.id,
            queueDepth: 1,
            deliveryPriority: priority
        )
    }
}

private actor JourneyLearningServiceStub: PersonalizedLearningProviding {
    private var contents: [PersonalizedLearningContent]
    private let error: PersonalizedLearningError?
    private(set) var requestCount = 0
    private(set) var freshRequestCount = 0
    private(set) var retryCount = 0
    private(set) var receivedFreshnessBoundary = false

    init(contents: [PersonalizedLearningContent], error: PersonalizedLearningError? = nil) {
        self.contents = contents
        self.error = error
    }

    func nextContent(for profile: UserProfile) async throws -> PersonalizedLearningContent? {
        requestCount += 1
        if let error { throw error }
        guard !contents.isEmpty else { return nil }
        return contents.removeFirst()
    }

    func preparedContent(for profile: UserProfile, after lessonID: UUID, generatedAfter: Date?, requestedTopic: String?, retry: Bool) async throws -> PersonalizedLearningContent? {
        freshRequestCount += 1
        if retry { retryCount += 1 }
        receivedFreshnessBoundary = generatedAfter != nil
        return try await nextContent(for: profile)
    }

    func completeLesson(
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile
    ) async throws {}

    func recordGeneratedVocabularyReview(
        vocabularyID: UUID,
        generatedLessonID: UUID,
        rating: ReviewRating,
        profile: UserProfile
    ) async throws {}
}
