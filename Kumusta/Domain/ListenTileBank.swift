import Foundation

/// The six Vietnamese tones and the combining mark each one adds to a vowel.
enum VietnameseTone: CaseIterable, Sendable {
    case level
    case falling
    case rising
    case question
    case tumbling
    case heavy

    var mark: Unicode.Scalar? {
        switch self {
        case .level: nil
        case .falling: "\u{0300}"
        case .rising: "\u{0301}"
        case .question: "\u{0309}"
        case .tumbling: "\u{0303}"
        case .heavy: "\u{0323}"
        }
    }

    init(mark: Unicode.Scalar) {
        self = Self.allCases.first { $0.mark == mark } ?? .level
    }

    static func isToneMark(_ scalar: Unicode.Scalar) -> Bool {
        allCases.contains { $0.mark == scalar }
    }

    /// The tone written on a single syllable, or `.level` when it carries no mark.
    static func of(_ syllable: String) -> VietnameseTone {
        let mark = syllable.decomposedStringWithCanonicalMapping.unicodeScalars
            .first(where: isToneMark)
        return mark.map(VietnameseTone.init(mark:)) ?? .level
    }

    /// Rewrites one syllable with `tone`, keeping its consonants and vowel
    /// shapes. Returns nil when the syllable has no vowel to carry a tone.
    static func applying(_ tone: VietnameseTone, to syllable: String) -> String? {
        // Each cluster is a base letter followed by its combining marks.
        var clusters: [[Unicode.Scalar]] = []
        var toneCarrier: Int?
        for scalar in syllable.decomposedStringWithCanonicalMapping.unicodeScalars {
            if isToneMark(scalar) {
                toneCarrier = clusters.indices.last
            } else if scalar.properties.canonicalCombiningClass == .notReordered || clusters.isEmpty {
                clusters.append([scalar])
            } else {
                clusters[clusters.count - 1].append(scalar)
            }
        }

        guard let carrier = toneCarrier ?? toneCarrierIndex(in: clusters) else { return nil }
        if let mark = tone.mark {
            clusters[carrier].append(mark)
        }
        var scalars = String.UnicodeScalarView()
        clusters.joined().forEach { scalars.append($0) }
        return String(scalars).precomposedStringWithCanonicalMapping
    }

    /// Every other tone of `syllable`, e.g. "ma" → "mà", "má", "mả", "mã", "mạ".
    static func variants(of syllable: String) -> [String] {
        let current = of(syllable)
        return allCases
            .filter { $0 != current }
            .compactMap { applying($0, to: syllable) }
    }

    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
    private static let vowelShapeMarks: Set<Unicode.Scalar> = ["\u{0302}", "\u{0306}", "\u{031B}"]

    /// Where an unmarked syllable takes its tone: a shaped vowel (â, ơ, ư…)
    /// wins; otherwise the last vowel of a closed syllable, or the second to
    /// last vowel of an open one ("hoà" style is written "hòa").
    private static func toneCarrierIndex(in clusters: [[Unicode.Scalar]]) -> Int? {
        let letters = clusters.map { Character($0[0]).lowercased().first ?? " " }
        var nucleus = letters.indices.filter { vowels.contains(letters[$0]) }
        guard let first = nucleus.first else { return nil }

        // The u of "qu" and the i of "gi" belong to the consonant.
        if nucleus.count > 1,
           (first == 1 && letters[0] == "q" && letters[1] == "u")
            || (first == 1 && letters[0] == "g" && letters[1] == "i") {
            nucleus.removeFirst()
        }
        // Only the first run of vowels forms the nucleus.
        var run: [Int] = []
        for index in nucleus where run.isEmpty || index == run[run.count - 1] + 1 {
            run.append(index)
        }

        if let shaped = run.last(where: { index in
            clusters[index].dropFirst().contains(where: vowelShapeMarks.contains)
        }) {
            return shaped
        }
        guard run.count > 1 else { return run[0] }
        let isClosed = run[run.count - 1] < letters.count - 1
        return isClosed ? run[run.count - 1] : run[run.count - 2]
    }
}

struct ListenTile: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
}

/// Word tiles for rebuilding a sentence heard during a cold listen: the
/// sentence's own syllables plus tone-swapped look-alikes as wrong choices.
struct ListenTileBank: Equatable, Sendable {
    /// The syllables of the sentence, in order, as they appear on tiles.
    let answer: [String]
    let tiles: [ListenTile]

    static let maximumSyllables = 12

    static func make<Generator: RandomNumberGenerator>(
        sentence: String,
        distractorCount: Int,
        using generator: inout Generator
    ) -> ListenTileBank? {
        let answer = tileTexts(in: sentence)
        guard (2...maximumSyllables).contains(answer.count) else { return nil }

        let answerSet = Set(answer)
        var variantsBySource = Array(answerSet)
            .sorted()
            .map { source in
                VietnameseTone.variants(of: source)
                    .filter { !answerSet.contains($0) }
                    .shuffled(using: &generator)
            }
            .filter { !$0.isEmpty }
        variantsBySource.shuffle(using: &generator)

        // One look-alike per source word first, so the traps spread across the sentence.
        var distractors: [String] = []
        var round = 0
        while distractors.count < distractorCount,
              variantsBySource.contains(where: { $0.count > round }) {
            for variants in variantsBySource where variants.count > round {
                guard distractors.count < distractorCount else { break }
                if !distractors.contains(variants[round]) {
                    distractors.append(variants[round])
                }
            }
            round += 1
        }

        let tiles = (answer + distractors)
            .enumerated()
            .map { ListenTile(id: $0.offset, text: $0.element) }
            .shuffled(using: &generator)
        return ListenTileBank(answer: answer, tiles: tiles)
    }

    /// Suggested number of wrong tiles: short sentences get fewer traps.
    static func distractorCount(forSyllables count: Int) -> Int {
        count <= 4 ? 2 : 3
    }

    static func tileTexts(in sentence: String) -> [String] {
        sentence
            .split(whereSeparator: \.isWhitespace)
            .map {
                $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
                    .lowercased(with: Locale(identifier: "vi"))
            }
            .filter { !$0.isEmpty }
    }

    func tile(id: Int) -> ListenTile? {
        tiles.first { $0.id == id }
    }

    /// Slot positions whose picked tile does not match the sentence; nil marks
    /// an empty slot. Tiles are compared by text, so a repeated word can fill
    /// either of its slots.
    func wrongPositions(for pickedTileIDs: [Int?]) -> [Int] {
        answer.indices.filter { position in
            guard pickedTileIDs.indices.contains(position),
                  let pickedID = pickedTileIDs[position],
                  let picked = tile(id: pickedID) else { return true }
            return picked.text != answer[position]
        }
    }

    func isCorrect(_ pickedTileIDs: [Int?]) -> Bool {
        pickedTileIDs.count == answer.count && wrongPositions(for: pickedTileIDs).isEmpty
    }
}
