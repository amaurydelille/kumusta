import Foundation
import OSLog

/// A transcription that listens while the learner is still speaking, so the
/// result is ready almost as soon as they stop.
protocol LiveSpeechTranscribing: AnyObject, Sendable {
    /// 16 kHz mono little-endian PCM16. Called on the audio capture thread.
    func append(_ pcm: Data)
    /// Ends the take and returns its transcript.
    func finish() async throws -> SpeechTranscription
    func cancel()
}

struct RealtimeSpeechGrant: Decodable, Sendable {
    let version: Int
    let url: URL
    let sampleRate: Int

    static let sampleRate = 16_000

    /// The backend owns the session URL; only accept one that points at
    /// ElevenLabs over TLS and expects the audio the recorder produces.
    var isValid: Bool {
        version == 1
            && sampleRate == Self.sampleRate
            && url.scheme == "wss"
            && (url.host() == "api.elevenlabs.io" || url.host()?.hasSuffix(".elevenlabs.io") == true)
    }
}

/// Streams one take to ElevenLabs realtime Scribe over a single-use session.
/// Audio is buffered until the socket is open, so capture never waits for the
/// grant. The session commits once, when the take ends.
final class ElevenLabsRealtimeTranscription: LiveSpeechTranscribing {
    /// How long `finish()` waits for the committed transcript before giving up,
    /// so a slow stream falls back to the upload path instead of stalling.
    static let finishTimeout: Duration = .milliseconds(2_500)
    private static let logger = Logger(subsystem: "com.kumusta.app", category: "SpeechRecognition")

    private let continuation: AsyncStream<Data>.Continuation
    private let result: Task<SpeechTranscription, Error>

    init(
        session: URLSession = .shared,
        grant: @escaping @Sendable () async throws -> RealtimeSpeechGrant
    ) {
        let (chunks, continuation) = AsyncStream.makeStream(of: Data.self)
        self.continuation = continuation
        result = Task {
            do {
                return try await Self.run(session: session, grant: grant, chunks: chunks)
            } catch {
                // Stop buffering audio nobody will send.
                continuation.finish()
                throw error
            }
        }
    }

    func append(_ pcm: Data) {
        continuation.yield(pcm)
    }

    func finish() async throws -> SpeechTranscription {
        continuation.finish()
        let result = result
        return try await withThrowingTaskGroup(of: SpeechTranscription.self) { group in
            group.addTask { try await result.value }
            group.addTask {
                try await Task.sleep(for: Self.finishTimeout)
                Self.logger.notice("Realtime transcript timed out")
                throw SpeechRecognitionError.temporarilyUnavailable
            }
            defer {
                group.cancelAll()
                result.cancel()
            }
            return try await group.next()!
        }
    }

    func cancel() {
        continuation.finish()
        result.cancel()
    }

    private static func run(
        session: URLSession,
        grant: @Sendable () async throws -> RealtimeSpeechGrant,
        chunks: AsyncStream<Data>
    ) async throws -> SpeechTranscription {
        let grant = try await grant()
        guard grant.isValid else { throw SpeechRecognitionError.responseInvalid }

        let socket = session.webSocketTask(with: grant.url)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        return try await withThrowingTaskGroup(of: SpeechTranscription?.self) { group in
            group.addTask {
                for await chunk in chunks {
                    try await socket.send(.string(audioMessage(chunk, commit: false)))
                }
                // A short tail of silence lets the final syllable settle
                // before the commit closes the segment.
                let tail = Data(count: RealtimeSpeechGrant.sampleRate / 10 * 2)
                try await socket.send(.string(audioMessage(tail, commit: true)))
                return nil
            }
            group.addTask {
                try await committedTranscript(from: socket)
            }
            defer { group.cancelAll() }
            while let next = try await group.next() {
                if let transcription = next { return transcription }
            }
            throw SpeechRecognitionError.temporarilyUnavailable
        }
    }

    private static func committedTranscript(
        from socket: URLSessionWebSocketTask
    ) async throws -> SpeechTranscription {
        while true {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default: continue
            }
            guard let event = try? JSONDecoder().decode(RealtimeEvent.self, from: data) else {
                continue
            }
            switch event.messageType {
            case "session_started", "partial_transcript", "warning":
                continue
            case "committed_transcript":
                return try transcription(from: event.text ?? "")
            case "insufficient_audio_activity":
                throw SpeechRecognitionError.speechNotDetected
            default:
                if event.error != nil {
                    logger.error("Realtime transcription failed: \(event.messageType, privacy: .public)")
                    throw SpeechRecognitionError.temporarilyUnavailable
                }
            }
        }
    }

    /// Mirrors the upload path's server-side normalization and bounds.
    static func transcription(from text: String) throws -> SpeechTranscription {
        let transcript = text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !transcript.isEmpty else { throw SpeechRecognitionError.speechNotDetected }
        guard transcript.count <= 500 else { throw SpeechRecognitionError.responseInvalid }
        return SpeechTranscription(
            version: 1,
            transcript: transcript,
            languageCode: "fil",
            languageProbability: nil,
            words: []
        )
    }

    private static func audioMessage(_ pcm: Data, commit: Bool) -> String {
        "{\"message_type\":\"input_audio_chunk\",\"audio_base_64\":\"\(pcm.base64EncodedString())\","
            + "\"commit\":\(commit),\"sample_rate\":\(RealtimeSpeechGrant.sampleRate)}"
    }

    private struct RealtimeEvent: Decodable {
        let messageType: String
        let text: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case text, error
            case messageType = "message_type"
        }
    }
}

extension TagalogSpeechRecognizing {
    /// Prefers the transcript streamed during the take and uploads the take
    /// only when the stream cannot deliver. Access errors surface directly so
    /// the same gate is not spent twice.
    func transcribe(
        audio: Data,
        live: (any LiveSpeechTranscribing)?,
        onboarding: Bool = false
    ) async throws -> SpeechTranscription {
        if let live {
            do {
                return try await live.finish()
            } catch let error as SpeechRecognitionError
                where [.authenticationRequired, .premiumRequired, .rateLimited].contains(error) {
                throw error
            } catch {
                try Task.checkCancellation()
                Logger(subsystem: "com.kumusta.app", category: "SpeechRecognition")
                    .notice("Realtime transcript unavailable; uploading the take")
            }
        }
        return onboarding
            ? try await transcribeOnboarding(audio: audio)
            : try await transcribe(audio: audio)
    }
}
