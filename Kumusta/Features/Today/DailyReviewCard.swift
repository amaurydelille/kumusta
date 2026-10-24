import SwiftUI

/// The daily review's place on Today. Prominent when phrases are due, a
/// quiet confirmation once they are done, and a one-line reminder that the
/// deck exists when nothing is due yet. Hidden until the first lesson.
struct DailyReviewCard: View {
    let onStart: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    /// Due-ness depends on the clock, so re-read it whenever Today returns.
    @State private var refreshDate = Date.now

    private var store: MemoryStore { dependencies.memoryStore }

    var body: some View {
        let _ = refreshDate
        let deckSize = store.allCards().count
        let due = store.dueCount()
        let today = store.todaySummary()

        Group {
            if deckSize == 0 {
                EmptyView()
            } else if due > 0 {
                dueCard(due: due, isFollowUp: today.reviewed > 0)
            } else if today.reviewed > 0 {
                statusLine(
                    title: L("Review done · %lld of %lld remembered", today.recalled, today.reviewed),
                    detail: store.nextReviewDate().map { ReviewSchedulePhrasing.nextReview($0) }
                )
            } else {
                statusLine(
                    title: L(one: "%lld phrase in your memory", other: "%lld phrases in your memory", count: deckSize),
                    detail: store.nextReviewDate().map { ReviewSchedulePhrasing.nextReview($0) }
                )
            }
        }
        .onAppear { refreshDate = .now }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDate = .now }
        }
    }

    private func dueCard(due: Int, isFollowUp: Bool) -> some View {
        // A long-time learner's first day can have hundreds of phrases due.
        // Show one session's worth, never the whole backlog.
        let sessionCount = min(due, MemoryStore.sessionSize)
        let minutes = max(1, Int((Double(sessionCount) * 15 / 60).rounded(.up)))
        return Button(action: onStart) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    BuddyMotionView(motion: .curious, size: 64)
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("DAILY REVIEW"))
                            .scaledFont(12, weight: .heavy, design: .rounded)
                            .scaledTracking(0.8, forPointSize: 12)
                            .foregroundStyle(KumustaColors.success)
                        Text(
                            isFollowUp
                                ? L(one: "%lld more phrase to refresh", other: "%lld more phrases to refresh", count: sessionCount)
                                : L(one: "%lld phrase is fading", other: "%lld phrases are fading", count: sessionCount)
                        )
                        .scaledFont(19, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        Text(L("About %lld min · locks in what you learned", minutes))
                            .scaledFont(13, weight: .medium, design: .rounded)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(L("START REVIEW"))
                    .scaledFont(16, weight: .heavy, design: .rounded)
                    .scaledTracking(0.8, forPointSize: 16)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(KumustaColors.success, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(KumustaColors.success.opacity(0.65))
                            .offset(y: 4)
                    )
                    .padding(.bottom, 4)
            }
        }
        .buttonStyle(ChoiceCardButtonStyle(face: KumustaColors.surface, border: KumustaColors.line))
        .accessibilityElement(children: .combine)
        .accessibilityHint(L("Starts a short review of the phrases you're closest to forgetting"))
        .accessibilityIdentifier("dailyReviewStart")
    }

    /// Plain text under the roadmap title, not a card: when nothing is due
    /// there is nothing to tap, so it shouldn't look like something to tap.
    private func statusLine(title: String, detail: String?) -> some View {
        (
            Text(title)
                .foregroundStyle(KumustaColors.ink)
                .fontWeight(.semibold)
            + Text(detail.map { "  ·  \($0)" } ?? "")
                .foregroundStyle(KumustaColors.muted)
        )
        .scaledFont(14, weight: .medium, design: .rounded)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, -4)
    }
}
