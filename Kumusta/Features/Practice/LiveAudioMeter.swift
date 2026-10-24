import Foundation
@preconcurrency import AVFoundation

/// Mouth features for a captured or played live audio buffer.
enum LiveAudioMeter {
    /// Matches `MascotSpeechTimeline`'s window features so live lip-sync looks
    /// the same as recorded conversation playback.
    static func features(of buffer: AVAudioPCMBuffer) -> MascotSpeechFrame {
        let count = Int(buffer.frameLength)
        guard count > 1 else { return .silent }
        let sample: (Int) -> Double
        if let floats = buffer.floatChannelData?[0] {
            sample = { Double(floats[$0]) }
        } else if let ints = buffer.int16ChannelData?[0] {
            sample = { Double(ints[$0]) / 32768 }
        } else {
            return .silent
        }
        var squares = 0.0
        var difference = 0.0
        var previous = sample(0)
        squares += previous * previous
        for index in 1..<count {
            let value = sample(index)
            squares += value * value
            difference += abs(value - previous)
            previous = value
        }
        let rms = sqrt(squares / Double(count))
        let brightness = difference / Double(count - 1) / max(0.0001, rms)
        return MascotSpeechFrame(
            energy: min(1, rms * 5),
            brightness: min(1, brightness),
            voicing: rms < 0.003 ? 0 : max(0, 1 - brightness * 1.3)
        )
    }
}
