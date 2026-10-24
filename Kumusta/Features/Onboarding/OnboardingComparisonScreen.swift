import SwiftUI

/// "On your own vs With Kumusta": the last onboarding screen, between the
/// welcome lesson and the paywall. It turns what the learner just did into a
/// picture of their next month: an illustrative progress curve, then what the
/// app will actually do for their goal. No invented statistics.
struct OnboardingComparisonScreen: View {
    let name: String?
    let goal: LearningGoal
    let level: ProficiencyLevel
    let dailyMinutes: Int
    let didFinishLesson: Bool
    let onContinue: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var curveProgress: Double = 0
    @State private var hasLanded = false
    @State private var visibleBenefits = 0
    @State private var showsSummary = false
    @State private var isContinuing = false

    private var benefits: [String] {
        OnboardingComparison.benefits(for: goal)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    ComparisonGrowthChart(progress: curveProgress, hasLanded: hasLanded)

                    benefitList

                    summaryChip
                        .opacity(showsSummary ? 1 : 0)
                        .offset(y: showsSummary || reduceMotion ? 0 : 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)

            footer
        }
        .sensoryFeedback(.success, trigger: hasLanded) { _, landed in landed }
        .sensoryFeedback(.impact(weight: .light), trigger: visibleBenefits)
        .task { await reveal() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("YOUR NEXT 30 DAYS"), systemImage: "calendar")
                .scaledFont(13, weight: .heavy, design: .rounded)
                .scaledTracking(0.9, forPointSize: 13)
                .foregroundStyle(KumustaColors.focus)
            Text(OnboardingComparison.headline(level: level, didFinishLesson: didFinishLesson))
                .scaledFont(28, weight: .heavy, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(name.map { L("Here’s what a few minutes a day changes, %@.", $0) } ?? L("Here’s what a few minutes a day changes."))
                .font(KumustaTypography.body)
                .foregroundStyle(KumustaColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Benefits

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark")
                        .scaledFont(12, weight: .black)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(KumustaColors.success))
                        .accessibilityHidden(true)
                    Text(benefit)
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .opacity(index < visibleBenefits ? 1 : 0)
                .offset(x: index < visibleBenefits || reduceMotion ? 0 : -12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("With Kumusta: %@", benefits.joined(separator: ". ")))
    }

    // MARK: Summary and footer

    private var summaryChip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("YOUR PLAN"))
                .scaledFont(12, weight: .heavy, design: .rounded)
                .scaledTracking(0.8, forPointSize: 12)
                .foregroundStyle(KumustaColors.muted)
            // One row when it fits; wraps at large Dynamic Type sizes.
            WordWrapLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                planChip("clock.fill", L("%lld min/day", dailyMinutes))
                planChip("waveform", L("Everyday Tagalog"))
                planChip(goal.systemImage, OnboardingComparison.goalLabel(goal))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func planChip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .scaledFont(13, weight: .bold)
                .foregroundStyle(KumustaColors.focus)
            Text(text)
                .scaledFont(14, weight: .semibold, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
        }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Capsule().fill(KumustaColors.surface))
            .overlay(Capsule().stroke(KumustaColors.line, lineWidth: 1.5))
            .fixedSize()
    }

    private var footer: some View {
        Button {
            guard !isContinuing else { return }
            isContinuing = true
            Task { await onContinue() }
        } label: {
            HStack(spacing: 9) {
                if isContinuing {
                    ProgressView().tint(.white)
                }
                Text(L("SEE MY PLAN"))
                if !isContinuing {
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.bold))
                }
            }
        }
        .buttonStyle(KumustaOnboardingButtonStyle())
        .disabled(isContinuing)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .screenContentWidth()
        .frame(maxWidth: .infinity)
        .background(KumustaColors.canvas.ignoresSafeArea(edges: .bottom))
    }

    // MARK: Reveal

    @MainActor
    private func reveal() async {
        guard !reduceMotion else {
            curveProgress = 1
            hasLanded = true
            visibleBenefits = benefits.count
            showsSummary = true
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeInOut(duration: 1.5)) { curveProgress = 1 }
        try? await Task.sleep(for: .milliseconds(1_500))
        withAnimation(KumustaMotion.celebrate) { hasLanded = true }
        try? await Task.sleep(for: .milliseconds(300))
        for index in 1...benefits.count {
            withAnimation(KumustaMotion.screen) { visibleBenefits = index }
            try? await Task.sleep(for: .milliseconds(220))
        }
        withAnimation(KumustaMotion.screen) { showsSummary = true }
    }
}

// MARK: - Growth chart

/// Illustrative curves, not data: steady daily speaking keeps compounding,
/// while studying alone levels off. The Kumusta icon rides the tip of its
/// curve as it draws and lands at day 30.
private struct ComparisonGrowthChart: View {
    let progress: Double
    let hasLanded: Bool

    private static let plotHeight: CGFloat = 178
    private static let iconSize: CGFloat = 46

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        VStack(alignment: .leading, spacing: 10) {
            Text(L("Speaking confidence"))
                .scaledFont(12, weight: .heavy, design: .rounded)
                .scaledTracking(0.6, forPointSize: 12)
                .foregroundStyle(KumustaColors.muted)
                .textCase(.uppercase)

            GeometryReader { proxy in
                let plot = plotRect(in: proxy.size)
                ZStack(alignment: .topLeading) {
                    grid(in: plot)

                    // Soft wash under the Kumusta curve.
                    GrowthArea(curve: .kumusta, plot: plot, progress: progress)
                        .fill(
                            LinearGradient(
                                colors: [KumustaColors.accent.opacity(0.28), KumustaColors.accent.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    GrowthLine(curve: .alone, plot: plot, progress: progress)
                        .stroke(KumustaColors.muted.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 7]))

                    GrowthLine(curve: .kumusta, plot: plot, progress: progress)
                        .stroke(KumustaColors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .shadow(color: KumustaColors.accent.opacity(0.35), radius: 6, y: 3)

                    startDot(at: GrowthCurve.kumusta.point(at: 0, in: plot))

                    aloneEnd(in: plot)

                    kumustaLabel(in: plot)

                    appIcon
                        .modifier(FollowCurve(curve: .kumusta, plot: plot, progress: progress))
                }
            }
            .frame(height: Self.plotHeight)

            HStack {
                Text(L("Today"))
                Spacer()
                Text(L("Day 30"))
            }
            .scaledFont(13, weight: .bold, design: .rounded)
            .foregroundStyle(KumustaColors.muted)

            Text(L("A few minutes of speaking every day keeps building. Studying on your own tends to stall."))
                .font(KumustaTypography.supporting)
                .foregroundStyle(KumustaColors.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(shape.fill(KumustaColors.surface))
        .overlay(shape.stroke(KumustaColors.line, lineWidth: 1.5))
        // The raised lip of the app's tactile cards.
        .background(shape.fill(KumustaColors.line).offset(y: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Chart: with Kumusta, your speaking confidence keeps rising over 30 days. On your own, it levels off."))
    }

    /// Room on the right and top for the icon that lands on the last point.
    private func plotRect(in size: CGSize) -> CGRect {
        let inset = Self.iconSize / 2
        return CGRect(x: 8, y: inset + 4, width: size.width - 8 - inset - 2, height: size.height - inset - 14)
    }

    private func grid(in plot: CGRect) -> some View {
        Path { path in
            for fraction in [0.0, 0.5, 1.0] {
                let y = plot.minY + plot.height * fraction
                path.move(to: CGPoint(x: plot.minX, y: y))
                path.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
        }
        .stroke(KumustaColors.line.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
    }

    private func startDot(at point: CGPoint) -> some View {
        Circle()
            .fill(KumustaColors.ink)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(KumustaColors.surface, lineWidth: 3))
            .position(point)
    }

    private func aloneEnd(in plot: CGRect) -> some View {
        let end = GrowthCurve.alone.point(at: 1, in: plot)
        return ZStack {
            Circle()
                .fill(KumustaColors.surface)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(KumustaColors.muted, lineWidth: 3))
                .position(end)
            Text(L("On your own"))
                .scaledFont(13, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.muted)
                .fixedSize()
                .position(x: end.x - 44, y: end.y - 20)
        }
        .opacity(hasLanded ? 1 : 0)
    }

    private func kumustaLabel(in plot: CGRect) -> some View {
        let end = GrowthCurve.kumusta.point(at: 1, in: plot)
        return Text(verbatim: "Kumusta")
            .scaledFont(14, weight: .heavy, design: .rounded)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(KumustaColors.accent))
            .fixedSize()
            .position(x: end.x - Self.iconSize / 2 - 50, y: end.y + 4)
            .opacity(hasLanded ? 1 : 0)
            .scaleEffect(hasLanded ? 1 : 0.7, anchor: .trailing)
    }

    private var appIcon: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Image("AppIconBadge")
            .resizable()
            .scaledToFill()
            .frame(width: Self.iconSize, height: Self.iconSize)
            .clipShape(shape)
            .overlay(shape.stroke(KumustaColors.surface, lineWidth: 3))
            .shadow(color: KumustaColors.accent.opacity(0.45), radius: hasLanded ? 10 : 4, y: 4)
            .scaleEffect(hasLanded ? 1.12 : 0.88)
            .accessibilityHidden(true)
    }
}

/// The two illustrative curves, in unit space (x: time, y: confidence, 0 at
/// the bottom). Cubic Béziers keep both smooth.
private struct GrowthCurve: Equatable {
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint

    static let kumusta = GrowthCurve(
        start: CGPoint(x: 0, y: 0.06),
        control1: CGPoint(x: 0.5, y: 0.04),
        control2: CGPoint(x: 0.72, y: 0.4),
        end: CGPoint(x: 1, y: 0.94)
    )

    static let alone = GrowthCurve(
        start: CGPoint(x: 0, y: 0.06),
        control1: CGPoint(x: 0.35, y: 0.08),
        control2: CGPoint(x: 0.6, y: 0.3),
        end: CGPoint(x: 1, y: 0.3)
    )

    func unitPoint(at t: Double) -> CGPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(
            x: a * start.x + b * control1.x + c * control2.x + d * end.x,
            y: a * start.y + b * control1.y + c * control2.y + d * end.y
        )
    }

    func point(at t: Double, in plot: CGRect) -> CGPoint {
        let unit = unitPoint(at: min(1, max(0, t)))
        return CGPoint(x: plot.minX + unit.x * plot.width, y: plot.maxY - unit.y * plot.height)
    }

    /// Points from the start up to `progress`, so line, wash and icon share
    /// one parameter and the icon sits exactly on the tip.
    func points(upTo progress: Double, in plot: CGRect) -> [CGPoint] {
        let clamped = min(1, max(0, progress))
        let steps = max(2, Int(64 * clamped))
        return (0...steps).map { point(at: clamped * Double($0) / Double(steps), in: plot) }
    }
}

private struct GrowthLine: Shape {
    let curve: GrowthCurve
    let plot: CGRect
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0 else { return path }
        path.addLines(curve.points(upTo: progress, in: plot))
        return path
    }
}

private struct GrowthArea: Shape {
    let curve: GrowthCurve
    let plot: CGRect
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = curve.points(upTo: progress, in: plot)
        guard progress > 0, let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: first.x, y: plot.maxY))
        path.addLines(points)
        path.addLine(to: CGPoint(x: last.x, y: plot.maxY))
        path.closeSubpath()
        return path
    }
}

/// Keeps a view on the tip of a curve while `progress` animates.
private struct FollowCurve: ViewModifier, Animatable {
    let curve: GrowthCurve
    let plot: CGRect
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.position(curve.point(at: progress, in: plot))
    }
}

/// The copy behind the comparison screen. Every benefit describes what the
/// app actually does: spoken feedback, everyday Manila Tagalog, real-life
/// situations, conversations with Tuko, and word review.
enum OnboardingComparison {
    static func headline(level: ProficiencyLevel, didFinishLesson: Bool) -> String {
        guard didFinishLesson else { return L("You’re one step from speaking Tagalog.") }
        return switch level {
        case .beginner: L("You just spoke your first Tagalog words.")
        case .intermediate: L("You just ordered merienda in Tagalog.")
        case .advanced: L("You just made plans like a local.")
        }
    }

    static func goalLabel(_ goal: LearningGoal) -> String {
        switch goal {
        case .family: L("Family")
        case .lifeInThePhilippines: L("Life in the Philippines")
        case .travel: L("Travel")
        case .partner: L("Partner")
        case .work: L("Work")
        case .culture: L("Roots")
        }
    }

    static func benefits(for goal: LearningGoal) -> [String] {
        switch goal {
        case .family:
            [
                L("Answer grandma in her own words"),
                L("Join the conversation at dinner"),
                L("Practice what your family really says")
            ]
        case .partner:
            [
                L("Talk to their parents yourself"),
                L("Say the sweet things in Tagalog"),
                L("Laugh at the joke the first time")
            ]
        case .travel:
            [
                L("Order like a local"),
                L("Ask the price and understand it"),
                L("Get a smile and a real chat")
            ]
        case .lifeInThePhilippines:
            [
                L("Handle the market and the landlord"),
                L("Pick up the phone with confidence"),
                L("Know your neighbors by name")
            ]
        case .work:
            [
                L("Follow the meeting"),
                L("Build real rapport with colleagues"),
                L("Make Tagalog part of your career")
            ]
        case .culture:
            [
                L("Answer, not just understand"),
                L("Use the words your family uses"),
                L("Make Tagalog your own voice")
            ]
        }
    }
}

#if DEBUG
#Preview("Comparison") {
    OnboardingComparisonScreen(
        name: "Alex",
        goal: .family,
        level: .intermediate,
        dailyMinutes: 7,
        didFinishLesson: true,
        onContinue: {}
    )
    .environment(DependencyContainer.preview())
}
#endif
