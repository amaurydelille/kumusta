import SwiftUI

struct PracticeHomeView: View {
    private enum PracticeDestination {
        case lesson
        case realtime
    }

    private struct SituationChoice: Identifiable {
        let id: String
        let text: String
        let isCorrect: Bool
    }

    @Environment(AppState.self) private var appState
    @Environment(AppNavigation.self) private var navigation
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lesson: Lesson?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedChoiceID: String?
    @State private var incorrectChoiceID: String?
    @State private var isPlaying = false
    @State private var listenCount = 0
    @State private var audioError: String?
    @State private var isShowingLesson = false
    @State private var shouldEvaluateAchievementsAfterLessonDismiss = false
    @State private var streakBeforeLesson = 0
    @State private var personalizedContent: PersonalizedLearningContent?
    @State private var showStreakCelebration = false
    @State private var celebratedStreak = 0
    @State private var destination: PracticeDestination? = ProcessInfo.processInfo.arguments.contains("livePractice")
        ? .realtime
        : nil
    @State private var presentedChoices: [SituationChoice] = []
    @State private var roadmapLessons: [RoadmapLesson] = []
    @State private var isUsingAuthoritativeRoadmap = false
    @State private var unlockedLevel: ProficiencyLevel?
    @State private var didTrackPracticeOpen = false

    private var choices: [SituationChoice] {
        // Wrong answers use the language of the right one, so the answer
        // never stands out as the only line in a different language.
        let matchesInterface = lesson.map { $0.sourceScenario != nil } ?? true
        let text: (String) -> String = { matchesInterface ? L($0) : $0 }
        return [
            SituationChoice(
                id: "lesson",
                text: lesson?.scenario ?? text("She’s ordering a drink"),
                isCorrect: true
            ),
            SituationChoice(id: "different", text: text("They’re making a friendly complaint"), isCorrect: false),
            SituationChoice(id: "directions", text: text("Someone is asking for directions"), isCorrect: false)
        ]
    }

    private var shuffledChoices: [SituationChoice] {
        presentedChoices.isEmpty ? choices : presentedChoices
    }

    var body: some View {
        Group {
            switch destination {
            case .realtime:
                LivePracticeView(onDismiss: {
                    destination = nil
                    appState.reviewMomentReached()
                })
            case .lesson:
                lessonDestination
            case nil:
                PracticeSessionChooser(
                    streak: activity.currentStreak(),
                    onRealtime: {
                        dependencies.analytics.track(
                            .practiceModeSelected,
                            properties: ["screen_name": "practice", "mode": "realtime"]
                        )
                        destination = .realtime
                    }
                )
            }
        }
        .task(id: "\(appState.profile.level.rawValue)") {
            if !didTrackPracticeOpen {
                didTrackPracticeOpen = true
                dependencies.analytics.track(
                    .practiceOpened,
                    properties: ["screen_name": "practice"]
                )
            }
            loadRoadmap()
            await loadLesson()
            await pollForPreparedLessonIfNeeded()
        }
        .onChange(of: dependencies.learningJourneyStore.preparedLessonID) { _, _ in
            applyPreparedContentIfAvailable()
        }
        .onChange(of: lesson?.id) { _, _ in
            randomizeChoices()
        }
        .onChange(of: navigation.selectedTab) { _, selectedTab in
            guard selectedTab == .practice, destination == nil else { return }
            Task { await loadLesson() }
        }
        .onDisappear { Task { await dependencies.audioService.stop() } }
        .overlay {
            if showStreakCelebration {
                StreakCelebrationView(streak: celebratedStreak) {
                    showStreakCelebration = false
                    appState.reviewMomentReached()
                }
            }
        }
        .alert(item: $unlockedLevel) { level in
            Alert(
                title: Text(L("New roadmap unlocked")),
                message: Text(L("You completed this path. %@ is now your active level.", level.title)),
                dismissButton: .default(Text(L("Start learning")))
            )
        }
    }

    @ViewBuilder
    private var lessonDestination: some View {
        if isLoading {
            loadingScreen
        } else if let errorMessage {
            errorScreen(errorMessage)
        } else if let lesson {
            LessonFlowView(
                lesson: lesson,
                initialStepIndex: initialStepIndex(for: lesson),
                telemetryContext: LessonTelemetryContext(
                    contentKind: personalizedContent == nil ? .authored : .generated,
                    entryPoint: "practice",
                    isReplay: dependencies.learningJourneyStore.isLessonCompleted(
                        lesson,
                        generatedLessonID: personalizedContent?.generatedLessonID
                    )
                ),
                onComplete: completeLesson,
                onDismiss: {
                    evaluateAchievementsAfterLessonDismiss()
                    destination = nil
                    Task { await loadLesson() }
                }
            )
        } else if dependencies.learningJourneyStore.isPreparingNextLesson {
            preparationScreen
        }
    }

    private var loadingScreen: some View {
        ZStack {
            PaperBackground()
            ProgressView()
                .controlSize(.large)
                .tint(KumustaColors.accentDeep)
                .accessibilityLabel(L("Loading your lesson"))
        }
    }

    private func errorScreen(_ message: String) -> some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 16) {
                Text(L("Your lesson couldn’t open"))
                    .font(KumustaTypography.title2)
                    .foregroundStyle(KumustaColors.ink)
                Text(message)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                Button(L("Try again")) { Task { await loadLesson() } }
                    .buttonStyle(KumustaPrimaryButtonStyle())
            }
            .padding(24)
            .screenContentWidth()
        }
    }

    private var preparationScreen: some View {
        ZStack {
            PaperBackground()
            KumustaAmbientShapes()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    KumustaScreenTopBar(
                        centerTitle: L("Next lesson"),
                        streak: activity.currentStreak()
                    )
                    NextLessonPreparationCard(
                        topic: dependencies.learningJourneyStore.requestedTopic,
                        phase: dependencies.learningJourneyStore.preparationPhase,
                        failure: dependencies.learningJourneyStore.preparationFailure,
                        onRetry: { Task { await retryPreparedLesson() } }
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 9)
                .padding(.bottom, 24)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    Button {
                        selectedChoiceID = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .scaledFont(18, weight: .bold)
                            .foregroundStyle(KumustaColors.ink)
                            .frame(width: 38, height: 38)
                            .background(KumustaColors.surface.opacity(0.58))
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(KumustaColors.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Reset answer"))

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(KumustaColors.accent)
                        Text("\(activity.currentStreak())")
                    }
                    .scaledFont(15, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 34)
                    .background(KumustaColors.surfaceMuted.opacity(0.72))
                    .clipShape(Capsule())
                }

                Text(L("COLD LISTEN"))
                    .scaledFont(13, weight: .bold, design: .rounded)
                    .scaledTracking(1.8, forPointSize: 13)
                    .foregroundStyle(KumustaColors.muted)
            }

            HStack(spacing: 8) {
                Capsule().fill(KumustaColors.accent).frame(width: 19, height: 5)
                Capsule().fill(KumustaColors.line).frame(width: 7, height: 5)
                Capsule().fill(KumustaColors.line).frame(width: 7, height: 5)
            }
        }
    }

    private var lessonPrompt: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L("LISTEN · TRUST YOUR INSTINCT"))
                .scaledFont(12, weight: .bold, design: .rounded)
                .scaledTracking(1.4, forPointSize: 12)
                .foregroundStyle(KumustaColors.accentDeep)

            Text(
                dependencies.learningJourneyStore.isPreparingNextLesson
                    ? L("Your next listen is taking shape.")
                    : L("What’s happening?")
            )
                .scaledFont(31, weight: .bold, design: .rounded)
                .scaledTracking(-0.9, forPointSize: 31)
                .foregroundStyle(KumustaColors.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var listeningCard: some View {
        if dependencies.learningJourneyStore.isPreparingNextLesson {
            NextLessonPreparationCard(
                topic: dependencies.learningJourneyStore.requestedTopic,
                phase: dependencies.learningJourneyStore.preparationPhase,
                failure: dependencies.learningJourneyStore.preparationFailure,
                onRetry: { Task { await retryPreparedLesson() } }
            )
        } else if isLoading {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(KumustaColors.surfaceStrong)
                .frame(height: 244)
                .overlay { ProgressView().tint(KumustaColors.accentDeep) }
        } else if let errorMessage {
            VStack(spacing: 14) {
                Text(errorMessage)
                    .scaledFont(17, design: .rounded)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                Button(L("Try again")) { Task { await loadLesson() } }
                    .buttonStyle(KumustaSecondaryButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 244)
            .background(KumustaColors.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        } else {
            VStack(spacing: 14) {
                HStack {
                    Label(L("LISTEN FIRST"), systemImage: "ear.fill")
                        .scaledFont(11, weight: .bold, design: .rounded)
                        .scaledTracking(0.7, forPointSize: 11)

                    Spacer()

                    Text(listenCount == 0 ? L("4 SEC") : L(one: "%lld LISTEN", other: "%lld LISTENS", count: listenCount))
                        .scaledFont(11, weight: .bold, design: .rounded)
                        .scaledTracking(0.7, forPointSize: 11)
                }
                .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 18) {
                    ZStack(alignment: .bottom) {
                        Circle()
                            .fill(KumustaColors.surface.opacity(0.96))
                            .frame(width: 118, height: 118)
                            .overlay {
                                Circle().stroke(.white.opacity(0.45), lineWidth: 3)
                            }

                        BuddyMark(size: 108, mood: isPlaying ? .listening : .happy)
                            .offset(y: 7)

                    }

                    VStack(alignment: .leading, spacing: 11) {
                        Text(isPlaying ? L("Listening…") : listenCount == 0 ? L("Ready when you are") : L("What did you catch?"))
                            .scaledFont(18, weight: .bold, design: .rounded)
                            .foregroundStyle(.white)

                        HStack(alignment: .center, spacing: 3) {
                            ForEach(0..<14, id: \.self) { index in
                                Capsule()
                                    .fill(.white.opacity(isPlaying ? 1 : 0.72))
                                    .frame(width: 3, height: barHeight(index))
                            }
                        }
                        .frame(height: 27)
                        .accessibilityHidden(true)

                        Text(L("NATURAL SPEED"))
                            .scaledFont(10, weight: .bold, design: .rounded)
                            .scaledTracking(0.8, forPointSize: 10)
                            .foregroundStyle(.white.opacity(0.76))
                    }
                }

                Button { playPhrase() } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(KumustaColors.surface)
                            Image(systemName: isPlaying ? "waveform" : "play.fill")
                                .scaledFont(15, weight: .bold)
                                .foregroundStyle(KumustaColors.accentDeep)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                        .frame(width: 34, height: 34)

                        Text(isPlaying ? L("Playing the scene…") : listenCount == 0 ? L("Play the scene") : L("Listen again"))
                            .scaledFont(15, weight: .bold, design: .rounded)

                        Spacer()

                        Image(systemName: "sparkles")
                            .scaledFont(15, weight: .bold)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(KumustaColors.ink)
                    .background(KumustaColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isPlaying || lesson == nil)
                .accessibilityLabel(isPlaying ? L("Playing phrase") : L("Play phrase"))
            }
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 250)
            .background(KumustaColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: KumustaColors.accentShadow.opacity(0.18), radius: 0, y: 5)
        }
    }

    @ViewBuilder
    private var answerChoices: some View {
        if !dependencies.learningJourneyStore.isPreparingNextLesson {
            VStack(alignment: .leading, spacing: 10) {

                ForEach(Array(shuffledChoices.enumerated()), id: \.element.id) { index, choice in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72)) {
                        selectedChoiceID = choice.id
                        incorrectChoiceID = nil
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(String(UnicodeScalar(65 + index)!))
                            .scaledFont(13, weight: .bold, design: .rounded)
                            .foregroundStyle(choiceBadgeForeground(choice))
                            .frame(width: 34, height: 34)
                            .background(choiceBadgeBackground(choice))
                            .clipShape(Circle())

                        Text(choice.text)
                            .scaledFont(15, weight: .semibold, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if selectedChoiceID == choice.id {
                            Image(systemName: "checkmark")
                                .scaledFont(15, weight: .bold)
                                .foregroundStyle(KumustaColors.accentDeep)
                                .transition(.scale.combined(with: .opacity))
                        } else if incorrectChoiceID == choice.id {
                            Image(systemName: "arrow.counterclockwise")
                                .scaledFont(14, weight: .bold)
                                .foregroundStyle(KumustaColors.errorDeep)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(choiceBackground(choice))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(
                                selectedChoiceID == choice.id
                                    ? KumustaColors.accent
                                    : KumustaColors.line,
                                lineWidth: selectedChoiceID == choice.id ? 2 : 1
                            )
                    }
                    .scaleEffect(selectedChoiceID == choice.id ? 1.012 : 1)
                }
                .buttonStyle(.plain)
                }

                if incorrectChoiceID != nil {
                    Label(L("Not that one, replay the scene and follow the context."), systemImage: "ear.badge.waveform")
                        .scaledFont(12, weight: .semibold, design: .rounded)
                        .foregroundStyle(KumustaColors.errorDeep)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        if !dependencies.learningJourneyStore.isPreparingNextLesson {
            Button {
            guard selectedChoice?.isCorrect == true else {
                WrongFeedbackPlayer.shared.play()
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                    incorrectChoiceID = selectedChoiceID
                    selectedChoiceID = nil
                }
                return
            }
            SuccessFeedbackPlayer.shared.play()
            isShowingLesson = true
        } label: {
            HStack {
                Text(L("Lock in my guess"))
                    .scaledFont(15, weight: .bold, design: .rounded)
                Spacer()
                Image(systemName: "arrow.right")
                    .scaledFont(18, weight: .semibold)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(selectedChoiceID == nil ? KumustaColors.muted : .white)
            .background(selectedChoiceID == nil ? KumustaColors.surfaceMuted.opacity(0.75) : KumustaColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
            .buttonStyle(.plain)
            .disabled(selectedChoiceID == nil)
        }
    }

    private var selectedChoice: SituationChoice? {
        shuffledChoices.first { $0.id == selectedChoiceID }
    }

    private func randomizeChoices() {
        var randomized = choices.shuffled()
        if randomized.first?.isCorrect == true,
           let firstIncorrectIndex = randomized.firstIndex(where: { !$0.isCorrect }) {
            randomized.swapAt(0, firstIncorrectIndex)
        }
        presentedChoices = randomized
    }

    private var voiceLabel: String {
        "TUKO · MANILA"
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let heights: [CGFloat] = [10, 17, 12, 20, 14, 23, 16, 11, 21, 15, 23, 13, 18, 11, 20, 15, 22, 12]
        let resting = heights[index % heights.count]
        return isPlaying && !reduceMotion ? min(25, resting + CGFloat(index % 3) * 2) : resting
    }

    private func playPhrase() {
        guard let currentLesson = lesson,
              let phrase = currentLesson.steps.first?.tagalog,
              !isPlaying else { return }
        isPlaying = true
        listenCount += 1
        audioError = nil
        Task {
            do {
                try await dependencies.audioService.play(
                    text: phrase,
                    speed: AudioPreferences().defaultSpeed
                )
            } catch {
                guard !Task.isCancelled else { return }
                audioError = L("The phrase couldn’t play. Try it once more.")
            }
            isPlaying = false
        }
    }

    private func choiceBackground(_ choice: SituationChoice) -> Color {
        if selectedChoiceID == choice.id { return KumustaColors.accentSoft.opacity(0.28) }
        if incorrectChoiceID == choice.id { return KumustaColors.errorSoft.opacity(0.12) }
        return KumustaColors.surface
    }

    private func choiceBadgeBackground(_ choice: SituationChoice) -> Color {
        if selectedChoiceID == choice.id { return KumustaColors.accent }
        if incorrectChoiceID == choice.id { return KumustaColors.errorSoft.opacity(0.55) }
        return KumustaColors.surfaceStrong
    }

    private func choiceBadgeForeground(_ choice: SituationChoice) -> Color {
        selectedChoiceID == choice.id ? .white : KumustaColors.accentDeep
    }

    private func loadLesson() async {
        loadRoadmap()

        if let todayLesson = currentTodayRoadmapLesson {
            personalizedContent = nil
            lesson = todayLesson.lesson
            selectedChoiceID = nil
            incorrectChoiceID = nil
            isLoading = false
            errorMessage = nil
            prewarmAudio(for: todayLesson.lesson)
            return
        }

        if dependencies.learningJourneyStore.isPreparingNextLesson {
            lesson = nil
            personalizedContent = nil
            isLoading = false
            errorMessage = nil
            return
        }
        if let prepared = dependencies.learningJourneyStore.consumePreparedContent() {
            personalizedContent = prepared
            lesson = prepared.lesson
            isLoading = false
            errorMessage = nil
            prewarmAudio(for: prepared.lesson)
            return
        }

        isLoading = true
        errorMessage = nil

        // Resolve both sources before painting the flow so an authored lesson
        // cannot flash over an in-progress personalized lesson.
        let authoredLesson = try? await dependencies.learningRepository.todayLesson(
            level: appState.profile.level,
            dailyMinutes: appState.profile.dailyMinutes
        )
        let generatedContent: PersonalizedLearningContent? = if let service = dependencies.personalizedLearningService {
            try? await service.nextContent(for: appState.profile)
        } else {
            nil
        }

        guard !Task.isCancelled else { return }
        let progressIDs = Set(dependencies.lessonProgressStore.snapshot().map(\.lessonID))
        if let generatedContent, progressIDs.contains(generatedContent.lesson.id) {
            personalizedContent = generatedContent
            lesson = generatedContent.lesson
        } else if let authoredLesson, progressIDs.contains(authoredLesson.id) {
            personalizedContent = nil
            lesson = authoredLesson
        } else if let generatedContent {
            personalizedContent = generatedContent
            lesson = generatedContent.lesson
        } else {
            personalizedContent = nil
            lesson = authoredLesson
        }

        isLoading = false
        guard let lesson else {
            errorMessage = L("We couldn’t prepare your lesson just now.")
            return
        }
        prewarmAudio(for: lesson)
    }

    private func completeLesson(feedback: SessionFeedback) {
        guard let completedLesson = lesson else { return }
        let completedGeneratedLessonID = personalizedContent?.generatedLessonID
        let isRoadmapLesson = roadmapLessons.contains { $0.id == completedLesson.id }
        let isReplay = dependencies.learningJourneyStore.isLessonCompleted(
            completedLesson,
            generatedLessonID: completedGeneratedLessonID
        )
        let currentLevel = appState.profile.level
        let completesCurrentRoadmap = !isReplay
            && isRoadmapLesson
            && isUsingAuthoritativeRoadmap
            && !roadmapLessons.isEmpty
            && roadmapLessons.allSatisfy { roadmapLesson in
                completedLessonIDs.contains(roadmapLesson.id) || roadmapLesson.id == completedLesson.id
            }

        if !isReplay {
            dependencies.learningJourneyStore.recordCompletion(
                lesson: completedLesson,
                generatedLessonID: completedGeneratedLessonID,
                feedback: feedback
            )
            activity.reconcile(with: dependencies.learningJourneyStore.completedLessons)
        }
        if !isRoadmapLesson, dependencies.personalizedLearningService != nil {
            dependencies.learningJourneyStore.beginPreparingNextLesson(
                after: completedLesson.id,
                requestedTopic: feedback.nextLessonTopic,
                requiresFreshGeneration: isReplay
            )
        }

        var updatedProfile = appState.profile
        let previousStreak = updatedProfile.currentStreak
        updatedProfile.currentStreak = activity.currentStreak()
        appState.profile = updatedProfile

        streakBeforeLesson = previousStreak
        shouldEvaluateAchievementsAfterLessonDismiss = true

        Task { @MainActor in
            let promotedLevel: ProficiencyLevel?
            if completesCurrentRoadmap {
                promotedLevel = await appState.advanceRoadmapLevelIfComplete(
                    currentLevel: currentLevel,
                    roadmapLessonIDs: Set(roadmapLessons.map(\.id)),
                    completedLessonIDs: completedLessonIDs
                )
            } else {
                promotedLevel = nil
            }
            if promotedLevel == nil {
                try? await dependencies.profileRepository.saveProfile(appState.profile)
            } else {
                unlockedLevel = promotedLevel
            }
            guard !isRoadmapLesson else { return }
            do {
                if isReplay {
                    try await dependencies.personalizedLearningService?.requestNextLesson(
                        generatedLessonID: completedGeneratedLessonID,
                        feedback: feedback,
                        profile: updatedProfile
                    )
                } else {
                    try await dependencies.personalizedLearningService?.completeLesson(
                        generatedLessonID: completedGeneratedLessonID,
                        feedback: feedback,
                        profile: updatedProfile
                    )
                }
            } catch {
                dependencies.learningJourneyStore.failPendingPreparation(with: error)
                return
            }
            await pollForPreparedLessonIfNeeded()
        }
    }

    private func evaluateAchievementsAfterLessonDismiss() {
        guard shouldEvaluateAchievementsAfterLessonDismiss else {
            appState.reviewMomentReached()
            return
        }
        shouldEvaluateAchievementsAfterLessonDismiss = false

        let newlyUnlocked = appState.evaluateAchievements()
        let currentStreak = appState.profile.currentStreak
        if newlyUnlocked.isEmpty,
           currentStreak > streakBeforeLesson,
           currentStreak > 0,
           !appState.hasPendingAchievements {
            celebratedStreak = currentStreak
            showStreakCelebration = true
        }
        // The streak celebration owns the screen first; its dismissal is the
        // natural break in that case.
        if !showStreakCelebration {
            appState.reviewMomentReached()
        }
    }

    private var activity: LocalLearningActivityStore {
        dependencies.learningActivityStore
    }

    private var completedLessonIDs: Set<UUID> {
        Set(dependencies.learningJourneyStore.completedLessons.map(\.lesson.id))
    }

    private var currentTodayRoadmapLesson: RoadmapLesson? {
        roadmapLessons.first(where: { !completedLessonIDs.contains($0.id) })
            ?? roadmapLessons.first
    }

    private func loadRoadmap() {
        do {
            roadmapLessons = try RoadmapCatalog.load(
                level: appState.profile.level
            )
            isUsingAuthoritativeRoadmap = true
        } catch {
            roadmapLessons = RoadmapCatalog.fallback(
                level: appState.profile.level
            )
            isUsingAuthoritativeRoadmap = false
        }
    }

    private func initialStepIndex(for lesson: Lesson) -> Int {
        if roadmapLessons.contains(where: { $0.id == lesson.id }) {
            return completedLessonIDs.contains(lesson.id)
                ? 0
                : dependencies.lessonProgressStore.resumeStepIndex(for: lesson)
        }
        if dependencies.learningJourneyStore.isLessonCompleted(
            lesson,
            generatedLessonID: personalizedContent?.generatedLessonID
        ) {
            // Reopen completion so LessonFlowView can recover a next-lesson
            // generation request that the learner never submitted.
            return lesson.steps.count
        }
        return dependencies.lessonProgressStore.resumeStepIndex(for: lesson)
    }

    private func dismissLesson() {
        evaluateAchievementsAfterLessonDismiss()
        navigation.selectedTab = .today
    }

    private func pollForPreparedLessonIfNeeded() async {
        guard currentTodayRoadmapLesson == nil else { return }
        guard let service = dependencies.personalizedLearningService else {
            dependencies.learningJourneyStore.abandonPendingPreparation()
            if lesson == nil, !Task.isCancelled {
                await loadAuthoredFallbackLesson()
            }
            return
        }
        await dependencies.learningJourneyStore.pollForPreparedLesson(
            using: service,
            profile: appState.profile
        )
        applyPreparedContentIfAvailable()
        if !dependencies.learningJourneyStore.isPreparingNextLesson,
           dependencies.learningJourneyStore.consumePreparedContent() == nil,
           lesson == nil,
           !Task.isCancelled {
            await loadAuthoredFallbackLesson()
        }
    }

    private func retryPreparedLesson() async {
        guard let service = dependencies.personalizedLearningService else {
            dependencies.learningJourneyStore.abandonPendingPreparation()
            if lesson == nil, !Task.isCancelled {
                await loadAuthoredFallbackLesson()
            }
            return
        }
        await dependencies.learningJourneyStore.retryPreparedLesson(
            using: service,
            profile: appState.profile
        )
        applyPreparedContentIfAvailable()
        if !dependencies.learningJourneyStore.isPreparingNextLesson,
           dependencies.learningJourneyStore.consumePreparedContent() == nil,
           lesson == nil,
           !Task.isCancelled {
            await loadAuthoredFallbackLesson()
        }
    }

    private func applyPreparedContentIfAvailable() {
        guard currentTodayRoadmapLesson == nil else { return }
        guard let prepared = dependencies.learningJourneyStore.consumePreparedContent() else { return }
        personalizedContent = prepared
        lesson = prepared.lesson
        selectedChoiceID = nil
        isLoading = false
        errorMessage = nil
        prewarmAudio(for: prepared.lesson)
    }

    private func loadAuthoredFallbackLesson() async {
        let fallback = try? await dependencies.learningRepository.todayLesson(
            level: appState.profile.level,
            dailyMinutes: appState.profile.dailyMinutes
        )
        guard !Task.isCancelled else { return }
        personalizedContent = nil
        lesson = fallback
        selectedChoiceID = nil
        isLoading = false
        errorMessage = fallback == nil ? L("We couldn’t load a ready lesson just now.") : nil
        if let fallback {
            prewarmAudio(for: fallback)
        }
    }

    private func prewarmAudio(for lesson: Lesson) {
        let audioService = dependencies.audioService
        let speed = AudioPreferences().defaultSpeed
        Task {
            await audioService.prewarm(lesson: lesson, speed: speed)
        }
    }
}

#Preview {
    PracticeHomeView()
        .environment(AppState(dependencies: .preview()))
        .environment(DependencyContainer.preview())
        .environment(AppNavigation())
}
