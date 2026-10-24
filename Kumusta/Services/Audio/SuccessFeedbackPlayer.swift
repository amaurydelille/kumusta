import AVFoundation
import Foundation

/// Feedback shares the app's session with speech and recording. A short cue
/// must never change an active speech/recording category or deactivate it when
/// the cue ends: doing so stops other players without a completion callback.
@MainActor
enum FeedbackAudioSession {
    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback && session.category != .playAndRecord {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        try session.setActive(true)
    }
}

/// Learner-controlled master volume for bundled sound effects (pop, success,
/// wrong, badge, typing). Spoken audio and voices are never affected.
enum SoundEffectsVolume {
    static let storageKey = "kumusta.audio.sound-effects-volume"
    static let fallback = 1.0

    static func current(store: UserDefaults = .standard) -> Double {
        guard store.object(forKey: storageKey) != nil else { return fallback }
        return min(max(store.double(forKey: storageKey), 0), 1)
    }

    /// Scales a cue's tuned base volume by the learner's setting.
    static func scaled(_ baseVolume: Float) -> Float {
        baseVolume * Float(current())
    }
}

/// Plays the short, bundled confirmation sound used after a successful
/// learning action. It is deliberately independent from lesson/TTS playback
/// so a feedback cue cannot be lost when a provider audio task is cancelled.
@MainActor
final class SuccessFeedbackPlayer: NSObject, @preconcurrency AVAudioPlayerDelegate {
    static let shared = SuccessFeedbackPlayer()

    private var player: AVAudioPlayer?
    private var successBorderToken: UUID?

    private override init() {
        super.init()
    }

    func play(showsSuccessBorder: Bool = false) {
        AudioReactiveBorderState.shared.end(successBorderToken)
        successBorderToken = nil
        guard let url = Bundle.main.url(
            forResource: "valid",
            withExtension: "mp3",
            subdirectory: "Audio/Feedback"
        ) ?? Bundle.main.url(
            forResource: "valid",
            withExtension: "mp3"
        ) else {
            return
        }

        do {
            player?.stop()

            try FeedbackAudioSession.activate()

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = SoundEffectsVolume.scaled(0.68)
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
            if showsSuccessBorder {
                successBorderToken = AudioReactiveBorderState.shared.beginSuccess()
            }
        } catch {
            player = nil
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
    }
}

/// Plays the quiet, tactile cue used when a learner selects an onboarding
/// option. It is intentionally softer than the success and badge cues so a
/// learner can explore choices without the feedback becoming distracting.
@MainActor
final class SelectionFeedbackPlayer: NSObject, @preconcurrency AVAudioPlayerDelegate {
    static let shared = SelectionFeedbackPlayer()

    private var player: AVAudioPlayer?

    var isPlaying: Bool { player?.isPlaying == true }
    var remainingTime: TimeInterval {
        guard let player, player.isPlaying else { return 0 }
        return max(0, player.duration - player.currentTime)
    }

    private override init() {
        super.init()
    }

    func play() {
        guard let url = Bundle.main.url(
            forResource: "pop",
            withExtension: "mp3",
            subdirectory: "Audio/Feedback"
        ) ?? Bundle.main.url(
            forResource: "pop",
            withExtension: "mp3"
        ) else {
            return
        }

        do {
            player?.stop()

            try FeedbackAudioSession.activate()

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = SoundEffectsVolume.scaled(0.50)
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
        } catch {
            player = nil
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
    }
}

/// Plays the fanfare when a learner reaches the end of a lesson.
@MainActor
final class LessonFinishedFeedbackPlayer: NSObject, @preconcurrency AVAudioPlayerDelegate {
    static let shared = LessonFinishedFeedbackPlayer()

    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func play() {
        guard let url = Bundle.main.url(
            forResource: "finished_lesson",
            withExtension: "mp3",
            subdirectory: "Audio/Feedback"
        ) ?? Bundle.main.url(
            forResource: "finished_lesson",
            withExtension: "mp3"
        ) else {
            return
        }

        do {
            player?.stop()

            try FeedbackAudioSession.activate()

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = SoundEffectsVolume.scaled(0.70)
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
        } catch {
            player = nil
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
    }
}

/// Plays the pop for each word tile placed while building a sentence. Every
/// next slot pops a step higher, so filling the sentence climbs a scale.
/// AVAudioPlayer's `rate` keeps the pitch, so this shifts it with an engine.
@MainActor
final class WordSelectFeedbackPlayer {
    static let shared = WordSelectFeedbackPlayer()

    /// Major-scale steps in semitones, up to one octave.
    private static let scaleSemitones: [Float] = [0, 2, 4, 5, 7, 9, 11, 12]
    // Quick taps overlap the 0.7 s pop instead of cutting it off.
    private static let voiceCount = 4

    private let engine = AVAudioEngine()
    private var voices: [(player: AVAudioPlayerNode, pitch: AVAudioUnitTimePitch)] = []
    private var nextVoice = 0
    private var buffer: AVAudioPCMBuffer?

    private init() {}

    /// The pitch shift, in semitones, for the pop that fills slot `step`
    /// (0-based) of a sentence with `slotCount` slots.
    static func semitones(forStep step: Int, slotCount: Int) -> Float {
        let step = max(0, step)
        // Long sentences climb by semitones so every slot still sounds higher.
        return slotCount <= scaleSemitones.count
            ? scaleSemitones[min(step, scaleSemitones.count - 1)]
            : Float(min(step, 12))
    }

    func play(step: Int, slotCount: Int) {
        do {
            try FeedbackAudioSession.activate()
            guard let buffer = try loadedBuffer() else { return }
            if !engine.isRunning {
                try engine.start()
            }

            let voice = voices[nextVoice]
            nextVoice = (nextVoice + 1) % voices.count
            voice.pitch.pitch = Self.semitones(forStep: step, slotCount: slotCount) * 100
            voice.player.volume = SoundEffectsVolume.scaled(0.55)
            voice.player.stop()
            voice.player.scheduleBuffer(buffer, at: nil, options: [])
            voice.player.play()
        } catch {
            return
        }
    }

    private func loadedBuffer() throws -> AVAudioPCMBuffer? {
        if let buffer { return buffer }
        guard let url = Bundle.main.url(
            forResource: "pop_word_select",
            withExtension: "mp3",
            subdirectory: "Audio/Feedback"
        ) ?? Bundle.main.url(
            forResource: "pop_word_select",
            withExtension: "mp3"
        ) else {
            return nil
        }

        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            return nil
        }
        try file.read(into: buffer)

        for _ in 0..<Self.voiceCount {
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            engine.attach(player)
            engine.attach(pitch)
            engine.connect(player, to: pitch, format: buffer.format)
            engine.connect(pitch, to: engine.mainMixerNode, format: buffer.format)
            voices.append((player, pitch))
        }
        engine.prepare()
        self.buffer = buffer
        return buffer
    }
}

/// Plays the short reward cue when a new badge celebration is presented.
@MainActor
final class BadgeFeedbackPlayer: NSObject, @preconcurrency AVAudioPlayerDelegate {
    static let shared = BadgeFeedbackPlayer()

    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func play() {
        guard let url = Bundle.main.url(
            forResource: "badge",
            withExtension: "mp3",
            subdirectory: "Audio/Feedback"
        ) ?? Bundle.main.url(
            forResource: "badge",
            withExtension: "mp3"
        ) else {
            return
        }

        do {
            player?.stop()

            try FeedbackAudioSession.activate()

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = SoundEffectsVolume.scaled(0.82)
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
        } catch {
            player = nil
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
    }
}

/// Plays a low-volume typing texture while onboarding mascot copy is revealed.
@MainActor
final class OnboardingTypingSound {
    static let shared = OnboardingTypingSound()

    private var player: AVAudioPlayer?
    private var playbackID: UUID?

    var isPlaying: Bool { player?.isPlaying == true }

    private init() {}

    @discardableResult
    func play(for revealDuration: Duration) -> UUID? {
        guard let url = Bundle.main.url(
            forResource: "typing",
            withExtension: "mp3",
            subdirectory: "Audio/Onboarding"
        ) ?? Bundle.main.url(
            forResource: "typing",
            withExtension: "mp3"
        ) else {
            return nil
        }

        do {
            player?.stop()

            try FeedbackAudioSession.activate()

            let player = try AVAudioPlayer(contentsOf: url)
            // A short title plays one pass; a title longer than the clip loops.
            player.numberOfLoops = revealDuration >= .milliseconds(Int(player.duration * 1_000) - 150) ? -1 : 0
            player.volume = SoundEffectsVolume.scaled(0.24)
            player.prepareToPlay()
            guard player.play() else { return nil }
            self.player = player
            let id = UUID()
            playbackID = id
            return id
        } catch {
            player = nil
            playbackID = nil
            return nil
        }
    }

    func stop(_ id: UUID?) {
        guard let id, playbackID == id else { return }
        player?.stop()
        player = nil
        playbackID = nil
    }
}
