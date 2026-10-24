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
    /// Whether every target syllable was heard exactly, which earns the
    /// success cue instead of the wrong-answer cue.
    let matchedTarget: Bool

    static let idle = PronunciationOutcome(state: .idle, matchedTarget: false)
}

enum PronunciationFeedbackEngine {
    /// Transcribes a take, then grades it on-device syllable by syllable.
    /// Only speech-to-text touches the network; no LLM is involved. A take
    /// streamed while it was recorded is used first; the upload is the fallback.
    static func evaluate(
        audio: Data,
        live: (any LiveSpeechTranscribing)? = nil,
        targetPhrase: String,
        accent: VietnameseAccent? = nil,
        speechService: any VietnameseSpeechRecognizing,
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
                transcript: transcription.transcript,
                accent: accent
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

/// Syllable-by-syllable grade of what speech-to-text heard against the phrase
/// the learner was asked to say. Vietnamese writes one syllable per word and
/// carries the tone as a mark on that syllable, so aligning words aligns
/// syllables, and "wrong tone" can be told apart from "wrong word" exactly.
struct PronunciationReview: Equatable, Sendable {
    enum Mark: Equatable, Sendable {
        case correct
        /// Same letters, different tone mark (mà heard as má).
        case tone
        /// Same base letters, different vowel mark or đ (mơ heard as mo).
        case spelling
        case wrong
        /// A target syllable that was never heard.
        case missing
        /// A heard syllable with no counterpart in the target.
        case extra
    }

    struct Syllable: Equatable, Sendable, Identifiable {
        let id: Int
        let text: String
        let mark: Mark
    }

    struct Tip: Equatable, Sendable {
        let mark: Mark
        /// Inline Markdown; syllables are bold.
        let message: String
    }

    let target: [Syllable]
    let heard: [Syllable]
    /// At most two, in phrase order, so the card stays scannable.
    let tips: [Tip]

    /// Whether the take passes. Deliberately forgiving, because speech-to-text
    /// cannot hear what native speakers do not pronounce either:
    /// - sounds the learner's accent merges already count as `.correct`;
    /// - a dropped or mistoned polite particle at the end (ạ, nhé…) is ignored;
    /// - one tone or vowel slip passes in a phrase of three or more syllables,
    ///   and in shorter ones only when the two tones sound alike (ạ/à).
    /// Wrong or skipped words always fail; extra filler syllables never do.
    let isMatch: Bool
    var correctCount: Int { target.filter { $0.mark == .correct }.count }
    var heardNothing: Bool { heard.isEmpty }

    init(target targetPhrase: String, transcript: String, accent: VietnameseAccent? = nil) {
        let expected = Self.syllables(in: targetPhrase)
        let said = Self.syllables(in: transcript)

        var target: [Syllable] = []
        var heard: [Syllable] = []
        var tips: [Tip] = []
        var skipped: [String] = []
        /// What was heard for each paired target syllable, by target index.
        var heardForTarget: [Int: String] = [:]

        func flushSkipped() {
            guard !skipped.isEmpty else { return }
            tips.append(Tip(mark: .missing, message: L("Don’t skip **%@**.", skipped.joined(separator: " "))))
            skipped = []
        }

        for step in Self.align(expected.map(\.key), said.map(\.key), accent: accent) {
            switch step {
            case let .pair(t, h, mark):
                flushSkipped()
                heardForTarget[target.count] = said[h].key
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
        self.isMatch = Self.passes(target: target, heardForTarget: heardForTarget)
    }

    /// Sentence-final particles: short, unstressed, and often dropped or
    /// mistoned by speech-to-text.
    private static let trailingParticles: Set<String> = [
        "ạ", "à", "nhé", "nhá", "nha", "nhỉ", "nè", "hả", "ha", "há", "hen",
    ]

    private static func passes(target: [Syllable], heardForTarget: [Int: String]) -> Bool {
        guard !target.isEmpty else { return false }
        let locale = Locale(identifier: "vi_VN")
        var graded = target
        // Forgive trailing particles, unless the phrase is nothing but particles.
        while let last = graded.last,
              graded.count > 1,
              trailingParticles.contains(last.text.lowercased(with: locale)) {
            graded.removeLast()
        }
        if graded.contains(where: { $0.mark == .wrong || $0.mark == .missing }) {
            return false
        }
        let slips = graded.filter { $0.mark == .tone || $0.mark == .spelling }
        guard let slip = slips.first else { return true }
        guard slips.count == 1 else { return false }
        if graded.count >= 3 { return true }
        guard slip.mark == .tone, let said = heardForTarget[slip.id] else { return false }
        return isSoftToneSlip(expected: slip.text.lowercased(with: locale), heard: said)
    }

    /// Tones that are hard to tell apart even for a careful listener: the two
    /// low tones (ạ/à), and sắc/nặng on syllables cut short by p, t, c or ch.
    static func isSoftToneSlip(expected: String, heard: String) -> Bool {
        let tones = [Tone(of: expected), Tone(of: heard)]
        if tones.contains(.nang), tones.contains(.huyen) { return true }
        let letters = canonicalLetters(expected)
        let isChecked = ["p", "t", "c", "ch"].contains { letters.hasSuffix($0) }
        return isChecked && tones.contains(.nang) && tones.contains(.sac)
    }

    // MARK: - Tokenizing

    struct Token: Equatable {
        /// As written, for display.
        let text: String
        /// Lowercased, precomposed, and punctuation-free, for comparison.
        let key: String
    }

    static func syllables(in text: String) -> [Token] {
        let locale = Locale(identifier: "vi_VN")
        return text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .flatMap { chunk -> [Token] in
                let word = String(chunk)
                // Transcribers often write "2" where a lesson writes "hai".
                if word.allSatisfy({ $0.isASCII && $0.isNumber }),
                   let value = Int(word),
                   let spelled = VietnameseNumber.spell(value) {
                    return spelled.map { Token(text: $0, key: $0) }
                }
                return [Token(text: word, key: word.lowercased(with: locale))]
            }
    }

    // MARK: - Comparing

    /// Combining marks for the five written tones (huyền, sắc, ngã, hỏi, nặng).
    /// Vowel marks (ă, â, ê, ô, ơ, ư) are deliberately not in this set.
    private static let toneMarks: Set<Unicode.Scalar> = ["\u{0300}", "\u{0301}", "\u{0303}", "\u{0309}", "\u{0323}"]

    static func withoutTone(_ syllable: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(
            contentsOf: syllable.decomposedStringWithCanonicalMapping.unicodeScalars
                .filter { !toneMarks.contains($0) }
        )
        return String(scalars).precomposedStringWithCanonicalMapping
    }

    static func bareLetters(_ syllable: String) -> String {
        syllable
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
    }

    static func mark(expected: String, heard: String, accent: VietnameseAccent? = nil) -> Mark {
        if expected == heard { return .correct }
        let expectedTone = Tone(of: expected)
        let heardTone = Tone(of: heard)
        // Southern and Central speakers pronounce hỏi and ngã the same way.
        let sameTone = expectedTone == heardTone
            || (accent == .southern && [expectedTone, heardTone].allSatisfy { $0 == .hoi || $0 == .nga })
        let expectedLetters = canonicalLetters(expected)
        let heardLetters = canonicalLetters(heard)
        if expectedLetters == heardLetters
            || soundKey(expectedLetters, accent: accent) == soundKey(heardLetters, accent: accent) {
            return sameTone ? .correct : .tone
        }
        if bareLetters(expected) == bareLetters(heard) { return .spelling }
        return .wrong
    }

    /// Lowercased letters without the tone mark, wherever it was written
    /// ("hoà" and "hòa" agree), with y spelled i after a consonant ("kỹ" and
    /// "kĩ" are the same word; "tay" and "tai" are not).
    static func canonicalLetters(_ syllable: String) -> String {
        let letters = withoutTone(syllable).lowercased(with: Locale(identifier: "vi_VN"))
        let (onset, rest) = splitOnset(letters)
        return !onset.isEmpty && rest == "y" ? onset + "i" : letters
    }

    private static let onsets = [
        "ngh", "ng", "nh", "ch", "tr", "gh", "gi", "kh", "ph", "th", "qu",
        "b", "c", "d", "đ", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x",
    ]
    private static let codas = ["ch", "ng", "nh", "c", "m", "n", "p", "t"]
    private static let vowels = Set("aăâeêioôơuưy")

    private static func splitOnset(_ letters: String) -> (onset: String, rest: String) {
        guard let onset = onsets.first(where: { letters.hasPrefix($0) }) else { return ("", letters) }
        var rest = String(letters.dropFirst(onset.count))
        // "gì" and "gìn": the i after g is both part of gi and the vowel.
        if onset == "gi", rest.first.map({ !vowels.contains($0) }) ?? true {
            rest = "i" + rest
        }
        return (onset, rest)
    }

    /// The syllable as the learner's accent pronounces it. Spellings that
    /// sound identical map to the same key, so speech-to-text guessing one
    /// spelling over the other never fails a correct take.
    static func soundKey(_ letters: String, accent: VietnameseAccent?) -> String {
        var (onset, rest) = splitOnset(letters)
        var coda = codas.first { rest.hasSuffix($0) && rest.count > $0.count } ?? ""
        var nucleus = String(rest.dropLast(coda.count))

        // Merged by speech-to-text in every accent.
        switch onset {
        case "tr": onset = "ch"
        case "s": onset = "x"
        case "k": onset = "c"
        case "gh": onset = "g"
        case "ngh": onset = "ng"
        default: break
        }
        if coda == "ch" { coda = "c" }

        switch accent {
        case .northern:
            if onset == "r" || onset == "gi" { onset = "d" }
        case .southern:
            if onset == "v" || onset == "gi" { onset = "d" }
            switch coda {
            case "t": coda = "c"
            case "nh", "ng": coda = "n"
            default: break
            }
            if nucleus == "iêu" { nucleus = "iu" }
            if nucleus == "ươu" { nucleus = "ưu" }
        case nil:
            break
        }
        return onset + nucleus + coda
    }

    private enum Step {
        case pair(Int, Int, Mark)
        case missing(Int)
        case extra(Int)
    }

    /// Near misses are cheaper than a wrong word so the alignment pairs "má"
    /// with "mà" rather than treating them as a skip plus an extra. Costs are
    /// dyadic so the backtrace's equality checks are exact.
    private static func substitutionCost(_ mark: Mark) -> Double {
        switch mark {
        case .correct: 0
        case .tone: 0.25
        case .spelling: 0.5
        case .wrong, .missing, .extra: 1
        }
    }

    /// Weighted edit distance over syllables, then a backtrace into steps.
    private static func align(_ expected: [String], _ heard: [String], accent: VietnameseAccent?) -> [Step] {
        let n = expected.count
        let m = heard.count
        var cost = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n + 1)
        for i in 0 ... n { cost[i][0] = Double(i) }
        for j in 0 ... m { cost[0][j] = Double(j) }
        for i in stride(from: 1, through: n, by: 1) {
            for j in stride(from: 1, through: m, by: 1) {
                let pair = cost[i - 1][j - 1]
                    + substitutionCost(mark(expected: expected[i - 1], heard: heard[j - 1], accent: accent))
                cost[i][j] = min(pair, cost[i - 1][j] + 1, cost[i][j - 1] + 1)
            }
        }

        var steps: [Step] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                let pairMark = mark(expected: expected[i - 1], heard: heard[j - 1], accent: accent)
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

    enum Tone: Equatable {
        case ngang, sac, huyen, hoi, nga, nang

        init(of syllable: String) {
            let scalars = syllable.decomposedStringWithCanonicalMapping.unicodeScalars
            if scalars.contains("\u{0301}") { self = .sac }
            else if scalars.contains("\u{0300}") { self = .huyen }
            else if scalars.contains("\u{0309}") { self = .hoi }
            else if scalars.contains("\u{0303}") { self = .nga }
            else if scalars.contains("\u{0323}") { self = .nang }
            else { self = .ngang }
        }

        /// Whole-sentence coaching so translations can reorder the syllables.
        func coaching(expected: String, heard: String) -> String {
            switch self {
            case .ngang: L("**%@** has no tone mark: keep it flat and steady. It sounded like **%@**.", expected, heard)
            case .sac: L("**%@** takes the sắc tone: start mid, then rise sharply. It sounded like **%@**.", expected, heard)
            case .huyen: L("**%@** takes the huyền tone: start low and let it fall gently. It sounded like **%@**.", expected, heard)
            case .hoi: L("**%@** takes the hỏi tone: dip down, then come back up. It sounded like **%@**.", expected, heard)
            case .nga: L("**%@** takes the ngã tone: rise with a little catch in the throat. It sounded like **%@**.", expected, heard)
            case .nang: L("**%@** takes the nặng tone: drop low and cut it short. It sounded like **%@**.", expected, heard)
            }
        }
    }

    private static func tip(for mark: Mark, expected: String, heard: String) -> Tip? {
        switch mark {
        case .correct, .missing, .extra:
            return nil
        case .tone:
            return Tip(
                mark: .tone,
                message: Tone(of: expected).coaching(expected: expected, heard: heard)
            )
        case .spelling:
            if expected.lowercased().contains("đ") != heard.lowercased().contains("đ") {
                return Tip(
                    mark: .spelling,
                    message: L("**%@**: đ is a firm “d”, while d sounds like “z” (north) or “y” (south). It sounded like **%@**.", expected, heard)
                )
            }
            return Tip(
                mark: .spelling,
                message: L("Almost! Check the vowel in **%@**. It sounded like **%@**.", expected, heard)
            )
        case .wrong:
            return Tip(mark: .wrong, message: L("It sounded like **%@** instead of **%@**.", heard, expected))
        }
    }
}

/// Spells digits the way a Vietnamese lesson writes them, so "25" from the
/// transcriber matches "hai mươi lăm" in the target.
enum VietnameseNumber {
    private static let digits = ["không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín"]

    static func spell(_ value: Int) -> [String]? {
        switch value {
        case 0 ..< 10: return [digits[value]]
        case 10 ..< 100: return tens(value)
        case 100 ..< 1000: return hundreds(value)
        case 1000 ..< 10000:
            let rest = value % 1000
            let thousands = [digits[value / 1000], "nghìn"]
            switch rest {
            case 0: return thousands
            case 1 ..< 10: return thousands + ["không", "trăm", "linh", digits[rest]]
            case 10 ..< 100: return thousands + ["không", "trăm"] + tens(rest)
            default: return thousands + hundreds(rest)
            }
        default: return nil
        }
    }

    private static func tens(_ value: Int) -> [String] {
        let ten = value / 10
        let unit = value % 10
        var words = ten == 1 ? ["mười"] : [digits[ten], "mươi"]
        switch unit {
        case 0: break
        case 1: words.append(ten == 1 ? "một" : "mốt")
        case 5: words.append("lăm")
        default: words.append(digits[unit])
        }
        return words
    }

    private static func hundreds(_ value: Int) -> [String] {
        let rest = value % 100
        let words = [digits[value / 100], "trăm"]
        switch rest {
        case 0: return words
        case 1 ..< 10: return words + ["linh", digits[rest]]
        default: return words + tens(rest)
        }
    }
}

/// Forgiving check for the onboarding conversation. A first-time learner
/// passes when speech-to-text heard at least half of the target syllables,
/// ignoring tones, case, punctuation, and the learner's own name (which
/// Vietnamese speech-to-text rarely transcribes faithfully).
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
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
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
                Text(L("No Vietnamese came through. Hold the phone a little closer and speak up."))
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
                    .accessibilityLabel(L("%lld of %lld syllables right", review.correctCount, review.target.count))
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
        let marks: [PronunciationReview.Mark] = [.correct, .tone, .spelling, .wrong, .missing, .extra]
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
        case .missing: KumustaColors.accentDeep
        case .extra: KumustaColors.muted
        case .correct, .tone, .spelling: KumustaColors.ink
        }
    }

    private var background: Color {
        switch mark {
        // Only the target row celebrates correct syllables; on the heard row
        // they stay neutral so the mistakes stand out.
        case .correct: isTarget ? KumustaColors.success.opacity(0.18) : KumustaColors.surface
        case .tone, .spelling: KumustaColors.caution.opacity(0.26)
        case .wrong: KumustaColors.accent
        case .missing: .clear
        case .extra: KumustaColors.surfaceMuted
        }
    }

    private var border: Color {
        switch mark {
        case .correct: isTarget ? KumustaColors.success.opacity(0.55) : KumustaColors.line
        case .tone, .spelling: KumustaColors.caution
        case .wrong, .missing: KumustaColors.accent
        case .extra: KumustaColors.line
        }
    }
}

private extension PronunciationReview.Mark {
    var tint: Color {
        switch self {
        case .correct: KumustaColors.success
        case .tone, .spelling: KumustaColors.caution
        case .wrong, .missing: KumustaColors.accent
        case .extra: KumustaColors.line
        }
    }

    var label: String {
        switch self {
        case .correct: L("Correct")
        case .tone: L("Tone")
        case .spelling: L("Almost")
        case .wrong: L("Wrong")
        case .missing: L("Missing")
        case .extra: L("Extra")
        }
    }

    var symbol: String {
        switch self {
        case .correct: "checkmark"
        case .tone: "waveform.path"
        case .spelling: "textformat.abc"
        case .wrong: "xmark"
        case .missing: "plus"
        case .extra: "minus"
        }
    }
}
