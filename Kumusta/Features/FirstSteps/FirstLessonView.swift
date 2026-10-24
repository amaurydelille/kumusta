import SwiftUI

/// A guided lesson played from a `FirstLessonScript`: hear, notice,
/// recognize, and say a few phrases, then use them in a short conversation
/// with Tuko. Missed answers come back at the end of the lesson, so every
/// learner leaves having answered everything correctly at least once.
///
/// The same view runs the in-app First Steps lesson and the short onboarding
/// lessons shown before the paywall. Before the paywall nothing needs a
/// subscription: fixed lines play from bundled clips and grading spends at
/// most the pre-paywall speech allowance.
struct FirstLessonView: View {
    let script: FirstLessonScript
    /// The learner's first name as spoken in the lesson, if any.
    let learnerName: String?
    /// True during onboarding, before the learner has a subscription.
    let isPrePaywall: Bool
    let onFinish: () -> Void
    let onClose: () -> Void
    /// Reports the onboarding funnel payload of the visible screen, so the
    /// host can attach it to an abandonment event.
    let onScreenChange: (([String: String]) -> Void)?

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var voice: FirstLessonVoice
    @State private var speechBudget: FirstLessonSpeechBudget
    @State private var queue: [QueuedStep] = []
    @State private var position = 0
    @State private var nextUID = 0
    @State private var firstAnswers: [String: Bool] = [:]
    @State private var retriedStepIDs: Set<String> = []
    @State private var combo = 0
    @State private var comboCallout: Int?
    @State private var isShowingExitSheet = false
    @State private var isComplete = false
    @State private var startedAt = Date.now
    @State private var finishedAt: Date?
    @State private var currentScreen: FirstLessonAnalytics.Screen?
    @State private var screenStartedAt = Date.now

    init(
        script: FirstLessonScript,
        learnerName: String?,
        isPrePaywall: Bool = false,
        onFinish: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onScreenChange: (([String: String]) -> Void)? = nil
    ) {
        self.script = script
        self.learnerName = learnerName
        self.isPrePaywall = isPrePaywall
        self.onFinish = onFinish
        self.onClose = onClose
        self.onScreenChange = onScreenChange
        _voice = State(initialValue: FirstLessonVoice(
            usesPaidVoice: !isPrePaywall,
            learnerName: learnerName
        ))
        _speechBudget = State(initialValue: FirstLessonSpeechBudget(
            limit: isPrePaywall ? FirstLessonSpeechBudget.prePaywallLimit : nil
        ))
    }

    private struct QueuedStep: Identifiable {
        let uid: Int
        let step: FirstLessonScript.Step
        var id: Int { uid }
    }

    private var isOnboarding: Bool { isPrePaywall }

    private var progressFraction: CGFloat {
        guard !queue.isEmpty else { return 0 }
        if isComplete { return 1 }
        return CGFloat(position) / CGFloat(queue.count)
    }

    var body: some View {
        ZStack {
            PaperBackground()

            if isComplete {
                FirstLessonCompleteView(
                    completion: script.completion,
                    accuracy: accuracy,
                    elapsed: (finishedAt ?? .now).timeIntervalSince(startedAt),
                    voice: voice,
                    onContinue: {
                        completeCurrentScreen()
                        onFinish()
                    }
                )
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    header

                    if queue.indices.contains(position) {
                        stepView(queue[position])
                            .id(queue[position].uid)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    )
                            )
                    } else {
                        Spacer()
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: position)
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: isComplete)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingExitSheet) {
            FirstLessonExitSheet(
                isOnboarding: isOnboarding,
                minutes: script.estimatedMinutes,
                onKeepGoing: { isShowingExitSheet = false },
                onQuit: {
                    isShowingExitSheet = false
                    track(.featureAction, ["step": "exited", "step_index": String(position)])
                    Task { await voice.stop() }
                    onClose()
                }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .onAppear(perform: prepare)
        .onDisappear {
            Task { await voice.stop() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                isShowingExitSheet = true
            } label: {
                Image(systemName: "xmark")
                    .scaledFont(19, weight: .bold)
                    .foregroundStyle(KumustaColors.muted)
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel(L("Close lesson"))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(KumustaColors.surfaceStrong)
                    Capsule()
                        .fill(combo >= 3 ? KumustaColors.success : KumustaColors.caution)
                        .frame(width: max(16, proxy.size.width * progressFraction))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)
                                .padding(.horizontal, 8)
                                .padding(.top, 3)
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progressFraction)
                        .animation(.easeOut(duration: 0.3), value: combo >= 3)
                }
            }
            .frame(height: 16)
            .overlay(alignment: .top) {
                if let comboCallout {
                    Text(L("%lld IN A ROW!", comboCallout))
                        .scaledFont(13, weight: .heavy, design: .rounded)
                        .scaledTracking(0.8, forPointSize: 13)
                        .foregroundStyle(KumustaColors.success)
                        .fixedSize()
                        .offset(y: -20)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.6))
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Lesson progress"))
            .accessibilityValue(L("%lld percent", Int(progressFraction * 100)))

            ComboFlame(count: combo)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .screenContentWidth()
    }

    // MARK: Steps

    @ViewBuilder
    private func stepView(_ queued: QueuedStep) -> some View {
        switch queued.step {
        case .intro:
            FirstLessonIntroStep(intro: script.intro, voice: voice, onContinue: advance)
        case let .teach(_, teach):
            FirstLessonTeachStep(teach: teach, voice: voice, onContinue: advance)
        case let .listenPick(_, pick):
            FirstLessonListenPickStep(
                pick: pick,
                voice: voice,
                onAnswer: { record($0, for: queued.step) },
                onContinue: advance
            )
        case let .newPhrase(_, phrase):
            FirstLessonNewPhraseStep(phrase: phrase, voice: voice, onContinue: advance)
        case let .speak(id, speak):
            FirstLessonSpeakStep(
                speak: speak,
                voice: voice,
                budget: speechBudget,
                isOnboarding: isOnboarding,
                analyticsProperties: stepProperties(id),
                onContinue: advance
            )
        case let .meaningPick(_, pick):
            FirstLessonMeaningPickStep(
                pick: pick,
                voice: voice,
                onAnswer: { record($0, for: queued.step) },
                onContinue: advance
            )
        case let .naturalPick(_, pick):
            FirstLessonNaturalPickStep(
                pick: pick,
                voice: voice,
                onAnswer: { record($0, for: queued.step) },
                onContinue: advance
            )
        case let .build(_, build):
            FirstLessonBuildStep(
                build: build,
                voice: voice,
                onAnswer: { record($0, for: queued.step) },
                onContinue: advance
            )
        case let .conversation(id, conversation):
            FirstLessonConversationStep(
                conversation: conversation,
                voice: voice,
                budget: speechBudget,
                isOnboarding: isOnboarding,
                analyticsProperties: stepProperties(id),
                onContinue: advance
            )
        }
    }

    // MARK: Flow

    private var accuracy: Int {
        guard !firstAnswers.isEmpty else { return 100 }
        let correct = firstAnswers.values.filter { $0 }.count
        return Int((Double(correct) / Double(firstAnswers.count) * 100).rounded())
    }

    private func prepare() {
        guard queue.isEmpty else { return }
        voice.configure(dependencies)
        let steps = script.steps
        queue = steps.enumerated().map { QueuedStep(uid: $0.offset, step: $0.element) }
        nextUID = steps.count
        startedAt = .now
        #if DEBUG
        // Simulator shortcut for reviewing one step: `-FirstLessonStep 5`.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-FirstLessonStep"),
           arguments.indices.contains(flag + 1),
           let index = Int(arguments[flag + 1]) {
            if index >= steps.count {
                isComplete = true
            } else {
                position = max(0, index)
            }
        }
        #endif
        track(.screenViewed, ["screen_name": "first_lesson"])
        trackStepViewed()
        voice.prewarm(script.audioTexts)
    }

    private func record(_ isCorrect: Bool, for step: FirstLessonScript.Step) {
        if firstAnswers[step.id] == nil {
            firstAnswers[step.id] = isCorrect
        }
        track(.featureAction, [
            "step": "answered",
            "step_id": step.id,
            "is_correct": isCorrect ? "true" : "false"
        ])

        if isCorrect {
            combo += 1
            if [3, 5, 8].contains(combo) {
                showComboCallout(combo)
            }
        } else {
            combo = 0
            // One more try at the end of the lesson, Duolingo-style.
            if !retriedStepIDs.contains(step.id) {
                retriedStepIDs.insert(step.id)
                queue.append(QueuedStep(uid: nextUID, step: step))
                nextUID += 1
            }
        }
    }

    private func showComboCallout(_ value: Int) {
        withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) {
            comboCallout = value
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard comboCallout == value else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                comboCallout = nil
            }
        }
    }

    private func advance() {
        Task { await voice.stop() }
        completeCurrentScreen()
        if position + 1 >= queue.count {
            finish()
        } else {
            position += 1
            trackStepViewed()
        }
    }

    private func finish() {
        finishedAt = .now
        saveWords()
        track(.featureAction, [
            "step": "completed",
            "score": String(accuracy),
            "active_seconds": String(Int((finishedAt ?? .now).timeIntervalSince(startedAt)))
        ])
        isComplete = true
        enterScreen(FirstLessonAnalytics.completionScreen(in: script))
    }

    private func saveWords() {
        let store = dependencies.savedLessonWordStore
        for word in script.completion.words {
            store.save(
                gloss: LessonWordGloss(id: UUID(), token: word.tagalog, translation: word.meaning),
                sentence: word.tagalog,
                sentenceTranslation: word.meaning,
                lessonID: script.sourceID,
                translationLanguage: script.language
            )
        }
    }

    private func stepProperties(_ stepID: String) -> [String: String] {
        baseProperties.merging(["step_id": stepID], uniquingKeysWith: { _, new in new })
    }

    private var baseProperties: [String: String] {
        FirstLessonAnalytics.base(script: script, isPrePaywall: isPrePaywall)
    }

    private func trackStepViewed() {
        guard queue.indices.contains(position) else { return }
        let queued = queue[position]
        let step = queued.step
        track(.featureAction, [
            "step": "viewed",
            "step_id": step.id,
            "step_kind": step.analyticsKind,
            "step_index": String(position)
        ])
        enterScreen(FirstLessonAnalytics.screen(
            for: step,
            in: script,
            isReplay: queued.uid >= script.steps.count
        ))
    }

    /// Before the paywall every lesson screen is its own onboarding funnel
    /// step, so drop-off can be read screen by screen up to the paywall.
    private func enterScreen(_ screen: FirstLessonAnalytics.Screen) {
        currentScreen = screen
        screenStartedAt = .now
        guard isPrePaywall else { return }
        let properties = FirstLessonAnalytics.funnel(screen, script: script)
        dependencies.analytics.track(.onboardingStepViewed, properties: properties)
        onScreenChange?(properties)
    }

    private func completeCurrentScreen() {
        guard isPrePaywall, let screen = currentScreen else { return }
        currentScreen = nil
        let seconds = max(0, Int(Date.now.timeIntervalSince(screenStartedAt)))
        dependencies.analytics.track(
            .onboardingStepCompleted,
            properties: FirstLessonAnalytics.funnel(screen, script: script)
                .merging(["active_seconds": String(seconds)], uniquingKeysWith: { _, new in new })
        )
    }

    private func track(_ event: AnalyticsEvent, _ properties: [String: String]) {
        dependencies.analytics.track(
            event,
            properties: baseProperties.merging(properties, uniquingKeysWith: { _, new in new })
        )
    }
}

// MARK: - Analytics

/// Analytics payloads for the guided lessons. Every key must be in the
/// first-party allowlist (`SupabaseSignedInRepository.validateAnalyticsProperties`
/// and the database validator); one unknown key drops the whole event.
enum FirstLessonAnalytics {
    static let onboardingSource = "onboarding_first_lesson_v2"
    /// Lesson screens follow the `first_lesson` container step (position 7)
    /// in the onboarding funnel, then onboarding completes and the paywall
    /// opens.
    static let firstScreenPosition = 8

    struct Screen: Equatable {
        let id: String
        let kind: String
        /// Index in the lesson script, so a retried question keeps its place.
        let index: Int
        let isReplay: Bool
    }

    static func base(script: FirstLessonScript, isPrePaywall: Bool) -> [String: String] {
        [
            "screen_name": isPrePaywall ? "onboarding_first_lesson" : "first_lesson",
            "lesson_id": script.id,
            "mode": script.mode.rawValue,
            "level": script.level.rawValue,
            "entry_point": isPrePaywall ? "onboarding" : "first_steps"
        ]
    }

    static func screen(for step: FirstLessonScript.Step, in script: FirstLessonScript, isReplay: Bool) -> Screen {
        Screen(
            id: step.id,
            kind: step.analyticsKind,
            index: script.steps.firstIndex { $0.id == step.id } ?? 0,
            isReplay: isReplay
        )
    }

    static func completionScreen(in script: FirstLessonScript) -> Screen {
        Screen(id: "completion", kind: "completion", index: script.steps.count, isReplay: false)
    }

    /// The `onboarding_step_viewed` / `onboarding_step_completed` payload for
    /// one lesson screen.
    static func funnel(_ screen: Screen, script: FirstLessonScript) -> [String: String] {
        base(script: script, isPrePaywall: true).merging([
            "source": onboardingSource,
            "step": "first_lesson_\(screen.kind)",
            "step_id": screen.id,
            "step_kind": screen.kind,
            "step_index": String(screen.index),
            "position": String(firstScreenPosition + screen.index),
            "is_replay": screen.isReplay ? "true" : "false"
        ], uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Voice

/// Speaks lesson lines from the best available source: a bundled clip, then
/// (in the app) the regular lesson voice. Before the paywall, the learner's
/// name line uses the server's fixed onboarding template and anything else
/// falls back to Apple's Tagalog voice, so no paid generation is needed.
@MainActor
final class FirstLessonVoice {
    let usesPaidVoice: Bool
    let learnerName: String?

    private weak var dependencies: DependencyContainer?
    /// Only set while a line is actually playing. Stopping a player
    /// deactivates the shared audio session, so an idle voice must not do it:
    /// that would cut off a recording that is just starting.
    private var current: (any AudioService)?
    private var playToken = 0
    private var isPlayingTemplate = false
    private let systemVoice = SystemTagalogAudioService()

    init(usesPaidVoice: Bool, learnerName: String?) {
        self.usesPaidVoice = usesPaidVoice
        self.learnerName = learnerName
    }

    func configure(_ dependencies: DependencyContainer) {
        self.dependencies = dependencies
    }

    /// Plays one line and returns when it finishes or is stopped.
    func play(_ text: String, speed: PlaybackSpeed = .natural) async throws {
        await stop()
        playToken &+= 1
        let token = playToken
        defer {
            if playToken == token { current = nil }
        }
        if let url = FirstLessonScript.bundledAudioURL(for: text) {
            let service = BundledAudioService(url: url)
            current = service
            try await service.play(text: text, speed: speed, purpose: .lesson)
            return
        }
        guard let dependencies else { return }
        if usesPaidVoice {
            current = dependencies.audioService
            try await dependencies.audioService.play(text: text, speed: speed, purpose: .lesson)
            return
        }
        if isNameLine(text), let learnerName {
            isPlayingTemplate = true
            defer { isPlayingTemplate = false }
            try await dependencies.onboardingConversationAudio.play(
                line: .replyName,
                text: text,
                name: learnerName
            )
            return
        }
        current = systemVoice
        try await systemVoice.play(text: text, speed: speed, purpose: .lesson)
    }

    func stop() async {
        playToken &+= 1
        let service = current
        current = nil
        await service?.stop()
        if isPlayingTemplate, let dependencies {
            await dependencies.onboardingConversationAudio.stop()
        }
    }

    /// Warms whatever is not bundled: the name line before the paywall, or
    /// any missing clip through the lesson voice in the app.
    func prewarm(_ texts: [String]) {
        guard let dependencies else { return }
        let missing = texts.filter { FirstLessonScript.bundledAudioURL(for: $0) == nil }
        guard !missing.isEmpty else { return }
        if usesPaidVoice {
            let audioService = dependencies.audioService
            Task { await audioService.prewarm(texts: missing, speed: .natural) }
        } else if missing.contains(where: isNameLine), let learnerName {
            dependencies.onboardingConversationAudio.prefetch(lines: [.replyName], name: learnerName)
        }
    }

    /// The only personalized line the pre-paywall voice server accepts.
    private func isNameLine(_ text: String) -> Bool {
        guard let learnerName else { return false }
        return FirstLessonScript.normalizedAudioText(text) == "Ako si \(learnerName)."
    }
}

// MARK: - Grading

enum FirstLessonGrading {
    /// True when any accepted wording was heard.
    static func matches(transcript: String, targets: [String]) -> Bool {
        targets.contains { target in
            PronunciationReview(target: target, transcript: transcript).isMatch
        }
    }
}

/// The pre-paywall speech allowance is three checked takes a day. Takes past
/// the budget are still recorded and celebrated, just not sent for grading.
@MainActor
@Observable
final class FirstLessonSpeechBudget {
    nonisolated static let prePaywallLimit = 3

    private(set) var remaining: Int?

    init(limit: Int?) {
        remaining = limit
    }

    var canGrade: Bool { remaining.map { $0 > 0 } ?? true }

    func spend() {
        if let remaining { self.remaining = max(0, remaining - 1) }
    }

    func exhaust() {
        if remaining != nil { remaining = 0 }
    }
}

// MARK: - Shared pieces

/// Header flame that counts consecutive correct answers.
private struct ComboFlame: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .scaledFont(17, weight: .bold)
            Text("\(count)")
                .scaledFont(16, weight: .heavy, design: .rounded)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        }
        .foregroundStyle(count > 0 ? KumustaColors.caution : KumustaColors.line)
        .frame(minWidth: 40)
        .scaleEffect(count > 0 && !reduceMotion ? 1.0 : 0.94)
        .animation(reduceMotion ? nil : KumustaMotion.celebrate, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L(one: "%lld correct answer in a row", other: "%lld correct answers in a row", count: count))
    }
}

/// Large step title shared by every step.
private struct StepTitle: View {
    let text: String
    var eyebrow: String?
    var eyebrowSymbol: String = "sparkles"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow, !eyebrow.isEmpty {
                Label(eyebrow, systemImage: eyebrowSymbol)
                    .scaledFont(13, weight: .heavy, design: .rounded)
                    .scaledTracking(0.9, forPointSize: 13)
                    .foregroundStyle(KumustaColors.focus)
            }
            Text(text)
                .scaledFont(26, weight: .heavy, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tuko next to a speech bubble holding the step's content.
private struct BuddySays<Content: View>: View {
    let motion: BuddyMotion
    var mascotSize: CGFloat = 104
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            BuddyMotionView(motion: motion, size: mascotSize)
                .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
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
}

/// Round raised play buttons (natural and slow) driven by the lesson voice.
private struct VoiceButtons: View {
    let text: String
    let voice: FirstLessonVoice
    var size: CGFloat = 56
    var showsSlow = true
    var autoplay = false

    @State private var playing: PlaybackSpeed?
    @State private var didAutoplay = false

    var body: some View {
        HStack(spacing: size * 0.22) {
            button(.natural, symbol: "speaker.wave.2.fill", diameter: size)
            if showsSlow {
                button(.slow, symbol: PlaybackSpeed.slow.systemImage, diameter: (size * 0.8).rounded())
            }
        }
        .task {
            guard autoplay, !didAutoplay else { return }
            didAutoplay = true
            await play(.natural)
        }
    }

    private func button(_ speed: PlaybackSpeed, symbol: String, diameter: CGFloat) -> some View {
        Button {
            Task {
                if playing == speed {
                    await voice.stop()
                    playing = nil
                } else {
                    await play(speed)
                }
            }
        } label: {
            Image(systemName: playing == speed ? "stop.fill" : symbol)
                .scaledFont(diameter * 0.38, weight: .bold)
        }
        .buttonStyle(KumustaRaisedCircleButtonStyle(diameter: diameter))
        .accessibilityLabel(playing == speed ? L("Stop audio") : (speed == .slow ? L("Play slowly") : L("Play")))
    }

    private func play(_ speed: PlaybackSpeed) async {
        playing = speed
        try? await voice.play(text, speed: speed)
        if playing == speed { playing = nil }
    }
}

/// Small pitch drawing that shows a tone's melody.
struct ToneContourShape: Shape {
    let contour: FirstLessonScript.ToneContour

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        switch contour {
        case .level:
            path.move(to: point(0, 0.32))
            path.addLine(to: point(1, 0.32))
        case .falling:
            path.move(to: point(0, 0.38))
            path.addQuadCurve(to: point(1, 0.86), control: point(0.5, 0.55))
        case .rising:
            path.move(to: point(0, 0.62))
            path.addQuadCurve(to: point(1, 0.12), control: point(0.55, 0.62))
        case .dipping:
            path.move(to: point(0, 0.45))
            path.addQuadCurve(to: point(1, 0.4), control: point(0.5, 0.86))
        case .heavy:
            // Nặng: a short low glide, then an abrupt drop that stops dead,
            // like the dot sitting under the vowel.
            path.move(to: point(0, 0.3))
            path.addQuadCurve(to: point(0.55, 0.42), control: point(0.3, 0.32))
            path.addLine(to: point(0.6, 1.0))
        }
        return path
    }
}

private struct ToneContourView: View {
    let contour: FirstLessonScript.ToneContour
    let tint: Color

    var body: some View {
        ToneContourShape(contour: contour)
            .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            .padding(4)
            .background {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(KumustaColors.line.opacity(0.45)).frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 6)
            }
            .accessibilityHidden(true)
    }
}

/// Plays one phrase; failures stay silent because a replay button is always
/// on screen.
@MainActor
private func playPhrase(_ text: String, voice: FirstLessonVoice) {
    Task { try? await voice.play(text) }
}

/// The bottom bar that turns into the green, red, or neutral result sheet.
private struct CheckFooter: View {
    enum Result: Equatable {
        case correct(headline: String, detail: String?)
        case incorrect(headline: String, solution: String?)
        /// A take that was recorded but not graded.
        case neutral(headline: String, detail: String?)
    }

    let result: Result?
    var checkTitle = L("CHECK")
    let canCheck: Bool
    let onCheck: () -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let result {
                banner(result)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else {
                Button(checkTitle, action: onCheck)
                    .buttonStyle(KumustaSuccessButtonStyle())
                    .disabled(!canCheck)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .screenContentWidth()
                    .frame(maxWidth: .infinity)
                    .background(FooterBackdrop())
            }
        }
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: result)
    }

    private func banner(_ result: Result) -> some View {
        let isPositive: Bool
        let symbol: String
        let tint: Color
        let deep: Color
        let headline: String
        let detailLabel: String?
        let detail: String?
        switch result {
        case let .correct(title, text):
            isPositive = true; symbol = "checkmark"; tint = KumustaColors.success; deep = KumustaColors.success
            headline = title; detailLabel = nil; detail = text
        case let .incorrect(title, solution):
            isPositive = false; symbol = "xmark"; tint = KumustaColors.accent; deep = KumustaColors.accentDeep
            headline = title; detailLabel = solution == nil ? nil : L("Correct answer:"); detail = solution
        case let .neutral(title, text):
            isPositive = true; symbol = "mic.fill"; tint = KumustaColors.focus; deep = KumustaColors.focus
            headline = title; detailLabel = nil; detail = text
        }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol)
                    .scaledFont(20, weight: .black)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(KumustaColors.canvas))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .scaledFont(22, weight: .heavy, design: .rounded)
                        .foregroundStyle(deep)
                    if let detailLabel {
                        Text(detailLabel)
                            .scaledFont(15, weight: .bold, design: .rounded)
                            .foregroundStyle(deep)
                    }
                    if let detail {
                        Text(detail)
                            .font(KumustaTypography.body)
                            .foregroundStyle(deep.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            Button(isPositive ? L("CONTINUE") : L("GOT IT"), action: onContinue)
                .buttonStyle(isPositive ? AnyButtonStyle(KumustaSuccessButtonStyle()) : AnyButtonStyle(KumustaPrimaryButtonStyle()))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .screenContentWidth()
        .frame(maxWidth: .infinity)
        .background {
            tint.opacity(0.18)
                .background(KumustaColors.canvas)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Type-erased button style so the banner can switch its button color.
private struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

private enum Praise {
    static var lines: [String] { [L("Nice!"), L("Great job!"), L("Excellent!"), L("Perfect!"), L("You got it!"), L("Amazing!")] }
    static func random() -> String { lines.randomElement() ?? L("Nice!") }
}

/// Solid canvas behind a footer with a soft top fade, so content scrolling
/// underneath never shows through the buttons.
private struct FooterBackdrop: View {
    var body: some View {
        KumustaColors.canvas
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [KumustaColors.canvas.opacity(0), KumustaColors.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
                .offset(y: -18)
            }
            .ignoresSafeArea(edges: .bottom)
    }
}

/// A plain footer with one big button, for steps that only teach.
private struct ContinueFooter: View {
    var title = L("CONTINUE")
    var isEnabled = true
    var hint: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let hint, !isEnabled {
                Text(hint)
                    .font(KumustaTypography.caption)
                    .foregroundStyle(KumustaColors.muted)
                    .transition(.opacity)
            }
            Button(title, action: action)
                .buttonStyle(KumustaSuccessButtonStyle())
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .screenContentWidth()
        .frame(maxWidth: .infinity)
        .background(FooterBackdrop())
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

private struct ShakeEffect: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: reduceMotion ? 0 : trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-10, duration: 0.07)
                CubicKeyframe(10, duration: 0.08)
                CubicKeyframe(-6, duration: 0.08)
                CubicKeyframe(4, duration: 0.07)
                CubicKeyframe(0, duration: 0.07)
            }
        }
    }
}

private extension CheckFooter.Result? {
    var mascotMotion: BuddyMotion {
        switch self {
        case .none: .curious
        case .correct?, .neutral?: .correct
        case .incorrect?: .mistake
        }
    }
}

private extension View {
    func resultHaptics(_ result: CheckFooter.Result?) -> some View {
        sensoryFeedback(trigger: result) { _, new in
            switch new {
            case .none, .neutral?: nil
            case .correct?: .success
            case .incorrect?: .error
            }
        }
    }
}

// MARK: - Intro

private struct FirstLessonIntroStep: View {
    let intro: FirstLessonScript.Intro
    let voice: FirstLessonVoice
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleGoals = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 0) {
                    BuddyMotionView(motion: .welcomeWave, size: 136)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text(intro.hook)
                            .scaledFont(30, weight: .heavy, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(intro.hookTranslation)
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                            .multilineTextAlignment(.center)
                        VoiceButtons(text: intro.hook, voice: voice, size: 52, showsSlow: false, autoplay: true)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 16)
                    .background {
                        SpeechBubbleShape(tailEdge: .top)
                            .fill(KumustaColors.surface)
                    }
                    .overlay {
                        SpeechBubbleShape(tailEdge: .top)
                            .stroke(KumustaColors.line, lineWidth: 2)
                    }
                    .padding(.top, SpeechBubbleShape.tailHeight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(intro.title)
                        .scaledFont(26, weight: .heavy, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(intro.subtitle)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                }

                VStack(spacing: 10) {
                    ForEach(Array(intro.goals.enumerated()), id: \.element.id) { index, goal in
                        HStack(spacing: 14) {
                            Text("\(index + 1)")
                                .scaledFont(16, weight: .heavy, design: .rounded)
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(KumustaColors.focusFill))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.tagalog)
                                    .scaledFont(19, weight: .bold, design: .rounded)
                                    .foregroundStyle(KumustaColors.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(goal.meaning)
                                    .font(KumustaTypography.supporting)
                                    .foregroundStyle(KumustaColors.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "lock.fill")
                                .foregroundStyle(KumustaColors.line)
                                .accessibilityHidden(true)
                        }
                        .padding(14)
                        .background(KumustaColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(KumustaColors.line, lineWidth: 1.5)
                        }
                        .opacity(index < visibleGoals ? 1 : 0)
                        .offset(y: index < visibleGoals || reduceMotion ? 0 : 14)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ContinueFooter(title: L("LET’S GO"), action: onContinue)
        }
        .task {
            guard !intro.goals.isEmpty else { return }
            for index in 1...intro.goals.count {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 260))
                withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) {
                    visibleGoals = index
                }
            }
        }
    }
}

// MARK: - Teach

private struct FirstLessonTeachStep: View {
    let teach: FirstLessonScript.Teach
    let voice: FirstLessonVoice
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tapped: Set<String> = []
    @State private var bounce: String?

    private var hasHeardAll: Bool {
        tapped.count >= teach.samples.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StepTitle(text: teach.title, eyebrow: teach.eyebrow, eyebrowSymbol: teach.symbol)

                Text(teach.body)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.ink)
                    .fixedSize(horizontal: false, vertical: true)

                // Equal-height cards even when one meaning wraps.
                HStack(alignment: .top, spacing: 12) {
                    ForEach(teach.samples) { sample in
                        sampleCard(sample)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                if let footnote = teach.footnote {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .scaledFont(18, weight: .bold)
                            .foregroundStyle(KumustaColors.caution)
                            .accessibilityHidden(true)
                        Text(footnote)
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KumustaColors.caution.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ContinueFooter(
                title: L("GOT IT"),
                isEnabled: hasHeardAll,
                hint: L("Tap each word to hear it"),
                action: onContinue
            )
        }
        .sensoryFeedback(.selection, trigger: tapped.count)
    }

    private func sampleCard(_ sample: FirstLessonScript.ToneSample) -> some View {
        let heard = tapped.contains(sample.id)
        return Button {
            tapped.insert(sample.id)
            playPhrase(sample.text, voice: voice)
            withAnimation(reduceMotion ? nil : KumustaMotion.press) { bounce = sample.id }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) { bounce = nil }
            }
        } label: {
            VStack(spacing: 10) {
                ToneContourView(contour: sample.contour, tint: heard ? KumustaColors.focus : KumustaColors.muted)
                    .frame(height: 44)
                Text(sample.text)
                    .scaledFont(34, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(sample.meaning)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: heard ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .scaledFont(17, weight: .bold)
                    .foregroundStyle(KumustaColors.focus)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ChoiceCardButtonStyle(
            face: heard ? KumustaColors.focus.opacity(0.1) : KumustaColors.surface,
            border: heard ? KumustaColors.focus : KumustaColors.line
        ))
        .scaleEffect(bounce == sample.id && !reduceMotion ? 0.94 : 1)
        .accessibilityLabel("\(sample.text), \(sample.meaning)")
        .accessibilityHint(L("Plays the word"))
    }
}

// MARK: - Listen and pick

private struct FirstLessonListenPickStep: View {
    let pick: FirstLessonScript.ListenPick
    let voice: FirstLessonVoice
    let onAnswer: (Bool) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: String?
    @State private var result: CheckFooter.Result?
    @State private var shake = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                StepTitle(text: pick.prompt)

                BuddySays(motion: result.mascotMotion) {
                    VoiceButtons(text: pick.answer, voice: voice, size: 72, autoplay: true)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 12) {
                    ForEach(pick.options) { option in
                        optionCard(option)
                    }
                }
                .sensoryFeedback(.selection, trigger: selection)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CheckFooter(
                result: result,
                canCheck: selection != nil,
                onCheck: check,
                onContinue: onContinue
            )
        }
        .resultHaptics(result)
    }

    private func optionCard(_ option: FirstLessonScript.ToneSample) -> some View {
        let isSelected = selection == option.id
        let isRevealedCorrect = result != nil && option.text == pick.answer
        let isWrongPick = result != nil && isSelected && option.text != pick.answer
        let tint: Color = isRevealedCorrect ? KumustaColors.success
            : isWrongPick ? KumustaColors.accent
            : isSelected ? KumustaColors.focus
            : KumustaColors.line

        return Button {
            withAnimation(reduceMotion ? nil : KumustaMotion.press) { selection = option.id }
        } label: {
            VStack(spacing: 8) {
                ToneContourView(contour: option.contour, tint: isSelected || isRevealedCorrect ? tint : KumustaColors.muted)
                    .frame(height: 38)
                Text(option.text)
                    .scaledFont(36, weight: .heavy, design: .rounded)
                    .foregroundStyle(isSelected || isRevealedCorrect ? tint : KumustaColors.ink)
                Text(option.meaning)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(ChoiceCardButtonStyle(
            face: tint == KumustaColors.line ? KumustaColors.surface : tint.opacity(0.14),
            border: tint
        ))
        .disabled(result != nil)
        .modifier(ShakeEffect(trigger: isWrongPick ? shake : 0))
        .accessibilityLabel("\(option.text), \(option.meaning)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func check() {
        guard let selection else { return }
        let isCorrect = selection == pick.answer
        onAnswer(isCorrect)
        if isCorrect {
            SuccessFeedbackPlayer.shared.play()
            result = .correct(headline: Praise.random(), detail: nil)
        } else {
            WrongFeedbackPlayer.shared.play()
            shake += 1
            let meaning = pick.options.first { $0.text == pick.answer }?.meaning
            result = .incorrect(
                headline: L("Not quite"),
                solution: meaning.map { "\(pick.answer) (\($0))" } ?? pick.answer
            )
        }
    }
}

// MARK: - New phrase

private struct FirstLessonNewPhraseStep: View {
    let phrase: FirstLessonScript.NewPhrase
    let voice: FirstLessonVoice
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedChunks: Set<String> = []
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepTitle(text: L("New phrase"), eyebrow: L("LEARN"), eyebrowSymbol: "star.fill")

                BuddySays(motion: .listening) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(phrase.tagalog)
                            .scaledFont(phrase.tagalog.count > 18 ? 26 : 34, weight: .heavy, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(phrase.translation)
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        VoiceButtons(text: phrase.tagalog, voice: voice, size: 50, autoplay: true)
                            .padding(.top, 6)
                    }
                }
                .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 10) {
                    Text(L("TAP TO BREAK IT DOWN"))
                        .scaledFont(13, weight: .heavy, design: .rounded)
                        .scaledTracking(0.9, forPointSize: 13)
                        .foregroundStyle(KumustaColors.muted)

                    WordWrapLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                        ForEach(phrase.chunks) { chunk in
                            chunkTile(chunk)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "music.note")
                        .scaledFont(18, weight: .bold)
                        .foregroundStyle(KumustaColors.focus)
                        .accessibilityHidden(true)
                    Text(phrase.tip)
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KumustaColors.focus.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ContinueFooter(action: onContinue)
        }
        .sensoryFeedback(.selection, trigger: revealedChunks.count)
        .onAppear {
            withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) { appeared = true }
        }
    }

    private func chunkTile(_ chunk: FirstLessonScript.Chunk) -> some View {
        let isRevealed = revealedChunks.contains(chunk.id)
        return Button {
            withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                _ = revealedChunks.insert(chunk.id)
            }
            playPhrase(chunk.tagalog, voice: voice)
        } label: {
            VStack(spacing: 6) {
                Text(chunk.tagalog)
                    .scaledFont(22, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .fixedSize()
                Text(isRevealed ? chunk.meaning : "?")
                    .font(KumustaTypography.supportingStrong)
                    .foregroundStyle(isRevealed ? KumustaColors.focus : KumustaColors.line)
                    .fixedSize()
                    .contentTransition(.opacity)
            }
            .frame(minWidth: 72)
        }
        .buttonStyle(ChoiceCardButtonStyle(
            face: isRevealed ? KumustaColors.focus.opacity(0.1) : KumustaColors.surface,
            border: isRevealed ? KumustaColors.focus : KumustaColors.line
        ))
        .accessibilityLabel(isRevealed ? "\(chunk.tagalog), \(chunk.meaning)" : chunk.tagalog)
        .accessibilityHint(L("Plays the word and shows its meaning"))
    }
}

// MARK: - Meaning pick

private struct FirstLessonMeaningPickStep: View {
    let pick: FirstLessonScript.MeaningPick
    let voice: FirstLessonVoice
    let onAnswer: (Bool) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: String?
    @State private var result: CheckFooter.Result?
    @State private var shake = 0
    @State private var options: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                StepTitle(text: pick.prompt)

                BuddySays(motion: result.mascotMotion) {
                    VoiceButtons(text: pick.audio, voice: voice, size: 64, autoplay: true)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        optionRow(option)
                    }
                }
                .sensoryFeedback(.selection, trigger: selection)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CheckFooter(
                result: result,
                canCheck: selection != nil,
                onCheck: check,
                onContinue: onContinue
            )
        }
        .resultHaptics(result)
        .onAppear {
            if options.isEmpty { options = pick.options.shuffled() }
        }
    }

    private func optionRow(_ option: String) -> some View {
        let isSelected = selection == option
        let isRevealedCorrect = result != nil && option == pick.answer
        let isWrongPick = result != nil && isSelected && option != pick.answer
        let tint: Color = isRevealedCorrect ? KumustaColors.success
            : isWrongPick ? KumustaColors.accent
            : isSelected ? KumustaColors.focus
            : KumustaColors.line

        return Button {
            withAnimation(reduceMotion ? nil : KumustaMotion.press) { selection = option }
        } label: {
            HStack {
                Text(option)
                    .scaledFont(19, weight: .semibold, design: .rounded)
                    .foregroundStyle(tint == KumustaColors.line ? KumustaColors.ink : tint)
                Spacer(minLength: 0)
                if isRevealedCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KumustaColors.success)
                        .transition(.scale.combined(with: .opacity))
                } else if isWrongPick {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KumustaColors.accentDeep)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaledFont(22, weight: .bold)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        }
        .buttonStyle(ChoiceCardButtonStyle(
            face: tint == KumustaColors.line ? KumustaColors.surface : tint.opacity(0.14),
            border: tint
        ))
        .disabled(result != nil)
        .opacity(result != nil && !isSelected && !isRevealedCorrect ? 0.55 : 1)
        .modifier(ShakeEffect(trigger: isWrongPick ? shake : 0))
        .accessibilityLabel(option)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func check() {
        guard let selection else { return }
        let isCorrect = selection == pick.answer
        onAnswer(isCorrect)
        if isCorrect {
            SuccessFeedbackPlayer.shared.play()
            result = .correct(headline: Praise.random(), detail: pick.note ?? "\(pick.audio) = \(pick.answer)")
        } else {
            WrongFeedbackPlayer.shared.play()
            shake += 1
            result = .incorrect(headline: L("Not quite"), solution: pick.answer)
        }
    }
}

// MARK: - Most natural reply

private struct FirstLessonNaturalPickStep: View {
    let pick: FirstLessonScript.NaturalPick
    let voice: FirstLessonVoice
    let onAnswer: (Bool) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: String?
    @State private var result: CheckFooter.Result?
    @State private var shake = 0
    @State private var options: [FirstLessonScript.NaturalOption] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepTitle(text: pick.prompt, eyebrow: L("SOUND NATURAL"), eyebrowSymbol: "ear.fill")

                BuddySays(motion: result.mascotMotion) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pick.context)
                            .scaledFont(24, weight: .heavy, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(pick.contextTranslation)
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        VoiceButtons(text: pick.context, voice: voice, size: 46, autoplay: true)
                            .padding(.top, 4)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        optionCard(option)
                    }
                }
                .sensoryFeedback(.selection, trigger: selection)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CheckFooter(
                result: result,
                canCheck: selection != nil,
                onCheck: check,
                onContinue: onContinue
            )
        }
        .resultHaptics(result)
        .onAppear {
            if options.isEmpty { options = pick.options.shuffled() }
        }
    }

    private func optionCard(_ option: FirstLessonScript.NaturalOption) -> some View {
        let isSelected = selection == option.id
        let isRevealed = result != nil
        let isWrongPick = isRevealed && isSelected && !option.isBest
        let tint: Color = isRevealed && option.isBest ? KumustaColors.success
            : isWrongPick ? KumustaColors.accent
            : isSelected ? KumustaColors.focus
            : KumustaColors.line

        return Button {
            withAnimation(reduceMotion ? nil : KumustaMotion.press) { selection = option.id }
            playPhrase(option.text, voice: voice)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(option.text)
                        .scaledFont(20, weight: .bold, design: .rounded)
                        .foregroundStyle(tint == KumustaColors.line ? KumustaColors.ink : tint)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if isRevealed {
                        Text(option.verdict.uppercased())
                            .scaledFont(11, weight: .heavy, design: .rounded)
                            .scaledTracking(0.6, forPointSize: 11)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(option.isBest ? KumustaColors.success : KumustaColors.caution))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(option.translation)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if isRevealed && (isSelected || option.isBest) {
                    Text(option.explanation)
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChoiceCardButtonStyle(
            face: tint == KumustaColors.line ? KumustaColors.surface : tint.opacity(0.14),
            border: tint
        ))
        .disabled(isRevealed)
        .opacity(isRevealed && !isSelected && !option.isBest ? 0.6 : 1)
        .modifier(ShakeEffect(trigger: isWrongPick ? shake : 0))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func check() {
        guard let selection, let best = pick.best else { return }
        let isCorrect = selection == best.id
        onAnswer(isCorrect)
        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
            if isCorrect {
                SuccessFeedbackPlayer.shared.play()
                result = .correct(headline: L("That’s how natives say it!"), detail: nil)
            } else {
                WrongFeedbackPlayer.shared.play()
                shake += 1
                result = .incorrect(headline: L("Close, but not quite natural"), solution: best.text)
            }
        }
    }
}

// MARK: - Build the sentence

private struct FirstLessonBuildStep: View {
    let build: FirstLessonScript.Build
    let voice: FirstLessonVoice
    let onAnswer: (Bool) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tileSpace
    @State private var bank: [Tile] = []
    @State private var placed: [Int] = []
    @State private var result: CheckFooter.Result?
    @State private var shake = 0

    private struct Tile: Identifiable {
        let id: Int
        let text: String
        let gloss: String?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                StepTitle(text: L("Write this in Tagalog"))

                BuddySays(motion: result.mascotMotion) {
                    Text(build.english)
                        .scaledFont(24, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                answerArea
                    .modifier(ShakeEffect(trigger: shake))

                WordWrapLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                    ForEach(bank) { tile in
                        bankSlot(tile)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CheckFooter(
                result: result,
                canCheck: !placed.isEmpty,
                onCheck: check,
                onContinue: onContinue
            )
        }
        .sensoryFeedback(.selection, trigger: placed)
        .resultHaptics(result)
        .onAppear {
            if bank.isEmpty {
                bank = build.tiles.shuffled().enumerated().map {
                    Tile(id: $0.offset, text: $0.element.text, gloss: $0.element.gloss)
                }
            }
        }
    }

    private var answerArea: some View {
        VStack(spacing: 0) {
            WordWrapLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                ForEach(placed, id: \.self) { id in
                    if let tile = bank.first(where: { $0.id == id }) {
                        Button {
                            guard result == nil else { return }
                            withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                                placed.removeAll { $0 == id }
                            }
                        } label: {
                            tileLabel(tile)
                        }
                        .buttonStyle(ChoiceCardButtonStyle(face: KumustaColors.surface, border: KumustaColors.line))
                        .matchedGeometryEffect(id: tile.id, in: tileSpace)
                        .accessibilityHint(L("Removes this word"))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(.vertical, 8)

            Rectangle().fill(KumustaColors.line).frame(height: 2)
            Spacer().frame(height: 52)
            Rectangle().fill(KumustaColors.line).frame(height: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Your answer"))
    }

    @ViewBuilder
    private func bankSlot(_ tile: Tile) -> some View {
        let isUsed = placed.contains(tile.id)
        ZStack {
            // The empty slot stays behind, like a gap left on the shelf.
            tileLabel(tile)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .opacity(0)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(KumustaColors.surfaceStrong)
                )
                .padding(.bottom, 4)

            if !isUsed {
                Button {
                    guard result == nil else { return }
                    playPhrase(tile.text, voice: voice)
                    withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                        placed.append(tile.id)
                    }
                } label: {
                    tileLabel(tile)
                }
                .buttonStyle(ChoiceCardButtonStyle(face: KumustaColors.surface, border: KumustaColors.line))
                .matchedGeometryEffect(id: tile.id, in: tileSpace)
                .accessibilityLabel(tile.gloss.map { "\(tile.text), \($0)" } ?? tile.text)
                .accessibilityHint(L("Adds this word to your answer"))
            }
        }
    }

    private func tileLabel(_ tile: Tile) -> some View {
        VStack(spacing: 2) {
            Text(tile.text)
                .scaledFont(20, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
            if let gloss = tile.gloss {
                Text(gloss)
                    .scaledFont(12, weight: .semibold, design: .rounded)
                    .foregroundStyle(KumustaColors.muted)
            }
        }
        .fixedSize()
    }

    private func check() {
        let words = placed.compactMap { id in bank.first { $0.id == id }?.text }
        let isCorrect = words.map { $0.lowercased() } == build.answer.map { $0.text.lowercased() }
        onAnswer(isCorrect)
        if isCorrect {
            SuccessFeedbackPlayer.shared.play()
            result = .correct(headline: Praise.random(), detail: "\(build.solution) = \(build.english)")
            playPhrase(build.solution, voice: voice)
        } else {
            WrongFeedbackPlayer.shared.play()
            shake += 1
            result = .incorrect(headline: L("Not quite"), solution: build.solution)
        }
    }
}

// MARK: - Speaking

/// Recording and on-device grading shared by the speak and conversation
/// steps. Before the paywall, takes past the daily allowance are recorded
/// without streaming or uploading, then celebrated without a grade.
@MainActor
@Observable
private final class FirstLessonSpeechCheck {
    enum Outcome {
        case matched
        case missed
        case unchecked
        case failed
    }

    let recorder = SpeakingRecorder()
    private(set) var feedbackState: SpeechFeedbackState = .idle
    private(set) var matchedTarget = false
    private(set) var isUnchecked = false
    private(set) var attempts = 0
    private(set) var isPreparing = false
    private var willGrade = true
    private var task: Task<Void, Never>?

    let budget: FirstLessonSpeechBudget
    let isOnboarding: Bool
    private let voice: FirstLessonVoice

    init(budget: FirstLessonSpeechBudget, isOnboarding: Bool, voice: FirstLessonVoice) {
        self.budget = budget
        self.isOnboarding = isOnboarding
        self.voice = voice
    }

    /// True from the tap until the take is saved; playback must wait.
    var isCapturing: Bool {
        isPreparing || recorder.isRecording || recorder.isFinishingRecording
    }

    func toggle(dependencies: DependencyContainer) {
        if recorder.isRecording {
            recorder.toggleRecording()
            return
        }
        task?.cancel()
        feedbackState = .idle
        matchedTarget = false
        isUnchecked = false
        isPreparing = true
        // A streamed take spends the allowance when it starts, so decide now.
        willGrade = budget.canGrade && dependencies.speechRecognitionService != nil
        let speechService = willGrade ? dependencies.speechRecognitionService : nil
        if willGrade { budget.spend() }
        let isOnboarding = isOnboarding
        Task { @MainActor in
            // Lesson audio must be fully stopped before the microphone takes
            // the audio session, or the take is cut off as it starts.
            await voice.stop()
            recorder.toggleRecording(streamingTo: speechService, onboarding: isOnboarding)
            isPreparing = false
        }
    }

    func evaluate(
        targets: [String],
        dependencies: DependencyContainer,
        onResult: @escaping (Outcome) -> Void
    ) {
        guard !feedbackState.isProcessing else { return }
        recorder.stopPlayback()
        attempts += 1

        guard willGrade, let speechService = dependencies.speechRecognitionService else {
            recorder.discardCurrentRecording()
            isUnchecked = true
            onResult(.unchecked)
            return
        }

        let audio: Data
        do {
            audio = try recorder.recordingData()
        } catch {
            recorder.discardCurrentRecording()
            feedbackState = .failed(L("That take was too short. Tap, say the whole line, then tap again."))
            onResult(.failed)
            return
        }

        let live = recorder.takeLiveTranscription()
        recorder.discardCurrentRecording()
        feedbackState = .processing
        matchedTarget = false
        task?.cancel()
        let isOnboarding = isOnboarding
        task = Task { @MainActor in
            do {
                let transcription = try await speechService.transcribe(audio: audio, live: live, onboarding: isOnboarding)
                guard !Task.isCancelled else { return }
                let matched = FirstLessonGrading.matches(
                    transcript: transcription.transcript,
                    targets: targets
                )
                matchedTarget = matched
                feedbackState = .result(
                    transcription,
                    PronunciationReview(
                        target: targets.first ?? "",
                        transcript: transcription.transcript
                    )
                )
                if matched {
                    SuccessFeedbackPlayer.shared.play(showsSuccessBorder: true)
                } else {
                    WrongFeedbackPlayer.shared.play()
                }
                onResult(matched ? .matched : .missed)
            } catch is CancellationError {
                return
            } catch let error as SpeechRecognitionError
                where isOnboarding && [.authenticationRequired, .premiumRequired, .rateLimited].contains(error) {
                // The pre-paywall allowance is spent: keep the moment positive.
                budget.exhaust()
                feedbackState = .idle
                isUnchecked = true
                onResult(.unchecked)
            } catch {
                feedbackState = .failed(
                    (error as? LocalizedError)?.errorDescription ?? L("Speech feedback is temporarily unavailable.")
                )
                onResult(.failed)
            }
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        feedbackState = .idle
        matchedTarget = false
        isUnchecked = false
        recorder.stopPlayback()
        recorder.discardCurrentRecording()
    }

    func resetForNextPhrase() {
        reset()
        attempts = 0
    }

    func cleanup() {
        task?.cancel()
        recorder.stopRecording()
        recorder.cleanup()
    }
}

/// The microphone footer: speak, finish, checking, or retry.
private struct SpeakFooter: View {
    let speech: FirstLessonSpeechCheck
    let onToggle: () -> Void
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if speech.recorder.isRecording {
                VoiceMeter(level: speech.recorder.meterLevel, isActive: true)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            if speech.feedbackState.isProcessing || speech.recorder.isFinishingRecording || speech.recorder.hasRecording {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(L("Tuko is listening back…"))
                }
                .font(KumustaTypography.bodyStrong)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(KumustaColors.focusFill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.bottom, 6)
            } else if speech.feedbackState.hasResult || speech.feedbackState.isFailed {
                Button(L("TRY AGAIN"), action: onRetry)
                    .buttonStyle(KumustaPrimaryButtonStyle())
            } else {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        Image(systemName: speech.recorder.isRecording ? "stop.fill" : "mic.fill")
                            .scaledFont(22, weight: .bold)
                        Text(speech.recorder.isRecording ? L("TAP TO FINISH") : L("TAP TO SPEAK"))
                            .scaledFont(18, weight: .heavy, design: .rounded)
                            .scaledTracking(0.8, forPointSize: 18)
                    }
                }
                .buttonStyle(SpeakButtonStyle(isRecording: speech.recorder.isRecording))
                .disabled(speech.isPreparing)
                .accessibilityLabel(speech.recorder.isRecording ? L("Stop recording") : L("Start recording"))
            }

            if !speech.recorder.isRecording && !speech.feedbackState.isProcessing && !speech.isPreparing {
                Button(action: onSkip) {
                    Text(skipTitle)
                        .scaledFont(14, weight: .heavy, design: .rounded)
                        .scaledTracking(0.8, forPointSize: 14)
                        .foregroundStyle(KumustaColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .screenContentWidth()
        .frame(maxWidth: .infinity)
        .background(FooterBackdrop())
        .animation(.easeOut(duration: 0.2), value: speech.recorder.isRecording)
    }

    private var skipTitle: String {
        if speech.feedbackState.isFailed { return L("CONTINUE WITHOUT FEEDBACK") }
        if speech.attempts >= 2 { return L("CONTINUE ANYWAY") }
        return L("CAN’T SPEAK NOW")
    }
}

private enum UncheckedTake {
    static var headline: String { L("Nice, you said it!") }
    static var detail: String { L("Tuko will check every word once your plan starts.") }
}

private struct FirstLessonSpeakStep: View {
    let speak: FirstLessonScript.Speak
    let voice: FirstLessonVoice
    let isOnboarding: Bool
    let analyticsProperties: [String: String]
    let onContinue: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @State private var speech: FirstLessonSpeechCheck
    @State private var result: CheckFooter.Result?

    init(
        speak: FirstLessonScript.Speak,
        voice: FirstLessonVoice,
        budget: FirstLessonSpeechBudget,
        isOnboarding: Bool,
        analyticsProperties: [String: String],
        onContinue: @escaping () -> Void
    ) {
        self.speak = speak
        self.voice = voice
        self.isOnboarding = isOnboarding
        self.analyticsProperties = analyticsProperties
        self.onContinue = onContinue
        _speech = State(initialValue: FirstLessonSpeechCheck(budget: budget, isOnboarding: isOnboarding, voice: voice))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StepTitle(text: speak.title, eyebrow: L("SPEAK"), eyebrowSymbol: "mic.fill")

                BuddySays(motion: mascotMotion) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(speak.display)
                            .scaledFont(speak.display.count > 22 ? 25 : 30, weight: .heavy, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(speak.translation)
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        VoiceButtons(text: speak.spokenText, voice: voice, size: 48, autoplay: true)
                            .padding(.top, 6)
                            .disabled(speech.isCapturing)
                    }
                }

                if let tip = speak.tip, !speech.feedbackState.hasResult {
                    Label(tip, systemImage: "lightbulb.fill")
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.ink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KumustaColors.caution.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let errorMessage = speech.recorder.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if speech.recorder.permissionState == .denied {
                    OpenSettingsButton()
                }

                if result == nil {
                    SpeechFeedbackCard(
                        state: speech.feedbackState,
                        isCorrect: speech.matchedTarget,
                        showsRetryButton: false,
                        onRetry: speech.reset
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let result {
                CheckFooter(result: result, canCheck: true, onCheck: {}, onContinue: finish)
            } else {
                SpeakFooter(
                    speech: speech,
                    onToggle: { speech.toggle(dependencies: dependencies) },
                    onRetry: speech.reset,
                    onSkip: skip
                )
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: speech.recorder.isRecording)
        .resultHaptics(result)
        .onChange(of: speech.recorder.hasRecording) { _, hasRecording in
            guard hasRecording else { return }
            speech.evaluate(
                targets: [speak.target] + speak.accepted,
                dependencies: dependencies
            ) { outcome in
                switch outcome {
                case .matched:
                    track("speech_matched")
                    result = .correct(headline: Praise.random(), detail: L("Tuko understood every word."))
                case .unchecked:
                    track("speech_unchecked")
                    result = .neutral(headline: UncheckedTake.headline, detail: UncheckedTake.detail)
                case .missed:
                    track("speech_missed")
                case .failed:
                    track("speech_failed")
                }
            }
        }
        .onDisappear { speech.cleanup() }
    }

    private var mascotMotion: BuddyMotion {
        if speech.feedbackState.isProcessing { return .reviewing }
        if result != nil { return .correct }
        if speech.feedbackState.hasResult { return .mistake }
        return .listening
    }

    private func skip() {
        track("speech_skipped")
        finish()
    }

    private func finish() {
        speech.cleanup()
        onContinue()
    }

    private func track(_ step: String) {
        dependencies.analytics.track(
            .featureAction,
            properties: analyticsProperties.merging([
                "step": step,
                "attempt": String(speech.attempts)
            ], uniquingKeysWith: { _, new in new })
        )
    }
}

// MARK: - Conversation

private struct FirstLessonConversationStep: View {
    let conversation: FirstLessonScript.Conversation
    let voice: FirstLessonVoice
    let isOnboarding: Bool
    let analyticsProperties: [String: String]
    let onContinue: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var speech: FirstLessonSpeechCheck
    @State private var messages: [Message] = []
    @State private var turnIndex = 0
    @State private var isBuddyTyping = false
    @State private var isAwaitingReply = false
    @State private var isFinished = false

    init(
        conversation: FirstLessonScript.Conversation,
        voice: FirstLessonVoice,
        budget: FirstLessonSpeechBudget,
        isOnboarding: Bool,
        analyticsProperties: [String: String],
        onContinue: @escaping () -> Void
    ) {
        self.conversation = conversation
        self.voice = voice
        self.isOnboarding = isOnboarding
        self.analyticsProperties = analyticsProperties
        self.onContinue = onContinue
        _speech = State(initialValue: FirstLessonSpeechCheck(budget: budget, isOnboarding: isOnboarding, voice: voice))
    }

    private struct Message: Identifiable, Equatable {
        let id = UUID()
        let fromBuddy: Bool
        let text: String
        let translation: String
    }

    private var turns: [FirstLessonScript.Turn] { conversation.turns }

    private var currentTurn: FirstLessonScript.Turn? {
        turns.indices.contains(turnIndex) ? turns[turnIndex] : nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    StepTitle(text: conversation.title, eyebrow: conversation.eyebrow, eyebrowSymbol: "bubble.left.and.bubble.right.fill")
                        .padding(.bottom, 4)

                    ForEach(messages) { message in
                        bubble(message)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .move(edge: message.fromBuddy ? .leading : .trailing).combined(with: .opacity)
                            )
                    }

                    if isBuddyTyping {
                        typingIndicator
                            .transition(.opacity)
                    }

                    if isAwaitingReply, let currentTurn, !isFinished {
                        replyPrompt(currentTurn)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if !speech.matchedTarget {
                        SpeechFeedbackCard(
                            state: speech.feedbackState,
                            isCorrect: false,
                            showsRetryButton: false,
                            onRetry: speech.reset
                        )
                    }

                    if let errorMessage = speech.recorder.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.accentDeep)
                    }

                    if speech.recorder.permissionState == .denied {
                        OpenSettingsButton()
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
                .screenContentWidth()
                .animation(reduceMotion ? nil : KumustaMotion.screen, value: messages)
                .animation(reduceMotion ? nil : KumustaMotion.screen, value: isAwaitingReply)
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: isAwaitingReply) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFinished {
                CheckFooter(
                    result: .correct(headline: L("You just spoke Tagalog!"), detail: L("A real conversation, start to finish.")),
                    canCheck: true,
                    onCheck: {},
                    onContinue: finish
                )
            } else if isAwaitingReply {
                SpeakFooter(
                    speech: speech,
                    onToggle: { speech.toggle(dependencies: dependencies) },
                    onRetry: speech.reset,
                    onSkip: { completeTurn(spoken: false) }
                )
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: speech.recorder.isRecording)
        .sensoryFeedback(.success, trigger: isFinished)
        .onChange(of: speech.recorder.hasRecording) { _, hasRecording in
            guard hasRecording, let currentTurn else { return }
            speech.evaluate(
                targets: [currentTurn.replyTarget] + currentTurn.accepted,
                dependencies: dependencies
            ) { outcome in
                switch outcome {
                case .matched, .unchecked:
                    completeTurn(spoken: true, graded: outcome == .matched)
                case .missed, .failed:
                    break
                }
            }
        }
        .task {
            if messages.isEmpty { await buddySpeaks() }
        }
        .onDisappear { speech.cleanup() }
    }

    private func bubble(_ message: Message) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.fromBuddy {
                BuddyMark(size: 52, mood: .happy)
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.fromBuddy ? .leading : .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Text(message.text)
                        .scaledFont(20, weight: .bold, design: .rounded)
                        .foregroundStyle(message.fromBuddy ? KumustaColors.ink : .white)
                        .fixedSize(horizontal: false, vertical: true)
                    if message.fromBuddy {
                        Button {
                            playPhrase(message.text, voice: voice)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .scaledFont(15, weight: .bold)
                                .foregroundStyle(KumustaColors.focus)
                                .frame(width: 32, height: 32)
                        }
                        .disabled(speech.isCapturing)
                        .accessibilityLabel(L("Replay"))
                    }
                }
                Text(message.translation)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(message.fromBuddy ? KumustaColors.muted : .white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: message.fromBuddy ? 6 : 20,
                    bottomTrailingRadius: message.fromBuddy ? 20 : 6,
                    topTrailingRadius: 20,
                    style: .continuous
                )
                .fill(message.fromBuddy ? KumustaColors.surface : KumustaColors.focusFill)
            )
            .overlay {
                if message.fromBuddy {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 20,
                        style: .continuous
                    )
                    .stroke(KumustaColors.line, lineWidth: 1.5)
                }
            }

            if message.fromBuddy {
                Spacer(minLength: 32)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.fromBuddy ? "Tuko" : L("You")): \(message.text), \(message.translation)")
    }

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            BuddyMark(size: 52, mood: .listening)
                .frame(width: 52, height: 52)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(KumustaColors.muted)
                            .frame(width: 9, height: 9)
                            .offset(y: reduceMotion ? 0 : -4 * max(0, sin((t * 6) - Double(index) * 0.7)))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(KumustaColors.surface)
            .clipShape(Capsule())
            Spacer()
        }
        .accessibilityLabel(L("Tuko is typing"))
    }

    private func replyPrompt(_ turn: FirstLessonScript.Turn) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(L("YOUR TURN · SAY"))
                .scaledFont(12, weight: .heavy, design: .rounded)
                .scaledTracking(0.9, forPointSize: 12)
                .foregroundStyle(KumustaColors.focus)
            Text(turn.replyDisplay)
                .scaledFont(22, weight: .heavy, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            Text(turn.replyTranslation)
                .font(KumustaTypography.supporting)
                .foregroundStyle(KumustaColors.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(KumustaColors.focus, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
        .accessibilityElement(children: .combine)
    }

    /// Tuko types, then says a line out loud.
    @MainActor
    private func say(_ text: String, translation: String) async {
        withAnimation { isBuddyTyping = true }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 900))
        guard !Task.isCancelled else { return }
        withAnimation {
            isBuddyTyping = false
            messages.append(Message(fromBuddy: true, text: text, translation: translation))
        }
        try? await voice.play(text)
    }

    @MainActor
    private func buddySpeaks() async {
        guard let turn = currentTurn else { return }
        await say(turn.buddyLine, translation: turn.buddyTranslation)
        withAnimation { isAwaitingReply = true }
    }

    private func completeTurn(spoken: Bool, graded: Bool = true) {
        guard let turn = currentTurn else { return }
        dependencies.analytics.track(
            .featureAction,
            properties: analyticsProperties.merging([
                "step": spoken ? (graded ? "turn_spoken" : "turn_unchecked") : "turn_skipped",
                "value": String(turn.id),
                "attempt": String(speech.attempts)
            ], uniquingKeysWith: { _, new in new })
        )
        withAnimation {
            isAwaitingReply = false
            messages.append(Message(fromBuddy: false, text: turn.replyDisplay, translation: turn.replyTranslation))
        }
        speech.resetForNextPhrase()
        turnIndex += 1
        Task { @MainActor in
            if turnIndex >= turns.count {
                if let closing = conversation.closing {
                    await say(closing.text, translation: closing.translation)
                } else {
                    try? await Task.sleep(for: .milliseconds(500))
                }
                withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) { isFinished = true }
            } else {
                await buddySpeaks()
            }
        }
    }

    private func finish() {
        speech.cleanup()
        onContinue()
    }
}

// MARK: - Exit sheet

private struct FirstLessonExitSheet: View {
    let isOnboarding: Bool
    let minutes: Int
    let onKeepGoing: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            BuddyMotionView(motion: .mistake, size: 110)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(L("Wait, don’t go!"))
                    .scaledFont(24, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                Text(isOnboarding
                     ? L(one: "Your first real exchange in Tagalog is about %lld minute away.", other: "Your first real exchange in Tagalog is about %lld minutes away.", count: minutes)
                     : L("You’re a few minutes away from your first conversation."))
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 4) {
                Button(L("KEEP LEARNING"), action: onKeepGoing)
                    .buttonStyle(KumustaPrimaryButtonStyle())
                Button(action: onQuit) {
                    Text(isOnboarding ? L("SKIP THE LESSON") : L("END LESSON"))
                        .scaledFont(15, weight: .heavy, design: .rounded)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(KumustaColors.canvas.ignoresSafeArea())
    }
}

// MARK: - Completion

private struct FirstLessonCompleteView: View {
    let completion: FirstLessonScript.Completion
    let accuracy: Int
    let elapsed: TimeInterval
    let voice: FirstLessonVoice
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsTitle = false
    @State private var visibleStats = 0
    @State private var visiblePhrases = 0
    @State private var confettiBurst = 0

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    stats
                    phrases
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)

            ConfettiBurstView(burst: confettiBurst)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ContinueFooter(title: L("CONTINUE"), action: onContinue)
        }
        .sensoryFeedback(.success, trigger: confettiBurst)
        .task { await celebrate() }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KumustaColors.caution.opacity(0.22))
                    .frame(width: 118, height: 118)
                    .scaleEffect(showsTitle || reduceMotion ? 1 : 0.6)
                Circle()
                    .stroke(KumustaColors.caution.opacity(0.35), lineWidth: 3)
                    .frame(width: 138, height: 138)
                    .scaleEffect(showsTitle || reduceMotion ? 1 : 0.7)
                    .opacity(showsTitle ? 1 : 0)
                BuddyMotionView(motion: .correct, size: 104)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(completion.title)
                    .scaledFont(30, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.caution)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(completion.subtitle)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .scaleEffect(showsTitle || reduceMotion ? 1 : 0.7)
            .opacity(showsTitle ? 1 : 0)
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            statCard(title: L("ACCURACY"), value: L("%lld%%", accuracy), symbol: "target", tint: KumustaColors.success, index: 0)
            statCard(title: L("TIME"), value: formattedElapsed, symbol: "stopwatch.fill", tint: KumustaColors.focus, index: 1)
            statCard(title: L("NEW WORDS"), value: "\(completion.words.count)", symbol: "book.closed.fill", tint: KumustaColors.caution, index: 2)
        }
    }

    private func statCard(title: String, value: String, symbol: String, tint: Color, index: Int) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .scaledFont(12, weight: .heavy, design: .rounded)
                .scaledTracking(0.8, forPointSize: 12)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(tint)
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(value)
                    .scaledFont(20, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(KumustaColors.canvas)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint, lineWidth: 2)
        }
        .scaleEffect(index < visibleStats || reduceMotion ? 1 : 0.6)
        .opacity(index < visibleStats ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.capitalized): \(value)")
    }

    private var phrases: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("YOU CAN NOW SAY"))
                .scaledFont(13, weight: .heavy, design: .rounded)
                .scaledTracking(0.9, forPointSize: 13)
                .foregroundStyle(KumustaColors.muted)

            ForEach(Array(completion.phrases.enumerated()), id: \.element.id) { index, phrase in
                Button {
                    playPhrase(FirstLessonScript.playableText(phrase.tagalog), voice: voice)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark")
                            .scaledFont(15, weight: .black)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(KumustaColors.success))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phrase.tagalog)
                                .scaledFont(19, weight: .bold, design: .rounded)
                                .foregroundStyle(KumustaColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(phrase.meaning)
                                .font(KumustaTypography.supporting)
                                .foregroundStyle(KumustaColors.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(KumustaColors.focus)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ChoiceCardButtonStyle(face: KumustaColors.surface, border: KumustaColors.line))
                .opacity(index < visiblePhrases ? 1 : 0)
                .offset(x: index < visiblePhrases || reduceMotion ? 0 : -24)
                .accessibilityLabel("\(phrase.tagalog), \(phrase.meaning)")
                .accessibilityHint(L("Plays the phrase"))
            }

            Label(L("Saved to your Words for review"), systemImage: "bookmark.fill")
                .font(KumustaTypography.caption)
                .foregroundStyle(KumustaColors.muted)
                .opacity(visiblePhrases >= completion.phrases.count ? 1 : 0)
        }
    }

    private var formattedElapsed: String {
        let seconds = max(0, Int(elapsed))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @MainActor
    private func celebrate() async {
        LessonFinishedFeedbackPlayer.shared.play()
        withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) { showsTitle = true }
        confettiBurst += 1
        for index in 1...3 {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 220))
            withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) { visibleStats = index }
        }
        guard !completion.phrases.isEmpty else { return }
        for index in 1...completion.phrases.count {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 200))
            withAnimation(reduceMotion ? nil : KumustaMotion.screen) { visiblePhrases = index }
        }
    }
}

#if DEBUG
#Preview("First lesson") {
    if let script = try? FirstLessonCatalog.load(FirstLessonCatalog.fullLessonFile, learnerName: "Alex") {
        FirstLessonView(script: script, learnerName: "Alex", onFinish: {}, onClose: {})
            .environment(DependencyContainer.preview())
            .environment(AppState(dependencies: .preview()))
    }
}
#endif
