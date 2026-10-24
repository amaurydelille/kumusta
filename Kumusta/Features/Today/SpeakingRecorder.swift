@preconcurrency import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpeakingRecorder: NSObject, @preconcurrency AVAudioPlayerDelegate {
    private static let recordingPrefix = "kumusta-speaking-rep-"
    static let maximumDuration: TimeInterval = 20
    static let minimumUsefulDuration: TimeInterval = 0.45

    enum PermissionState: Equatable {
        case unknown
        case granted
        case denied
    }

    private(set) var permissionState: PermissionState = .unknown
    private(set) var isRecording = false
    private(set) var isFinishingRecording = false
    private(set) var hasRecording = false
    private(set) var meterLevel: Double = 0
    private(set) var isPlayingBack = false
    private(set) var recordedDuration: TimeInterval = 0
    var errorMessage: String?

    private var engine: AVAudioEngine?
    private var capture: CaptureSink?
    private var liveTranscription: (any LiveSpeechTranscribing)?
    private var captureObservers: [NSObjectProtocol] = []
    private var player: AVAudioPlayer?
    private var glowToken: UUID?
    private var microphoneGlowToken: UUID?
    private var meterTask: Task<Void, Never>?
    private var recordingURL: URL?
    private var capturedRecordingData: Data?

    override init() {
        super.init()
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionState = .granted
        case .denied:
            permissionState = .denied
        case .undetermined:
            permissionState = .unknown
        @unknown default:
            permissionState = .unknown
        }
    }

    /// Pass a speech service to stream the take while it is recorded, so its
    /// transcript is ready when the learner stops.
    func toggleRecording(
        streamingTo speechService: (any TagalogSpeechRecognizing)? = nil,
        onboarding: Bool = false
    ) {
        if isRecording {
            stopRecording()
            return
        }

        guard !isFinishingRecording else { return }

        switch permissionState {
        case .granted:
            startRecording(live: speechService?.makeLiveTranscription(onboarding: onboarding))
        case .denied:
            errorMessage = L("Microphone access is off. You can enable it in Settings.")
        case .unknown:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.permissionState = granted ? .granted : .denied
                    if granted {
                        self.startRecording(
                            live: speechService?.makeLiveTranscription(onboarding: onboarding)
                        )
                    } else {
                        self.errorMessage = L("Microphone access is off. You can enable it in Settings.")
                    }
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording, !isFinishingRecording else { return }
        isFinishingRecording = true
        finishRecording(successfully: true)
    }

    /// Hands the streamed transcription of the finished take to the caller,
    /// so discarding the local take afterwards does not cancel it.
    func takeLiveTranscription() -> (any LiveSpeechTranscribing)? {
        defer { liveTranscription = nil }
        return liveTranscription
    }

    func playRecording() {
        guard hasRecording, !isRecording, let capturedRecordingData else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            player = try AVAudioPlayer(data: capturedRecordingData)
            player?.delegate = self
            player?.volume = 1
            guard player?.prepareToPlay() == true else {
                throw RecorderError.couldNotPrepare
            }
            isPlayingBack = player?.play() == true
            if isPlayingBack, let player {
                glowToken = AudioReactiveBorderState.shared.follow(player)
            }
        } catch {
            errorMessage = L("Your recording couldn’t be played back. Try one more time.")
            isPlayingBack = false
        }
    }

    func stopPlayback() {
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        isPlayingBack = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Ends playback/recording and securely discards the local practice take.
    /// Call this when leaving any screen that owns a recorder.
    func cleanup() {
        if isRecording {
            stopCapture()
        }
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        meterTask?.cancel()
        meterTask = nil
        AudioReactiveBorderState.shared.end(microphoneGlowToken)
        microphoneGlowToken = nil
        player = nil
        isRecording = false
        isFinishingRecording = false
        isPlayingBack = false
        meterLevel = 0
        discardRecording()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func recordingData() throws -> Data {
        guard
            hasRecording,
            recordedDuration >= Self.minimumUsefulDuration,
            let capturedRecordingData,
            Self.isValidRecordingData(capturedRecordingData)
        else {
            throw SpeechRecognitionError.invalidAudio
        }
        return capturedRecordingData
    }

    func discardCurrentRecording() {
        discardRecording()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        isPlayingBack = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startRecording(live: (any LiveSpeechTranscribing)?) {
        errorMessage = nil
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        isPlayingBack = false
        discardRecording()
        isFinishingRecording = false
        let newRecordingURL = Self.makeRecordingURL()
        recordingURL = newRecordingURL
        recordedDuration = 0
        liveTranscription = live

        do {
            let session = AVAudioSession.sharedInstance()
            // Lesson audio uses a playback session. Explicitly deactivate it
            // before switching to a session that owns the microphone. This is
            // especially important when the learner taps record immediately
            // after hearing the phrase or has a Bluetooth route connected.
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
            guard session.isInputAvailable, session.inputNumberOfChannels > 0 else {
                throw RecorderError.inputUnavailable
            }

            // Capture at the route's own rate (48 kHz, or a Bluetooth rate)
            // and convert once to the 16 kHz mono speech rate used by both the
            // saved take and the realtime stream.
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                throw RecorderError.inputUnavailable
            }
            let capture = try CaptureSink(inputFormat: inputFormat, fileURL: newRecordingURL, live: live)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: newRecordingURL.path
            )
            input.installTap(
                onBus: 0,
                bufferSize: 2_048,
                format: inputFormat,
                block: capture.tapBlock
            )
            engine.prepare()
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                capture.close()
                throw RecorderError.couldNotStart
            }
            self.engine = engine
            self.capture = capture
            observeCaptureInterruptions(of: engine)
            isRecording = true
            hasRecording = false
            microphoneGlowToken = AudioReactiveBorderState.shared.begin(microphone: true)
            beginMetering()
        } catch {
            discardRecording()
            switch error {
            case RecorderError.inputUnavailable:
                errorMessage = L("No microphone input is available right now. Check your headset connection and try again.")
            default:
                errorMessage = L("The microphone couldn’t start. Check your audio route and try again.")
            }
            isRecording = false
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    /// A route change or an interruption (a call, Siri) stops the engine.
    /// Keep what was captured so far rather than losing the take.
    private func observeCaptureInterruptions(of engine: AVAudioEngine) {
        let center = NotificationCenter.default
        let stop: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.stopRecording() }
        }
        captureObservers = [
            center.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: .main,
                using: stop
            ),
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main,
                using: stop
            )
        ]
    }

    /// Stops the engine and finalizes the take's file. Safe to call twice.
    private func stopCapture() {
        captureObservers.forEach(NotificationCenter.default.removeObserver)
        captureObservers = []
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        if let capture {
            capture.close()
            recordedDuration = max(recordedDuration, capture.duration)
        }
        capture = nil
    }

    private func finishRecording(successfully: Bool) {
        stopCapture()
        meterTask?.cancel()
        meterTask = nil
        AudioReactiveBorderState.shared.end(microphoneGlowToken)
        microphoneGlowToken = nil
        meterLevel = 0
        isRecording = false
        isFinishingRecording = false
        let durationIsUseful = recordedDuration >= Self.minimumUsefulDuration
        hasRecording = successfully && durationIsUseful && captureRecordingData()
        if !hasRecording {
            discardRecording()
            if successfully && durationIsUseful {
                errorMessage = L("That take couldn’t be saved. Please record it once more.")
            } else if successfully {
                errorMessage = L("That was a little too quick. Try the full phrase once more.")
            } else {
                errorMessage = L("The recording stopped unexpectedly. Please try again.")
            }
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, isRecording, let capture else { return }
                if capture.duration >= Self.maximumDuration {
                    stopRecording()
                    return
                }
                let decibels = capture.decibels
                meterLevel = min(1, max(0.08, Double((decibels + 60) / 60)))
                if let microphoneGlowToken {
                    AudioReactiveBorderState.shared.update(microphoneGlowToken, decibels: decibels)
                }
                try? await Task.sleep(for: .milliseconds(70))
            }
        }
    }

    private func discardRecording() {
        liveTranscription?.cancel()
        liveTranscription = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        capturedRecordingData = nil
        hasRecording = false
        recordedDuration = 0
    }

    /// Finalizes a take into memory and removes its temporary file immediately.
    /// Once the UI says a take is ready, neither another recorder nor iOS temp
    /// directory maintenance can invalidate it underneath playback or upload.
    private func captureRecordingData() -> Bool {
        if let capturedRecordingData {
            return Self.isValidRecordingData(capturedRecordingData)
        }

        guard let recordingURL else { return false }
        defer {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }

        guard let data = Self.snapshotRecordingData(from: recordingURL) else { return false }
        capturedRecordingData = data
        return true
    }

    /// Copies a completed temporary take before its file can be removed. The
    /// speech service and playback path must consume this detached value, not
    /// retain a URL in the temporary directory.
    static func snapshotRecordingData(from url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url), isValidRecordingData(data) else {
            return nil
        }
        return data
    }

    private static func isValidRecordingData(_ data: Data) -> Bool {
        (512 ... SupabaseSpeechRecognitionService.maximumUploadBytes)
            .contains(data.count)
    }

    static func makeRecordingURL(
        in directory: URL = FileManager.default.temporaryDirectory
    ) -> URL {
        directory.appending(
            path: "\(recordingPrefix)\(UUID().uuidString).m4a",
            directoryHint: .notDirectory
        )
    }

    static func scrubAbandonedRecordings(
        in directory: URL = FileManager.default.temporaryDirectory
    ) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for file in files where
            file.lastPathComponent.hasPrefix(recordingPrefix)
                && file.pathExtension.lowercased() == "m4a"
        {
            try? FileManager.default.removeItem(at: file)
        }
    }

}

/// Everything the audio capture thread touches. It converts each input buffer
/// to 16 kHz mono once, then writes it to the take's M4A and forwards it as
/// PCM16 to the realtime transcription.
private final class CaptureSink: @unchecked Sendable {
    private static let speechFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(RealtimeSpeechGrant.sampleRate),
        channels: 1,
        interleaved: false
    )!

    private let lock = NSLock()
    private let converter: AVAudioConverter
    private var file: AVAudioFile?
    private var live: (any LiveSpeechTranscribing)?
    private var frames: AVAudioFramePosition = 0
    private var level: Float = -60

    init(inputFormat: AVAudioFormat, fileURL: URL, live: (any LiveSpeechTranscribing)?) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: Self.speechFormat) else {
            throw RecorderError.couldNotPrepare
        }
        self.converter = converter
        file = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: Self.speechFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        self.live = live
    }

    /// Built here, outside the main actor: a tap closure written inside the
    /// @MainActor recorder inherits its isolation, and Swift 6 then traps when
    /// the audio thread calls it.
    var tapBlock: AVAudioNodeTapBlock {
        { [self] buffer, _ in consume(buffer) }
    }

    var duration: TimeInterval {
        lock.withLock { Double(frames) / Self.speechFormat.sampleRate }
    }

    var decibels: Float {
        lock.withLock { level }
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file else { return }

        let ratio = Self.speechFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: Self.speechFormat, frameCapacity: capacity) else {
            return
        }
        // The input block runs synchronously inside convert(), on this thread.
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let input = buffer
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, converted.frameLength > 0, let samples = converted.floatChannelData?[0] else {
            return
        }
        do {
            try file.write(from: converted)
        } catch {
            return
        }

        let count = Int(converted.frameLength)
        frames += AVAudioFramePosition(count)
        var sumOfSquares: Float = 0
        var pcm = Data(count: count * 2)
        pcm.withUnsafeMutableBytes { raw in
            let output = raw.bindMemory(to: Int16.self)
            for index in 0..<count {
                let sample = max(-1, min(1, samples[index]))
                sumOfSquares += sample * sample
                output[index] = Int16(sample * Float(Int16.max)).littleEndian
            }
        }
        level = max(-60, 20 * log10(max(sqrt(sumOfSquares / Float(count)), 0.000_001)))
        live?.append(pcm)
    }

    /// Releasing the file writes its container; the take is readable after this.
    func close() {
        lock.withLock {
            file = nil
            live = nil
        }
    }
}

private enum RecorderError: Error {
    case inputUnavailable
    case couldNotPrepare
    case couldNotStart
}
