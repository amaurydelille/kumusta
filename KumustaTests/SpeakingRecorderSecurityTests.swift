import AVFoundation
import Foundation
import Testing
@testable import Kumusta

@MainActor
@Suite("Local speaking recording security")
struct SpeakingRecorderSecurityTests {
    @Test("Every recording uses a random temporary filename")
    func randomRecordingURLs() {
        let first = SpeakingRecorder.makeRecordingURL()
        let second = SpeakingRecorder.makeRecordingURL()

        #expect(first != second)
        #expect(first.lastPathComponent.hasPrefix("kumusta-speaking-rep-"))
        #expect(first.pathExtension == "m4a")
    }

    @Test("Creating another recorder never deletes an existing take")
    func recorderInitializationDoesNotScrubTakes() throws {
        let take = SpeakingRecorder.makeRecordingURL()
        try Data(repeating: 0x01, count: 1_024).write(to: take)
        defer { try? FileManager.default.removeItem(at: take) }

        _ = SpeakingRecorder()

        #expect(FileManager.default.fileExists(atPath: take.path))
    }

    @Test("Abandoned recording scrub leaves unrelated files alone")
    func scrubOnlyKumustaRecordings() throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "KumustaRecorderTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let abandoned = SpeakingRecorder.makeRecordingURL(in: directory)
        let unrelated = directory.appending(path: "keep-me.m4a")
        try Data([0x01]).write(to: abandoned)
        try Data([0x02]).write(to: unrelated)

        SpeakingRecorder.scrubAbandonedRecordings(in: directory)

        #expect(!FileManager.default.fileExists(atPath: abandoned.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @Test("A completed take stays available after its temporary file is removed")
    func snapshotsRecordingDataBeforeCleanup() throws {
        let source = SpeakingRecorder.makeRecordingURL()
        let expected = Data(repeating: 0x01, count: 1_024)
        try expected.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let snapshot = SpeakingRecorder.snapshotRecordingData(from: source)
        try FileManager.default.removeItem(at: source)

        #expect(snapshot == expected)
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }

    /// Drives a real take through the audio engine. The tap runs on the audio
    /// thread, so an accidental main-actor closure there traps immediately.
    /// Skipped when the host has no microphone access.
    @Test("A real take is captured on the audio thread and saved")
    func capturesARealTake() async throws {
        guard AVAudioApplication.shared.recordPermission == .granted else { return }
        let recorder = SpeakingRecorder()
        defer { recorder.cleanup() }
        let live = RecordingLiveTranscription()

        recorder.toggleRecording(streamingTo: LiveOnlySpeechService(live: live))
        #expect(recorder.isRecording, "\(recorder.errorMessage ?? "")")
        try await Task.sleep(for: .milliseconds(900))
        recorder.stopRecording()

        #expect(!recorder.isRecording)
        #expect(recorder.hasRecording, "\(recorder.errorMessage ?? "")")
        #expect(try recorder.recordingData().count > 512)
        #expect(live.receivedBytes > 16_000)
    }
}

private final class RecordingLiveTranscription: LiveSpeechTranscribing, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = 0

    var receivedBytes: Int { lock.withLock { bytes } }

    func append(_ pcm: Data) {
        lock.withLock { bytes += pcm.count }
    }

    func finish() async throws -> SpeechTranscription {
        throw SpeechRecognitionError.temporarilyUnavailable
    }

    func cancel() {}
}

private struct LiveOnlySpeechService: TagalogSpeechRecognizing {
    let live: RecordingLiveTranscription

    func transcribe(audio: Data) async throws -> SpeechTranscription {
        throw SpeechRecognitionError.temporarilyUnavailable
    }

    func makeLiveTranscription(onboarding: Bool) -> (any LiveSpeechTranscribing)? {
        live
    }
}
