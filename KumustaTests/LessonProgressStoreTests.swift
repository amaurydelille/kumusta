import Foundation
import Testing
@testable import Kumusta

struct LessonProgressStoreTests {
    @MainActor
    @Test
    func partialLessonResumesAtTheNextUnfinishedStepAfterRecreation() throws {
        let suiteName = "kumusta.tests.progress.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let lesson = SampleContent.dailySession(
            level: .intermediate,
            dailyMinutes: 7
        )

        LessonProgressStore(defaults: defaults).save(nextStepIndex: 8, for: lesson)
        let restored = LessonProgressStore(defaults: defaults)

        #expect(restored.resumeStepIndex(for: lesson) == 8)
    }

    @MainActor
    @Test
    func progressNeverMovesBehindThePracticeEntryPoint() throws {
        let suiteName = "kumusta.tests.progress.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let lesson = SampleContent.dailySession(
            level: .intermediate,
            dailyMinutes: 5
        )
        let store = LessonProgressStore(defaults: defaults)

        #expect(store.resumeStepIndex(for: lesson, minimum: 1) == 1)
        store.save(nextStepIndex: 4, for: lesson)
        #expect(store.resumeStepIndex(for: lesson, minimum: 1) == 4)
    }

    @MainActor
    @Test
    func completingFeedbackClearsSavedProgress() throws {
        let suiteName = "kumusta.tests.progress.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let lesson = SampleContent.dailySession(
            level: .advanced,
            dailyMinutes: 5
        )
        let store = LessonProgressStore(defaults: defaults)
        store.save(nextStepIndex: lesson.steps.count, for: lesson)

        store.clear(for: lesson.id)

        #expect(store.resumeStepIndex(for: lesson) == 0)
    }
}
