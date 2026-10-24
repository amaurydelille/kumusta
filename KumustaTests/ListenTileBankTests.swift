import Testing
@testable import Kumusta

struct ListenTileBankTests {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @Test("Offers the words learners really confuse")
    func offersLookAlikes() {
        #expect(Set(TagalogLookAlike.variants(of: "ang")) == ["ng", "sa"])
        #expect(TagalogLookAlike.variants(of: "ka") == ["kayo"])
        #expect(Set(TagalogLookAlike.variants(of: "ito")) == ["iyan", "iyon"])
        #expect(TagalogLookAlike.variants(of: "nagluto") == ["magluto"])
        #expect(TagalogLookAlike.variants(of: "magluluto").contains("nagluluto"))
    }

    @Test("Short or unknown words have no look-alikes")
    func unknownWordsHaveNone() {
        #expect(TagalogLookAlike.variants(of: "kape").isEmpty)
        #expect(TagalogLookAlike.variants(of: "mag").isEmpty)
    }

    @Test("Builds tiles from the sentence plus look-alikes")
    func buildsBank() throws {
        var generator = SeededGenerator(state: 7)
        let bank = try #require(
            ListenTileBank.make(
                sentence: "Gusto ko ang kape dito.",
                distractorCount: 3,
                using: &generator
            )
        )
        #expect(bank.answer == ["gusto", "ko", "ang", "kape", "dito"])
        #expect(bank.tiles.count == 8)
        #expect(Set(bank.tiles.map(\.id)).count == 8)

        let distractors = bank.tiles.map(\.text).filter { !bank.answer.contains($0) }
        #expect(distractors.count == 3)
        #expect(Set(distractors).count == 3)
    }

    @Test("Checks picks by text so repeated words fit either slot")
    func checksPicks() throws {
        var generator = SeededGenerator(state: 3)
        let bank = try #require(
            ListenTileBank.make(sentence: "Sige, sige po", distractorCount: 2, using: &generator)
        )
        let ids = { (text: String) in bank.tiles.filter { $0.text == text }.map(\.id) }
        let das = ids("sige")
        let duoc = try #require(ids("po").first)
        #expect(das.count == 2)

        #expect(bank.isCorrect([das[1], das[0], duoc]))
        #expect(bank.wrongPositions(for: [das[0], duoc, das[1]]) == [1, 2])
        #expect(!bank.isCorrect([das[0], das[1]]))
        #expect(bank.wrongPositions(for: [nil, das[0], duoc]) == [0])
        #expect(!bank.isCorrect([nil, das[0], duoc]))
    }

    @Test("Skips sentences that are too short or too long")
    func skipsUnusableSentences() {
        var generator = SeededGenerator(state: 1)
        #expect(ListenTileBank.make(sentence: "Opo.", distractorCount: 2, using: &generator) == nil)
        let long = Array(repeating: "isa", count: ListenTileBank.maximumSyllables + 1).joined(separator: " ")
        #expect(ListenTileBank.make(sentence: long, distractorCount: 2, using: &generator) == nil)
    }
}

@MainActor
struct WordSelectPitchTests {
    @Test("Each next slot pops higher, from the original pitch")
    func pitchClimbs() {
        for slotCount in [2, 6, 8, 9, 12] {
            let steps = (0..<slotCount).map {
                WordSelectFeedbackPlayer.semitones(forStep: $0, slotCount: slotCount)
            }
            #expect(steps[0] == 0)
            #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 < $1 })
            #expect(steps.allSatisfy { $0 <= 12 })
        }
    }
}
