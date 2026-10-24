import SwiftUI

struct OnboardingFlowView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case name
        case goal
        case level
        case dailyPlan
        case building
        case firstLesson
        /// "On your own vs With Kumusta", right before the paywall.
        case comparison

        var analyticsName: String {
            switch self {
            case .welcome: "welcome"
            case .name: "name"
            case .goal: "goal"
            case .level: "level"
            case .dailyPlan: "daily_plan"
            case .building: "plan_building"
            case .firstLesson: "first_lesson"
            case .comparison: "comparison"
            }
        }

        /// Keeps the plan-building screen outside the learner-facing step count.
        var analyticsPosition: Int {
            switch self {
            case .welcome: 0
            case .name: 1
            // 2 was the removed accent step; later positions keep their numbers.
            case .goal: 3
            case .level: 4
            case .dailyPlan: 5
            case .building: 6
            case .firstLesson: 7
            // Welcome-lesson screens use positions 8–15.
            case .comparison: 16
            }
        }

        var showsContinueButton: Bool {
            self == .welcome || self == .name
        }
    }

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = OnboardingDraft()
    @FocusState private var isNameFocused: Bool
    @State private var step: Step = .welcome
    @State private var isSubmitting = false
    @State private var contentIdentity = UUID()
    @State private var hasStarted = false
    @State private var hasRecordedExitForCurrentForeground = false
    /// The funnel payload of the visible welcome-lesson screen, so quitting
    /// mid-lesson is attributed to the exact screen.
    @State private var lessonScreenProperties: [String: String] = [:]
    @State private var didFinishLesson = false

    let onComplete: (OnboardingDraft) async -> Void

    var body: some View {
        ZStack {
            PaperBackground()

            if step == .firstLesson {
                // The lesson brings its own header, progress, and exit sheet.
                firstLesson
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if step == .comparison {
                OnboardingComparisonScreen(
                    name: spokenName,
                    goal: draft.goal,
                    level: draft.level,
                    accent: draft.accent,
                    dailyMinutes: draft.dailyMinutes,
                    didFinishLesson: didFinishLesson
                ) {
                    await finishOnboarding()
                }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else {
            VStack(spacing: 0) {
                if step != .welcome && step != .building {
                    navigationBar
                }

                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 12) {
                            stepPage
                            if step.showsContinueButton {
                                footer
                                    .frame(maxWidth: 560)
                                    .padding(.horizontal, 22)
                                    .padding(.bottom, 12)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    ScrollView {
                        stepPage
                    }
                    .scrollDismissesKeyboard(.interactively)

                    if step.showsContinueButton {
                        footer
                            .frame(maxWidth: 560)
                            .padding(.horizontal, 22)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                    }
                }
            }
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            dependencies.analytics.track(
                .onboardingStarted,
                properties: stepProperties(for: step)
            )
            trackStep()
        }
        .onChange(of: step) {
            trackStep()
            // Personalized clips take ~10s+ to generate. Start as soon as the
            // name and accent are known so the greeting is ready on arrival;
            // repeat at plan building in case either was changed. Requests
            // already in flight are reused.
            // Only the name line is generated live; every other lesson line
            // ships as a bundled clip.
            if step == .goal || step == .building, let spokenName {
                dependencies.onboardingConversationAudio.prefetch(
                    lines: [.replyName],
                    name: spokenName,
                    accent: draft.accent
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                recordExit(reason: "app_backgrounded", flush: true)
            case .active:
                // A backgrounded learner may resume and continue the same
                // onboarding attempt. Allow the next real exit to be logged.
                hasRecordedExitForCurrentForeground = false
            default:
                break
            }
        }
        .onDisappear {
            recordExit(reason: "flow_disappeared", flush: false)
        }
    }

    private var stepPage: some View {
        stepContent
            .id(contentIdentity)
            .frame(maxWidth: 560)
            .padding(.horizontal, 22)
            .padding(.top, step == .welcome ? 28 : 18)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeScreen()
        case .name:
            NameEntryScreen(name: $draft.name, isFocused: $isNameFocused) {
                advance(from: .name)
            }
        case .goal:
            GoalSelectionScreen(selection: $draft.goal) {
                advance(from: .goal)
            }
        case .level:
            LevelSelectionScreen(selection: $draft.level) {
                advance(from: .level)
            }
        case .dailyPlan:
            DailyPlanScreen(minutes: $draft.dailyMinutes) {
                advance(from: .dailyPlan)
            }
        case .building:
            OnboardingPlanBuildingScreen(draft: draft) {
                advance(from: .building)
            }
        case .firstLesson, .comparison:
            // Rendered full-screen instead.
            EmptyView()
        }
    }

    /// The level- and accent-specific welcome lesson, right before the
    /// paywall. Finishing or skipping it completes onboarding.
    @ViewBuilder
    private var firstLesson: some View {
        if let script = try? FirstLessonCatalog.load(
            FirstLessonCatalog.onboardingFile(for: draft.level),
            accent: draft.accent,
            learnerName: spokenName
        ) {
            FirstLessonView(
                script: script,
                learnerName: spokenName,
                isPrePaywall: true,
                onFinish: {
                    didFinishLesson = true
                    move(to: .comparison)
                },
                onClose: {
                    dependencies.analytics.track(
                        .featureAction,
                        properties: currentLessonProperties.merging(["value": "lesson_skipped"], uniquingKeysWith: { _, new in new })
                    )
                    move(to: .comparison)
                },
                onScreenChange: { lessonScreenProperties = $0 }
            )
            .id(script.id)
        } else {
            // A missing bundle resource must never block the paywall.
            Color.clear.task { move(to: .comparison) }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 14) {
            Button {
                moveBackward()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(KumustaColors.ink)
                    .background(KumustaColors.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(KumustaColors.line, lineWidth: 1)
                    }
            }
            .accessibilityLabel(L("Back"))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(KumustaColors.surfaceMuted)
                    Capsule()
                        .fill(KumustaColors.accent)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Onboarding progress"))
            .accessibilityValue(L("%lld percent", Int(progress * 100)))

            Text(L("%lld of %lld", step.rawValue, Self.questionStepCount))
                .font(.body.weight(.semibold))
                .foregroundStyle(KumustaColors.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                HStack(spacing: 9) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    }
                    Text(primaryButtonTitle)
                    if !isSubmitting {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.bold))
                    }
                }
            }
            .buttonStyle(KumustaOnboardingButtonStyle())
            .disabled(isSubmitting || (step == .name && !isValidName))
        }
    }

    /// The bar counts the question screens; the lesson and comparison run
    /// full-screen after them.
    private static let questionStepCount = Step.firstLesson.rawValue

    private var progress: CGFloat {
        min(1, CGFloat(step.rawValue) / CGFloat(Self.questionStepCount))
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: L("Continue")
        case .name: L("Continue")
        case .goal, .level: L("Continue")
        case .dailyPlan: L("Build my learning plan")
        case .building: L("Building your plan…")
        case .firstLesson, .comparison: L("Continue")
        }
    }

    private func advance(from expectedStep: Step? = nil) {
        guard !isSubmitting else { return }
        guard expectedStep == nil || expectedStep == step else { return }
        if step == .name {
            guard isValidName else { return }
            draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            isNameFocused = false
        }
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        move(to: next)
    }

    private var spokenName: String? {
        OnboardingConversationAudio.spokenFirstName(from: draft.name)
    }

    private var isValidName: Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 60 && !ProfanityFilter.containsProfanity(name)
    }

    private func finishOnboarding() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        dependencies.analytics.track(.onboardingStepCompleted, properties: stepProperties(for: step))
        await onComplete(draft)
    }

    private func moveBackward() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        move(to: previous, tracksProgress: false)
    }

    private func move(to destination: Step, tracksProgress: Bool = true) {
        if tracksProgress {
            dependencies.analytics.track(
                .onboardingStepCompleted,
                properties: stepProperties(for: step)
            )
            if let selectedValue = selectedValue(for: step) {
                dependencies.analytics.track(
                    .onboardingOptionSelected,
                    properties: stepProperties(for: step, additional: ["value": selectedValue])
                )
            }
        }
        if reduceMotion {
            step = destination
            contentIdentity = UUID()
        } else {
            withAnimation(KumustaMotion.screen) {
                step = destination
                contentIdentity = UUID()
            }
        }
    }

    private func trackStep() {
        dependencies.analytics.track(
            .onboardingStepViewed,
            properties: stepProperties(for: step)
        )
    }

    private func recordExit(reason: String, flush: Bool) {
        guard hasStarted, !isSubmitting, !hasRecordedExitForCurrentForeground else { return }
        hasRecordedExitForCurrentForeground = true
        let base = step == .firstLesson ? currentLessonProperties : stepProperties(for: step)
        let properties = base.merging(["source": reason], uniquingKeysWith: { _, new in new })
        if flush {
            Task {
                await dependencies.analytics.trackAndFlush(
                    .onboardingAbandoned,
                    properties: properties
                )
            }
        } else {
            dependencies.analytics.track(.onboardingAbandoned, properties: properties)
        }
    }

    /// The welcome-lesson screen when one is showing, else the lesson step.
    private var currentLessonProperties: [String: String] {
        lessonScreenProperties.isEmpty ? stepProperties(for: .firstLesson) : lessonScreenProperties
    }

    private func stepProperties(
        for step: Step,
        additional: [String: String] = [:]
    ) -> [String: String] {
        [
            "screen_name": "onboarding_\(step.analyticsName)",
            "source": "onboarding_first_lesson_v2",
            "step": step.analyticsName,
            "position": String(step.analyticsPosition)
        ].merging(additional, uniquingKeysWith: { _, additional in additional })
    }

    private func selectedValue(for step: Step) -> String? {
        switch step {
        case .name: "provided"
        case .goal: draft.goal.rawValue
        case .level: draft.level.rawValue
        case .dailyPlan: String(draft.dailyMinutes)
        case .welcome, .building, .firstLesson, .comparison: nil
        }
    }
}
