import Foundation

enum SampleContent {
    static let coffeeLesson = coffeeLesson(accent: .southern, level: .familiar)

    static func coffeeLesson(
        accent: VietnameseAccent,
        level: ProficiencyLevel
    ) -> Lesson {
        let content = coffeeContent(accent: accent, level: level)
        let lessonID = lessonIDFor(accent: accent, level: level)

        return makeLesson(
            id: lessonID,
            scenario: content.scenario,
            minutes: content.minutes,
            accent: accent,
            phrase: content.phrase,
            translation: content.translation,
            speakingPrompt: content.speakingPrompt,
            chunks: content.chunks
        )
    }

    static func dailySession(
        accent: VietnameseAccent,
        level: ProficiencyLevel,
        dailyMinutes: Int
    ) -> Lesson {
        let supportedMinutes = min(15, max(5, dailyMinutes))
        let targetRounds = LessonSessionPlan.roundCount(for: supportedMinutes)
        let openingRound = coffeeLesson(accent: accent, level: level)
        let followUpRounds = lessonCatalog(for: accent).dropFirst()
        let rounds = Array(([openingRound] + Array(followUpRounds)).prefix(targetRounds))
        let hearRespondIndexes = LessonSessionPlan.hearRespondRoundIndexes(for: rounds.count)
        let steps = rounds.enumerated().flatMap { roundIndex, round in
            round.steps.map { step in
                guard
                    step.kind == .decode,
                    hearRespondIndexes.contains(roundIndex),
                    let exercise = authoredHearRespondExercise(
                        for: round,
                        roundIndex: roundIndex
                    )
                else {
                    return step
                }

                return LessonStep(
                    id: step.id,
                    kind: .hearRespond,
                    prompt: "Listen to the audio, then choose the matching meaning.",
                    vietnamese: step.vietnamese,
                    translation: step.translation,
                    chunks: step.chunks,
                    wordGlosses: step.wordGlosses,
                    hearRespond: exercise
                )
            }
        }

        return Lesson(
            id: dailySessionIDFor(
                accent: accent,
                level: level,
                minutes: supportedMinutes
            ),
            scenario: openingRound.scenario,
            minutes: supportedMinutes,
            accent: accent,
            steps: steps
        )
    }

    private static func authoredHearRespondExercise(
        for round: Lesson,
        roundIndex: Int
    ) -> HearRespondExercise? {
        guard let targetStep = round.steps.first(where: { $0.kind == .speak }) else {
            return nil
        }

        let promptVietnamese: String
        let promptTranslation: String
        let distractors: [String]

        switch round.scenario {
        case "Ask which way to go, then understand the first turn":
            promptVietnamese = targetStep.vietnamese
            promptTranslation = targetStep.translation
            distractors = [
                "Go straight to the intersection, then turn right.",
                "The market is next to the bus station.",
            ]
        case "Recover when someone speaks too quickly":
            promptVietnamese = targetStep.vietnamese
            promptTranslation = targetStep.translation
            distractors = [
                "The speaker is asking you to slow down.",
                "Order an iced milk coffee.",
            ]
        case "Ask which direction leads to the market":
            promptVietnamese = targetStep.vietnamese
            promptTranslation = targetStep.translation
            distractors = [
                "Ask which way the market is.",
                "The bus station is far from here.",
            ]
        default:
            return nil
        }

        let correctOptionIndex = roundIndex % 3
        var optionTranslations = distractors
        optionTranslations.insert(promptTranslation, at: correctOptionIndex)
        let optionIDs = optionTranslations.indices.map { optionIndex in
            responseOptionIDFor(
                lessonID: round.id,
                roundIndex: roundIndex,
                optionIndex: optionIndex
            )
        }

        return HearRespondExercise(
            promptVietnamese: promptVietnamese,
            promptTranslation: promptTranslation,
            options: optionTranslations.enumerated().map { index, translation in
                HearRespondOption(
                    id: optionIDs[index],
                    englishTranslation: translation
                )
            },
            correctOptionID: optionIDs[correctOptionIndex]
        )
    }

    /// A small authored catalog for previews and offline curriculum validation.
    /// These drafts still require the editorial review gate documented in CONTENT_GUIDE.md.
    static func lessonCatalog(for accent: VietnameseAccent) -> [Lesson] {
        lessonDrafts(for: accent).map { draft in
            let lessonID = catalogLessonID(accent: accent, topicPosition: draft.position)
            let chunks = draft.chunks.enumerated().map { index, chunk in
                PhraseChunk(
                    id: catalogChunkID(
                        accent: accent,
                        topicPosition: draft.position,
                        chunkPosition: index + 1
                    ),
                    vietnamese: chunk.vietnamese,
                    english: chunk.english,
                    note: chunk.note
                )
            }

            return makeLesson(
                id: lessonID,
                scenario: draft.scenario,
                minutes: draft.minutes,
                accent: accent,
                phrase: draft.phrase,
                translation: draft.translation,
                speakingPrompt: draft.speakingPrompt,
                chunks: chunks
            )
        }
    }

    static var vocabulary: [VocabularyItem] {
        let referenceDate = Date.now
        return vocabulary(for: .southern, referenceDate: referenceDate)
            + vocabulary(for: .northern, referenceDate: referenceDate)
    }

    static func vocabulary(
        for accent: VietnameseAccent,
        referenceDate: Date = .now
    ) -> [VocabularyItem] {
        vocabularySeeds(for: accent).map { seed in
            VocabularyItem(
                id: vocabularyID(accent: accent, position: seed.position),
                vietnamese: seed.vietnamese,
                english: seed.english,
                example: seed.example,
                exampleTranslation: seed.exampleTranslation,
                accent: accent,
                mastery: seed.mastery,
                nextReviewAt: referenceDate.addingTimeInterval(seed.reviewDelay),
                // Authored curriculum is a source of teachable phrases, not
                // the learner's personal saved vocabulary. A phrase enters
                // the saved bank only after an explicit save action.
                isSaved: false
            )
        }
    }

    private static func makeLesson(
        id: UUID,
        scenario: String,
        minutes: Int,
        accent: VietnameseAccent,
        phrase: String,
        translation: String,
        speakingPrompt: String,
        chunks: [PhraseChunk]
    ) -> Lesson {
        let wordGlosses = authoredWordGlosses(
            phrase: phrase,
            chunks: chunks,
            lessonID: id
        )
        return Lesson(
            id: id,
            scenario: scenario,
            minutes: minutes,
            accent: accent,
            steps: [
                LessonStep(
                    id: stepIDFor(lessonID: id, position: 1),
                    kind: .coldListen,
                    prompt: "Listen once. What is happening in this situation?",
                    vietnamese: phrase,
                    translation: translation,
                    chunks: [],
                    wordGlosses: wordGlosses
                ),
                LessonStep(
                    id: stepIDFor(lessonID: id, position: 2),
                    kind: .decode,
                    prompt: "Build the meaning from useful chunks.",
                    vietnamese: phrase,
                    translation: translation,
                    chunks: chunks,
                    wordGlosses: wordGlosses
                ),
                LessonStep(
                    id: stepIDFor(lessonID: id, position: 3),
                    kind: .speak,
                    prompt: speakingPrompt,
                    vietnamese: phrase,
                    translation: translation,
                    chunks: [],
                    wordGlosses: wordGlosses
                )
            ]
        )
    }

    private static func authoredWordGlosses(
        phrase: String,
        chunks: [PhraseChunk],
        lessonID: UUID
    ) -> [LessonWordGloss] {
        phrase.split(whereSeparator: \.isWhitespace).enumerated().map { index, tokenSlice in
            let token = String(tokenSlice)
            let normalized = token
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased(with: Locale(identifier: "vi"))
            let containingChunk = chunks.first { chunk in
                chunk.vietnamese
                    .lowercased(with: Locale(identifier: "vi"))
                    .split(whereSeparator: \.isWhitespace)
                    .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
                    .contains(normalized)
            }
            return LessonWordGloss(
                id: wordGlossIDFor(lessonID: lessonID, position: index + 1),
                token: token,
                translation: authoredTokenTranslations[normalized]
                    ?? containingChunk?.english
                    ?? "Meaning in this sentence"
            )
        }
    }

    private static let authoredTokenTranslations: [String: String] = [
        "ạ": "polite particle",
        "anh": "you / older man",
        "bao": "how (in ‘how much’)",
        "bạn": "you / friend",
        "bằng": "by / using",
        "bến": "station",
        "bị": "to be affected by",
        "bớt": "reduce",
        "cà": "coffee (compound)",
        "cái": "this thing / item",
        "cấp": "emergency (compound)",
        "chậm": "slowly",
        "chợ": "market",
        "cho": "give / let",
        "chút": "a little",
        "chưa": "not yet",
        "có": "is / have",
        "coi": "see / look at",
        "cốc": "cup",
        "đá": "ice / iced",
        "đây": "here",
        "đi": "go",
        "điện": "electric / phone (compound)",
        "đôi": "pair",
        "đồng": "meter / clock (compound)",
        "đường": "sugar",
        "được": "possible / can",
        "đũa": "chopsticks",
        "em": "me / younger person",
        "gọi": "call",
        "giúp": "help / for",
        "giùm": "help / for",
        "hỏi": "ask",
        "hướng": "direction",
        "khác": "different / another",
        "không": "not / question marker",
        "kịp": "in time / keep up",
        "lạc": "lost",
        "lại": "again",
        "làm": "do / make",
        "ly": "glass",
        "mang": "carry / take",
        "màu": "color",
        "mình": "I / me",
        "một": "one",
        "mượn": "borrow",
        "ngã": "intersection (compound)",
        "nghe": "hear",
        "ngọt": "sweet",
        "nào": "which",
        "nha": "please / friendly particle",
        "nhé": "please / friendly particle",
        "nhiêu": "much (in ‘how much’)",
        "nói": "say / speak",
        "ở": "at / in",
        "phê": "coffee (compound)",
        "phải": "right / correct",
        "rẽ": "turn",
        "sữa": "milk",
        "thêm": "more / another",
        "thoại": "phone (compound)",
        "tiền": "money / fare",
        "tính": "calculate",
        "tôi": "I / me",
        "trái": "left",
        "tư": "four-way (compound)",
        "vào": "enter / come in",
        "vậy": "conversational particle",
        "vâng": "yes",
        "xin": "ask for / please",
        "xuống": "get out / go down",
        "xem": "see / look at",
        "xa": "far"
    ]

    private static func lessonDrafts(for accent: VietnameseAccent) -> [LessonDraft] {
        switch accent {
        case .southern:
            [
                LessonDraft(
                    position: 1,
                    title: "Coffee, your way",
                    scenario: "Order an iced coffee and change the sweetness",
                    minutes: 7,
                    phrase: "Dạ, cho mình một ly cà phê sữa đá, ít ngọt nha.",
                    translation: "I’ll have an iced milk coffee, less sweet please.",
                    speakingPrompt: "Order the same drink with your own sweetness preference.",
                    chunks: [
                        ("Dạ, cho mình", "Yes please, I’ll have", "a warm, polite way to start"),
                        ("một ly cà phê sữa đá", "one iced milk coffee", "ly is common for a drinking glass in the South"),
                        ("ít ngọt nha", "less sweet, please", "nha softens the request")
                    ]
                ),
                LessonDraft(
                    position: 2,
                    title: "Your stop",
                    scenario: "Ask a driver to let you out here",
                    minutes: 5,
                    phrase: "Cho mình xuống ở đây nha.",
                    translation: "Please let me out here.",
                    speakingPrompt: "Tell the driver where you would like to get out.",
                    chunks: [
                        ("cho mình xuống", "let me out", "a compact request to a driver"),
                        ("ở đây", "here", "the place where you want to stop"),
                        ("nha", "please", "keeps the request friendly")
                    ]
                ),
                LessonDraft(
                    position: 3,
                    title: "Find the turn",
                    scenario: "Ask which way to go, then understand the first turn",
                    minutes: 6,
                    phrase: "Cho mình hỏi, quẹo trái ở ngã tư phải không?",
                    translation: "Excuse me, do I turn left at the intersection?",
                    speakingPrompt: "Confirm the turn before you walk on.",
                    chunks: [
                        ("cho mình hỏi", "excuse me, may I ask", "a natural attention-getter"),
                        ("quẹo trái", "turn left", "quẹo is widely heard in the South"),
                        ("ở ngã tư", "at the intersection", "the location of the turn"),
                        ("phải không?", "is that right?", "asks for confirmation")
                    ]
                ),
                LessonDraft(
                    position: 4,
                    title: "Check the price",
                    scenario: "Ask the price and make a gentle counteroffer",
                    minutes: 6,
                    phrase: "Cái này bao nhiêu tiền vậy? Bớt chút được không?",
                    translation: "How much is this? Could you lower it a little?",
                    speakingPrompt: "Ask the price first, then make the request lightly.",
                    chunks: [
                        ("cái này", "this item", "points to the item in front of you"),
                        ("bao nhiêu tiền vậy?", "how much is it?", "vậy makes the question conversational"),
                        ("bớt chút", "lower it a little", "a modest counteroffer"),
                        ("được không?", "would that be possible?", "checks rather than demands")
                    ]
                ),
                LessonDraft(
                    position: 5,
                    title: "Ask for a replay",
                    scenario: "Recover when someone speaks too quickly",
                    minutes: 5,
                    phrase: "Xin lỗi, mình nghe không kịp. Bạn nói chậm lại giùm mình được không?",
                    translation: "Sorry, I couldn’t keep up. Could you say it again more slowly?",
                    speakingPrompt: "Use the full repair line instead of pretending you understood.",
                    chunks: [
                        ("xin lỗi", "sorry / excuse me", "opens the repair politely"),
                        ("mình nghe không kịp", "I couldn’t keep up", "explains the listening problem"),
                        ("nói chậm lại", "say it again more slowly", "asks for a slower replay"),
                        ("giùm mình được không?", "could you do that for me?", "a natural Southern request frame")
                    ]
                ),
                LessonDraft(
                    position: 6,
                    title: "Get help now",
                    scenario: "Ask someone nearby to call an ambulance",
                    minutes: 5,
                    phrase: "Làm ơn gọi cấp cứu giùm tôi!",
                    translation: "Please call an ambulance for me!",
                    speakingPrompt: "Say the emergency request clearly and without extra words.",
                    chunks: [
                        ("làm ơn", "please", "signals an urgent request"),
                        ("gọi cấp cứu", "call emergency medical help", "the essential action"),
                        ("giùm tôi", "for me", "giùm is common in Southern requests")
                    ]
                ),
                LessonDraft(
                    position: 7,
                    title: "Use the meter",
                    scenario: "Ask a taxi driver to use the meter",
                    minutes: 5,
                    phrase: "Anh chạy đồng hồ giùm em nha.",
                    translation: "Please use the taxi meter for me.",
                    speakingPrompt: "Make the meter request clearly before the ride starts.",
                    chunks: [
                        ("Anh chạy đồng hồ", "Please use the meter", "the practical request to the driver"),
                        ("giùm em", "for me", "keeps the request conversational"),
                        ("nha", "please", "softens the ending")
                    ]
                ),
                LessonDraft(
                    position: 8,
                    title: "Find the market",
                    scenario: "Ask which direction leads to the market",
                    minutes: 5,
                    phrase: "Cho mình hỏi, chợ đi hướng nào vậy?",
                    translation: "Excuse me, which way is the market?",
                    speakingPrompt: "Ask for the direction without naming a street.",
                    chunks: [
                        ("Cho mình hỏi", "Excuse me, may I ask", "opens the question naturally"),
                        ("chợ", "the market", "the destination"),
                        ("đi hướng nào vậy?", "which way do I go?", "asks for the direction")
                    ]
                ),
                LessonDraft(
                    position: 9,
                    title: "Check the distance",
                    scenario: "Ask whether the bus station is far away",
                    minutes: 5,
                    phrase: "Bến xe có xa đây không?",
                    translation: "Is the bus station far from here?",
                    speakingPrompt: "Check the distance before deciding how to get there.",
                    chunks: [
                        ("Bến xe", "the bus station", "the destination"),
                        ("có xa đây", "far from here", "the distance you are checking"),
                        ("không?", "is it?", "closes the yes-or-no question")
                    ]
                ),
                LessonDraft(
                    position: 10,
                    title: "See another color",
                    scenario: "Ask a shopkeeper to show another color",
                    minutes: 5,
                    phrase: "Cho mình coi màu khác được không?",
                    translation: "Could I see another color?",
                    speakingPrompt: "Ask to compare one other color before choosing.",
                    chunks: [
                        ("Cho mình coi", "Let me see", "a common Southern shopping request"),
                        ("màu khác", "another color", "the variation you want"),
                        ("được không?", "would that be possible?", "makes the request polite")
                    ]
                ),
                LessonDraft(
                    position: 11,
                    title: "Borrow a phone",
                    scenario: "Explain that you are lost and ask to borrow a phone",
                    minutes: 5,
                    phrase: "Tôi bị lạc. Cho tôi mượn điện thoại được không?",
                    translation: "I’m lost. Could I borrow your phone?",
                    speakingPrompt: "Say both parts so the listener understands why you need help.",
                    chunks: [
                        ("Tôi bị lạc", "I’m lost", "explains the problem first"),
                        ("Cho tôi mượn điện thoại", "Let me borrow your phone", "the help you need"),
                        ("được không?", "would that be possible?", "keeps the request respectful")
                    ]
                ),
                LessonDraft(
                    position: 12,
                    title: "One more pair",
                    scenario: "Ask for another pair of chopsticks at a meal",
                    minutes: 5,
                    phrase: "Cho mình xin thêm một đôi đũa nha.",
                    translation: "Could I have another pair of chopsticks, please?",
                    speakingPrompt: "Ask for the extra pair in one easy breath.",
                    chunks: [
                        ("Cho mình xin thêm", "Could I have another", "a friendly request for an extra item"),
                        ("một đôi đũa", "one pair of chopsticks", "the item you need"),
                        ("nha", "please", "warms the ending")
                    ]
                )
            ]
        case .northern:
            [
                LessonDraft(
                    position: 1,
                    title: "Coffee, your way",
                    scenario: "Order an iced coffee and change the sugar",
                    minutes: 7,
                    phrase: "Vâng, cho mình một cốc cà phê sữa đá, ít đường nhé.",
                    translation: "I’ll have an iced milk coffee with less sugar, please.",
                    speakingPrompt: "Order the same drink with your own sugar preference.",
                    chunks: [
                        ("Vâng, cho mình", "Yes please, I’ll have", "a polite way to start"),
                        ("một cốc cà phê sữa đá", "one iced milk coffee", "cốc is common for a drinking glass in the North"),
                        ("ít đường nhé", "less sugar, please", "nhé softens the request")
                    ]
                ),
                LessonDraft(
                    position: 2,
                    title: "Your stop",
                    scenario: "Ask a driver to let you out here",
                    minutes: 5,
                    phrase: "Cho mình xuống ở đây nhé.",
                    translation: "Please let me out here.",
                    speakingPrompt: "Tell the driver where you would like to get out.",
                    chunks: [
                        ("cho mình xuống", "let me out", "a compact request to a driver"),
                        ("ở đây", "here", "the place where you want to stop"),
                        ("nhé", "please", "keeps the request friendly")
                    ]
                ),
                LessonDraft(
                    position: 3,
                    title: "Find the turn",
                    scenario: "Ask which way to go, then understand the first turn",
                    minutes: 6,
                    phrase: "Cho mình hỏi, rẽ trái ở ngã tư phải không ạ?",
                    translation: "Excuse me, do I turn left at the intersection?",
                    speakingPrompt: "Confirm the turn before you walk on.",
                    chunks: [
                        ("cho mình hỏi", "excuse me, may I ask", "a natural attention-getter"),
                        ("rẽ trái", "turn left", "rẽ is standard in Northern directions"),
                        ("ở ngã tư", "at the intersection", "the location of the turn"),
                        ("phải không ạ?", "is that right?", "ạ adds polite deference")
                    ]
                ),
                LessonDraft(
                    position: 4,
                    title: "Check the price",
                    scenario: "Ask the price and make a gentle counteroffer",
                    minutes: 6,
                    phrase: "Cái này bao nhiêu tiền ạ? Bớt một chút được không ạ?",
                    translation: "How much is this? Could you lower it a little?",
                    speakingPrompt: "Ask the price first, then make the request lightly.",
                    chunks: [
                        ("cái này", "this item", "points to the item in front of you"),
                        ("bao nhiêu tiền ạ?", "how much is it?", "ạ keeps the question polite"),
                        ("bớt một chút", "lower it a little", "a modest counteroffer"),
                        ("được không ạ?", "would that be possible?", "checks rather than demands")
                    ]
                ),
                LessonDraft(
                    position: 5,
                    title: "Ask for a replay",
                    scenario: "Recover when someone speaks too quickly",
                    minutes: 5,
                    phrase: "Xin lỗi, mình chưa nghe kịp. Bạn nói chậm lại giúp mình được không ạ?",
                    translation: "Sorry, I didn’t quite keep up. Could you say it again more slowly?",
                    speakingPrompt: "Use the full repair line instead of pretending you understood.",
                    chunks: [
                        ("xin lỗi", "sorry / excuse me", "opens the repair politely"),
                        ("mình chưa nghe kịp", "I didn’t quite keep up", "explains the listening problem"),
                        ("nói chậm lại", "say it again more slowly", "asks for a slower replay"),
                        ("giúp mình được không ạ?", "could you do that for me?", "a polite Northern request frame")
                    ]
                ),
                LessonDraft(
                    position: 6,
                    title: "Get help now",
                    scenario: "Ask someone nearby to call an ambulance",
                    minutes: 5,
                    phrase: "Làm ơn gọi cấp cứu giúp tôi!",
                    translation: "Please call an ambulance for me!",
                    speakingPrompt: "Say the emergency request clearly and without extra words.",
                    chunks: [
                        ("làm ơn", "please", "signals an urgent request"),
                        ("gọi cấp cứu", "call emergency medical help", "the essential action"),
                        ("giúp tôi", "for me", "giúp is common in Northern requests")
                    ]
                ),
                LessonDraft(
                    position: 7,
                    title: "Use the meter",
                    scenario: "Ask a taxi driver to turn on the meter",
                    minutes: 5,
                    phrase: "Anh bật đồng hồ tính tiền giúp em nhé.",
                    translation: "Please turn on the taxi meter for me.",
                    speakingPrompt: "Make the meter request clearly before the ride starts.",
                    chunks: [
                        ("Anh bật đồng hồ tính tiền", "Please turn on the meter", "the practical request to the driver"),
                        ("giúp em", "for me", "keeps the request polite"),
                        ("nhé", "please", "softens the ending")
                    ]
                ),
                LessonDraft(
                    position: 8,
                    title: "Find the market",
                    scenario: "Ask which way leads to the market",
                    minutes: 5,
                    phrase: "Cho mình hỏi, chợ đi lối nào ạ?",
                    translation: "Excuse me, which way is the market?",
                    speakingPrompt: "Ask for the direction without naming a street.",
                    chunks: [
                        ("Cho mình hỏi", "Excuse me, may I ask", "opens the question naturally"),
                        ("chợ", "the market", "the destination"),
                        ("đi lối nào ạ?", "which way do I go?", "asks politely for the route")
                    ]
                ),
                LessonDraft(
                    position: 9,
                    title: "Check the distance",
                    scenario: "Ask whether the bus station is far away",
                    minutes: 5,
                    phrase: "Bến xe có xa đây không ạ?",
                    translation: "Is the bus station far from here?",
                    speakingPrompt: "Check the distance before deciding how to get there.",
                    chunks: [
                        ("Bến xe", "the bus station", "the destination"),
                        ("có xa đây", "far from here", "the distance you are checking"),
                        ("không ạ?", "is it?", "closes the question politely")
                    ]
                ),
                LessonDraft(
                    position: 10,
                    title: "See another color",
                    scenario: "Ask a shopkeeper to show another color",
                    minutes: 5,
                    phrase: "Cho mình xem màu khác được không ạ?",
                    translation: "Could I see another color?",
                    speakingPrompt: "Ask to compare one other color before choosing.",
                    chunks: [
                        ("Cho mình xem", "Let me see", "a natural shopping request"),
                        ("màu khác", "another color", "the variation you want"),
                        ("được không ạ?", "would that be possible?", "makes the request polite")
                    ]
                ),
                LessonDraft(
                    position: 11,
                    title: "Borrow a phone",
                    scenario: "Explain that you are lost and ask to borrow a phone",
                    minutes: 5,
                    phrase: "Tôi bị lạc. Cho tôi mượn điện thoại được không ạ?",
                    translation: "I’m lost. Could I borrow your phone?",
                    speakingPrompt: "Say both parts so the listener understands why you need help.",
                    chunks: [
                        ("Tôi bị lạc", "I’m lost", "explains the problem first"),
                        ("Cho tôi mượn điện thoại", "Let me borrow your phone", "the help you need"),
                        ("được không ạ?", "would that be possible?", "keeps the request respectful")
                    ]
                ),
                LessonDraft(
                    position: 12,
                    title: "One more pair",
                    scenario: "Ask for another pair of chopsticks at a meal",
                    minutes: 5,
                    phrase: "Cho mình xin thêm một đôi đũa nhé.",
                    translation: "Could I have another pair of chopsticks, please?",
                    speakingPrompt: "Ask for the extra pair in one easy breath.",
                    chunks: [
                        ("Cho mình xin thêm", "Could I have another", "a friendly request for an extra item"),
                        ("một đôi đũa", "one pair of chopsticks", "the item you need"),
                        ("nhé", "please", "warms the ending")
                    ]
                )
            ]
        }
    }

    private static func vocabularySeeds(for accent: VietnameseAccent) -> [VocabularySeed] {
        switch accent {
        case .southern:
            [
                seed(1, "ít ngọt", "less sweet", "Cho mình cà phê ít ngọt nha.", "I’ll have a less-sweet coffee, please.", 0.18, -172_800),
                seed(2, "mang đi", "to take away", "Cho mình phần này mang đi nha.", "I’ll take this order to go, please.", 0.42, 0),
                seed(3, "xin thêm một đôi đũa", "ask for another pair of chopsticks", "Cho mình xin thêm một đôi đũa nha.", "Could I have another pair of chopsticks, please?", 0.67, 259_200),
                seed(4, "xuống ở đây", "get out here", "Cho mình xuống ở đây nha.", "Please let me out here.", 0.31, -86_400),
                seed(5, "hết bao nhiêu?", "how much will it cost?", "Đi sân bay hết bao nhiêu vậy?", "How much will it cost to go to the airport?", 0.55, 86_400),
                seed(6, "chạy đồng hồ", "use the taxi meter", "Anh chạy đồng hồ giùm em nha.", "Please use the meter for me.", 0.76, 604_800),
                seed(7, "quẹo trái", "turn left", "Quẹo trái ở ngã tư.", "Turn left at the intersection.", 0.24, -259_200),
                seed(8, "đi hướng nào?", "which way do I go?", "Cho mình hỏi, chợ đi hướng nào vậy?", "Excuse me, which way is the market?", 0.49, 172_800),
                seed(9, "có xa đây không?", "is it far from here?", "Bến xe có xa đây không?", "Is the bus station far from here?", 0.82, 1_209_600),
                seed(10, "bao nhiêu tiền vậy?", "how much is it?", "Cái này bao nhiêu tiền vậy?", "How much is this?", 0.37, -43_200),
                seed(11, "bớt chút được không?", "could you lower it a little?", "Bớt chút được không?", "Could you lower the price a little?", 0.61, 345_600),
                seed(12, "coi màu khác", "look at another color", "Cho mình coi màu khác được không?", "Could I see another color?", 0.88, 1_814_400),
                seed(13, "nghe không kịp", "not keep up with what was said", "Xin lỗi, mình nghe không kịp.", "Sorry, I couldn’t keep up.", 0.15, -604_800),
                seed(14, "nói chậm lại", "say it again more slowly", "Bạn nói chậm lại giùm mình được không?", "Could you say it again more slowly?", 0.46, 43_200),
                seed(15, "ý bạn là sao?", "what do you mean?", "Xin lỗi, ý bạn là sao vậy?", "Sorry, what do you mean?", 0.72, 432_000),
                seed(16, "giúp tôi với!", "help me!", "Giúp tôi với!", "Help me!", 0.28, -86_400),
                seed(17, "gọi cấp cứu", "call emergency medical help", "Làm ơn gọi cấp cứu giùm tôi!", "Please call an ambulance for me!", 0.53, 86_400),
                seed(18, "cho tôi mượn điện thoại", "let me borrow a phone", "Tôi bị lạc. Cho tôi mượn điện thoại được không?", "I’m lost. Could I borrow your phone?", 0.79, 864_000)
            ]
        case .northern:
            [
                seed(1, "ít đường", "less sugar", "Cho mình cà phê ít đường nhé.", "I’ll have a coffee with less sugar, please.", 0.18, -172_800),
                seed(2, "mang về", "to take away", "Cho mình phần này mang về nhé.", "I’ll take this order away, please.", 0.42, 0),
                seed(3, "xin thêm một đôi đũa", "ask for another pair of chopsticks", "Cho mình xin thêm một đôi đũa nhé.", "Could I have another pair of chopsticks, please?", 0.67, 259_200),
                seed(4, "xuống ở đây", "get out here", "Cho mình xuống ở đây nhé.", "Please let me out here.", 0.31, -86_400),
                seed(5, "hết bao nhiêu tiền?", "how much will it cost?", "Đi ra sân bay hết bao nhiêu tiền ạ?", "How much will it cost to go to the airport?", 0.55, 86_400),
                seed(6, "bật đồng hồ tính tiền", "turn on the taxi meter", "Anh bật đồng hồ tính tiền giúp em nhé.", "Please turn on the meter for me.", 0.76, 604_800),
                seed(7, "rẽ trái", "turn left", "Rẽ trái ở ngã tư.", "Turn left at the intersection.", 0.24, -259_200),
                seed(8, "đi lối nào?", "which way do I go?", "Cho mình hỏi, chợ đi lối nào ạ?", "Excuse me, which way is the market?", 0.49, 172_800),
                seed(9, "có xa đây không?", "is it far from here?", "Bến xe có xa đây không ạ?", "Is the bus station far from here?", 0.82, 1_209_600),
                seed(10, "bao nhiêu tiền ạ?", "how much is it?", "Cái này bao nhiêu tiền ạ?", "How much is this?", 0.37, -43_200),
                seed(11, "bớt một chút được không ạ?", "could you lower it a little?", "Bớt một chút được không ạ?", "Could you lower the price a little?", 0.61, 345_600),
                seed(12, "xem màu khác", "look at another color", "Cho mình xem màu khác được không ạ?", "Could I see another color?", 0.88, 1_814_400),
                seed(13, "chưa nghe kịp", "not quite keep up with what was said", "Xin lỗi, mình chưa nghe kịp.", "Sorry, I didn’t quite keep up.", 0.15, -604_800),
                seed(14, "nói chậm lại", "say it again more slowly", "Bạn nói chậm lại giúp mình được không ạ?", "Could you say it again more slowly?", 0.46, 43_200),
                seed(15, "ý bạn là gì?", "what do you mean?", "Xin lỗi, ý bạn là gì ạ?", "Sorry, what do you mean?", 0.72, 432_000),
                seed(16, "giúp tôi với!", "help me!", "Giúp tôi với!", "Help me!", 0.28, -86_400),
                seed(17, "gọi cấp cứu", "call emergency medical help", "Làm ơn gọi cấp cứu giúp tôi!", "Please call an ambulance for me!", 0.53, 86_400),
                seed(18, "cho tôi mượn điện thoại", "let me borrow a phone", "Tôi bị lạc. Cho tôi mượn điện thoại được không ạ?", "I’m lost. Could I borrow your phone?", 0.79, 864_000)
            ]
        }
    }

    private static func seed(
        _ position: Int,
        _ vietnamese: String,
        _ english: String,
        _ example: String,
        _ exampleTranslation: String,
        _ mastery: Double,
        _ reviewDelay: TimeInterval
    ) -> VocabularySeed {
        VocabularySeed(
            position: position,
            vietnamese: vietnamese,
            english: english,
            example: example,
            exampleTranslation: exampleTranslation,
            mastery: mastery,
            reviewDelay: reviewDelay
        )
    }

    private static func coffeeContent(
        accent: VietnameseAccent,
        level: ProficiencyLevel
    ) -> CoffeeContent {
        let vessel = accent == .southern ? "ly" : "cốc"
        let softener = accent == .southern ? "nha" : "nhé"
        let sweetness = accent == .southern ? "ít ngọt" : "ít đường"
        let politeLead = accent == .southern ? "Dạ, " : "Vâng, "

        let phrase: String
        let translation: String
        let scenario: String
        let minutes: Int
        let speakingPrompt: String
        var chunkCopy: [(String, String, String)]

        switch level {
        case .new:
            phrase = "Cho mình một \(vessel) cà phê sữa đá \(softener)."
            translation = "I’ll have an iced milk coffee, please."
            scenario = "Order one iced milk coffee naturally"
            minutes = 5
            speakingPrompt = "Now make the simple order yourself."
            chunkCopy = [
                ("Cho mình", "I’ll have", "a natural way to begin an order"),
                ("một \(vessel)", "one cup", accent == .southern ? "ly is common in the South" : "cốc is common in the North"),
                ("cà phê sữa đá", "iced milk coffee", "the whole drink name"),
                (softener, "please", "a warm sentence-ending softener")
            ]
        case .familiar:
            phrase = "Cho mình một \(vessel) cà phê sữa đá, \(sweetness) \(softener)."
            translation = "I’ll have an iced milk coffee, less sweet please."
            scenario = "Order an iced coffee and change the sweetness"
            minutes = 7
            speakingPrompt = "Now order it with your own sweetness preference."
            chunkCopy = [
                ("Cho mình", "I’ll have", "a natural ordering opener"),
                ("cà phê sữa đá", "iced milk coffee", "the order"),
                (sweetness, accent == .southern ? "less sweet" : "less sugar", "the useful change"),
                (softener, "please", "social glue at the end")
            ]
        case .conversational:
            phrase = "Cho mình một \(vessel) cà phê sữa đá, \(sweetness), mang đi \(softener)."
            translation = "I’ll have an iced milk coffee, less sweet, to take away please."
            scenario = "Customize a coffee and ask for it to go"
            minutes = 8
            speakingPrompt = "Now keep the full request moving in one breath."
            chunkCopy = [
                ("Cho mình một \(vessel)", "I’ll have one cup", "keep this opener light"),
                ("cà phê sữa đá", "iced milk coffee", "the core order"),
                (sweetness, accent == .southern ? "less sweet" : "less sugar", "the customization"),
                ("mang đi \(softener)", "to take away, please", "finish with the service detail")
            ]
        case .rusty:
            phrase = "\(politeLead)cho mình một \(vessel) cà phê sữa đá, \(sweetness), mang đi \(softener)."
            translation = "Yes please, I’ll have an iced milk coffee, less sweet, to take away."
            scenario = "Bring a familiar, polite coffee order back into your voice"
            minutes = 7
            speakingPrompt = "Say it once without overthinking the words you already know."
            chunkCopy = [
                (politeLead.trimmingCharacters(in: .whitespaces), "yes / certainly", "a polite response before ordering"),
                ("cho mình một \(vessel)", "I’ll have one cup", "an everyday ordering rhythm"),
                (sweetness, accent == .southern ? "less sweet" : "less sugar", "the preference"),
                ("mang đi \(softener)", "to take away, please", "close the request naturally")
            ]
        }

        let chunks = chunkCopy.enumerated().map { index, chunk in
            PhraseChunk(
                id: chunkIDFor(accent: accent, level: level, position: index + 1),
                vietnamese: chunk.0,
                english: chunk.1,
                note: chunk.2
            )
        }

        return CoffeeContent(
            title: level == .new ? "Your first coffee" : "Coffee, your way",
            scenario: scenario,
            minutes: minutes,
            phrase: phrase,
            translation: translation,
            speakingPrompt: speakingPrompt,
            chunks: chunks
        )
    }

    private static func lessonIDFor(
        accent: VietnameseAccent,
        level: ProficiencyLevel
    ) -> UUID {
        let accentDigit = accent == .southern ? "1" : "2"
        let levelDigit: String = switch level {
        case .new: "1"
        case .familiar: "2"
        case .conversational: "3"
        case .rusty: "4"
        }
        return uuid("20000000-0000-0000-0000-0000000000\(accentDigit)\(levelDigit)")
    }

    private static func dailySessionIDFor(
        accent: VietnameseAccent,
        level: ProficiencyLevel,
        minutes: Int
    ) -> UUID {
        let accentSeed = accent == .southern ? 1_000 : 2_000
        let levelSeed: Int = switch level {
        case .new: 100
        case .familiar: 200
        case .conversational: 300
        case .rusty: 400
        }
        return deterministicUUID(
            namespace: "23000000",
            seed: accentSeed + levelSeed + minutes
        )
    }

    private static func catalogLessonID(accent: VietnameseAccent, topicPosition: Int) -> UUID {
        deterministicUUID(namespace: "20000000", seed: (accent == .southern ? 100 : 200) + topicPosition)
    }

    private static func stepIDFor(lessonID: UUID, position: Int) -> UUID {
        let lessonSeed = Int(lessonID.uuidString.suffix(12)) ?? 0
        return deterministicUUID(namespace: "21000000", seed: (lessonSeed * 10) + position)
    }

    private static func wordGlossIDFor(lessonID: UUID, position: Int) -> UUID {
        let lessonSeed = Int(lessonID.uuidString.suffix(12)) ?? 0
        return deterministicUUID(namespace: "24000000", seed: (lessonSeed * 100) + position)
    }

    private static func responseOptionIDFor(
        lessonID: UUID,
        roundIndex: Int,
        optionIndex: Int
    ) -> UUID {
        let lessonSeed = Int(lessonID.uuidString.suffix(12)) ?? 0
        return deterministicUUID(
            namespace: "25000000",
            seed: (lessonSeed * 100) + ((roundIndex + 1) * 10) + optionIndex + 1
        )
    }

    private static func catalogChunkID(
        accent: VietnameseAccent,
        topicPosition: Int,
        chunkPosition: Int
    ) -> UUID {
        let lessonSeed = (accent == .southern ? 100 : 200) + topicPosition
        return deterministicUUID(namespace: "22000000", seed: (lessonSeed * 10) + chunkPosition)
    }

    private static func chunkIDFor(
        accent: VietnameseAccent,
        level: ProficiencyLevel,
        position: Int
    ) -> UUID {
        let accentDigit = accent == .southern ? "1" : "2"
        let levelDigit: String = switch level {
        case .new: "1"
        case .familiar: "2"
        case .conversational: "3"
        case .rusty: "4"
        }
        return uuid("22000000-0000-0000-0000-00000000\(accentDigit)\(levelDigit)0\(position)")
    }

    private static func vocabularyID(accent: VietnameseAccent, position: Int) -> UUID {
        let seed = (accent == .southern ? 300_000 : 310_000) + position
        return deterministicUUID(namespace: "30000000", seed: seed)
    }

    private static func deterministicUUID(namespace: String, seed: Int) -> UUID {
        uuid("\(namespace)-0000-0000-0000-\(String(format: "%012d", seed))")
    }

    private static func uuid(_ value: String) -> UUID {
        guard let id = UUID(uuidString: value) else {
            preconditionFailure("Invalid deterministic sample-content UUID: \(value)")
        }
        return id
    }
}

private struct CoffeeContent {
    let title: String
    let scenario: String
    let minutes: Int
    let phrase: String
    let translation: String
    let speakingPrompt: String
    let chunks: [PhraseChunk]
}

private struct LessonDraft {
    let position: Int
    let title: String
    let scenario: String
    let minutes: Int
    let phrase: String
    let translation: String
    let speakingPrompt: String
    let chunks: [(vietnamese: String, english: String, note: String)]
}

private struct VocabularySeed {
    let position: Int
    let vietnamese: String
    let english: String
    let example: String
    let exampleTranslation: String
    let mastery: Double
    let reviewDelay: TimeInterval
}
