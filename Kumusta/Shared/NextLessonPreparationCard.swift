import SwiftUI

struct NextLessonPreparationCard: View {
    let topic: String?
    let phase: LearningJourneyStore.PreparationPhase
    let failure: PersonalizedLearningError?
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0.18

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                BuddyMotionView(
                    motion: phase == .failed ? .mistake : .generation,
                    size: 76
                )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(titleCopy)
                        .font(KumustaTypography.title2)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detailCopy)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(KumustaColors.line.opacity(0.72))
                    Capsule()
                        .fill(KumustaColors.accent)
                        .frame(width: max(24, proxy.size.width * progress))
                }
            }
            .frame(height: 9)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Preparing the next lesson"))
            .accessibilityValue(progressAccessibilityValue)

            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .foregroundStyle(KumustaColors.accentDeep)
                Text(L("Your completed lesson is already saved in Profile."))
                    .font(KumustaTypography.caption)
                    .foregroundStyle(KumustaColors.muted)
            }

            if phase == .waitingInBackground || (phase == .failed && failure != .generationDailyLimit) {
                Button(phase == .failed ? L("Try again") : L("Check again"), action: onRetry)
                    .buttonStyle(KumustaSecondaryButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(KumustaColors.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .onAppear { animateProgress() }
        .onChange(of: phase) { _, _ in animateProgress() }
    }

    private var detailCopy: String {
        if phase == .failed {
            if let failure {
                return failure.localizedDescription
            }
            return L("We couldn’t prepare this request. Your completed lesson is safe, tap Try again to reconnect.")
        }
        if let topic, !topic.isEmpty {
            return phase == .waitingInBackground
                ? L("Your “%@” lesson needs a little longer. You can leave this screen or check again now.", topic)
                : L("Next up: “%@”. We’re matching the vocabulary, listening rounds, and speaking practice to it.", topic)
        }
        return phase == .waitingInBackground
            ? L("It needs a little longer. You can leave this screen or check again now.")
            : L("We’re using your level and pace feedback to prepare a fresh session.")
    }

    private func animateProgress() {
        let target: CGFloat = phase == .waitingInBackground ? 0.82 : phase == .failed ? 1 : 0.68
        if reduceMotion {
            progress = target
        } else {
            progress = 0.18
            if phase == .failed {
                withAnimation(.easeOut(duration: 0.25)) { progress = target }
            } else {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    progress = target
                }
            }
        }
    }

    private var titleCopy: String {
        if phase == .failed {
            switch failure {
            case .generationDailyLimit:
                return L("Daily lesson limit reached")
            case .generationFailed:
                return L("We couldn’t generate that lesson")
            case .generationPacingLimit:
                return L("Take a quick breather")
            default:
                return L("Your lesson hit a snag")
            }
        }
        return switch phase {
        case .waitingInBackground: L("Still shaping your course")
        case .failed: L("Your lesson hit a snag")
        case .idle, .generating: L("We’re building your next lesson")
        }
    }

    private var progressAccessibilityValue: String {
        switch phase {
        case .waitingInBackground: L("Continuing in the background")
        case .failed: L("Needs attention")
        case .idle, .generating: L("In progress")
        }
    }
}
