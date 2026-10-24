import AVFoundation
import Foundation
import Testing
@testable import Kumusta

@Suite("Resilient audio service", .serialized)
struct ResilientAudioServiceTests {
    @Test("Lesson prewarming keeps one clip per distinct phrase")
    func lessonPrewarmingDeduplicatesRepeatedRoundStages() async {
        let phrase = "Xin chào, mình là Linh."
        let lesson = Lesson(
            id: UUID(),
            scenario: "Meeting someone new",
            minutes: 5,
            accent: .southern,
            steps: [
                LessonStep(
                    id: UUID(),
                    kind: .coldListen,
                    prompt: "Listen",
                    vietnamese: "Linh: \(phrase)",
                    translation: "Hello, I’m Linh.",
                    chunks: []
                ),
                LessonStep(
                    id: UUID(),
                    kind: .decode,
                    prompt: "Decode",
                    vietnamese: phrase,
                    translation: "Hello, I’m Linh.",
                    chunks: []
                ),
                LessonStep(
                    id: UUID(),
                    kind: .speak,
                    prompt: "Speak",
                    vietnamese: phrase,
                    translation: "Hello, I’m Linh.",
                    chunks: []
                )
            ]
        )
        let responseID = UUID()
        let responseExercise = HearRespondExercise(
            promptVietnamese: phrase,
            promptTranslation: "Hello, I’m Linh.",
            options: [
                HearRespondOption(
                    id: responseID,
                    englishTranslation: "Hello, I’m Linh."
                ),
                HearRespondOption(
                    id: UUID(),
                    englishTranslation: "I would like to order an iced coffee."
                ),
                HearRespondOption(
                    id: UUID(),
                    englishTranslation: "Could you tell me where the restroom is?"
                ),
            ],
            correctOptionID: responseID
        )
        let exerciseLesson = Lesson(
            id: lesson.id,
            scenario: lesson.scenario,
            minutes: lesson.minutes,
            accent: lesson.accent,
            steps: lesson.steps.enumerated().map { index, step in
                guard index == 1 else { return step }
                return LessonStep(
                    id: step.id,
                    kind: .hearRespond,
                    prompt: step.prompt,
                    vietnamese: step.vietnamese,
                    translation: step.translation,
                    chunks: step.chunks,
                    wordGlosses: step.wordGlosses,
                    hearRespond: responseExercise
                )
            }
        )
        let service = PrewarmAudioServiceSpy()

        await service.prewarm(lesson: exerciseLesson, speed: .natural)

        #expect(await service.prewarmedTexts == [phrase])
    }

    @Test("Authenticated audio prewarming uses the shared TTS gateway")
    func authenticatedAudioPrewarmingForwardsToGateway() async {
        let gateway = RecordingTTSGateway()
        let service = AuthenticatedElevenLabsAudioService(gateway: gateway)

        await service.prewarm(
            texts: ["Xin chào"],
            accent: .southern,
            speed: .natural
        )

        #expect(await gateway.prefetchCallCount == 1)
        #expect(await gateway.lastPrefetchedTexts == ["Xin chào"])
    }

    @Test("Slow prewarming reuses the natural provider clip")
    func slowPrewarmingUsesNaturalSourceSpeed() async {
        let gateway = RecordingTTSGateway()
        let service = AuthenticatedElevenLabsAudioService(gateway: gateway)

        await service.prewarm(
            texts: ["Xin chào"],
            accent: .northern,
            speed: .slow
        )

        #expect(await gateway.lastPrefetchedSpeed == .natural)
    }

    @Test("Fast prewarming reuses the natural provider clip")
    func fastPrewarmingUsesNaturalSourceSpeed() async {
        let gateway = RecordingTTSGateway()
        let service = AuthenticatedElevenLabsAudioService(gateway: gateway)

        await service.prewarm(
            texts: ["Xin chào"],
            accent: .southern,
            speed: .fast
        )

        #expect(await gateway.lastPrefetchedSpeed == .natural)
    }

    @Test("Vocabulary prewarming uses the vocabulary cache namespace")
    func vocabularyPrewarmingForwardsPurpose() async {
        let gateway = RecordingTTSGateway()
        let service = AuthenticatedElevenLabsAudioService(gateway: gateway)

        await service.prewarm(
            texts: ["Xin chào"],
            accent: .southern,
            speed: .natural,
            purpose: .vocabulary
        )

        #expect(await gateway.lastPrefetchedPurpose == .vocabulary)
    }

    @Test("One failed prewarm item does not block the remaining phrases")
    func prewarmingIsolatesIndividualFailures() async {
        let gateway = BestEffortTTSGateway(failingText: "Xin lỗi")

        await gateway.prefetch(
            texts: ["Xin chào", "Xin lỗi", "Cảm ơn"],
            accent: .southern,
            speed: .natural
        )

        #expect(await gateway.requestedTexts == ["Xin chào", "Xin lỗi", "Cảm ơn"])
    }

    @Test("Stopping before a request cannot poison the next audio clip")
    func stopBeforePlaybackDoesNotPoisonNextClip() async throws {
        let service = AuthenticatedElevenLabsAudioService(
            gateway: StubTTSGateway(audio: Self.silentWAV(duration: 0.3))
        )

        await service.stop()
        let clock = ContinuousClock()
        let startedAt = clock.now
        try await service.play(text: "Xin chào", accent: .southern, speed: .natural)

        #expect(clock.now - startedAt > .milliseconds(150))
    }

    @Test("Stopping active playback promptly releases its caller")
    func stoppingActivePlaybackReleasesCaller() async throws {
        let service = AuthenticatedElevenLabsAudioService(
            gateway: StubTTSGateway(audio: Self.silentWAV(duration: 2))
        )
        let playback = Task {
            try await service.playCached(
                text: "Xin chào",
                accent: .southern,
                speed: .natural,
                purpose: .vocabulary
            )
        }

        try await Task.sleep(for: .milliseconds(150))
        let clock = ContinuousClock()
        let stoppedAt = clock.now
        await service.stop()

        await #expect(throws: CancellationError.self) {
            try await playback.value
        }
        #expect(clock.now - stoppedAt < .seconds(1))
    }

    @Test("Provider failure uses the offline fallback")
    func providerFailureUsesFallback() async throws {
        let primary = AudioServiceSpy(behavior: .failure)
        let fallback = AudioServiceSpy(behavior: .success)
        let service = ResilientAudioService(primary: primary, fallback: fallback)

        try await service.play(text: "Xin chào", accent: .southern, speed: .natural)

        #expect(await primary.playCount == 1)
        #expect(await fallback.playCount == 1)
    }

    @Test("An intentional stop never starts fallback speech")
    func cancellationDoesNotUseFallback() async {
        let primary = AudioServiceSpy(behavior: .cancellation)
        let fallback = AudioServiceSpy(behavior: .success)
        let service = ResilientAudioService(primary: primary, fallback: fallback)

        await #expect(throws: CancellationError.self) {
            try await service.play(text: "Xin chào", accent: .northern, speed: .slow)
        }
        #expect(await primary.playCount == 1)
        #expect(await fallback.playCount == 0)
    }

    @Test("Onboarding feedback preserves the voice playback session")
    @MainActor
    func onboardingFeedbackPreservesVoiceSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
        let voice = try AVAudioPlayer(data: Self.silentWAV(duration: 2))
        #expect(voice.play())
        defer { voice.stop() }

        let typingID = OnboardingTypingSound.shared.play(for: .seconds(2))
        SelectionFeedbackPlayer.shared.play()
        OnboardingTypingSound.shared.stop(typingID)
        try await Task.sleep(for: .milliseconds(600))

        #expect(session.category == .playback)
        #expect(session.mode == .spokenAudio)
        #expect(voice.isPlaying)
    }

    @Test("An interruption releases the audio completion waiter")
    func interruptionReleasesCompletionWaiter() async {
        let delegate = DataPlaybackDelegate()
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        #expect(await delegate.gate.wait() == false)
    }

    @Test("Cancelling bundled onboarding playback allows the next play")
    func bundledPlaybackCancellationAllowsReplay() async throws {
        let service = BundledAudioService(resourceName: "tuyet_southern_onboarding")
        let playback = Task {
            try await service.play(text: "Chào bạn", accent: .southern, speed: .natural)
        }
        try await Task.sleep(for: .milliseconds(150))
        playback.cancel()
        await #expect(throws: CancellationError.self) {
            try await playback.value
        }

        let clock = ContinuousClock()
        let startedAt = clock.now
        try await service.play(text: "Chào bạn", accent: .southern, speed: .natural)
        #expect(clock.now - startedAt > .milliseconds(500))
    }

    private static func silentWAV(duration: Double) -> Data {
        let sampleRate: UInt32 = 8_000
        let channelCount: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let sampleCount = UInt32(Double(sampleRate) * duration)
        let dataSize = sampleCount * UInt32(bitsPerSample / 8) * UInt32(channelCount)
        let byteRate = sampleRate * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * (bitsPerSample / 8)

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.append(contentsOf: "WAVEfmt ".utf8)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channelCount)
        data.appendLittleEndian(sampleRate)
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.append(contentsOf: "data".utf8)
        data.appendLittleEndian(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}

private actor PrewarmAudioServiceSpy: AudioService {
    private(set) var prewarmedTexts: [String] = []

    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {}

    func stop() async {}

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed
    ) async {
        prewarmedTexts.append(contentsOf: texts)
    }
}

private actor RecordingTTSGateway: VietnameseTTSProviding {
    private(set) var prefetchCallCount = 0
    private(set) var lastPrefetchedTexts: [String] = []
    private(set) var lastPrefetchedPurpose: AudioPlaybackPurpose?
    private(set) var lastPrefetchedSpeed: PlaybackSpeed?

    func audio(
        for text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data {
        Data()
    }

    func prefetch(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed
    ) async {
        prefetchCallCount += 1
        lastPrefetchedTexts = texts
        lastPrefetchedSpeed = speed
    }

    func prefetch(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async {
        prefetchCallCount += 1
        lastPrefetchedTexts = texts
        lastPrefetchedPurpose = purpose
        lastPrefetchedSpeed = speed
    }
}

private actor BestEffortTTSGateway: VietnameseTTSProviding {
    private let failingText: String
    private(set) var requestedTexts: [String] = []

    init(failingText: String) {
        self.failingText = failingText
    }

    func audio(
        for text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data {
        requestedTexts.append(text)
        if text == failingText {
            throw TTSGatewayTestError.failed
        }
        return Data([0])
    }
}

private struct StubTTSGateway: VietnameseTTSProviding {
    let audio: Data

    func audio(
        for text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data {
        audio
    }

    func cachedAudio(
        for text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data? {
        audio
    }
}

private actor AudioServiceSpy: AudioService {
    enum Behavior: Sendable {
        case success
        case failure
        case cancellation
    }

    private(set) var playCount = 0
    private let behavior: Behavior

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        playCount += 1
        switch behavior {
        case .success:
            return
        case .failure:
            throw AudioServiceSpyError.providerUnavailable
        case .cancellation:
            throw CancellationError()
        }
    }

    func stop() async {}
}

private enum AudioServiceSpyError: Error {
    case providerUnavailable
}

private enum TTSGatewayTestError: Error {
    case failed
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
