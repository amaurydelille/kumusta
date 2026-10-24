import Foundation
import Observation
import Supabase
@preconcurrency import AVFoundation

struct LivePracticeAllowance: Decodable, Sendable {
    let remaining_seconds: Int
    let daily_limit_seconds: Int?
    let resets_at: Date
    let available: Bool
}

struct LivePracticeTranscriptLine: Encodable, Sendable {
    let speaker: String
    let text: String
    let start_ms: Int?
}

struct LivePracticeGatewayError: LocalizedError, Sendable {
    let code: String
    let message: String
    var errorDescription: String? { message }
}

struct LivePracticeGateway: Sendable {
    let client: SupabaseClient
    let configuration: AppConfiguration

    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }

    func makeRequest(
        _ body: some Encodable, function: String = LivePracticeGateway.pipelineFunction, timeout: TimeInterval = 8
    ) async throws -> URLRequest {
        guard let base = configuration.supabaseURL else { throw URLError(.badURL) }
        var request = URLRequest(url: base.appendingPathComponent("functions/v1/\(function)"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(try await client.auth.session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Version headers let the server log and gate behaviour per build.
        let info = Bundle.main.infoDictionary
        request.setValue(info?["CFBundleShortVersionString"] as? String, forHTTPHeaderField: "X-Kumusta-App-Version")
        request.setValue(info?["CFBundleVersion"] as? String, forHTTPHeaderField: "X-Kumusta-App-Build")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// A request can stall on a dead pooled connection and never reach the
    /// server; a timed-out attempt is retried once on a fresh connection when
    /// the action is safe to repeat.
    func post(
        _ body: some Encodable, function: String = LivePracticeGateway.pipelineFunction, timeout: TimeInterval = 8,
        retryOnTimeout: Bool = true
    ) async throws -> Data {
        let request = try await makeRequest(body, function: function, timeout: timeout)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where retryOnTimeout && error.code == .timedOut {
            (data, response) = try await URLSession.shared.data(for: request)
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            if let failure = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw LivePracticeGatewayError(code: failure.code, message: failure.message)
            }
            throw URLError(.badServerResponse)
        }
        return data
    }

    func allowance(function: String = LivePracticeGateway.pipelineFunction) async throws -> LivePracticeAllowance {
        struct Request: Encodable { let action = "allowance" }
        let data = try await post(Request(), function: function)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: text) else { throw URLError(.cannotParseResponse) }
            return date
        }
        return try decoder.decode(LivePracticeAllowance.self, from: data)
    }

    func finish(
        sessionID: UUID, conversationID: String?, reason: String, mutes: Int,
        transcript: [LivePracticeTranscriptLine], function: String = LivePracticeGateway.pipelineFunction
    ) async throws {
        struct Request: Encodable {
            let action = "finish"
            let session_id: String
            let conversation_id: String?
            let reason: String
            let mutes: Int
            let transcript: [LivePracticeTranscriptLine]
        }
        _ = try await post(Request(
            session_id: sessionID.uuidString.lowercased(),
            conversation_id: conversationID,
            reason: reason,
            mutes: mutes,
            transcript: transcript
        ), function: function)
    }
}

struct LiveCaption: Identifiable {
    let id: String
    let isUser: Bool
    var text: String
    /// Milliseconds since the conversation became active.
    var startMs: Int?
}

/// Which live engine this build ships, reported with live analytics.
let livePracticeEngine = "pipeline"

/// The visual speaking turn bridges short delivery gaps, but articulation still
/// samples the actual audible PCM. This does not gate microphone capture.
struct LiveSpeakingActivity {
    private var lastAudibleAt: Double?

    mutating func update(frame: MascotSpeechFrame, isPlaying: Bool, at time: Double) -> Bool {
        // Live output includes silent PCM, so a queued buffer is not itself
        // evidence that the assistant has the speaking turn.
        update(audible: isPlaying && frame.energy > 0.015, at: time)
    }

    mutating func update(audible: Bool, at time: Double) -> Bool {
        if audible { lastAudibleAt = time }
        guard let lastAudibleAt else { return false }
        return audible || time - lastAudibleAt < 0.6
    }
}

/// Separate start/stop thresholds and dwell times prevent level-meter flicker.
struct LiveMicrophoneActivity {
    private(set) var level = 0.0
    private(set) var isSpeaking = false
    private var updatedAt: Double?
    private var aboveThresholdAt: Double?
    private var belowThresholdAt: Double?

    mutating func update(level input: Double, at time: Double) {
        let input = min(1, max(0, input))
        let elapsed = max(0, time - (updatedAt ?? time))
        let smoothing = input > level ? 0.06 : 0.2
        level += (input - level) * (1 - exp(-elapsed / smoothing))
        updatedAt = time
        if isSpeaking {
            aboveThresholdAt = nil
            if level < 0.06 {
                if belowThresholdAt == nil { belowThresholdAt = time }
                if time - belowThresholdAt! >= 0.4 { isSpeaking = false }
            } else { belowThresholdAt = nil }
        } else {
            belowThresholdAt = nil
            if level > 0.12 {
                if aboveThresholdAt == nil { aboveThresholdAt = time }
                if time - aboveThresholdAt! >= 0.12 { isSpeaking = true }
            } else { aboveThresholdAt = nil }
        }
    }
}
