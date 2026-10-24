import Foundation
import Testing
@testable import Kumusta

@Suite("Spoken utterance boundary")
struct SpokenUtteranceTests {
    @Test("English role label is not spoken")
    func stripsEnglishRole() {
        #expect(
            SpokenUtterance.playbackText(
                from: "Barista: Magandang umaga po! Ano po ang order ninyo?"
            ) == "Magandang umaga po! Ano po ang order ninyo?"
        )
    }

    @Test("Tagalog role label is not spoken")
    func stripsTagalogRole() {
        #expect(
            SpokenUtterance.playbackText(
                from: "Tindera: Magkano po?"
            ) == "Magkano po?"
        )
    }

    @Test("A spoken Tagalog vocative remains intact")
    func preservesVocative() {
        let phrase = "Kuya, isang kape nga po, walang asukal."
        #expect(SpokenUtterance.playbackText(from: phrase) == phrase)
        #expect(!SpokenUtterance.hasLeadingSpeakerLabel(phrase))
    }
}

@Suite("Onboarding first conversation")
struct OnboardingFirstConversationTests {
    @Test("Speech matching ignores case, punctuation, variants, and the learner's name")
    func lenientMatching() {
        #expect(OnboardingSpeechMatcher.matches(transcript: "kamusta po", target: "Kumusta po!", ignoringName: nil))
        #expect(OnboardingSpeechMatcher.matches(transcript: "Ako si Amory", target: "Ako si Amaury.", ignoringName: "Amaury"))
        #expect(OnboardingSpeechMatcher.matches(transcript: "si", target: "Ako si Amaury.", ignoringName: "Amaury"))
        #expect(!OnboardingSpeechMatcher.matches(transcript: "paalam", target: "Kumusta po!", ignoringName: nil))
        #expect(!OnboardingSpeechMatcher.matches(transcript: "Amaury", target: "Ako si Amaury.", ignoringName: "Amaury"))
    }

    @Test("Only plain first names are spoken")
    func spokenFirstName() {
        #expect(OnboardingConversationAudio.spokenFirstName(from: "  amaury delille ") == "Amaury")
        #expect(OnboardingConversationAudio.spokenFirstName(from: "Jean-Luc") == "Jean-Luc")
        #expect(OnboardingConversationAudio.spokenFirstName(from: "Niño") == "Niño")
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
        let review = PronunciationReview(target: "Kumusta ka, Ate?", transcript: "kumusta ka ate")
        #expect(review.isMatch)
        #expect(review.tips.isEmpty)
    }

    @Test("Stress marks a transcriber adds never fail a take")
    func stressMarksFold() {
        #expect(PronunciationReview(target: "Salamat po", transcript: "Salámat pô").isMatch)
    }

    @Test("Everyday spelling variants are the same word", arguments: [
        ("Puwede po ba?", "pwede po ba"),
        ("Ako rin", "ako din"),
        ("Kumusta ka?", "kamusta ka"),
        ("Salamat po", "salamat ho"),
        ("Anong pangalan mo?", "ano'ng pangalan mo"),
        ("Gusto ko ng halo-halo", "gusto ko ng halo halo"),
        ("Saka na lang", "tsaka na lang"),
    ])
    func spellingVariants(target: String, transcript: String) {
        #expect(PronunciationReview(target: target, transcript: transcript).isMatch)
    }

    @Test("A vowel slip is an almost, not a wrong word")
    func vowelSlip() {
        let review = PronunciationReview(target: "lalaki", transcript: "lalake")
        #expect(marks(review.target) == [.spelling])
        #expect(review.tips.first?.mark == .spelling)
    }

    @Test("Skipped words are missing and grouped in one tip")
    func missingWords() {
        let review = PronunciationReview(target: "Gusto ko ng kape", transcript: "gusto kape")
        #expect(marks(review.target) == [.correct, .missing, .missing, .correct])
        #expect(review.tips == [.init(mark: .missing, message: "Don’t skip **ko ng**.")])
        #expect(!review.isMatch)
    }

    @Test("A different word is wrong, an added word is extra")
    func wrongAndExtra() {
        let review = PronunciationReview(target: "Kumain ka na ba", transcript: "kumain kayo na ba eh")
        #expect(marks(review.target) == [.correct, .wrong, .correct, .correct])
        #expect(marks(review.heard) == [.correct, .wrong, .correct, .correct, .extra])
    }

    @Test("Extra filler words do not fail an otherwise clean take")
    func extraFillerStillMatches() {
        #expect(PronunciationReview(target: "Salamat po", transcript: "ay salamat po").isMatch)
    }

    @Test("Digits match native and Spanish-derived number words")
    func numbersMatch() {
        #expect(PronunciationReview(target: "Singkwenta pesos po", transcript: "50 pesos po").isMatch)
        #expect(PronunciationReview(target: "Limampu", transcript: "50").isMatch)
        #expect(PronunciationReview(target: "Dalawa po", transcript: "dos po").isMatch)
        #expect(!PronunciationReview(target: "Dalawa po", transcript: "tatlo po").isMatch)
    }

    @Test("A dropped enclitic at the end is forgiven")
    func trailingParticles() {
        #expect(PronunciationReview(target: "Salamat po.", transcript: "salamat").isMatch)
        #expect(PronunciationReview(target: "Kain na!", transcript: "kain").isMatch)
        // Only at the end: a skipped word mid-phrase still fails.
        #expect(!PronunciationReview(target: "Magandang umaga po", transcript: "umaga po").isMatch)
    }

    @Test("One slip passes in a phrase of three or more words, two do not")
    func singleSlipAllowance() {
        let one = PronunciationReview(target: "Ang lalaki ay mabait", transcript: "ang lalake ay mabait")
        #expect(one.isMatch)
        #expect(marks(one.target) == [.correct, .spelling, .correct, .correct])
        #expect(!PronunciationReview(target: "lalaki", transcript: "lalake").isMatch)
        #expect(!PronunciationReview(target: "Gusto ko ng kape", transcript: "gusto ko ng tubig").isMatch)
    }

    @Test("Silence marks every target word missing")
    func emptyTranscript() {
        let review = PronunciationReview(target: "Magandang umaga", transcript: "")
        #expect(review.heardNothing)
        #expect(marks(review.target) == [.missing, .missing])
        #expect(!review.isMatch)
    }
}

private struct StubSpeechRecognizer: TagalogSpeechRecognizing {
    let result: Result<String, SpeechRecognitionError>

    func transcribe(audio: Data) async throws -> SpeechTranscription {
        let transcript = try result.get()
        return SpeechTranscription(version: 1, transcript: transcript, languageCode: "fil", languageProbability: nil, words: [])
    }
}

@Suite("Speech recognition fallback")
struct SpeechRecognitionFallbackTests {
    private let audio = Data(repeating: 0, count: 1024)

    @Test("A provider outage falls back to the on-device recognizer")
    func outageUsesFallback() async throws {
        let service = FallbackSpeechRecognitionService(
            primary: StubSpeechRecognizer(result: .failure(.temporarilyUnavailable)),
            fallback: StubSpeechRecognizer(result: .success("kumusta"))
        )
        #expect(try await service.transcribe(audio: audio).transcript == "kumusta")
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
            fallback: StubSpeechRecognizer(result: .success("kumusta"))
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
        try StreamingSpeechTranscription.transcription(from: result.get())
    }
}

@Suite("Realtime speech transcription")
struct RealtimeSpeechTranscriptionTests {
    private let audio = Data(repeating: 0, count: 1024)

    @Test("A streamed transcript is used without uploading the take")
    func streamedTranscriptWins() async throws {
        let service = StubSpeechRecognizer(result: .failure(.temporarilyUnavailable))
        let live = StubLiveTranscription(result: .success("kumusta"))
        #expect(try await service.transcribe(audio: audio, live: live).transcript == "kumusta")
    }

    @Test("A failed or silent stream falls back to the upload", arguments: [
        SpeechRecognitionError.temporarilyUnavailable,
        .speechNotDetected,
        .responseInvalid
    ])
    func streamFailureUploads(error: SpeechRecognitionError) async throws {
        let service = StubSpeechRecognizer(result: .success("salamat"))
        let live = StubLiveTranscription(result: .failure(error))
        #expect(try await service.transcribe(audio: audio, live: live).transcript == "salamat")
    }

    @Test("Access errors from the stream are not retried as an upload", arguments: [
        SpeechRecognitionError.premiumRequired,
        .rateLimited,
        .authenticationRequired
    ])
    func accessErrorsSurface(error: SpeechRecognitionError) async {
        let service = StubSpeechRecognizer(result: .success("salamat"))
        let live = StubLiveTranscription(result: .failure(error))
        await #expect(throws: error) {
            try await service.transcribe(audio: audio, live: live)
        }
    }

    @Test("Streamed text is normalized like the upload path")
    func normalizesTranscript() throws {
        let decomposed = "  sala\u{0301}mat  po\n Ate "
        let transcription = try StreamingSpeechTranscription.transcription(from: decomposed)
        #expect(transcription.transcript == "salámat po Ate")
        #expect(transcription.transcript.unicodeScalars.count == "salámat po Ate".unicodeScalars.count)
        #expect(throws: SpeechRecognitionError.speechNotDetected) {
            try StreamingSpeechTranscription.transcription(from: "  ")
        }
    }

    @Test("Only a Soniox TLS session at the recorder's rate is accepted")
    func validatesGrant() {
        func grant(
            _ url: String,
            provider: String = "soniox",
            token: String = "temp:key",
            rate: Int = 16_000
        ) -> RealtimeSpeechGrant {
            RealtimeSpeechGrant(
                version: 1, provider: provider, url: URL(string: url)!,
                token: token, config: "{}", sampleRate: rate
            )
        }
        #expect(grant("wss://stt-rt.soniox.com/transcribe-websocket").isValid)
        #expect(!grant("ws://stt-rt.soniox.com/transcribe-websocket").isValid)
        #expect(!grant("wss://stt-rt.soniox.com.example.com/x").isValid)
        #expect(!grant("wss://stt-rt.soniox.com/transcribe-websocket", provider: "elevenlabs").isValid)
        #expect(!grant("wss://stt-rt.soniox.com/transcribe-websocket", token: "").isValid)
        #expect(!grant("wss://stt-rt.soniox.com/transcribe-websocket", rate: 48_000).isValid)
    }
}
