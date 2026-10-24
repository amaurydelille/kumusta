import SwiftUI
import Supabase
import CryptoKit

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var roadmapLessons: [RoadmapLesson] = []
    @State private var selectedRoadmapLesson: RoadmapLesson?
    @State private var loadError: String?
    @State private var shouldEvaluateAchievementsAfterLessonDismiss = false
    @State private var isUsingAuthoritativeRoadmap = false
    @State private var unlockedLevel: ProficiencyLevel?
    @State private var goalRows: [GoalCurriculumRow] = []
    @State private var goalStage = 1
    @State private var isReviewing = false
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeedRawValue = AudioPreferences.fallbackSpeed.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                KumustaAmbientShapes()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            VStack(spacing: 12) {
                                KumustaScreenTopBar(streak: activity.currentStreak())
                                roadmapSummary
                                DailyReviewCard() {
                                    isReviewing = true
                                }
                            }
                            .padding(.horizontal, 22)

                            if let loadError {
                                roadmapError(loadError)
                                    .padding(.horizontal, 22)
                                    .padding(.top, 26)
                            } else if roadmapLessons.isEmpty {
                                roadmapLoading.padding(.top, 34)
                            } else {
                                roadmap.padding(.top, 20)
                            }
                        }
                        .padding(.top, 9)
                        .padding(.bottom, 42)
                        .screenContentWidth()
                    }
                    .scrollIndicators(.hidden)
                    // Attached outside the lazy stack, which may unload the card.
                    .fullScreenCover(isPresented: $isReviewing) {
                        DailyReviewView(
                            entryPoint: "today",
                            onDismiss: { isReviewing = false }
                        )
                        .overlay { AudioReactiveBorder() }
                    }
                    // Open where the learner left off, and follow them to the
                    // next lesson after they finish one.
                    .onChange(of: activeLessonID, initial: true) { _, lessonID in
                        guard let lessonID else { return }
                        Task { @MainActor in
                            // Let the lazy stack lay out the new rows first.
                            await Task.yield()
                            proxy.scrollTo(lessonID, anchor: .center)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { activity.reload() }
            // Lessons load in the app's language; the review deck keeps each
            // phrase's meaning in it so reviews follow a language switch.
            .onChange(of: roadmapLessons.map(\.id), initial: true) { _, _ in
                dependencies.memoryStore.learnMeanings(from: roadmapLessons.map(\.lesson))
            }
            .task(id: "\(appState.profile.id)-\(appState.profile.goal.rawValue)-\(appState.profile.level.rawValue)") {
                await loadRoadmap()
            }
            .fullScreenCover(
                item: $selectedRoadmapLesson,
                onDismiss: evaluateAchievementsAfterLessonDismiss
            ) { item in
                LessonFlowView(
                    lesson: item.lesson,
                    initialStepIndex: resumeStepIndex(for: item),
                    telemetryContext: LessonTelemetryContext(
                        contentKind: goalRows.contains(where: { $0.id == item.id }) ? .goal : .authored,
                        entryPoint: "today",
                        isReplay: completedLessonIDs.contains(item.id)
                    ),
                    onComplete: { feedback in completeLesson(item, feedback: feedback) },
                    onDismiss: dismissLesson
                )
                .overlay { AudioReactiveBorder() }
            }
            .alert(item: $unlockedLevel) { level in
                Alert(
                    title: Text(L("New roadmap unlocked")),
                    message: Text(L("You completed this path. %@ is now your active level.", level.title)),
                    dismissButton: .default(Text(L("Start learning")))
                )
            }
        }
    }

    private var roadmapSummary: some View {
        Text(roadmapTitle)
            .scaledFont(23, weight: .bold, design: .rounded)
            .scaledTracking(-0.45, forPointSize: 23)
            .foregroundStyle(KumustaColors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var roadmap: some View {
        LazyVStack(spacing: 28) {
            ForEach(roadmapUnits) { unit in
                RoadmapUnitSection(
                    unit: unit,
                    completedLessonIDs: completedLessonIDs,
                    activeLessonID: activeLessonID,
                    reduceMotion: reduceMotion,
                    onOpen: openLesson
                )
            }
            roadmapFinish.padding(.horizontal, 22)
        }
    }

    private var roadmapFinish: some View {
        VStack(spacing: 10) {
            Image(systemName: completedRoadmapCount == roadmapLessons.count ? "trophy.fill" : "flag.fill")
                .scaledFont(25, weight: .bold)
                .foregroundStyle(completedRoadmapCount == roadmapLessons.count ? KumustaColors.accentDeep : KumustaColors.muted)
            Text(completedRoadmapCount == roadmapLessons.count ? L("Learning path complete") : L("Your next Tagalog milestone"))
                .scaledFont(15, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
            Text(completedRoadmapCount == roadmapLessons.count ? L("Every lesson stays open for practice.") : L("Complete each lesson to reach the flag."))
                .scaledFont(12, weight: .medium, design: .rounded)
                .foregroundStyle(KumustaColors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private var roadmapLoading: some View {
        VStack(spacing: 30) {
            ForEach(0 ..< 4, id: \.self) { index in
                Circle()
                    .fill(index == 0 ? KumustaColors.accent.opacity(0.45) : KumustaColors.surfaceStrong)
                    .frame(width: 78, height: 78)
                    .offset(x: RoadmapPathGeometry.horizontalOffset(for: index))
            }
        }
        .frame(maxWidth: .infinity)
        .overlay { ProgressView().tint(KumustaColors.accentDeep) }
        .accessibilityLabel(L("Loading your lesson path"))
    }

    private func roadmapError(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "map.fill")
                .scaledFont(28, weight: .bold)
                .foregroundStyle(KumustaColors.accentDeep)
            Text(L("Your path couldn’t open"))
                .font(KumustaTypography.title2)
                .foregroundStyle(KumustaColors.ink)
            Text(message)
                .font(KumustaTypography.supporting)
                .foregroundStyle(KumustaColors.muted)
                .multilineTextAlignment(.center)
            Button(L("Try again")) { Task { await loadRoadmap() } }
                .buttonStyle(KumustaPrimaryButtonStyle())
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(KumustaColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var completedLessonIDs: Set<UUID> {
        dependencies.learningJourneyStore.completedLessonIDs
    }

    private func loadRoadmap() async {
        let profile = appState.profile
        roadmapLessons = []
        goalRows = []
        loadError = nil

        // Keep the existing level roadmap and its stable lesson IDs first.
        // Goal lessons are an extension; they must never replace prior progress.
        loadBundledRoadmap(for: profile)

        guard GoalCurriculumSelection.supports(profile.goal) else {
            return
        }

        do {
            guard let service = dependencies.goalCurriculum else { throw GoalCurriculumError.unavailable }
            let rows = try await service.lessons(goal: profile.goal)
            try Task.checkCancellation()
            guard appState.profile.id == profile.id, appState.profile.goal == profile.goal,
                  appState.profile.level == profile.level else { return }
            try GoalCurriculumSelection.validate(rows, goal: profile.goal)
            goalRows = rows
            goalStage = GoalCurriculumSelection.recommendedStage(level: profile.level, rows: rows, completed: completedLessonIDs)
            appendGoalStage()
            prewarmNextLesson()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            // The existing roadmap remains usable if the optional extension
            // is unavailable. Do not hide or reset prior progress.
            if roadmapLessons.isEmpty {
                loadError = L("Your personalized path couldn’t load. Check your connection and try again.")
            }
        }
    }

    private var completedRoadmapCount: Int {
        roadmapLessons.filter { completedLessonIDs.contains($0.id) }.count
    }

    private var visibleGoalLessons: [RoadmapLesson] {
        let goalIDs = Set(goalRows.map(\.id))
        return roadmapLessons.filter { goalIDs.contains($0.id) }
    }

    private var activeLessonID: UUID? {
        roadmapLessons.first { !completedLessonIDs.contains($0.id) }?.id
    }

    private var roadmapUnits: [RoadmapUnit] {
        Dictionary(grouping: roadmapLessons, by: \.unitOrder)
            .map { _, lessons in
                let ordered = lessons.sorted { $0.lessonOrder < $1.lessonOrder }
                return RoadmapUnit(
                    order: ordered[0].unitOrder,
                    title: ordered[0].unitTitle,
                    lessons: ordered
                )
            }
            .sorted { $0.order < $1.order }
    }

    private var roadmapTitle: String {
        if !visibleGoalLessons.isEmpty {
            return GoalCurriculumSelection.title(appState.profile.goal)
        }
        return switch appState.profile.level {
        case .beginner: L("New to Tagalog")
        case .intermediate: L("Turn words into conversation")
        case .advanced: L("Handle real conversations")
        }
    }

    private var activity: LocalLearningActivityStore {
        dependencies.learningActivityStore
    }

    private func loadBundledRoadmap(for profile: UserProfile) {
        do {
            roadmapLessons = try RoadmapCatalog.load(
                level: profile.level
            )
            isUsingAuthoritativeRoadmap = true
            loadError = nil
        } catch {
            roadmapLessons = RoadmapCatalog.fallback(
                level: profile.level
            )
            isUsingAuthoritativeRoadmap = false
            loadError = roadmapLessons.isEmpty
                ? L("This learning path isn’t included in this build. Please update Kumusta.")
                : nil
        }
        prewarmNextLesson()
    }

    private func openLesson(_ item: RoadmapLesson) {
        guard completedLessonIDs.contains(item.id) || item.id == activeLessonID else { return }
        selectedRoadmapLesson = item
        prewarmAudio(for: item.lesson)
    }

    private func resumeStepIndex(for item: RoadmapLesson) -> Int {
        completedLessonIDs.contains(item.id) ? 0 : dependencies.lessonProgressStore.resumeStepIndex(for: item.lesson)
    }

    private func completeLesson(_ item: RoadmapLesson, feedback: SessionFeedback) {
        let alreadyCompleted = completedLessonIDs.contains(item.id)
        if alreadyCompleted {
            dependencies.lessonProgressStore.clear(for: item.id)
            return
        }
        let currentLevel = appState.profile.level
        let isGoalLesson = goalRows.contains { $0.id == item.id }
        let completesGoalStage = isGoalLesson
            && goalRows.filter { $0.stage == goalStage }.allSatisfy { row in
                completedLessonIDs.contains(row.id) || row.id == item.id
            }
        let completesCurrentRoadmap = isUsingAuthoritativeRoadmap
            && !roadmapLessons.isEmpty
            && roadmapLessons.allSatisfy { lesson in
                completedLessonIDs.contains(lesson.id) || lesson.id == item.id
            }
        dependencies.learningJourneyStore.recordCompletion(
            lesson: item.lesson,
            generatedLessonID: nil,
            feedback: feedback
        )
        dependencies.lessonProgressStore.clear(for: item.id)
        activity.reconcile(with: dependencies.learningJourneyStore.completedLessons)

        var updated = appState.profile
        updated.currentStreak = activity.currentStreak()
        updated.totalWordsLearned += 4
        appState.profile = updated
        shouldEvaluateAchievementsAfterLessonDismiss = true
        appState.scheduleCloudStateSync()
        if completesGoalStage {
            advanceGoalRoadmapIfNeeded()
        }

        Task { @MainActor in
            let promotedLevel: ProficiencyLevel?
            if completesCurrentRoadmap {
                promotedLevel = await appState.advanceRoadmapLevelIfComplete(
                    currentLevel: currentLevel,
                    roadmapLessonIDs: Set(roadmapLessons.map(\.id)),
                    completedLessonIDs: completedLessonIDs
                )
            } else {
                promotedLevel = nil
            }
            if promotedLevel == nil {
                try? await dependencies.profileRepository.saveProfile(appState.profile)
            } else {
                unlockedLevel = promotedLevel
            }
            prewarmNextLesson()
        }
    }

    private func dismissLesson() {
        selectedRoadmapLesson = nil
        prewarmNextLesson()
    }

    private func evaluateAchievementsAfterLessonDismiss() {
        defer { appState.reviewMomentReached() }
        guard shouldEvaluateAchievementsAfterLessonDismiss else { return }
        shouldEvaluateAchievementsAfterLessonDismiss = false
        appState.evaluateAchievements()
    }

    private func prewarmNextLesson() {
        guard let next = roadmapLessons.first(where: { !completedLessonIDs.contains($0.id) }) else { return }
        prewarmAudio(for: next.lesson)
    }

    private func advanceGoalRoadmapIfNeeded() {
        guard goalStage < 4 else { return }
        goalStage += 1
        appendGoalStage()
    }

    private func appendGoalStage() {
        let unitOrderOffset = roadmapLessons.map(\.unitOrder).max() ?? 0
        let nextLessons = GoalCurriculumSelection.roadmap(
            stage: goalStage,
            rows: goalRows,
            unitOrderOffset: unitOrderOffset
        )
        guard nextLessons.contains(where: { !completedLessonIDs.contains($0.id) }) else { return }
        roadmapLessons += nextLessons
    }

    private func prewarmAudio(for lesson: Lesson) {
        let audioService = dependencies.audioService
        let speed = AudioPreferences.speed(from: defaultSpeedRawValue)
        Task { await audioService.prewarm(lesson: lesson, speed: speed) }
    }
}

private struct RoadmapUnitSection: View {
    let unit: RoadmapUnit
    let completedLessonIDs: Set<UUID>
    let activeLessonID: UUID?
    let reduceMotion: Bool
    let onOpen: (RoadmapLesson) -> Void

    var body: some View {
        VStack(spacing: 24) {
            unitBanner.padding(.horizontal, 16)
            VStack(spacing: 24) {
                ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { localIndex, item in
                    let isCompleted = completedLessonIDs.contains(item.id)
                    let isActive = item.id == activeLessonID
                    ZStack {
                        RoadmapLessonButton(
                            item: item,
                            number: item.lessonOrder,
                            isCompleted: isCompleted,
                            isActive: isActive,
                            isUnitFinish: localIndex == unit.lessons.count - 1,
                            reduceMotion: reduceMotion,
                            action: { onOpen(item) }
                        )
                        .offset(x: RoadmapPathGeometry.horizontalOffset(for: localIndex))
                        .disabled(!isCompleted && !isActive)

                        if companionLessonIndex == localIndex {
                            RoadmapCompanion(
                                imageName: companionImageName,
                                sitsOnRight: companionSitsOnRight,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                    .id(item.id)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var unitBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L("UNIT %lld", unit.order))
                    .scaledFont(11, weight: .bold, design: .rounded)
                    .scaledTracking(1.25, forPointSize: 11)
                    .foregroundStyle(.white.opacity(0.78))
                Text(unit.title)
                    .scaledFont(21, weight: .bold, design: .rounded)
                    .scaledTracking(-0.35, forPointSize: 21)
                    .foregroundStyle(.white)
                Text(L("%lld of %lld lessons", completedCount, unit.lessons.count))
                    .scaledFont(12, weight: .semibold, design: .rounded)
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            ZStack {
                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 62, height: 62)
                BuddyMark(size: 58, mood: completedCount == unit.lessons.count ? .proud : .happy)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, minHeight: 102)
        .background(KumustaColors.accentPanel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(KumustaColors.accentShadow)
                .offset(y: 6)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }

    private var completedCount: Int {
        unit.lessons.filter { completedLessonIDs.contains($0.id) }.count
    }

    private var companionSitsOnRight: Bool { unit.order.isMultiple(of: 2) }
    private var companionLessonIndex: Int { companionSitsOnRight ? 4 : 2 }
    private var companionImageName: String {
        companionSitsOnRight ? "BuddyRoadmapCafe" : "BuddyRoadmapTraveler"
    }
}

private struct RoadmapCompanion: View {
    let imageName: String
    let sitsOnRight: Bool
    let reduceMotion: Bool

    @State private var isFloating = false

    var body: some View {
        HStack {
            if sitsOnRight { Spacer(minLength: 0) }

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 124)
                .rotationEffect(.degrees(sitsOnRight ? -2.5 : 2.5))
                .offset(y: isFloating ? -4 : 2)

            if !sitsOnRight { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

private struct RoadmapLessonButton: View {
    let item: RoadmapLesson
    let number: Int
    let isCompleted: Bool
    let isActive: Bool
    let isUnitFinish: Bool
    let reduceMotion: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 7) {
            if isActive { activeCallout }
            Button(action: action) {
                RoadmapNode(state: nodeState, symbol: nodeSymbol, number: number)
            }
            .buttonStyle(RoadmapNodeButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard isActive, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var activeCallout: some View {
        VStack(spacing: 3) {
            Text(L("START"))
                .scaledFont(10, weight: .heavy, design: .rounded)
                .scaledTracking(1.15, forPointSize: 10)
                .foregroundStyle(KumustaColors.accentDeep)
            Text(item.title)
                .scaledFont(13, weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .frame(maxWidth: 188)
        .background(KumustaColors.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .shadow(color: KumustaColors.line.opacity(0.22), radius: 6, y: 3)
        .scaleEffect(isPulsing ? 1.025 : 1)
    }

    private var nodeState: RoadmapNode.State {
        if isCompleted { return .completed }
        if isActive { return .active }
        return .locked
    }

    private var nodeSymbol: String {
        if isCompleted { return "star.fill" }
        if !isActive { return "lock.fill" }
        return isUnitFinish ? "flag.fill" : "arrow.right"
    }

    private var accessibilityLabel: String {
        if isCompleted { return L("Lesson %lld, %@, completed", number, item.title) }
        if isActive { return L("Start today’s lesson: %@", item.title) }
        return L("Lesson %lld, %@, locked", number, item.title)
    }

    private var accessibilityHint: String {
        if isCompleted { return L("Practice this lesson again") }
        if isActive { return L("Opens the next lesson on your path") }
        return L("Complete the previous lesson to unlock this one")
    }
}

private struct RoadmapNode: View {
    enum State { case completed, active, locked }
    let state: State
    let symbol: String
    let number: Int

    var body: some View {
        ZStack {
            Circle().fill(shadowColor).frame(width: 82, height: 82).offset(y: 8)
            Circle().fill(faceColor).frame(width: 82, height: 82)
            Circle().stroke(highlightColor, lineWidth: 4).frame(width: 68, height: 68).offset(y: -1)
            Image(systemName: symbol)
                .scaledFont(state == .locked ? 21 : 27, weight: .heavy)
                .foregroundStyle(symbolColor)
                .offset(x: symbol == "arrow.right" ? 2 : 0, y: -1)
        }
        .frame(width: 92, height: 94)
        .overlay(alignment: .bottomTrailing) {
            Text("\(number)")
                .scaledFont(10, weight: .heavy, design: .rounded)
                .foregroundStyle(state == .locked ? KumustaColors.muted : .white)
                .monospacedDigit()
                .frame(width: 25, height: 25)
                .background(numberBadgeColor, in: Circle())
                .overlay(Circle().stroke(KumustaColors.canvas, lineWidth: 3))
                .offset(x: 1, y: -3)
        }
    }

    private var faceColor: Color {
        switch state {
        case .completed: KumustaColors.accentSoft
        case .active: KumustaColors.accent
        case .locked: KumustaColors.surfaceStrong
        }
    }

    private var shadowColor: Color {
        switch state {
        case .completed: KumustaColors.accent
        case .active: KumustaColors.accentShadow
        case .locked: KumustaColors.line
        }
    }

    private var highlightColor: Color {
        switch state {
        case .completed: Color.white.opacity(0.32)
        case .active: Color.white.opacity(0.42)
        case .locked: Color.white.opacity(0.28)
        }
    }

    private var symbolColor: Color {
        switch state {
        case .completed: KumustaColors.accentDeep
        case .active: .white
        case .locked: KumustaColors.muted.opacity(0.76)
        }
    }

    private var numberBadgeColor: Color {
        state == .locked ? KumustaColors.surfaceMuted : KumustaColors.accentDeep
    }
}

private struct RoadmapNodeButtonStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(reduceMotion ? nil : KumustaMotion.press, value: configuration.isPressed)
    }
}

private enum RoadmapPathGeometry {
    static func horizontalOffset(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [-52, 14, 64, 14, -52]
        return pattern[index % pattern.count]
    }
}

private struct RoadmapUnit: Identifiable {
    let order: Int
    let title: String
    let lessons: [RoadmapLesson]
    var id: Int { order }
}

struct RoadmapLesson: Identifiable, Equatable {
    let lesson: Lesson
    let title: String
    let summary: String
    let unitTitle: String
    let unitOrder: Int
    let lessonOrder: Int
    var id: UUID { lesson.id }
}

enum RoadmapCatalog {
    static func load(
        level: ProficiencyLevel = .beginner,
        bundle: Bundle = .main
    ) throws -> [RoadmapLesson] {
        let catalog = "\(level.rawValue)-tagalog-v1"
        let catalogLevel = level.rawValue
        guard let url = bundle.url(forResource: catalog, withExtension: "json") else {
            throw RoadmapCatalogError.resourceMissing
        }
        let root = try JSONDecoder().decode(RoadmapCatalogRoot.self, from: Data(contentsOf: url))
        let lessons = root.lessons
            .filter { $0.level == catalogLevel }
            .sorted { $0.lessonOrder < $1.lessonOrder }
            .map { $0.makeRoadmapLesson() }
        guard !lessons.isEmpty else { throw RoadmapCatalogError.emptyCatalog }
        return lessons
    }

    static func fallback(
        level: ProficiencyLevel = .beginner
    ) -> [RoadmapLesson] {
        guard level == .beginner else { return [] }
        return SampleContent.lessonCatalog().enumerated().map { index, lesson in
            RoadmapLesson(
                lesson: lesson,
                title: lesson.scenario,
                summary: L("Build practical Tagalog you can use right away."),
                unitTitle: L("First conversations"),
                unitOrder: 1,
                lessonOrder: index + 1
            )
        }
    }
}

private enum RoadmapCatalogError: Error { case resourceMissing, emptyCatalog }

private struct RoadmapCatalogRoot: Decodable {
    let version: Int
    let roadmap: String
    let lessons: [RoadmapCatalogRow]
}

private struct RoadmapCatalogRow: Decodable {
    let id: UUID
    let summary: String
    let level: String
    let unitTitle: String
    let unitOrder: Int
    let lessonOrder: Int
    let content: RoadmapLessonContent
    /// The English title when the row shows a translation.
    var sourceTitle: String? = nil

    func makeRoadmapLesson() -> RoadmapLesson {
        let identifierNamespaceOffset = switch level {
        case "intermediate": 10
        case "advanced": 20
        default: 0
        }
        return RoadmapLesson(
            lesson: Lesson(
                id: id,
                scenario: content.title,
                minutes: content.minutes,
                steps: content.rounds.enumerated().flatMap { roundIndex, round in
                    round.makeSteps(
                        lessonOrder: lessonOrder,
                        roundIndex: roundIndex,
                        identifierNamespaceOffset: identifierNamespaceOffset
                    )
                },
                sourceScenario: sourceTitle
            ),
            title: content.title,
            summary: summary,
            unitTitle: unitTitle,
            unitOrder: unitOrder,
            lessonOrder: lessonOrder
        )
    }
}

struct RoadmapLessonContent: Decodable, Sendable {
    let title: String
    let minutes: Int
    let rounds: [RoadmapRound]
}

struct RoadmapRound: Decodable, Sendable {
    let situation: String
    let tagalog: String
    let translation: String
    let chunks: [RoadmapChunk]
    let wordGlosses: [RoadmapWordGloss]
    let speakingPrompt: String
    let responseExercise: RoadmapResponseExercise?

    func makeSteps(
        lessonOrder: Int,
        roundIndex: Int,
        identifierNamespaceOffset: Int,
        lessonID: UUID? = nil
    ) -> [LessonStep] {
        let mappedChunks = chunks.enumerated().map { index, chunk in
            PhraseChunk(
                id: RoadmapIdentifier.uuid(namespace: 43 + identifierNamespaceOffset, lessonOrder: lessonOrder, position: roundIndex * (lessonID == nil ? 10 : 100) + index + 1, lessonID: lessonID),
                tagalog: chunk.tagalog,
                english: chunk.english,
                note: chunk.note
            )
        }
        let mappedGlosses = wordGlosses.enumerated().map { index, gloss in
            LessonWordGloss(
                id: RoadmapIdentifier.uuid(namespace: 44 + identifierNamespaceOffset, lessonOrder: lessonOrder, position: roundIndex * (lessonID == nil ? 10 : 100) + index + 1, lessonID: lessonID),
                token: gloss.token,
                translation: gloss.english
            )
        }
        let mappedResponse = responseExercise?.makeExercise(
            lessonOrder: lessonOrder,
            roundIndex: roundIndex,
            identifierNamespaceOffset: identifierNamespaceOffset,
            lessonID: lessonID
        )
        let middleKind: LessonStepKind = mappedResponse == nil ? .decode : .hearRespond
        let stages: [(LessonStepKind, String)] = [
            (.coldListen, lessonID == nil ? L("Listen once. What is happening in this situation?") : situation),
            (middleKind, mappedResponse == nil ? L("Build the meaning from useful chunks.") : L("Listen and choose the meaning you heard.")),
            (.speak, speakingPrompt),
        ]
        return stages.enumerated().map { stageIndex, stage in
            LessonStep(
                id: RoadmapIdentifier.uuid(
                    namespace: 42 + identifierNamespaceOffset,
                    lessonOrder: lessonOrder,
                    position: roundIndex * LessonSessionPlan.stagesPerRound + stageIndex + 1,
                    lessonID: lessonID
                ),
                kind: stage.0,
                prompt: stage.1,
                tagalog: tagalog,
                translation: translation,
                chunks: mappedChunks,
                wordGlosses: mappedGlosses,
                hearRespond: stage.0 == .hearRespond ? mappedResponse : nil
            )
        }
    }
}

struct RoadmapChunk: Decodable, Sendable {
    let tagalog: String
    let english: String
    let note: String
}

struct RoadmapWordGloss: Decodable, Sendable {
    let token: String
    let english: String
}

struct RoadmapResponseExercise: Decodable, Sendable {
    let promptTagalog: String
    let promptTranslation: String
    let options: [RoadmapResponseOption]
    let correctOptionIndex: Int

    func makeExercise(
        lessonOrder: Int,
        roundIndex: Int,
        identifierNamespaceOffset: Int,
        lessonID: UUID? = nil
    ) -> HearRespondExercise? {
        guard options.indices.contains(correctOptionIndex) else { return nil }
        let mappedOptions = options.enumerated().map { index, option in
            HearRespondOption(
                id: RoadmapIdentifier.uuid(
                    namespace: 45 + identifierNamespaceOffset,
                    lessonOrder: lessonOrder,
                    position: roundIndex * 10 + index + 1,
                    lessonID: lessonID
                ),
                englishTranslation: option.englishTranslation
            )
        }
        return HearRespondExercise(
            promptTagalog: promptTagalog,
            promptTranslation: promptTranslation,
            options: mappedOptions,
            correctOptionID: mappedOptions[correctOptionIndex].id
        )
    }
}

struct RoadmapResponseOption: Decodable, Sendable {
    let englishTranslation: String
}

private enum RoadmapIdentifier {
    static func uuid(namespace: Int, lessonOrder: Int, position: Int, lessonID: UUID? = nil) -> UUID {
        if let lessonID {
            let digest = SHA256.hash(data: Data("\(lessonID.uuidString):\(namespace):\(position)".utf8))
            let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
            let characters = Array(hex)
            let value = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32]
                .map { String(characters[$0]) }.joined(separator: "-")
            return UUID(uuidString: value)!
        }
        let value = String(
            format: "%02d000000-0000-4000-%04d-%012d",
            namespace,
            8100,
            lessonOrder * 1_000 + position
        )
        return UUID(uuidString: value)!
    }
}

enum GoalCurriculumError: Error { case unavailable, incomplete }

protocol GoalCurriculumProviding: Sendable {
    func lessons(goal: LearningGoal) async throws -> [GoalCurriculumRow]
}

struct PreviewGoalCurriculum: GoalCurriculumProviding {
    func lessons(goal: LearningGoal) async throws -> [GoalCurriculumRow] {
        // Deterministic bundled fixtures keep previews and UI tests offline.
        // Four goal stages from the three authored levels; advanced fills the last two.
        let resources = ["beginner-tagalog-v1", "intermediate-tagalog-v1", "advanced-tagalog-v1", "advanced-tagalog-v1"]
        return try resources.enumerated().flatMap { stage, resource in
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
                throw GoalCurriculumError.unavailable
            }
            let root = try JSONDecoder().decode(RoadmapCatalogRoot.self, from: Data(contentsOf: url))
            return root.lessons
                .sorted { $0.lessonOrder < $1.lessonOrder }.prefix(10).enumerated().map { index, row in
                    GoalCurriculumRow(id: RoadmapIdentifier.uuid(namespace: 91,
                        lessonOrder: stage * 10 + index + 1, position: 1), goal: goal, stage: stage + 1,
                        lessonOrder: index + 1, title: row.content.title,
                        summary: row.summary, content: row.content)
                }
        }
    }
}

actor SupabaseGoalCurriculum: GoalCurriculumProviding {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func lessons(goal: LearningGoal) async throws -> [GoalCurriculumRow] {
        try await sourceLessons(goal: goal)
    }

    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("goal-curriculum-v1", isDirectory: true)
    }

    private func sourceLessons(goal: LearningGoal) async throws -> [GoalCurriculumRow] {
        let cacheDirectory = Self.cacheDirectory
        let cacheURL = cacheDirectory.appendingPathComponent("\(goal.rawValue).json")
        do {
            let data = try await client.from("kumusta_goal_lessons")
                .select("id,goal,stage,lesson_order,title,summary,content")
                .eq("curriculum_version", value: "goals-v1")
                .eq("goal", value: goal.rawValue)
                .eq("is_published", value: true)
                .order("stage").order("lesson_order")
                .execute().data
            let rows = try JSONDecoder().decode([GoalCurriculumRow].self, from: data)
            try GoalCurriculumSelection.validate(rows, goal: goal)
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
            return rows
        } catch {
            try Task.checkCancellation()
            if let data = try? Data(contentsOf: cacheURL),
               let rows = try? JSONDecoder().decode([GoalCurriculumRow].self, from: data),
               (try? GoalCurriculumSelection.validate(rows, goal: goal)) != nil {
                return rows
            }
            throw error
        }
    }
}

struct GoalCurriculumRow: Decodable, Sendable {
    let id: UUID
    let goal: LearningGoal
    let stage: Int
    let lessonOrder: Int
    let title: String
    let summary: String
    let content: RoadmapLessonContent
    /// The English title when the row shows a translation (not decoded).
    var sourceTitle: String? = nil
    enum CodingKeys: String, CodingKey {
        case id, goal, stage, title, summary, content
        case lessonOrder = "lesson_order"
    }
    func makeLesson(unitOrderOffset: Int = 0) -> RoadmapLesson {
        RoadmapLesson(
            lesson: Lesson(id: id, scenario: title, minutes: content.minutes,
                steps: content.rounds.enumerated().flatMap { index, round in
                    round.makeSteps(lessonOrder: lessonOrder, roundIndex: index,
                                    identifierNamespaceOffset: 0, lessonID: id)
                }, sourceScenario: sourceTitle),
            title: title, summary: summary,
            unitTitle: lessonOrder <= 5 ? L("Find your voice") : L("Make it your own"),
            unitOrder: unitOrderOffset + (lessonOrder <= 5 ? 1 : 2), lessonOrder: lessonOrder
        )
    }
}

enum GoalCurriculumSelection {
    static func supports(_ goal: LearningGoal) -> Bool {
        [.lifeInThePhilippines, .family, .partner, .travel].contains(goal)
    }
    static func title(_ goal: LearningGoal) -> String {
        switch goal {
        case .lifeInThePhilippines: L("Make daily life feel like home")
        case .family: L("Speak naturally with family")
        case .partner: L("Share more of your partner’s world")
        case .travel: L("Travel with confidence")
        default: goal.title
        }
    }
    static func stageTitle(_ stage: Int) -> String {
        switch stage {
        case 1: L("Beginner")
        case 2: L("Elementary")
        case 3: L("Intermediate")
        default: L("Advanced")
        }
    }

    static func roadmap(
        stage: Int,
        rows: [GoalCurriculumRow],
        unitOrderOffset: Int = 0
    ) -> [RoadmapLesson] {
        rows
            .filter { $0.stage == stage }
            .sorted { $0.lessonOrder < $1.lessonOrder }
            .map { $0.makeLesson(unitOrderOffset: unitOrderOffset) }
    }

    static func recommendedStage(level: ProficiencyLevel, rows: [GoalCurriculumRow], completed: Set<UUID>) -> Int {
        let entry: Int = switch level { case .beginner: 1; case .intermediate: 2; case .advanced: 3 }
        for stage in entry...4 {
            let lessons = rows.filter { $0.stage == stage }
            if lessons.count != 10 || lessons.contains(where: { !completed.contains($0.id) }) { return stage }
        }
        return 4
    }
    static func validate(_ rows: [GoalCurriculumRow], goal: LearningGoal) throws {
        guard rows.count == 40, Set(rows.map(\.id)).count == 40,
              rows.allSatisfy({ $0.goal == goal }) else { throw GoalCurriculumError.incomplete }
        for stage in 1...4 {
            let lessons = rows.filter { $0.stage == stage }
            guard Set(lessons.map(\.lessonOrder)) == Set(1...10), lessons.count == 10 else { throw GoalCurriculumError.incomplete }
            for row in lessons {
                guard row.content.rounds.count == 5, row.content.minutes == 5 else { throw GoalCurriculumError.incomplete }
                let steps = row.makeLesson().lesson.steps
                guard steps.count == 15, steps.filter({ $0.kind == .hearRespond }).count == 2,
                      steps.filter({ $0.kind == .decode }).count == 3,
                      steps.filter({ $0.kind == .speak }).count == 5 else { throw GoalCurriculumError.incomplete }
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(AppState(dependencies: .preview()))
        .environment(DependencyContainer.preview())
        .environment(AppNavigation())
}
