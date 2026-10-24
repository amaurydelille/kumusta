import Foundation

/// A guided lesson built from bundled JSON in `Resources/FirstLessons`.
/// `{name}` in any line is replaced with the learner's first name. The same files drive the audio generator in
/// `scripts/generate-first-lesson-audio.ts`, so text and clips never drift.
struct FirstLessonScript: Equatable, Sendable {
    enum Mode: String, Decodable, Sendable {
        /// The short lesson shown during onboarding, before the paywall.
        case onboarding
        /// A complete in-app lesson.
        case full
    }

    let id: String
    let level: ProficiencyLevel
    let mode: Mode
    let sourceID: UUID
    let replayTitle: String
    let estimatedMinutes: Int
    let intro: Intro
    let steps: [Step]
    let completion: Completion
    /// Language of the learner-facing text; English unless a translation loaded.
    var language: AppLanguage = .english

    struct Chunk: Identifiable, Equatable, Sendable {
        let tagalog: String
        let meaning: String

        var id: String { tagalog }
    }

    struct Intro: Equatable, Sendable {
        let hook: String
        let hookTranslation: String
        let title: String
        let subtitle: String
        let goals: [Chunk]
    }

    struct Completion: Equatable, Sendable {
        let title: String
        let subtitle: String
        let phrases: [Chunk]
        let words: [Chunk]
    }

    /// The pitch shape drawn next to a tone sample.
    enum ToneContour: String, Decodable, Equatable, Sendable {
        case level
        case falling
        case rising
        case dipping
        case heavy
    }

    struct ToneSample: Identifiable, Equatable, Sendable {
        let text: String
        let meaning: String
        let contour: ToneContour

        var id: String { text }
    }

    struct Teach: Equatable, Sendable {
        let symbol: String
        let eyebrow: String
        let title: String
        let body: String
        let samples: [ToneSample]
        let footnote: String?
    }

    struct ListenPick: Equatable, Sendable {
        let prompt: String
        let answer: String
        let options: [ToneSample]
    }

    struct NewPhrase: Equatable, Sendable {
        let tagalog: String
        let translation: String
        let chunks: [Chunk]
        let tip: String
    }

    struct Speak: Equatable, Sendable {
        let title: String
        /// What the learner reads; may end with their own name.
        let display: String
        let translation: String
        /// What pronunciation feedback grades. Names are left out because
        /// speech-to-text cannot be expected to spell a foreign name.
        let target: String
        /// Other takes that count as correct, such as oo for opo.
        let accepted: [String]
        let tip: String?
        /// What the voice reads aloud when it differs from `target`, such as
        /// the introduction spoken with the learner's own name.
        let audio: String?

        var spokenText: String { audio ?? target }
    }

    struct MeaningPick: Equatable, Sendable {
        let prompt: String
        let audio: String
        let answer: String
        let options: [String]
        /// Shown on the result banner once the learner has answered.
        let note: String?
    }

    struct NaturalOption: Identifiable, Equatable, Sendable {
        let text: String
        let translation: String
        let verdict: String
        let explanation: String
        let isBest: Bool

        var id: String { text }
    }

    struct NaturalPick: Equatable, Sendable {
        let prompt: String
        let context: String
        let contextTranslation: String
        let options: [NaturalOption]

        var best: NaturalOption? { options.first(where: \.isBest) }
    }

    struct Tile: Equatable, Sendable {
        let text: String
        let gloss: String?
    }

    struct Build: Equatable, Sendable {
        let english: String
        let answer: [Tile]
        let distractors: [Tile]

        var tiles: [Tile] { answer + distractors }
        var solution: String { answer.map(\.text).joined(separator: " ") }
    }

    struct Turn: Identifiable, Equatable, Sendable {
        let id: Int
        let buddyLine: String
        let buddyTranslation: String
        let replyDisplay: String
        let replyTranslation: String
        let replyTarget: String
        let accepted: [String]
    }

    struct Line: Equatable, Sendable {
        let text: String
        let translation: String
    }

    struct Conversation: Equatable, Sendable {
        let eyebrow: String
        let title: String
        let turns: [Turn]
        let closing: Line?
    }

    enum Step: Identifiable, Equatable, Sendable {
        case intro
        case teach(id: String, Teach)
        case listenPick(id: String, ListenPick)
        case newPhrase(id: String, NewPhrase)
        case speak(id: String, Speak)
        case meaningPick(id: String, MeaningPick)
        case naturalPick(id: String, NaturalPick)
        case build(id: String, Build)
        case conversation(id: String, Conversation)

        var id: String {
            switch self {
            case .intro: "intro"
            case let .teach(id, _), let .listenPick(id, _), let .newPhrase(id, _),
                 let .speak(id, _), let .meaningPick(id, _), let .naturalPick(id, _),
                 let .build(id, _), let .conversation(id, _):
                id
            }
        }

        /// Steps the learner answers, which count toward accuracy.
        var isGraded: Bool {
            switch self {
            case .listenPick, .meaningPick, .naturalPick, .build: true
            case .intro, .teach, .newPhrase, .speak, .conversation: false
            }
        }

        /// How many takes a perfect run records, used to fit the pre-paywall
        /// speech allowance.
        var recordingCount: Int {
            switch self {
            case .speak: 1
            case let .conversation(_, conversation): conversation.turns.count
            default: 0
            }
        }

        var analyticsKind: String {
            switch self {
            case .intro: "intro"
            case .teach: "teach"
            case .listenPick: "listen_pick"
            case .newPhrase: "new_phrase"
            case .speak: "speak"
            case .meaningPick: "meaning_pick"
            case .naturalPick: "natural_pick"
            case .build: "build"
            case .conversation: "conversation"
            }
        }
    }

    /// Every phrase the lesson can speak, in lesson order.
    var audioTexts: [String] {
        var texts = [intro.hook]
        for step in steps {
            switch step {
            case .intro:
                break
            case let .teach(_, teach):
                texts += teach.samples.map(\.text)
            case let .listenPick(_, pick):
                texts += pick.options.map(\.text)
            case let .newPhrase(_, phrase):
                texts.append(phrase.tagalog)
                texts += phrase.chunks.map(\.tagalog)
            case let .speak(_, speak):
                texts.append(speak.spokenText)
            case let .meaningPick(_, pick):
                texts.append(pick.audio)
            case let .naturalPick(_, pick):
                texts.append(pick.context)
                texts += pick.options.map(\.text)
            case let .build(_, build):
                texts += build.tiles.map(\.text)
                texts.append(build.solution)
            case let .conversation(_, conversation):
                texts += conversation.turns.map(\.buddyLine)
                if let closing = conversation.closing { texts.append(closing.text) }
            }
        }
        texts += completion.phrases.map { Self.playableText($0.tagalog) }
        var seen = Set<String>()
        return texts.filter { seen.insert(Self.normalizedAudioText($0)).inserted }
    }

    /// Strips the ellipsis used for open phrases such as "Ako si…".
    static func playableText(_ text: String) -> String {
        text.replacingOccurrences(of: "…", with: "").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Audio keys

extension FirstLessonScript {
    /// NFC, trimmed, single-spaced: the exact text the audio generator hashes.
    static func normalizedAudioText(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// 64-bit FNV-1a of the normalized UTF-8 text, as 16 hex digits. The
    /// generator script computes the same key to name each bundled clip.
    static func audioKey(for text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in normalizedAudioText(text).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }

    static func bundledAudioURL(
        for text: String,
        bundle: Bundle = .main
    ) -> URL? {
        bundle.url(
            forResource: audioKey(for: text),
            withExtension: "mp3",
            subdirectory: "FirstLessons/audio"
        )
    }
}

// MARK: - Catalog

enum FirstLessonCatalog {
    /// The complete in-app beginner lesson behind First Steps.
    static let fullLessonFile = "first-lesson-beginner"

    /// The short onboarding lesson for a level, shown before the paywall and
    /// replayable from the basics cheat sheet.
    static func onboardingFile(for level: ProficiencyLevel) -> String {
        "onboarding-\(level.rawValue)"
    }

    static let allFiles: [String] = [fullLessonFile] + ProficiencyLevel.allCases.map(onboardingFile(for:))

    enum LoadError: Error {
        case missing(String)
    }

    static func load(
        _ file: String,
        learnerName: String?,
        bundle: Bundle = .main
    ) throws -> FirstLessonScript {
        guard let url = bundle.url(forResource: file, withExtension: "json", subdirectory: "FirstLessons") else {
            throw LoadError.missing(file)
        }
        let raw = try JSONDecoder().decode(RawLesson.self, from: Data(contentsOf: url))
        return raw.resolved(name: learnerName)
    }

    /// The learner's first name as the lesson speaks it, or nil when the
    /// name could not be spoken safely (the voice server rejects it too).
    static func spokenName(from rawName: String?) -> String? {
        rawName.flatMap(OnboardingConversationAudio.spokenFirstName(from:))
    }
}

// MARK: - JSON

/// One line of lesson text.
private struct ScriptText: Decodable {
    let value: String

    init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(String.self)
    }
}

private struct ResolveContext {
    let name: String?

    /// Fills `{name}`. Without a name, display text shows an ellipsis.
    func text(_ value: ScriptText) -> String {
        let text = value.value
        guard text.contains("{name}") else { return text }
        if let name { return text.replacingOccurrences(of: "{name}", with: name) }
        return text
            .replacingOccurrences(of: " {name}.", with: " …")
            .replacingOccurrences(of: "{name}", with: "…")
    }

    /// Audio is only personalized when there is a name; otherwise nil.
    func audio(_ value: ScriptText?) -> String? {
        guard let value else { return nil }
        let text = value.value
        guard text.contains("{name}") else { return text }
        return name.map { text.replacingOccurrences(of: "{name}", with: $0) }
    }

    func optional(_ value: ScriptText?) -> String? {
        value.map(text)
    }
}

private struct RawLesson: Decodable {
    let id: String
    let level: ProficiencyLevel
    let mode: FirstLessonScript.Mode
    let sourceID: UUID
    let replayTitle: String
    let estimatedMinutes: Int
    let intro: RawIntro
    let steps: [RawStep]
    let completion: RawCompletion

    func resolved(name: String?) -> FirstLessonScript {
        let context = ResolveContext(name: name)
        return FirstLessonScript(
            id: id,
            level: level,
            mode: mode,
            sourceID: sourceID,
            replayTitle: replayTitle,
            estimatedMinutes: estimatedMinutes,
            intro: FirstLessonScript.Intro(
                hook: context.text(intro.hook),
                hookTranslation: context.text(intro.hookTranslation),
                title: context.text(intro.title),
                subtitle: context.text(intro.subtitle),
                goals: intro.goals.map { $0.resolved(context) }
            ),
            steps: [.intro] + steps.map { $0.resolved(context) },
            completion: FirstLessonScript.Completion(
                title: context.text(completion.title),
                subtitle: context.text(completion.subtitle),
                phrases: completion.phrases.map { $0.resolved(context) },
                words: completion.words.map { $0.resolved(context) }
            )
        )
    }
}

private struct RawIntro: Decodable {
    let hook: ScriptText
    let hookTranslation: ScriptText
    let title: ScriptText
    let subtitle: ScriptText
    let goals: [RawChunk]
}

private struct RawCompletion: Decodable {
    let title: ScriptText
    let subtitle: ScriptText
    let phrases: [RawChunk]
    let words: [RawChunk]
}

private struct RawChunk: Decodable {
    let tagalog: ScriptText
    let meaning: ScriptText

    func resolved(_ context: ResolveContext) -> FirstLessonScript.Chunk {
        FirstLessonScript.Chunk(tagalog: context.text(tagalog), meaning: context.text(meaning))
    }
}

private struct RawSample: Decodable {
    let text: ScriptText
    let meaning: ScriptText
    let contour: ScriptText

    func resolved(_ context: ResolveContext) -> FirstLessonScript.ToneSample {
        FirstLessonScript.ToneSample(
            text: context.text(text),
            meaning: context.text(meaning),
            contour: FirstLessonScript.ToneContour(rawValue: contour.value) ?? .level
        )
    }
}

private struct RawTile: Decodable {
    let text: ScriptText
    let gloss: ScriptText?

    func resolved(_ context: ResolveContext) -> FirstLessonScript.Tile {
        FirstLessonScript.Tile(text: context.text(text), gloss: context.optional(gloss))
    }
}

private struct RawNaturalOption: Decodable {
    let text: ScriptText
    let translation: ScriptText
    let verdict: ScriptText
    let explanation: ScriptText
    let isBest: Bool?
}

private struct RawTurn: Decodable {
    let buddy: ScriptText
    let buddyTranslation: ScriptText
    let reply: ScriptText
    let replyTranslation: ScriptText
    let target: ScriptText
    let accepted: [ScriptText]?
}

private struct RawLine: Decodable {
    let text: ScriptText
    let translation: ScriptText
}

private struct RawStep: Decodable {
    let kind: String
    let id: String
    // Shared and per-kind fields; each kind reads only its own.
    let symbol: String?
    let eyebrow: ScriptText?
    let title: ScriptText?
    let body: ScriptText?
    let samples: [RawSample]?
    let footnote: ScriptText?
    let prompt: ScriptText?
    let answer: AnswerField?
    let options: OptionsField?
    let tagalog: ScriptText?
    let translation: ScriptText?
    let chunks: [RawChunk]?
    let tip: ScriptText?
    let tipWithoutName: ScriptText?
    let display: ScriptText?
    let target: ScriptText?
    let accepted: [ScriptText]?
    let audio: ScriptText?
    let note: ScriptText?
    let context: ScriptText?
    let contextTranslation: ScriptText?
    let english: ScriptText?
    let distractors: [RawTile]?
    let turns: [RawTurn]?
    let closing: RawLine?

    /// `answer` is a string for picks and a tile list for build steps.
    enum AnswerField: Decodable {
        case text(ScriptText)
        case tiles([RawTile])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let tiles = try? container.decode([RawTile].self) {
                self = .tiles(tiles)
            } else {
                self = .text(try container.decode(ScriptText.self))
            }
        }
    }

    /// `options` holds tone samples, plain strings, or natural-reply options.
    enum OptionsField: Decodable {
        case samples([RawSample])
        case natural([RawNaturalOption])
        case texts([ScriptText])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let natural = try? container.decode([RawNaturalOption].self) {
                self = .natural(natural)
            } else if let samples = try? container.decode([RawSample].self) {
                self = .samples(samples)
            } else {
                self = .texts(try container.decode([ScriptText].self))
            }
        }
    }

    func resolved(_ c: ResolveContext) -> FirstLessonScript.Step {
        func t(_ value: ScriptText?) -> String { value.map(c.text) ?? "" }
        switch kind {
        case "teach":
            return .teach(id: id, FirstLessonScript.Teach(
                symbol: symbol ?? "sparkles",
                eyebrow: t(eyebrow),
                title: t(title),
                body: t(body),
                samples: (samples ?? []).map { $0.resolved(c) },
                footnote: c.optional(footnote)
            ))
        case "listenPick":
            guard case let .samples(samples)? = options, case let .text(answer)? = answer else { break }
            return .listenPick(id: id, FirstLessonScript.ListenPick(
                prompt: t(prompt),
                answer: c.text(answer),
                options: samples.map { $0.resolved(c) }
            ))
        case "newPhrase":
            return .newPhrase(id: id, FirstLessonScript.NewPhrase(
                tagalog: t(tagalog),
                translation: t(translation),
                chunks: (chunks ?? []).map { $0.resolved(c) },
                tip: t(tip)
            ))
        case "speak":
            return .speak(id: id, FirstLessonScript.Speak(
                title: t(title),
                display: t(display),
                translation: t(translation),
                target: t(target),
                accepted: (accepted ?? []).map(c.text),
                tip: c.name == nil ? (c.optional(tipWithoutName) ?? c.optional(tip)) : c.optional(tip),
                audio: c.audio(audio)
            ))
        case "meaningPick":
            guard case let .texts(texts)? = options, case let .text(answer)? = answer else { break }
            return .meaningPick(id: id, FirstLessonScript.MeaningPick(
                prompt: c.optional(prompt) ?? L("What does this mean?"),
                audio: t(audio),
                answer: c.text(answer),
                options: texts.map(c.text),
                note: c.optional(note)
            ))
        case "naturalPick":
            guard case let .natural(natural)? = options else { break }
            return .naturalPick(id: id, FirstLessonScript.NaturalPick(
                prompt: t(prompt),
                context: t(context),
                contextTranslation: t(contextTranslation),
                options: natural.map {
                    FirstLessonScript.NaturalOption(
                        text: c.text($0.text),
                        translation: c.text($0.translation),
                        verdict: c.text($0.verdict),
                        explanation: c.text($0.explanation),
                        isBest: $0.isBest ?? false
                    )
                }
            ))
        case "build":
            guard case let .tiles(tiles)? = answer else { break }
            return .build(id: id, FirstLessonScript.Build(
                english: t(english),
                answer: tiles.map { $0.resolved(c) },
                distractors: (distractors ?? []).map { $0.resolved(c) }
            ))
        case "conversation":
            return .conversation(id: id, FirstLessonScript.Conversation(
                eyebrow: t(eyebrow),
                title: t(title),
                turns: (turns ?? []).enumerated().map { index, turn in
                    FirstLessonScript.Turn(
                        id: index,
                        buddyLine: c.text(turn.buddy),
                        buddyTranslation: c.text(turn.buddyTranslation),
                        replyDisplay: c.text(turn.reply),
                        replyTranslation: c.text(turn.replyTranslation),
                        replyTarget: c.text(turn.target),
                        accepted: (turn.accepted ?? []).map(c.text)
                    )
                },
                closing: closing.map { FirstLessonScript.Line(text: c.text($0.text), translation: c.text($0.translation)) }
            ))
        default:
            break
        }
        // An unknown or malformed step teaches nothing; tests reject it.
        return .teach(id: id, FirstLessonScript.Teach(
            symbol: "exclamationmark.triangle",
            eyebrow: "",
            title: "Unsupported step \(kind)",
            body: "",
            samples: [],
            footnote: nil
        ))
    }
}
