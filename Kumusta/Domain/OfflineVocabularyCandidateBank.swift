import Foundation

enum FlashcardDirection: String, CaseIterable, Identifiable, Sendable {
    case englishAudioToVietnamese
    case vietnameseAudioToEnglish

    var id: Self { self }

}

struct OfflineVocabularyCandidate: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let vietnamese: String
    let english: String

    init(id: UUID = UUID(), vietnamese: String, english: String) {
        self.id = id
        self.vietnamese = vietnamese
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
        candidate("xin chào", "hello"),
        candidate("cảm ơn", "thank you"),
        candidate("xin lỗi", "sorry"),
        candidate("làm ơn", "please"),
        candidate("tạm biệt", "goodbye"),
        candidate("không sao", "no problem"),
        candidate("được không", "is it okay"),
        candidate("đúng rồi", "that’s right"),
        candidate("chưa", "not yet"),
        candidate("rồi", "already"),
        candidate("hôm nay", "today"),
        candidate("ngày mai", "tomorrow"),
        candidate("hôm qua", "yesterday"),
        candidate("bây giờ", "now"),
        candidate("sau đó", "after that"),
        candidate("ở đâu", "where"),
        candidate("khi nào", "when"),
        candidate("tại sao", "why"),
        candidate("bao nhiêu", "how much / how many"),
        candidate("ai", "who"),
        candidate("gì", "what"),
        candidate("nào", "which"),
        candidate("mình", "I / me"),
        candidate("tôi", "I / me, formal"),
        candidate("bạn", "you / friend"),
        candidate("anh", "older brother / you"),
        candidate("chị", "older sister / you"),
        candidate("em", "younger person / I"),
        candidate("ông", "grandfather / Mr"),
        candidate("bà", "grandmother / Mrs"),
        candidate("người", "person"),
        candidate("nhà", "home / house"),
        candidate("phòng", "room"),
        candidate("cửa", "door"),
        candidate("bàn", "table"),
        candidate("ghế", "chair"),
        candidate("đường", "street"),
        candidate("chợ", "market"),
        candidate("cửa hàng", "shop"),
        candidate("trường", "school"),
        candidate("bệnh viện", "hospital"),
        candidate("sân bay", "airport"),
        candidate("bến xe", "bus station"),
        candidate("nhà ga", "train station"),
        candidate("quán", "shop / café"),
        candidate("cà phê", "coffee"),
        candidate("nước", "water"),
        candidate("cơm", "rice / meal"),
        candidate("phở", "pho"),
        candidate("bánh mì", "bread"),
        candidate("trà", "tea"),
        candidate("sữa", "milk"),
        candidate("đá", "ice"),
        candidate("ngon", "delicious"),
        candidate("đói", "hungry"),
        candidate("khát", "thirsty"),
        candidate("nóng", "hot"),
        candidate("lạnh", "cold"),
        candidate("ngọt", "sweet"),
        candidate("cay", "spicy"),
        candidate("mặn", "salty"),
        candidate("thêm", "more / another"),
        candidate("bớt", "reduce / less"),
        candidate("một", "one"),
        candidate("hai", "two"),
        candidate("nhiều", "many / much"),
        candidate("ít", "few / little"),
        candidate("lớn", "big"),
        candidate("nhỏ", "small"),
        candidate("tốt", "good"),
        candidate("xấu", "bad"),
        candidate("mới", "new"),
        candidate("cũ", "old"),
        candidate("nhanh", "fast / quick"),
        candidate("chậm", "slow"),
        candidate("gần", "near"),
        candidate("xa", "far"),
        candidate("trái", "left"),
        candidate("phải", "right"),
        candidate("thẳng", "straight"),
        candidate("đi", "go"),
        candidate("đến", "arrive / come"),
        candidate("về", "return / go home"),
        candidate("rẽ", "turn"),
        candidate("nghe", "hear / listen"),
        candidate("nói", "speak / say"),
        candidate("hiểu", "understand"),
        candidate("biết", "know"),
        candidate("nhớ", "remember / miss"),
        candidate("quên", "forget"),
        candidate("muốn", "want"),
        candidate("cần", "need"),
        candidate("thích", "like"),
        candidate("giúp", "help"),
        candidate("gọi", "call"),
        candidate("mua", "buy"),
        candidate("bán", "sell"),
        candidate("trả", "pay / return"),
        candidate("mượn", "borrow"),
        candidate("đợi", "wait")
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
        let targetText = direction == .englishAudioToVietnamese
            ? optionText(target.word)
            : optionText(target.translation)
        let targetVietnamese = normalized(target.word)
        let targetEnglish = normalized(target.translation)
        let language = target.translationLanguage ?? .english

        let distractors = all
            .filter {
                normalized($0.vietnamese) != targetVietnamese
                    && normalized(meaning(of: $0, in: language)) != targetEnglish
            }
            .shuffled()
            .prefix(choiceCount - 1)
            .map { candidate in
                FlashcardChoice(
                    id: candidate.id,
                    text: direction == .englishAudioToVietnamese
                        ? optionText(candidate.vietnamese)
                        : optionText(meaning(of: candidate, in: language)),
                    isCorrect: false
                )
            }

        return (
            [FlashcardChoice(id: target.id, text: targetText, isCorrect: true)]
                + distractors
        ).shuffled()
    }

    private static func candidate(_ vietnamese: String, _ english: String) -> OfflineVocabularyCandidate {
        OfflineVocabularyCandidate(vietnamese: vietnamese, english: english)
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
                locale: Locale(identifier: "vi")
            )
            .replacingOccurrences(of: "đ", with: "d")
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
