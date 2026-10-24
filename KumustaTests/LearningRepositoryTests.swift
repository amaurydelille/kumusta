import Foundation
import Testing
@testable import Kumusta

@Suite("Goal curriculum")
struct GoalCurriculumTests {
    private func rows(goal: LearningGoal = .family) throws -> [GoalCurriculumRow] {
        let rounds: [[String: Any]] = (0..<5).map { index in
            var round: [String: Any] = [
                "situation": "You greet an older relative.", "tagalog": "Kumusta po, Tita.",
                "translation": "Hello, auntie.", "speakingPrompt": "Greet your aunt.",
                "chunks": [["tagalog": "Kumusta po,", "english": "hello (respectful)", "note": "Po shows respect"],
                           ["tagalog": "Tita.", "english": "auntie", "note": "Address her by family title"]],
                "wordGlosses": [["token": "Kumusta", "english": "how are / hello"], ["token": "po,", "english": "(respect)"],
                                ["token": "Tita.", "english": "auntie"]],
            ]
            if [2, 4].contains(index) {
                round["responseExercise"] = ["promptTagalog": "Kumusta po, Tita.",
                    "promptTranslation": "Hello, auntie.", "correctOptionIndex": 1,
                    "options": [["englishTranslation": "Goodbye."], ["englishTranslation": "Hello, auntie."],
                                ["englishTranslation": "Thank you."]]]
            }
            return round
        }
        let objects: [[String: Any]] = (1...4).flatMap { stage in
            (1...10).map { order in
                ["id": UUID().uuidString, "goal": goal.rawValue, "stage": stage,
                 "lesson_order": order, "title": "Visit \(order)",
                 "summary": "Greet your family", "content": ["title": "Visit \(order)", "minutes": 5, "rounds": rounds]]
            }
        }
        return try JSONDecoder().decode([GoalCurriculumRow].self, from: JSONSerialization.data(withJSONObject: objects))
    }

    @Test func recommendationsRespectLevelAndAdvanceOnlyAfterWholeStage() throws {
        let rows = try rows()
        #expect(GoalCurriculumSelection.recommendedStage(level: .beginner, rows: rows, completed: []) == 1)
        #expect(GoalCurriculumSelection.recommendedStage(level: .intermediate, rows: rows, completed: []) == 2)
        #expect(GoalCurriculumSelection.recommendedStage(level: .advanced, rows: rows, completed: []) == 3)
        #expect(GoalCurriculumSelection.recommendedStage(level: .advanced, rows: rows, completed: []) == 3)
        let nine = Set(rows.filter { $0.stage == 1 && $0.lessonOrder < 10 }.map(\.id))
        #expect(GoalCurriculumSelection.recommendedStage(level: .beginner, rows: rows, completed: nine) == 1)
        let ten = Set(rows.filter { $0.stage == 1 }.map(\.id))
        #expect(GoalCurriculumSelection.recommendedStage(level: .beginner, rows: rows, completed: ten) == 2)
    }

    @Test func roadmapContainsOnlyTheAdaptiveStageInSequence() throws {
        let rows = try rows(goal: .partner)
        let stage = GoalCurriculumSelection.recommendedStage(
            level: .advanced,
            rows: rows,
            completed: []
        )
        let roadmap = GoalCurriculumSelection.roadmap(stage: stage, rows: rows)

        #expect(stage == 3)
        #expect(roadmap.count == 10)
        #expect(roadmap.map(\.lessonOrder) == Array(1...10))
        #expect(Set(roadmap.map(\.id)) == Set(rows.filter { $0.stage == 3 }.map(\.id)))
    }

    @Test func rejectsWrongGoalAndIncompleteCatalog() throws {
        let rows = try rows()
        try GoalCurriculumSelection.validate(rows, goal: .family)
        #expect(throws: GoalCurriculumError.self) { try GoalCurriculumSelection.validate(rows, goal: .travel) }
        #expect(throws: GoalCurriculumError.self) { try GoalCurriculumSelection.validate(Array(rows.dropLast()), goal: .family) }
    }

    @Test func exercisesAndIdentifiersStayCorrectAcrossGoalsAndLevels() throws {
        var stepIDs = Set<UUID>()
        for goal in [LearningGoal.family, .lifeInThePhilippines, .partner, .travel] {
            for row in try rows(goal: goal) {
                let lesson = row.makeLesson().lesson
                #expect(lesson.steps.map(\.kind) == [.coldListen, .decode, .speak, .coldListen, .decode, .speak,
                    .coldListen, .hearRespond, .speak, .coldListen, .decode, .speak, .coldListen, .hearRespond, .speak])
                #expect(lesson.steps.map(\.id) == row.makeLesson().lesson.steps.map(\.id))
                for step in lesson.steps { #expect(stepIDs.insert(step.id).inserted) }
                #expect(lesson.steps.filter { $0.kind == .hearRespond }.allSatisfy { $0.hearRespond != nil })
            }
        }
    }
}

@Suite("Seeded learning repository")
struct LearningRepositoryTests {
    @Test("Sample content IDs are deterministic and come from the roadmap")
    func contentIDsAreDeterministic() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let firstVocabulary = SampleContent.vocabulary(referenceDate: referenceDate)
        let secondVocabulary = SampleContent.vocabulary(referenceDate: referenceDate)
        let firstLessons = SampleContent.lessonCatalog()
        let secondLessons = SampleContent.lessonCatalog()

        #expect(firstVocabulary.map(\.id) == secondVocabulary.map(\.id))
        #expect(firstLessons.map(\.id) == secondLessons.map(\.id))
        #expect(firstLessons.flatMap(\.steps).map(\.id) == secondLessons.flatMap(\.steps).map(\.id))
        #expect(firstLessons.first?.id.uuidString == "43010000-0000-4000-8100-000000000001")
    }

    @Test("Sample content is the bundled beginner roadmap")
    func sampleContentCoverage() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let items = SampleContent.vocabulary(referenceDate: referenceDate)
        let lessons = SampleContent.lessonCatalog()

        #expect(lessons.count == 10)
        #expect(Set(lessons.map(\.scenario)).count == 10)
        #expect(lessons.allSatisfy { $0.steps.count == 15 && $0.roundCount == 5 })
        #expect(items.count >= 40)
        #expect(Set(items.map { $0.tagalog.lowercased() }).count == items.count)
        #expect(items.allSatisfy { $0.nextReviewAt == referenceDate && (0...1).contains($0.mastery) })
    }

    @Test("Authored roadmaps promote through the sequential levels")
    func authoredRoadmapPromotionOrder() {
        #expect(ProficiencyLevel.beginner.nextRoadmapLevel == .intermediate)
        #expect(ProficiencyLevel.intermediate.nextRoadmapLevel == .advanced)
        #expect(ProficiencyLevel.advanced.nextRoadmapLevel == nil)
    }

    @Test("Every level has its own bundled roadmap")
    func everyLevelHasARoadmap() throws {
        var firstPhrases: Set<String> = []
        for level in ProficiencyLevel.allCases {
            let roadmap = try RoadmapCatalog.load(level: level)
            #expect(roadmap.count == 10)
            #expect(roadmap.map(\.lessonOrder) == Array(1...10))
            firstPhrases.insert(roadmap[0].lesson.steps[0].tagalog)
        }
        #expect(firstPhrases.count == ProficiencyLevel.allCases.count)
    }

    @Test("Every proficiency level has a distinct icon")
    func proficiencyLevelIconsAreDistinct() {
        let icons = ProficiencyLevel.allCases.map(\.systemImage)

        #expect(Set(icons).count == ProficiencyLevel.allCases.count)
    }

    @Test("Lessons honor every selected level")
    func lessonsHonorPreferences() async throws {
        let repository = SeededLearningRepository()
        var phrases: Set<String> = []

        for level in ProficiencyLevel.allCases {
            let lesson = try await repository.todayLesson(
                level: level,
                dailyMinutes: 5
            )

            #expect(lesson.minutes == 5)
            #expect(lesson.roundCount == 5)
            #expect(lesson.steps.count == 15)
            #expect(lesson.steps.allSatisfy { !$0.tagalog.isEmpty })
            #expect(lesson.steps[1].chunks.count >= 2)
            phrases.insert(lesson.steps[0].tagalog)
        }
        #expect(phrases.count == ProficiencyLevel.allCases.count)
    }

    @Test("Daily time creates a proportionate multi-round session")
    func dailyTimeControlsSessionLength() async throws {
        let repository = SeededLearningRepository()

        for minutes in [5, 7, 10, 15] {
            let lesson = try await repository.todayLesson(
                level: .intermediate,
                dailyMinutes: minutes
            )
            let expectedRounds = LessonSessionPlan.roundCount(for: minutes)

            #expect(lesson.minutes == minutes)
            #expect(lesson.roundCount == expectedRounds)
            #expect(lesson.steps.count == expectedRounds * 3)
            for roundStart in stride(from: 0, to: lesson.steps.count, by: 3) {
                // Rounds come from the authored roadmap in order, so each keeps
                // its own listening exercise (rounds 3 and 5 of every lesson).
                let middleKind = lesson.steps[roundStart + 1].kind
                #expect([.decode, .hearRespond].contains(middleKind))
                #expect(
                    Array(lesson.steps[roundStart ..< roundStart + 3]).map(\.kind)
                        == [.coldListen, middleKind, .speak]
                )
                if middleKind == .hearRespond {
                    #expect(lesson.steps[roundStart + 1].hearRespond?.options.count == 3)
                    #expect(
                        lesson.steps[roundStart + 1].hearRespond?.correctOption?.englishTranslation
                            == lesson.steps[roundStart + 1].translation
                    )
                }
            }
            #expect(Set(lesson.steps.filter { $0.kind == .coldListen }.map(\.tagalog)).count == expectedRounds)
            #expect(lesson.steps.allSatisfy { step in
                let tokens = step.tagalog
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                var cursor = 0
                for gloss in step.wordGlosses {
                    let glossTokens = gloss.token
                        .split(whereSeparator: \.isWhitespace)
                    guard (1 ... 2).contains(glossTokens.count),
                          cursor + glossTokens.count <= tokens.count
                    else { return false }
                    cursor += glossTokens.count
                }
                return cursor == tokens.count
            })
        }
    }

    @Test("Vocabulary is the roadmap's Tagalog")
    func vocabularyIsTagalog() async throws {
        let repository = SeededLearningRepository()
        let items = try await repository.vocabulary()
        #expect(!items.isEmpty)
        #expect(items.contains { $0.tagalog.lowercased().contains("kumusta") })
    }

    @Test("Save state is shared across repository consumers")
    func saveStateHasOneSourceOfTruth() async throws {
        let suiteName = "kumusta.tests.learning.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let repository = SeededLearningRepository(defaultsSuiteName: suiteName)
        let item = try #require(try await repository.vocabulary().first)

        try await repository.setVocabularySaved(itemID: item.id, isSaved: false)
        let afterWordsToggle = try await repository.vocabulary()
        #expect(afterWordsToggle.first(where: { $0.id == item.id })?.isSaved == false)

        try await repository.setVocabularySaved(itemID: item.id, isSaved: true)
        try await repository.recordReview(itemID: item.id, rating: .gotIt)
        let afterPracticeReview = try await repository.vocabulary()
        let updated = try #require(afterPracticeReview.first(where: { $0.id == item.id }))
        #expect(updated.isSaved)
        #expect(updated.mastery > item.mastery)
    }

    @Test("Four-day reviews survive repository recreation")
    func reviewSchedulePersistsAcrossRelaunch() async throws {
        let suiteName = "kumusta.tests.review-persistence.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let reviewedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let firstRepository = SeededLearningRepository(
            defaultsSuiteName: suiteName,
            referenceDate: reviewedAt
        )
        let original = try #require(
            try await firstRepository.vocabulary().first
        )

        try await firstRepository.recordReview(itemID: original.id, rating: .gotIt)
        let scheduled = try #require(
            try await firstRepository
                .vocabulary()
                .first(where: { $0.id == original.id })
        )

        let relaunchedRepository = SeededLearningRepository(
            defaultsSuiteName: suiteName,
            referenceDate: reviewedAt.addingTimeInterval(120)
        )
        let restored = try #require(
            try await relaunchedRepository
                .vocabulary()
                .first(where: { $0.id == original.id })
        )
        #expect(restored.mastery > original.mastery)
        #expect(restored.nextReviewAt == scheduled.nextReviewAt)
    }

    @Test("Reset removes persisted learner vocabulary state")
    func resetClearsPersistedState() async throws {
        let suiteName = "kumusta.tests.learning.reset.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = SeededLearningRepository(
            defaultsSuiteName: suiteName,
            referenceDate: referenceDate
        )
        let item = try #require(try await repository.vocabulary().first)

        try await repository.setVocabularySaved(itemID: item.id, isSaved: false)
        try await repository.recordReview(itemID: item.id, rating: .gotIt)
        await repository.reset()

        let resetItem = try #require(try await repository.vocabulary().first)
        let authoredItem = try #require(
            SampleContent.vocabulary(referenceDate: referenceDate).first
        )
        #expect(resetItem.mastery == authoredItem.mastery)
        #expect(resetItem.nextReviewAt == authoredItem.nextReviewAt)
        #expect(resetItem.isSaved == authoredItem.isSaved)
        #expect(UserDefaults(suiteName: suiteName)?.data(forKey: SeededLearningRepository.persistedStateKey) == nil)
    }

    @Test("Unknown vocabulary mutations fail explicitly")
    func unknownVocabularyFails() async {
        let repository = SeededLearningRepository()

        await #expect(throws: LearningRepositoryError.vocabularyNotFound) {
            try await repository.setVocabularySaved(itemID: UUID(), isSaved: true)
        }
    }

    @Test("Hear-and-match options can move the correct answer away from the first position")
    func hearRespondOptionsCanBeRandomized() throws {
        let correctID = UUID()
        let exercise = HearRespondExercise(
            promptTagalog: "Kumusta",
            promptTranslation: "Hello",
            options: [
                HearRespondOption(id: correctID, englishTranslation: "Hello"),
                HearRespondOption(id: UUID(), englishTranslation: "Goodbye"),
                HearRespondOption(id: UUID(), englishTranslation: "Thank you"),
            ],
            correctOptionID: correctID
        )
        var generator = SequenceRandomNumberGenerator(values: [0, UInt64.max])

        let randomized = exercise.randomizedOptions(using: &generator)

        #expect(randomized.count == exercise.options.count)
        #expect(Set(randomized.map { $0.id }) == Set(exercise.options.map { $0.id }))
        #expect(randomized.first?.id != correctID)
        #expect(randomized.first(where: { $0.id == exercise.correctOptionID })?.englishTranslation == "Hello")
    }
}

private struct SequenceRandomNumberGenerator: RandomNumberGenerator {
    let values: [UInt64]
    private var index = 0

    init(values: [UInt64]) {
        self.values = values
    }

    mutating func next() -> UInt64 {
        let value = values[min(index, values.count - 1)]
        index += 1
        return value
    }
}
