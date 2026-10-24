import SwiftUI

struct PracticeSessionChooser: View {
    let streak: Int
    let onRealtime: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    KumustaScreenTopBar(centerTitle: L("Practice"), streak: streak)

                    modeCard(
                        eyebrow: L("REAL-TIME CHAT"),
                        badge: L("5 MIN"),
                        title: L("Talk with Bé Trâu"),
                        subtitle: L("Free conversation, role-play, and instant feedback."),
                        symbol: "mic.fill",
                        color: KumustaColors.focusFill,
                        shadowColor: KumustaColors.lessonAccentShadow,
                        accessibilityLabel: L("Talk with Bé Trâu in real time for five minutes"),
                        action: onRealtime
                    ) {
                        RealtimePracticeMascots(height: 83)
                            .frame(width: 150, alignment: .leading)
                            .offset(y: isAnimating ? -3 : 2)
                    }

                }
                .padding(.horizontal, 22)
                .padding(.top, 9)
                .padding(.bottom, 24)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func modeCard<Artwork: View>(
        eyebrow: String,
        badge: String,
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        shadowColor: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder artwork: () -> Artwork
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Text(eyebrow)
                        .scaledFont(11, weight: .bold, design: .rounded)
                        .scaledTracking(1.15, forPointSize: 11)

                    Spacer(minLength: 4)

                    Text(badge)
                        .scaledFont(11, weight: .bold, design: .rounded)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                .foregroundStyle(.white.opacity(0.86))

                Text(title)
                    .scaledFont(27, weight: .bold, design: .rounded)
                    .scaledTracking(-0.45, forPointSize: 27)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .scaledFont(14, weight: .medium, design: .rounded)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 2)

                HStack(alignment: .bottom, spacing: 14) {
                    artwork()

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.24), lineWidth: 1.5)
                            .padding(-9)
                        Circle().fill(.white)
                        Image(systemName: symbol)
                            .scaledFont(19, weight: .bold)
                            .foregroundStyle(color)
                            .offset(x: symbol == "play.fill" ? 1 : 0)
                    }
                    .frame(width: 58, height: 58)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
                }
                .accessibilityHidden(true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 232, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    color
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 26)
                        .frame(width: 184, height: 184)
                        .offset(x: 80, y: -102)
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 18, height: 18)
                        .offset(x: -24, y: 31)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: shadowColor.opacity(0.34), radius: 0, y: 6)
        }
        .buttonStyle(.plain)
        .tactile()
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct RealtimePracticeMascots: View {
    let height: CGFloat

    var body: some View {
        HStack(spacing: -5) {
            Image("ConversationMascotFemale")
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(-3))
            Image("ConversationMascotMale")
                .resizable()
                .scaledToFit()
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(3))
        }
        .frame(height: height)
        .accessibilityLabel(L("Your Vietnamese conversation buddies"))
    }
}
