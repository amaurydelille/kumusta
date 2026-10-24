import Foundation
import Observation
import OSLog

enum CompletedLessonSource: String, Codable, Sendable {
    case authored
    case generated
}

struct CompletedLessonRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let lesson: Lesson
    let generatedLessonID: UUID?
    let source: CompletedLessonSource
    let completedAt: Date
    let difficultyFeedback: LessonDifficultyFeedback
    let paceFeedback: AudioPaceFeedback
    let requestedNextTopic: String?
}

struct PendingLessonPreparation: Codable, Equatable, Sendable {
    let completedLessonID: UUID
    let requestedTopic: String?
    let requestedAt: Date
    var requiresFreshGeneration: Bool? = nil
}

struct LearningJourneySnapshot: Codable, Equatable, Sendable {
    let completedLessons: [CompletedLessonRecord]
    let pendingPreparation: PendingLessonPreparation?
    var completedLessonIDs: Set<UUID>? = nil
}

@MainActor
@Observable
final class LearningJourneyStore {
    enum PreparationPhase: Equatable, Sendable {
        case idle
        case generating
        case waitingInBackground
        case failed
    }

    static let historyStorageKey = "kumusta.completed-lessons.v1"
    static let pendingStorageKey = "kumusta.pending-next-lesson.v1"
    static let completionIDsStorageKey = "kumusta.completed-lesson-ids.v1"
    static let maximumHistoryCount = 100
    static let maximumPreparationAge: TimeInterval = 180

    private let logger = Logger(subsystem: "com.kumusta.app", category: "lesson-history")
    private let defaults: UserDefaults
    private let historyFileURL: URL
    private(set) var completedLessons: [CompletedLessonRecord]
    private(set) var completedLessonIDs: Set<UUID> = []
    private(set) var pendingPreparation: PendingLessonPreparation?
    private(set) var preparedContent: PersonalizedLearningContent?
    private(set) var preparationPhase: PreparationPhase
    private(set) var preparationErrorMessage: String?
    private(set) var preparationFailure: PersonalizedLearningError?
    private var isPolling = false
    private var onLessonCompleted: (@MainActor (CompletedLessonRecord) -> Void)?

    init(defaults: UserDefaults = .standard, historyFileURL: URL? = nil) {
        self.defaults = defaults
        self.historyFileURL = historyFileURL ?? Self.defaultHistoryFileURL()

        let fileData = try? Data(contentsOf: self.historyFileURL)
        let legacyData = defaults.data(forKey: Self.historyStorageKey)
        if let data = fileData ?? legacyData,
           let decoded = try? JSONDecoder().decode([CompletedLessonRecord].self, from: data) {
            completedLessons = decoded
                .sorted { $0.completedAt > $1.completedAt }
                .prefix(Self.maximumHistoryCount)
                .map(\.self)
        } else {
            completedLessons = []
        }

        if let data = defaults.data(forKey: Self.pendingStorageKey),
           let decoded = try? JSONDecoder().decode(PendingLessonPreparation.self, from: data),
           !Self.isExpired(decoded, at: .now) {
            pendingPreparation = decoded
            preparationPhase = .waitingInBackground
        } else {
            pendingPreparation = nil
            preparationPhase = .idle
            defaults.removeObject(forKey: Self.pendingStorageKey)
        }
        preparationErrorMessage = nil
        preparationFailure = nil

        if let data = defaults.data(forKey: Self.completionIDsStorageKey),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            completedLessonIDs = ids
        }
        completedLessonIDs.formUnion(completedLessons.map(\.lesson.id))

        // Migrate the early UserDefaults prototype into an atomic Application
        // Support document. Full lessons are intentionally not kept in prefs.
        if fileData == nil, legacyData != nil {
            persistHistory()
            defaults.removeObject(forKey: Self.historyStorageKey)
        }
    }

    var isPreparingNextLesson: Bool { pendingPreparation != nil }
    var requestedTopic: String? { pendingPreparation?.requestedTopic }
    var preparedLessonID: UUID? { preparedContent?.lesson.id }

    func snapshot() -> LearningJourneySnapshot {
        LearningJourneySnapshot(
            completedLessons: completedLessons,
            pendingPreparation: pendingPreparation,
            completedLessonIDs: completedLessonIDs
        )
    }

    func replace(with snapshot: LearningJourneySnapshot) {
        completedLessonIDs = snapshot.completedLessonIDs ?? Set(snapshot.completedLessons.map(\.lesson.id))
        completedLessonIDs.formUnion(snapshot.completedLessons.map(\.lesson.id))
        completedLessons = snapshot.completedLessons
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(Self.maximumHistoryCount)
            .map(\.self)
        pendingPreparation = snapshot.pendingPreparation.flatMap {
            Self.isExpired($0, at: .now) ? nil : $0
        }
        preparedContent = nil
        preparationPhase = pendingPreparation == nil ? .idle : .waitingInBackground
        preparationErrorMessage = nil
        preparationFailure = nil
        persistHistory()
        persistPendingPreparation()
    }

    func isLessonCompleted(
        _ lesson: Lesson,
        generatedLessonID: UUID?,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        completedLessons.contains { record in
            if let generatedLessonID {
                return record.generatedLessonID == generatedLessonID
            }
            return record.generatedLessonID == nil &&
                record.lesson.id == lesson.id &&
                calendar.isDate(record.completedAt, inSameDayAs: date)
        }
    }

    func recordCompletion(
        lesson: Lesson,
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        completedAt: Date = .now
    ) {
        // A generated lesson is a unique curriculum object. Replaying it from
        // history must not create duplicate library entries.
        if let generatedLessonID,
           completedLessons.contains(where: { $0.generatedLessonID == generatedLessonID }) {
            return
        }

        let record = CompletedLessonRecord(
            id: UUID(),
            lesson: lesson,
            generatedLessonID: generatedLessonID,
            source: generatedLessonID == nil ? .authored : .generated,
            completedAt: completedAt,
            difficultyFeedback: feedback.difficulty,
            paceFeedback: feedback.audioPace,
            requestedNextTopic: feedback.nextLessonTopic
        )
        completedLessons.insert(record, at: 0)
        completedLessonIDs.insert(lesson.id)
        if completedLessons.count > Self.maximumHistoryCount {
            completedLessons.removeLast(completedLessons.count - Self.maximumHistoryCount)
        }
        persistHistory()
        onLessonCompleted?(record)
    }

    /// Lets the memory deck enroll a lesson's phrases the moment it is
    /// finished, from every screen that records completions.
    func configureCompletionObserver(
        _ handler: @escaping @MainActor (CompletedLessonRecord) -> Void
    ) {
        onLessonCompleted = handler
    }

    func beginPreparingNextLesson(
        after completedLessonID: UUID,
        requestedTopic: String?,
        requestedAt: Date = .now,
        requiresFreshGeneration: Bool = false
    ) {
        pendingPreparation = PendingLessonPreparation(
            completedLessonID: completedLessonID,
            requestedTopic: requestedTopic,
            requestedAt: requestedAt,
            requiresFreshGeneration: requiresFreshGeneration
        )
        preparedContent = nil
        preparationPhase = .generating
        preparationErrorMessage = nil
        preparationFailure = nil
        persistPendingPreparation()
    }

    func failPendingPreparation(with error: Error) {
        guard pendingPreparation != nil else { return }
        let failure = (error as? PersonalizedLearningError) ?? .requestRejected
        preparationPhase = .failed
        preparationErrorMessage = failure.localizedDescription
        preparationFailure = failure
        persistPendingPreparation()
    }

    func pollForPreparedLesson(
        using service: any PersonalizedLearningProviding,
        profile: UserProfile,
        // Covers one normal provider call, bounded exceptional recovery, and
        // request overhead, so a successful background lesson replaces the
        // preparation card without requiring a manual refresh.
        maximumAttempts: Int = 60
    ) async {
        guard pendingPreparation != nil, !isPolling, preparationPhase != .failed else { return }
        if abandonExpiredPreparation() { return }
        isPolling = true
        preparationPhase = .generating
        preparationErrorMessage = nil
        preparationFailure = nil
        defer { isPolling = false }

        for attempt in 0..<maximumAttempts {
            guard !Task.isCancelled, let pendingPreparation else { return }
            if abandonExpiredPreparation() { return }
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if abandonExpiredPreparation() { return }
            }

            do {
                if let content = try await service.preparedContent(
                    for: profile,
                    after: pendingPreparation.completedLessonID,
                    generatedAfter: pendingPreparation.requiresFreshGeneration == true ? pendingPreparation.requestedAt : nil,
                    requestedTopic: pendingPreparation.requestedTopic,
                    retry: false
                ),
                   shouldAccept(content, for: pendingPreparation) {
                    preparedContent = content
                    self.pendingPreparation = nil
                    preparationPhase = .idle
                    persistPendingPreparation()
                    return
                }
            } catch let error as PersonalizedLearningError {
                switch error {
                case .requestRejected, .generationFailed, .generationDailyLimit, .generationPacingLimit:
                    failPendingPreparation(with: error)
                    return
                case .invalidResponse:
                    break
                }
            } catch {
                // A generation request is durable on the backend and the
                // client completion is durable in its outbox. Polling may
                // continue through transient network/provider failures.
            }
        }

        guard !Task.isCancelled else { return }
        failPendingPreparation(with: PersonalizedLearningError.generationFailed)
    }

    func retryPreparedLesson(
        using service: any PersonalizedLearningProviding,
        profile: UserProfile
    ) async {
        guard let pendingPreparation, !isPolling else { return }
        isPolling = true
        preparationPhase = .generating
        preparationErrorMessage = nil
        preparationFailure = nil
        do {
            self.pendingPreparation = PendingLessonPreparation(
                completedLessonID: pendingPreparation.completedLessonID,
                requestedTopic: pendingPreparation.requestedTopic,
                requestedAt: .now,
                requiresFreshGeneration: pendingPreparation.requiresFreshGeneration
            )
            persistPendingPreparation()
            if let content = try await service.preparedContent(
                for: profile,
                after: pendingPreparation.completedLessonID,
                generatedAfter: pendingPreparation.requiresFreshGeneration == true ? pendingPreparation.requestedAt : nil,
                requestedTopic: pendingPreparation.requestedTopic,
                retry: true
            ),
               shouldAccept(content, for: pendingPreparation) {
                preparedContent = content
                self.pendingPreparation = nil
                preparationPhase = .idle
                persistPendingPreparation()
                isPolling = false
                return
            }
        } catch let error as PersonalizedLearningError {
            switch error {
            case .requestRejected, .generationFailed, .generationDailyLimit, .generationPacingLimit:
                failPendingPreparation(with: error)
                isPolling = false
                return
            case .invalidResponse:
                break
            }
        } catch {
            // The retry may have been accepted before the connection closed.
            // Continue with the normal bounded status polling below.
        }
        isPolling = false
        await pollForPreparedLesson(using: service, profile: profile)
    }

    func consumePreparedContent() -> PersonalizedLearningContent? {
        preparedContent
    }

    @discardableResult
    func abandonExpiredPreparation(now: Date = .now) -> Bool {
        guard let pendingPreparation,
              Self.isExpired(pendingPreparation, at: now) else { return false }
        failPendingPreparation(with: PersonalizedLearningError.generationFailed)
        return true
    }

    func abandonPendingPreparation() {
        guard pendingPreparation != nil || preparedContent != nil else { return }
        pendingPreparation = nil
        preparedContent = nil
        preparationPhase = .idle
        preparationErrorMessage = nil
        preparationFailure = nil
        persistPendingPreparation()
    }

    func reset() {
        completedLessons = []
        completedLessonIDs = []
        defaults.removeObject(forKey: Self.completionIDsStorageKey)
        pendingPreparation = nil
        preparedContent = nil
        preparationPhase = .idle
        preparationErrorMessage = nil
        preparationFailure = nil
        defaults.removeObject(forKey: Self.pendingStorageKey)
        try? FileManager.default.removeItem(at: historyFileURL)
    }

    private func shouldAccept(
        _ content: PersonalizedLearningContent,
        for pending: PendingLessonPreparation
    ) -> Bool {
        guard content.lesson.id != pending.completedLessonID else { return false }
        // An explicit request must not be satisfied by an older generic queue
        // entry. Topic generations are delivered through the server priority
        // lane and carry a positive queue priority.
        if pending.requestedTopic != nil {
            return content.deliveryPriority > 0
        }
        return true
    }

    private func persistHistory() {
        if let ids = try? JSONEncoder().encode(completedLessonIDs) {
            defaults.set(ids, forKey: Self.completionIDsStorageKey)
        }
        guard let data = try? JSONEncoder().encode(completedLessons) else { return }
        do {
            try FileManager.default.createDirectory(
                at: historyFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: historyFileURL, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Could not persist lesson history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistPendingPreparation() {
        guard let pendingPreparation else {
            defaults.removeObject(forKey: Self.pendingStorageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(pendingPreparation) else { return }
        defaults.set(data, forKey: Self.pendingStorageKey)
    }

    private static func isExpired(
        _ preparation: PendingLessonPreparation,
        at date: Date
    ) -> Bool {
        date.timeIntervalSince(preparation.requestedAt) >= maximumPreparationAge
    }

    private static func defaultHistoryFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Kumusta", isDirectory: true)
            .appendingPathComponent("completed-lessons-v1.json", isDirectory: false)
    }
}
