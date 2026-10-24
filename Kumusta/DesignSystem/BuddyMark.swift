import SwiftUI

enum BuddyMood {
    case happy
    case listening
    case proud
}

enum BuddyMotion: Equatable {
    case launch
    case welcomeWave
    case listening
    case curious
    case reviewing
    case correct
    case mistake
    case generation
    case streak

    fileprivate var spriteName: String {
        switch self {
        case .launch: "MascotLaunchSprite"
        case .welcomeWave: "MascotWelcomeWaveSprite"
        case .listening: "MascotListeningSprite"
        case .curious: "MascotCuriousSprite"
        case .reviewing: "MascotGenerationSprite"
        case .correct: "MascotCorrectSprite"
        case .mistake: "MascotMistakeSprite"
        case .generation: "MascotGenerationSprite"
        case .streak: "MascotStreakSprite"
        }
    }

    fileprivate var isLooping: Bool {
        switch self {
        case .launch, .welcomeWave, .listening, .curious, .reviewing, .correct, .generation, .streak: true
        case .mistake: false
        }
    }

    fileprivate var sequence: [(frame: Int, duration: Duration)] {
        switch self {
        case .launch:
            [(0, .milliseconds(110)), (1, .milliseconds(100)), (2, .milliseconds(100)), (3, .milliseconds(120)), (4, .milliseconds(170)), (5, .milliseconds(120)), (6, .milliseconds(100)), (7, .milliseconds(100)), (6, .milliseconds(100)), (5, .milliseconds(120)), (4, .milliseconds(170)), (3, .milliseconds(120)), (2, .milliseconds(100)), (1, .milliseconds(100))]
        case .welcomeWave:
            [(0, .milliseconds(130)), (1, .milliseconds(110)), (2, .milliseconds(100)), (3, .milliseconds(120)), (4, .milliseconds(220)), (5, .milliseconds(120)), (6, .milliseconds(100)), (7, .milliseconds(110)), (6, .milliseconds(100)), (5, .milliseconds(120)), (4, .milliseconds(220)), (3, .milliseconds(120)), (2, .milliseconds(100)), (1, .milliseconds(110))]
        case .listening:
            [(0, .milliseconds(220)), (1, .milliseconds(180)), (2, .milliseconds(180)), (3, .milliseconds(220)), (4, .milliseconds(560)), (5, .milliseconds(220)), (6, .milliseconds(180)), (7, .milliseconds(220)), (6, .milliseconds(180)), (5, .milliseconds(220)), (4, .milliseconds(560)), (3, .milliseconds(220)), (2, .milliseconds(180)), (1, .milliseconds(180))]
        case .curious:
            [(0, .milliseconds(160)), (1, .milliseconds(140)), (2, .milliseconds(140)), (3, .milliseconds(180)), (4, .milliseconds(620)), (5, .milliseconds(180)), (6, .milliseconds(140)), (7, .milliseconds(180)), (6, .milliseconds(140)), (5, .milliseconds(180)), (4, .milliseconds(620)), (3, .milliseconds(180)), (2, .milliseconds(140)), (1, .milliseconds(140))]
        case .correct:
            [(0, .milliseconds(100)), (1, .milliseconds(90)), (2, .milliseconds(90)), (3, .milliseconds(110)), (4, .milliseconds(220)), (5, .milliseconds(110)), (6, .milliseconds(120)), (7, .milliseconds(180)), (6, .milliseconds(100)), (5, .milliseconds(100)), (4, .milliseconds(180)), (3, .milliseconds(100)), (2, .milliseconds(90)), (1, .milliseconds(90))]
        case .mistake:
            [(0, .milliseconds(140)), (1, .milliseconds(140)), (2, .milliseconds(160)), (3, .milliseconds(220)), (4, .milliseconds(720)), (5, .milliseconds(220)), (6, .milliseconds(180)), (7, .milliseconds(900))]
        case .reviewing, .generation:
            [(0, .milliseconds(180)), (1, .milliseconds(140)), (2, .milliseconds(140)), (3, .milliseconds(180)), (4, .milliseconds(420)), (5, .milliseconds(180)), (6, .milliseconds(140)), (7, .milliseconds(180)), (6, .milliseconds(140)), (5, .milliseconds(180)), (4, .milliseconds(420)), (3, .milliseconds(180)), (2, .milliseconds(140)), (1, .milliseconds(140))]
        case .streak:
            [(0, .milliseconds(100)), (1, .milliseconds(90)), (2, .milliseconds(90)), (3, .milliseconds(110)), (4, .milliseconds(480)), (5, .milliseconds(150)), (6, .milliseconds(120)), (7, .milliseconds(200)), (6, .milliseconds(100)), (5, .milliseconds(100)), (4, .milliseconds(400)), (3, .milliseconds(110)), (2, .milliseconds(90)), (1, .milliseconds(90))]
        }
    }

    fileprivate var frameAspectRatio: CGFloat {
        1
    }

    fileprivate var spriteGrid: (columns: Int, rows: Int) {
        (8, 1)
    }

    fileprivate var spriteCellInset: CGFloat {
        0
    }

    fileprivate var usesContinuousMotion: Bool {
        self == .launch || self == .listening || self == .curious
    }
}

struct BuddyMark: View {
    let size: CGFloat
    var mood: BuddyMood = .happy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAlive = false

    var body: some View {
        Image("TukoBuddy")
            .resizable()
            .scaledToFit()
            .scaleEffect(animatedScale)
            .rotationEffect(.degrees(animatedRotation))
            .offset(y: animatedOffset)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Tuko, the Kumusta mascot"))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(KumustaMotion.breathe.repeatForever(autoreverses: true)) {
                isAlive = true
            }
        }
    }

    private var animatedScale: CGFloat {
        guard isAlive else { return 1 }
        return switch mood {
        case .happy: 1.025
        case .listening: 1.04
        case .proud: 1.055
        }
    }

    private var animatedRotation: Double {
        guard isAlive else { return 0 }
        return switch mood {
        case .happy: 1
        case .listening: -2
        case .proud: 2
        }
    }

    private var animatedOffset: CGFloat {
        guard isAlive else { return 0 }
        return switch mood {
        case .happy: -2
        case .listening: 1
        case .proud: -5
        }
    }
}

/// An eight-frame mascot sprite animation. Each generated sheet is intentionally
/// kept as one asset so the mascot's painted details stay consistent between
/// the anticipation, action, and settle poses.
struct BuddyMotionView: View {
    let motion: BuddyMotion
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStart = Date()

    var body: some View {
        Group {
            if reduceMotion {
                SpriteSheetFrame(
                    imageName: motion.spriteName,
                    frame: 0,
                    size: size,
                    frameAspectRatio: motion.frameAspectRatio,
                    columns: motion.spriteGrid.columns,
                    rows: motion.spriteGrid.rows,
                    cellInset: motion.spriteCellInset
                )
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    SpriteSheetFrame(
                        imageName: motion.spriteName,
                        frame: motion.usesContinuousMotion ? 0 : frame(at: timeline.date),
                        size: size,
                        frameAspectRatio: motion.frameAspectRatio,
                        columns: motion.spriteGrid.columns,
                        rows: motion.spriteGrid.rows,
                        cellInset: motion.spriteCellInset
                    )
                    .rotationEffect(continuousRotation(at: timeline.date))
                    .offset(y: continuousVerticalOffset(at: timeline.date))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(motion.accessibilityLabel)
        .onAppear {
            animationStart = .now
        }
        .onChange(of: motion) { _, _ in
            animationStart = .now
        }
    }

    private func frame(at date: Date) -> Int {
        guard !motion.sequence.isEmpty else { return 0 }

        let elapsed = max(0, date.timeIntervalSince(animationStart))
        let cycleDuration = motion.sequence.reduce(0.0) { total, step in
            total + seconds(for: step.duration)
        }
        guard cycleDuration > 0 else { return motion.sequence[0].frame }

        let position = motion.isLooping
            ? elapsed.truncatingRemainder(dividingBy: cycleDuration)
            : min(elapsed, cycleDuration.nextDown)

        var cursor = 0.0
        for step in motion.sequence {
            cursor += seconds(for: step.duration)
            if position < cursor {
                return step.frame
            }
        }
        return motion.sequence.last?.frame ?? 0
    }

    private func seconds(for duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private func continuousVerticalOffset(at date: Date) -> CGFloat {
        guard motion.usesContinuousMotion else { return 0 }

        let elapsed = max(0, date.timeIntervalSince(animationStart))
        let period: TimeInterval
        let amplitude: CGFloat

        switch motion {
        case .launch:
            period = 2.6
            amplitude = 2.2
        case .listening:
            period = 2.8
            amplitude = 0.8
        case .curious:
            period = 2.4
            amplitude = 1.0
        default:
            return 0
        }

        let phase = (elapsed / period) * 2 * Double.pi
        return CGFloat(sin(phase)) * amplitude
    }

    private func continuousRotation(at date: Date) -> Angle {
        guard motion == .launch else { return .zero }

        let elapsed = max(0, date.timeIntervalSince(animationStart))
        let phase = (elapsed / 3.2) * 2 * Double.pi
        return .degrees(sin(phase) * 0.9)
    }
}

private struct SpriteSheetFrame: View {
    let imageName: String
    let frame: Int
    let size: CGFloat
    let frameAspectRatio: CGFloat
    let columns: Int
    let rows: Int
    let cellInset: CGFloat

    var body: some View {
        let safeColumns = max(columns, 1)
        let safeRows = max(rows, 1)
        let frameCount = safeColumns * safeRows
        let safeFrame = min(max(frame, 0), frameCount - 1)
        let column = safeFrame % safeColumns
        let row = safeFrame / safeColumns
        let frameWidth = size * frameAspectRatio
        let safeInset = min(max(cellInset, 0), min(frameWidth, size) / 4)

        Image(imageName)
            .resizable()
            .interpolation(.high)
            .frame(
                width: size * frameAspectRatio * CGFloat(safeColumns),
                height: size * CGFloat(safeRows)
            )
            .offset(
                x: -CGFloat(column) * frameWidth - safeInset,
                y: -CGFloat(row) * size - safeInset
            )
            .frame(
                width: frameWidth - (safeInset * 2),
                height: size - (safeInset * 2),
                alignment: .topLeading
            )
            .clipped()
            .frame(width: frameWidth, height: size)
    }
}

private extension BuddyMotion {
    var accessibilityLabel: String {
        switch self {
        case .launch: L("Tuko welcomes you to Kumusta")
        case .welcomeWave: L("Tuko waves hello")
        case .listening: L("Tuko is listening")
        case .curious: L("Tuko is curious")
        case .reviewing: L("Tuko is reviewing your recording")
        case .correct: L("Tuko celebrates the correct answer")
        case .mistake: L("Tuko encourages another try")
        case .generation: L("Tuko is building the next lesson")
        case .streak: L("Tuko celebrates your learning streak")
        }
    }
}
