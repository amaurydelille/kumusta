import SwiftUI

struct FirstStepsOfferView: View {
    let onStart: () -> Void
    let onSkip: () -> Void
    let onSeen: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PaperBackground()
            KumustaAmbientShapes()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        KumustaEyebrow(text: L("YOUR FIRST LESSON"))
                        Spacer()
                        Image(systemName: "sparkles")
                            .scaledFont(19, weight: .bold)
                            .foregroundStyle(KumustaColors.accentDeep)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(L("Say your first words today."))
                            .font(KumustaTypography.hero)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L("Hear the sounds, learn three phrases, then use them in a real mini-conversation with Tuko."))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(KumustaColors.surfaceStrong)
                            .frame(height: 190)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach([34, 58, 42, 84, 66, 112, 94], id: \.self) { height in
                                Capsule()
                                    .fill(KumustaColors.accent.opacity(height > 80 ? 0.95 : 0.5))
                                    .frame(width: 14, height: CGFloat(height))
                            }
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 26)

                        BuddyMark(size: 142, mood: .listening)
                            .offset(x: -24, y: 14)
                    }
                    .overlay(alignment: .topLeading) {
                        Label(L("Hear it. Say it. Use it."), systemImage: "waveform")
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.accentDeep)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(KumustaColors.canvas.opacity(0.9))
                            .clipShape(Capsule())
                            .padding(18)
                    }

                    HStack(spacing: 10) {
                        offerFeature(symbol: "ear.fill", title: L("Hear"), detail: L("Catch the sounds"))
                        offerFeature(symbol: "mic.fill", title: L("Speak"), detail: L("Say it out loud"))
                        offerFeature(symbol: "bubble.left.and.bubble.right.fill", title: L("Chat"), detail: L("Talk with Tuko"))
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(KumustaColors.success)
                        Text(L("About 6 minutes · 3 phrases · 1 real conversation"))
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.muted)
                    }

                    VStack(spacing: 12) {
                        Button(L("Start my first lesson")) {
                            dependencies.analytics.track(.featureAction, properties: ["screen_name": "first_steps_offer", "step": "started"])
                            onStart()
                        }
                            .buttonStyle(KumustaPrimaryButtonStyle())

                        Button(L("Skip for now")) {
                            dependencies.analytics.track(.featureAction, properties: ["screen_name": "first_steps_offer", "step": "skipped"])
                            onSkip()
                        }
                            .buttonStyle(KumustaSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 34)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: reduceMotion)
        .onAppear {
            dependencies.analytics.track(.screenViewed, properties: ["screen_name": "first_steps_offer"])
            onSeen()
        }
    }

    private func offerFeature(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .scaledFont(17, weight: .bold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 38, height: 38)
                .background(KumustaColors.accentSoft.opacity(0.45))
                .clipShape(Circle())
            Text(title)
                .font(KumustaTypography.bodyStrong)
                .foregroundStyle(KumustaColors.ink)
            Text(detail)
                .font(KumustaTypography.caption)
                .foregroundStyle(KumustaColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(KumustaColors.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
    }
}

private struct FirstStepsReferencePair: Identifiable {
    let id: String
    let tagalog: String
    let meaning: String

    init(tagalog: String, meaning: String) {
        id = tagalog
        self.tagalog = tagalog
        self.meaning = meaning
    }
}

private struct FirstStepsCheatSheetEntry: Identifiable {
    let id: String
    let title: String
    let explanation: String
    let example: String?
    let translation: String?
    let usesSystemSpeech: Bool
    let bundledAudioResourceName: String?
    let referencePairs: [FirstStepsReferencePair]?
    let referenceAudioText: String?

    init(
        id: String,
        title: String,
        explanation: String,
        example: String? = nil,
        translation: String? = nil,
        usesSystemSpeech: Bool = false,
        bundledAudioResourceName: String? = nil,
        referencePairs: [FirstStepsReferencePair]? = nil,
        referenceAudioText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.example = example
        self.translation = translation
        self.usesSystemSpeech = usesSystemSpeech
        self.bundledAudioResourceName = bundledAudioResourceName
        self.referencePairs = referencePairs
        self.referenceAudioText = referenceAudioText
    }
}

private struct FirstStepsCheatSheetSection: Identifiable {
    let id: String
    let title: String
    let summary: String
    let symbol: String
    let entries: [FirstStepsCheatSheetEntry]

    static var all: [FirstStepsCheatSheetSection] { [
        FirstStepsCheatSheetSection(
            id: "vowels",
            title: L("Five clear vowels"),
            summary: L("Tagalog is read the way it is written. Every letter is pronounced."),
            symbol: "textformat.abc",
            entries: [
                FirstStepsCheatSheetEntry(
                    id: "vowel-shapes",
                    title: "a · e · i · o · u",
                    explanation: L("Each vowel keeps one short, clean sound, and two vowels side by side are both said."),
                    example: "ama · ewan · isda · oras · ulan",
                    translation: "father · don’t know · fish · time · rain"
                ),
            ]
        ),
        FirstStepsCheatSheetSection(
            id: "ng",
            title: L("The ng sound"),
            summary: L("Ng is one sound, like the end of “sing”, even at the start of a word."),
            symbol: "link",
            entries: [
                FirstStepsCheatSheetEntry(
                    id: "ng-start",
                    title: "ng · mga",
                    explanation: L("Start words with the “sing” sound. Mga, the plural marker, is said “ma-NGA”."),
                    example: "ngayon · ngiti · mga bata",
                    translation: "now · smile · children"
                ),
            ]
        ),
        FirstStepsCheatSheetSection(
            id: "stress",
            title: L("Stress changes the word"),
            summary: L("Tagalog is written without stress marks, but where the stress falls can change the meaning."),
            symbol: "waveform.path.ecg",
            entries: [
                FirstStepsCheatSheetEntry(
                    id: "stress-pairs",
                    title: "",
                    explanation: "",
                    referencePairs: [
                        FirstStepsReferencePair(tagalog: "BU-hay", meaning: "life"),
                        FirstStepsReferencePair(tagalog: "bu-HAY", meaning: "alive"),
                        FirstStepsReferencePair(tagalog: "A-so", meaning: "dog"),
                        FirstStepsReferencePair(tagalog: "a-SO", meaning: "smoke")
                    ]
                ),
                FirstStepsCheatSheetEntry(
                    id: "glottal-catch",
                    title: L("The little catch"),
                    explanation: L("Many words end with a short catch in the throat, like the break in “uh-oh”."),
                    example: "bata · oo · hindi",
                    translation: "child · yes · no"
                )
            ]
        ),
        FirstStepsCheatSheetSection(
            id: "respect",
            title: L("Respect: po and opo"),
            summary: L("Filipinos show respect in the words themselves. Use it with elders, strangers and anyone serving you."),
            symbol: "hand.raised.fill",
            entries: [
                FirstStepsCheatSheetEntry(
                    id: "respect-po",
                    title: "po · opo",
                    explanation: L("Add po to sound respectful. Opo is a respectful yes."),
                    example: "Salamat po. · Opo.",
                    translation: "Thank you. · Yes. (both respectful)"
                ),
                FirstStepsCheatSheetEntry(
                    id: "respect-kayo",
                    title: "ka · kayo",
                    explanation: L("Say kayo instead of ka to one older person; ka is for friends and peers."),
                    example: "Kumusta po kayo?",
                    translation: "How are you? (respectful)"
                )
            ]
        ),
        FirstStepsCheatSheetSection(
            id: "people",
            title: L("People words"),
            summary: L("Pronouns and the names you call family and older people."),
            symbol: "person.2.fill",
            entries: [
                FirstStepsCheatSheetEntry(
                    id: "people-pronouns",
                    title: "",
                    explanation: "",
                    referencePairs: [
                        FirstStepsReferencePair(tagalog: "ako", meaning: "I / me"),
                        FirstStepsReferencePair(tagalog: "ikaw · ka", meaning: "you"),
                        FirstStepsReferencePair(tagalog: "siya", meaning: "he / she"),
                        FirstStepsReferencePair(tagalog: "tayo", meaning: "we (with you)"),
                        FirstStepsReferencePair(tagalog: "kami", meaning: "we (not you)"),
                        FirstStepsReferencePair(tagalog: "kayo", meaning: "you all / you (respectful)"),
                        FirstStepsReferencePair(tagalog: "sila", meaning: "they")
                    ],
                    referenceAudioText: "ako · ikaw · siya · tayo · kami · kayo · sila"
                ),
                FirstStepsCheatSheetEntry(
                    id: "people-family",
                    title: "",
                    explanation: "",
                    referencePairs: [
                        FirstStepsReferencePair(tagalog: "Kuya", meaning: "older brother / older guy"),
                        FirstStepsReferencePair(tagalog: "Ate", meaning: "older sister / older woman"),
                        FirstStepsReferencePair(tagalog: "Lola · Lolo", meaning: "grandma · grandpa"),
                        FirstStepsReferencePair(tagalog: "Tita · Tito", meaning: "auntie · uncle")
                    ],
                    referenceAudioText: "Kuya · Ate · Lola · Lolo · Tita · Tito"
                )
            ]
        ),
        FirstStepsCheatSheetSection(
            id: "numbers",
            title: L("Numbers"),
            summary: L("Count in Tagalog, but expect Spanish-derived numbers for prices and the time."),
            symbol: "123.rectangle.fill",
            entries: [
                FirstStepsCheatSheetEntry(
                    id: "numbers-one-to-ten",
                    title: "",
                    explanation: "",
                    referencePairs: [
                        FirstStepsReferencePair(tagalog: "isa", meaning: "1"),
                        FirstStepsReferencePair(tagalog: "dalawa", meaning: "2"),
                        FirstStepsReferencePair(tagalog: "tatlo", meaning: "3"),
                        FirstStepsReferencePair(tagalog: "apat", meaning: "4"),
                        FirstStepsReferencePair(tagalog: "lima", meaning: "5"),
                        FirstStepsReferencePair(tagalog: "anim", meaning: "6"),
                        FirstStepsReferencePair(tagalog: "pito", meaning: "7"),
                        FirstStepsReferencePair(tagalog: "walo", meaning: "8"),
                        FirstStepsReferencePair(tagalog: "siyam", meaning: "9"),
                        FirstStepsReferencePair(tagalog: "sampu", meaning: "10")
                    ],
                    referenceAudioText: "isa · dalawa · tatlo · apat · lima · anim · pito · walo · siyam · sampu"
                ),
                FirstStepsCheatSheetEntry(
                    id: "numbers-prices",
                    title: "",
                    explanation: "",
                    referencePairs: [
                        FirstStepsReferencePair(tagalog: "bente", meaning: "20 (pesos)"),
                        FirstStepsReferencePair(tagalog: "singkwenta", meaning: "50 (pesos)"),
                        FirstStepsReferencePair(tagalog: "isang daan", meaning: "100"),
                        FirstStepsReferencePair(tagalog: "isang libo", meaning: "1,000"),
                        FirstStepsReferencePair(tagalog: "alas-tres", meaning: "3 o’clock")
                    ],
                    referenceAudioText: "bente · singkwenta · isang daan · isang libo · alas-tres"
                )
            ]
        )
    ] }
}

private struct FirstStepsCheatSheetView: View {
    struct Replay: Identifiable {
        let file: String
        let title: String
        let detail: String
        let symbol: String

        var id: String { file }
    }

    let replays: [Replay]
    let onReplay: (String) -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                KumustaEyebrow(text: L("BASICS CHEAT SHEET"))

                HStack {
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 9)
            .padding(.bottom, 8)
            .screenContentWidth()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(L("Tagalog basics, at a glance"))
                            .font(KumustaTypography.title)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label(L("Your reference for sounds, respect words, people words, and numbers. Tap any example to hear it."), systemImage: "ear.fill")
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KumustaColors.accentSoft.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(FirstStepsCheatSheetSection.all) { section in
                            sectionView(section)
                        }
                    }

                    replaySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            dependencies.analytics.track(.screenViewed, properties: ["screen_name": "first_steps_cheat_sheet"])
        }
    }

    private var replaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "arrow.counterclockwise")
                    .scaledFont(17, weight: .bold)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(width: 38, height: 38)
                    .background(KumustaColors.accentSoft.opacity(0.44))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Replay your lessons"))
                        .font(KumustaTypography.title2)
                        .foregroundStyle(KumustaColors.ink)
                    Text(L("Run them again any time. Tuko checks every word."))
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(replays) { replay in
                Button {
                    onReplay(replay.file)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: replay.symbol)
                            .scaledFont(18, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(KumustaColors.focusFill))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(replay.title)
                                .font(KumustaTypography.bodyStrong)
                                .foregroundStyle(KumustaColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(replay.detail)
                                .font(KumustaTypography.supporting)
                                .foregroundStyle(KumustaColors.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.fill")
                            .foregroundStyle(KumustaColors.focus)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ChoiceCardButtonStyle(face: KumustaColors.surface, border: KumustaColors.line))
                .accessibilityHint(L("Starts the lesson again"))
            }
        }
    }

    private func sectionView(_ section: FirstStepsCheatSheetSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: section.symbol)
                    .scaledFont(17, weight: .bold)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(width: 38, height: 38)
                    .background(KumustaColors.accentSoft.opacity(0.44))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(KumustaTypography.title2)
                        .foregroundStyle(KumustaColors.ink)
                    Text(section.summary)
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                    cheatSheetEntry(entry)
                    if index < section.entries.count - 1 {
                        Divider()
                            .overlay(KumustaColors.line)
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(KumustaColors.surface.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KumustaColors.line, lineWidth: 1)
            }
        }
    }

    private func cheatSheetEntry(_ entry: FirstStepsCheatSheetEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let referencePairs = entry.referencePairs {
                referencePairList(referencePairs)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(KumustaTypography.title2)
                        .foregroundStyle(KumustaColors.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(entry.explanation)
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let example = entry.example {
                VStack(alignment: .leading, spacing: 4) {
                    Text(example)
                        .scaledFont(22, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let translation = entry.translation {
                        Text(translation)
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.muted)
                    }
                }
                .padding(.leading, 21)

            }

            if let audioText = entry.referenceAudioText ?? entry.example {
                AudioSpeedControls(
                    text: audioText,
                    usesSystemSpeech: entry.usesSystemSpeech,
                    bundledAudioResourceName: entry.bundledAudioResourceName,
                    purpose: .lesson,
                    analyticsProperties: ["screen_name": "first_steps_cheat_sheet", "step_id": entry.id],
                    showsSpeedChoices: false,
                    singlePlaybackSpeed: .natural
                )
                .padding(.leading, 21)
            }
        }
        .padding(.vertical, 16)
    }

    private func referencePairList(_ pairs: [FirstStepsReferencePair]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(pairs) { pair in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(pair.tagalog)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(":")
                        .foregroundStyle(KumustaColors.muted)
                    Text(pair.meaning)
                        .frame(width: 132, alignment: .leading)
                }
                .font(KumustaTypography.bodyStrong)
                .foregroundStyle(KumustaColors.ink)
            }
        }
        .padding(.leading, 21)
    }
}

/// Hosts First Steps: the guided first lesson for newcomers, or the basics
/// cheat sheet with replays of the learner's lessons.
struct FirstStepsCourseView: View {
    let onExit: (() -> Void)?
    let reviewMode: Bool

    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    /// The lesson file being replayed from the cheat sheet.
    @State private var replayingFile: String?

    init(onExit: (() -> Void)? = nil, reviewMode: Bool = false) {
        self.onExit = onExit
        self.reviewMode = reviewMode
    }

    private var learnerName: String? {
        FirstLessonCatalog.spokenName(from: appState.profile.name)
    }

    /// The lesson First Steps teaches when it is not a replay.
    private var defaultFile: String {
        #if DEBUG
        // Simulator shortcut: `-FirstLessonFile onboarding-intermediate`.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-FirstLessonFile"), arguments.indices.contains(flag + 1) {
            return arguments[flag + 1]
        }
        #endif
        return FirstLessonCatalog.fullLessonFile
    }

    private var replays: [FirstStepsCheatSheetView.Replay] {
        let welcomeFile = FirstLessonCatalog.onboardingFile(for: appState.profile.level)
        var replays: [FirstStepsCheatSheetView.Replay] = []
        if let welcome = script(welcomeFile) {
            replays.append(.init(
                file: welcomeFile,
                title: welcome.replayTitle,
                detail: L("Your welcome lesson · %lld min", welcome.estimatedMinutes),
                symbol: "sparkles"
            ))
        }
        if let full = script(FirstLessonCatalog.fullLessonFile) {
            replays.append(.init(
                file: FirstLessonCatalog.fullLessonFile,
                title: full.replayTitle,
                detail: L("First Steps lesson · %lld min", full.estimatedMinutes),
                symbol: "bubble.left.and.bubble.right.fill"
            ))
        }
        return replays
    }

    var body: some View {
        ZStack {
            PaperBackground()

            if reviewMode && replayingFile == nil {
                FirstStepsCheatSheetView(replays: replays) { file in
                    dependencies.analytics.track(
                        .featureAction,
                        properties: ["screen_name": "first_steps_cheat_sheet", "step": "replay_lesson", "value": file]
                    )
                    replayingFile = file
                }
                .transition(.opacity)
            } else if let script = script(replayingFile ?? defaultFile) {
                FirstLessonView(
                    script: script,
                    learnerName: learnerName,
                    onFinish: { finish(script) },
                    onClose: closeLesson
                )
                .id(script.id)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else {
                ContentUnavailableView(
                    L("Lesson unavailable"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(L("Please update Kumusta and try again."))
                )
            }
        }
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: replayingFile)
        .onAppear {
            if !reviewMode {
                dependencies.firstStepsCourseStore.start()
            }
        }
    }

    private func script(_ file: String) -> FirstLessonScript? {
        try? FirstLessonCatalog.load(file, learnerName: learnerName)
    }

    private func finish(_ script: FirstLessonScript) {
        if script.id == FirstStepsCourseStore.courseID {
            let store = dependencies.firstStepsCourseStore
            if !store.hasCompletedLesson {
                AppsFlyerAppEvents.trackCourseCompleted(courseName: "First Steps")
            }
            store.complete()
            appState.scheduleCloudStateSync()
        }
        closeLesson()
    }

    private func closeLesson() {
        if reviewMode {
            replayingFile = nil
        } else {
            exit()
        }
    }

    private func exit() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }
}

#Preview("First Steps offer") {
    FirstStepsOfferView(onStart: {}, onSkip: {}, onSeen: {})
        .environment(DependencyContainer.preview())
        .environment(AppState(dependencies: .preview()))
}

#Preview("First Steps course") {
    FirstStepsCourseView()
        .environment(DependencyContainer.preview())
        .environment(AppState(dependencies: .preview()))
}
