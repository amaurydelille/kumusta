import AVFoundation
import Foundation

/// Plays the short, bundled error cue used after an incorrect answer.
/// Mirrors ``SuccessFeedbackPlayer`` but targets the wrong-answer sound.
@MainActor
final class WrongFeedbackPlayer: NSObject, @preconcurrency AVAudioPlayerDelegate {
    static let shared = WrongFeedbackPlayer()

    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func play() {
        guard let url = Bundle.main.url(
            forResource: "wrong",
            withExtension: "mp3",
            subdirectory: "Audio/Feedback"
        ) ?? Bundle.main.url(
            forResource: "wrong",
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
        } catch {
            player = nil
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
    }
}
