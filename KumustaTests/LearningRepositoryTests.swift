import Foundation
import Testing
@testable import Kumusta

@Suite("Goal curriculum")
struct GoalCurriculumTests {
    private func rows(goal: LearningGoal = .family, accent: VietnameseAccent = .southern) throws -> [GoalCurriculumRow] {
        let rounds: [[String: Any]] = (0..<5).map { index in
            var round: [String: Any] = [
                "situation": "You greet an older relative.", "vietnamese": "Con chào cô ạ.",
                "translation": "Hello, auntie.", "speakingPrompt": "Greet your aunt.",
                "chunks": [["vietnamese": "Con", "english": "I", "note": "Younger speaker"],
                           ["vietnamese": "chào cô ạ.", "english": "greet auntie", "note": "Polite greeting"]],
                "wordGlosses": [["token": "Con", "english": "I"], ["token": "chào", "english": "greet"],
                                ["token": "cô", "english": "auntie"], ["token": "ạ.", "english": "polite particle"]],
            ]
            if [2, 4].contains(index) {
                round["responseExercise"] = ["promptVietnamese": "Con chào cô ạ.",
                    "promptTranslation": "Hello, auntie.", "correctOptionIndex": 1,
                    "options": [["englishTranslation": "Goodbye."], ["englishTranslation": "Hello, auntie."],
                                ["englishTranslation": "Thank you."]]]
            }
            return round
        }
        let objects: [[String: Any]] = (1...4).flatMap { stage in
            (1...10).map { order in
                ["id": UUID().uuidString, "goal": goal.rawValue, "stage": stage,
                 "accent": accent.rawValue, "lesson_order": order, "title": "Visit \(order)",
                 "summary": "Greet your family", "content": ["title": "Visit \(order)", "minutes": 5, "rounds": rounds]]
            }
        }
        return try JSONDecoder().decode([GoalCurriculumRow].self, from: JSONSerialization.data(withJSONObject: objects))
    }

    @Test func recommendationsRespectLevelAndAdvanceOnlyAfterWholeStage() throws {
        let rows = try rows()
        #expect(GoalCurriculumSelection.recommendedStage(level: .new, rows: rows, completed: []) == 1)
        #expect(GoalCurriculumSelection.recommendedStage(level: .familiar, rows: rows, completed: []) == 2)
        #expect(GoalCurriculumSelection.recommendedStage(level: .conversational, rows: rows, completed: []) == 3)
        #expect(GoalCurriculumSelection.recommendedStage(level: .rusty, rows: rows, completed: []) == 3)
        let nine = Set(rows.filter { $0.stage == 1 && $0.lessonOrder < 10 }.map(\.id))
        #expect(GoalCurriculumSelection.recommendedStage(level: .new, rows: rows, completed: nine) == 1)
        let ten = Set(rows.filter { $0.stage == 1 }.map(\.id))
        #expect(GoalCurriculumSelection.recommendedStage(level: .new, rows: rows, completed: ten) == 2)
    }

    @Test func roadmapContainsOnlyTheAdaptiveStageInSequence() throws {
        let rows = try rows(goal: .partner, accent: .northern)
        let stage = GoalCurriculumSelection.recommendedStage(
            level: .conversational,
            rows: rows,
            completed: []
        )
        let roadmap = GoalCurriculumSelection.roadmap(stage: stage, rows: rows)

        #expect(stage == 3)
        #expect(roadmap.count == 10)
        #expect(roadmap.map(\.lessonOrder) == Array(1...10))
        #expect(Set(roadmap.map(\.id)) == Set(rows.filter { $0.stage == 3 }.map(\.id)))
    }

    @Test func rejectsWrongGoalAccentAndIncompleteCatalog() throws {
        let rows = try rows()
        try GoalCurriculumSelection.validate(rows, goal: .family, accent: .southern)
        #expect(throws: GoalCurriculumError.self) { try GoalCurriculumSelection.validate(rows, goal: .travel, accent: .southern) }
        #expect(throws: GoalCurriculumError.self) { try GoalCurriculumSelection.validate(rows, goal: .family, accent: .northern) }
        #expect(throws: GoalCurriculumError.self) { try GoalCurriculumSelection.validate(Array(rows.dropLast()), goal: .family, accent: .southern) }
    }

    @Test func exercisesAndIdentifiersStayCorrectAcrossGoalsAndLevels() throws {
        var stepIDs = Set<UUID>()
        for goal in [LearningGoal.family, .lifeInVietnam, .partner, .travel] {
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
    @Test("Authored content IDs are deterministic and stable")
    func contentIDsAreDeterministic() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        for accent in VietnameseAccent.allCases {
            let firstVocabulary = SampleContent.vocabulary(
                for: accent,
                referenceDate: referenceDate
            )
            let secondVocabulary = SampleContent.vocabulary(
                for: accent,
                referenceDate: referenceDate
            )
            let firstLessons = SampleContent.lessonCatalog(for: accent)
            let secondLessons = SampleContent.lessonCatalog(for: accent)

            #expect(firstVocabulary.map(\.id) == secondVocabulary.map(\.id))
            #expect(firstLessons.map(\.id) == secondLessons.map(\.id))
            #expect(firstLessons.flatMap(\.steps).map(\.id) == secondLessons.flatMap(\.steps).map(\.id))
        }

        let southernFirst = try #require(
            SampleContent.vocabulary(for: .southern, referenceDate: referenceDate).first
        )
        let northernFirst = try #require(
            SampleContent.vocabulary(for: .northern, referenceDate: referenceDate).first
        )

        #expect(southernFirst.id.uuidString == "30000000-0000-0000-0000-000000300001")
        #expect(northernFirst.id.uuidString == "30000000-0000-0000-0000-000000310001")
        #expect(
            SampleContent.lessonCatalog(for: .southern).first?.id.uuidString
                == "20000000-0000-0000-0000-000000000101"
        )
    }

    @Test("Accent catalogs remain separate")
    func accentCatalogsRemainSeparate() {
        let southernVocabulary = SampleContent.vocabulary(for: .southern)
        let northernVocabulary = SampleContent.vocabulary(for: .northern)
        let southernLessons = SampleContent.lessonCatalog(for: .southern)
        let northernLessons = SampleContent.lessonCatalog(for: .northern)

        #expect(Set(southernVocabulary.map(\.id)).isDisjoint(with: Set(northernVocabulary.map(\.id))))
        #expect(Set(southernLessons.map(\.id)).isDisjoint(with: Set(northernLessons.map(\.id))))
        #expect(southernVocabulary.allSatisfy { $0.accent == .southern })
        #expect(northernVocabulary.allSatisfy { $0.accent == .northern })
        #expect(southernLessons.allSatisfy { $0.accent == .southern })
        #expect(northernLessons.allSatisfy { $0.accent == .northern })

        let southernText = southernVocabulary
            .flatMap { [$0.vietnamese, $0.example] }
            .joined(separator: " ")
        let northernText = northernVocabulary
            .flatMap { [$0.vietnamese, $0.example] }
            .joined(separator: " ")
        #expect(southernText.contains("quẹo trái"))
        #expect(southernText.contains("giùm"))
        #expect(!southernText.contains("rẽ trái"))
        #expect(northernText.contains("rẽ trái"))
        #expect(northernText.contains("giúp"))
        #expect(!northernText.contains("quẹo trái"))
    }

    @Test("Phrase bank has useful scenario breadth and review distribution")
    func phraseBankCoverageAndDistribution() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let expectedLessonCount = 12

        for accent in VietnameseAccent.allCases {
            let items = SampleContent.vocabulary(for: accent, referenceDate: referenceDate)
            let lessons = SampleContent.lessonCatalog(for: accent)

            #expect(items.count == 18)
            #expect(lessons.count == expectedLessonCount)
            #expect(Set(lessons.map(\.scenario)).count == expectedLessonCount)
            #expect(lessons.allSatisfy { lesson in
                lesson.steps.map(\.kind) == [.coldListen, .decode, .speak]
                    && lesson.steps[1].chunks.count >= 3
            })
            #expect(items.filter { $0.nextReviewAt <= referenceDate }.count >= 5)
            #expect(items.filter { $0.nextReviewAt > referenceDate }.count >= 10)
            #expect(Set(items.map(\.mastery)).count >= 12)
            #expect(items.allSatisfy { (0...1).contains($0.mastery) })
        }
    }

    @Test("Bundled curriculum parses with complete accent coverage")
    func bundledCurriculumParses() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceURL = projectRoot
            .appendingPathComponent("Kumusta/Resources/Seed/curriculum-v1.json")
        let data = try Data(contentsOf: resourceURL)
        let document = try JSONDecoder().decode(CurriculumSeedDocument.self, from: data)

        #expect(document.version == 1)
        #expect(document.reviewStatus == "native-speaker-review-required")
        #expect(document.lessons.count == 12)

        for accent in VietnameseAccent.allCases {
            let lessons = document.lessons.filter { $0.accent == accent }
            #expect(lessons.count == 6)
            #expect(lessons.allSatisfy { $0.steps.map(\.kind) == [.coldListen, .decode, .speak] })
        }

        let lessonIDs = document.lessons.map(\.id)
        let stepIDs = document.lessons.flatMap(\.steps).map(\.id)
        let chunkIDs = document.lessons
            .flatMap(\.steps)
            .flatMap(\.chunks)
            .map(\.id)
        #expect(Set(lessonIDs).count == lessonIDs.count)
        #expect(Set(stepIDs).count == stepIDs.count)
        #expect(Set(chunkIDs).count == chunkIDs.count)
    }

    @Test("Authored roadmaps promote through the sequential levels")
    func authoredRoadmapPromotionOrder() {
        #expect(ProficiencyLevel.new.nextRoadmapLevel == .familiar)
        #expect(ProficiencyLevel.familiar.nextRoadmapLevel == .conversational)
        #expect(ProficiencyLevel.conversational.nextRoadmapLevel == nil)
        #expect(ProficiencyLevel.rusty.nextRoadmapLevel == nil)
    }

    @Test("Every proficiency level has a distinct icon")
    func proficiencyLevelIconsAreDistinct() {
        let icons = ProficiencyLevel.allCases.map(\.systemImage)

        #expect(Set(icons).count == ProficiencyLevel.allCases.count)
    }

    @Test("Lessons honor every selected accent and level")
    func lessonsHonorPreferences() async throws {
        let repository = SeededLearningRepository()

        for accent in VietnameseAccent.allCases {
            var phrases: Set<String> = []

            for level in ProficiencyLevel.allCases {
                let lesson = try await repository.todayLesson(
                    accent: accent,
                    level: level,
                    dailyMinutes: 5
                )

                #expect(lesson.accent == accent)
                #expect(lesson.minutes == 5)
                #expect(lesson.roundCount == 5)
                #expect(lesson.steps.count == 15)
                #expect(lesson.steps.allSatisfy { !$0.vietnamese.isEmpty })
                #expect(lesson.steps[1].chunks.count >= 4)
                phrases.insert(lesson.steps[0].vietnamese)
            }

            #expect(phrases.count == ProficiencyLevel.allCases.count)
        }
    }

    @Test("Daily time creates a proportionate multi-round session")
    func dailyTimeControlsSessionLength() async throws {
        let repository = SeededLearningRepository()

        for minutes in [5, 7, 10, 15] {
            let lesson = try await repository.todayLesson(
                accent: .southern,
                level: .familiar,
                dailyMinutes: minutes
            )
            let expectedRounds = LessonSessionPlan.roundCount(for: minutes)

            #expect(lesson.minutes == minutes)
            #expect(lesson.roundCount == expectedRounds)
            #expect(lesson.steps.count == expectedRounds * 3)
            #expect(LessonSessionPlan.hearRespondRoundIndexes(for: expectedRounds).count == 2)
            for roundStart in stride(from: 0, to: lesson.steps.count, by: 3) {
                let roundIndex = roundStart / LessonSessionPlan.stagesPerRound
                let middleKind: LessonStepKind = LessonSessionPlan
                    .hearRespondRoundIndexes(for: expectedRounds)
                    .contains(roundIndex) ? .hearRespond : .decode
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
            #expect(Set(lesson.steps.filter { $0.kind == .coldListen }.map(\.vietnamese)).count == expectedRounds)
            #expect(lesson.steps.allSatisfy { step in
                let tokens = step.vietnamese
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

    @Test("Northern and Southern lessons use region-appropriate softeners")
    func lessonCopyMatchesAccent() async throws {
        let repository = SeededLearningRepository()
        let southern = try await repository.todayLesson(
            accent: .southern,
            level: .familiar,
            dailyMinutes: 5
        )
        let northern = try await repository.todayLesson(
            accent: .northern,
            level: .familiar,
            dailyMinutes: 5
        )

        #expect(southern.steps[0].vietnamese.contains("nha"))
        #expect(southern.steps[0].vietnamese.contains("ly"))
        #expect(northern.steps[0].vietnamese.contains("nhé"))
        #expect(northern.steps[0].vietnamese.contains("cốc"))
    }

    @Test("Vocabulary results never leak the other accent")
    func vocabularyMatchesAccent() async throws {
        let repository = SeededLearningRepository()

        for accent in VietnameseAccent.allCases {
            let items = try await repository.vocabulary(accent: accent)
            #expect(!items.isEmpty)
            #expect(items.allSatisfy { $0.accent == accent })
        }
    }

    @Test("Save state is shared across repository consumers")
    func saveStateHasOneSourceOfTruth() async throws {
        let suiteName = "kumusta.tests.learning.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let repository = SeededLearningRepository(defaultsSuiteName: suiteName)
        let item = try #require(try await repository.vocabulary(accent: .southern).first)

        try await repository.setVocabularySaved(itemID: item.id, isSaved: false)
        let afterWordsToggle = try await repository.vocabulary(accent: .southern)
        #expect(afterWordsToggle.first(where: { $0.id == item.id })?.isSaved == false)

        try await repository.setVocabularySaved(itemID: item.id, isSaved: true)
        try await repository.recordReview(itemID: item.id, rating: .gotIt)
        let afterPracticeReview = try await repository.vocabulary(accent: .southern)
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
            try await firstRepository.vocabulary(accent: .southern).first
        )

        try await firstRepository.recordReview(itemID: original.id, rating: .gotIt)
        let scheduled = try #require(
            try await firstRepository
                .vocabulary(accent: .southern)
                .first(where: { $0.id == original.id })
        )

        let relaunchedRepository = SeededLearningRepository(
            defaultsSuiteName: suiteName,
            referenceDate: reviewedAt.addingTimeInterval(120)
        )
        let restored = try #require(
            try await relaunchedRepository
                .vocabulary(accent: .southern)
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
        let item = try #require(try await repository.vocabulary(accent: .southern).first)

        try await repository.setVocabularySaved(itemID: item.id, isSaved: false)
        try await repository.recordReview(itemID: item.id, rating: .gotIt)
        await repository.reset()

        let resetItem = try #require(try await repository.vocabulary(accent: .southern).first)
        let authoredItem = try #require(
            SampleContent.vocabulary(for: .southern, referenceDate: referenceDate).first
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
            promptVietnamese: "Xin chào",
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

private struct CurriculumSeedDocument: Decodable {
    let version: Int
    let reviewStatus: String
    let lessons: [Lesson]
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
