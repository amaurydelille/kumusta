import SwiftUI

struct StreakCelebrationView: View {
    let streak: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CelebrationPhase = .entering
    @State private var particles: [CelebrationParticle] = []
    @State private var flameScale: CGFloat = 0.3
    @State private var textOpacity: CGFloat = 0
    @State private var textOffset: CGFloat = 30

    private enum CelebrationPhase {
        case entering
        case showing
        case exiting
    }

    var body: some View {
        ZStack {
            Color.black.opacity(phase == .entering ? 0 : 0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()

                BuddyMotionView(motion: .streak, size: 190)
                    .scaleEffect(flameScale)
                    .accessibilityHidden(true)

                Spacer().frame(height: 24)

                VStack(spacing: 6) {
                    Text("\(streak)")
                        .scaledFont(72, weight: .heavy, design: .rounded)
                        .foregroundStyle(.white)

                    Text(L(one: "day streak (singular)", other: "day streak", count: streak))
                        .scaledFont(28, weight: .bold, design: .rounded)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L(one: "%lld day streak", other: "%lld-day streak", count: streak))

                if streak >= 7 {
                    Text(streakMilestoneLabel)
                        .scaledFont(18, weight: .semibold, design: .rounded)
                        .foregroundStyle(KumustaColors.accentSoft)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .opacity(textOpacity)
                        .padding(.top, 16)
                }

                Spacer()

                Button(L("Keep going")) {
                    dismiss()
                }
                .scaledFont(18, weight: .bold, design: .rounded)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(KumustaColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .opacity(textOpacity)
            }

            particleCanvas
        }
        .onAppear { animateIn() }
        .sensoryFeedback(.success, trigger: phase)
    }

    private var streakMilestoneLabel: String {
        switch streak {
        case 7: L("One week strong")
        case 14: L("Two weeks of ear training")
        case 30: L("A full month. You're building a habit.")
        case 60: L("Two months. Real progress.")
        case 100: L("One hundred days. This is who you are now.")
        case 365: L("One year. Chúc mừng.")
        default: L("%lld days and counting", streak)
        }
    }

    private var particleCanvas: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.x,
                    y: particle.y,
                    width: particle.size,
                    height: particle.size
                )
                let path = Circle().path(in: rect)
                context.fill(path, with: .color(particle.color.opacity(particle.opacity)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func animateIn() {
        guard !reduceMotion else {
            flameScale = 1
            textOpacity = 1
            textOffset = 0
            phase = .showing
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
            flameScale = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            textOpacity = 1
            textOffset = 0
        }

        spawnParticles()

        phase = .showing
    }

    private func spawnParticles() {
        let colors: [Color] = [.orange, .yellow, .red, .pink, .white]
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.keyWindow
        else { return }

        let centerX = window.bounds.width / 2

        for _ in 0..<40 {
            let angle = Double.random(in: -.pi...0)
            let distance = Double.random(in: 60...220)
            particles.append(CelebrationParticle(
                x: centerX + cos(angle) * distance,
                y: 280 + sin(angle) * distance,
                size: Double.random(in: 3...9),
                color: colors.randomElement()!,
                opacity: 0.9
            ))
        }

        withAnimation(.easeOut(duration: 1.8)) {
            for i in particles.indices {
                particles[i].y += Double.random(in: 100...350)
                particles[i].x += Double.random(in: -80...80)
                particles[i].opacity = 0
            }
        }
    }

    private func dismiss() {
        guard phase == .showing else { return }
        phase = .exiting
        withAnimation(.easeOut(duration: 0.25)) {
            flameScale = 0.3
            textOpacity = 0
            textOffset = -20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

private struct CelebrationParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    let size: Double
    let color: Color
    var opacity: Double
}
