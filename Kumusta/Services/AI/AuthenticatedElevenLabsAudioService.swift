@preconcurrency import AVFoundation
import Foundation

/// Production AudioService adapter. Unlike the legacy URLRequest adapter, this
/// path uses the refreshed Supabase user JWT through FunctionsClient and cannot
/// mistake a publishable API key for an authenticated bearer token.
actor AuthenticatedElevenLabsAudioService: AudioService {
    private let gateway: any VietnameseTTSProviding
    private var player: AVAudioPlayer?
    private var glowToken: UUID?
    private var playbackRequestID: UUID?

    init(gateway: any VietnameseTTSProviding) {
        self.gateway = gateway
    }

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed
    ) async {
        await gateway.prefetch(texts: texts, accent: accent, speed: speed.sourceSpeed)
    }

    func prewarm(
        texts: [String],
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async {
        await gateway.prefetch(
            texts: texts,
            accent: accent,
            speed: speed.sourceSpeed,
            purpose: purpose
        )
    }

    func play(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        cancelCurrentPlayback()
        let requestID = UUID()
        playbackRequestID = requestID

        do {
            let audio = try await gateway.audio(
                for: text,
                accent: accent,
                speed: speed.sourceSpeed,
                purpose: purpose
            )
            try Task.checkCancellation()
            guard playbackRequestID == requestID else {
                throw CancellationError()
            }
            try await playAudioData(audio, requestID: requestID, speed: speed)
        } catch {
            let requestWasStopped = playbackRequestID != requestID
            if playbackRequestID == requestID {
                cancelCurrentPlayback()
            }
            if requestWasStopped || error is CancellationError {
                throw CancellationError()
            }
            throw error
        }
    }

    func playCached(
        text: String,
        accent: VietnameseAccent,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws {
        cancelCurrentPlayback()
        let requestID = UUID()
        playbackRequestID = requestID

        do {
            guard let audio = try await gateway.cachedAudio(
                for: text,
                accent: accent,
                speed: speed.sourceSpeed,
                purpose: purpose
            ) else {
                throw CachedAudioError.notPrewarmed
            }
            try Task.checkCancellation()
            try await playAudioData(audio, requestID: requestID, speed: speed)
        } catch {
            let requestWasStopped = playbackRequestID != requestID
            if playbackRequestID == requestID {
                cancelCurrentPlayback()
            }
            if requestWasStopped || error is CancellationError {
                throw CancellationError()
            }
            throw error
        }
    }

    func stop() async {
        cancelCurrentPlayback()
    }

    func reset() async {
        cancelCurrentPlayback()
        await gateway.reset()
    }

    private func cancelCurrentPlayback() {
        playbackRequestID = nil
        player?.stop()
        player = nil
        let token = glowToken
        glowToken = nil
        Task { await AudioReactiveBorderState.shared.end(token) }
    }

    private func playAudioData(
        _ audio: Data,
        requestID: UUID,
        speed: PlaybackSpeed
    ) async throws {
        guard playbackRequestID == requestID else {
            throw CancellationError()
        }

        let audioSession = AVAudioSession.sharedInstance()
        // A speaking round leaves the shared session in record mode. Fully
        // release that route before selecting playback so lesson audio cannot
        // remain attached to the input/receiver route on the next round.
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        try audioSession.setCategory(.playback, mode: .spokenAudio)
        try audioSession.setActive(true)

        let player = try AVAudioPlayer(data: audio)
        player.isMeteringEnabled = true
        player.enableRate = true
        player.rate = speed.playbackRate
        player.volume = 1
        guard player.prepareToPlay() else {
            throw TTSGatewayError.invalidAudio
        }
        self.player = player
        guard player.play() else {
            throw TTSGatewayError.invalidAudio
        }
        let token = await AudioReactiveBorderState.shared.begin()
        glowToken = token

        // AVAudioPlayer does not guarantee a completion delegate callback when
        // playback is interrupted. Polling `isPlaying` also covers that path,
        // so a finished/interrupted clip cannot strand a caller indefinitely.
        let expectedDuration = player.duration / Double(max(player.rate, 0.1))
        let deadline = Date.now.addingTimeInterval(
            min(60, max(3, expectedDuration + 2))
        )
        while player.isPlaying, Date.now < deadline {
            player.updateMeters()
            await AudioReactiveBorderState.shared.update(
                token,
                decibels: player.averagePower(forChannel: 0)
            )
            try Task.checkCancellation()
            guard playbackRequestID == requestID else {
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        guard playbackRequestID == requestID else {
            throw CancellationError()
        }
        // Defensive cutoff for malformed audio whose player never reports
        // completion even after its advertised duration has elapsed.
        cancelCurrentPlayback()
    }
}
