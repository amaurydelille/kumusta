import SwiftUI

/// A friendly, comic-style prompt used throughout onboarding so every question
/// feels like it comes from Bé Trâu instead of reading like a form heading.
struct OnboardingSpeechHeader: View {
    let title: String
    let subtitle: String?
    var typingStartDelay: Duration = .milliseconds(190)
    var showsBuddy = true
    var mood: BuddyMood = .happy

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedTitle = ""
    @State private var typingPlaybackID: UUID?

    init(
        title: String,
        subtitle: String? = nil,
        typingStartDelay: Duration = .milliseconds(190),
        showsBuddy: Bool = true,
        mood: BuddyMood = .happy
    ) {
        self.title = title
        self.subtitle = subtitle
        self.typingStartDelay = typingStartDelay
        self.showsBuddy = showsBuddy
        self.mood = mood
    }

    var body: some View {
        Group {
            if showsBuddy {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        BuddyMark(size: 64, mood: mood)
                            .accessibilityHidden(true)
                        speechBubble
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        BuddyMark(size: 66, mood: mood)
                            .accessibilityHidden(true)
                        speechBubble
                    }
                }
            } else {
                speechBubble
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .task(id: animationKey) {
            await revealTitle()
        }
        .onDisappear {
            OnboardingTypingSound.shared.stop(typingPlaybackID)
            typingPlaybackID = nil
        }
    }

    private var animationKey: String {
        "\(title)\u{1f}\(subtitle ?? "")"
    }

    @MainActor
    private func revealTitle() async {
        revealedTitle = ""

        guard !reduceMotion else {
            revealedTitle = title
            return
        }

        do {
            try await Task.sleep(for: typingStartDelay)
            let popRemaining = SelectionFeedbackPlayer.shared.remainingTime
            if popRemaining > 0 {
                try await Task.sleep(for: .milliseconds(Int(ceil(popRemaining * 1_000)) + 35))
            }
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        let revealDuration = title.reduce(Duration.zero) { $0 + typingDelay(after: $1) }
        let playbackID = OnboardingTypingSound.shared.play(for: revealDuration)
        typingPlaybackID = playbackID
        defer {
            OnboardingTypingSound.shared.stop(playbackID)
            if typingPlaybackID == playbackID { typingPlaybackID = nil }
        }

        for character in title {
            do {
                try await Task.sleep(for: typingDelay(after: character))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            revealedTitle.append(character)
        }
    }

    private func typingDelay(after character: Character) -> Duration {
        if character.isWhitespace { return .milliseconds(17) }

        switch character {
        case ".", "!", "?", "…": return .milliseconds(105)
        case ",", ":", ";": return .milliseconds(72)
        default: return .milliseconds(33)
        }
    }

    private var speechBubble: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                Text(title)
                    .scaledFont(25, weight: .bold, design: .rounded)
                    .scaledTracking(-0.25, forPointSize: 25)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .accessibilityHidden(true)

                Text(revealedTitle)
                    .scaledFont(25, weight: .bold, design: .rounded)
                    .scaledTracking(-0.25, forPointSize: 25)
                    .foregroundStyle(KumustaColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(title))
                    .accessibilityAddTraits(.isHeader)
            }

            if let subtitle {
                Text(subtitle)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 25)
        .background {
            OnboardingSpeechBubbleShape()
                .fill(KumustaColors.surface)
        }
        .overlay {
            OnboardingSpeechBubbleShape()
                .stroke(KumustaColors.line, lineWidth: 1.5)
        }
    }
}

private struct OnboardingSpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tailDepth: CGFloat = 10
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(0, rect.height - tailDepth)
        )
        let radius = min(22, bubbleRect.width / 2, bubbleRect.height / 2)
        let tailLeft = min(bubbleRect.maxX - radius - 30, bubbleRect.minX + 24)
        let tailRight = min(bubbleRect.maxX - radius, tailLeft + 25)

        var path = Path()
        path.move(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.minY))
        path.addLine(to: CGPoint(x: bubbleRect.maxX - radius, y: bubbleRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY + radius),
            control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY)
        )
        path.addLine(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.maxX - radius, y: bubbleRect.maxY),
            control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY)
        )
        path.addLine(to: CGPoint(x: tailRight, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailLeft + 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailLeft, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY - radius),
            control: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY)
        )
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.minY),
            control: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct OnboardingWelcomeScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        VStack(spacing: 34) {
            Spacer(minLength: 20)

            OnboardingSpeechHeader(
                title: L("Hi there! I’m Bé Trâu."),
                subtitle: L("I’ll be your Vietnamese buddy."),
                typingStartDelay: .zero,
                showsBuddy: false
            )

            ZStack {
                BuddyMark(size: 220, mood: .happy)
                    .offset(y: isFloating ? -5 : 3)
                    .rotationEffect(.degrees(isFloating ? -1.5 : 1.5))
            }
            .accessibilityHidden(true)

            Spacer(minLength: 24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(KumustaMotion.breathe.repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

struct GoalSelectionScreen: View {
    @Binding var selection: LearningGoal
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            OnboardingSpeechHeader(
                title: L("Why do you want to learn Vietnamese ?"),
                subtitle: ""
            )

            VStack(spacing: 11) {
                ForEach(LearningGoal.allCases) { goal in
                    Button {
                        selection = goal
                        SelectionFeedbackPlayer.shared.play()
                        onSelect()
                    } label: {
                        ChoiceRow(
                            title: goal.title,
                            detail: nil,
                            isSelected: selection == goal,
                            leadingSize: 42
                        ) {
                            Image(goalIconName(for: goal))
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == goal ? .isSelected : [])
                }
            }
        }
    }

    private func goalIconName(for goal: LearningGoal) -> String {
        switch goal {
        case .family: "GoalFamily"
        case .lifeInVietnam: "GoalLifeVietnam"
        case .travel: "GoalTravel"
        case .partner: "GoalPartner"
        case .work: "GoalWork"
        case .culture: "GoalCulture"
        }
    }
}

struct LevelSelectionScreen: View {
    @Binding var selection: ProficiencyLevel
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            OnboardingSpeechHeader(
                title: L("Where is your Vietnamese today?"),
                subtitle: ""
            )

            VStack(spacing: 11) {
                ForEach(ProficiencyLevel.allCases) { level in
                    Button {
                        selection = level
                        SelectionFeedbackPlayer.shared.play()
                        onSelect()
                    } label: {
                        ChoiceRow(
                            title: level.title,
                            detail: nil,
                            isSelected: selection == level,
                            leadingSize: 42
                        ) {
                            Image(levelIconName(for: level))
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == level ? .isSelected : [])
                }
            }
        }
    }

    private func levelIconName(for level: ProficiencyLevel) -> String {
        switch level {
        case .new: "LevelStarting"
        case .familiar: "LevelWords"
        case .conversational: "LevelBasics"
        case .rusty: "LevelHeritage"
        }
    }
}

struct NameEntryScreen: View {
    @Binding var name: String
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasProfanity: Bool {
        !trimmedName.isEmpty && ProfanityFilter.containsProfanity(trimmedName)
    }

    var body: some View {
        VStack(spacing: 26) {
            OnboardingSpeechHeader(
                title: L("What should I call you?"),
                subtitle: L("A first name or nickname is perfect.")
            )

            HStack(spacing: 14) {
                BuddyMark(size: 82, mood: .listening)
                    Text(previewText)
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            TextField(L("First name or nickname"), text: $name)
                .focused(isFocused)
                .font(.title3)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .onSubmit(onSubmit)
                .onChange(of: name) { _, newValue in
                    if newValue.count > 60 { name = String(newValue.prefix(60)) }
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 58)
                .foregroundStyle(KumustaColors.ink)
                .background(KumustaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 2)
                }
                .accessibilityLabel(L("First name or nickname"))

            if hasProfanity {
                Label(
                    L("Please pick a name that’s respectful — this one can’t be used."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.body.weight(.semibold))
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)
        }
        .animation(KumustaMotion.press, value: hasProfanity)
    }

    private var previewText: String {
        if trimmedName.isEmpty { return L("I can’t wait to meet you!") }
        if hasProfanity { return L("I’ll keep it friendly.") }
        return L("He Lô %@!", trimmedName)
    }

    private var borderColor: Color {
        if hasProfanity { return KumustaColors.accent }
        if isFocused.wrappedValue { return KumustaColors.focus }
        return KumustaColors.line
    }
}

struct DailyPlanScreen: View {
    private let options = [5, 7, 10, 15]
    @Binding var minutes: Int
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            OnboardingSpeechHeader(
                title: L("What can you repeat most days?"),
                subtitle: ""
            )

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button {
                        minutes = option
                        SelectionFeedbackPlayer.shared.play()
                        onSelect()
                    } label: {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(KumustaColors.surfaceStrong)
                                Text("\(option)")
                                    .font(.title2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(KumustaColors.ink)
                            }
                            .frame(width: 54, height: 54)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(L(one: "%lld minute a day", other: "%lld minutes a day", count: option))
                                    .font(.headline)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(KumustaColors.ink)
                                Text(planDescription(option))
                                    .font(.body)
                                    .foregroundStyle(KumustaColors.muted)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(minutes == option ? KumustaColors.accentSoft.opacity(0.22) : KumustaColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(minutes == option ? KumustaColors.accent : KumustaColors.line, lineWidth: minutes == option ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(minutes == option ? .isSelected : [])
                }
            }
        }
    }

    private func planDescription(_ option: Int) -> String {
        switch option {
        case 5: L("One focused listening round")
        case 7: L("A complete daily practice")
        case 10: L("Practice plus a word review")
        default: L("A deeper lesson and review")
        }
    }
}

struct CalloutStrip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 32)
            Text(text)
                .font(.body)
                .foregroundStyle(KumustaColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(KumustaColors.accentSoft.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct OnboardingPlanBuildingScreen: View {
    private struct PlanComponent: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let detail: String
    }

    private struct PlanReview: Identifiable {
        let title: String
        let quote: String
        let reviewer: String
        let date: String

        var id: String { reviewer }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var statusIndex = 0
    @State private var completedComponents = 0
    @State private var reviewIndex = 0
    @State private var hasStarted = false

    private let reviews = [
        PlanReview(
            title: "Can’t recommend enough",
            quote: "The app skyrocketed my Vietnamese from A2 to C1 in a few weeks.",
            reviewer: "baddiewithchronicillness",
            date: "Aug 26, 2026"
        ),
        PlanReview(
            title: "Life changing",
            quote: "The voices just sound so natural, it recreates real life Vietnamese situations.",
            reviewer: "AliceChenGM",
            date: "Aug 20, 2026"
        ),
        PlanReview(
            title: "its a no brainer",
            quote: "the before and after is incredible. the best part is the app focusing on hearing and speaking.",
            reviewer: "timdll",
            date: "Aug 24, 2026"
        )
    ]

    let draft: OnboardingDraft
    let onFinished: () async -> Void

    private var statuses: [String] {
        [
            L("Finding the right lessons for you"),
            L("Tuning practice to your level"),
            L("Balancing listening, speaking and review"),
            L("Your learning plan is ready")
        ]
    }

    // The slightly varied beats make the five-second reveal feel like a real
    // sequence of decisions instead of one long, uniform spinner.
    private let componentDelays: [UInt64] = [
        1_100_000_000,
        1_250_000_000,
        1_350_000_000
    ]

    private var components: [PlanComponent] {
        [
            PlanComponent(
                id: 0,
                icon: "ear.fill",
                title: L("Listening"),
                detail: draft.accent == .southern ? L("Real southern Vietnamese") : L("Real northern Vietnamese")
            ),
            PlanComponent(
                id: 1,
                icon: draft.goal.systemImage,
                title: L("Speaking"),
                detail: draft.goal.title
            ),
            PlanComponent(
                id: 2,
                icon: "clock.fill",
                title: L("Daily rhythm"),
                detail: L(one: "%lld focused minute", other: "%lld focused minutes", count: draft.dailyMinutes)
            )
        ]
    }

    var body: some View {
        VStack(spacing: 26) {
            Text(L("PERSONALIZING YOUR KUMUSTA"))
                .font(.caption.weight(.bold))
                .tracking(1.25)
                .foregroundStyle(KumustaColors.accentDeep)

            VStack(spacing: 9) {
                OnboardingSpeechHeader(
                    title: L("Making this yours"),
                    showsBuddy: false,
                    mood: .listening
                )
                statusRoller
            }

            reviewCarousel

            VStack(spacing: 10) {
                ForEach(components) { component in
                    planComponentRow(component)
                }
            }

            progressBar
        }
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
        .task {
            await buildPlan()
        }
    }

    private var statusRoller: some View {
        ZStack {
            ForEach(Array(statuses.enumerated()), id: \.offset) { index, status in
                Text(status)
                    .font(.body.weight(.medium))
                    .foregroundStyle(index == statuses.count - 1 ? KumustaColors.success : KumustaColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .offset(y: CGFloat(index - statusIndex) * 44)
                    .opacity(index == statusIndex ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .clipped()
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82), value: statusIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statuses[statusIndex])
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var reviewCarousel: some View {
        VStack(spacing: 9) {
            TabView(selection: $reviewIndex) {
                ForEach(reviews.indices, id: \.self) { index in
                    appStoreReviewCard(reviews[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 184)
            .accessibilityLabel(L("App Store reviews"))

            HStack(spacing: 6) {
                ForEach(reviews.indices, id: \.self) { index in
                    Circle()
                        .fill(index == reviewIndex ? KumustaColors.accent : KumustaColors.line)
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KumustaColors.accentDeep)
                Text(L("Join a community of"))
                    .foregroundStyle(KumustaColors.muted)
                Text(L("1,000+ students"))
                    .foregroundStyle(KumustaColors.ink)
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(KumustaColors.accentSoft.opacity(0.22), in: Capsule())
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func appStoreReviewCard(_ review: PlanReview) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0xE5A42D))
                .accessibilityLabel(L("5 out of 5 stars"))

                Spacer()

                Label("App Store", systemImage: "apple.logo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KumustaColors.muted)
            }

            Text(review.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(KumustaColors.ink)

            Text("“\(review.quote)”")
                .font(.subheadline)
                .foregroundStyle(KumustaColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(review.reviewer)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                Text(review.date)
                    .fixedSize()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(KumustaColors.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KumustaColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KumustaColors.line.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: KumustaColors.ink.opacity(0.06), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
    }

    private func planComponentRow(_ component: PlanComponent) -> some View {
        let isComplete = completedComponents > component.id

        return HStack(spacing: 14) {
            Image(systemName: component.icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isComplete ? .white : KumustaColors.accentDeep)
                .frame(width: 42, height: 42)
                .background(isComplete ? KumustaColors.accent : KumustaColors.accentSoft.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(component.title)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(KumustaColors.ink)
                Text(component.detail)
                    .font(.subheadline)
                    .foregroundStyle(KumustaColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dotted")
                .font(.title2.weight(.semibold))
                .foregroundStyle(isComplete ? KumustaColors.success : KumustaColors.line)
                .symbolEffect(.bounce, value: isComplete)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isComplete ? KumustaColors.success.opacity(0.36) : KumustaColors.line, lineWidth: 1)
        }
        .scaleEffect(isComplete && !reduceMotion ? 1.012 : 1)
        .animation(reduceMotion ? nil : KumustaMotion.celebrate, value: isComplete)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isComplete ? L("Ready") : L("Preparing"))
    }

    private var progressBar: some View {
        VStack(spacing: 9) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(KumustaColors.surfaceMuted)
                    Capsule()
                        .fill(completedComponents == components.count ? KumustaColors.success : KumustaColors.accent)
                        .frame(width: proxy.size.width * CGFloat(completedComponents) / CGFloat(components.count))
                }
            }
            .frame(height: 10)

            Text(completedComponents == components.count ? L("Ready for your first lesson") : L("Building your daily path…"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(completedComponents == components.count ? KumustaColors.success : KumustaColors.muted)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: completedComponents)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("Learning plan progress"))
        .accessibilityValue(L("%lld of %lld parts ready", completedComponents, components.count))
    }

    @MainActor
    private func buildPlan() async {
        guard !hasStarted else { return }
        hasStarted = true
        for (index, delay) in componentDelays.enumerated() {
            let nextComponent = index + 1
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            withAnimation(reduceMotion ? nil : KumustaMotion.celebrate) {
                completedComponents = nextComponent
                statusIndex = min(nextComponent, statuses.count - 1)
                reviewIndex = min(nextComponent, reviews.count - 1)
            }
            if nextComponent == components.count {
                SuccessFeedbackPlayer.shared.play()
            }
        }

        do {
            try await Task.sleep(nanoseconds: 2_300_000_000)
        } catch {
            return
        }
        await onFinished()
    }
}

struct LessonReminderInvitation: View {
    let onDone: () -> Void
    @Environment(DependencyContainer.self) private var dependencies
    @State private var hour = 19
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OnboardingSpeechHeader(
                    title: L("Make room for tomorrow."),
                    subtitle: L("When would a little nudge help?"),
                    showsBuddy: false
                )
                BuddyMark(size: 110, mood: .happy).accessibilityHidden(true)
                VStack(spacing: 12) {
                    choice(L("Morning"), time: L("9:00 AM"), symbol: "sunrise.fill", value: 9)
                    choice(L("Lunch break"), time: L("12:00 PM"), symbol: "sun.max.fill", value: 12)
                    choice(L("Evening"), time: L("7:00 PM"), symbol: "moon.fill", value: 19)
                }
                Button(isRequesting ? L("Setting up…") : L("Remind me")) {
                    guard !isRequesting else { return }
                    isRequesting = true
                    Task { @MainActor in
                        let service = dependencies.notificationService
                        if await service.requestPermission() {
                            service.reminderHour = hour
                            service.reminderMinute = 0
                            service.remindersEnabled = true
                        }
                        onDone()
                    }
                }
                .buttonStyle(KumustaPrimaryButtonStyle())
                Button(L("Not now"), action: onDone)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(KumustaColors.muted)
                    .frame(minHeight: 44)
            }
            .disabled(isRequesting)
            .padding(24)
            .screenContentWidth()
        }
    }

    private func choice(_ title: String, time: String, symbol: String, value: Int) -> some View {
        Button { hour = value } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 28).accessibilityHidden(true)
                Text(title).font(.headline)
                Spacer()
                Text(time).font(.subheadline)
                Image(systemName: hour == value ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(hour == value ? KumustaColors.accentDeep : KumustaColors.ink)
            .padding(18)
            .background(hour == value ? KumustaColors.accentSoft.opacity(0.25) : KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(hour == value ? .isSelected : [])
    }
}
