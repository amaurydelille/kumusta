import AVFoundation
import Observation
import SwiftUI

/// The tokens let independent audio players contribute without one player's
/// completion hiding another player's glow.
@MainActor
@Observable
final class AudioReactiveBorderState {
    static let shared = AudioReactiveBorderState()

    private var levels: [UUID: Double] = [:]
    private var microphoneTokens: Set<UUID> = []
    private var successTokens: Set<UUID> = []
    private var peakDecibels: [UUID: Double] = [:]
    private var meterTasks: [UUID: Task<Void, Never>] = [:]
    private(set) var level: Double = 0
    var isActive: Bool { !levels.isEmpty || !successTokens.isEmpty }
    var isMicrophoneActive: Bool { !microphoneTokens.isEmpty }
    var isSuccessActive: Bool { !successTokens.isEmpty }

    @discardableResult
    func beginSuccess() -> UUID {
        let token = UUID()
        successTokens.insert(token)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.end(token)
        }
        return token
    }

    @discardableResult
    func begin(microphone: Bool = false) -> UUID {
        let token = UUID()
        levels[token] = 0.08
        if microphone { microphoneTokens.insert(token) }
        peakDecibels[token] = -24
        refresh()
        return token
    }

    func update(_ token: UUID, decibels: Float) {
        guard levels[token] != nil else { return }
        updateLevel(token, decibels: Double(decibels))
    }

    func update(_ token: UUID, amplitude: Double) {
        guard levels[token] != nil else { return }
        let decibels = 20 * log10(max(amplitude, 0.0001))
        updateLevel(token, decibels: decibels)
    }

    private func updateLevel(_ token: UUID, decibels: Double) {
        let measured = decibels.isFinite ? min(0, max(-90, decibels)) : -90
        let peak = max(peakDecibels[token] ?? -24, measured)
        peakDecibels[token] = peak
        // The moving clip reference preserves contrast across quiet recordings
        // and mastered TTS alike. Silence falls away while vowels fill the halo.
        let relative = min(1, max(0, (measured - peak + 24) / 24))
        levels[token] = pow(relative, 2.2)
        refresh()
    }

    func end(_ token: UUID?) {
        guard let token else { return }
        meterTasks.removeValue(forKey: token)?.cancel()
        levels.removeValue(forKey: token)
        microphoneTokens.remove(token)
        successTokens.remove(token)
        peakDecibels.removeValue(forKey: token)
        refresh()
    }

    /// For voice recordings played on the main actor.
    @discardableResult
    func follow(_ player: AVAudioPlayer) -> UUID {
        let token = begin()
        player.isMeteringEnabled = true
        meterTasks[token] = Task { [weak self, weak player] in
            while let self, let player, player.isPlaying, !Task.isCancelled {
                player.updateMeters()
                self.update(token, decibels: player.averagePower(forChannel: 0))
                // 20 Hz is responsive for a decorative meter and leaves the
                // main actor free for the lesson's own transitions and text.
                try? await Task.sleep(for: .milliseconds(50))
            }
            self?.end(token)
        }
        return token
    }

    private func refresh() {
        let target = levels.values.max() ?? 0
        let response = target > level ? 0.58 : 0.38
        let next = levels.isEmpty ? 0 : level + (target - level) * response
        // Tiny meter fluctuations are visually invisible but still invalidate
        // the full-screen overlay. Coalescing them avoids needless redraws.
        if abs(next - level) >= 0.012 || next == 0 {
            level = next
        }
    }
}

struct AudioReactiveBorder: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var state = AudioReactiveBorderState.shared
    @State private var showsSuccessColor = false

    var body: some View {
        let palette: AudioBorderPalette = showsSuccessColor
            ? .success
            : state.isMicrophoneActive
                ? .microphone
                : colorScheme == .dark ? .playbackDark : .playbackLight
        let energy = showsSuccessColor
            ? 0.63
            : pow(max(0, min(1, state.level)), 1.1)
        let reactiveOpacity = showsSuccessColor ? 0.68 : 0.10 + energy * 0.90
        let reactiveScale = showsSuccessColor ? 1 : 0.986 + energy * 0.014

        AudioBorderGlowLayer(palette: palette)
            .equatable()
            // The expensive gradient and blur are rasterized as one stable
            // texture. Audio only changes compositor opacity and scale, so
            // the rich halo is not redrawn on every meter sample.
            .scaleEffect(reactiveScale)
            .opacity(state.isActive ? reactiveOpacity : 0)
            .animation(.linear(duration: 0.055), value: state.level)
        .animation(.easeInOut(duration: 0.24), value: state.isActive)
        .task(id: state.isSuccessActive) {
            if state.isSuccessActive {
                showsSuccessColor = true
            } else {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                showsSuccessColor = false
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum AudioBorderPalette: Equatable {
    case success
    case microphone
    case playbackLight
    case playbackDark

    var primary: Color {
        switch self {
        case .success: KumustaColors.success
        case .microphone: Color(red: 0.20, green: 0.42, blue: 1)
        case .playbackLight: Color(red: 0.05, green: 0.50, blue: 0.51)
        case .playbackDark: Color(red: 0.08, green: 0.58, blue: 0.79)
        }
    }

    var colors: [Color] {
        let color = primary
        return switch self {
        case .success:
            [
                color.opacity(0.35),
                Color(red: 0.58, green: 0.95, blue: 0.60),
                color.opacity(0.98),
                Color(red: 0.25, green: 0.78, blue: 0.50),
                color.opacity(0.35)
            ]
        case .microphone:
            [
                color.opacity(0.42),
                Color(red: 0.30, green: 0.80, blue: 1),
                color.opacity(0.96),
                Color(red: 0.48, green: 0.60, blue: 1),
                color.opacity(0.42)
            ]
        case .playbackLight, .playbackDark:
            [
                color.opacity(0.44),
                color.opacity(0.92),
                color.opacity(0.55),
                color.opacity(0.78),
                color.opacity(0.44)
            ]
        }
    }
}

private struct AudioBorderGlowLayer: View, Equatable {
    let palette: AudioBorderPalette

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 34, style: .continuous)
            .inset(by: 3)
        let gradient = AngularGradient(colors: palette.colors, center: .center)

        ZStack {
            outline
                .stroke(gradient, lineWidth: 50)
                .blur(radius: 30)
                .opacity(0.53)
            outline
                .stroke(gradient, lineWidth: 18)
                .blur(radius: 14)
                .opacity(0.38)
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}
