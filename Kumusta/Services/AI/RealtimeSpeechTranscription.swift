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
    let provider: String
    let url: URL
    /// A short-lived, single-use provider key.
    let token: String
    /// The server-owned start request, sent as the socket's first message.
    let config: String
    let sampleRate: Int

    static let sampleRate = 16_000

    /// The backend owns the session; only accept one that points at Soniox
    /// over TLS and expects the audio the recorder produces.
    var isValid: Bool {
        version == 1
            && provider == "soniox"
            && sampleRate == Self.sampleRate
            && url.scheme == "wss"
            && url.host() == "stt-rt.soniox.com"
            && !token.isEmpty
            && !config.isEmpty
    }
}

/// Streams one take to Soniox realtime over a single-use key. Audio is
/// buffered until the socket is open, so capture never waits for the grant.
/// The take ends with an empty frame; the transcript is the final tokens.
final class StreamingSpeechTranscription: LiveSpeechTranscribing {
    /// How long `finish()` waits for the final transcript before giving up,
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

        var request = URLRequest(url: grant.url)
        request.setValue("Bearer \(grant.token)", forHTTPHeaderField: "Authorization")
        let socket = session.webSocketTask(with: request)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        return try await withThrowingTaskGroup(of: SpeechTranscription?.self) { group in
            group.addTask {
                try await socket.send(.string(grant.config))
                for await chunk in chunks {
                    try await socket.send(.data(chunk))
                }
                // A short tail of silence lets the final syllable settle,
                // then an empty text frame ends the stream.
                try await socket.send(.data(Data(count: RealtimeSpeechGrant.sampleRate / 10 * 2)))
                try await socket.send(.string(""))
                return nil
            }
            group.addTask {
                try await finalTranscript(from: socket)
            }
            defer { group.cancelAll() }
            while let next = try await group.next() {
                if let transcription = next { return transcription }
            }
            throw SpeechRecognitionError.temporarilyUnavailable
        }
    }

    /// Final tokens arrive once each; the stream is done at `finished`.
    private static func finalTranscript(
        from socket: URLSessionWebSocketTask
    ) async throws -> SpeechTranscription {
        var finals = ""
        while true {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default: continue
            }
            guard let response = try? JSONDecoder().decode(RealtimeResponse.self, from: data) else {
                continue
            }
            if response.errorCode != nil || response.errorType != nil {
                logger.error("Realtime transcription failed: \(response.errorType ?? "unknown", privacy: .public)")
                throw SpeechRecognitionError.temporarilyUnavailable
            }
            for token in response.tokens ?? [] where token.isFinal && !token.text.hasPrefix("<") {
                finals += token.text
            }
            if response.finished == true {
                return try transcription(from: finals)
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

    private struct RealtimeResponse: Decodable {
        struct Token: Decodable {
            let text: String
            let isFinal: Bool

            enum CodingKeys: String, CodingKey {
                case text
                case isFinal = "is_final"
            }
        }

        let tokens: [Token]?
        let finished: Bool?
        let errorCode: Int?
        let errorType: String?

        enum CodingKeys: String, CodingKey {
            case tokens, finished
            case errorCode = "error_code"
            case errorType = "error_type"
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
