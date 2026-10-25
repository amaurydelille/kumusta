import SwiftUI

/// Routes a review task to its exercise. Each exercise reports what the
/// learner did once (`onAnswered`) and then waits for Continue.
struct ReviewExerciseView: View {
    let task: ReviewTask
    let pool: [MemoryCard]
    let onAnswered: (ReviewAnswer) -> Void
    let onContinue: () -> Void
    let onCantSpeak: () -> Void

    var body: some View {
        switch task.kind {
        case .listenMeaning:
            ReviewChoiceExercise(mode: .meaning, card: task.card, pool: pool, onAnswered: onAnswered, onContinue: onContinue)
        case .pickTagalog:
            ReviewChoiceExercise(mode: .tagalog, card: task.card, pool: pool, onAnswered: onAnswered, onContinue: onContinue)
        case .build:
            if let bank = ReviewBuildExercise.tileBank(for: task.card) {
                ReviewBuildExercise(card: task.card, tileBank: bank, onAnswered: onAnswered, onContinue: onContinue)
            } else {
                ReviewChoiceExercise(mode: .tagalog, card: task.card, pool: pool, onAnswered: onAnswered, onContinue: onContinue)
            }
        case .speak:
            ReviewSpeakExercise(card: task.card, onAnswered: onAnswered, onContinue: onContinue, onCantSpeak: onCantSpeak)
        }
    }
}

extension MemoryCard {
    var audioPurpose: AudioPlaybackPurpose {
        source == .savedWord ? .vocabulary : .lesson
    }
}

// MARK: - Shared pieces

/// The cue for a production exercise: the meaning in a bubble the mascot
/// "says", with the disambiguating hint underneath.
private struct ReviewPromptBubble: View {
    let card: MemoryCard
    let motion: BuddyMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BuddyMotionView(motion: motion, size: 96)
                .padding(.leading, SpeechBubbleShape.tailCenterX - 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(card.translation)
                    .scaledFont(24, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let hint = card.hint {
                    Label(hint, systemImage: "lightbulb.fill")
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background { SpeechBubbleShape().fill(KumustaColors.surface) }
            .overlay { SpeechBubbleShape().stroke(KumustaColors.line, lineWidth: 2) }
            .padding(.top, SpeechBubbleShape.tailHeight)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct ReviewExerciseTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .scaledFont(26, weight: .heavy, design: .rounded)
            .foregroundStyle(KumustaColors.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The bottom sheet after an answer: verdict, the right answer with its
/// audio, and Continue. Green when right, red when not, amber when close.
struct ReviewFeedbackPanel: View {
    enum Verdict { case correct, close, wrong }

    let verdict: Verdict
    let title: String
    let card: MemoryCard
    let autoplaysAnswer: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        switch verdict {
        case .correct: KumustaColors.success
        case .close: KumustaColors.caution
        case .wrong: KumustaColors.error
        }
    }

    private var titleColor: Color {
        switch verdict {
        case .correct: KumustaColors.success
        case .close: KumustaColors.cautionDeep
        case .wrong: KumustaColors.errorDeep
        }
    }

    private var symbol: String {
        switch verdict {
        case .correct: "checkmark.circle.fill"
        case .close: "exclamationmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .scaledFont(28, weight: .bold)
                Text(title)
                    .scaledFont(22, weight: .heavy, design: .rounded)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(titleColor)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.tagalog)
                        .scaledFont(20, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                    Text(card.translation)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                AudioSpeedControls(
                    text: card.tagalog,
                    purpose: card.audioPurpose,
                    showsSpeedChoices: false,
                    iconOnly: true,
                    iconSize: 44,
                    autoplay: autoplaysAnswer
                )
                .fixedSize()
            }

            Button(L("CONTINUE"), action: onContinue)
                .buttonStyle(ReviewContinueButtonStyle(verdict: verdict))
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
    }
}

private struct ReviewContinueButtonStyle: ButtonStyle {
    let verdict: ReviewFeedbackPanel.Verdict

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        switch verdict {
        case .correct:
            KumustaSuccessButtonStyle().makeBody(configuration: configuration)
        case .close, .wrong:
            KumustaPrimaryButtonStyle().makeBody(configuration: configuration)
        }
    }
}

/// Raised answer row; turns green or red after checking, and the right
/// answer lights up even when the learner picked another.
private struct ReviewChoiceRow: View {
    let choice: ReviewExerciseChoice
    let isTagalog: Bool
    let isSelected: Bool
    let isSubmitted: Bool
    let shakeTrigger: Int
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsCorrect: Bool { isSubmitted && choice.isCorrect }
    private var showsWrong: Bool { isSubmitted && isSelected && !choice.isCorrect }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(choice.text)
                    .scaledFont(isTagalog ? 20 : 18, weight: isTagalog ? .bold : .semibold, design: .rounded)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if showsCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .scaledFont(22, weight: .bold)
                        .foregroundStyle(KumustaColors.success)
                        .transition(.scale.combined(with: .opacity))
                } else if showsWrong {
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
        .opacity(isSubmitted && !isSelected && !choice.isCorrect ? 0.5 : 1)
        .keyframeAnimator(
            initialValue: CGFloat.zero,
            trigger: showsWrong && !reduceMotion ? shakeTrigger : 0
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
        .accessibilityLabel(choice.text)
        .accessibilityValue(accessibilityState)
        .accessibilityIdentifier("reviewChoice")
    }

    private var faceColor: Color {
        if showsCorrect { return KumustaColors.success.opacity(0.18) }
        if showsWrong { return KumustaColors.error.opacity(0.16) }
        if isSelected { return KumustaColors.focus.opacity(0.16) }
        return KumustaColors.surface
    }

    private var borderColor: Color {
        if showsCorrect { return KumustaColors.success }
        if showsWrong { return KumustaColors.error }
        if isSelected { return KumustaColors.focus }
        return KumustaColors.line
    }

    private var textColor: Color {
        if showsCorrect { return KumustaColors.success }
        if showsWrong { return KumustaColors.errorDeep }
        if isSelected { return KumustaColors.focus }
        return KumustaColors.ink
    }

    private var accessibilityState: String {
        if showsCorrect { return L("Correct answer") }
        if showsWrong { return L("Not the right answer") }
        return isSelected ? L("Selected") : L("Not selected")
    }
}

/// The CHECK bar shown before an answer is submitted.
private struct ReviewCheckBar<Extra: View>: View {
    let isEnabled: Bool
    let onCheck: () -> Void
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(spacing: 4) {
            Button(L("CHECK"), action: onCheck)
                .buttonStyle(KumustaPrimaryButtonStyle())
                .disabled(!isEnabled)
            extra()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(KumustaColors.canvas)
        .screenContentWidth()
    }
}

private enum ReviewPraise {
    static func random() -> String {
        [L("Nice work!"), L("Correct!"), L("You remembered it!"), L("Spot on!")].randomElement() ?? L("Correct!")
    }
}

// MARK: - Multiple choice

/// Hear the Tagalog and pick the meaning, or see the meaning and pick the
/// Tagalog among look-alikes.
private struct ReviewChoiceExercise: View {
    enum Mode { case meaning, tagalog }

    let mode: Mode
    let card: MemoryCard
    let onAnswered: (ReviewAnswer) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var choices: [ReviewExerciseChoice]
    @State private var selectedID: Int?
    @State private var isSubmitted = false
    @State private var shakeTrigger = 0
    @State private var praise = ReviewPraise.random()
    @State private var startedAt = Date.now

    init(
        mode: Mode,
        card: MemoryCard,
        pool: [MemoryCard],
        onAnswered: @escaping (ReviewAnswer) -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.mode = mode
        self.card = card
        self.onAnswered = onAnswered
        self.onContinue = onContinue
        var generator = SystemRandomNumberGenerator()
        _choices = State(
            initialValue: mode == .meaning
                ? ReviewExercisePlanner.meaningChoices(for: card, pool: pool, using: &generator)
                : ReviewExercisePlanner.tagalogChoices(for: card, pool: pool, using: &generator)
        )
    }

    private var isCorrect: Bool {
        choices.first { $0.id == selectedID }?.isCorrect == true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ReviewExerciseTitle(text: mode == .meaning ? L("What does this mean?") : L("Choose the Tagalog"))

                if mode == .meaning {
                    listenHero
                } else {
                    ReviewPromptBubble(card: card, motion: mascotMotion)
                }

                VStack(spacing: 12) {
                    ForEach(choices) { choice in
                        ReviewChoiceRow(
                            choice: choice,
                            isTagalog: mode == .tagalog,
                            isSelected: selectedID == choice.id,
                            isSubmitted: isSubmitted,
                            shakeTrigger: shakeTrigger
                        ) {
                            withAnimation(reduceMotion ? nil : KumustaMotion.press) {
                                selectedID = choice.id
                            }
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedID)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSubmitted {
                ReviewFeedbackPanel(
                    verdict: isCorrect ? .correct : .wrong,
                    title: isCorrect ? praise : L("Correct answer:"),
                    card: card,
                    // The meaning question already played the phrase.
                    autoplaysAnswer: mode == .tagalog,
                    onContinue: onContinue
                )
            } else {
                ReviewCheckBar(isEnabled: selectedID != nil, onCheck: submit) { EmptyView() }
            }
        }
        .sensoryFeedback(trigger: isSubmitted) { _, submitted in
            guard submitted else { return nil }
            return isCorrect ? .success : .error
        }
    }

    private var mascotMotion: BuddyMotion {
        guard isSubmitted else { return .curious }
        return isCorrect ? .correct : .mistake
    }

    private var listenHero: some View {
        HStack(alignment: .center, spacing: 4) {
            BuddyMotionView(motion: mascotMotion, size: 112)
                .accessibilityHidden(true)

            AudioSpeedControls(
                text: card.tagalog,
                purpose: card.audioPurpose,
                iconOnly: true,
                iconSize: 72,
                autoplay: true,
                forceAutoplay: true
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background { SpeechBubbleShape(tailEdge: .leading).fill(KumustaColors.surface) }
            .overlay { SpeechBubbleShape(tailEdge: .leading).stroke(KumustaColors.line, lineWidth: 2) }
            .padding(.leading, SpeechBubbleShape.tailHeight)
        }
    }

    private func submit() {
        guard selectedID != nil, !isSubmitted else { return }
        let correct = isCorrect
        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
            isSubmitted = true
            shakeTrigger += 1
        }
        if correct {
            SuccessFeedbackPlayer.shared.play()
        } else {
            WrongFeedbackPlayer.shared.play()
        }
        onAnswered(
            ReviewAnswer(
                correctOnFirstAttempt: correct,
                eventuallyCorrect: correct,
                responseSeconds: Date.now.timeIntervalSince(startedAt)
            )
        )
    }
}

// MARK: - Build from tiles

/// See the meaning and rebuild the Tagalog from syllable tiles mixed with
/// look-alike words. A wrong check marks the bad tiles in red so the
/// learner can fix them once before revealing the answer.
private struct ReviewBuildExercise: View {
    let card: MemoryCard
    let tileBank: ListenTileBank
    let onAnswered: (ReviewAnswer) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pickedTileIDs: [Int?]
    @State private var wrongPositions: Set<Int> = []
    @State private var attempts = 0
    @State private var outcome: ReviewFeedbackPanel.Verdict?
    @State private var praise = ReviewPraise.random()
    @State private var startedAt = Date.now

    init(
        card: MemoryCard,
        tileBank: ListenTileBank,
        onAnswered: @escaping (ReviewAnswer) -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.card = card
        self.tileBank = tileBank
        self.onAnswered = onAnswered
        self.onContinue = onContinue
        _pickedTileIDs = State(initialValue: Array(repeating: nil, count: tileBank.answer.count))
    }

    static func tileBank(for card: MemoryCard) -> ListenTileBank? {
        var generator = SystemRandomNumberGenerator()
        return ListenTileBank.make(
            sentence: card.tagalog,
            distractorCount: ListenTileBank.distractorCount(forSyllables: card.syllableCount),
            using: &generator
        )
    }

    private var isFilled: Bool { !pickedTileIDs.contains(nil) }
    private var filledCount: Int { pickedTileIDs.compactMap { $0 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ReviewExerciseTitle(text: L("Build it in Tagalog"))
                ReviewPromptBubble(card: card, motion: mascotMotion)
                builder
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let outcome {
                ReviewFeedbackPanel(
                    verdict: outcome,
                    title: outcome == .correct ? praise : outcome == .close ? L("Got there!") : L("Correct answer:"),
                    card: card,
                    autoplaysAnswer: true,
                    onContinue: onContinue
                )
            } else {
                ReviewCheckBar(isEnabled: isFilled, onCheck: check) {
                    Button(L("Show me the answer"), action: reveal)
                        .scaledFont(15, weight: .semibold, design: .rounded)
                        .foregroundStyle(KumustaColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: filledCount)
    }

    private var mascotMotion: BuddyMotion {
        switch outcome {
        case .correct, .close: .correct
        case .wrong: .mistake
        case nil: wrongPositions.isEmpty ? .curious : .mistake
        }
    }

    private var builder: some View {
        VStack(alignment: .center, spacing: 22) {
            WordWrapLayout(horizontalSpacing: 5, verticalSpacing: 8, centered: true) {
                ForEach(tileBank.answer.indices, id: \.self) { position in
                    if let pickedID = pickedTileIDs[position], let tile = tileBank.tile(id: pickedID) {
                        Button {
                            unpick(at: position)
                        } label: {
                            Text(tile.text)
                                .scaledFont(24, weight: .bold, design: .rounded)
                        }
                        .buttonStyle(ListenTileButtonStyle(isWrong: wrongPositions.contains(position)))
                        .disabled(outcome != nil)
                        .accessibilityLabel(tile.text)
                        .accessibilityHint(L("Removes this word"))
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
                            .accessibilityHidden(true)
                    }
                }
            }
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: reduceMotion ? 0 : attempts) { view, offset in
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

            if !wrongPositions.isEmpty, outcome == nil {
                Text(L("The red words don't match, often a look-alike word. Fix them and check again."))
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
                        pick(tile)
                    } label: {
                        Text(tile.text)
                            .scaledFont(20, weight: .semibold, design: .rounded)
                            .opacity(isPicked ? 0 : 1)
                    }
                    .buttonStyle(ListenTileButtonStyle(isGhost: isPicked))
                    .disabled(isPicked || isFilled || outcome != nil)
                    .accessibilityHidden(isPicked)
                    .accessibilityIdentifier("reviewTile")
                    .accessibilityLabel(tile.text)
                    .accessibilityHint(L("Adds this word to your sentence"))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pick(_ tile: ListenTile) {
        guard let slot = pickedTileIDs.firstIndex(of: nil) else { return }
        WordSelectFeedbackPlayer.shared.play(step: filledCount, slotCount: tileBank.answer.count)
        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
            pickedTileIDs[slot] = tile.id
        }
    }

    private func unpick(at position: Int) {
        withAnimation(reduceMotion ? nil : KumustaMotion.press) {
            pickedTileIDs[position] = nil
            wrongPositions.remove(position)
        }
    }

    private func check() {
        guard isFilled, outcome == nil else { return }
        let wrong = tileBank.wrongPositions(for: pickedTileIDs)
        attempts += 1
        if wrong.isEmpty {
            SuccessFeedbackPlayer.shared.play()
            finish(verdict: attempts == 1 ? .correct : .close, gaveUp: false)
        } else if attempts >= 2 {
            WrongFeedbackPlayer.shared.play()
            withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
                wrongPositions = Set(wrong)
            }
            finish(verdict: .wrong, gaveUp: false)
        } else {
            WrongFeedbackPlayer.shared.play()
            withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
                wrongPositions = Set(wrong)
            }
        }
    }

    private func reveal() {
        guard outcome == nil else { return }
        finish(verdict: .wrong, gaveUp: true)
    }

    private func finish(verdict: ReviewFeedbackPanel.Verdict, gaveUp: Bool) {
        withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
            outcome = verdict
        }
        onAnswered(
            ReviewAnswer(
                correctOnFirstAttempt: verdict == .correct,
                eventuallyCorrect: verdict != .wrong,
                gaveUp: gaveUp,
                responseSeconds: Date.now.timeIntervalSince(startedAt)
            )
        )
    }
}

// MARK: - Speak from memory

/// See the meaning and say the Tagalog without seeing it. The phrase is
/// only revealed after an attempt, so this tests recall, not reading.
private struct ReviewSpeakExercise: View {
    let card: MemoryCard
    let onAnswered: (ReviewAnswer) -> Void
    let onContinue: () -> Void
    let onCantSpeak: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @State private var recorder = SpeakingRecorder()
    @State private var feedbackState: SpeechFeedbackState = .idle
    @State private var feedbackTask: Task<Void, Never>?
    @State private var isPreparingToRecord = false
    @State private var attempts = 0
    @State private var outcome: ReviewFeedbackPanel.Verdict?
    @State private var praise = ReviewPraise.random()
    @State private var startedAt = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReviewExerciseTitle(
                    text: feedbackState.isProcessing ? L("Checking your take…") : L("Say it in Tagalog")
                )
                ReviewPromptBubble(card: card, motion: mascotMotion)

                if let errorMessage = recorder.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.errorDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if recorder.permissionState == .denied {
                    OpenSettingsButton()
                }
                if outcome == nil, feedbackState.hasResult || feedbackState.isFailed {
                    SpeechFeedbackCard(
                        state: feedbackState,
                        isCorrect: false,
                        showsRetryButton: false,
                        onRetry: resetAttempt
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .screenContentWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let outcome {
                ReviewFeedbackPanel(
                    verdict: outcome,
                    title: title(for: outcome),
                    card: card,
                    autoplaysAnswer: outcome != .correct,
                    onContinue: onContinue
                )
            } else {
                speakingFooter
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: recorder.isRecording)
        .onChange(of: recorder.hasRecording) { _, hasRecording in
            if hasRecording { evaluate() }
        }
        .onDisappear {
            feedbackTask?.cancel()
            recorder.cleanup()
        }
    }

    private func title(for verdict: ReviewFeedbackPanel.Verdict) -> String {
        switch verdict {
        case .correct: praise
        case .close: L("Keep practicing this one")
        case .wrong: L("Here’s how to say it")
        }
    }

    private var mascotMotion: BuddyMotion {
        if feedbackState.isProcessing { return .reviewing }
        switch outcome {
        case .correct: return .correct
        case .close, .wrong: return .mistake
        case nil: return recorder.isRecording ? .listening : .curious
        }
    }

    private var speakingFooter: some View {
        VStack(spacing: 5) {
            if feedbackState.isProcessing || recorder.isFinishingRecording || recorder.hasRecording {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(L("Checking your Tagalog…"))
                }
                .font(KumustaTypography.bodyStrong)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(KumustaColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if feedbackState.hasResult {
                Button(L("Try speaking again"), action: resetAttempt)
                    .buttonStyle(KumustaPrimaryButtonStyle())
                secondaryButton(L("Continue")) { finish(verdict: .close, gaveUp: false) }
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
                .disabled(isPreparingToRecord)
                .accessibilityLabel(recorder.isRecording ? L("Stop recording") : L("Start recording"))
                .accessibilityHint(L("Your recording is checked automatically when you finish"))

                if !recorder.isRecording {
                    HStack(spacing: 8) {
                        secondaryButton(L("Can’t speak now")) {
                            feedbackTask?.cancel()
                            recorder.cleanup()
                            onCantSpeak()
                        }
                        secondaryButton(L("I don’t remember")) { finish(verdict: .wrong, gaveUp: true) }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(KumustaColors.canvas)
        .screenContentWidth()
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .scaledFont(14, weight: .heavy, design: .rounded)
                .scaledTracking(0.8, forPointSize: 14)
                .foregroundStyle(KumustaColors.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel(title)
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

    private func evaluate() {
        guard !feedbackState.isProcessing else { return }
        let audio: Data
        do {
            audio = try recorder.recordingData()
        } catch {
            recorder.discardCurrentRecording()
            feedbackState = .failed(L("That take isn’t available anymore. Please record it once more."))
            return
        }
        guard let speechService = dependencies.speechRecognitionService else {
            onCantSpeak()
            return
        }
        let live = recorder.takeLiveTranscription()
        recorder.discardCurrentRecording()
        attempts += 1
        feedbackState = .processing
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            let result = await PronunciationFeedbackEngine.evaluate(
                audio: audio,
                live: live,
                targetPhrase: card.tagalog,
                speechService: speechService
            )
            guard !Task.isCancelled, result.state != .idle else { return }
            feedbackState = result.state
            if result.matchedTarget {
                SuccessFeedbackPlayer.shared.play(showsSuccessBorder: true)
                finish(verdict: attempts == 1 ? .correct : .close, gaveUp: false)
            } else if result.state.hasResult {
                WrongFeedbackPlayer.shared.play()
            }
        }
    }

    private func resetAttempt() {
        feedbackTask?.cancel()
        feedbackTask = nil
        feedbackState = .idle
        recorder.stopPlayback()
        recorder.discardCurrentRecording()
    }

    private func finish(verdict: ReviewFeedbackPanel.Verdict, gaveUp: Bool) {
        guard outcome == nil else { return }
        recorder.stopRecording()
        withAnimation(KumustaMotion.screen) {
            outcome = verdict
        }
        onAnswered(
            ReviewAnswer(
                correctOnFirstAttempt: verdict == .correct,
                eventuallyCorrect: verdict != .wrong,
                gaveUp: gaveUp,
                responseSeconds: Date.now.timeIntervalSince(startedAt)
            )
        )
    }
}
