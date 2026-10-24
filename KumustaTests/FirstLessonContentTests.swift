import Foundation
import Testing
@testable import Kumusta

struct FirstLessonContentTests {
    private static let names: [String?] = [nil, "Linh"]

    private static func allScripts() throws -> [FirstLessonScript] {
        try FirstLessonCatalog.allFiles.flatMap { file in
            try VietnameseAccent.allCases.flatMap { accent in
                try names.map { try FirstLessonCatalog.load(file, accent: accent, learnerName: $0) }
            }
        }
    }

    @Test("Every lesson file loads for both accents with only known steps")
    func everyLessonLoads() throws {
        let scripts = try Self.allScripts()
        #expect(scripts.count == FirstLessonCatalog.allFiles.count * 4)
        for script in scripts {
            #expect(script.steps.first == .intro)
            #expect(!script.intro.goals.isEmpty)
            #expect(!script.completion.phrases.isEmpty)
            for step in script.steps {
                if case let .teach(_, teach) = step {
                    #expect(!teach.title.hasPrefix("Unsupported"), "\(script.id) \(step.id)")
                }
            }
        }
    }

    @Test("Each level has an onboarding lesson and every lesson keeps its level")
    func levelsAreCovered() throws {
        for level in ProficiencyLevel.allCases {
            let script = try FirstLessonCatalog.load(
                FirstLessonCatalog.onboardingFile(for: level),
                accent: .southern,
                learnerName: nil
            )
            #expect(script.level == level)
            #expect(script.mode == .onboarding)
        }
    }

    @Test("Every graded question offers its answer exactly once")
    func answersAreOffered() throws {
        for script in try Self.allScripts() {
            for step in script.steps {
                switch step {
                case let .listenPick(_, pick):
                    #expect(pick.options.filter { $0.text == pick.answer }.count == 1, "\(script.id) \(step.id)")
                case let .meaningPick(_, pick):
                    #expect(pick.options.filter { $0 == pick.answer }.count == 1, "\(script.id) \(step.id)")
                    #expect(Set(pick.options).count == pick.options.count)
                case let .naturalPick(_, pick):
                    #expect(pick.options.filter(\.isBest).count == 1, "\(script.id) \(step.id)")
                case let .build(_, build):
                    let answer = Set(build.answer.map { $0.text.lowercased() })
                    #expect(build.distractors.allSatisfy { !answer.contains($0.text.lowercased()) })
                default:
                    break
                }
            }
        }
    }

    @Test("Step IDs are unique so retries and analytics stay distinct")
    func uniqueStepIDs() throws {
        for script in try Self.allScripts() {
            let ids = script.steps.map(\.id)
            #expect(Set(ids).count == ids.count, "\(script.id)")
        }
    }

    @Test("Onboarding lessons fit the pre-paywall allowance of three checked takes")
    func onboardingFitsSpeechAllowance() throws {
        for script in try Self.allScripts() where script.mode == .onboarding {
            let takes = script.steps.map(\.recordingCount).reduce(0, +)
            #expect(takes <= FirstLessonSpeechBudget.prePaywallLimit, "\(script.id) \(script.accent)")
        }
    }

    @Test("Saying the displayed line counts as correct for every speaking prompt")
    func speakingTargetsGradeCleanly() throws {
        for script in try Self.allScripts() {
            for step in script.steps {
                switch step {
                case let .speak(_, speak):
                    #expect(
                        FirstLessonGrading.matches(
                            transcript: speak.display,
                            targets: [speak.target] + speak.accepted,
                            accent: script.accent
                        ),
                        "\(script.id) \(script.accent) \(speak.display)"
                    )
                case let .conversation(_, conversation):
                    for turn in conversation.turns {
                        #expect(
                            FirstLessonGrading.matches(
                                transcript: turn.replyDisplay,
                                targets: [turn.replyTarget] + turn.accepted,
                                accent: script.accent
                            ),
                            "\(script.id) \(script.accent) \(turn.replyDisplay)"
                        )
                    }
                default:
                    break
                }
            }
        }
    }

    @Test("Every fixed line ships as a bundled clip for its accent")
    func fixedLinesAreBundled() throws {
        for script in try Self.allScripts() {
            let nameLine = "Mình tên là Linh."
            for text in script.audioTexts where text != nameLine {
                #expect(
                    FirstLessonScript.bundledAudioURL(for: text, accent: script.accent) != nil,
                    "\(script.id) \(script.accent) missing clip for “\(text)”"
                )
            }
        }
    }

    @Test("The learner's name is shown and spoken, but never graded")
    func personalizesIntroduction() throws {
        let script = try FirstLessonCatalog.load(FirstLessonCatalog.fullLessonFile, accent: .southern, learnerName: "Linh")
        let speak = try #require(script.steps.compactMap { step -> FirstLessonScript.Speak? in
            if case let .speak(id, speak) = step, id == "speak-ten-la" { return speak }
            return nil
        }.first)
        #expect(speak.display == "Mình tên là Linh.")
        #expect(speak.target == "Mình tên là")
        #expect(speak.spokenText == "Mình tên là Linh.")
        #expect(speak.tip == nil)
    }

    @Test("A missing name falls back to a placeholder and a tip")
    func placeholderName() throws {
        let script = try FirstLessonCatalog.load(FirstLessonCatalog.fullLessonFile, accent: .northern, learnerName: nil)
        let speak = try #require(script.steps.compactMap { step -> FirstLessonScript.Speak? in
            if case let .speak(id, speak) = step, id == "speak-ten-la" { return speak }
            return nil
        }.first)
        #expect(speak.display == "Mình tên là …")
        #expect(speak.translation == "My name is …")
        #expect(speak.spokenText == "Mình tên là")
        #expect(speak.tip != nil)
    }

    @Test("Accent variants resolve to their own wording")
    func accentVariants() throws {
        let south = try FirstLessonCatalog.load("onboarding-familiar", accent: .southern, learnerName: nil)
        let north = try FirstLessonCatalog.load("onboarding-familiar", accent: .northern, learnerName: nil)
        #expect(south.intro.goals[0].vietnamese == "Cho em một ly cà phê sữa đá")
        #expect(north.intro.goals[0].vietnamese == "Cho em một cốc nâu đá")
    }

    @Test("Southern grading treats hỏi and ngã as the same tone")
    func southernMergesHoiNga() {
        // Two-word phrases: no single-slip allowance, so only the accent rule applies.
        #expect(FirstLessonGrading.matches(transcript: "khoẻ không", targets: ["khoẽ không"], accent: .southern))
        #expect(!FirstLessonGrading.matches(transcript: "khoẻ không", targets: ["khoẽ không"], accent: .northern))
        #expect(!FirstLessonGrading.matches(transcript: "khoè không", targets: ["khoẻ không"], accent: .southern))
    }

    @Test("Audio keys are FNV-1a over normalized text, matching the generator")
    func audioKeys() {
        #expect(FirstLessonScript.audioKey(for: "") == "cbf29ce484222325")
        #expect(FirstLessonScript.audioKey(for: "a") == "af63dc4c8601ec8c")
        #expect(FirstLessonScript.audioKey(for: "  Xin   chào! ") == FirstLessonScript.audioKey(for: "Xin chào!"))
        // Decomposed and precomposed Vietnamese share one clip.
        #expect(FirstLessonScript.audioKey(for: "chào".decomposedStringWithCanonicalMapping) == FirstLessonScript.audioKey(for: "chào"))
    }

    @MainActor
    @Test("Completing the lesson persists and survives a reload")
    func storeCompletion() throws {
        let suite = "first-lesson-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = FirstStepsCourseStore(defaults: defaults)
        #expect(store.shouldOffer)
        store.start()
        #expect(store.status == .inProgress)
        store.complete()

        let reloaded = FirstStepsCourseStore(defaults: defaults)
        #expect(reloaded.status == .completed)
        #expect(!reloaded.shouldOffer)
        #expect(reloaded.completedActivityIDs.contains(FirstStepsCourseStore.courseID))
        #expect(reloaded.hasCompletedLesson)
    }

    @MainActor
    @Test("Finishing the old cheat sheet does not count as finishing the lesson")
    func legacyCompletionStillOffersLesson() throws {
        let suite = "first-lesson-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = FirstStepsCourseStore(defaults: defaults)
        store.replace(with: FirstStepsCourseSnapshot(status: .completed, offerSeen: true, completedActivityIDs: []))
        #expect(!store.hasCompletedLesson)
        #expect(store.lessonStatus == .notStarted)
    }

    @Test("Every lesson analytics payload passes the Supabase property allowlist")
    func analyticsPayloadsAreAccepted() throws {
        for script in try Self.allScripts() {
            for isPrePaywall in [true, false] {
                let base = FirstLessonAnalytics.base(script: script, isPrePaywall: isPrePaywall)
                // The extra keys the lesson adds to feature events.
                let extras: [String: String] = [
                    "step": "answered", "step_id": "x", "step_kind": "teach", "step_index": "3",
                    "is_correct": "true", "score": "100", "active_seconds": "42",
                    "attempt": "2", "value": "1"
                ]
                try SupabaseSignedInRepository.validateAnalyticsProperties(
                    base.merging(extras, uniquingKeysWith: { _, new in new })
                )
            }
            let screens = script.steps.map { FirstLessonAnalytics.screen(for: $0, in: script, isReplay: false) }
                + [FirstLessonAnalytics.completionScreen(in: script)]
            for screen in screens {
                let funnel = FirstLessonAnalytics.funnel(screen, script: script)
                try SupabaseSignedInRepository.validateAnalyticsProperties(
                    funnel.merging(["active_seconds": "12"], uniquingKeysWith: { _, new in new })
                )
            }
        }
    }

    @Test("Onboarding lesson screens follow the onboarding funnel in order")
    func onboardingFunnelPositions() throws {
        for level in ProficiencyLevel.allCases {
            let script = try FirstLessonCatalog.load(
                FirstLessonCatalog.onboardingFile(for: level),
                accent: .northern,
                learnerName: "Linh"
            )
            let screens = script.steps.map { FirstLessonAnalytics.screen(for: $0, in: script, isReplay: false) }
                + [FirstLessonAnalytics.completionScreen(in: script)]
            let positions = screens.compactMap { Int(FirstLessonAnalytics.funnel($0, script: script)["position"] ?? "") }
            // Directly after the `first_lesson` container step (position 7).
            #expect(positions.first == FirstLessonAnalytics.firstScreenPosition)
            #expect(positions == Array(positions.first!..<(positions.first! + positions.count)))
            #expect(FirstLessonAnalytics.funnel(screens[0], script: script)["step"] == "first_lesson_intro")
            #expect(FirstLessonAnalytics.funnel(screens.last!, script: script)["step"] == "first_lesson_completion")
        }
    }

    @MainActor
    @Test("The speech budget stops grading after the allowance")
    func speechBudget() {
        let budget = FirstLessonSpeechBudget(limit: 2)
        #expect(budget.canGrade)
        budget.spend()
        budget.spend()
        #expect(!budget.canGrade)
        let unlimited = FirstLessonSpeechBudget(limit: nil)
        unlimited.spend()
        #expect(unlimited.canGrade)
    }
}
