import Foundation
import Testing
@testable import Kumusta

@Suite("Spoken utterance boundary")
struct SpokenUtteranceTests {
    @Test("English role label is not spoken")
    func stripsEnglishRole() {
        #expect(
            SpokenUtterance.playbackText(
                from: "Barista: Chào anh! Anh muốn uống gì ạ?"
            ) == "Chào anh! Anh muốn uống gì ạ?"
        )
    }

    @Test("Vietnamese role label is not spoken")
    func stripsVietnameseRole() {
        #expect(
            SpokenUtterance.playbackText(
                from: "Người bán hàng: Chào anh!"
            ) == "Chào anh!"
        )
    }

    @Test("A spoken Vietnamese vocative remains intact")
    func preservesVocative() {
        let phrase = "Anh ơi, cho mình một cà phê sữa đá nha."
        #expect(SpokenUtterance.playbackText(from: phrase) == phrase)
        #expect(!SpokenUtterance.hasLeadingSpeakerLabel(phrase))
    }
}

@Suite("Onboarding first conversation")
struct OnboardingFirstConversationTests {
    @Test("Speech matching ignores tones, punctuation, and the learner's name")
    func lenientMatching() {
        #expect(OnboardingSpeechMatcher.matches(transcript: "chao ban", target: "Chào bạn!", ignoringName: nil))
        #expect(OnboardingSpeechMatcher.matches(transcript: "Mình tên là Amory", target: "Mình tên là Amaury.", ignoringName: "Amaury"))
        #expect(OnboardingSpeechMatcher.matches(transcript: "tên là", target: "Mình tên là Amaury.", ignoringName: "Amaury"))
        #expect(!OnboardingSpeechMatcher.matches(transcript: "tạm biệt", target: "Chào bạn!", ignoringName: nil))
        #expect(!OnboardingSpeechMatcher.matches(transcript: "Amaury", target: "Mình tên là Amaury.", ignoringName: "Amaury"))
    }

    @Test("Only plain first names are spoken")
    func spokenFirstName() {
        #expect(OnboardingConversationAudio.spokenFirstName(from: "  amaury delille ") == "Amaury")
        #expect(OnboardingConversationAudio.spokenFirstName(from: "Jean-Luc") == "Jean-Luc")
        #expect(OnboardingConversationAudio.spokenFirstName(from: "Thảo") == "Thảo")
        #expect(OnboardingConversationAudio.spokenFirstName(from: "R2D2") == nil)
        #expect(OnboardingConversationAudio.spokenFirstName(from: "😀") == nil)
        #expect(OnboardingConversationAudio.spokenFirstName(from: "") == nil)
    }
}

@Suite("On-device pronunciation review")
struct PronunciationReviewTests {
    private func marks(_ syllables: [PronunciationReview.Syllable]) -> [PronunciationReview.Mark] {
        syllables.map(\.mark)
    }

    @Test("Case and punctuation never fail a clean take")
    func ignoresCaseAndPunctuation() {
        let review = PronunciationReview(target: "Chào bạn, khỏe không?", transcript: "chào bạn khỏe không")
        #expect(review.isMatch)
        #expect(review.tips.isEmpty)
    }

    @Test("Composed and decomposed Unicode compare equal")
    func unicodeNormalization() {
        let decomposed = "Chào bạn".decomposedStringWithCanonicalMapping
        #expect(PronunciationReview(target: "Chào bạn", transcript: decomposed).isMatch)
    }

    @Test("A wrong tone is flagged as a tone, not a wrong word")
    func toneMistake() {
        let review = PronunciationReview(target: "Cảm ơn", transcript: "cám ơn")
        #expect(!review.isMatch)
        #expect(marks(review.target) == [.tone, .correct])
        #expect(review.tips.first?.mark == .tone)
        #expect(review.tips.first?.message.contains("hỏi") == true)
    }

    @Test("A vowel-mark slip is an almost, not a tone")
    func vowelMistake() {
        let review = PronunciationReview(target: "mơ", transcript: "mo")
        #expect(marks(review.target) == [.spelling])
    }

    @Test("Skipped syllables are missing and grouped in one tip")
    func missingSyllables() {
        let review = PronunciationReview(target: "Tôi muốn uống cà phê", transcript: "tôi muốn cà phê")
        #expect(marks(review.target) == [.correct, .correct, .missing, .correct, .correct])
        #expect(review.tips == [.init(mark: .missing, message: "Don’t skip **uống**.")])
    }

    @Test("A different word is wrong, an added word is extra")
    func wrongAndExtra() {
        let review = PronunciationReview(target: "Tôi là sinh viên", transcript: "tôi là giáo viên ạ")
        #expect(marks(review.target) == [.correct, .correct, .wrong, .correct])
        #expect(marks(review.heard) == [.correct, .correct, .wrong, .correct, .extra])
    }

    @Test("Extra filler syllables do not fail an otherwise clean take")
    func extraFillerStillMatches() {
        #expect(PronunciationReview(target: "Cảm ơn", transcript: "à cảm ơn").isMatch)
    }

    @Test("Digits from the transcriber match spelled-out numbers")
    func numbersAreSpelled() {
        #expect(PronunciationReview(target: "Hai mươi lăm nghìn", transcript: "25 nghìn").isMatch)
        #expect(VietnameseNumber.spell(21) == ["hai", "mươi", "mốt"])
        #expect(VietnameseNumber.spell(105) == ["một", "trăm", "linh", "năm"])
    }

    @Test("Punctuation anywhere never fails a take", arguments: [
        "Chào bạn… khỏe không!!",
        "« chào bạn » , khỏe không ?",
        "chào-bạn khỏe-không",
        "Chào bạn.Khỏe không",
    ])
    func punctuationIsForgiven(transcript: String) {
        let review = PronunciationReview(target: "Chào bạn, khỏe không?", transcript: transcript)
        #expect(review.isMatch)
        #expect(marks(review.target) == [.correct, .correct, .correct, .correct])
    }

    @Test("Where the tone mark sits and i/y spellings are the same word")
    func spellingVariants() {
        #expect(PronunciationReview(target: "hoà bình", transcript: "hòa bình").isMatch)
        #expect(PronunciationReview(target: "Thuý", transcript: "thúy").isMatch)
        #expect(PronunciationReview(target: "kỹ sư", transcript: "kĩ sư").isMatch)
        #expect(PronunciationReview(target: "lý do", transcript: "lí do").isMatch)
        // Real vowel differences stay differences.
        #expect(!PronunciationReview(target: "tay", transcript: "tai").isMatch)
    }

    @Test("Sounds every accent merges count as correct")
    func everyAccentMerges() {
        for accent in VietnameseAccent.allCases {
            #expect(PronunciationReview(target: "đi chợ", transcript: "đi trợ", accent: accent).isMatch, "tr/ch \(accent)")
            #expect(PronunciationReview(target: "xin chào", transcript: "sin chào", accent: accent).isMatch, "s/x \(accent)")
            #expect(PronunciationReview(target: "thích quá", transcript: "thíc quá", accent: accent).isMatch, "-ch/-c \(accent)")
        }
    }

    @Test("Southern merges: hỏi/ngã, v/d, final t/c, n/ng, nh/n, iêu/iu")
    func southernMerges() {
        let pairs = [
            ("Mẹ nghĩ", "mẹ nghỉ"),
            ("về nhà", "dề nhà"),
            ("mắt đẹp", "mắc đẹp"),
            ("cái bàn", "cái bàng"),
            ("anh ơi", "an ơi"),
            ("nhiều lắm", "nhìu lắm"),
        ]
        for (target, heard) in pairs {
            #expect(PronunciationReview(target: target, transcript: heard, accent: .southern).isMatch, "\(target)")
            #expect(!PronunciationReview(target: target, transcript: heard, accent: .northern).isMatch, "\(target)")
        }
    }

    @Test("Northern merges r, d and gi")
    func northernMerges() {
        #expect(PronunciationReview(target: "rất vui", transcript: "dất vui", accent: .northern).isMatch)
        #expect(PronunciationReview(target: "rất vui", transcript: "giất vui", accent: .northern).isMatch)
        #expect(!PronunciationReview(target: "rất vui", transcript: "dất vui", accent: .southern).isMatch)
    }

    @Test("A dropped or mistoned polite particle at the end is forgiven")
    func trailingParticles() {
        #expect(PronunciationReview(target: "Chào anh ạ.", transcript: "chào anh").isMatch)
        #expect(PronunciationReview(target: "Chào anh ạ.", transcript: "chào anh à").isMatch)
        #expect(PronunciationReview(target: "Đi nhé!", transcript: "đi").isMatch)
        // Only at the end: a skipped word mid-phrase still fails.
        #expect(!PronunciationReview(target: "Dạ em cảm ơn", transcript: "em cảm ơn").isMatch)
    }

    @Test("One slip passes in a phrase of three or more syllables, two do not")
    func singleSlipAllowance() {
        let one = PronunciationReview(target: "Tôi muốn uống cà phê", transcript: "tôi muốn uống cá phê")
        #expect(one.isMatch)
        #expect(marks(one.target) == [.correct, .correct, .correct, .tone, .correct])
        #expect(one.tips.first?.mark == .tone)
        #expect(!PronunciationReview(target: "Tôi muốn uống cà phê", transcript: "tối muốn uống cá phê").isMatch)
        #expect(!PronunciationReview(target: "Tôi muốn uống cà phê", transcript: "tôi muốn ăn cà phê").isMatch)
    }

    @Test("Short phrases forgive only the low tones that sound alike")
    func softToneSlips() {
        #expect(PronunciationReview(target: "bạn", transcript: "bàn").isMatch)
        #expect(PronunciationReview(target: "một ly", transcript: "mốt ly").isMatch)
        #expect(!PronunciationReview(target: "bạn", transcript: "bán").isMatch)
        #expect(!PronunciationReview(target: "ma", transcript: "mả").isMatch)
    }

    @Test("Silence marks every target syllable missing")
    func emptyTranscript() {
        let review = PronunciationReview(target: "Xin chào", transcript: "")
        #expect(review.heardNothing)
        #expect(marks(review.target) == [.missing, .missing])
        #expect(!review.isMatch)
    }
}

private struct StubSpeechRecognizer: VietnameseSpeechRecognizing {
    let result: Result<String, SpeechRecognitionError>

    func transcribe(audio: Data) async throws -> SpeechTranscription {
        let transcript = try result.get()
        return SpeechTranscription(version: 1, transcript: transcript, languageCode: "vie", languageProbability: nil, words: [])
    }
}

@Suite("Speech recognition fallback")
struct SpeechRecognitionFallbackTests {
    private let audio = Data(repeating: 0, count: 1024)

    @Test("A provider outage falls back to the on-device recognizer")
    func outageUsesFallback() async throws {
        let service = FallbackSpeechRecognitionService(
            primary: StubSpeechRecognizer(result: .failure(.temporarilyUnavailable)),
            fallback: StubSpeechRecognizer(result: .success("xin chào"))
        )
        #expect(try await service.transcribe(audio: audio).transcript == "xin chào")
    }

    @Test("Access and learner errors never reach the fallback", arguments: [
        SpeechRecognitionError.premiumRequired,
        .authenticationRequired,
        .rateLimited,
        .speechNotDetected,
        .invalidAudio,
    ])
    func gatedErrorsSurface(error: SpeechRecognitionError) async {
        let service = FallbackSpeechRecognitionService(
            primary: StubSpeechRecognizer(result: .failure(error)),
            fallback: StubSpeechRecognizer(result: .success("xin chào"))
        )
        await #expect(throws: error) { try await service.transcribe(audio: audio) }
    }

    @Test("A failed fallback reports the outage, or silence when it heard none")
    func failedFallback() async {
        let outage = FallbackSpeechRecognitionService(
            primary: StubSpeechRecognizer(result: .failure(.temporarilyUnavailable)),
            fallback: StubSpeechRecognizer(result: .failure(.responseInvalid))
        )
        await #expect(throws: SpeechRecognitionError.temporarilyUnavailable) { try await outage.transcribe(audio: audio) }

        let silence = FallbackSpeechRecognitionService(
            primary: StubSpeechRecognizer(result: .failure(.temporarilyUnavailable)),
            fallback: StubSpeechRecognizer(result: .failure(.speechNotDetected))
        )
        await #expect(throws: SpeechRecognitionError.speechNotDetected) { try await silence.transcribe(audio: audio) }
    }
}

private final class StubLiveTranscription: LiveSpeechTranscribing {
    let result: Result<String, SpeechRecognitionError>

    init(result: Result<String, SpeechRecognitionError>) {
        self.result = result
    }

    func append(_ pcm: Data) {}
    func cancel() {}

    func finish() async throws -> SpeechTranscription {
        try ElevenLabsRealtimeTranscription.transcription(from: result.get())
    }
}

@Suite("Realtime speech transcription")
struct RealtimeSpeechTranscriptionTests {
    private let audio = Data(repeating: 0, count: 1024)

    @Test("A streamed transcript is used without uploading the take")
    func streamedTranscriptWins() async throws {
        let service = StubSpeechRecognizer(result: .failure(.temporarilyUnavailable))
        let live = StubLiveTranscription(result: .success("xin chào"))
        #expect(try await service.transcribe(audio: audio, live: live).transcript == "xin chào")
    }

    @Test("A failed or silent stream falls back to the upload", arguments: [
        SpeechRecognitionError.temporarilyUnavailable,
        .speechNotDetected,
        .responseInvalid
    ])
    func streamFailureUploads(error: SpeechRecognitionError) async throws {
        let service = StubSpeechRecognizer(result: .success("cảm ơn"))
        let live = StubLiveTranscription(result: .failure(error))
        #expect(try await service.transcribe(audio: audio, live: live).transcript == "cảm ơn")
    }

    @Test("Access errors from the stream are not retried as an upload", arguments: [
        SpeechRecognitionError.premiumRequired,
        .rateLimited,
        .authenticationRequired
    ])
    func accessErrorsSurface(error: SpeechRecognitionError) async {
        let service = StubSpeechRecognizer(result: .success("cảm ơn"))
        let live = StubLiveTranscription(result: .failure(error))
        await #expect(throws: error) {
            try await service.transcribe(audio: audio, live: live)
        }
    }

    @Test("Streamed text is normalized like the upload path")
    func normalizesTranscript() throws {
        let decomposed = "  xin  cha\u{0300}o\n bạn "
        let transcription = try ElevenLabsRealtimeTranscription.transcription(from: decomposed)
        #expect(transcription.transcript == "xin chào bạn")
        #expect(transcription.transcript.unicodeScalars.count == "xin chào bạn".unicodeScalars.count)
        #expect(throws: SpeechRecognitionError.speechNotDetected) {
            try ElevenLabsRealtimeTranscription.transcription(from: "  ")
        }
    }

    @Test("Only an ElevenLabs TLS session at the recorder's rate is accepted")
    func validatesGrant() {
        func grant(_ url: String, rate: Int = 16_000) -> RealtimeSpeechGrant {
            RealtimeSpeechGrant(version: 1, url: URL(string: url)!, sampleRate: rate)
        }
        #expect(grant("wss://api.elevenlabs.io/v1/speech-to-text/realtime?token=x").isValid)
        #expect(!grant("ws://api.elevenlabs.io/v1/speech-to-text/realtime").isValid)
        #expect(!grant("wss://elevenlabs.io.example.com/realtime").isValid)
        #expect(!grant("wss://api.elevenlabs.io/v1/speech-to-text/realtime", rate: 48_000).isValid)
    }
}
