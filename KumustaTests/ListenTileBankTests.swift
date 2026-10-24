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

    @Test("Reads the tone written on a syllable")
    func readsTone() {
        #expect(VietnameseTone.of("ma") == .level)
        #expect(VietnameseTone.of("mà") == .falling)
        #expect(VietnameseTone.of("người") == .falling)
        #expect(VietnameseTone.of("mạ") == .heavy)
        #expect(VietnameseTone.of("hỏi") == .question)
    }

    @Test("Swaps a tone that is already written")
    func swapsExistingTone() {
        #expect(VietnameseTone.applying(.rising, to: "mà") == "má")
        #expect(VietnameseTone.applying(.heavy, to: "người") == "người".replacingOccurrences(of: "ờ", with: "ợ"))
        #expect(VietnameseTone.applying(.level, to: "bán") == "ban")
        #expect(VietnameseTone.applying(.falling, to: "tiếng") == "tiềng")
    }

    @Test("Places a new tone on the right vowel")
    func placesNewTone() {
        #expect(VietnameseTone.applying(.rising, to: "mua") == "múa")
        #expect(VietnameseTone.applying(.falling, to: "hai") == "hài")
        #expect(VietnameseTone.applying(.rising, to: "toan") == "toán")
        #expect(VietnameseTone.applying(.rising, to: "qua") == "quá")
        #expect(VietnameseTone.applying(.question, to: "gia") == "giả")
        #expect(VietnameseTone.applying(.falling, to: "tôi") == "tồi")
        #expect(VietnameseTone.applying(.falling, to: "nguoi") == "nguòi")
        #expect(VietnameseTone.applying(.falling, to: "ươi") == "ười")
    }

    @Test("Syllables without a vowel have no tone variants")
    func noVowelNoVariants() {
        #expect(VietnameseTone.variants(of: "ngh").isEmpty)
        #expect(VietnameseTone.variants(of: "ma").count == 5)
    }

    @Test("Builds tiles from the sentence plus tone look-alikes")
    func buildsBank() throws {
        var generator = SeededGenerator(state: 7)
        let bank = try #require(
            ListenTileBank.make(
                sentence: "Cho tôi một ly cà phê.",
                distractorCount: 3,
                using: &generator
            )
        )
        #expect(bank.answer == ["cho", "tôi", "một", "ly", "cà", "phê"])
        #expect(bank.tiles.count == 9)
        #expect(Set(bank.tiles.map(\.id)).count == 9)

        let distractors = bank.tiles.map(\.text).filter { !bank.answer.contains($0) }
        #expect(distractors.count == 3)
        #expect(Set(distractors).count == 3)
    }

    @Test("Checks picks by text so repeated words fit either slot")
    func checksPicks() throws {
        var generator = SeededGenerator(state: 3)
        let bank = try #require(
            ListenTileBank.make(sentence: "Dạ, dạ được", distractorCount: 2, using: &generator)
        )
        let ids = { (text: String) in bank.tiles.filter { $0.text == text }.map(\.id) }
        let das = ids("dạ")
        let duoc = try #require(ids("được").first)
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
        #expect(ListenTileBank.make(sentence: "Dạ.", distractorCount: 2, using: &generator) == nil)
        let long = Array(repeating: "ba", count: ListenTileBank.maximumSyllables + 1).joined(separator: " ")
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
