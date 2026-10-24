import Foundation
import OSLog
import Speech
import Supabase

struct SpeechTranscriptionWord: Codable, Equatable, Sendable {
    let text: String
    let start: Double
    let end: Double
}

struct SpeechTranscription: Codable, Equatable, Sendable {
    let version: Int
    let transcript: String
    let languageCode: String
    let languageProbability: Double?
    let words: [SpeechTranscriptionWord]

    enum CodingKeys: String, CodingKey {
        case version, transcript, words
        case languageCode = "languageCode"
        case languageProbability = "languageProbability"
    }
}

enum SpeechRecognitionError: LocalizedError, Sendable {
    case invalidAudio
    case responseInvalid
    case speechNotDetected
    case temporarilyUnavailable
    case authenticationRequired
    case premiumRequired
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidAudio:
            L("That recording is too short or too large. Try one short phrase.")
        case .responseInvalid:
            L("The speech result could not be read. Please try again.")
        case .speechNotDetected:
            L("I couldn’t hear a phrase yet. Move a little closer and try again.")
        case .temporarilyUnavailable:
            L("Speech feedback is taking a break. Please try again shortly.")
        case .authenticationRequired:
            L("Your session expired. Sign in again to check your speech.")
        case .premiumRequired:
            L("Your Kumusta Pro access needs to be restored before speech checking.")
        case .rateLimited:
            L("Too many checks in a short time. Please wait a moment and try again.")
        }
    }
}

protocol VietnameseSpeechRecognizing: Sendable {
    func transcribe(audio: Data) async throws -> SpeechTranscription
    func transcribeOnboarding(audio: Data) async throws -> SpeechTranscription
    /// Starts streaming a take as it is recorded, or nil when this service
    /// can only transcribe a finished take.
    func makeLiveTranscription(onboarding: Bool) -> (any LiveSpeechTranscribing)?
}

extension VietnameseSpeechRecognizing {
    func transcribeOnboarding(audio: Data) async throws -> SpeechTranscription {
        try await transcribe(audio: audio)
    }

    func makeLiveTranscription(onboarding: Bool) -> (any LiveSpeechTranscribing)? {
        nil
    }
}

/// Uploads one bounded, ephemeral M4A take through the authenticated Supabase
/// boundary. The ElevenLabs credential and provider response never enter the
/// application bundle.
actor SupabaseElevenLabsSpeechRecognitionService: VietnameseSpeechRecognizing {
    static let maximumUploadBytes = 1_500_000
    private static let logger = Logger(subsystem: "com.kumusta.app", category: "SpeechRecognition")

    private let client: SupabaseClient
    private let authSessionProvider: any AuthSessionProviding

    init(client: SupabaseClient, authSessionProvider: any AuthSessionProviding) {
        self.client = client
        self.authSessionProvider = authSessionProvider
    }

    func transcribe(audio: Data) async throws -> SpeechTranscription {
        try await transcribe(audio: audio, onboarding: false)
    }

    func transcribeOnboarding(audio: Data) async throws -> SpeechTranscription {
        try await transcribe(audio: audio, onboarding: true)
    }

    nonisolated func makeLiveTranscription(onboarding: Bool) -> (any LiveSpeechTranscribing)? {
        ElevenLabsRealtimeTranscription { [self] in
            try await realtimeGrant(onboarding: onboarding)
        }
    }

    private func transcribe(audio: Data, onboarding: Bool) async throws -> SpeechTranscription {
        guard (512 ... Self.maximumUploadBytes).contains(audio.count) else {
            throw SpeechRecognitionError.invalidAudio
        }
        var headers = Self.headers(onboarding: onboarding)
        headers["Content-Type"] = "audio/mp4"
        let response: SpeechTranscription = try await invoke(
            "kumusta-elevenlabs-stt",
            headers: headers,
            body: audio,
            timeout: 25
        )
        guard
            response.version == 1,
            response.languageCode == "vie",
            (1 ... 500).contains(response.transcript.count),
            response.words.count <= 100,
            response.words.allSatisfy({
                !$0.text.isEmpty && $0.text.count <= 80 && $0.start >= 0 && $0.end >= $0.start
            })
        else {
            throw SpeechRecognitionError.responseInvalid
        }
        return response
    }

    /// One single-use realtime session, admitted by the same gate and quota as
    /// an uploaded take.
    private func realtimeGrant(onboarding: Bool) async throws -> RealtimeSpeechGrant {
        try await invoke(
            "kumusta-elevenlabs-stt-token",
            headers: Self.headers(onboarding: onboarding),
            body: nil,
            timeout: 10
        )
    }

    private static func headers(onboarding: Bool) -> [String: String] {
        #if DEBUG
        // Simulator builds can unlock the lesson UI with the local development
        // paywall bypass. Use the bounded pre-paywall speech allowance there
        // so that local-only access does not create a misleading auth failure.
        let usesPrePaywallAllowance = true
        #else
        let usesPrePaywallAllowance = onboarding
        #endif
        return usesPrePaywallAllowance ? ["X-Kumusta-Onboarding": "first-lesson"] : [:]
    }

    private func invoke<Response: Decodable>(
        _ functionName: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> Response {
        do {
            _ = try await authSessionProvider.currentBackendIdentity()
        } catch {
            do {
                // `refreshSession` cannot recover `sessionMissing`. Create the
                // anonymous backend identity that normal app bootstrap would
                // have created before invoking a protected Edge Function.
                _ = try await authSessionProvider.bootstrapAnonymousSession()
            } catch {
                Self.logger.error("Speech request has no backend session: \(String(reflecting: error), privacy: .public)")
                throw SpeechRecognitionError.authenticationRequired
            }
        }

        for attempt in 0..<2 {
            do {
                let options = if let body {
                    FunctionInvokeOptions(headers: headers, body: body, timeoutInterval: timeout)
                } else {
                    FunctionInvokeOptions(method: .post, headers: headers, timeoutInterval: timeout)
                }
                return try await client.functions.invoke(functionName, options: options)
            } catch let error as SpeechRecognitionError {
                throw error
            } catch let FunctionsError.httpError(code, data) {
                let backendCode = Self.providerErrorCode(in: data) ?? "unknown"
                Self.logger.error("Speech request failed: HTTP \(code, privacy: .public), code \(backendCode, privacy: .public)")
                if code == 422, backendCode == "speech_not_detected" {
                    throw SpeechRecognitionError.speechNotDetected
                }
                if code == 401 || backendCode == "invalid_session" || backendCode == "authentication_required" {
                    if attempt == 0 {
                        do {
                            _ = try await authSessionProvider.refreshBackendSession()
                            continue
                        } catch {
                            Self.logger.error(
                                "Speech session refresh failed: \(String(reflecting: error), privacy: .public)"
                            )
                        }
                    }
                    throw SpeechRecognitionError.authenticationRequired
                }
                if backendCode == "premium_required" {
                    throw SpeechRecognitionError.premiumRequired
                }
                if code == 429 {
                    throw SpeechRecognitionError.rateLimited
                }
                if code == 413 || code == 415 || code == 422 {
                    throw SpeechRecognitionError.invalidAudio
                }
                if attempt == 0 && [502, 503, 504].contains(code) {
                    try await Task.sleep(for: .milliseconds(450))
                    continue
                }
                throw SpeechRecognitionError.temporarilyUnavailable
            } catch is CancellationError {
                throw CancellationError()
            } catch is DecodingError {
                throw SpeechRecognitionError.responseInvalid
            } catch {
                Self.logger.error("Speech request failed: \(String(reflecting: error), privacy: .public)")
                if attempt == 0 {
                    try await Task.sleep(for: .milliseconds(450))
                    continue
                }
                throw SpeechRecognitionError.temporarilyUnavailable
            }
        }
        throw SpeechRecognitionError.temporarilyUnavailable
    }

    private static func providerErrorCode(in data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = object["code"] as? String
        else { return nil }
        return code
    }
}

actor PreviewSpeechRecognitionService: VietnameseSpeechRecognizing {
    func transcribe(audio: Data) async throws -> SpeechTranscription {
        try await Task.sleep(for: .milliseconds(450))
        return SpeechTranscription(
            version: 1,
            transcript: "Cho mình một cà phê sữa đá.",
            languageCode: "vie",
            languageProbability: 0.99,
            words: []
        )
    }

    func transcribeOnboarding(audio: Data) async throws -> SpeechTranscription {
        try await Task.sleep(for: .milliseconds(450))
        return SpeechTranscription(
            version: 1,
            transcript: "Chào bạn, bạn uống cà phê không?",
            languageCode: "vie",
            languageProbability: 0.99,
            words: []
        )
    }
}

/// ElevenLabs first; Apple's recognizer only when the provider is down.
/// Errors about the learner or their access (silence, sign-in, Pro, rate
/// limit) surface unchanged, so the fallback never bypasses a server gate.
struct FallbackSpeechRecognitionService: VietnameseSpeechRecognizing {
    private static let logger = Logger(subsystem: "com.kumusta.app", category: "SpeechRecognition")

    let primary: any VietnameseSpeechRecognizing
    let fallback: any VietnameseSpeechRecognizing

    func transcribe(audio: Data) async throws -> SpeechTranscription {
        try await run { try await $0.transcribe(audio: audio) }
    }

    func transcribeOnboarding(audio: Data) async throws -> SpeechTranscription {
        try await run { try await $0.transcribeOnboarding(audio: audio) }
    }

    /// Streaming is ElevenLabs-only; a failed stream falls back to `transcribe`,
    /// which keeps the on-device fallback behind it.
    func makeLiveTranscription(onboarding: Bool) -> (any LiveSpeechTranscribing)? {
        primary.makeLiveTranscription(onboarding: onboarding)
    }

    private func run(
        _ operation: (any VietnameseSpeechRecognizing) async throws -> SpeechTranscription
    ) async throws -> SpeechTranscription {
        do {
            return try await operation(primary)
        } catch SpeechRecognitionError.temporarilyUnavailable {
            Self.logger.notice("Primary speech provider unavailable; using on-device fallback")
            do {
                return try await operation(fallback)
            } catch is CancellationError {
                throw CancellationError()
            } catch SpeechRecognitionError.speechNotDetected {
                throw SpeechRecognitionError.speechNotDetected
            } catch {
                Self.logger.error("Fallback speech recognition failed: \(String(reflecting: error), privacy: .public)")
                throw SpeechRecognitionError.temporarilyUnavailable
            }
        }
    }
}

/// Apple's Vietnamese recognizer, used only as a fallback. It prefers
/// on-device recognition when the device supports it, and asks for speech
/// permission lazily, the first time it is actually needed.
struct AppleSpeechRecognitionService: VietnameseSpeechRecognizing {
    private static let locale = Locale(identifier: "vi-VN")

    func transcribe(audio: Data) async throws -> SpeechTranscription {
        guard await Self.isAuthorized(),
              let recognizer = SFSpeechRecognizer(locale: Self.locale),
              recognizer.isAvailable
        else {
            throw SpeechRecognitionError.temporarilyUnavailable
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kumusta-fallback-\(UUID().uuidString).m4a")
        try audio.write(to: url, options: [.atomic, .completeFileProtection])
        defer { try? FileManager.default.removeItem(at: url) }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let pending = PendingRecognition()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.begin(continuation) {
                    recognizer.recognitionTask(with: request) { result, error in
                        if let result, result.isFinal {
                            pending.finish(Self.transcription(from: result.bestTranscription))
                        } else if let error {
                            pending.finish(.failure(Self.mapped(error)))
                        }
                    }
                }
            }
        } onCancel: {
            pending.cancel()
        }
    }

    private static func isAuthorized() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        default:
            return false
        }
    }

    private static func transcription(from best: SFTranscription) -> Result<SpeechTranscription, Error> {
        let transcript = best.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return .failure(SpeechRecognitionError.speechNotDetected) }
        return .success(
            SpeechTranscription(
                version: 1,
                transcript: String(transcript.prefix(500)),
                languageCode: "vie",
                languageProbability: nil,
                words: best.segments.prefix(100).map {
                    SpeechTranscriptionWord(
                        text: $0.substring,
                        start: $0.timestamp,
                        end: $0.timestamp + $0.duration
                    )
                }
            )
        )
    }

    /// Apple reports silence as kAFAssistantErrorDomain 1110.
    private static func mapped(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 {
            return SpeechRecognitionError.speechNotDetected
        }
        return SpeechRecognitionError.temporarilyUnavailable
    }
}

/// Resumes the continuation exactly once, whichever of result, error, or
/// cancellation arrives first.
private final class PendingRecognition: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<SpeechTranscription, Error>?
    private var task: SFSpeechRecognitionTask?
    private var isCancelled = false

    func begin(
        _ continuation: CheckedContinuation<SpeechTranscription, Error>,
        start: () -> SFSpeechRecognitionTask
    ) {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        lock.unlock()

        let task = start()
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func finish(_ result: Result<SpeechTranscription, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
        finish(.failure(CancellationError()))
    }
}
