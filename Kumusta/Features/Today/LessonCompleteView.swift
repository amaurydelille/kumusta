import SwiftUI

/// End-of-lesson celebration with the session tune-up folded in: fanfare,
/// confetti and stats first, then the two quick feedback questions and a
/// single Continue button.
struct LessonCompleteView: View {
    let roundCount: Int
    let minutes: Int
    let chunkCount: Int
    /// XP the server granted; nil while pending, 0 when none was granted.
    let awardedXP: Int?
    let onContinue: (SessionFeedback) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsTitle = false
    @State private var visibleStatCount = 0
    @State private var displayedXP = 0
    @State private var showsFeedback = false
    @State private var confettiBurst = 0
    @State private var difficulty: LessonDifficultyFeedback?
    @State private var audioPace: AudioPaceFeedback?
    @State private var hasSubmitted = false
    @State private var didGiveUpOnXP = false

    /// How long to wait for the XP award before treating it as none.
    private static let xpWait: Duration = .seconds(4)

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    statCards
                    if showsFeedback {
                        feedbackCard
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .move(edge: .bottom).combined(with: .opacity)
                            )
                    }
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
            continueBar
        }
        .sensoryFeedback(.success, trigger: confettiBurst)
        .sensoryFeedback(.selection, trigger: difficulty)
        .sensoryFeedback(.selection, trigger: audioPace)
        .task { await celebrate() }
        .onChange(of: awardedXP) { _, xp in
            revealXP(xp)
        }
    }

    // MARK: Celebration

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KumustaColors.caution.opacity(0.22))
                    .frame(width: 138, height: 138)
                    .scaleEffect(showsTitle || reduceMotion ? 1 : 0.6)
                Circle()
                    .stroke(KumustaColors.caution.opacity(0.35), lineWidth: 3)
                    .frame(width: 162, height: 162)
                    .scaleEffect(showsTitle || reduceMotion ? 1 : 0.7)
                    .opacity(showsTitle ? 1 : 0)
                BuddyMotionView(motion: .correct, size: 118)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(L("Lesson complete!"))
                    .scaledFont(30, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.caution)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(L(one: "You handled %lld real-life situation in Vietnamese.", other: "You handled %lld real-life situations in Vietnamese.", count: roundCount))
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .scaleEffect(showsTitle || reduceMotion ? 1 : 0.7)
            .opacity(showsTitle ? 1 : 0)
        }
    }

    private var showsXPCard: Bool {
        if let awardedXP { return awardedXP > 0 }
        return !didGiveUpOnXP
    }

    private var statCards: some View {
        HStack(spacing: 10) {
            if showsXPCard {
                LessonStatCard(
                    title: L("TOTAL XP"),
                    symbol: "bolt.fill",
                    tint: KumustaColors.caution
                ) {
                    if awardedXP == nil {
                        ProgressView()
                            .tint(KumustaColors.caution)
                    } else {
                        Text("\(displayedXP)")
                            .contentTransition(.numericText(value: Double(displayedXP)))
                    }
                }
                .statCardEntrance(isVisible: visibleStatCount > 0, reduceMotion: reduceMotion)
                .accessibilityLabel(awardedXP.map { L("%lld XP earned", $0) } ?? L("Counting your XP"))
                .transition(.scale.combined(with: .opacity))
            }

            LessonStatCard(
                title: L("SITUATIONS"),
                symbol: "bubble.left.and.bubble.right.fill",
                tint: KumustaColors.focus
            ) {
                Text("\(roundCount)")
            }
            .statCardEntrance(isVisible: visibleStatCount > 1, reduceMotion: reduceMotion)
            .accessibilityLabel(L(one: "%lld situation", other: "%lld situations", count: roundCount))

            LessonStatCard(
                title: chunkCount > 0 ? L("CHUNKS") : L("MINUTES"),
                symbol: chunkCount > 0 ? "square.grid.2x2.fill" : "clock.fill",
                tint: KumustaColors.accent
            ) {
                Text("\(chunkCount > 0 ? chunkCount : minutes)")
            }
            .statCardEntrance(isVisible: visibleStatCount > 2, reduceMotion: reduceMotion)
            .accessibilityLabel(chunkCount > 0 ? L(one: "%lld chunk decoded", other: "%lld chunks decoded", count: chunkCount) : L(one: "%lld minute", other: "%lld minutes", count: minutes))
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: showsXPCard)
    }

    private func celebrate() async {
        guard !showsFeedback else { return }
        LessonFinishedFeedbackPlayer.shared.play()
        confettiBurst += 1

        let spring: Animation? = reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.62)
        withAnimation(spring) { showsTitle = true }
        try? await Task.sleep(for: .milliseconds(450))
        for index in 1...3 {
            withAnimation(spring) { visibleStatCount = index }
            try? await Task.sleep(for: .milliseconds(140))
        }
        revealXP(awardedXP)

        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) {
            showsFeedback = true
        }

        try? await Task.sleep(for: Self.xpWait)
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75)) {
            didGiveUpOnXP = true
        }
    }

    private func revealXP(_ xp: Int?) {
        guard let xp, xp > 0, visibleStatCount > 0, displayedXP != xp else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9)) {
            displayedXP = xp
        }
    }

    // MARK: Feedback

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Tune your next lesson"))
                    .scaledFont(20, weight: .heavy, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                Spacer(minLength: 8)
                Text(L("OPTIONAL"))
                    .scaledFont(11, weight: .heavy, design: .rounded)
                    .scaledTracking(0.8, forPointSize: 11)
                    .foregroundStyle(KumustaColors.muted)
            }

            feedbackRow(title: L("Level")) {
                ForEach(LessonDifficultyFeedback.allCases) { option in
                    FeedbackChip(
                        title: option.title,
                        symbol: difficultySymbol(option),
                        isSelected: difficulty == option
                    ) {
                        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                            difficulty = difficulty == option ? nil : option
                        }
                    }
                }
            }

            feedbackRow(title: L("Voice speed")) {
                ForEach(AudioPaceFeedback.allCases) { option in
                    FeedbackChip(
                        title: option.title,
                        symbol: paceSymbol(option),
                        isSelected: audioPace == option
                    ) {
                        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                            audioPace = audioPace == option ? nil : option
                        }
                    }
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(KumustaColors.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 2)
        }
    }

    private func feedbackRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .scaledFont(15, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.muted)
            HStack(spacing: 8) {
                content()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    // MARK: Continue

    private var continueBar: some View {
        Button(L("CONTINUE")) { submit() }
            .buttonStyle(KumustaSuccessButtonStyle())
            .disabled(!showsFeedback || hasSubmitted)
            .opacity(showsFeedback ? 1 : 0)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(KumustaColors.canvas.opacity(showsFeedback ? 1 : 0))
            .screenContentWidth()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: showsFeedback)
    }

    private func submit() {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        // Unanswered questions keep the current level and voice speed.
        onContinue(
            SessionFeedback(
                difficulty: difficulty ?? .justRight,
                audioPace: audioPace ?? .justRight
            )
        )
    }

    private func difficultySymbol(_ option: LessonDifficultyFeedback) -> String {
        switch option {
        case .tooEasy: "arrow.up.right"
        case .justRight: "checkmark"
        case .tooHard: "arrow.down.right"
        }
    }

    private func paceSymbol(_ option: AudioPaceFeedback) -> String {
        switch option {
        case .tooSlow: "hare.fill"
        case .justRight: "waveform"
        case .tooFast: "tortoise.fill"
        }
    }
}

/// Duolingo-style result tile: a colored title band over a bordered value.
struct LessonStatCard<Value: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder let value: () -> Value

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .scaledFont(11, weight: .heavy, design: .rounded)
                .scaledTracking(0.6, forPointSize: 11)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .scaledFont(17, weight: .bold)
                value()
                    .scaledFont(22, weight: .heavy, design: .rounded)
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(KumustaColors.canvas, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding([.horizontal, .bottom], 2)
        }
        .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
    }
}

extension View {
    func statCardEntrance(isVisible: Bool, reduceMotion: Bool) -> some View {
        scaleEffect(isVisible || reduceMotion ? 1 : 0.5)
            .opacity(isVisible ? 1 : 0)
    }
}

private struct FeedbackChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .scaledFont(17, weight: .bold)
                Text(title)
                    .scaledFont(14, weight: .bold, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(FeedbackChipStyle(isSelected: isSelected, reduceMotion: reduceMotion))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FeedbackChipStyle: ButtonStyle {
    let isSelected: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = 4
        let pressed = configuration.isPressed && !reduceMotion
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let border = isSelected ? KumustaColors.focus : KumustaColors.line
        configuration.label
            .foregroundStyle(isSelected ? KumustaColors.focus : KumustaColors.ink)
            .padding(.horizontal, 6)
            .background(shape.fill(isSelected ? KumustaColors.focus.opacity(0.16) : KumustaColors.surface))
            .background(shape.fill(KumustaColors.canvas))
            .overlay(shape.stroke(border, lineWidth: 2))
            .background(shape.fill(border).offset(y: pressed ? 0 : depth))
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .contentShape(shape)
            .animation(reduceMotion ? nil : KumustaMotion.press, value: configuration.isPressed)
    }
}

/// A one-shot confetti shower drawn on a canvas; each change of `burst` fires
/// a new one. Hidden when Reduce Motion is on.
struct ConfettiBurstView: View {
    let burst: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?
    @State private var pieces: [Piece] = []

    private static let lifetime: TimeInterval = 3.2
    private static let gravity: CGFloat = 820

    private struct Piece {
        let originX: CGFloat
        let velocityX: CGFloat
        let velocityY: CGFloat
        let spin: Double
        let wobble: Double
        let size: CGFloat
        let colorIndex: Int
        let isRound: Bool
        let delay: Double
    }

    private static let palette: [Color] = [
        KumustaColors.caution,
        KumustaColors.accent,
        KumustaColors.success,
        KumustaColors.focus,
        KumustaColors.accentSoft
    ]

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { context in
            Canvas { canvas, size in
                guard let startDate else { return }
                let elapsed = context.date.timeIntervalSince(startDate)
                for piece in pieces {
                    let time = elapsed - piece.delay
                    guard time > 0 else { continue }
                    let x = size.width * piece.originX + piece.velocityX * time
                        + sin(time * piece.wobble) * 12
                    let y = size.height * 0.22 + piece.velocityY * time
                        + 0.5 * Self.gravity * time * time
                    let fade = max(0, min(1, (Self.lifetime - elapsed) / 0.6))
                    guard fade > 0, y < size.height + 30 else { continue }

                    var context = canvas
                    context.opacity = fade
                    context.translateBy(x: x, y: y)
                    context.rotate(by: .radians(piece.spin * time))
                    // Flipping the height fakes a 3D tumble.
                    let height = piece.size * 0.55 * abs(cos(time * piece.wobble))
                    let rect = CGRect(x: -piece.size / 2, y: -height / 2, width: piece.size, height: max(1.5, height))
                    let path = piece.isRound
                        ? Path(ellipseIn: CGRect(x: -piece.size / 3, y: -piece.size / 3, width: piece.size / 1.5, height: piece.size / 1.5))
                        : Path(roundedRect: rect, cornerRadius: 1.5)
                    context.fill(path, with: .color(Self.palette[piece.colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: burst) { _, _ in fire() }
        .onAppear { if burst > 0 { fire() } }
    }

    private func fire() {
        guard !reduceMotion else { return }
        pieces = (0..<90).map { index in
            let fromLeft = index.isMultiple(of: 2)
            return Piece(
                originX: fromLeft ? .random(in: 0.05...0.35) : .random(in: 0.65...0.95),
                velocityX: fromLeft ? .random(in: -40...220) : .random(in: -220...40),
                velocityY: .random(in: -620 ... -260),
                spin: .random(in: -9...9),
                wobble: .random(in: 4...10),
                size: .random(in: 7...12),
                colorIndex: .random(in: 0..<Self.palette.count),
                isRound: .random(in: 0...1) < 0.2,
                delay: .random(in: 0...0.25)
            )
        }
        let start = Date.now
        startDate = start
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.lifetime))
            if startDate == start { startDate = nil }
        }
    }
}

#Preview {
    LessonCompleteView(
        roundCount: 5,
        minutes: 5,
        chunkCount: 12,
        awardedXP: 30
    ) { _ in }
    .background(PaperBackground())
}
