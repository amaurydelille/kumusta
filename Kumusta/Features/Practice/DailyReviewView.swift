import SwiftUI

/// The daily review: a short run of the phrases the learner is closest to
/// forgetting, each tested in the form that fits how well it is known.
/// Every first answer is saved the moment it is given, so leaving early
/// never loses progress.
struct DailyReviewView: View {
    let entryPoint: String
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeedRawValue = AudioPreferences.fallbackSpeed.rawValue
    @State private var session: DailyReviewSession?
    @State private var telemetrySessionID = UUID()
    @State private var didFinalizeTelemetry = false

    var body: some View {
        ZStack {
            PaperBackground()

            if let session {
                VStack(spacing: 0) {
                    if !session.isFinished {
                        header(session)
                    }
                    content(session)
                        .animation(reduceMotion ? nil : KumustaMotion.screen, value: session.index)
                }
            }
        }
        .interactiveDismissDisabled()
        .task { if session == nil { startSession() } }
        .onDisappear {
            Task { await dependencies.audioService.stop() }
            finalizeTelemetry(completed: false)
            appState.scheduleCloudStateSync()
        }
    }

    // MARK: Layout

    private func header(_ session: DailyReviewSession) -> some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .scaledFont(19, weight: .bold)
                    .foregroundStyle(KumustaColors.muted)
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel(L("Close review"))
            .accessibilityHint(L("Your answers so far are saved"))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(KumustaColors.surfaceStrong)
                    Capsule()
                        .fill(KumustaColors.success)
                        .frame(width: max(16, proxy.size.width * session.progress))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)
                                .padding(.horizontal, 8)
                                .padding(.top, 3)
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: session.progress)
                }
            }
            .frame(height: 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Review progress"))
            .accessibilityValue(L("%lld of %lld phrases", session.clearedCardIDs.count, session.totalCards))

            comboBadge(session.combo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .screenContentWidth()
    }

    /// Duolingo-style streak flame once the learner strings answers together.
    @ViewBuilder
    private func comboBadge(_ combo: Int) -> some View {
        if combo >= 2 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                Text("\(combo)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(combo)))
            }
            .scaledFont(16, weight: .heavy, design: .rounded)
            .foregroundStyle(KumustaColors.caution)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel(L("%lld in a row", combo))
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    @ViewBuilder
    private func content(_ session: DailyReviewSession) -> some View {
        if let task = session.current {
            ReviewExerciseView(
                task: task,
                pool: session.pool,
                onAnswered: { answer in record(answer, for: task, in: session) },
                onContinue: { advance(session) },
                onCantSpeak: { session.disableSpeaking() }
            )
            // A task whose exercise changes (speaking turned off) restarts cleanly.
            .id("\(task.id)-\(task.kind.rawValue)")
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
            )
        } else {
            ReviewCompleteView(
                reviewed: session.answeredCount,
                remembered: session.rememberedCount,
                bestCombo: session.bestCombo,
                stillDue: dependencies.memoryStore.dueCount(),
                nextReview: dependencies.memoryStore.nextReviewDate(),
                onReviewMore: startSession,
                onDone: onDismiss
            )
            .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        }
    }

    // MARK: Session

    private func startSession() {
        let store = dependencies.memoryStore
        let language = AppLanguage.english
        let cards = store.sessionCards().map { $0.displayed(in: language) }
        guard !cards.isEmpty else {
            onDismiss()
            return
        }
        let pool = store.allCards().map { $0.displayed(in: language) } + Self.fillerCards()
        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
            session = DailyReviewSession(
                cards: cards,
                pool: pool,
                canSpeak: dependencies.speechRecognitionService != nil
            )
        }
        telemetrySessionID = UUID()
        didFinalizeTelemetry = false
        dependencies.analytics.track(
            .reviewSessionStarted,
            properties: [
                "screen_name": "daily_review",
                "entry_point": entryPoint,
                "total_cards": String(cards.count),
            ],
            clientSessionID: telemetrySessionID
        )

        let audioService = dependencies.audioService
        let speed = AudioPreferences.speed(from: defaultSpeedRawValue)
        let lessonTexts = cards.filter { $0.source == .lesson }.map(\.tagalog)
        let wordTexts = cards.filter { $0.source == .savedWord }.map(\.tagalog)
        Task {
            await audioService.prewarm(texts: lessonTexts, speed: speed, purpose: .lesson)
            await audioService.prewarm(texts: wordTexts, speed: speed, purpose: .vocabulary)
        }
    }

    private func record(_ answer: ReviewAnswer, for task: ReviewTask, in session: DailyReviewSession) {
        let predictedRecall = dependencies.memoryStore.recall(of: task.card)
        guard let grade = session.submit(answer) else { return }
        dependencies.memoryStore.record(cardID: task.card.id, grade: grade, exercise: task.kind)
        dependencies.analytics.track(
            .reviewRated,
            properties: [
                "screen_name": "daily_review",
                "card_id": String(task.card.fuzzSeed, radix: 16),
                "mode": task.kind.rawValue,
                "value": String(describing: grade),
                "is_correct": answer.correctOnFirstAttempt ? "true" : "false",
                "is_first_attempt": "true",
                "response_ms": String(Int(answer.responseSeconds * 1_000)),
                // Predicted recall before answering; with is_correct this
                // measures how well the scheduler's forecasts hold up.
                "score": String(Int((predictedRecall * 100).rounded())),
                "source": task.card.source.rawValue,
            ],
            clientSessionID: telemetrySessionID
        )
    }

    private func advance(_ session: DailyReviewSession) {
        Task { await dependencies.audioService.stop() }
        session.advance()
        if session.isFinished {
            finalizeTelemetry(completed: true)
            appState.scheduleCloudStateSync()
        }
    }

    private func finalizeTelemetry(completed: Bool) {
        guard let session, !didFinalizeTelemetry, session.answeredCount > 0 || completed else { return }
        didFinalizeTelemetry = true
        dependencies.analytics.track(
            completed ? .reviewSessionCompleted : .reviewSessionAbandoned,
            properties: [
                "screen_name": "daily_review",
                "entry_point": entryPoint,
                "total_cards": String(session.totalCards),
                "cards_answered": String(session.answeredCount),
                "correct_count": String(session.rememberedCount),
            ],
            clientSessionID: telemetrySessionID
        )
    }

    /// Bundled starter vocabulary, used only as wrong answers so a learner
    /// with a handful of phrases still gets four real choices.
    private static func fillerCards() -> [MemoryCard] {
        return SampleContent.vocabulary().map { item in
            MemoryCard(
                id: "filler:" + MemoryCard.key(for: item.tagalog),
                tagalog: item.tagalog,
                translation: item.english,
                hint: nil,
                translationLanguage: nil,
                source: .savedWord,
                sourceID: item.id,
                enrolledAt: .distantPast,
                memory: MemoryState(stability: 1, difficulty: 5, lastReviewedAt: .distantPast, dueAt: .distantFuture, reps: 0, lapses: 0)
            )
        }
    }
}

// MARK: - Completion

private struct ReviewCompleteView: View {
    let reviewed: Int
    let remembered: Int
    let bestCombo: Int
    let stillDue: Int
    let nextReview: Date?
    let onReviewMore: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsTitle = false
    @State private var visibleStatCount = 0
    @State private var confettiBurst = 0

    private var accuracy: Int {
        reviewed == 0 ? 0 : Int((Double(remembered) / Double(reviewed) * 100).rounded())
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    stats
                    nextReviewNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 24)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)

            ConfettiBurstView(burst: confettiBurst)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                Button(L("CONTINUE"), action: onDone)
                    .buttonStyle(KumustaSuccessButtonStyle())
                if stillDue > 0 {
                    Button(L("Review %lld more", min(stillDue, MemoryStore.sessionSize)), action: onReviewMore)
                        .buttonStyle(KumustaSecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(KumustaColors.canvas)
            .screenContentWidth()
        }
        .sensoryFeedback(.success, trigger: confettiBurst)
        .task { await celebrate() }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KumustaColors.success.opacity(0.2))
                    .frame(width: 138, height: 138)
                    .scaleEffect(showsTitle || reduceMotion ? 1 : 0.6)
                BuddyMotionView(motion: accuracy >= 60 ? .streak : .correct, size: 118)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(L("Memory refreshed!"))
                    .scaledFont(30, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.success)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .scaleEffect(showsTitle || reduceMotion ? 1 : 0.7)
            .opacity(showsTitle ? 1 : 0)
        }
    }

    private var message: String {
        switch accuracy {
        case 90...: L("Sharp! Every phrase you got right now stays with you longer.")
        case 60..<90: L("Solid work. The tricky ones will come back sooner so they stick.")
        default: L("Tough set, and that’s how memory gets stronger. You’ll see the tricky ones again soon.")
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            LessonStatCard(title: L("REVIEWED"), symbol: "square.stack.fill", tint: KumustaColors.focus) {
                Text("\(reviewed)")
            }
            .statCardEntrance(isVisible: visibleStatCount > 0, reduceMotion: reduceMotion)
            .accessibilityLabel(L(one: "%lld phrase reviewed", other: "%lld phrases reviewed", count: reviewed))

            LessonStatCard(title: L("REMEMBERED"), symbol: "brain.head.profile", tint: KumustaColors.success) {
                Text("\(accuracy)%")
            }
            .statCardEntrance(isVisible: visibleStatCount > 1, reduceMotion: reduceMotion)
            .accessibilityLabel(L("%lld percent remembered", accuracy))

            LessonStatCard(title: L("BEST COMBO"), symbol: "flame.fill", tint: KumustaColors.caution) {
                Text("\(bestCombo)")
            }
            .statCardEntrance(isVisible: visibleStatCount > 2, reduceMotion: reduceMotion)
            .accessibilityLabel(L("Best combo %lld", bestCombo))
        }
    }

    @ViewBuilder
    private var nextReviewNote: some View {
        if stillDue == 0, let nextReview {
            Label(ReviewSchedulePhrasing.nextReview(nextReview), systemImage: "calendar")
                .font(KumustaTypography.supportingStrong)
                .foregroundStyle(KumustaColors.muted)
                .opacity(visibleStatCount > 2 ? 1 : 0)
        }
    }

    private func celebrate() async {
        LessonFinishedFeedbackPlayer.shared.play()
        confettiBurst += 1
        let spring: Animation? = reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.62)
        withAnimation(spring) { showsTitle = true }
        try? await Task.sleep(for: .milliseconds(450))
        for index in 1...3 {
            withAnimation(spring) { visibleStatCount = index }
            try? await Task.sleep(for: .milliseconds(140))
        }
    }
}

/// Friendly wording for when the next review comes due.
enum ReviewSchedulePhrasing {
    static func nextReview(_ date: Date, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 1
        if days <= 1 {
            return L("Next review tomorrow")
        }
        return L(one: "Next review in %lld day", other: "Next review in %lld days", count: days)
    }
}
