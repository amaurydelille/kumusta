import SwiftUI

private enum WordsSortOption: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case alphabetical = "A–Z"

    var id: Self { self }

    var title: String {
        switch self {
        case .recent: L("Recent")
        case .alphabetical: L("A–Z")
        }
    }
}

struct WordsView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeedRawValue = AudioPreferences.fallbackSpeed.rawValue

    @State private var isShowingReview = false
    @State private var selectedWord: SavedLessonWord?
    @State private var playingWordID: UUID?
    @State private var errorMessage: String?
    @State private var isPreparingReviewAudio = false
    @State private var sortOption: WordsSortOption = .recent

    private var savedWords: [SavedLessonWord] {
        let words = dependencies.savedLessonWordStore.words
            .filter { $0.accent == appState.profile.accent }

        switch sortOption {
        case .recent:
            return words.sorted { $0.savedAt > $1.savedAt }
        case .alphabetical:
            return words.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        }
    }

    private var activeFlashcardWords: [SavedLessonWord] {
        savedWords.filter(\.isInFlashcards)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                KumustaAmbientShapes()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        practiceHero
                        savedLibrary
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                    .screenContentWidth()
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(
                isPresented: $isShowingReview,
                onDismiss: appState.reviewMomentReached
            ) {
                FlashcardReviewView(words: activeFlashcardWords)
                    .overlay { AudioReactiveBorder() }
            }
            .sheet(item: $selectedWord) { word in
                SavedWordDetailView(
                    word: word,
                    onRemove: {
                        dependencies.savedLessonWordStore.remove(id: word.id)
                        dependencies.analytics.track(
                            .vocabularyRemoved,
                            properties: [
                                "screen_name": "saved_vocabulary_detail",
                                "vocabulary_id": word.id.uuidString,
                                "source_lesson_id": word.lessonID.uuidString,
                                "source": "detail_remove"
                            ]
                        )
                        appState.scheduleCloudStateSync()
                        selectedWord = nil
                    }
                )
                .overlay { AudioReactiveBorder() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert(
                L("Audio unavailable"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(L("Close"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? L("Please try again."))
            }
            .onChange(of: sortOption) { _, option in
                dependencies.analytics.track(.featureAction, properties: ["screen_name": "words", "step": "sort_selected", "value": option == .recent ? "recent" : "alphabetical"])
            }
            .onDisappear {
                Task { await dependencies.audioService.stop() }
            }
            .task(id: reviewAudioPreparationID) {
                await prepareReviewAudio()
            }
        }
    }

    private var reviewAudioPreparationID: String {
        [
            appState.profile.accent.rawValue,
            defaultSpeedRawValue,
            activeFlashcardWords.map { $0.id.uuidString }.joined(separator: ",")
        ].joined(separator: "|")
    }

    private func prepareReviewAudio() async {
        guard !activeFlashcardWords.isEmpty else {
            isPreparingReviewAudio = false
            return
        }

        isPreparingReviewAudio = true
        // Cards play with the accent they were saved in, so warm each accent's
        // cache key separately rather than assuming the current profile accent.
        let wordsByAccent = Dictionary(grouping: activeFlashcardWords, by: \.accent)
        let speed = AudioPreferences.speed(from: defaultSpeedRawValue)
        for (accent, words) in wordsByAccent {
            await dependencies.audioService.prewarm(
                texts: words.map(\.word),
                accent: accent,
                speed: speed,
                purpose: .vocabulary
            )
        }
        guard !Task.isCancelled else { return }
        isPreparingReviewAudio = false
    }

    private var practiceHero: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack(alignment: .topTrailing) {
                Text(L("Practice your\nVietnamese words"))
                    .font(KumustaTypography.title)
                    .foregroundStyle(KumustaColors.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 94)

                WordsHeroMark()
                    .frame(width: 112, height: 112)
            }

            Button {
                if !activeFlashcardWords.isEmpty {
                    isShowingReview = true
                }
            } label: {
                Text(activeFlashcardWords.isEmpty ? L("ADD WORDS TO START") : L("START +10 XP"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(KumustaOnboardingButtonStyle())
            .disabled(activeFlashcardWords.isEmpty || isPreparingReviewAudio)
            .accessibilityHint(L("Starts your listening-first flashcard review session"))
        }
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var savedLibrary: some View {
        VStack(alignment: .leading, spacing: 0) {
            if savedWords.isEmpty {
                emptyLibrary
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(L(one: "%lld word", other: "%lld words", count: savedWords.count))
                        .font(KumustaTypography.title2)
                        .foregroundStyle(KumustaColors.ink)

                    Spacer()

                    Menu {
                        ForEach(WordsSortOption.allCases) { option in
                            Button {
                                sortOption = option
                            } label: {
                                Label(option.title, systemImage: sortOption == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Text(L("SORT"))
                            .scaledFont(14, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.accentDeep)
                            .tracking(0.8)
                    }
                    .accessibilityLabel(L("Sort vocabulary"))
                }
                .padding(.bottom, 4)

                Text(L("Swipe rows to add or remove them from flashcards."))
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .padding(.bottom, 8)

                LazyVStack(spacing: 0) {
                    ForEach(savedWords) { word in
                        SavedWordLibraryRow(
                            word: word,
                            isPlaying: playingWordID == word.id,
                            onOpen: {
                                dependencies.analytics.track(
                                    .vocabularyOpened,
                                    properties: [
                                        "screen_name": "words",
                                        "vocabulary_id": word.id.uuidString,
                                        "source_lesson_id": word.lessonID.uuidString
                                    ]
                                )
                                selectedWord = word
                            },
                            onPlay: { play(savedWord: word) },
                            onRetire: {
                                dependencies.savedLessonWordStore.retireFromFlashcards(id: word.id)
                                dependencies.analytics.track(
                                    .vocabularyRemoved,
                                    properties: [
                                        "screen_name": "words",
                                        "vocabulary_id": word.id.uuidString,
                                        "source_lesson_id": word.lessonID.uuidString,
                                        "source": "flashcard_swipe"
                                    ]
                                )
                                appState.scheduleCloudStateSync()
                            },
                            onRestore: {
                                dependencies.savedLessonWordStore.restoreToFlashcards(id: word.id)
                                dependencies.analytics.track(
                                    .vocabularySaved,
                                    properties: [
                                        "screen_name": "words",
                                        "vocabulary_id": word.id.uuidString,
                                        "source_lesson_id": word.lessonID.uuidString,
                                        "source": "flashcard_swipe"
                                    ]
                                )
                                appState.scheduleCloudStateSync()
                            }
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 14) {
                Image(systemName: "bookmark.circle.fill")
                    .scaledFont(27, weight: .semibold)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(width: 54, height: 54)
                    .background(KumustaColors.accentSoft.opacity(0.46))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Nothing saved yet"))
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.ink)
                    Text(L("When a phrase feels useful, tap Save in a lesson. It will appear here with its real context."))
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(L("Save a phrase. Hear it again. Make it yours."))
                .font(KumustaTypography.supportingStrong)
                .foregroundStyle(KumustaColors.accentDeep)
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
    }

    private func play(savedWord: SavedLessonWord) {
        guard playingWordID == nil else { return }
        playingWordID = savedWord.id

        Task { @MainActor in
            defer { playingWordID = nil }
            do {
                try await dependencies.audioService.play(
                    text: savedWord.word,
                    accent: savedWord.accent,
                    speed: AudioPreferences.speed(from: defaultSpeedRawValue),
                    purpose: .vocabulary
                )
                dependencies.analytics.track(
                    .vocabularyAudioPlayed,
                    properties: [
                        "screen_name": "words",
                        "vocabulary_id": savedWord.id.uuidString,
                        "source_lesson_id": savedWord.lessonID.uuidString,
                        "playback_result": "completed"
                    ]
                )
            } catch is CancellationError {
                return
            } catch {
                errorMessage = L("The Vietnamese voice is unavailable right now. Please try again.")
            }
        }
    }
}

private struct WordsHeroMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(KumustaColors.accentSoft.opacity(0.72))
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(18))
                .offset(x: 12, y: 12)

            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(KumustaColors.accent)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "sparkles")
                        .scaledFont(30, weight: .bold)
                        .foregroundStyle(KumustaColors.surface)
                }
        }
        .rotationEffect(.degrees(-3))
        .accessibilityHidden(true)
    }
}

private struct AnimatedSpeakerIcon: View {
    let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isPlaying && !reduceMotion {
            TimelineView(.animation) { context in
                speakerImage
                    .scaleEffect(pulseScale(at: context.date))
                    .opacity(pulseOpacity(at: context.date))
            }
        } else {
            speakerImage
                .scaleEffect(0.92)
                .opacity(0.82)
        }
    }

    private var speakerImage: some View {
        Image(systemName: "speaker.wave.2.fill")
            .scaledFont(24, weight: .semibold)
            .foregroundStyle(KumustaColors.accent)
    }

    private func pulseScale(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 0.48)
        let progress = phase / 0.48
        let wave = (sin(progress * 2 * .pi) + 1) / 2
        return 0.92 + CGFloat(wave) * 0.18
    }

    private func pulseOpacity(at date: Date) -> Double {
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 0.48)
        let progress = phase / 0.48
        let wave = (sin(progress * 2 * .pi) + 1) / 2
        return 0.82 + wave * 0.18
    }
}

private struct SavedWordLibraryRow: View {
    let word: SavedLessonWord
    let isPlaying: Bool
    let onOpen: () -> Void
    let onPlay: () -> Void
    let onRetire: () -> Void
    let onRestore: () -> Void

    private let rowMinHeight: CGFloat = 74

    var body: some View {
        rowContent
        .frame(maxWidth: .infinity, minHeight: rowMinHeight)
        .accessibilityAction(named: Text(word.isInFlashcards ? L("Remove from flashcards") : L("Put back in flashcards"))) {
            if word.isInFlashcards {
                onRetire()
            } else {
                onRestore()
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 16) {
            AnimatedSpeakerIcon(isPlaying: isPlaying)
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isPlaying else { return }
                    onPlay()
                }
                .accessibilityElement()
                .accessibilityLabel(L("Hear %@", word.word))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    guard !isPlaying else { return }
                    onPlay()
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(word.word)
                    .font(KumustaTypography.headline)
                    .foregroundStyle(KumustaColors.ink)
                    .lineLimit(1)

                Text(word.translation)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(L("Opens the saved phrase context"))
            .accessibilityAction {
                onOpen()
            }

            flashcardStatusControl
        }
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KumustaColors.line.opacity(0.72))
                .frame(height: 1)
        }
    }

    private var flashcardStatusControl: some View {
        Circle()
            .fill(word.isInFlashcards ? KumustaColors.accent : KumustaColors.muted)
            .frame(width: 10, height: 10)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleFlashcardStatus()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }

                        if word.isInFlashcards, value.translation.width <= -48 {
                            onRetire()
                        } else if !word.isInFlashcards, value.translation.width >= 48 {
                            onRestore()
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(word.isInFlashcards ? L("In review") : L("Saved only"))
            .accessibilityHint(word.isInFlashcards ? L("Removes this word from flashcards") : L("Adds this word to flashcards"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                toggleFlashcardStatus()
            }
    }

    private func toggleFlashcardStatus() {
        if word.isInFlashcards {
            onRetire()
        } else {
            onRestore()
        }
    }
}

private struct SavedWordDetailView: View {
    let word: SavedLessonWord
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPlaying = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 21) {
                        VStack(alignment: .leading, spacing: 9) {
                            Label(
                                word.isInFlashcards ? L("Active flashcard") : L("Saved · mastered"),
                                systemImage: word.isInFlashcards ? "rectangle.stack.fill" : "checkmark.seal.fill"
                            )
                            .font(KumustaTypography.supportingStrong)
                            .foregroundStyle(word.isInFlashcards ? KumustaColors.accentDeep : KumustaColors.success)

                            Text(word.word)
                                .font(KumustaTypography.vietnameseHero)
                                .foregroundStyle(KumustaColors.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(word.translation)
                                .font(KumustaTypography.title2)
                                .foregroundStyle(KumustaColors.accentDeep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KumustaColors.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))

                        Button {
                            isPlaying = true
                            Task { @MainActor in
                                defer { isPlaying = false }
                                do {
                                    try await dependencies.audioService.play(
                                        text: word.word,
                                        accent: word.accent,
                                        speed: .natural,
                                        purpose: .vocabulary
                                    )
                                    dependencies.analytics.track(
                                        .vocabularyAudioPlayed,
                                        properties: [
                                            "screen_name": "saved_vocabulary_detail",
                                            "vocabulary_id": word.id.uuidString,
                                            "source_lesson_id": word.lessonID.uuidString,
                                            "playback_result": "completed"
                                        ]
                                    )
                                } catch {
                                    dependencies.analytics.track(
                                        .vocabularyAudioPlayed,
                                        properties: [
                                            "screen_name": "saved_vocabulary_detail",
                                            "vocabulary_id": word.id.uuidString,
                                            "source_lesson_id": word.lessonID.uuidString,
                                            "playback_result": "failed"
                                        ]
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if isPlaying {
                                    ProgressView()
                                        .tint(KumustaColors.accentDeep)
                                } else {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .scaledFont(20, weight: .semibold)
                                }

                                Text(isPlaying ? L("Playing Vietnamese") : L("Hear this phrase"))
                                    .font(KumustaTypography.bodyStrong)

                                Spacer()
                            }
                            .foregroundStyle(KumustaColors.accentDeep)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 62)
                            .background(KumustaColors.accentSoft.opacity(0.36))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isPlaying)

                        VStack(alignment: .leading, spacing: 9) {
                            Text(L("In real life"))
                                .font(KumustaTypography.title2)
                                .foregroundStyle(KumustaColors.ink)
                            Text(word.sentence)
                                .font(KumustaTypography.bodyStrong)
                                .foregroundStyle(KumustaColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(word.sentenceTranslation)
                                .font(KumustaTypography.body)
                                .foregroundStyle(KumustaColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KumustaColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(KumustaColors.line, lineWidth: 1)
                        }

                        Button(L("Remove from saved vocabulary"), role: .destructive) {
                            onRemove()
                        }
                        .font(KumustaTypography.supportingStrong)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("Saved phrase"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KumustaColors.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                        .font(KumustaTypography.supportingStrong)
                        .foregroundStyle(KumustaColors.accentDeep)
                }
            }
            .animation(reduceMotion ? nil : KumustaMotion.screen, value: word.isInFlashcards)
            .onDisappear {
                Task { await dependencies.audioService.stop() }
            }
        }
    }
}

private struct FlashcardReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeedRawValue = AudioPreferences.fallbackSpeed.rawValue

    @State private var cards: [SavedLessonWord]
    @State private var direction: FlashcardDirection = .vietnameseAudioToEnglish
    @State private var choices: [FlashcardChoice] = []
    @State private var phase: FlashcardPhase = .listening
    @State private var selectedChoiceID: UUID?
    @State private var isPlaying = false
    @State private var score = 0
    @State private var streak = 0
    @State private var isComplete = false
    @State private var hasStarted = false
    @State private var audioTask: Task<Void, Never>?
    @State private var activeAudioRequestID: UUID?
    @State private var audioErrorMessage: String?
    @State private var telemetrySessionID = UUID()
    @State private var telemetryStartedAt = Date.now
    @State private var cardsPresented = 0
    @State private var cardsAnswered = 0
    @State private var correctAnswers = 0
    @State private var didFinalizeTelemetry = false

    private let totalCount: Int

    init(words: [SavedLessonWord]) {
        let sessionCards = Array(words.shuffled().prefix(10))
        _cards = State(initialValue: sessionCards)
        totalCount = sessionCards.count
    }

    var body: some View {
        ZStack {
            PaperBackground()
            reviewAmbient

            VStack(spacing: 0) {
                reviewTopBar

                if isComplete || cards.isEmpty {
                    completionView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let card = cards.first {
                                sourceCard(for: card)
                                if phase != .listening {
                                    choicesView
                                }
                                if phase == .correct {
                                    correctReward
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 17)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)

                    reviewFooter
                }
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            dependencies.analytics.track(
                .flashcardSessionStarted,
                properties: [
                    "screen_name": "flashcards",
                    "total_cards": String(totalCount)
                ],
                clientSessionID: telemetrySessionID
            )
            Task { await syncFlashcardSession(completed: false, endedAt: nil) }
            prepareCurrentCard()
        }
        .onDisappear {
            activeAudioRequestID = nil
            audioTask?.cancel()
            isPlaying = false
            Task { await dependencies.audioService.stop() }
            guard !didFinalizeTelemetry else { return }
            dependencies.analytics.track(
                .flashcardSessionAbandoned,
                properties: [
                    "screen_name": "flashcards",
                    "total_cards": String(totalCount),
                    "cards_presented": String(cardsPresented),
                    "cards_answered": String(cardsAnswered)
                ],
                clientSessionID: telemetrySessionID
            )
            Task { await syncFlashcardSession(completed: false, endedAt: .now) }
        }
        .alert(
            L("Voice unavailable"),
            isPresented: Binding(
                get: { audioErrorMessage != nil },
                set: { if !$0 { audioErrorMessage = nil } }
            )
        ) {
            Button(L("Retry")) { replayCurrentCard() }
            Button(L("Close"), role: .cancel) { audioErrorMessage = nil }
        } message: {
            Text(audioErrorMessage ?? L("The Vietnamese voice could not be loaded."))
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: phase)
    }

    private var reviewAmbient: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(KumustaColors.accentSoft.opacity(0.18))
                    .frame(width: 270, height: 270)
                    .blur(radius: 4)
                    .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.42)

                Circle()
                    .fill(KumustaColors.focus.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .blur(radius: 10)
                    .offset(x: -proxy.size.width * 0.46, y: proxy.size.height * 0.18)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var reviewTopBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .scaledFont(15, weight: .bold)
                    .foregroundStyle(KumustaColors.ink)
                    .frame(width: 42, height: 42)
                    .background(KumustaColors.surfaceMuted.opacity(0.78))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Close flashcards"))

            VStack(alignment: .leading, spacing: 2) {
                Text(L("PHRASE QUEST"))
                    .scaledFont(12, weight: .bold, design: .rounded)
                    .scaledTracking(1.2, forPointSize: 12)
                    .foregroundStyle(KumustaColors.accentDeep)
                Text(L("Train your ear"))
                    .font(KumustaTypography.supportingStrong)
                    .foregroundStyle(KumustaColors.ink)
            }

            Spacer(minLength: 8)

            if streak > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(streak)")
                }
                .scaledFont(14, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.accentDeep)
                .padding(.horizontal, 9)
                .frame(minHeight: 34)
                .background(KumustaColors.accentSoft.opacity(0.55))
                .clipShape(Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L(one: "%lld answer streak", other: "%lld answer streak", count: streak))
            }

            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(KumustaColors.accent)
                Text("\(score)")
                    .foregroundStyle(KumustaColors.ink)
            }
            .scaledFont(15, weight: .bold, design: .rounded)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(KumustaColors.surfaceMuted.opacity(0.78))
            .clipShape(Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L(one: "%lld experience point", other: "%lld experience points", count: score))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(minHeight: 58)
    }

    @ViewBuilder
    private func sourceCard(for card: SavedLessonWord) -> some View {
        vietnameseAudioCard(for: card)
    }

    private func vietnameseAudioCard(for card: SavedLessonWord) -> some View {
        VStack(spacing: 16) {
            HStack {
                Label(
                    phase == .incorrect ? L("One more rep") : phase == .correct ? L("Locked in") : L("Hear the phrase"),
                    systemImage: phase == .incorrect ? "arrow.uturn.backward" : phase == .correct ? "checkmark" : "waveform"
                )
                .font(KumustaTypography.supportingStrong)
                .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Text("+10 XP")
                    .scaledFont(12, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.88))
                    .clipShape(Capsule())
            }

            Button {
                replayCurrentCard()
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.24), lineWidth: 2)
                        .frame(width: 158, height: 158)
                        .scaleEffect(isPlaying && !reduceMotion ? 1.05 : 1)

                    Circle()
                        .stroke(.white.opacity(0.44), lineWidth: 1.5)
                        .frame(width: 128, height: 128)

                    Circle()
                        .fill(.white)
                        .frame(width: 88, height: 88)

                    Image(systemName: isPlaying ? "waveform" : "speaker.wave.2.fill")
                        .scaledFont(29, weight: .bold)
                        .foregroundStyle(KumustaColors.accentDeep)
                }
            }
            .buttonStyle(.plain)
            .disabled(isPlaying)
            .accessibilityLabel(L("Play phrase audio"))
            .accessibilityHint(L("Tap the speaker to hear this phrase again"))

            if phase == .incorrect || phase == .correct {
                VStack(spacing: 4) {
                    Text(card.word)
                        .font(KumustaTypography.vietnameseHero)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(card.translation)
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isPlaying {
                Text(L("Listen closely"))
                    .font(KumustaTypography.supportingStrong)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(L("Tap the speaker whenever you want a replay"))
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(KumustaColors.accentPanel)

                Circle()
                    .fill(KumustaColors.accent.opacity(0.68))
                    .frame(width: 230, height: 230)
                    .offset(x: 132, y: -96)

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 190, height: 190)
                    .offset(x: -136, y: 108)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1.5)
        }
    }

    private var choicesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Choose your move"))
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                Spacer()
                Text(L("4 choices"))
                    .font(KumustaTypography.supportingStrong)
                    .foregroundStyle(KumustaColors.muted)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)],
                spacing: 11
            ) {
                ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                    FlashcardChoiceButton(
                        index: index,
                        choice: choice,
                        phase: phase,
                        isSelected: selectedChoiceID == choice.id
                    ) {
                        select(choice)
                    }
                    .disabled(!canSelectChoices)
                }
            }
        }
    }

    private var correctReward: some View {
        HStack(alignment: .center, spacing: 12) {
            BuddyMotionView(motion: .correct, size: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(L("Correct ear"))
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                Text(L("+10 XP · back in your phrase bank"))
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.success)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(KumustaColors.success.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var reviewFooter: some View {
        VStack(spacing: 9) {
            switch phase {
            case .listening:
                Label(L("Listening…"), systemImage: "waveform")
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.muted)
                    .frame(maxWidth: .infinity, minHeight: 55)
            case .answering:
                Text(L("Choose the answer to keep your streak alive"))
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .frame(maxWidth: .infinity, minHeight: 55)
            case .incorrect:
                Button {
                    advance()
                } label: {
                    HStack {
                        Text(L("Next word"))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(KumustaPrimaryButtonStyle())
            case .correct:
                Button {
                    advance()
                } label: {
                    HStack {
                        Text(L("Keep the streak going"))
                        Spacer()
                        Text("+10 XP")
                            .scaledFont(13, weight: .bold, design: .rounded)
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(KumustaPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .background(KumustaColors.canvas)
        .overlay(alignment: .top) {
            Divider().overlay(KumustaColors.line)
        }
    }

    private var completionView: some View {
        VStack(spacing: 19) {
            Spacer(minLength: 30)

            BuddyMotionView(motion: .streak, size: 136)

            Text(L("Deck cleared"))
                .font(KumustaTypography.hero)
                .foregroundStyle(KumustaColors.ink)

            Text(L("You earned %lld XP and moved %@ out of the active deck.", score, L(one: "%lld phrase", other: "%lld phrases", count: totalCount)))
                .font(KumustaTypography.body)
                .foregroundStyle(KumustaColors.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(L("Back to my phrase bank")) {
                dismiss()
            }
            .buttonStyle(KumustaPrimaryButtonStyle())
            .padding(.top, 4)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prepareCurrentCard() {
        guard let card = cards.first else {
            isComplete = true
            return
        }

        cardsPresented = min(totalCount, cardsPresented + 1)
        dependencies.analytics.track(
            .flashcardPresented,
            properties: [
                "screen_name": "flashcards",
                "card_id": card.id.uuidString,
                "source_lesson_id": card.lessonID.uuidString,
                "card_index": String(cardsPresented - 1),
                "total_cards": String(totalCount)
            ],
            clientSessionID: telemetrySessionID
        )

        direction = .vietnameseAudioToEnglish
        choices = OfflineVocabularyCandidateBank.choices(for: card, direction: direction)
        selectedChoiceID = nil

        phase = .listening
        playCurrentCard(for: card)
    }

    private func playCurrentCard(for card: SavedLessonWord? = nil) {
        guard let card = card ?? cards.first else { return }
        phase = .listening
        playAudio(for: card, revealsChoices: true)
    }

    private func replayCurrentCard() {
        guard let card = cards.first, phase != .listening else { return }
        playAudio(for: card, revealsChoices: false)
    }

    private func playAudio(for card: SavedLessonWord, revealsChoices: Bool) {
        audioTask?.cancel()
        let requestID = UUID()
        activeAudioRequestID = requestID
        isPlaying = true
        audioErrorMessage = nil

        audioTask = Task { @MainActor in
            let speed = AudioPreferences.speed(from: defaultSpeedRawValue)
            do {
                do {
                    try await dependencies.audioService.playCached(
                        text: card.word,
                        accent: card.accent,
                        speed: speed,
                        purpose: .vocabulary
                    )
                } catch CachedAudioError.notPrewarmed {
                    // Prewarming is best-effort (network, eviction). Fetch this
                    // one card on demand instead of failing on every retry.
                    try await dependencies.audioService.play(
                        text: card.word,
                        accent: card.accent,
                        speed: speed,
                        purpose: .vocabulary
                    )
                }
            } catch is CancellationError {
                trackFlashcardAudio(card, source: revealsChoices ? "initial" : "replay", result: "cancelled")
                settleAudioAttempt(requestID: requestID, revealsChoices: revealsChoices)
                return
            } catch {
                guard activeAudioRequestID == requestID else { return }
                audioErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                trackFlashcardAudio(card, source: revealsChoices ? "initial" : "replay", result: "failed")
                settleAudioAttempt(requestID: requestID, revealsChoices: revealsChoices)
                return
            }

            trackFlashcardAudio(card, source: revealsChoices ? "initial" : "replay", result: "completed")
            settleAudioAttempt(requestID: requestID, revealsChoices: revealsChoices)
        }
    }

    /// Completes only the playback attempt that still owns the UI. Audio can
    /// be stopped by another surface using the shared service, and treating
    /// that cancellation as a no-op would leave this card stuck in Listening.
    private func settleAudioAttempt(requestID: UUID, revealsChoices: Bool) {
        guard activeAudioRequestID == requestID else { return }
        activeAudioRequestID = nil
        isPlaying = false
        if revealsChoices, phase == .listening {
            phase = .answering
        }
    }

    private func select(_ choice: FlashcardChoice) {
        guard canSelectChoices, let card = cards.first else { return }
        selectedChoiceID = choice.id
        cardsAnswered += 1
        if choice.isCorrect {
            correctAnswers += 1
        }
        dependencies.analytics.track(
            .flashcardAnswered,
            properties: [
                "screen_name": "flashcards",
                "card_id": card.id.uuidString,
                "source_lesson_id": card.lessonID.uuidString,
                "is_correct": choice.isCorrect ? "true" : "false",
                "cards_answered": String(cardsAnswered),
                "choice_id": choice.id.uuidString
            ],
            clientSessionID: telemetrySessionID
        )

        if choice.isCorrect {
            phase = .correct
            score += 10
            streak += 1
            dependencies.savedLessonWordStore.retireFromFlashcards(id: card.id)
            appState.scheduleCloudStateSync()
            SuccessFeedbackPlayer.shared.play()

            // Replay the answer through the same request-aware path as the
            // card's initial audio. Stopping/restarting a shared player is an
            // expected cancellation, not a voice failure, and the task must
            // remain owned by this view so advancing or dismissing the session
            // can cancel it cleanly.
            playAudio(for: card, revealsChoices: false)
        } else {
            phase = .incorrect
            streak = 0
            dependencies.savedLessonWordStore.recordFlashcardMiss(id: card.id)
            appState.scheduleCloudStateSync()
            WrongFeedbackPlayer.shared.play()
        }
    }

    private func trackFlashcardAudio(_ card: SavedLessonWord, source: String, result: String) {
        dependencies.analytics.track(
            .flashcardAudioPlayed,
            properties: [
                "screen_name": "flashcards",
                "card_id": card.id.uuidString,
                "source_lesson_id": card.lessonID.uuidString,
                "playback_source": source,
                "playback_result": result
            ],
            clientSessionID: telemetrySessionID
        )
    }

    private func advance() {
        activeAudioRequestID = nil
        audioTask?.cancel()
        isPlaying = false
        cards.removeFirst()
        if cards.isEmpty {
            isComplete = true
            Task { await finalizeFlashcardSession() }
        } else {
            prepareCurrentCard()
        }
    }

    private func syncFlashcardSession(completed: Bool, endedAt: Date?) async {
        guard let remote = dependencies.signedInRepository else { return }
        let activeSeconds = min(
            14_400,
            max(0, Int((endedAt ?? .now).timeIntervalSince(telemetryStartedAt)))
        )
        _ = try? await remote.syncFlashcardSession(
            FlashcardSessionSyncInput(
                clientSessionID: telemetrySessionID,
                startedAt: telemetryStartedAt,
                endedAt: endedAt,
                completed: completed,
                totalCards: totalCount,
                cardsPresented: cardsPresented,
                cardsAnswered: cardsAnswered,
                correctCount: correctAnswers,
                activeSeconds: activeSeconds,
                score: totalCount == 0 ? nil : Double(correctAnswers) / Double(totalCount),
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            )
        )
    }

    private func finalizeFlashcardSession() async {
        guard !didFinalizeTelemetry else { return }
        didFinalizeTelemetry = true
        appState.recordReviewSignal(
            .flashcards(correctCount: correctAnswers, cardCount: totalCount)
        )
        dependencies.analytics.track(
            .flashcardSessionCompleted,
            properties: [
                "screen_name": "flashcards",
                "total_cards": String(totalCount),
                "cards_presented": String(cardsPresented),
                "cards_answered": String(cardsAnswered),
                "correct_count": String(correctAnswers)
            ],
            clientSessionID: telemetrySessionID
        )

        guard let remote = dependencies.signedInRepository else { return }
        let activeSeconds = min(
            14_400,
            max(0, Int(Date.now.timeIntervalSince(telemetryStartedAt)))
        )
        guard let session = try? await remote.syncFlashcardSession(
            FlashcardSessionSyncInput(
                clientSessionID: telemetrySessionID,
                startedAt: telemetryStartedAt,
                endedAt: .now,
                completed: true,
                totalCards: totalCount,
                cardsPresented: cardsPresented,
                cardsAnswered: cardsAnswered,
                correctCount: correctAnswers,
                activeSeconds: activeSeconds,
                score: totalCount == 0 ? nil : Double(correctAnswers) / Double(totalCount),
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            )
        ) else { return }

        _ = try? await remote.awardXP(
            XPAwardRequest(
                reasonCode: "vocabulary_flashcard_session_completed",
                sourceID: session.id.uuidString,
                idempotencyKey: "vocabulary_flashcard_session_completed:\(session.id.uuidString)",
                metadata: [
                    "total_cards": String(totalCount),
                    "correct_count": String(correctAnswers)
                ]
            )
        )
        await appState.syncDailyProgress()
    }

    private var canSelectChoices: Bool {
        phase == .answering
    }

}

private enum FlashcardPhase: Equatable {
    case listening
    case answering
    case incorrect
    case correct
}

private struct FlashcardChoiceButton: View {
    let index: Int
    let choice: FlashcardChoice
    let phase: FlashcardPhase
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 9) {
                Text(optionLabel)
                    .scaledFont(12, weight: .bold, design: .rounded)
                    .foregroundStyle(textColor)
                    .frame(width: 25, height: 25)
                    .background(textColor.opacity(0.12))
                    .clipShape(Circle())

                Text(choice.text)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if phase == .correct, isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KumustaColors.success)
                } else if phase == .incorrect, isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KumustaColors.accentDeep)
                } else if phase == .incorrect, choice.isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KumustaColors.success)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
        }
        .buttonStyle(FlashcardChoiceButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var optionLabel: String {
        ["A", "B", "C", "D"][min(index, 3)]
    }

    private var textColor: Color {
        if phase == .incorrect, choice.isCorrect { return KumustaColors.success }
        if isSelected { return KumustaColors.accentDeep }
        return KumustaColors.ink
    }

    private var backgroundColor: Color {
        if phase == .correct, isSelected { return KumustaColors.success.opacity(0.15) }
        if phase == .incorrect, isSelected { return KumustaColors.accentSoft.opacity(0.4) }
        if phase == .incorrect, choice.isCorrect { return KumustaColors.success.opacity(0.15) }
        return KumustaColors.surface
    }

    private var borderColor: Color {
        if phase == .correct, isSelected { return KumustaColors.success }
        if phase == .incorrect, isSelected { return KumustaColors.accentDeep }
        if phase == .incorrect, choice.isCorrect { return KumustaColors.success }
        if isSelected { return KumustaColors.accent }
        return KumustaColors.line
    }

    private var borderWidth: CGFloat {
        isSelected || (phase == .incorrect && choice.isCorrect) ? 2 : 1
    }
}

private struct FlashcardChoiceButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .animation(reduceMotion ? nil : KumustaMotion.press, value: configuration.isPressed)
    }
}
