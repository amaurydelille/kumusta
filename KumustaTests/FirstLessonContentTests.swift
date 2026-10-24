import Foundation
import Testing
@testable import Kumusta

struct FirstLessonContentTests {
    private static let names: [String?] = [nil, "Linh"]

    private static func allScripts() throws -> [FirstLessonScript] {
        try FirstLessonCatalog.allFiles.flatMap { file in
            try names.map { try FirstLessonCatalog.load(file, learnerName: $0) }
        }
    }

    @Test("Every lesson file loads with only known steps")
    func everyLessonLoads() throws {
        let scripts = try Self.allScripts()
        #expect(scripts.count == FirstLessonCatalog.allFiles.count * 2)
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
            #expect(takes <= FirstLessonSpeechBudget.prePaywallLimit, "\(script.id)")
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
                            targets: [speak.target] + speak.accepted
                        ),
                        "\(script.id) \(speak.display)"
                    )
                case let .conversation(_, conversation):
                    for turn in conversation.turns {
                        #expect(
                            FirstLessonGrading.matches(
                                transcript: turn.replyDisplay,
                                targets: [turn.replyTarget] + turn.accepted
                            ),
                            "\(script.id) \(turn.replyDisplay)"
                        )
                    }
                default:
                    break
                }
            }
        }
    }

    @Test(
        "Every fixed line ships as a bundled clip",
        .disabled("Tagalog clips are not generated yet: run scripts/generate-first-lesson-audio.ts")
    )
    func fixedLinesAreBundled() throws {
        for script in try Self.allScripts() {
            let nameLine = "Ako si Linh."
            for text in script.audioTexts where text != nameLine {
                #expect(
                    FirstLessonScript.bundledAudioURL(for: text) != nil,
                    "\(script.id) missing clip for “\(text)”"
                )
            }
        }
    }

    @Test("The learner's name is shown and spoken, but never graded")
    func personalizesIntroduction() throws {
        let script = try FirstLessonCatalog.load(FirstLessonCatalog.fullLessonFile, learnerName: "Linh")
        let speak = try #require(script.steps.compactMap { step -> FirstLessonScript.Speak? in
            if case let .speak(_, speak) = step, speak.display.contains("Linh") { return speak }
            return nil
        }.first)
        #expect(speak.display == "Ako si Linh.")
        #expect(speak.target == "Ako si")
        #expect(speak.spokenText == "Ako si Linh.")
    }

    @Test("A missing name falls back to a placeholder and a tip")
    func placeholderName() throws {
        let script = try FirstLessonCatalog.load(FirstLessonCatalog.fullLessonFile, learnerName: nil)
        let speak = try #require(script.steps.compactMap { step -> FirstLessonScript.Speak? in
            if case let .speak(_, speak) = step, speak.display.hasPrefix("Ako si") { return speak }
            return nil
        }.first)
        #expect(speak.display == "Ako si …")
        #expect(speak.translation.contains("…"))
        #expect(speak.spokenText == "Ako si")
    }

    @Test("Grading accepts everyday spelling variants of the target")
    func gradingAcceptsVariants() {
        #expect(FirstLessonGrading.matches(transcript: "kamusta po", targets: ["Kumusta po"]))
        #expect(FirstLessonGrading.matches(transcript: "pwede po", targets: ["Puwede po"]))
        #expect(!FirstLessonGrading.matches(transcript: "paalam po", targets: ["Kumusta po"]))
    }

    @Test("Audio keys are FNV-1a over normalized text, matching the generator")
    func audioKeys() {
        #expect(FirstLessonScript.audioKey(for: "") == "cbf29ce484222325")
        #expect(FirstLessonScript.audioKey(for: "a") == "af63dc4c8601ec8c")
        #expect(FirstLessonScript.audioKey(for: "  Kumusta   po! ") == FirstLessonScript.audioKey(for: "Kumusta po!"))
        // Decomposed and precomposed text share one clip.
        #expect(FirstLessonScript.audioKey(for: "Niño".decomposedStringWithCanonicalMapping) == FirstLessonScript.audioKey(for: "Niño"))
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
