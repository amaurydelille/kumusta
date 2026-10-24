import Foundation

enum FlashcardDirection: String, CaseIterable, Identifiable, Sendable {
    case englishAudioToTagalog
    case tagalogAudioToEnglish

    var id: Self { self }

}

struct OfflineVocabularyCandidate: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let tagalog: String
    let english: String

    init(id: UUID = UUID(), tagalog: String, english: String) {
        self.id = id
        self.tagalog = tagalog
        self.english = english
    }
}

struct FlashcardChoice: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let isCorrect: Bool
}

/// A compact, offline distractor bank. It deliberately contains useful
/// everyday words rather than the authored review phrases that previously
/// dominated the Words tab. It can be replaced by a downloaded catalog later
/// without changing the flashcard interaction.
enum OfflineVocabularyCandidateBank {
    static let all: [OfflineVocabularyCandidate] = [
        candidate("kumusta", "how are you / hello"),
        candidate("salamat", "thank you"),
        candidate("paalam", "goodbye"),
        candidate("pasensya na", "sorry / excuse me"),
        candidate("walang anuman", "you're welcome"),
        candidate("puwede ba", "may I / can I"),
        candidate("sige", "okay / go ahead"),
        candidate("oo", "yes"),
        candidate("hindi", "no / not"),
        candidate("opo", "yes (respectful)"),
        candidate("kape", "coffee"),
        candidate("tubig", "water"),
        candidate("kanin", "cooked rice"),
        candidate("ulam", "main dish (with rice)"),
        candidate("tinapay", "bread"),
        candidate("gatas", "milk"),
        candidate("yelo", "ice"),
        candidate("masarap", "delicious"),
        candidate("gutom", "hungry"),
        candidate("uhaw", "thirsty"),
        candidate("mainit", "hot"),
        candidate("malamig", "cold"),
        candidate("matamis", "sweet"),
        candidate("maanghang", "spicy"),
        candidate("maalat", "salty"),
        candidate("dagdag", "more / extra"),
        candidate("bawas", "less"),
        candidate("isa", "one"),
        candidate("dalawa", "two"),
        candidate("marami", "many / a lot"),
        candidate("kaunti", "a little"),
        candidate("malaki", "big"),
        candidate("maliit", "small"),
        candidate("mabuti", "good / well"),
        candidate("pangit", "ugly / bad"),
        candidate("bago", "new"),
        candidate("luma", "old (things)"),
        candidate("mabilis", "fast"),
        candidate("mabagal", "slow"),
        candidate("malapit", "near"),
        candidate("malayo", "far"),
        candidate("kaliwa", "left"),
        candidate("kanan", "right"),
        candidate("diretso", "straight ahead"),
        candidate("pumunta", "go"),
        candidate("dumating", "arrive"),
        candidate("umuwi", "go home"),
        candidate("lumiko", "turn"),
        candidate("makinig", "listen"),
        candidate("magsalita", "speak"),
        candidate("maintindihan", "understand"),
        candidate("alam", "know"),
        candidate("tandaan", "remember"),
        candidate("nakalimutan", "forgot"),
        candidate("gusto", "want / like"),
        candidate("kailangan", "need"),
        candidate("tulong", "help"),
        candidate("tumawag", "call"),
        candidate("bumili", "buy"),
        candidate("magbayad", "pay"),
        candidate("hiram", "borrow"),
        candidate("maghintay", "wait"),
        candidate("bahay", "house / home"),
        candidate("palengke", "market"),
        candidate("tindahan", "store"),
        candidate("paaralan", "school"),
        candidate("ospital", "hospital"),
        candidate("paliparan", "airport"),
        candidate("trabaho", "work / job"),
        candidate("pamilya", "family"),
        candidate("kaibigan", "friend"),
        candidate("ngayon", "now / today"),
        candidate("bukas", "tomorrow"),
        candidate("kahapon", "yesterday"),
        candidate("mamaya", "later"),
        candidate("saan", "where"),
        candidate("kailan", "when"),
        candidate("bakit", "why"),
        candidate("magkano", "how much"),
        candidate("ano", "what")
    ]

    private static func meaning(of candidate: OfflineVocabularyCandidate, in language: AppLanguage) -> String {
        candidate.english
    }

    static func choices(
        for target: SavedLessonWord,
        direction: FlashcardDirection,
        count: Int = 4
    ) -> [FlashcardChoice] {
        let choiceCount = max(2, min(count, all.count + 1))
        let targetText = direction == .englishAudioToTagalog
            ? optionText(target.word)
            : optionText(target.translation)
        let targetTagalog = normalized(target.word)
        let targetEnglish = normalized(target.translation)
        let language = target.translationLanguage ?? .english

        let distractors = all
            .filter {
                normalized($0.tagalog) != targetTagalog
                    && normalized(meaning(of: $0, in: language)) != targetEnglish
            }
            .shuffled()
            .prefix(choiceCount - 1)
            .map { candidate in
                FlashcardChoice(
                    id: candidate.id,
                    text: direction == .englishAudioToTagalog
                        ? optionText(candidate.tagalog)
                        : optionText(meaning(of: candidate, in: language)),
                    isCorrect: false
                )
            }

        return (
            [FlashcardChoice(id: target.id, text: targetText, isCorrect: true)]
                + distractors
        ).shuffled()
    }

    private static func candidate(_ tagalog: String, _ english: String) -> OfflineVocabularyCandidate {
        OfflineVocabularyCandidate(tagalog: tagalog, english: english)
    }

    private static func optionText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }

        // Isolated vocabulary is displayed in lowercase so capitalization
        // never hints at the correct answer.
        return String(first).lowercased() + String(trimmed.dropFirst())
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "fil")
            )
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
