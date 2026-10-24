import SwiftUI

struct SessionFeedbackSheet: View {
    let showsTopicPreference: Bool
    let onSubmit: (SessionFeedback) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var difficulty: LessonDifficultyFeedback?
    @State private var audioPace: AudioPaceFeedback?
    @State private var nextLessonTopic = ""
    @State private var isTopicEditorExpanded = false
    @State private var hasSubmitted = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                KumustaAmbientShapes()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top, spacing: 14) {
                            BuddyMark(size: 76, mood: .listening)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(L("Quick tune-up"))
                                    .font(KumustaTypography.title)
                                    .foregroundStyle(KumustaColors.ink)
                                Text(L("Choose one answer in each section. Your feedback saves automatically."))
                                    .font(KumustaTypography.body)
                                    .foregroundStyle(KumustaColors.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if showsTopicPreference {
                            topicPreferenceSection
                        }

                        feedbackSection(
                            title: L("How was the level?"),
                            subtitle: L("We’ll nudge future words and situations up or down.")
                        ) {
                            adaptiveChoiceGroup(Array(LessonDifficultyFeedback.allCases)) { option in
                                choiceButton(
                                    title: option.title,
                                    symbol: difficultySymbol(option),
                                    isSelected: difficulty == option
                                ) {
                                    difficulty = option
                                    submitIfComplete(difficulty: option, audioPace: audioPace)
                                }
                            }
                        }

                        feedbackSection(
                            title: L("How was the voice pace?"),
                            subtitle: L("This changes the approved ElevenLabs voice speed by one step.")
                        ) {
                            adaptiveChoiceGroup(Array(AudioPaceFeedback.allCases)) { option in
                                choiceButton(
                                    title: option.title,
                                    symbol: paceSymbol(option),
                                    isSelected: audioPace == option
                                ) {
                                    audioPace = option
                                    submitIfComplete(difficulty: difficulty, audioPace: option)
                                }
                            }
                        }

                        Text(feedbackPrompt)
                            .font(KumustaTypography.caption)
                            .foregroundStyle(KumustaColors.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(22)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
    }

    private var topicPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Guide the next lesson"))
                        .font(KumustaTypography.title2)
                        .foregroundStyle(KumustaColors.ink)
                    Text(isTopicEditorExpanded
                        ? L("Optional. Name one real-life situation and we’ll make it your very next lesson.")
                        : L("Let Kumusta choose, or add one real-life situation."))
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.78)) {
                        isTopicEditorExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isTopicEditorExpanded ? "minus" : "plus")
                        .scaledFont(17, weight: .bold)
                        .foregroundStyle(KumustaColors.ink)
                        .frame(width: 42, height: 42)
                        .background(KumustaColors.surface)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(KumustaColors.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTopicEditorExpanded ? L("Hide lesson topic") : L("Add a lesson topic"))
                .accessibilityValue(isTopicEditorExpanded ? L("Expanded") : L("Collapsed"))
            }

            if isTopicEditorExpanded {
                topicEditor
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity)
                    )
            }
        }
    }

    private var topicEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $nextLessonTopic)
                .font(KumustaTypography.body)
                .foregroundStyle(KumustaColors.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 116)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(KumustaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(
                            topicValidationMessage == nil ? KumustaColors.line : KumustaColors.accentDeep,
                            lineWidth: topicValidationMessage == nil ? 1 : 2
                        )
                }
                .accessibilityLabel(L("Optional next lesson topic"))
                .onChange(of: nextLessonTopic) { _, newValue in
                    if newValue.count > NextLessonTopicPreference.maximumLength {
                        nextLessonTopic = String(newValue.prefix(NextLessonTopicPreference.maximumLength))
                    }
                    submitIfComplete(difficulty: difficulty, audioPace: audioPace)
                }
                .overlay(alignment: .topLeading) {
                    if nextLessonTopic.isEmpty {
                        Text(L("For example: Renewing my papers"))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted.opacity(0.82))
                            .padding(.horizontal, 21)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let topicValidationMessage {
                        Text(topicValidationMessage)
                            .foregroundStyle(KumustaColors.accentDeep)
                    } else {
                        Text(L("We use this only as a topic, not as instructions."))
                            .foregroundStyle(KumustaColors.muted)
                    }

                    Spacer(minLength: 8)

                    Text("\(nextLessonTopic.count)/\(NextLessonTopicPreference.maximumLength)")
                        .foregroundStyle(
                            nextLessonTopic.count > NextLessonTopicPreference.maximumLength
                                ? KumustaColors.accentDeep
                                : KumustaColors.muted
                        )
                        .monospacedDigit()
                }
                .font(KumustaTypography.caption)
        }
    }

    private var validatedTopic: String? {
        try? NextLessonTopicPreference.validated(nextLessonTopic)
    }

    private var topicValidationMessage: String? {
        do {
            _ = try NextLessonTopicPreference.validated(nextLessonTopic)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var feedbackPrompt: String {
        if topicValidationMessage != nil {
            return L("Fix or clear the optional topic above to save.")
        }
        if difficulty != nil, audioPace == nil {
            return L("Choose the voice pace to save your feedback.")
        }
        if difficulty == nil, audioPace != nil {
            return L("Choose the lesson level to save your feedback.")
        }
        return L("Your choices save as soon as both questions are answered.")
    }

    private func submitIfComplete(
        difficulty: LessonDifficultyFeedback?,
        audioPace: AudioPaceFeedback?
    ) {
        guard
            !hasSubmitted,
            topicValidationMessage == nil,
            let difficulty,
            let audioPace
        else { return }

        hasSubmitted = true
        onSubmit(
            SessionFeedback(
                difficulty: difficulty,
                audioPace: audioPace,
                nextLessonTopic: validatedTopic
            )
        )
        dismiss()
    }

    private func feedbackSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(KumustaTypography.title2)
                .foregroundStyle(KumustaColors.ink)
            Text(subtitle)
                .font(KumustaTypography.body)
                .foregroundStyle(KumustaColors.muted)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    @ViewBuilder
    private func adaptiveChoiceGroup<Option: Identifiable, Content: View>(
        _ options: [Option],
        @ViewBuilder content: @escaping (Option) -> Content
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                ForEach(options) { option in
                    content(option)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        content(option)
                            .frame(minWidth: 92)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(options) { option in
                        content(option)
                    }
                }
            }
        }
    }

    private func choiceButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    choiceLabel(title: title, symbol: symbol)
                }
                .frame(maxWidth: .infinity, minHeight: 64)

                VStack(spacing: 8) {
                    choiceLabel(title: title, symbol: symbol)
                }
                .frame(maxWidth: .infinity, minHeight: 86)
            }
            .foregroundStyle(isSelected ? .white : KumustaColors.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .background(isSelected ? KumustaColors.accent : KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? KumustaColors.accentDeep : KumustaColors.line, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(L("Feedback saves automatically after both questions are answered"))
    }

    @ViewBuilder
    private func choiceLabel(title: String, symbol: String) -> some View {
        Image(systemName: symbol)
            .scaledFont(21, weight: .bold)
        Text(title)
            .font(KumustaTypography.bodyStrong)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
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

extension View {
    func sessionFeedbackSheet(
        isPresented: Binding<Bool>,
        showsTopicPreference: Bool = true,
        onSubmit: @escaping (SessionFeedback) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            SessionFeedbackSheet(
                showsTopicPreference: showsTopicPreference,
                onSubmit: onSubmit
            )
        }
    }
}

#Preview {
    SessionFeedbackSheet(showsTopicPreference: true) { _ in }
}
