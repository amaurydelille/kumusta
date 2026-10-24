import Foundation

/// Tagalog words learners really confuse, used as wrong choices: the case
/// markers, pronoun pairs, demonstratives, and the mag-/nag- aspect prefixes
/// that separate "do" from "did".
enum TagalogLookAlike {
    private static let groups: [[String]] = [
        ["ang", "ng", "sa"],
        ["si", "ni", "kay"],
        ["ka", "kayo"],
        ["ako", "ko", "akin"],
        ["ikaw", "mo", "iyo"],
        ["siya", "niya"],
        ["kami", "tayo"],
        ["ito", "iyan", "iyon"],
        ["dito", "diyan", "doon"],
        ["na", "pa"],
        ["hindi", "huwag", "wala"],
        ["gusto", "ayaw"],
        ["oo", "opo", "hindi po"],
        ["ngayon", "kanina", "mamaya", "bukas"],
    ]

    /// Every look-alike of a lowercased word, without the word itself.
    static func variants(of word: String) -> [String] {
        var variants = groups.first { $0.contains(word) }?.filter { $0 != word } ?? []
        // Aspect: magluto (will/to cook) vs nagluto (cooked).
        for (from, to) in [("mag", "nag"), ("nag", "mag")]
        where word.hasPrefix(from) && word.count > from.count + 2 {
            variants.append(to + word.dropFirst(from.count))
        }
        return variants
    }
}

struct ListenTile: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
}

/// Word tiles for rebuilding a sentence heard during a cold listen: the
/// sentence's own words plus Tagalog look-alikes as wrong choices.
struct ListenTileBank: Equatable, Sendable {
    /// The words of the sentence, in order, as they appear on tiles.
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
                TagalogLookAlike.variants(of: source)
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
                    .lowercased(with: Locale(identifier: "fil"))
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
