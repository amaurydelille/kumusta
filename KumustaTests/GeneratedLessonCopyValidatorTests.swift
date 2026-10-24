import Testing
@testable import Kumusta

struct GeneratedLessonCopyValidatorTests {
    @Test("English situation descriptions are accepted")
    func acceptsEnglishSituationCopy() {
        #expect(
            GeneratedLessonCopyValidator.isSafeInterfaceText(
                "The host is warmly inviting guests inside."
            )
        )
    }

    @Test("A single accented loanword in English UI copy is accepted")
    func acceptsCafeInEnglishSituationCopy() {
        #expect(
            GeneratedLessonCopyValidator.isSafeInterfaceText(
                "Start a casual conversation at a café"
            )
        )
    }

    @Test("Tagalog utterances cannot become answer choices")
    func rejectsTagalogAnswerLeakage() {
        #expect(
            !GeneratedLessonCopyValidator.isSafeInterfaceText(
                "Pasok po kayo, kain tayo!"
            )
        )
    }

    @Test("A transliterated utterance cannot become an answer choice")
    func rejectsTransliteratedAnswerLeakage() {
        #expect(
            !GeneratedLessonCopyValidator.isSafeInterfaceText(
                "pasok kayo kain tayo",
                spokenUtterances: ["Pasok kayo, kain tayo!"]
            )
        )
    }
}
