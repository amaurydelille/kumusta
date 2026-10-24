import SwiftUI

/// A reusable, game-like reward moment for every achievement in Kumusta.
/// The badge starts above the reward stage, rotates into place, then releases
/// an XP burst before the copy settles underneath it.
struct BadgeCelebrationView: View {
    let achievement: Achievement
    let onDismiss: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var backdropOpacity = 0.0
    @State private var badgeScale: CGFloat = 0.28
    @State private var badgeOffset: CGFloat = -190
    @State private var badgeRotation = -26.0
    @State private var haloScale: CGFloat = 0.2
    @State private var haloOpacity = 0.82
    @State private var particleVisible = false
    @State private var particleBurst = false
    @State private var particleFaded = false
    @State private var copyOpacity = 0.0
    @State private var copyOffset: CGFloat = 28
    @State private var xpScale: CGFloat = 0.62
    @State private var xpOpacity = 0.0
    @State private var isDismissing = false

    private let particles: [RewardParticle] = [
        .init(symbol: "sparkle", x: -124, y: -92, rotation: -22, scale: 1.0, color: .yellow, delay: 0.00),
        .init(symbol: "diamond.fill", x: -92, y: -144, rotation: 18, scale: 0.72, color: .orange, delay: 0.04),
        .init(symbol: "circle.fill", x: -34, y: -166, rotation: 0, scale: 0.65, color: .white, delay: 0.08),
        .init(symbol: "sparkle", x: 36, y: -158, rotation: 28, scale: 0.78, color: .pink, delay: 0.03),
        .init(symbol: "diamond.fill", x: 102, y: -128, rotation: -18, scale: 0.72, color: .yellow, delay: 0.09),
        .init(symbol: "circle.fill", x: 142, y: -68, rotation: 16, scale: 0.58, color: .orange, delay: 0.05),
        .init(symbol: "sparkle", x: 154, y: 2, rotation: -26, scale: 0.92, color: .white, delay: 0.12),
        .init(symbol: "diamond.fill", x: 122, y: 76, rotation: 30, scale: 0.7, color: .pink, delay: 0.07),
        .init(symbol: "circle.fill", x: 58, y: 126, rotation: -10, scale: 0.62, color: .yellow, delay: 0.02),
        .init(symbol: "sparkle", x: -12, y: 148, rotation: 24, scale: 0.82, color: .orange, delay: 0.11),
        .init(symbol: "diamond.fill", x: -80, y: 128, rotation: -16, scale: 0.64, color: .white, delay: 0.06),
        .init(symbol: "circle.fill", x: -140, y: 78, rotation: 12, scale: 0.56, color: .pink, delay: 0.10),
        .init(symbol: "sparkle", x: -154, y: 0, rotation: -12, scale: 0.86, color: .yellow, delay: 0.01),
        .init(symbol: "diamond.fill", x: -145, y: -54, rotation: 24, scale: 0.62, color: .orange, delay: 0.13)
    ]

    var body: some View {
        ZStack {
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                rewardStage

                rewardCopy

                Spacer(minLength: 22)

                Button(L("Keep going"), action: dismiss)
                    .buttonStyle(BadgeRewardButtonStyle())
                    .opacity(copyOpacity)
                    .scaleEffect(xpScale)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 26)
            }
            .frame(maxWidth: 480)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L("%@ badge earned. %@ %lld XP.", achievement.title, achievement.celebrationCopy, achievement.xpValue)
        )
        .onAppear(perform: animateIn)
        .sensoryFeedback(.success, trigger: particleVisible)
    }

    private var rewardStage: some View {
        ZStack {
            Circle()
                .stroke(KumustaColors.accentSoft.opacity(haloOpacity), lineWidth: 2)
                .frame(width: 224, height: 224)
                .scaleEffect(haloScale)

            Circle()
                .stroke(KumustaColors.accent.opacity(haloOpacity * 0.7), lineWidth: 1)
                .frame(width: 270, height: 270)
                .scaleEffect(haloScale * 0.82)

            ForEach(particles) { particle in
                Image(systemName: particle.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(particle.color)
                    .scaleEffect(particle.scale)
                    .rotationEffect(.degrees(particle.rotation))
                    .offset(
                        x: particleBurst ? particle.x : 0,
                        y: particleBurst ? particle.y : 0
                    )
                    .opacity(particleVisible && !particleFaded ? 0.92 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.72, dampingFraction: 0.68)
                                .delay(particle.delay),
                        value: particleBurst
                    )
            }

            ZStack {
                Circle()
                    .fill(KumustaColors.accentShadow.opacity(0.72))
                    .frame(width: 178, height: 178)
                    .offset(y: 9)

                Circle()
                    .fill(KumustaColors.accent)
                    .frame(width: 178, height: 178)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.78), lineWidth: 3)
                            .padding(7)
                    }
                    .overlay {
                        Circle()
                            .stroke(KumustaColors.accentSoft.opacity(0.9), lineWidth: 1)
                            .padding(16)
                    }

                Image(systemName: achievement.symbol)
                    .font(.system(size: 70, weight: .heavy))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(color: KumustaColors.accentShadow.opacity(0.45), radius: 0, y: 4)
            }
            .scaleEffect(badgeScale)
            .offset(y: badgeOffset)
            .rotationEffect(.degrees(badgeRotation))
        }
        .frame(width: 310, height: 310)
        .accessibilityHidden(true)
    }

    private var rewardCopy: some View {
        VStack(spacing: 10) {
            Text(L("BADGE EARNED"))
                .scaledFont(13, weight: .heavy, design: .rounded)
                .scaledTracking(2.1, forPointSize: 13)
                .foregroundStyle(KumustaColors.accentSoft)

            Text(achievement.title)
                .scaledFont(34, weight: .heavy, design: .rounded)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(achievement.celebrationCopy)
                .scaledFont(17, weight: .semibold, design: .rounded)
                .foregroundStyle(.white.opacity(0.76))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(L("+%lld XP", achievement.xpValue))
                .scaledFont(18, weight: .heavy, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(KumustaColors.accentSoft)
                .clipShape(Capsule())
                .scaleEffect(xpScale)
                .opacity(xpOpacity)
                .padding(.top, 3)
        }
        .opacity(copyOpacity)
        .offset(y: copyOffset)
        .padding(.horizontal, 28)
    }

    private func animateIn() {
        BadgeFeedbackPlayer.shared.play()

        guard !reduceMotion else {
            backdropOpacity = 0.86
            badgeScale = 1
            badgeOffset = 0
            badgeRotation = 0
            haloScale = 1
            haloOpacity = 0.18
            copyOpacity = 1
            copyOffset = 0
            xpScale = 1
            xpOpacity = 1
            return
        }

        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.32)) {
            backdropOpacity = 0.86
        }

        withAnimation(.spring(response: 0.78, dampingFraction: 0.62).delay(0.08)) {
            badgeScale = 1
            badgeOffset = 0
            badgeRotation = 5
        }

        withAnimation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.13)) {
            haloScale = 1.32
            haloOpacity = 0
        }

        withAnimation(.spring(response: 0.62, dampingFraction: 0.78).delay(0.45)) {
            particleVisible = true
            particleBurst = true
        }

        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.56).delay(0.48)) {
            copyOpacity = 1
            copyOffset = 0
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.65).delay(0.64)) {
            xpScale = 1
            xpOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.42)) {
                particleFaded = true
            }
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        guard !reduceMotion else {
            onDismiss()
            return
        }

        withAnimation(.timingCurve(0.32, 0, 0.67, 0, duration: 0.24)) {
            backdropOpacity = 0
            badgeScale = 0.74
            badgeOffset = 20
            copyOpacity = 0
            xpOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            onDismiss()
        }
    }
}

private struct RewardParticle: Identifiable {
    let id = UUID()
    let symbol: String
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat
    let color: Color
    let delay: Double
}

private struct BadgeRewardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        KumustaRaisedButtonContent(
            label: configuration.label,
            face: isEnabled ? KumustaColors.accentSoft : KumustaColors.surfaceMuted,
            shadow: isEnabled ? KumustaColors.accentDeep : KumustaColors.line,
            foreground: isEnabled ? KumustaColors.ink : KumustaColors.muted,
            faceHeight: 58,
            depth: 6,
            cornerRadius: 19,
            horizontalPadding: 20,
            font: .system(size: 18, weight: .heavy, design: .rounded),
            border: Color.white.opacity(0.62),
            borderWidth: 1.5,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

#Preview("Badge reward") {
    BadgeCelebrationView(
        achievement: Achievement(kind: .firstLesson, unlockedAt: .now),
        onDismiss: {}
    )
}
