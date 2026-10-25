import SwiftUI
import AVFoundation
import Combine

struct LivePracticeView: View {
    let onDismiss: () -> Void
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session = LivePracticeSession()
    @State private var didTrackEnd = false
    @State private var arrivalFinished = false
    @AppStorage("livePractice.showsTranscript") private var showsTranscript = true
    @AppStorage("livePractice.personality") private var personality: LivePersonality = .friendly

    private var latestLessonRecord: CompletedLessonRecord? {
        dependencies.learningJourneyStore.completedLessons
            .max(by: { $0.completedAt < $1.completedAt })
    }

    private var latestLesson: String {
        latestLessonRecord?.lesson.scenario ?? "a friendly introduction"
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                header
                if focusesMascot {
                    Spacer(minLength: 12)
                } else {
                    Spacer().frame(height: compactHeader ? 4 : 18)
                }
                if focusesMascot {
                    // Shrinks toward the compact size on short screens.
                    mascot.frame(minHeight: 190, maxHeight: 340)
                } else if compactHeader {
                    mascot.frame(height: 190)
                } else {
                    // Gives way to the mood picker on short screens.
                    mascot.frame(minHeight: 150, maxHeight: 250)
                }
                Text("Tuko")
                    .scaledFont(compactHeader ? 19 : 23, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .padding(.top, compactHeader ? 5 : 10)
                Text(companionStatus)
                    .scaledFont(13, weight: .medium, design: .rounded)
                    .foregroundStyle(KumustaColors.muted)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.updatesFrequently)

                if session.isOpen {
                    LiveVoiceWaveform(
                        level: session.assistantSpeaking ? max(0.2, session.assistantLevel) : session.voiceLevel,
                        active: session.assistantSpeaking || session.userSpeaking,
                        reduceMotion: reduceMotion
                    )
                    .frame(height: 22)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
                }

                if focusesMascot {
                    Spacer(minLength: 12)
                } else if hasConversation {
                    transcript.padding(.top, 12)
                } else {
                    Spacer(minLength: 20)
                    Text(L("A little Tagalog.\nA real conversation."))
                        .scaledFont(20, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("Today: %@", latestLessonRecord?.lesson.scenario ?? L("a friendly introduction")))
                        .scaledFont(14, design: .rounded)
                        .foregroundStyle(KumustaColors.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    Spacer(minLength: 16)
                    LivePersonalityPicker(selection: $personality, reduceMotion: reduceMotion)
                }

                if let message = session.message {
                    Text(message)
                        .scaledFont(13, design: .rounded)
                        .foregroundStyle(KumustaColors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Spacer().frame(height: 14)
                controls
            }
            .padding(.horizontal, 22)
            .padding(.top, 9)
            .padding(.bottom, 18)
            .screenContentWidth()
            .animation(
                reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86),
                value: compactHeader
            )
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: showsTranscript)
        }
        .task {
            await session.load(dependencies.livePracticeGateway)
            dependencies.analytics.track(
                .livePracticeOpened,
                properties: liveProperties.merging([
                    "availability": session.available ? "available" : "unavailable",
                    "remaining_seconds": String(session.remaining),
                    "daily_limit_seconds": String(session.dailyLimit)
                ], uniquingKeysWith: { current, _ in current })
            )
            #if DEBUG
            if let clip = UserDefaults.standard.string(forKey: "liveDemoClip") {
                await dependencies.audioService.stop()
                try? await Task.sleep(for: .seconds(2))
                session.startDemo(clip: URL(fileURLWithPath: clip))
            } else if ProcessInfo.processInfo.arguments.contains("autoStartLivePractice"), session.available {
                await dependencies.audioService.stop()
                startLivePractice()
            }
            #endif
        }
        .onDisappear {
            if session.isOpen { trackLiveEnd(reason: "view_disappeared") }
            session.stop()
        }
        .onChange(of: session.phase) { _, phase in
            switch phase {
            case .active:
                didTrackEnd = false
                dependencies.analytics.track(
                    .livePracticeStarted,
                    properties: liveProperties,
                    clientSessionID: session.clientSessionID
                )
            case .ended:
                trackLiveEnd(reason: session.endReason.isEmpty ? "ended" : session.endReason)
            default:
                break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            session.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               value == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                session.stop()
            }
        }
    }

    private var companionStatus: String {
        if session.isOpen { return session.status }
        if session.phase == .ended, session.message != nil { return L("Conversation ended · try again when ready") }
        if session.phase == .ended, session.elapsed > 0 {
            return L(
                "%@ of Tagalog · nice work",
                "\(session.elapsed / 60):\(String(format: "%02d", session.elapsed % 60))"
            )
        }
        return L("Ready when you are")
    }

    private var hasConversation: Bool {
        session.isOpen || !session.captions.isEmpty
    }

    /// With the transcript hidden, Tuko grows and takes the center.
    private var focusesMascot: Bool {
        hasConversation && !showsTranscript
    }

    private var compactHeader: Bool {
        session.phase != .idle || !session.captions.isEmpty
    }

    private var header: some View {
        ZStack {
            Text("KUMUSTA")
                .font(.custom("Fredoka-Bold", size: 28, relativeTo: .title2))
                .tracking(-0.45)
                .foregroundStyle(KumustaColors.accentDeep)
                .accessibilityLabel("Kumusta")

            HStack {
                Button {
                    session.stop()
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .scaledFont(17, weight: .bold)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Back to practice and end conversation"))

                Spacer()
            }
        }
        .frame(height: 44)
    }

    private var mascotActivity: MascotActivity {
        if session.assistantSpeaking { return .speaking }
        switch session.phase {
        case .connecting: return .thinking
        case .active: return .listening
        case .stopping: return .farewell
        case .ended: return session.message == nil && session.elapsed > 0 ? .celebrating : .idle
        case .idle: return arrivalFinished ? .idle : .greeting
        }
    }

    private var mascot: some View {
        ConversationMascot(
            activity: mascotActivity,
            speech: session.assistantSpeech,
            listeningLevel: session.muted || !session.userSpeaking ? 0 : Double(session.voiceLevel),
            reduceMotion: reduceMotion
        )
        .accessibilityElement()
        .accessibilityLabel(L("Tuko, your conversation buddy"))
        .task {
            try? await Task.sleep(for: .seconds(3.6))
            guard !Task.isCancelled else { return }
            arrivalFinished = true
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if session.captions.isEmpty {
                        Text(L("Your conversation appears here"))
                            .scaledFont(15, design: .rounded)
                            .foregroundStyle(KumustaColors.muted)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }

                    ForEach(session.captions) { caption in
                        HStack {
                            if caption.isUser { Spacer(minLength: 44) }
                            Text(caption.text)
                                .scaledFont(16, design: .rounded)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                                .foregroundStyle(caption.isUser ? Color.white : KumustaColors.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    caption.isUser ? KumustaColors.accent : KumustaColors.surface,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .accessibilityLabel(caption.isUser ? L("You: %@", caption.text) : L("Tuko: %@", caption.text))
                            if !caption.isUser { Spacer(minLength: 44) }
                        }
                        .id(caption.id)
                    }
                    Color.clear.frame(height: 1).id("latest-caption")
                }
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxHeight: .infinity)
            .onChange(of: session.captions.map(\.text)) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo("latest-caption", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if session.isOpen {
            HStack(spacing: 22) {
                roundButton(
                    icon: session.muted ? "mic.slash.fill" : "mic.fill",
                    label: session.muted ? L("Unmute") : L("Mute"),
                    fill: KumustaColors.surface,
                    foreground: KumustaColors.ink,
                    action: toggleMute
                )
                .disabled(session.phase != .active)

                roundButton(
                    icon: showsTranscript ? "captions.bubble.fill" : "captions.bubble",
                    label: showsTranscript ? L("Hide text") : L("Show text"),
                    fill: KumustaColors.surface,
                    foreground: KumustaColors.ink,
                    action: { showsTranscript.toggle() }
                )

                roundButton(
                    icon: "phone.down.fill",
                    label: session.phase == .connecting ? L("Cancel") : L("End"),
                    fill: KumustaColors.accent,
                    foreground: .white,
                    action: session.stop
                )
                .disabled(session.phase == .stopping)
            }
        } else {
            Button {
                if session.available {
                    Task {
                        await dependencies.audioService.stop()
                        startLivePractice()
                    }
                } else {
                    Task { await session.load(dependencies.livePracticeGateway) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: session.available ? "mic.fill" : "arrow.clockwise")
                    Text(startLabel)
                }
                .scaledFont(17, weight: .bold, design: .rounded)
                .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(KumustaPrimaryButtonStyle())
            .disabled(session.loadingAllowance || session.remaining == 0)
        }
    }

    private var startLabel: String {
        if session.loadingAllowance { return L("Loading…") }
        if session.remaining == 0 { return L("Done for today") }
        if !session.available { return L("Try again") }
        return session.phase == .ended ? L("Talk again") : L("Start talking")
    }

    private var liveProperties: [String: String] {
        var properties = [
            "screen_name": "live_practice",
            "live_engine": livePracticeEngine,
            "personality": personality.rawValue
        ]
        if let lessonID = latestLessonRecord?.lesson.id {
            properties["lesson_id"] = lessonID.uuidString
        }
        return properties
    }

    private func startLivePractice() {
        didTrackEnd = false
        guard let clientSessionID = session.start(
            topic: "",
            lesson: latestLesson,
            lessonID: latestLessonRecord?.lesson.id,
            personality: personality.rawValue
        ) else { return }
        dependencies.analytics.track(
            .livePracticeStartRequested,
            properties: liveProperties.merging([
                "remaining_seconds": String(session.remaining)
            ], uniquingKeysWith: { current, _ in current }),
            clientSessionID: clientSessionID
        )
    }

    private func toggleMute() {
        session.toggleMute()
        dependencies.analytics.track(
            .livePracticeMuteChanged,
            properties: liveProperties.merging([
                "muted": session.muted ? "true" : "false"
            ], uniquingKeysWith: { current, _ in current }),
            clientSessionID: session.clientSessionID
        )
    }

    private func trackLiveEnd(reason: String) {
        guard !didTrackEnd else { return }
        didTrackEnd = true
        let event: AnalyticsEvent = session.didBecomeActive
            ? .livePracticeEnded
            : .livePracticeStartFailed
        var properties = [
            "active_seconds": String(session.elapsed),
            "end_reason": String(reason.prefix(100)),
            "user_fragments": String(session.userFragments)
        ]
        if !session.startFailure.isEmpty { properties["start_error"] = session.startFailure }
        dependencies.analytics.track(
            event,
            properties: liveProperties.merging(properties, uniquingKeysWith: { current, _ in current }),
            clientSessionID: session.clientSessionID
        )
        recordReviewOutcome(reason: reason)
    }

    /// Dropped or failed calls are friction; a real conversation the learner
    /// chose to end is a win. When the view is already gone the learner is
    /// back on the practice screen, which is itself a natural break.
    private func recordReviewOutcome(reason: String) {
        let failureReasons: Set<String> = [
            "start_failed", "connection_lost", "provider_error", "agent_not_connected"
        ]
        if failureReasons.contains(reason) {
            appState.recordReviewFriction()
            return
        }
        guard session.didBecomeActive else { return }
        appState.recordReviewSignal(
            .livePractice(activeSeconds: session.elapsed, userTurns: session.userFragments),
            isAtNaturalBreak: reason == "view_disappeared"
        )
    }

    private func roundButton(
        icon: String,
        label: String,
        fill: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .scaledFont(20, weight: .bold)
                    .frame(width: 58, height: 58)
                    .background(fill, in: Circle())
                Text(label).scaledFont(12, weight: .bold, design: .rounded)
            }
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .tactile()
    }
}

enum LivePersonality: String, CaseIterable, Identifiable {
    case friendly
    case familiar
    case grumpy
    case strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friendly: L("Friendly")
        case .familiar: L("Familiar")
        case .grumpy: L("Grumpy")
        case .strict: L("Strict")
        }
    }

    var tagalogTitle: String {
        switch self {
        case .friendly: "Palakaibigan"
        case .familiar: "Barkada"
        case .grumpy: "Masungit"
        case .strict: "Istrikto"
        }
    }

    var icon: String {
        switch self {
        case .friendly: "face.smiling.inverse"
        case .familiar: "hand.wave.fill"
        case .grumpy: "flame.fill"
        case .strict: "graduationcap.fill"
        }
    }

    var summary: String {
        switch self {
        case .friendly: L("Warm and patient. Cheers you on.")
        case .familiar: L("Like an old friend. Casual words, lots of teasing.")
        case .grumpy: L("Short-tempered palengke energy. Keep up!")
        case .strict: L("A demanding teacher. Every mistake gets fixed.")
        }
    }

    var sample: String {
        switch self {
        case .friendly: "Kumusta! Kumusta ang araw mo?"
        case .familiar: "Uy, bes! Ang tagal nating hindi nagkita!"
        case .grumpy: "Ano na naman? Bilisan mo!"
        case .strict: "Ulitin mo. Buong pangungusap."
        }
    }
}

private struct LivePersonalityPicker: View {
    @Binding var selection: LivePersonality
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(L("Tuko's mood"))
                .scaledFont(13, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.muted)
                .textCase(.uppercase)
                .tracking(0.6)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                ForEach(LivePersonality.allCases) { personality in
                    tile(personality)
                }
            }

            VStack(spacing: 3) {
                Text(selection.summary)
                    .scaledFont(14, weight: .semibold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                Text("“\(selection.sample)”")
                    .scaledFont(13, design: .rounded)
                    .italic()
                    .foregroundStyle(KumustaColors.muted)
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(minHeight: 40)
            .id(selection)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82), value: selection)
    }

    private func tile(_ personality: LivePersonality) -> some View {
        let isSelected = personality == selection
        return Button {
            selection = personality
        } label: {
            VStack(spacing: 6) {
                Image(systemName: personality.icon)
                    .scaledFont(18, weight: .bold)
                    .foregroundStyle(isSelected ? Color.white : KumustaColors.accentDeep)
                    .frame(width: 40, height: 40)
                    .background(
                        isSelected ? KumustaColors.accent : KumustaColors.accentSoft.opacity(0.45),
                        in: Circle()
                    )
                Text(personality.title)
                    .scaledFont(13, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(personality.tagalogTitle)
                    .scaledFont(11, weight: .medium, design: .rounded)
                    .foregroundStyle(KumustaColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? KumustaColors.surface : KumustaColors.surface.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? KumustaColors.accent : KumustaColors.line.opacity(0.7),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .tactile()
        .accessibilityLabel("\(personality.title), \(personality.tagalogTitle)")
        .accessibilityHint(personality.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LiveVoiceWaveform: View {
    let level: CGFloat
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 18, paused: !active || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    let oscillation = reduceMotion
                        ? 0.55
                        : (sin(time * 9 + Double(index) * 0.82) + 1) / 2
                    let amplitude = active ? max(0.22, Double(level)) : 0
                    Capsule()
                        .fill(active ? KumustaColors.accent : KumustaColors.line)
                        .frame(width: 4, height: 5 + CGFloat(oscillation * amplitude * 19))
                }
            }
            .animation(.easeOut(duration: 0.18), value: active)
        }
    }
}
