import Foundation
import Observation

struct LessonProgressRecord: Codable, Equatable, Sendable {
    let lessonID: UUID
    let nextStepIndex: Int
    let totalSteps: Int
    let updatedAt: Date
}

@MainActor
@Observable
final class LessonProgressStore {
    static let storageKey = "kumusta.lesson-progress.v1"
    static let maximumRecordCount = 100

    private let defaults: UserDefaults
    private(set) var records: [UUID: LessonProgressRecord]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([LessonProgressRecord].self, from: data)
        else {
            records = [:]
            return
        }
        records = Dictionary(
            uniqueKeysWithValues: decoded
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(Self.maximumRecordCount)
                .map { ($0.lessonID, $0) }
        )
    }

    func resumeStepIndex(for lesson: Lesson, minimum: Int = 0) -> Int {
        let boundedMinimum = max(0, min(minimum, lesson.steps.count))
        guard let record = records[lesson.id], record.totalSteps == lesson.steps.count else {
            return boundedMinimum
        }
        return max(boundedMinimum, min(record.nextStepIndex, lesson.steps.count))
    }

    func save(nextStepIndex: Int, for lesson: Lesson, updatedAt: Date = .now) {
        let boundedIndex = max(0, min(nextStepIndex, lesson.steps.count))
        guard boundedIndex > 0 else {
            clear(for: lesson.id)
            return
        }
        records[lesson.id] = LessonProgressRecord(
            lessonID: lesson.id,
            nextStepIndex: boundedIndex,
            totalSteps: lesson.steps.count,
            updatedAt: updatedAt
        )
        trimAndPersist()
    }

    func clear(for lessonID: UUID) {
        guard records.removeValue(forKey: lessonID) != nil else { return }
        persist()
    }

    func snapshot() -> [LessonProgressRecord] {
        records.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func replace(with records: [LessonProgressRecord]) {
        self.records = Dictionary(
            uniqueKeysWithValues: records
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(Self.maximumRecordCount)
                .map { ($0.lessonID, $0) }
        )
        persist()
    }

    func reset() {
        records = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func trimAndPersist() {
        if records.count > Self.maximumRecordCount {
            let retainedIDs = Set(
                records.values
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .prefix(Self.maximumRecordCount)
                    .map(\.lessonID)
            )
            records = records.filter { retainedIDs.contains($0.key) }
        }
        persist()
    }

    private func persist() {
        let ordered = records.values.sorted { $0.updatedAt > $1.updatedAt }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
