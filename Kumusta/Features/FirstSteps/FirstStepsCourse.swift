import Foundation
import Observation

enum FirstStepsCourseStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case skipped
    case completed
}

struct FirstStepsCourseSnapshot: Codable, Equatable, Sendable {
    let status: FirstStepsCourseStatus
    let offerSeen: Bool
    let completedActivityIDs: Set<String>
}

@MainActor
@Observable
final class FirstStepsCourseStore {

    static let courseID = "first-lesson-v1"
    private static let storageKey = "kumusta.first-steps.progress.v1"

    private let defaults: UserDefaults

    private(set) var status: FirstStepsCourseStatus
    private(set) var offerSeen: Bool
    /// Kept for cloud-sync compatibility; holds the finished lesson's ID.
    private(set) var completedActivityIDs: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Self.storageKey),
            let state = try? JSONDecoder().decode(FirstStepsCourseSnapshot.self, from: data)
        {
            status = state.status
            offerSeen = state.offerSeen
            completedActivityIDs = state.completedActivityIDs
        } else {
            status = .notStarted
            offerSeen = false
            completedActivityIDs = []
        }
    }

    var shouldOffer: Bool {
        status == .notStarted && !offerSeen
    }

    /// True only once the guided first lesson is finished. Learners who
    /// "completed" the earlier cheat-sheet version still get the lesson.
    var hasCompletedLesson: Bool {
        status == .completed && completedActivityIDs.contains(Self.courseID)
    }

    /// The status to show, with the old cheat-sheet completion treated as
    /// not yet started.
    var lessonStatus: FirstStepsCourseStatus {
        if hasCompletedLesson { return .completed }
        return status == .inProgress ? .inProgress : .notStarted
    }

    func snapshot() -> FirstStepsCourseSnapshot {
        FirstStepsCourseSnapshot(
            status: status,
            offerSeen: offerSeen,
            completedActivityIDs: completedActivityIDs
        )
    }

    func replace(with snapshot: FirstStepsCourseSnapshot) {
        status = snapshot.status
        offerSeen = snapshot.offerSeen
        completedActivityIDs = snapshot.completedActivityIDs
        persist()
    }

    func markOfferSeen() {
        offerSeen = true
        persist()
    }

    func start() {
        offerSeen = true
        if !hasCompletedLesson {
            status = .inProgress
        }
        persist()
    }

    func complete() {
        offerSeen = true
        status = .completed
        completedActivityIDs.insert(Self.courseID)
        persist()
    }

    func skip() {
        offerSeen = true
        status = .skipped
        persist()
    }

    func reset() {
        status = .notStarted
        offerSeen = false
        completedActivityIDs = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
