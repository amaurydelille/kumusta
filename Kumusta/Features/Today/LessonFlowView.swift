import OSLog
import SwiftUI

enum LessonEducation {
    static let formatSeenKey = "kumusta.education.hasSeenLessonFormat"
}

struct LessonTelemetryContext: Sendable {
    let contentKind: RemoteLearningContentKind
    let entryPoint: String
    let isReplay: Bool

    static let unknown = LessonTelemetryContext(
        contentKind: .unknown,
        entryPoint: "unknown",
        isReplay: false
    )
}

struct LessonFlowView: View {
    let lesson: Lesson
    let telemetryContext: LessonTelemetryContext
    let onComplete: (SessionFeedback) -> Void
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stepIndex = 0
    @State private var didRecordCompletion = false
    @State private var isShowingReminderInvitation = false
    @State private var didTrackTikTokStart = false
    @State private var telemetrySessionID = UUID()
    @State private var telemetryStartedAt = Date.now
    @State private var didStartTelemetry = false
    @State private var didFinalizeTelemetry = false
    @State private var revealedListenStepIDs: Set<UUID> = []
    /// XP the server granted for finishing; 0 when none (signed out, replayed
    /// award, or a failed request), nil while the award is still pending.
    @State private var awardedLessonXP: Int?
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeedRawValue = AudioPreferences.fallbackSpeed.rawValue
    private let minimumInitialStepIndex: Int

    init(
        lesson: Lesson,
        initialStepIndex: Int = 0,
        telemetryContext: LessonTelemetryContext = .unknown,
        onComplete: @escaping (SessionFeedback) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.lesson = lesson
        self.telemetryContext = telemetryContext
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        let boundedInitialStepIndex = max(0, min(initialStepIndex, lesson.steps.count))
        minimumInitialStepIndex = boundedInitialStepIndex
        _stepIndex = State(initialValue: boundedInitialStepIndex)
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                if stepIndex < lesson.steps.count {
                    lessonHeader
                }

                Group {
                    if isShowingReminderInvitation {
                        LessonReminderInvitation {
                            isShowingReminderInvitation = false
                            appState.scheduleCloudStateSync()
                            onDismiss()
                        }
                    } else if stepIndex < lesson.steps.count {
                        stepContent(for: lesson.steps[stepIndex])
                            .id(stepIndex)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    )
                            )
                    } else {
                        LessonCompleteView(
                            roundCount: lesson.roundCount,
                            minutes: lesson.minutes,
                            chunkCount: lesson.decodedChunkCount,
                            awardedXP: awardedLessonXP
                        ) { feedback in
                            apply(feedback)
                        }
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.96).combined(with: .opacity)
                            )
                    }
                }
                .animation(reduceMotion ? nil : KumustaMotion.screen, value: stepIndex)
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            let resumedIndex = dependencies.lessonProgressStore.resumeStepIndex(
                for: lesson,
                minimum: minimumInitialStepIndex
            )
            if resumedIndex > 0,
               resumedIndex < lesson.steps.count,
               lesson.steps[resumedIndex].kind == .decode,
               lesson.steps[resumedIndex - 1].kind == .coldListen {
                revealedListenStepIDs.insert(lesson.steps[resumedIndex - 1].id)
                stepIndex = resumedIndex - 1
            } else {
                stepIndex = resumedIndex
            }
            if !didTrackTikTokStart {
                didTrackTikTokStart = true
                TikTokAppEvents.trackLessonStarted(lesson: lesson)
                AppsFlyerAppEvents.trackLessonStarted(lesson: lesson)
                MetaAppEvents.trackLessonStarted(lesson: lesson)
            }
            if !didStartTelemetry {
                didStartTelemetry = true
                dependencies.analytics.track(
                    .lessonOpened,
                    properties: baseTelemetryProperties.merging([
                        "screen_name": "lesson",
                        "step_count": String(lesson.steps.count)
                    ], uniquingKeysWith: { current, _ in current }),
                    clientSessionID: telemetrySessionID
                )
                dependencies.analytics.track(
                    .lessonStarted,
                    properties: baseTelemetryProperties.merging([
                        "screen_name": "lesson",
                        "round_count": String(lesson.roundCount)
                    ], uniquingKeysWith: { current, _ in current }),
                    clientSessionID: telemetrySessionID
                )
                if stepIndex < lesson.steps.count {
                    dependencies.analytics.track(
                        .lessonStepViewed,
                        properties: stepTelemetryProperties(index: stepIndex),
                        clientSessionID: telemetrySessionID
                    )
                }
                Task { await syncLessonSession(completed: false, endedAt: nil) }
            }
            let audioService = dependencies.audioService
            let speed = AudioPreferences.speed(from: defaultSpeedRawValue)
            Task {
                await audioService.prewarm(lesson: lesson, speed: speed)
            }
        }
        .onDisappear {
            Task { await dependencies.audioService.stop() }
            guard didStartTelemetry, !didFinalizeTelemetry else { return }
            dependencies.analytics.track(
                .lessonAbandoned,
                properties: baseTelemetryProperties.merging([
                    "screen_name": "lesson",
                    "step_index": String(stepIndex)
                ], uniquingKeysWith: { current, _ in current }),
                clientSessionID: telemetrySessionID
            )
            Task { await syncLessonSession(completed: false, endedAt: .now) }
        }
        .onChange(of: stepIndex) { _, newValue in
            guard newValue < lesson.steps.count else { return }
            dependencies.analytics.track(
                .lessonStepViewed,
                properties: stepTelemetryProperties(index: newValue),
                clientSessionID: telemetrySessionID
            )
        }
    }

    private var lessonHeader: some View {
        HStack(spacing: 10) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .scaledFont(19, weight: .bold)
                    .foregroundStyle(KumustaColors.muted)
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel(L("Close lesson"))

            if canGoBack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .scaledFont(18, weight: .bold)
                        .foregroundStyle(KumustaColors.muted)
                        .frame(width: 32, height: 44)
                }
                .accessibilityLabel(L("Previous step"))
                .accessibilityHint(L("Go back to the previous lesson step"))
                .transition(.opacity)
            }

            GeometryReader { proxy in
                let fraction = CGFloat(progressStepCount) / CGFloat(max(1, lesson.steps.count))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(KumustaColors.surfaceStrong)
                    Capsule()
                        .fill(KumustaColors.caution)
                        .frame(width: max(16, proxy.size.width * fraction))
                        .overlay(alignment: .top) {
                            // Glossy highlight, the "candy" look of big learning apps.
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)
                                .padding(.horizontal, 8)
                                .padding(.top, 3)
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progressStepCount)
                }
            }
            .frame(height: 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Lesson progress"))
            .accessibilityValue(
                stepIndex < lesson.steps.count
                    ? L("Round %lld of %lld, %@", currentRoundNumber, lesson.roundCount, currentStageTitle)
                    : L("Complete")
            )

            Text(stepIndex < lesson.steps.count ? "\(currentRoundNumber)/\(lesson.roundCount)" : "✓")
                .scaledFont(15, weight: .heavy, design: .rounded)
                .foregroundStyle(KumustaColors.cautionDeep)
                .monospacedDigit()
                .accessibilityHidden(true)
        }
        .animation(.easeOut(duration: 0.2), value: canGoBack)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .screenContentWidth()
    }

    /// Language of this lesson's support text, recorded with saved words.
    private var contentLanguage: AppLanguage? {
        lesson.sourceScenario == nil ? nil : AppLocalization.language
    }

    @ViewBuilder
    private func stepContent(for step: LessonStep) -> some View {
        switch step.kind {
        case .coldListen:
            ColdListenStep(
                step: step,
                lessonID: lesson.id,
                translationLanguage: contentLanguage,
                lessonMinutes: lesson.minutes,
                roundCount: lesson.roundCount,
                analyticsProperties: stepTelemetryProperties(index: stepIndex),
                telemetrySessionID: telemetrySessionID,
                isRevealed: Binding(
                    get: { revealedListenStepIDs.contains(step.id) },
                    set: { revealed in
                        if revealed {
                            revealedListenStepIDs.insert(step.id)
                        } else {
                            revealedListenStepIDs.remove(step.id)
                        }
                    }
                ),
                onContinue: advanceFromListen
            )
        case .decode:
            DecodeStep(
                step: step,
                lessonID: lesson.id,
                translationLanguage: contentLanguage,
                analyticsProperties: stepTelemetryProperties(index: stepIndex),
                telemetrySessionID: telemetrySessionID,
                onContinue: advance
            )
        case .hearRespond:
            if let hearRespond = step.hearRespond {
                HearRespondStep(
                    exercise: hearRespond,
                    analyticsProperties: stepTelemetryProperties(index: stepIndex),
                    telemetrySessionID: telemetrySessionID,
                    onContinue: advance
                )
            } else {
                DecodeStep(
                    step: step,
                    lessonID: lesson.id,
                    translationLanguage: contentLanguage,
                    analyticsProperties: stepTelemetryProperties(index: stepIndex),
                    telemetrySessionID: telemetrySessionID,
                    onContinue: advance
                )
            }
        case .speak:
            SpeakStep(
                step: step,
                analyticsProperties: stepTelemetryProperties(index: stepIndex),
                telemetrySessionID: telemetrySessionID,
                isFinalRound: stepIndex == lesson.steps.count - 1,
                nextRoundNumber: min(lesson.roundCount, currentRoundNumber + 1),
                onContinue: advance
            )
        }
    }

    private func advanceFromListen() {
        let skipsDecode = stepIndex + 1 < lesson.steps.count
            && lesson.steps[stepIndex + 1].kind == .decode
        advance(by: skipsDecode ? 2 : 1)
    }

    private func advance() {
        advance(by: 1)
    }

    private func advance(by stepCount: Int) {
        Task { await dependencies.audioService.stop() }
        if stepIndex < lesson.steps.count {
            dependencies.analytics.track(
                .lessonStepCompleted,
                properties: stepTelemetryProperties(index: stepIndex),
                clientSessionID: telemetrySessionID
            )
        }
        let nextStepIndex = min(stepIndex + stepCount, lesson.steps.count)
        dependencies.lessonProgressStore.save(nextStepIndex: nextStepIndex, for: lesson)
        appState.scheduleCloudStateSync()
        stepIndex = nextStepIndex
        if nextStepIndex == lesson.steps.count {
            finalizeLessonTelemetry()
        }
    }

    private var canGoBack: Bool {
        stepIndex > 0
    }

    private func goBack() {
        guard canGoBack else { return }
        Task { await dependencies.audioService.stop() }
        var previousStepIndex = max(0, stepIndex - 1)
        if lesson.steps[previousStepIndex].kind == .decode,
           previousStepIndex > 0,
           lesson.steps[previousStepIndex - 1].kind == .coldListen {
            previousStepIndex -= 1
            revealedListenStepIDs.insert(lesson.steps[previousStepIndex].id)
        }
        dependencies.lessonProgressStore.save(nextStepIndex: previousStepIndex, for: lesson)
        appState.scheduleCloudStateSync()
        stepIndex = previousStepIndex
    }

    private var currentRoundNumber: Int {
        min(lesson.roundCount, (stepIndex / LessonSessionPlan.stagesPerRound) + 1)
    }

    private var progressStepCount: Int {
        guard stepIndex < lesson.steps.count else { return lesson.steps.count }
        let step = lesson.steps[stepIndex]
        let includesInlineDecode = step.kind == .coldListen
            && revealedListenStepIDs.contains(step.id)
            && stepIndex + 1 < lesson.steps.count
            && lesson.steps[stepIndex + 1].kind == .decode
        return min(stepIndex + (includesInlineDecode ? 2 : 1), lesson.steps.count)
    }

    private var currentStageTitle: String {
        guard stepIndex < lesson.steps.count else { return L("Complete") }
        return switch lesson.steps[stepIndex].kind {
        case .coldListen:
            revealedListenStepIDs.contains(lesson.steps[stepIndex].id) ? L("Decode") : L("Listen")
        case .decode: L("Decode")
        case .hearRespond: L("Hear & match")
        case .speak: L("Speak")
        }
    }

    private func apply(_ feedback: SessionFeedback) {
        guard !didRecordCompletion else { return }
        let currentSpeed = AudioPreferences.speed(from: defaultSpeedRawValue)
        defaultSpeedRawValue = AudioPreferences.adjustedSpeed(
            from: currentSpeed,
            feedback: feedback.audioPace
        ).rawValue
        dependencies.analytics.track(
            .sessionFeedbackSubmitted,
            properties: baseTelemetryProperties.merging([
                "difficulty_feedback": feedback.difficulty.rawValue,
                "pace_feedback": feedback.audioPace.rawValue,
                "has_topic_preference": feedback.nextLessonTopic == nil ? "false" : "true"
            ], uniquingKeysWith: { current, _ in current }),
            clientSessionID: telemetrySessionID
        )
        didRecordCompletion = true
        appState.recordReviewSignal(.lesson(difficulty: feedback.difficulty))
        dependencies.lessonProgressStore.clear(for: lesson.id)
        appState.scheduleCloudStateSync()
        onComplete(feedback)
        Task { @MainActor in
            if await dependencies.notificationService.shouldInviteAfterLesson() {
                dependencies.notificationService.markReminderInvitationSeen()
                isShowingReminderInvitation = true
            } else {
                onDismiss()
            }
        }
    }

    private func finalizeLessonTelemetry() {
        guard !didFinalizeTelemetry else { return }
        didFinalizeTelemetry = true
        let properties = baseTelemetryProperties.merging([
            "screen_name": "lesson",
            "round_count": String(lesson.roundCount)
        ], uniquingKeysWith: { current, _ in current })
        dependencies.analytics.track(
            .lessonExercisesCompleted,
            properties: properties,
            clientSessionID: telemetrySessionID
        )
        dependencies.analytics.track(
            .lessonCompleted,
            properties: properties,
            clientSessionID: telemetrySessionID
        )
        Task { await syncLessonSession(completed: true, endedAt: .now) }
        TikTokAppEvents.trackLessonCompleted(lesson: lesson)
        AppsFlyerAppEvents.trackLessonCompleted(lesson: lesson)
        MetaAppEvents.trackLessonCompleted(lesson: lesson)
        AppsFlyerAppEvents.trackExerciseCompleted(
            courseName: "Kumusta",
            exerciseName: lesson.analyticsScenario
        )
    }

    private func syncLessonSession(completed: Bool, endedAt: Date?) async {
        guard let remote = dependencies.signedInRepository else {
            if completed { awardedLessonXP = 0 }
            return
        }
        let activeSeconds = min(
            14_400,
            max(0, Int((endedAt ?? .now).timeIntervalSince(telemetryStartedAt)))
        )
        guard let saved = try? await remote.syncLearningSession(
            LearningSessionSyncInput(
                clientSessionID: telemetrySessionID,
                lessonID: lesson.id,
                contentKind: telemetryContext.contentKind,
                entryPoint: telemetryContext.entryPoint,
                isReplay: telemetryContext.isReplay,
                kind: .lesson,
                startedAt: telemetryStartedAt,
                endedAt: endedAt,
                activeSeconds: activeSeconds,
                completed: completed,
                score: nil,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            )
        ) else {
            if completed { awardedLessonXP = 0 }
            return
        }

        if completed {
            let award = try? await remote.awardXP(
                XPAwardRequest(
                    reasonCode: "lesson_completed",
                    sourceID: saved.id.uuidString,
                    idempotencyKey: "lesson_completed:\(saved.id.uuidString)",
                    metadata: ["lesson_id": lesson.id.uuidString]
                )
            )
            awardedLessonXP = award.map { $0.wasDuplicate ? 0 : $0.amount } ?? 0
            await appState.syncDailyProgress()
        }
    }

    private var baseTelemetryProperties: [String: String] {
        [
            "lesson_id": lesson.id.uuidString,
            "content_kind": telemetryContext.contentKind.rawValue,
            "entry_point": telemetryContext.entryPoint,
            "is_replay": telemetryContext.isReplay ? "true" : "false"
        ]
    }

    private func stepTelemetryProperties(index: Int) -> [String: String] {
        guard lesson.steps.indices.contains(index) else {
            return baseTelemetryProperties.merging([
                "screen_name": "lesson",
                "step_index": String(index)
            ], uniquingKeysWith: { current, _ in current })
        }
        let step = lesson.steps[index]
        return baseTelemetryProperties.merging([
            "screen_name": "lesson",
            "step_id": step.id.uuidString,
            "step_index": String(index),
            "step_kind": step.kind.rawValue
        ], uniquingKeysWith: { current, _ in current })
    }

}

private struct ColdListenStep: View {
    let step: LessonStep
    let lessonID: UUID
    let translationLanguage: AppLanguage?
    let lessonMinutes: Int
    let roundCount: Int
    let analyticsProperties: [String: String]
    let telemetrySessionID: UUID
    @Binding var isRevealed: Bool
    let onContinue: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(LessonEducation.formatSeenKey)
    private var hasSeenLessonFormat = false
    @State private var selectedGloss: LessonWordGloss?
    @State private var hasListenedToSentence = false
    @State private var showsListenReminder = false
    @State private var tileBank: ListenTileBank?
    /// One entry per slot; removing a word leaves its slot empty (nil).
    @State private var pickedTileIDs: [Int?] = []
    @State private var wrongTilePositions: Set<Int> = []
    /// Frames of the sentence slots, used to find where a dragged word lands.
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var draggedPosition: Int?
    @State private var dragTranslation: CGSize = .zero
    @State private var dropTargetPosition: Int?
    @State private var reorderCount = 0
    @State private var buildAttemptCount = 0
    @State private var builtSentenceCorrectly = false

    init(
        step: LessonStep,
        lessonID: UUID,
        translationLanguage: AppLanguage?,
        lessonMinutes: Int,
        roundCount: Int,
        analyticsProperties: [String: String],
        telemetrySessionID: UUID,
        isRevealed: Binding<Bool>,
        onContinue: @escaping () -> Void
    ) {
        self.step = step
        self.lessonID = lessonID
        self.translationLanguage = translationLanguage
        self.lessonMinutes = lessonMinutes
        self.roundCount = roundCount
        self.analyticsProperties = analyticsProperties
        self.telemetrySessionID = telemetrySessionID
        self._isRevealed = isRevealed
        self.onContinue = onContinue

        var generator = SystemRandomNumberGenerator()
        let syllableCount = ListenTileBank.tileTexts(in: step.tagalog).count
        _tileBank = State(
            initialValue: ListenTileBank.make(
                sentence: step.tagalog,
                distractorCount: ListenTileBank.distractorCount(forSyllables: syllableCount),
                using: &generator
            )
        )
    }

    /// The learner rebuilds the sentence from tiles before the reveal.
    private var isBuildingSentence: Bool {
        !isRevealed && tileBank != nil
    }

    private var hasFilledAllSlots: Bool {
        guard let tileBank else { return false }
        return pickedTileIDs.count == tileBank.answer.count && !pickedTileIDs.contains(nil)
    }

    private var filledSlotCount: Int {
        pickedTileIDs.compactMap { $0 }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !hasSeenLessonFormat {
                            LessonFormatExplainer(
                                lessonMinutes: lessonMinutes,
                                roundCount: roundCount
                            ) {
                                withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
                                    hasSeenLessonFormat = true
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer(minLength: 0)
                        coldListenHeader
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: max(0, proxy.size.height - 36))
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                    .screenContentWidth()
                }
                .scrollIndicators(.hidden)
            }

            VStack(spacing: 16) {
                AudioSpeedControls(
                    text: step.tagalog,
                    analyticsProperties: analyticsProperties,
                    telemetrySessionID: telemetrySessionID,
                    autoplay: true,
                    forceAutoplay: true,
                    onPlaybackCompleted: {
                        hasListenedToSentence = true
                        showsListenReminder = false
                    }
                )

                if showsListenReminder {
                    Text(L("Listen to the sentence at least once before revealing it."))
                        .font(.footnote)
                        .foregroundStyle(KumustaColors.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("lesson-listen-reminder")
                }

                if isBuildingSentence {
                    Button(wrongTilePositions.isEmpty ? L("Check") : L("Try again")) {
                        hasSeenLessonFormat = true
                        if wrongTilePositions.isEmpty {
                            checkBuiltSentence()
                        } else {
                            clearWrongTiles()
                        }
                    }
                    .buttonStyle(KumustaPrimaryButtonStyle())
                    .disabled(wrongTilePositions.isEmpty && !hasFilledAllSlots)
                } else {
                    Button(isRevealed ? L("Continue") : L("Reveal the situation")) {
                        hasSeenLessonFormat = true
                        if isRevealed {
                            onContinue()
                        } else {
                            revealSentence()
                        }
                    }
                    .buttonStyle(KumustaPrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .screenContentWidth()
        }
        .sheet(item: $selectedGloss) { gloss in
            LessonWordGlossSheet(
                gloss: gloss,
                sentence: step.tagalog,
                sentenceTranslation: step.translation,
                isSaved: dependencies.savedLessonWordStore.contains(
                    token: gloss.token
                )
            ) {
                dependencies.savedLessonWordStore.save(
                    gloss: gloss,
                    sentence: step.tagalog,
                    sentenceTranslation: step.translation,
                    lessonID: lessonID,
                    translationLanguage: translationLanguage
                )
                dependencies.analytics.track(
                    .lessonVocabularySaved,
                    properties: analyticsProperties.merging([
                        "vocabulary_id": gloss.id.uuidString,
                        "source_lesson_id": lessonID.uuidString
                    ], uniquingKeysWith: { current, _ in current }),
                    clientSessionID: telemetrySessionID
                )
                appState.scheduleCloudStateSync()
            }
            .presentationDetents([.height(390), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var coldListenHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                if !isRevealed {
                    Text(L("Cold listen"))
                        .scaledFont(12, weight: .semibold, design: .rounded)
                        .scaledTracking(1.5, forPointSize: 12)
                        .foregroundStyle(KumustaColors.muted)
                }

                Text(isRevealed ? L("Decode the sentence") : isBuildingSentence ? L("Build what you heard") : L("Hear the situation first"))
                    .font(KumustaTypography.title2)
                    .foregroundStyle(KumustaColors.ink.opacity(isRevealed ? 0.82 : 1))
                    .contentTransition(.opacity)
            }

            sentenceCard
        }
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isRevealed {
                VStack(alignment: .center, spacing: 10) {
                    if builtSentenceCorrectly {
                        Label(L("You heard it!"), systemImage: "checkmark.circle.fill")
                            .scaledFont(15, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.success)
                            .frame(maxWidth: .infinity)
                    }
                    if step.wordGlosses.isEmpty {
                        Text(step.tagalog)
                            .scaledFont(27, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        WordGlossFlow(glosses: step.wordGlosses, centered: true) { gloss in
                            selectedGloss = gloss
                            dependencies.analytics.track(
                                .lessonVocabularyOpened,
                                properties: analyticsProperties.merging([
                                    "vocabulary_id": gloss.id.uuidString
                                ], uniquingKeysWith: { current, _ in current }),
                                clientSessionID: telemetrySessionID
                            )
                        }
                        Label(L("Tap a word or phrase to see how it works"), systemImage: "hand.tap.fill")
                            .scaledFont(14, weight: .semibold, design: .rounded)
                            .foregroundStyle(KumustaColors.accentDeep)
                            .multilineTextAlignment(.center)
                    }
                    Text(step.translation)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
            } else if let tileBank {
                sentenceBuilder(tileBank)
                    .transition(.opacity)
            } else {
                Button(action: revealSentence) {
                    VStack(alignment: .center, spacing: 14) {
                        SentencePlaceholder(text: step.tagalog)
                        Label(L("Tap to reveal and decode"), systemImage: "hand.tap.fill")
                            .scaledFont(14, weight: .semibold, design: .rounded)
                            .foregroundStyle(KumustaColors.accentDeep)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Reveal the spoken sentence and its meaning"))
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: isRevealed)
        .sensoryFeedback(trigger: buildAttemptCount) { _, attempts in
            guard attempts > 0 else { return nil }
            return builtSentenceCorrectly ? .success : .error
        }
    }

    private func revealSentence() {
        guard hasListenedToSentence else {
            showsListenReminder = true
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
            hasSeenLessonFormat = true
            isRevealed = true
        }
    }

    private func sentenceBuilder(_ tileBank: ListenTileBank) -> some View {
        VStack(alignment: .center, spacing: 22) {
            WordWrapLayout(horizontalSpacing: 5, verticalSpacing: 8, centered: true) {
                ForEach(tileBank.answer.indices, id: \.self) { position in
                    if pickedTileIDs.indices.contains(position),
                       let pickedID = pickedTileIDs[position],
                       let tile = tileBank.tile(id: pickedID) {
                        let isDragged = draggedPosition == position
                        Button {
                            unpickTile(at: position)
                        } label: {
                            Text(tile.text)
                                .scaledFont(24, weight: .bold, design: .rounded)
                        }
                        .buttonStyle(ListenTileButtonStyle(isWrong: wrongTilePositions.contains(position)))
                        .overlay {
                            if dropTargetPosition == position {
                                dropTargetOutline
                            }
                        }
                        .scaleEffect(isDragged && !reduceMotion ? 1.08 : 1)
                        .offset(isDragged ? dragTranslation : .zero)
                        .zIndex(isDragged ? 1 : 0)
                        .highPriorityGesture(slotDragGesture(from: position))
                        .accessibilityLabel(tile.text)
                        .accessibilityHint(L("Removes this word. Drag to move it."))
                        .accessibilityActions {
                            if position > 0 {
                                Button(L("Move earlier")) { moveTile(from: position, to: position - 1) }
                            }
                            if position < tileBank.answer.count - 1 {
                                Button(L("Move later")) { moveTile(from: position, to: position + 1) }
                            }
                        }
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(Self.sentenceSlotSpace))
                        } action: { frame in
                            slotFrames[position] = frame
                        }
                    } else {
                        Text(tileBank.answer[position])
                            .scaledFont(24, weight: .bold, design: .rounded)
                            .foregroundStyle(.clear)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.dynamic(light: 0x74604D, dark: 0x3A4B54))
                            }
                            .padding(.bottom, 3)
                            .overlay {
                                if dropTargetPosition == position {
                                    dropTargetOutline
                                        .padding(.bottom, 3)
                                }
                            }
                            .accessibilityHidden(true)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named(Self.sentenceSlotSpace))
                            } action: { frame in
                                slotFrames[position] = frame
                            }
                    }
                }
            }
            .coordinateSpace(.named(Self.sentenceSlotSpace))
            .sensoryFeedback(.impact(weight: .light), trigger: reorderCount)
            .keyframeAnimator(
                initialValue: CGFloat.zero,
                trigger: reduceMotion ? 0 : buildAttemptCount
            ) { view, offset in
                view.offset(x: offset)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-9, duration: 0.07)
                    CubicKeyframe(9, duration: 0.08)
                    CubicKeyframe(-6, duration: 0.08)
                    CubicKeyframe(4, duration: 0.07)
                    CubicKeyframe(0, duration: 0.07)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L("Your sentence"))

            if !wrongTilePositions.isEmpty {
                Text(L("Listen again. The red words don't match, often a look-alike word."))
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.errorDeep)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            Rectangle()
                .fill(KumustaColors.line)
                .frame(height: 1)

            WordWrapLayout(horizontalSpacing: 8, verticalSpacing: 10, centered: true) {
                ForEach(tileBank.tiles) { tile in
                    let isPicked = pickedTileIDs.contains(tile.id)
                    Button {
                        pickTile(tile)
                    } label: {
                        Text(tile.text)
                            .scaledFont(20, weight: .semibold, design: .rounded)
                            .opacity(isPicked ? 0 : 1)
                    }
                    .buttonStyle(ListenTileButtonStyle(isGhost: isPicked))
                    .disabled(isPicked || hasFilledAllSlots)
                    .accessibilityHidden(isPicked)
                    .accessibilityLabel(tile.text)
                    .accessibilityHint(L("Adds this word to your sentence"))
                }
            }
            .sensoryFeedback(.selection, trigger: filledSlotCount)

            Button(buildAttemptCount == 0 ? L("Not sure? Just reveal it") : L("Show me the answer")) {
                revealSentence()
            }
            .scaledFont(15, weight: .semibold, design: .rounded)
            .foregroundStyle(KumustaColors.muted)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private static let sentenceSlotSpace = "sentenceSlots"

    private var dropTargetOutline: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(KumustaColors.accent, lineWidth: 3)
    }

    /// Dragging a placed word onto another slot swaps the two (or moves it
    /// into an empty slot). A plain tap still removes the word.
    private func slotDragGesture(from position: Int) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.sentenceSlotSpace))
            .onChanged { value in
                draggedPosition = position
                dragTranslation = value.translation
                let target = slotPosition(at: value.location)
                dropTargetPosition = target == position ? nil : target
            }
            .onEnded { value in
                if let target = slotPosition(at: value.location), target != position {
                    moveTile(from: position, to: target)
                }
                withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                    draggedPosition = nil
                    dragTranslation = .zero
                    dropTargetPosition = nil
                }
            }
    }

    private func slotPosition(at location: CGPoint) -> Int? {
        slotFrames.first { $0.value.insetBy(dx: -4, dy: -6).contains(location) }?.key
    }

    private func moveTile(from source: Int, to destination: Int) {
        guard pickedTileIDs.indices.contains(source),
              pickedTileIDs.indices.contains(destination),
              source != destination
        else { return }
        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
            pickedTileIDs.swapAt(source, destination)
            // Both slots hold a different word now, so their red marks no
            // longer describe what is there.
            wrongTilePositions.remove(source)
            wrongTilePositions.remove(destination)
        }
        reorderCount += 1
    }

    private func pickTile(_ tile: ListenTile) {
        guard let tileBank else { return }
        if pickedTileIDs.count != tileBank.answer.count {
            pickedTileIDs = Array(repeating: nil, count: tileBank.answer.count)
        }
        guard let emptySlot = pickedTileIDs.firstIndex(of: nil) else { return }
        // The pitch climbs with each filled slot, so it restarts with each sentence.
        WordSelectFeedbackPlayer.shared.play(
            step: filledSlotCount,
            slotCount: tileBank.answer.count
        )
        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
            pickedTileIDs[emptySlot] = tile.id
        }
    }

    private func unpickTile(at position: Int) {
        guard pickedTileIDs.indices.contains(position) else { return }
        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
            pickedTileIDs[position] = nil
            wrongTilePositions.remove(position)
        }
    }

    private func clearWrongTiles() {
        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
            for position in wrongTilePositions where pickedTileIDs.indices.contains(position) {
                pickedTileIDs[position] = nil
            }
            wrongTilePositions = []
        }
    }

    private func checkBuiltSentence() {
        guard let tileBank, hasFilledAllSlots else { return }
        let wrongPositions = tileBank.wrongPositions(for: pickedTileIDs)
        let isCorrect = wrongPositions.isEmpty
        dependencies.analytics.track(
            .lessonAnswerSubmitted,
            properties: analyticsProperties.merging([
                "exercise": "listen_build",
                "is_correct": isCorrect ? "true" : "false",
                "is_first_attempt": buildAttemptCount == 0 ? "true" : "false",
                "wrong_count": String(wrongPositions.count),
                "missed_words": wrongPositions.map { tileBank.answer[$0] }.joined(separator: " ")
            ], uniquingKeysWith: { current, _ in current }),
            clientSessionID: telemetrySessionID
        )
        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
            builtSentenceCorrectly = isCorrect
            wrongTilePositions = Set(wrongPositions)
            buildAttemptCount += 1
        }
        if isCorrect {
            SuccessFeedbackPlayer.shared.play()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
                isRevealed = true
            }
        } else {
            WrongFeedbackPlayer.shared.play()
        }
    }
}

/// A raised word tile; `isGhost` leaves an empty dent where a used tile sat.
struct ListenTileButtonStyle: ButtonStyle {
    var isWrong = false
    var isGhost = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = isGhost ? 0 : 3
        let pressed = configuration.isPressed && !reduceMotion
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let border = isWrong ? KumustaColors.error : KumustaColors.line
        configuration.label
            .foregroundStyle(isWrong ? KumustaColors.errorDeep : KumustaColors.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(shape.fill(isGhost ? KumustaColors.surfaceMuted : isWrong ? KumustaColors.error.opacity(0.16) : KumustaColors.surface))
            .background(shape.fill(KumustaColors.canvas))
            .overlay(shape.stroke(isGhost ? Color.clear : border, lineWidth: 2))
            .background(shape.fill(border).offset(y: pressed ? 0 : depth))
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, 3)
            .contentShape(shape)
            .animation(reduceMotion ? nil : KumustaMotion.press, value: configuration.isPressed)
    }
}

private struct LessonFormatExplainer: View {
    let lessonMinutes: Int
    let roundCount: Int
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .scaledFont(21, weight: .semibold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 42, height: 42)
                .background(KumustaColors.accentSoft.opacity(0.65))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L("YOUR FIRST LESSON"))
                    .scaledFont(14, weight: .bold, design: .rounded)
                    .scaledTracking(0.7, forPointSize: 14)
                    .foregroundStyle(KumustaColors.accentDeep)
                Text(L("Your %lld-minute plan has %lld complete rounds.", lessonMinutes, roundCount))
                    .scaledFont(18, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L(one: "You’ll complete %lld round. Every round starts with audio, then asks you to decode the meaning before you say the line.", other: "You’ll complete %lld rounds. Every round starts with audio, then asks you to decode the meaning before you say the line.", count: roundCount))
                    .scaledFont(16, weight: .regular, design: .rounded)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Got it"), action: onDismiss)
                    .scaledFont(16, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(minHeight: 44)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KumustaColors.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KumustaColors.accentSoft, lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct HearRespondStep: View {
    let exercise: HearRespondExercise
    let analyticsProperties: [String: String]
    let telemetrySessionID: UUID
    let onContinue: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedOptionID: UUID?
    @State private var submittedOptionID: UUID?
    @State private var attemptCount = 0
    @State private var displayedOptions: [HearRespondOption]

    init(
        exercise: HearRespondExercise,
        analyticsProperties: [String: String],
        telemetrySessionID: UUID,
        onContinue: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.analyticsProperties = analyticsProperties
        self.telemetrySessionID = telemetrySessionID
        self.onContinue = onContinue

        var generator = SystemRandomNumberGenerator()
        _displayedOptions = State(
            initialValue: exercise.randomizedOptions(using: &generator)
        )
    }

    private var hasSubmitted: Bool {
        submittedOptionID != nil
    }

    private var selectedOptionIsCorrect: Bool {
        selectedOptionID == exercise.correctOptionID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(L("What did you hear?"))
                    .scaledFont(26, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .accessibilityAddTraits(.isHeader)

                listenHero

                VStack(spacing: 12) {
                    ForEach(displayedOptions) { option in
                        HearRespondOptionRow(
                            option: option,
                            isSelected: selectedOptionID == option.id,
                            isSubmitted: hasSubmitted,
                            isCorrect: option.id == exercise.correctOptionID,
                            wasSelected: option.id == submittedOptionID,
                            shakeTrigger: attemptCount
                        ) {
                            withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                                selectedOptionID = option.id
                            }
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedOptionID)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            answerFooter
        }
        .sensoryFeedback(trigger: submittedOptionID) { _, submitted in
            guard submitted != nil else { return nil }
            return selectedOptionIsCorrect ? .success : .error
        }
    }

    /// Mascot "speaking" the audio: a bubble holding the big replay button and
    /// the slow-speed button, Duolingo-listening style.
    private var listenHero: some View {
        HStack(alignment: .center, spacing: 4) {
            BuddyMotionView(motion: promptMascotMotion, size: 112)
                .accessibilityHidden(true)

            AudioSpeedControls(
                text: exercise.promptTagalog,
                analyticsProperties: analyticsProperties,
                telemetrySessionID: telemetrySessionID,
                iconOnly: true,
                iconSize: 72,
                autoplay: true,
                forceAutoplay: true
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background {
                SpeechBubbleShape(tailEdge: .leading)
                    .fill(KumustaColors.surface)
            }
            .overlay {
                SpeechBubbleShape(tailEdge: .leading)
                    .stroke(KumustaColors.line, lineWidth: 2)
            }
            .padding(.leading, SpeechBubbleShape.tailHeight)
        }
    }

    @ViewBuilder
    private var answerFooter: some View {
        if hasSubmitted {
            let isCorrect = selectedOptionIsCorrect
            let tint = isCorrect ? KumustaColors.success : KumustaColors.error
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .scaledFont(28, weight: .bold)
                    Text(isCorrect ? L("Nice work!") : L("Not quite"))
                        .scaledFont(22, weight: .heavy, design: .rounded)
                }
                .foregroundStyle(isCorrect ? KumustaColors.success : KumustaColors.errorDeep)

                if isCorrect {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.promptTagalog)
                            .scaledFont(19, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                        Text(exercise.promptTranslation)
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    Button(L("CONTINUE")) { onContinue() }
                        .buttonStyle(KumustaSuccessButtonStyle())
                } else {
                    Text(L("Listen once more, then pick again."))
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.ink)

                    Button(L("TRY AGAIN")) {
                        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
                            selectedOptionID = nil
                            submittedOptionID = nil
                        }
                    }
                    .buttonStyle(KumustaPrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                tint.opacity(0.16)
                    .background(KumustaColors.canvas)
                    .ignoresSafeArea(edges: .bottom)
            }
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        } else {
            Button(L("CHECK")) { submitAnswer() }
                .buttonStyle(KumustaPrimaryButtonStyle())
                .disabled(selectedOptionID == nil)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(KumustaColors.canvas)
                .screenContentWidth()
        }
    }

    private var promptMascotMotion: BuddyMotion {
        guard hasSubmitted else { return .curious }
        return selectedOptionIsCorrect ? .correct : .mistake
    }

    private func submitAnswer() {
        guard let selectedOptionID else { return }
        let isFirstAttempt = attemptCount == 0
        let isCorrect = selectedOptionID == exercise.correctOptionID
        dependencies.analytics.track(
            .lessonAnswerSubmitted,
            properties: analyticsProperties.merging([
                "answer_id": selectedOptionID.uuidString,
                "is_correct": isCorrect ? "true" : "false",
                "is_first_attempt": isFirstAttempt ? "true" : "false"
            ], uniquingKeysWith: { current, _ in current }),
            clientSessionID: telemetrySessionID
        )
        Task { await dependencies.audioService.stop() }
        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
            attemptCount += 1
            submittedOptionID = selectedOptionID
            if isCorrect {
                SuccessFeedbackPlayer.shared.play()
            } else {
                WrongFeedbackPlayer.shared.play()
            }
        }
    }
}

private struct HearRespondOptionRow: View {
    let option: HearRespondOption
    let isSelected: Bool
    let isSubmitted: Bool
    let isCorrect: Bool
    let wasSelected: Bool
    let shakeTrigger: Int
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(option.englishTranslation)
                    .scaledFont(18, weight: .semibold, design: .rounded)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if correctAnswer {
                    Image(systemName: "checkmark.circle.fill")
                        .scaledFont(22, weight: .bold)
                        .foregroundStyle(KumustaColors.success)
                        .transition(.scale.combined(with: .opacity))
                } else if wrongAnswer {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(22, weight: .bold)
                        .foregroundStyle(KumustaColors.errorDeep)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        }
        .buttonStyle(ChoiceCardButtonStyle(face: faceColor, border: borderColor))
        .disabled(isSubmitted)
        .opacity(isSubmitted && !wasSelected ? 0.55 : 1)
        .keyframeAnimator(
            initialValue: CGFloat.zero,
            trigger: wrongAnswer && !reduceMotion ? shakeTrigger : 0
        ) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-9, duration: 0.07)
                CubicKeyframe(9, duration: 0.08)
                CubicKeyframe(-6, duration: 0.08)
                CubicKeyframe(4, duration: 0.07)
                CubicKeyframe(0, duration: 0.07)
            }
        }
        .accessibilityLabel(option.englishTranslation)
        .accessibilityHint(isSubmitted ? selectionDescription : L("Selects this meaning"))
        .accessibilityValue(selectionDescription)
    }

    private var correctAnswer: Bool { isSubmitted && isCorrect && wasSelected }
    private var wrongAnswer: Bool { isSubmitted && !isCorrect && wasSelected }

    private var faceColor: Color {
        if correctAnswer { return KumustaColors.success.opacity(0.18) }
        if wrongAnswer { return KumustaColors.error.opacity(0.16) }
        if isSelected { return KumustaColors.focus.opacity(0.16) }
        return KumustaColors.surface
    }

    private var borderColor: Color {
        if correctAnswer { return KumustaColors.success }
        if wrongAnswer { return KumustaColors.error }
        if isSelected { return KumustaColors.focus }
        return KumustaColors.line
    }

    private var textColor: Color {
        if correctAnswer { return KumustaColors.success }
        if wrongAnswer { return KumustaColors.errorDeep }
        if isSelected { return KumustaColors.focus }
        return KumustaColors.ink
    }

    private var selectionDescription: String {
        if correctAnswer { return L("Correct meaning") }
        if wrongAnswer { return L("Not the right meaning") }
        if isSelected { return L("Selected") }
        return L("Not selected")
    }
}

private struct DecodeStep: View {
    let step: LessonStep
    let lessonID: UUID
    let translationLanguage: AppLanguage?
    let analyticsProperties: [String: String]
    let telemetrySessionID: UUID
    let onContinue: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @State private var selectedGloss: LessonWordGloss?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TodayScreenHeader(
                    eyebrow: "",
                    title: L("Decode the sentence"),
                    subtitle: L("Tap a word or phrase to see how it works.")
                )

                VStack(alignment: .leading, spacing: 7) {
                    if step.wordGlosses.isEmpty {
                        Text(step.tagalog)
                            .scaledFont(27, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        WordGlossFlow(glosses: step.wordGlosses) { gloss in
                            selectedGloss = gloss
                            dependencies.analytics.track(
                                .lessonVocabularyOpened,
                                properties: analyticsProperties.merging([
                                    "vocabulary_id": gloss.id.uuidString
                                ], uniquingKeysWith: { current, _ in current }),
                                clientSessionID: telemetrySessionID
                            )
                        }
                        Label(L("Tap any word or phrase for its meaning"), systemImage: "hand.tap.fill")
                            .scaledFont(14, weight: .semibold, design: .rounded)
                            .foregroundStyle(KumustaColors.accentDeep)
                    }
                    Text(step.translation)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KumustaColors.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                AudioSpeedControls(
                    text: step.tagalog,
                    analyticsProperties: analyticsProperties,
                    telemetrySessionID: telemetrySessionID
                )

                Button(L("Say the whole request")) {
                    onContinue()
                }
                .buttonStyle(KumustaPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedGloss) { gloss in
            LessonWordGlossSheet(
                gloss: gloss,
                sentence: step.tagalog,
                sentenceTranslation: step.translation,
                isSaved: dependencies.savedLessonWordStore.contains(
                    token: gloss.token
                )
            ) {
                dependencies.savedLessonWordStore.save(
                    gloss: gloss,
                    sentence: step.tagalog,
                    sentenceTranslation: step.translation,
                    lessonID: lessonID,
                    translationLanguage: translationLanguage
                )
                dependencies.analytics.track(
                    .lessonVocabularySaved,
                    properties: analyticsProperties.merging([
                        "vocabulary_id": gloss.id.uuidString,
                        "source_lesson_id": lessonID.uuidString
                    ], uniquingKeysWith: { current, _ in current }),
                    clientSessionID: telemetrySessionID
                )
                appState.scheduleCloudStateSync()
            }
            .presentationDetents([.height(390), .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct SentencePlaceholder: View {
    let text: String

    private var chunks: [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private var chunkColor: Color {
        Color.dynamic(light: 0x74604D, dark: 0x3A4B54)
    }

    var body: some View {
        WordWrapLayout(horizontalSpacing: 4, verticalSpacing: 6, centered: true) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                Text(chunk)
                    .scaledFont(27, weight: .bold, design: .rounded)
                    .foregroundStyle(.clear)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(chunkColor)
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WordGlossFlow: View {
    let glosses: [LessonWordGloss]
    var centered = false
    let onSelect: (LessonWordGloss) -> Void

    var body: some View {
        WordWrapLayout(horizontalSpacing: 5, verticalSpacing: 7, centered: centered) {
            ForEach(glosses) { gloss in
                Button {
                    onSelect(gloss)
                } label: {
                    Text(gloss.token)
                        .scaledFont(27, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(KumustaColors.accentSoft)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(gloss.token), \(gloss.translation)")
                .accessibilityHint(L("Shows the word card"))
            }
        }
    }
}

private struct LessonWordGlossSheet: View {
    let gloss: LessonWordGloss
    let sentence: String
    let sentenceTranslation: String
    let isSaved: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(L("IN THIS SENTENCE"))
                        .scaledFont(14, weight: .bold, design: .rounded)
                        .scaledTracking(0.8, forPointSize: 14)
                        .foregroundStyle(KumustaColors.accentDeep)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .scaledFont(16, weight: .bold)
                            .foregroundStyle(KumustaColors.ink)
                            .frame(width: 44, height: 44)
                            .background(KumustaColors.surfaceMuted)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L("Close word card"))
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(gloss.token.trimmingCharacters(in: .punctuationCharacters))
                        .scaledFont(34, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                    Text(gloss.translation)
                        .scaledFont(21, weight: .semibold, design: .rounded)
                        .foregroundStyle(KumustaColors.accentDeep)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(sentence)
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.ink)
                    Text(sentenceTranslation)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                }

                Spacer(minLength: 0)

                Button {
                    onSave()
                } label: {
                    Label(
                        isSaved ? L("Added to Vocabulary") : L("Add to Vocabulary"),
                        systemImage: isSaved ? "checkmark.circle.fill" : "plus.circle.fill"
                    )
                }
                .buttonStyle(KumustaPrimaryButtonStyle())
                .disabled(isSaved)
            }
            .padding(24)
        }
    }
}

struct WordWrapLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    var centered = false

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let availableWidth = proposal.width ?? 320
        var position = CGPoint.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x > 0, position.x + size.width > availableWidth {
                position.x = 0
                position.y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            position.x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: availableWidth, height: position.y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var lines: [[Int]] = []
        var currentLine: [Int] = []
        var currentLineWidth: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            let nextLineWidth = currentLine.isEmpty
                ? size.width
                : currentLineWidth + horizontalSpacing + size.width
            if !currentLine.isEmpty, nextLineWidth > bounds.width {
                lines.append(currentLine)
                currentLine = [index]
                currentLineWidth = size.width
            } else {
                currentLine.append(index)
                currentLineWidth = nextLineWidth
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        var y = bounds.minY
        for line in lines {
            let lineWidth = line.reduce(CGFloat.zero) { $0 + sizes[$1].width }
                + horizontalSpacing * CGFloat(max(0, line.count - 1))
            let lineHeight = line.reduce(CGFloat.zero) { max($0, sizes[$1].height) }
            var x = bounds.minX + (centered ? max(0, (bounds.width - lineWidth) / 2) : 0)

            for index in line {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(sizes[index])
                )
                x += sizes[index].width + horizontalSpacing
            }
            y += lineHeight + verticalSpacing
        }
    }
}

private struct SpeakStep: View {
    let step: LessonStep
    let analyticsProperties: [String: String]
    let telemetrySessionID: UUID
    let isFinalRound: Bool
    let nextRoundNumber: Int
    let onContinue: () -> Void
    @Environment(DependencyContainer.self) private var dependencies
    @State private var recorder = SpeakingRecorder()
    @State private var feedbackState: SpeechFeedbackState = .idle
    @State private var feedbackTask: Task<Void, Never>?
    @State private var isPreparingToRecord = false
    @State private var matchedTarget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(feedbackState.isProcessing ? L("Checking your take…") : L("Speak this sentence"))
                    .scaledFont(26, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 0) {
                    BuddyMotionView(
                        motion: feedbackState.isProcessing
                            ? .reviewing
                            : feedbackState.hasResult
                                ? (matchedTarget ? .correct : .mistake)
                                : .listening,
                        size: 112
                    )
                    .padding(.leading, SpeechBubbleShape.tailCenterX - 56)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        // Keep the sentence on one line when it fits, stepping
                        // the size down once before allowing a wrap.
                        ViewThatFits(in: .horizontal) {
                            phraseText(size: 28).fixedSize()
                            phraseText(size: 23).fixedSize()
                            phraseText(size: 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(step.translation)
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        AudioSpeedControls(
                            text: step.tagalog,
                            analyticsProperties: analyticsProperties,
                            telemetrySessionID: telemetrySessionID,
                            iconOnly: true
                        )
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background {
                        SpeechBubbleShape()
                            .fill(KumustaColors.surface)
                    }
                    .overlay {
                        SpeechBubbleShape()
                            .stroke(KumustaColors.line, lineWidth: 2)
                    }
                    .padding(.top, SpeechBubbleShape.tailHeight)
                }

                if let errorMessage = recorder.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.errorDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if recorder.permissionState == .denied {
                    OpenSettingsButton()
                }

                feedbackContent

                if feedbackState.hasResult {
                    Label(
                        matchedTarget ? L("Nailed it. Tuko heard the full phrase.") : L("Close one. Listen and try again."),
                        systemImage: matchedTarget ? "checkmark.seal.fill" : "arrow.counterclockwise"
                    )
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(matchedTarget ? KumustaColors.success : KumustaColors.errorDeep)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            speakingFooter
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: recorder.isRecording)
        .onChange(of: recorder.isRecording) { wasRecording, isRecording in
            if isRecording {
                dependencies.analytics.track(
                    .lessonRecordingStarted,
                    properties: analyticsProperties,
                    clientSessionID: telemetrySessionID
                )
            } else if wasRecording {
                dependencies.analytics.track(
                    .lessonRecordingCompleted,
                    properties: analyticsProperties.merging([
                        "recording_duration_ms": String(
                            max(0, Int(recorder.recordedDuration * 1_000))
                        )
                    ], uniquingKeysWith: { current, _ in current }),
                    clientSessionID: telemetrySessionID
                )
            }
        }
        .onChange(of: recorder.hasRecording) { _, hasRecording in
            if hasRecording { requestFeedback() }
        }
        .onDisappear {
            feedbackTask?.cancel()
            recorder.cleanup()
        }
    }

    private func phraseText(size: CGFloat) -> some View {
        Text(step.tagalog)
            .scaledFont(size, weight: .bold, design: .rounded)
            .foregroundStyle(KumustaColors.ink)
    }

    private var secondaryContinueTitle: String {
        if feedbackState.isFailed {
            return isFinalRound ? L("Finish without feedback") : L("Continue without feedback")
        }
        if isFinalRound {
            return recorder.hasRecording ? L("Finish without feedback") : L("Can’t speak now")
        }
        return recorder.hasRecording
            ? L("Continue without feedback")
            : L("Can’t speak now")
    }

    private var speakingFooter: some View {
        VStack(spacing: 5) {
            if feedbackState.hasResult && matchedTarget {
                Button {
                    finish()
                } label: {
                    Label(
                        isFinalRound ? L("Finish today’s session") : L("Continue to round %lld", nextRoundNumber),
                        systemImage: "checkmark.circle.fill"
                    )
                }
                .buttonStyle(KumustaSuccessButtonStyle())
            } else if feedbackState.hasResult || feedbackState.isFailed {
                Button(L("Try speaking again"), action: resetAttempt)
                    .buttonStyle(KumustaPrimaryButtonStyle())
            } else if feedbackState.isProcessing {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(L("Checking your Tagalog…"))
                }
                .font(KumustaTypography.bodyStrong)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(KumustaColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if recorder.isFinishingRecording || recorder.hasRecording {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L("Preparing your take…"))
                }
                .font(KumustaTypography.bodyStrong)
                .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                Button(action: toggleRecording) {
                    HStack(spacing: 12) {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .scaledFont(22, weight: .bold)
                        Text(recorder.isRecording ? L("TAP TO FINISH") : L("TAP TO SPEAK"))
                            .scaledFont(18, weight: .heavy, design: .rounded)
                            .scaledTracking(0.8, forPointSize: 18)
                    }
                }
                .buttonStyle(SpeakButtonStyle(isRecording: recorder.isRecording))
                .disabled(isPreparingToRecord || recorder.isFinishingRecording)
                .accessibilityLabel(recorder.isRecording ? L("Stop recording") : L("Start recording"))
                .accessibilityHint(L("Your recording is checked automatically when you finish"))
            }

            if feedbackState.isFailed || (!feedbackState.hasResult
                && !feedbackState.isProcessing
                && !recorder.isRecording
                && !recorder.isFinishingRecording
                && !recorder.hasRecording) {
                Button(action: finish) {
                    Text(secondaryContinueTitle.uppercased())
                        .scaledFont(14, weight: .heavy, design: .rounded)
                        .scaledTracking(0.8, forPointSize: 14)
                        .foregroundStyle(KumustaColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel(secondaryContinueTitle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(KumustaColors.canvas)
        .screenContentWidth()
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.toggleRecording()
            return
        }
        feedbackTask?.cancel()
        feedbackState = .idle
        isPreparingToRecord = true
        Task { @MainActor in
            await dependencies.audioService.stop()
            guard !Task.isCancelled else { return }
            recorder.toggleRecording(streamingTo: dependencies.speechRecognitionService)
            isPreparingToRecord = false
        }
    }

    @ViewBuilder
    private var feedbackContent: some View {
        SpeechFeedbackCard(
            state: feedbackState,
            isCorrect: matchedTarget,
            showsRetryButton: false,
            onRetry: resetAttempt
        )
    }

    private func requestFeedback() {
        guard !feedbackState.isProcessing else { return }
        recorder.stopPlayback()

        let audio: Data
        do {
            audio = try recorder.recordingData()
        } catch {
            recorder.discardCurrentRecording()
            feedbackState = .failed(L("That take isn’t available anymore. Please record it once more."))
            return
        }
        guard let speechService = dependencies.speechRecognitionService else {
            feedbackState = .failed(L("Connect Kumusta to its speech service, then try again."))
            return
        }

        let live = recorder.takeLiveTranscription()
        recorder.discardCurrentRecording()
        feedbackState = .processing
        matchedTarget = false
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            let outcome = await PronunciationFeedbackEngine.evaluate(
                audio: audio,
                live: live,
                targetPhrase: step.tagalog,
                speechService: speechService
            )
            guard !Task.isCancelled, outcome.state != .idle else { return }
            matchedTarget = outcome.matchedTarget
            dependencies.analytics.track(
                .lessonPronunciationEvaluated,
                properties: analyticsProperties.merging([
                    "matched_target": outcome.matchedTarget ? "true" : "false"
                ], uniquingKeysWith: { current, _ in current }),
                clientSessionID: telemetrySessionID
            )
            if outcome.matchedTarget {
                SuccessFeedbackPlayer.shared.play(showsSuccessBorder: true)
            } else if outcome.state.hasResult {
                WrongFeedbackPlayer.shared.play()
            }
            feedbackState = outcome.state
        }
    }

    private func resetAttempt() {
        feedbackTask?.cancel()
        feedbackTask = nil
        feedbackState = .idle
        matchedTarget = false
        recorder.stopPlayback()
        recorder.discardCurrentRecording()
    }

    private func finish() {
        if !feedbackState.hasResult {
            dependencies.analytics.track(
                .lessonSpeakingSkipped,
                properties: analyticsProperties.merging([
                    "skipped_reason": feedbackState.isFailed
                        ? "feedback_unavailable"
                        : recorder.hasRecording ? "feedback_skipped" : "recording_skipped"
                ], uniquingKeysWith: { current, _ in current }),
                clientSessionID: telemetrySessionID
            )
        }
        feedbackTask?.cancel()
        recorder.stopRecording()
        recorder.cleanup()
        onContinue()
    }
}

/// Raised answer card: a flat face with a 2pt border and a darker lip that the
/// card presses down into, like the big learning apps' choice tiles.
struct ChoiceCardButtonStyle: ButtonStyle {
    let face: Color
    let border: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = 4
        let pressed = configuration.isPressed && !reduceMotion
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(shape.fill(face))
            // Opaque base under the (often translucent) face hides the lip.
            .background(shape.fill(KumustaColors.canvas))
            .overlay(shape.stroke(border, lineWidth: 2))
            .background(shape.fill(border).offset(y: pressed ? 0 : depth))
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .contentShape(shape)
            .animation(reduceMotion ? nil : KumustaMotion.press, value: configuration.isPressed)
    }
}

/// Rounded speech bubble whose tail points at the mascot: up when the mascot
/// stands above it, left when the mascot stands beside it.
struct SpeechBubbleShape: Shape {
    enum TailEdge { case top, leading }

    static let tailHeight: CGFloat = 12
    /// Horizontal position of a top tail, measured from the bubble's leading edge.
    static let tailCenterX: CGFloat = 72

    var tailEdge: TailEdge = .top

    func path(in rect: CGRect) -> Path {
        // One continuous outline so the stroke doesn't cross the tail's base.
        let r = min(22, rect.height / 2)
        let x = rect.minX + Self.tailCenterX
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        if tailEdge == .top {
            path.addLine(to: CGPoint(x: x - 12, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: x - 2, y: rect.minY - Self.tailHeight),
                control: CGPoint(x: x - 4, y: rect.minY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: x + 12, y: rect.minY),
                control: CGPoint(x: x + 4, y: rect.minY - 2)
            )
        }
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
        if tailEdge == .leading {
            let y = rect.midY
            path.addLine(to: CGPoint(x: rect.minX, y: y + 12))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX - Self.tailHeight, y: y + 2),
                control: CGPoint(x: rect.minX - 2, y: y + 4)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: y - 12),
                control: CGPoint(x: rect.minX - 2, y: y - 4)
            )
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

struct SpeakButtonStyle: ButtonStyle {
    let isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        KumustaRaisedButtonContent(
            label: configuration.label,
            face: isRecording ? KumustaColors.accentPanel : KumustaColors.accent,
            shadow: KumustaColors.accentShadow,
            foreground: .white,
            faceHeight: 62,
            depth: 6,
            cornerRadius: 20,
            horizontalPadding: 20,
            font: KumustaTypography.bodyStrong,
            border: .clear,
            borderWidth: 0,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

struct SpeakingFrequencyWave: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == 1 ? 1 : 0.82))
                    .frame(width: 8, height: [CGFloat(27), 44, 32][index])
            }
        }
        .frame(width: 40, height: 48)
        .accessibilityHidden(true)
    }
}

struct VoiceMeter: View {
    let level: Double
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(index < activeBars ? KumustaColors.accent : KumustaColors.line)
                    .frame(width: 7, height: barHeight(for: index))
            }
        }
        .frame(height: 48)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: activeBars)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Microphone level"))
        .accessibilityValue(isActive ? L("Recording") : L("Idle"))
    }

    private var activeBars: Int {
        guard isActive else { return 0 }
        return max(1, Int(level * 12))
    }

    private func barHeight(for index: Int) -> CGFloat {
        16 + CGFloat((index * 11) % 30)
    }
}

struct AudioSpeedControls: View {
    private static let logger = Logger(
        subsystem: "com.kumusta.app",
        category: "AudioPlayback"
    )

    let text: String
    let usesSystemSpeech: Bool
    let usesOfflineAudioService: Bool
    let bundledAudioResourceName: String?
    let bundledAudioServiceOverride: BundledAudioService?
    let purpose: AudioPlaybackPurpose
    let analyticsProperties: [String: String]
    let telemetrySessionID: UUID?
    let showsSpeedChoices: Bool
    let singlePlaybackSpeed: PlaybackSpeed?
    let compact: Bool
    let iconOnly: Bool
    let iconSize: CGFloat
    let autoplay: Bool
    let forceAutoplay: Bool
    let onPlaybackCompleted: (() -> Void)?

    @State private var systemSpeechService: SystemTagalogAudioService?
    @State private var bundledAudioService: BundledAudioService?

    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeedRawValue = AudioPreferences.fallbackSpeed.rawValue
    @AppStorage(AudioPreferences.autoplayKey)
    private var autoplayAudio = AudioPreferences.fallbackAutoplay

    @State private var busySpeed: PlaybackSpeed?
    @State private var errorMessage: String?
    @State private var lastRequestedSpeed: PlaybackSpeed?
    @State private var hasAttemptedAutoplay = false

    init(
        text: String,
        usesSystemSpeech: Bool = false,
        usesOfflineAudioService: Bool = false,
        bundledAudioResourceName: String? = nil,
        bundledAudioServiceOverride: BundledAudioService? = nil,
        purpose: AudioPlaybackPurpose = .lesson,
        analyticsProperties: [String: String] = [:],
        telemetrySessionID: UUID? = nil,
        showsSpeedChoices: Bool = true,
        singlePlaybackSpeed: PlaybackSpeed? = nil,
        compact: Bool = false,
        iconOnly: Bool = false,
        iconSize: CGFloat = 56,
        autoplay: Bool = false,
        forceAutoplay: Bool = false,
        onPlaybackCompleted: (() -> Void)? = nil
    ) {
        self.text = text
        self.usesSystemSpeech = usesSystemSpeech
        self.usesOfflineAudioService = usesOfflineAudioService
        self.bundledAudioResourceName = bundledAudioResourceName
        self.bundledAudioServiceOverride = bundledAudioServiceOverride
        self.purpose = purpose
        self.analyticsProperties = analyticsProperties
        self.telemetrySessionID = telemetrySessionID
        self.showsSpeedChoices = showsSpeedChoices
        self.singlePlaybackSpeed = singlePlaybackSpeed
        self.compact = compact
        self.iconOnly = iconOnly
        self.iconSize = iconSize
        _systemSpeechService = State(
            initialValue: usesSystemSpeech ? SystemTagalogAudioService() : nil
        )
        _bundledAudioService = State(
            initialValue: bundledAudioServiceOverride ?? bundledAudioResourceName.map {
                BundledAudioService(resourceName: $0)
            }
        )
        self.autoplay = autoplay
        self.forceAutoplay = forceAutoplay
        self.onPlaybackCompleted = onPlaybackCompleted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if iconOnly {
                HStack(spacing: iconSize * 0.22) {
                    iconButton(speed: preferredSpeed, symbol: "speaker.wave.2.fill", diameter: iconSize)
                    if showsSpeedChoices {
                        let alternate: PlaybackSpeed = preferredSpeed == .slow ? .natural : .slow
                        iconButton(speed: alternate, symbol: alternate.systemImage, diameter: (iconSize * 0.8).rounded())
                    }
                }
            } else if showsSpeedChoices {
                HStack(spacing: 12) {
                    ForEach(orderedSpeeds, id: \.self) { speed in
                        speedButton(
                            title: speed.title,
                            symbol: speed.systemImage,
                            speed: speed
                        )
                    }
                }
            } else {
                speedButton(title: L("Listen"), symbol: "play.fill", speed: singlePlaybackSpeed ?? .natural)
            }

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(errorMessage, systemImage: "speaker.slash.fill")
                        .scaledFont(16, weight: .medium, design: .rounded)
                        .foregroundStyle(KumustaColors.errorDeep)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(L("Try audio again")) {
                        Task { await play(lastRequestedSpeed ?? preferredSpeed, source: "retry") }
                    }
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(minHeight: 44)
                    .disabled(busySpeed != nil)
                }
                .accessibilityElement(children: .contain)
            }
        }
        .task {
            guard autoplay,
                  forceAutoplay || autoplayAudio,
                  !hasAttemptedAutoplay
            else { return }
            hasAttemptedAutoplay = true
            await play(singlePlaybackSpeed ?? preferredSpeed, source: "autoplay")
        }
        .onDisappear {
            if usesOfflineAudioService {
                Task { await dependencies.offlineAudioService.stop() }
            }
            if let systemSpeechService {
                Task { await systemSpeechService.stop() }
            }
            if let bundledAudioService {
                Task { await bundledAudioService.stop() }
            }
        }
    }

    private var preferredSpeed: PlaybackSpeed {
        AudioPreferences.speed(from: defaultSpeedRawValue)
    }

    private var orderedSpeeds: [PlaybackSpeed] {
        AudioPreferences.speeds(startingWith: preferredSpeed)
    }

    private func iconButton(speed: PlaybackSpeed, symbol: String, diameter: CGFloat) -> some View {
        Button {
            Task {
                if busySpeed != nil {
                    await playbackService.stop()
                } else {
                    await play(speed, source: "manual")
                }
            }
        } label: {
            Image(systemName: busySpeed == speed ? "stop.fill" : symbol)
                .scaledFont(diameter * 0.38, weight: .bold)
        }
        .buttonStyle(KumustaRaisedCircleButtonStyle(diameter: diameter))
        .disabled(busySpeed != nil && busySpeed != speed)
        .accessibilityLabel(busySpeed == speed ? L("Stop audio") : L("Play at %@ speed", speed.title.lowercased()))
    }

    private func speedButton(title: String, symbol: String, speed: PlaybackSpeed) -> some View {
        let isPrimarySpeed = !showsSpeedChoices || speed == preferredSpeed
        let buttonTitle = showsSpeedChoices ? title : L("Listen")

        return Button {
            Task {
                if busySpeed != nil {
                    await playbackService.stop()
                } else {
                    await play(speed, source: "manual")
                }
            }
        } label: {
            VStack(spacing: compact ? 2 : 4) {
                if busySpeed == speed {
                    Image(systemName: "stop.fill")
                        .scaledFont(compact ? 16 : 19, weight: .semibold)
                } else {
                    Image(systemName: symbol)
                        .scaledFont(compact ? 16 : 18, weight: .semibold)
                }
                Text(busySpeed == speed ? L("Stop") : buttonTitle)
                    .scaledFont(compact ? 13 : 15, weight: .bold, design: .rounded)
            }
            .foregroundStyle(isPrimarySpeed ? Color.white : KumustaColors.ink)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 62)
            .background(isPrimarySpeed ? KumustaColors.accent : KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 15 : 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 15 : 17, style: .continuous)
                    .stroke(
                        isPrimarySpeed ? KumustaColors.accentDeep : KumustaColors.line,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(busySpeed != nil && busySpeed != speed)
        .accessibilityLabel(
            busySpeed == speed ? L("Stop audio") : (showsSpeedChoices ? L("%@ speed", title) : L("Listen to example"))
        )
    }

    private var playbackService: any AudioService {
        if let bundledAudioService { return bundledAudioService }
        if let systemSpeechService { return systemSpeechService }
        if usesOfflineAudioService { return dependencies.offlineAudioService }
        return dependencies.audioService
    }

    private func play(_ speed: PlaybackSpeed, source: String) async {
        guard busySpeed == nil else { return }
        busySpeed = speed
        lastRequestedSpeed = speed
        errorMessage = nil
        do {
            let service: any AudioService
            if let bundledAudioService {
                await dependencies.audioService.stop()
                service = bundledAudioService
            } else if let systemSpeechService {
                await dependencies.audioService.stop()
                service = systemSpeechService
            } else if usesOfflineAudioService {
                await dependencies.audioService.stop()
                service = dependencies.offlineAudioService
            } else {
                service = dependencies.audioService
            }
            try await service.play(
                text: text,
                speed: speed,
                purpose: purpose
            )
            trackPlayback(speed: speed, source: source, result: "completed")
            onPlaybackCompleted?()
        } catch is CancellationError {
            // Replacing playback, advancing the lesson, starting a recording,
            // or leaving the screen intentionally stops audio. That is normal
            // control flow and must not be presented as a provider outage.
            errorMessage = nil
            trackPlayback(speed: speed, source: source, result: "cancelled")
        } catch {
            Self.logger.error(
                "Lesson audio failed after fallback handling. Error: \(String(reflecting: error), privacy: .public)"
            )
            errorMessage = L("Audio is taking a break. Try again in a moment.")
            trackPlayback(speed: speed, source: source, result: "failed")
        }
        busySpeed = nil
    }

    private func trackPlayback(speed: PlaybackSpeed, source: String, result: String) {
        guard !analyticsProperties.isEmpty else { return }
        dependencies.analytics.track(
            .lessonAudioPlayed,
            properties: analyticsProperties.merging([
                "playback_speed": speed.rawValue,
                "playback_source": source,
                "playback_result": result
            ], uniquingKeysWith: { current, _ in current }),
            clientSessionID: telemetrySessionID
        )
    }
}

struct TodayScreenHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(KumustaTypography.title)
                .foregroundStyle(KumustaColors.ink)
            if let subtitle {
                Text(subtitle)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
