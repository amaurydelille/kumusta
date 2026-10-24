import AVFoundation
import Foundation
import OSLog

extension Notification.Name {
    static let kumustaAuthenticationRequired = Notification.Name(
        "com.kumusta.app.authentication-required"
    )
}

enum PlaybackSpeed: String, Codable, CaseIterable, Sendable {
    case slow
    case natural
    case fast

    /// Alternate playback speeds reuse the natural TTS artifact and are
    /// applied locally by the audio player. This keeps one provider-generated
    /// clip per phrase.
    var sourceSpeed: PlaybackSpeed {
        .natural
    }

    /// Preserve the provider's natural delivery and change only playback rate.
    var playbackRate: Float {
        switch self {
        case .slow: 0.7
        case .natural: 1.0
        case .fast: 1.2
        }
    }

    var title: String {
        switch self {
        case .slow: L("Slower")
        case .natural: L("Natural")
        case .fast: L("Faster")
        }
    }

    var systemImage: String {
        switch self {
        case .slow: "tortoise.fill"
        case .natural: "waveform"
        case .fast: "hare.fill"
        }
    }
}

/// One source of truth for the persisted listening preferences shared by the
/// profile and every learning surface.
struct AudioPreferences: Codable, Equatable, Sendable {
    static let defaultSpeedKey = "kumusta.audio.default-speed"
    static let autoplayKey = "kumusta.audio.autoplay"

    static let fallbackSpeed = PlaybackSpeed.natural
    static let fallbackAutoplay = true

    let defaultSpeed: PlaybackSpeed
    let autoplay: Bool

    init(defaultSpeedRawValue: String, autoplay: Bool) {
        defaultSpeed = Self.speed(from: defaultSpeedRawValue)
        self.autoplay = autoplay
    }

    init(store: UserDefaults = .standard) {
        self.init(
            defaultSpeedRawValue: store.string(forKey: Self.defaultSpeedKey)
                ?? Self.fallbackSpeed.rawValue,
            autoplay: store.object(forKey: Self.autoplayKey) == nil
                ? Self.fallbackAutoplay
                : store.bool(forKey: Self.autoplayKey)
        )
    }

    static func speed(from rawValue: String) -> PlaybackSpeed {
        PlaybackSpeed(rawValue: rawValue) ?? fallbackSpeed
    }

    static func speeds(startingWith preferredSpeed: PlaybackSpeed) -> [PlaybackSpeed] {
        [preferredSpeed] + PlaybackSpeed.allCases.filter { $0 != preferredSpeed }
    }

    static func adjustedSpeed(
        from speed: PlaybackSpeed,
        feedback: AudioPaceFeedback
    ) -> PlaybackSpeed {
        switch (speed, feedback) {
        case (_, .justRight): speed
        case (.slow, .tooSlow): .natural
        case (.natural, .tooSlow), (.fast, .tooSlow): .fast
        case (.fast, .tooFast): .natural
        case (.natural, .tooFast), (.slow, .tooFast): .slow
        }
    }
}

enum AudioPlaybackPurpose: String, Codable, Sendable {
    case lesson
    case vocabulary
    /// An explicit side-by-side accent sample. Unlike normal lesson audio,
    /// this must honor the accent supplied by the caller even when it differs
    /// from the learner's saved preference.
    case accentComparison
}

enum CachedAudioError: LocalizedError, Sendable {
    case notPrewarmed

    var errorDescription: String? {
        switch self {
        case .notPrewarmed:
            L("This card's audio is still being prepared. Please try again shortly.")
        }
    }
}

protocol AudioService: Sendable {
    /// Plays the phrase and returns only after audible playback finishes
    /// (or is stopped), so callers can drive UI state from real audio.
    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws

    /// Plays only an audio artifact already present in the local cache. The
    /// flashcard session uses this to prevent provider generation on a card.
    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws

    func stop() async
    func reset() async

    /// Warms the reusable lesson phrases without starting playback. This is
    /// deliberately best-effort: a lesson must remain usable when the voice
    /// provider or network is unavailable.
    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed
    ) async

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async
}

extension AudioService {
    func play(text: String, accent: VietnameseAccent, speed: PlaybackSpeed) async throws {
        try await play(text: text, accent: accent, speed: speed, purpose: .lesson)
    }

    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        _ = text
        _ = accent
        _ = speed
        _ = purpose
        throw CachedAudioError.notPrewarmed
    }

    func reset() async {}
}

extension AudioService {
    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async {
        guard purpose == .lesson || purpose == .accentComparison else { return }
        await prewarm(texts: texts, accent: accent, speed: speed)
    }

    func prewarm(lesson: Lesson, speed: PlaybackSpeed) async {
        var seen = Set<String>()
        let texts = lesson.steps.flatMap { step -> [String] in
            var candidates = [step.vietnamese]
            if let prompt = step.hearRespond?.promptVietnamese {
                candidates.append(prompt)
            }
            return candidates.compactMap { candidate in
                let text = SpokenUtterance.playbackText(from: candidate)
                guard !text.isEmpty, seen.insert(text).inserted else { return nil }
                return text
            }
        }
        await prewarm(texts: texts, accent: lesson.accent, speed: speed)
    }

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed
    ) async {
        _ = texts
        _ = accent
        _ = speed
    }
}

final class PlaybackCompletionGate: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var earlyResult: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?

    func wait() async -> Bool {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let earlyResult {
                lock.unlock()
                continuation.resume(returning: earlyResult)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func finish(_ success: Bool) {
        lock.lock()
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(returning: success)
        } else {
            earlyResult = success
            lock.unlock()
        }
    }

    /// Clears a remembered result before starting a new playback.
    func reset() {
        lock.lock()
        earlyResult = nil
        lock.unlock()
    }
}

/// Bridges `AVAudioPlayer` completion into ``PlaybackCompletionGate``.
final class DataPlaybackDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    let gate = PlaybackCompletionGate()
    private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        let gate = gate
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawType) == .began else { return }
            // Interrupted players need not receive a finish callback. Resolve
            // the waiter so the UI can leave its busy state and allow replay.
            gate.finish(false)
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        gate.finish(false)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        gate.finish(flag)
    }
}

protocol AccentSampleAudioService: Sendable {
    func playSample(for accent: VietnameseAccent) async throws -> TimeInterval
    func stop() async
}

protocol OnboardingDemoAudioService: Sendable {
    func playDemo() async throws -> TimeInterval
    func stop() async
}

enum BundledOnboardingAudioError: LocalizedError, Sendable {
    case resourceMissing(VietnameseAccent)
    case demoResourceMissing
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case let .resourceMissing(accent):
            L("The %@ sample is missing from this build.", accent.title)
        case .demoResourceMissing:
            L("The pre-paywall demo audio is missing from this build.")
        case .playbackFailed:
            L("The bundled audio could not be played.")
        }
    }
}

@MainActor
final class BundledOnboardingAudioService: AccentSampleAudioService, OnboardingDemoAudioService {
    private let resourceURLs: [VietnameseAccent: URL]
    private let demoURL: URL?
    private var delegate = DataPlaybackDelegate()
    private var player: AVAudioPlayer?
    private var glowToken: UUID?

    init(bundle: Bundle = .main) {
        resourceURLs = Dictionary(
            uniqueKeysWithValues: VietnameseAccent.allCases.compactMap { accent in
                let url = bundle.url(
                    forResource: accent.sampleAudioResourceName,
                    withExtension: "mp3",
                    subdirectory: "Audio/AccentSamples"
                ) ?? bundle.url(
                    forResource: accent.sampleAudioResourceName,
                    withExtension: "mp3"
                )
                return url.map { (accent, $0) }
            }
        )
        demoURL = bundle.url(
            forResource: "demo-before-paywall",
            withExtension: "mp3",
            subdirectory: "Audio/Onboarding"
        ) ?? bundle.url(
            forResource: "demo-before-paywall",
            withExtension: "mp3"
        )
    }

    func playSample(for accent: VietnameseAccent) async throws -> TimeInterval {
        guard let url = resourceURLs[accent] else {
            throw BundledOnboardingAudioError.resourceMissing(accent)
        }
        return try await play(url: url)
    }

    func playDemo() async throws -> TimeInterval {
        guard let demoURL else {
            throw BundledOnboardingAudioError.demoResourceMissing
        }
        return try await play(url: demoURL)
    }

    private func play(url: URL) async throws -> TimeInterval {
        // Resolve any previous playback before reusing the completion gate.
        // This also unblocks a caller that was waiting for an older sample.
        delegate.gate.finish(false)
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        player = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try audioSession.setActive(true)

        let delegate = DataPlaybackDelegate()
        self.delegate = delegate
        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer.delegate = delegate
        audioPlayer.prepareToPlay()
        delegate.gate.reset()

        // Retain the player before starting it. Short samples can finish
        // synchronously, and AVAudioPlayer must remain strongly referenced for
        // the whole playback lifetime.
        self.player = audioPlayer
        guard audioPlayer.play() else {
            self.player = nil
            throw BundledOnboardingAudioError.playbackFailed
        }
        glowToken = AudioReactiveBorderState.shared.follow(audioPlayer)

        let duration = audioPlayer.duration
        let completed = await withTaskCancellationHandler {
            await delegate.gate.wait()
        } onCancel: {
            delegate.gate.finish(false)
        }

        // Do not leave the audio session active after the sample has finished.
        // Only clear the player that belongs to this playback in case a new
        // sample was started while the completion callback was being handled.
        if self.player === audioPlayer {
            AudioReactiveBorderState.shared.end(glowToken)
            glowToken = nil
            audioPlayer.stop()
            self.player = nil
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
        try Task.checkCancellation()
        guard completed else { throw CancellationError() }
        return duration
    }

    func stop() async {
        delegate.gate.finish(false)
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        player = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

actor PreviewOnboardingAudioService: AccentSampleAudioService, OnboardingDemoAudioService {
    func playSample(for accent: VietnameseAccent) async throws -> TimeInterval {
        0.9
    }

    func playDemo() async throws -> TimeInterval {
        0.9
    }

    func stop() async {}
}

actor PreviewAudioService: AudioService {
    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        try await Task.sleep(for: .milliseconds(900))
    }

    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        try await play(text: text, accent: accent, speed: speed, purpose: purpose)
    }

    func stop() async {}
}

/// Offline and pre-entitlement fallback. Production ElevenLabs traffic is
/// handled by `AuthenticatedElevenLabsAudioService`; this type never sends a
/// publishable key as though it were a user bearer token.
actor SystemVietnameseAudioService: AudioService {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechPlaybackDelegate()
    private var isConfigured = false
    private var glowToken: UUID?

    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        if !isConfigured {
            synthesizer.delegate = delegate
            isConfigured = true
        }
        let utterance = AVSpeechUtterance(string: SpokenUtterance.playbackText(from: text))
        utterance.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        utterance.rate = switch speed {
        case .slow: 0.38
        case .natural: 0.48
        case .fast: 0.55
        }
        delegate.gate.reset()
        synthesizer.speak(utterance)
        let token = await AudioReactiveBorderState.shared.begin()
        glowToken = token
        await AudioReactiveBorderState.shared.update(token, amplitude: 0.018)
        _ = await delegate.gate.wait()
        if glowToken == token {
            await AudioReactiveBorderState.shared.end(token)
            glowToken = nil
        }
    }

    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        try await play(text: text, accent: accent, speed: speed, purpose: purpose)
    }

    func stop() async {
        delegate.gate.finish(false)
        synthesizer.stopSpeaking(at: .immediate)
        await AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
    }
}

enum BundledAudioError: LocalizedError, Sendable {
    case resourceMissing
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            L("The bundled example is missing from this build.")
        case .playbackFailed:
            L("The bundled example could not be played.")
        }
    }
}

/// Plays an authored reference recording without sending it through a TTS
/// provider or changing it with the learner's audio-speed preference.
actor BundledAudioService: AudioService {
    private let audioURL: URL?
    private var delegate = DataPlaybackDelegate()
    private var player: AVAudioPlayer?
    private var glowToken: UUID?
    private var meterTask: Task<Void, Never>?

    init(resourceName: String, bundle: Bundle = .main) {
        audioURL = bundle.url(forResource: resourceName, withExtension: "mp3")
    }

    /// Plays a clip that lives in a bundle subdirectory.
    init(url: URL?) {
        audioURL = url
    }

    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        guard let audioURL else {
            throw BundledAudioError.resourceMissing
        }

        delegate.gate.finish(false)
        player?.stop()
        meterTask?.cancel()
        meterTask = nil
        await AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        player = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio)
        try audioSession.setActive(true)

        let delegate = DataPlaybackDelegate()
        self.delegate = delegate
        let player = try AVAudioPlayer(contentsOf: audioURL)
        player.isMeteringEnabled = true
        player.enableRate = true
        player.rate = speed.playbackRate
        player.delegate = delegate
        player.prepareToPlay()
        delegate.gate.reset()
        guard player.play() else {
            throw BundledAudioError.playbackFailed
        }
        self.player = player
        let token = await AudioReactiveBorderState.shared.begin()
        glowToken = token
        meterTask = Task { await meterPlayback(token: token) }
        let completed = await withTaskCancellationHandler {
            await delegate.gate.wait()
        } onCancel: {
            delegate.gate.finish(false)
        }
        if self.player === player {
            player.stop()
            self.player = nil
        }
        if glowToken == token {
            meterTask?.cancel()
            meterTask = nil
            await AudioReactiveBorderState.shared.end(token)
            glowToken = nil
        }
        try Task.checkCancellation()
        guard completed else { throw CancellationError() }
    }

    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        try await play(text: text, accent: accent, speed: speed, purpose: purpose)
    }

    func stop() async {
        delegate.gate.finish(false)
        player?.stop()
        meterTask?.cancel()
        meterTask = nil
        await AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        player = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func meterPlayback(token: UUID) async {
        while glowToken == token, let player, player.isPlaying, !Task.isCancelled {
            player.updateMeters()
            await AudioReactiveBorderState.shared.update(
                token,
                decibels: player.averagePower(forChannel: 0)
            )
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

/// Bridges `AVSpeechSynthesizer` completion into ``PlaybackCompletionGate``.
private final class SpeechPlaybackDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let gate = PlaybackCompletionGate()

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        gate.finish(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        gate.finish(false)
    }
}

/// Generic resilience wrapper retained for non-production callers and its
/// contract coverage. Kumusta's live lesson voice deliberately does not use
/// this wrapper because substituting a different speaker is misleading.
actor ResilientAudioService: AudioService {
    private static let logger = Logger(subsystem: "com.kumusta.app", category: "AudioPlayback")
    private let primary: any AudioService
    private let fallback: any AudioService

    init(primary: any AudioService, fallback: any AudioService) {
        self.primary = primary
        self.fallback = fallback
    }

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed
    ) async {
        await prewarm(
            texts: texts,
            accent: accent,
            speed: speed,
            purpose: .lesson
        )
    }

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async {
        await primary.prewarm(
            texts: texts,
            accent: accent,
            speed: speed,
            purpose: purpose
        )
    }

    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        try await primary.playCached(
            text: text,
            accent: accent,
            speed: speed,
            purpose: purpose
        )
    }

    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        do {
            try await primary.play(
                text: text,
                accent: accent,
                speed: speed,
                purpose: purpose
            )
            Self.logger.info("Playback source: ElevenLabs")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error(
                "ElevenLabs playback failed; using Apple fallback. Error: \(String(reflecting: error), privacy: .public)"
            )
            if let authError = error as? AuthSessionError,
               case .notAuthenticated = authError {
                NotificationCenter.default.post(name: .kumustaAuthenticationRequired, object: nil)
            }
            try await fallback.play(
                text: text,
                accent: accent,
                speed: speed,
                purpose: purpose
            )
            Self.logger.info("Playback source: Apple fallback")
        }
    }

    func stop() async {
        await primary.stop()
        await fallback.stop()
    }
}
