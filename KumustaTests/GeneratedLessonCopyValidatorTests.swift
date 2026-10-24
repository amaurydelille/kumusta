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

    @Test("A single European accent in English UI copy is accepted")
    func acceptsCafeInEnglishSituationCopy() {
        #expect(
            GeneratedLessonCopyValidator.isSafeInterfaceText(
                "Start a casual conversation at a café"
            )
        )
    }

    @Test("Vietnamese utterances cannot become answer choices")
    func rejectsVietnameseAnswerLeakage() {
        #expect(
            !GeneratedLessonCopyValidator.isSafeInterfaceText(
                "Mời anh chị vào nhà chơi nha!"
            )
        )
    }

    @Test("A transliterated utterance cannot become an answer choice")
    func rejectsTransliteratedAnswerLeakage() {
        #expect(
            !GeneratedLessonCopyValidator.isSafeInterfaceText(
                "Moi anh chi vao nha choi",
                spokenUtterances: ["Mời anh chị vào nhà chơi nha!"]
            )
        )
    }
}
