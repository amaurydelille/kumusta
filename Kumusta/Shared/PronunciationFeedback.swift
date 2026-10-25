import SwiftUI

/// Shared outcome of a pronunciation check, used by the lesson flow and the
/// word gym so their speech feedback can never drift apart again.
enum SpeechFeedbackState: Equatable {
    case idle
    case processing
    case failed(String)
    case result(SpeechTranscription, PronunciationReview)

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var canRequestFeedback: Bool {
        switch self {
        case .idle, .failed: true
        case .processing, .result: false
        }
    }

    var hasResult: Bool {
        if case .result = self { return true }
        return false
    }
}

struct PronunciationOutcome {
    let state: SpeechFeedbackState
    /// Whether every target word was heard exactly, which earns the
    /// success cue instead of the wrong-answer cue.
    let matchedTarget: Bool

    static let idle = PronunciationOutcome(state: .idle, matchedTarget: false)
}

enum PronunciationFeedbackEngine {
    /// Transcribes a take, then grades it on-device word by word.
    /// Only speech-to-text touches the network; no LLM is involved. A take
    /// streamed while it was recorded is used first; the upload is the fallback.
    static func evaluate(
        audio: Data,
        live: (any LiveSpeechTranscribing)? = nil,
        targetPhrase: String,
        speechService: any TagalogSpeechRecognizing,
        onboarding: Bool = false
    ) async -> PronunciationOutcome {
        do {
            let transcription = try await speechService.transcribe(
                audio: audio,
                live: live,
                onboarding: onboarding
            )
            let review = PronunciationReview(
                target: targetPhrase,
                transcript: transcription.transcript
            )
            return PronunciationOutcome(
                state: .result(transcription, review),
                matchedTarget: review.isMatch
            )
        } catch is CancellationError {
            return .idle
        } catch {
            return PronunciationOutcome(
                state: .failed(
                    (error as? LocalizedError)?.errorDescription
                        ?? L("Speech feedback is temporarily unavailable.")
                ),
                matchedTarget: false
            )
        }
    }
}

/// Word-by-word grade of what speech-to-text heard against the phrase the
/// learner was asked to say. Tagalog is written as it sounds, so aligning
/// words is enough; everyday spelling variants (pwede/puwede, rin/din) count
/// as the same word because speech-to-text picks either.
struct PronunciationReview: Equatable, Sendable {
    enum Mark: Equatable, Sendable {
        case correct
        /// Same consonants, a slipped vowel (lalake heard for lalaki).
        case spelling
        case wrong
        /// A target word that was never heard.
        case missing
        /// A heard word with no counterpart in the target.
        case extra
    }

    struct Syllable: Equatable, Sendable, Identifiable {
        let id: Int
        let text: String
        let mark: Mark
    }

    struct Tip: Equatable, Sendable {
        let mark: Mark
        /// Inline Markdown; words are bold.
        let message: String
    }

    let target: [Syllable]
    let heard: [Syllable]
    /// At most two, in phrase order, so the card stays scannable.
    let tips: [Tip]

    /// Whether the take passes. Deliberately forgiving, because speech-to-text
    /// cannot hear what native speakers do not pronounce either:
    /// - spelling variants of the same word already count as `.correct`;
    /// - a dropped enclitic at the end (po, na, lang…) is ignored;
    /// - one vowel slip passes in a phrase of three or more words.
    /// Wrong or skipped words always fail; extra filler words never do.
    let isMatch: Bool
    var correctCount: Int { target.filter { $0.mark == .correct }.count }
    var heardNothing: Bool { heard.isEmpty }

    init(target targetPhrase: String, transcript: String) {
        let expected = Self.syllables(in: targetPhrase)
        let said = Self.syllables(in: transcript)

        var target: [Syllable] = []
        var heard: [Syllable] = []
        var tips: [Tip] = []
        var skipped: [String] = []

        func flushSkipped() {
            guard !skipped.isEmpty else { return }
            tips.append(Tip(mark: .missing, message: L("Don’t skip **%@**.", skipped.joined(separator: " "))))
            skipped = []
        }

        for step in Self.align(expected.map(\.key), said.map(\.key)) {
            switch step {
            case let .pair(t, h, mark):
                flushSkipped()
                target.append(Syllable(id: target.count, text: expected[t].text, mark: mark))
                heard.append(Syllable(id: heard.count, text: said[h].text, mark: mark))
                if let tip = Self.tip(for: mark, expected: expected[t].text, heard: said[h].text) {
                    tips.append(tip)
                }
            case let .missing(t):
                target.append(Syllable(id: target.count, text: expected[t].text, mark: .missing))
                skipped.append(expected[t].text)
            case let .extra(h):
                heard.append(Syllable(id: heard.count, text: said[h].text, mark: .extra))
            }
        }
        flushSkipped()

        self.target = target
        self.heard = heard
        self.tips = Array(tips.prefix(2))
        self.isMatch = Self.passes(target: target)
    }

    /// Enclitics that close a sentence: short, unstressed, and often dropped
    /// by speech-to-text.
    private static let trailingParticles: Set<String> = [
        "po", "ho", "na", "pa", "lang", "naman", "ha", "ba", "nga", "eh", "o", "oh",
    ]

    private static func passes(target: [Syllable]) -> Bool {
        guard !target.isEmpty else { return false }
        var graded = target
        // Forgive trailing particles, unless the phrase is nothing but particles.
        while let last = graded.last,
              graded.count > 1,
              trailingParticles.contains(normalized(last.text)) {
            graded.removeLast()
        }
        if graded.contains(where: { $0.mark == .wrong || $0.mark == .missing }) {
            return false
        }
        let slips = graded.filter { $0.mark == .spelling }
        return slips.isEmpty || (slips.count == 1 && graded.count >= 3)
    }

    // MARK: - Tokenizing

    struct Token: Equatable {
        /// As written, for display.
        let text: String
        /// Normalized and variant-folded, for comparison.
        let key: String
    }

    /// Words of a phrase. Hyphens split ("halo-halo" and "halo halo" agree)
    /// and apostrophes vanish ("ano'ng" and "anong" agree).
    static func syllables(in text: String) -> [Token] {
        text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map { chunk in
                let word = String(chunk)
                // Transcribers often write "50" where a lesson writes "singkwenta".
                if word.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(word) {
                    return Token(text: word, key: TagalogNumber.key(value))
                }
                return Token(text: word, key: canonical(word))
            }
    }

    // MARK: - Comparing

    /// Lowercased, without stress marks, ñ kept as n.
    static func normalized(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fil_PH"))
    }

    /// Everyday spellings of the same spoken word, and number words mapped to
    /// their value so "singkwenta", "limampu" and "50" all agree.
    static func canonical(_ word: String) -> String {
        let folded = normalized(word)
        if let number = TagalogNumber.value(of: folded) { return TagalogNumber.key(number) }
        if let variant = variants[folded] { return variant }
        // pwede/puwede, kwento/kuwento, sya/siya.
        return folded
            .replacingOccurrences(of: "uw", with: "w")
            .replacingOccurrences(of: "iy", with: "y")
    }

    private static let variants: [String: String] = [
        "rin": "din", "raw": "daw", "rito": "dito", "roon": "doon", "rine": "dine",
        "ho": "po", "oho": "opo", "kamusta": "kumusta", "tsaka": "saka",
        "nang": "ng", "yung": "iyong", "yun": "iyon", "yon": "iyon", "yan": "iyan",
        "wag": "huwag", "di": "hindi",
    ]

    /// Same word, or the same consonants with e/i or o/u swapped, which
    /// Tagalog speakers interchange in unstressed syllables.
    static func mark(expected: String, heard: String) -> Mark {
        if expected == heard { return .correct }
        if vowelFolded(expected) == vowelFolded(heard) { return .spelling }
        return .wrong
    }

    private static func vowelFolded(_ key: String) -> String {
        key.replacingOccurrences(of: "e", with: "i").replacingOccurrences(of: "o", with: "u")
    }

    private enum Step {
        case pair(Int, Int, Mark)
        case missing(Int)
        case extra(Int)
    }

    /// Near misses are cheaper than a wrong word so the alignment pairs
    /// "lalake" with "lalaki" rather than treating them as a skip plus an
    /// extra. Costs are dyadic so the backtrace's equality checks are exact.
    private static func substitutionCost(_ mark: Mark) -> Double {
        switch mark {
        case .correct: 0
        case .spelling: 0.5
        case .wrong, .missing, .extra: 1
        }
    }

    /// Weighted edit distance over words, then a backtrace into steps.
    private static func align(_ expected: [String], _ heard: [String]) -> [Step] {
        let n = expected.count
        let m = heard.count
        var cost = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n + 1)
        for i in 0 ... n { cost[i][0] = Double(i) }
        for j in 0 ... m { cost[0][j] = Double(j) }
        for i in stride(from: 1, through: n, by: 1) {
            for j in stride(from: 1, through: m, by: 1) {
                let pair = cost[i - 1][j - 1]
                    + substitutionCost(mark(expected: expected[i - 1], heard: heard[j - 1]))
                cost[i][j] = min(pair, cost[i - 1][j] + 1, cost[i][j - 1] + 1)
            }
        }

        var steps: [Step] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                let pairMark = mark(expected: expected[i - 1], heard: heard[j - 1])
                if cost[i][j] == cost[i - 1][j - 1] + substitutionCost(pairMark) {
                    steps.append(.pair(i - 1, j - 1, pairMark))
                    i -= 1
                    j -= 1
                    continue
                }
            }
            if i > 0, cost[i][j] == cost[i - 1][j] + 1 {
                steps.append(.missing(i - 1))
                i -= 1
            } else {
                steps.append(.extra(j - 1))
                j -= 1
            }
        }
        return steps.reversed()
    }

    // MARK: - Coaching

    private static func tip(for mark: Mark, expected: String, heard: String) -> Tip? {
        switch mark {
        case .correct, .missing, .extra:
            return nil
        case .spelling:
            return Tip(
                mark: .spelling,
                message: L("Almost! Check the vowel in **%@**. It sounded like **%@**.", expected, heard)
            )
        case .wrong:
            return Tip(mark: .wrong, message: L("It sounded like **%@** instead of **%@**.", heard, expected))
        }
    }
}

/// Number words a lesson may write, native Tagalog or Spanish-derived, so the
/// "50" a transcriber writes matches "singkwenta" or "limampu" in the target.
enum TagalogNumber {
    private static let words: [String: Int] = [
        "isa": 1, "uno": 1, "dalawa": 2, "dos": 2, "tatlo": 3, "tres": 3,
        "apat": 4, "kwatro": 4, "kuwatro": 4, "lima": 5, "singko": 5,
        "anim": 6, "sais": 6, "pito": 7, "syete": 7, "siyete": 7,
        "walo": 8, "otso": 8, "syam": 9, "siyam": 9, "nwebe": 9, "nuwebe": 9,
        "sampu": 10, "dyis": 10, "diyes": 10, "onse": 11, "dose": 12,
        "bente": 20, "beinte": 20, "dalawampu": 20, "trenta": 30, "treinta": 30, "tatlumpu": 30,
        "kwarenta": 40, "kuwarenta": 40, "apatnapu": 40, "singkwenta": 50, "limampu": 50,
        "sandaan": 100, "isandaan": 100, "sanlibo": 1000, "isanlibo": 1000,
    ]

    static func value(of word: String) -> Int? { words[word] }

    static func key(_ value: Int) -> String { "#\(value)" }
}

/// Forgiving check for the onboarding conversation. A first-time learner
/// passes when speech-to-text heard at least half of the target words,
/// ignoring case, punctuation, spelling variants and the learner's own name
/// (which speech-to-text rarely transcribes faithfully).
enum OnboardingSpeechMatcher {
    static func matches(transcript: String, target: String, ignoringName name: String?) -> Bool {
        let nameTokens = Set(tokens(name ?? ""))
        let targetTokens = tokens(target).filter { !nameTokens.contains($0) }
        let heard = Set(tokens(transcript))
        guard !targetTokens.isEmpty else { return !heard.isEmpty }
        let hits = targetTokens.filter(heard.contains).count
        return Double(hits) / Double(targetTokens.count) >= 0.5
    }

    static func tokens(_ text: String) -> [String] {
        PronunciationReview.syllables(in: text).map(\.key)
    }
}

/// The "couldn't check" / syllable review cards rendered after a
/// pronunciation attempt.
struct SpeechFeedbackCard: View {
    let state: SpeechFeedbackState
    let isCorrect: Bool
    var showsRetryButton = true
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .processing:
            EmptyView()
        case let .failed(message):
            VStack(alignment: .leading, spacing: 10) {
                Label(L("Couldn’t check that take"), systemImage: "waveform.badge.exclamationmark")
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.accentDeep)
                Text(message)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KumustaColors.accentSoft.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        case let .result(_, review):
            if isCorrect {
                EmptyView()
            } else {
                PronunciationReviewCard(
                    review: review,
                    showsRetryButton: showsRetryButton,
                    onRetry: onRetry
                )
            }
        }
    }
}

private struct PronunciationReviewCard: View {
    let review: PronunciationReview
    let showsRetryButton: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if review.heardNothing {
                Text(L("No Tagalog came through. Hold the phone a little closer and speak up."))
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            syllableRow(title: L("TARGET"), syllables: review.target, isTarget: true)

            if !review.heardNothing {
                syllableRow(title: L("YOU SAID"), syllables: review.heard, isTarget: false)
            }

            if !review.tips.isEmpty {
                tips
            }

            legend

            if showsRetryButton {
                Button(L("Try one more take"), action: onRetry)
                    .buttonStyle(KumustaSecondaryButtonStyle())
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KumustaColors.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KumustaColors.accentSoft, lineWidth: 2)
        }
    }

    private var headline: String {
        guard !review.heardNothing, !review.target.isEmpty else { return L("Didn’t catch that") }
        let ratio = Double(review.correctCount) / Double(review.target.count)
        if ratio >= 0.75 { return L("So close!") }
        if ratio >= 0.4 { return L("Getting there") }
        return L("Let’s try that again")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "ear.fill")
                    .foregroundStyle(KumustaColors.accentDeep)
                    .accessibilityHidden(true)
                Text(headline)
                    .font(KumustaTypography.headline)
                    .foregroundStyle(KumustaColors.ink)
                Spacer(minLength: 8)
                Text("\(review.correctCount)/\(review.target.count)")
                    .scaledFont(14, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(KumustaColors.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(KumustaColors.surface, in: Capsule())
                    .accessibilityLabel(L("%lld of %lld words right", review.correctCount, review.target.count))
            }

            HStack(spacing: 4) {
                ForEach(review.target) { syllable in
                    Capsule()
                        .fill(syllable.mark.tint)
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func syllableRow(
        title: String,
        syllables: [PronunciationReview.Syllable],
        isTarget: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .scaledFont(11, weight: .bold, design: .rounded)
                .scaledTracking(1.2, forPointSize: 11)
                .foregroundStyle(KumustaColors.muted)
            WordWrapLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(syllables) { syllable in
                    SyllableChip(syllable: syllable, isTarget: isTarget)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isTarget ? L("Target phrase") : L("What you said"))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(review.tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: tip.mark.symbol)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(tip.mark.tint, in: Circle())
                        .accessibilityHidden(true)
                    Text((try? AttributedString(markdown: tip.message)) ?? AttributedString(tip.message))
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KumustaColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Explains only the colors that actually appear on this card.
    private var legend: some View {
        let shown = Set((review.target + review.heard).map(\.mark))
        let marks: [PronunciationReview.Mark] = [.correct, .spelling, .wrong, .missing, .extra]
            .filter(shown.contains)
        return WordWrapLayout(horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(marks, id: \.self) { mark in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(mark.tint)
                        .frame(width: 10, height: 10)
                    Text(mark.label)
                        .scaledFont(12, weight: .medium, design: .rounded)
                        .foregroundStyle(KumustaColors.muted)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SyllableChip: View {
    let syllable: PronunciationReview.Syllable
    let isTarget: Bool

    private var mark: PronunciationReview.Mark { syllable.mark }

    var body: some View {
        Text(syllable.text)
            .strikethrough(mark == .extra, color: KumustaColors.muted)
            .scaledFont(19, weight: .semibold, design: .rounded)
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(background, in: shape)
            .overlay {
                shape.strokeBorder(
                    border,
                    style: StrokeStyle(lineWidth: 1.5, dash: mark == .missing ? [4, 3] : [])
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("%@, %@", syllable.text, mark.label))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
    }

    private var foreground: Color {
        switch mark {
        case .wrong: .white
        case .missing: KumustaColors.errorDeep
        case .extra: KumustaColors.muted
        case .correct, .spelling: KumustaColors.ink
        }
    }

    private var background: Color {
        switch mark {
        // Only the target row celebrates correct syllables; on the heard row
        // they stay neutral so the mistakes stand out.
        case .correct: isTarget ? KumustaColors.success.opacity(0.18) : KumustaColors.surface
        case .spelling: KumustaColors.caution.opacity(0.26)
        case .wrong: KumustaColors.error
        case .missing: .clear
        case .extra: KumustaColors.surfaceMuted
        }
    }

    private var border: Color {
        switch mark {
        case .correct: isTarget ? KumustaColors.success.opacity(0.55) : KumustaColors.line
        case .spelling: KumustaColors.caution
        case .wrong, .missing: KumustaColors.error
        case .extra: KumustaColors.line
        }
    }
}

private extension PronunciationReview.Mark {
    var tint: Color {
        switch self {
        case .correct: KumustaColors.success
        case .spelling: KumustaColors.caution
        case .wrong, .missing: KumustaColors.error
        case .extra: KumustaColors.line
        }
    }

    var label: String {
        switch self {
        case .correct: L("Correct")
        case .spelling: L("Almost")
        case .wrong: L("Wrong")
        case .missing: L("Missing")
        case .extra: L("Extra")
        }
    }

    var symbol: String {
        switch self {
        case .correct: "checkmark"
        case .spelling: "textformat.abc"
        case .wrong: "xmark"
        case .missing: "plus"
        case .extra: "minus"
        }
    }
}
