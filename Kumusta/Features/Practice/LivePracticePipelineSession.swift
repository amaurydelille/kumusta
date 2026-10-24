import Foundation
import Observation
import OSLog
import os
@preconcurrency import AVFoundation

// MARK: - Gateway

/// Reply streams get their own connections: a long response cancelled
/// mid-stream must not stall the shared pool the rest of the app relies on.
private let liveReplySession = URLSession(configuration: .ephemeral)

/// A pipeline session: no daily allowance, an hour at most per session.
struct LivePipelineStart: Decodable, Sendable {
    let session_id: UUID
    let seconds: Int
}

extension LivePracticeGateway {
    static let pipelineFunction = "kumusta-live-pipeline"

    /// The pipeline owns its sessions, without the agent's daily limit.
    func pipelineStart(
        topic: String, lesson: String, lessonID: UUID?, personality: String,
        clientSessionID: UUID?
    ) async throws -> LivePipelineStart {
        struct Request: Encodable {
            let action = "start"
            let topic: String
            let latest_lesson: String
            let latest_lesson_id: String
            let personality: String
            let client_session_id: String
        }
        let data = try await post(Request(
            topic: topic,
            latest_lesson: lesson,
            latest_lesson_id: lessonID?.uuidString.lowercased() ?? "",
            personality: personality,
            client_session_id: clientSessionID?.uuidString.lowercased() ?? ""
        ), function: Self.pipelineFunction, timeout: 12)
        return try JSONDecoder().decode(LivePipelineStart.self, from: data)
    }

    /// A single-use realtime transcription session for the open live
    /// session; the server picks the provider among those this build speaks.
    func transcriber(sessionID: UUID) async throws -> LivePipelineTranscriberGrant {
        struct Request: Encodable {
            let action = "transcriber"
            let session_id: String
            let providers = ["elevenlabs", "soniox"]
        }
        let data = try await post(
            Request(session_id: sessionID.uuidString.lowercased()),
            function: "kumusta-live-pipeline")
        return try LivePipelineTranscriberGrant(data)
    }

    struct ReplyContext: Encodable, Sendable {
        let topic: String
        let latest_lesson: String
        let personality: String
    }

    struct HistoryLine: Encodable, Sendable {
        let speaker: String
        let text: String
        /// The learner caption this line came from; not sent to the server.
        var captionID: String? = nil

        enum CodingKeys: String, CodingKey { case speaker, text }
    }

    enum ReplyEvent: Sendable {
        case text(String)
        case audio(Data)
    }

    /// Streams one spoken reply: sentences of text, each followed by its
    /// 24 kHz PCM16 speech. An empty history asks for the greeting.
    func reply(
        sessionID: UUID, context: ReplyContext, history: [HistoryLine]
    ) -> AsyncThrowingStream<ReplyEvent, Error> {
        struct Request: Encodable {
            let action = "reply"
            let session_id: String
            let context: ReplyContext
            let greeting: Bool
            let history: [HistoryLine]
        }
        struct Line: Decodable {
            let type: String
            let text: String?
            let data: String?
            let code: String?
        }
        let body = Request(
            session_id: sessionID.uuidString.lowercased(), context: context,
            greeting: history.isEmpty, history: history)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let clock = ContinuousClock()
                    let begun = clock.now
                    let request = try await makeRequest(body, function: "kumusta-live-pipeline", timeout: 30)
                    let prepared = clock.now
                    let (bytes, response) = try await liveReplySession.bytes(for: request)
                    Logger(subsystem: "com.kumusta.app", category: "LivePractice").notice(
                        "Live reply request prepared in \(begun.duration(to: prepared), privacy: .public), headers after \(prepared.duration(to: clock.now), privacy: .public)")
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard http.statusCode == 200 else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        if let failure = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                            throw LivePracticeGatewayError(code: failure.code, message: failure.message)
                        }
                        throw URLError(.badServerResponse)
                    }
                    for try await text in bytes.lines {
                        guard let line = try? JSONDecoder().decode(Line.self, from: Data(text.utf8)) else {
                            continue
                        }
                        switch line.type {
                        case "text":
                            if let text = line.text { continuation.yield(.text(text)) }
                        case "audio":
                            if let audio = line.data.flatMap({ Data(base64Encoded: $0) }) {
                                continuation.yield(.audio(audio))
                            }
                        case "error":
                            throw LivePracticeGatewayError(
                                code: line.code ?? "reply_failed",
                                message: L("Kalabaw couldn’t answer. Try saying that again."))
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Session

/// Drives one live conversation as a speech pipeline: the microphone streams
/// to ElevenLabs Scribe realtime, each committed learner turn goes to
/// `kumusta-live-pipeline` (Claude -> ElevenLabs TTS), and the streamed
/// reply plays through the audio engine. The same function opens and settles
/// the session; unlike the agent there is no daily time limit.
///
/// Turns are half-duplex: while Kalabaw answers, the microphone sends
/// silence, so the reply cannot be transcribed back as the learner.
@MainActor @Observable
final class LivePracticeSession {
    enum Phase: Equatable { case idle, connecting, active, stopping, ended }
    var phase: Phase = .idle
    var remaining = 300
    var dailyLimit = 300
    var elapsed = 0
    var muted = false
    var captions: [LiveCaption] = []
    var message: String?
    var available = false
    var loadingAllowance = false
    var resetAt: Date?
    var assistantSpeaking = false
    var assistantSpeech = MascotSpeechFrame.silent
    var assistantLevel: CGFloat = 0
    var voiceLevel: CGFloat = 0
    private(set) var userSpeaking = false
    private(set) var thinking = false
    private var speakingActivity = LiveSpeakingActivity()
    private var microphoneActivity = LiveMicrophoneActivity()
    var userFragments = 0
    var endReason = ""
    /// Why the last start failed, for analytics; empty when it didn't.
    private(set) var startFailure = ""
    var clientSessionID: UUID?
    private(set) var didBecomeActive = false
    private var gateway: LivePracticeGateway?
    private var audio: LivePipelineAudio?
    private var transcriber: (any LivePipelineTranscribing)?
    private var context: LivePracticeGateway.ReplyContext?
    /// What the model said and heard, with audio tags kept for continuity.
    private var history: [LivePracticeGateway.HistoryLine] = []
    private var partialCaptionID: String?
    private var waitingTurn = false
    /// The reply being prepared or spoken; replies of an interrupted turn
    /// compare against it and stop touching the session.
    private var currentTurn: UUID?
    private var replyCaptionID: String?
    private var replySpoken = ""
    private var replyAudible = false
    private var replyAudibleAt: Double?
    /// What Kalabaw said last and when she stopped, to recognize her own
    /// voice picked up again just after.
    private var lastSpoken = ""
    private var lastSpokenEndedAt: Double?
    /// Cutting in this soon after Kalabaw started means the learner had not
    /// finished: her answer is dropped and their sentence continues.
    static let continuationWindow: TimeInterval = 3
    /// The learner's turn that was cut short by a pause: it is completed by
    /// what they say next instead of being answered on its own.
    private var unfinishedTurn: (text: String, captionID: String?)?
    /// When the last learner turn was committed, to time the reply.
    private var committedAt: ContinuousClock.Instant?
    private var startTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    private var replyTask: Task<Void, Never>?
    private var glowToken: UUID?
    private var microphoneGlowToken: UUID?
    private var deadline: Date?
    private var activatedAt: Date?
    private var generation = UUID()
    private var serverSessionID: UUID?
    private var mutes = 0
    private var roundStartingRemaining = 300
    private static let logger = Logger(subsystem: "com.kumusta.app", category: "LivePractice")
    /// The conversation ends after this long without the learner saying
    /// anything on their turn. Kalabaw thinking or talking pauses the clock.
    static let inactivityLimit: TimeInterval = 10
    private var lastActivity = ProcessInfo.processInfo.systemUptime

    var isOpen: Bool { phase == .connecting || phase == .active || phase == .stopping }
    var timeLabel: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }
    var progressFraction: CGFloat {
        guard dailyLimit > 0 else { return 0 }
        return min(1, max(0, CGFloat(dailyLimit - remaining) / CGFloat(dailyLimit)))
    }
    var status: String {
        if phase == .connecting { return L("Finding your conversation buddy…") }
        if phase == .stopping { return L("Finishing your practice…") }
        if phase == .ended { return elapsed > 0 ? L("Nice work") : L("Ready when you are") }
        if phase == .idle { return L("Ready when you are") }
        if muted { return L("Microphone muted · time is still running") }
        if assistantSpeaking { return L("Kalabaw is talking") }
        if thinking { return L("Kalabaw is thinking…") }
        return userSpeaking ? L("I hear you") : L("Listening…")
    }

    func load(_ gateway: LivePracticeGateway?) async {
        self.gateway = gateway
        guard !isOpen else { return }
        guard let gateway else { message = L("Live practice needs a connected account."); return }
        loadingAllowance = true
        defer { loadingAllowance = false }
        do {
            let allowance = try await gateway.allowance(function: LivePracticeGateway.pipelineFunction)
            remaining = allowance.remaining_seconds
            dailyLimit = max(300, allowance.daily_limit_seconds ?? 300)
            resetAt = allowance.resets_at
            available = allowance.available
            if !available { message = L("Live practice is being set up. Please check back shortly.") }
            else { message = nil }
        } catch { available = false; message = L("Couldn’t load your daily time. Check your connection and retry.") }
    }

    @discardableResult
    func start(
        topic: String, lesson: String, lessonID: UUID?, personality: String
    ) -> UUID? {
        guard !isOpen, !loadingAllowance, available, remaining > 0, let gateway else { return nil }
        generation = UUID()
        let current = generation
        let analyticsSessionID = UUID()
        clientSessionID = analyticsSessionID
        didBecomeActive = false
        serverSessionID = nil
        history = []
        partialCaptionID = nil
        waitingTurn = false
        currentTurn = nil
        unfinishedTurn = nil
        mutes = 0
        endReason = ""
        startFailure = ""
        phase = .connecting; message = nil; muted = false; captions = []; elapsed = 0; userFragments = 0
        let topic = String(topic.prefix(200))
        let lesson = String(lesson.prefix(600))
        context = .init(topic: topic, latest_lesson: lesson, personality: personality)
        startTask = Task { [weak self] in
            let permitted = await AVAudioApplication.requestRecordPermission()
            guard let self, self.generation == current, !Task.isCancelled else { return }
            guard permitted else {
                self.message = L("Allow microphone access in Settings to talk with your buddy.")
                self.endReason = "microphone_permission_denied"
                self.generation = UUID()
                self.phase = .ended
                return
            }
            await self.connect(
                gateway: gateway, current: current, topic: topic, lesson: lesson,
                lessonID: lessonID, personality: personality)
        }
        return analyticsSessionID
    }

    private func connect(
        gateway: LivePracticeGateway, current: UUID, topic: String, lesson: String,
        lessonID: UUID?, personality: String
    ) async {
        let reservation: LivePipelineStart
        do {
            // Unstructured so stop() can't cancel the request mid-flight: the
            // server may already have reserved the session, and only a
            // completed response tells us which one to release below.
            let clientSessionID = clientSessionID
            let request = Task {
                try await gateway.pipelineStart(
                    topic: topic, lesson: lesson, lessonID: lessonID,
                    personality: personality, clientSessionID: clientSessionID)
            }
            reservation = try await request.value
        } catch {
            guard generation == current, phase == .connecting else { return }
            startFailure = (error as? LivePracticeGatewayError).map { "gateway_\($0.code)" }
                ?? String(String(describing: error).prefix(100))
            message = (error as? LivePracticeGatewayError)?.message
                ?? L("Couldn’t connect to live practice. Please try again.")
            finish(reason: "start_failed")
            return
        }
        guard generation == current, !Task.isCancelled else {
            // The learner left while time was being reserved; release it now.
            Task {
                try? await gateway.finish(
                    sessionID: reservation.session_id, conversationID: nil,
                    reason: "cancelled_start", mutes: 0, transcript: [],
                    function: LivePracticeGateway.pipelineFunction)
            }
            return
        }
        serverSessionID = reservation.session_id

        let audio: LivePipelineAudio
        let transcriber: any LivePipelineTranscribing
        do {
            let grant = try await gateway.transcriber(sessionID: reservation.session_id)
            guard generation == current, !Task.isCancelled else { return }
            transcriber = try grant.connect()
            Self.logger.notice("Live transcription via \(grant.provider, privacy: .public)")
            audio = try LivePipelineAudio(echoCancellation: grant.echoCancellation) { [transcriber] pcm in
                transcriber.send(pcm)
            }
        } catch {
            guard generation == current, phase == .connecting else { return }
            startFailure = (error as? LivePracticeGatewayError).map { "gateway_\($0.code)" }
                ?? String(String(describing: error).prefix(100))
            message = error is LivePipelineAudio.Failure
                ? L("The microphone couldn’t start. Check your audio route and try again.")
                : L("Couldn’t connect to live practice. Please try again.")
            finish(reason: "start_failed")
            return
        }
        self.audio = audio
        self.transcriber = transcriber
        activatedAt = .now
        roundStartingRemaining = reservation.seconds
        remaining = reservation.seconds
        deadline = .now.addingTimeInterval(Double(reservation.seconds))
        didBecomeActive = true
        phase = .active
        listen(to: transcriber, current: current)
        startMonitor(current: current)
        respond(current: current)
    }

    // MARK: Turns

    private func listen(to transcriber: any LivePipelineTranscribing, current: UUID) {
        transcriptTask = Task { [weak self] in
            do {
                for try await event in transcriber.events {
                    guard let self, self.generation == current else { return }
                    switch event {
                    case .partial(let text): self.showPartial(text)
                    case .committed(let text):
                        Self.logger.notice("Live turn committed (\(text.count) characters)")
                        self.commit(text, current: current)
                    }
                }
                throw URLError(.networkConnectionLost)
            } catch {
                guard let self, self.generation == current, self.phase == .active else { return }
                Self.logger.error("Live transcriber ended: \(String(describing: error), privacy: .public)")
                self.message = L("Connection lost. Your microphone is off. Retry when you’re ready.")
                self.finish(reason: "connection_lost")
            }
        }
    }

    private func showPartial(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, phase == .active else { return }
        // Recognized words, not the microphone level, so background noise
        // cannot keep a silent conversation open.
        lastActivity = ProcessInfo.processInfo.systemUptime
        // Kalabaw's own voice coming back through the microphone.
        if let reference = echoReference(), Self.isEcho(text, of: reference) { return }
        // The learner has the priority: speaking while Kalabaw prepares or
        // gives an answer takes the turn back.
        if currentTurn != nil { interruptReply() }
        let shown = unfinishedTurn.map { "\($0.text) \(text)" } ?? text
        if let id = partialCaptionID, let index = captions.firstIndex(where: { $0.id == id }) {
            captions[index].text = shown
        } else {
            let id = unfinishedTurn?.captionID ?? UUID().uuidString
            partialCaptionID = id
            if let index = captions.firstIndex(where: { $0.id == id }) {
                captions[index].text = shown
            } else {
                captions.append(LiveCaption(id: id, isUser: true, text: shown, startMs: offsetMs()))
            }
        }
    }

    private func commit(_ text: String, current: UUID) {
        var text = text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let partial = partialCaptionID
        partialCaptionID = nil
        let echo = echoReference().map { Self.isEcho(text, of: $0) } ?? false
        guard !text.isEmpty, !echo else {
            if unfinishedTurn == nil { captions.removeAll { $0.id == partial } }
            return
        }
        if let unfinished = unfinishedTurn {
            text = "\(unfinished.text) \(text)"
            unfinishedTurn = nil
        }
        let captionID = partial ?? UUID().uuidString
        if let index = captions.firstIndex(where: { $0.id == captionID }) {
            captions[index].text = text
        } else {
            captions.append(LiveCaption(id: captionID, isUser: true, text: text, startMs: offsetMs()))
        }
        userFragments = captions.filter(\.isUser).count
        history.append(.init(speaker: "user", text: text, captionID: captionID))
        committedAt = .now
        // A turn that lands while Kalabaw is answering is answered next.
        if currentTurn == nil { respond(current: current) } else { waitingTurn = true }
    }

    /// Stops the reply in flight because the learner is talking. Before any
    /// of it was heard, the learner had only paused: their previous turn is
    /// reopened and completed by what they say now. Once Kalabaw was audible,
    /// what she said so far stays in the conversation.
    private func interruptReply() {
        guard currentTurn != nil else { return }
        currentTurn = nil
        replyTask?.cancel()
        replyTask = nil
        thinking = false
        waitingTurn = false
        audio?.interrupt()
        let heardFor = replyAudibleAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0
        if replyAudible && heardFor >= Self.continuationWindow {
            if !replySpoken.isEmpty { history.append(.init(speaker: "assistant", text: replySpoken)) }
            Self.logger.notice("Live reply interrupted by the learner")
        } else {
            captions.removeAll { $0.id == replyCaptionID }
            if let last = history.last, last.speaker == "user" {
                history.removeLast()
                unfinishedTurn = (last.text, last.captionID)
            }
            Self.logger.notice("Live reply cancelled: the learner kept talking")
        }
        replyCaptionID = nil
        replySpoken = ""
        replyAudible = false
        replyAudibleAt = nil
        audio?.capturing = true
    }

    /// Only while Kalabaw is audible or just after: a learner repeating her
    /// sentence on their own turn ("repeat after me") is not an echo.
    private func echoReference() -> String? {
        if replyAudible { return replySpoken }
        guard let ended = lastSpokenEndedAt,
              ProcessInfo.processInfo.systemUptime - ended < 1 else { return nil }
        return lastSpoken
    }

    /// True when most recognized words are words Kalabaw is saying: residual
    /// echo the canceller let through, not the learner.
    static func isEcho(_ heard: String, of spoken: String) -> Bool {
        func words(_ text: String) -> [String] {
            text.replacing(/\[[^\]\n]{1,40}\]/, with: " ")
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
        }
        let heardWords = words(heard)
        let spokenWords = Set(words(spoken))
        guard !heardWords.isEmpty, !spokenWords.isEmpty else { return false }
        let matches = heardWords.filter(spokenWords.contains).count
        return Double(matches) / Double(heardWords.count) >= 0.7
    }

    /// Kalabaw can be interrupted mid-sentence when her voice cannot reach
    /// the microphone: echo cancellation is on, or she plays in headphones.
    private func allowsBargeIn(_ audio: LivePipelineAudio) -> Bool {
        audio.echoCancelled || Self.outputIsPrivate
    }

    private static var outputIsPrivate: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .usbAudio].contains($0.portType)
        }
    }

    /// Asks for the next reply (the greeting when nothing has been said yet)
    /// and plays it as it streams in. The microphone stays open until the
    /// reply is audible, so a learner who only paused can carry on.
    private func respond(current: UUID) {
        guard let gateway, let sessionID = serverSessionID, let context, let audio else { return }
        let turn = UUID()
        currentTurn = turn
        replyCaptionID = nil
        replySpoken = ""
        replyAudible = false
        replyAudibleAt = nil
        waitingTurn = false
        thinking = true
        let greeting = history.isEmpty
        audio.capturing = !greeting
        let history = history
        replyTask = Task { [weak self] in
            var audioBytes = 0
            do {
                for try await event in gateway.reply(sessionID: sessionID, context: context, history: history) {
                    guard let self, self.generation == current, self.currentTurn == turn else { return }
                    switch event {
                    case .text(let sentence):
                        self.replySpoken = self.replySpoken.isEmpty ? sentence : "\(self.replySpoken) \(sentence)"
                        let shown = Self.withoutAudioTags(self.replySpoken)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let id = self.replyCaptionID, let index = self.captions.firstIndex(where: { $0.id == id }) {
                            self.captions[index].text = shown
                        } else if !shown.isEmpty {
                            let id = UUID().uuidString
                            self.replyCaptionID = id
                            self.captions.append(
                                LiveCaption(id: id, isUser: false, text: shown, startMs: self.offsetMs()))
                        }
                    case .audio(let pcm):
                        if audioBytes == 0, let committedAt = self.committedAt {
                            Self.logger.notice("Live reply first audio after \(committedAt.duration(to: .now), privacy: .public)")
                            self.committedAt = nil
                        }
                        if !self.replyAudible {
                            self.replyAudible = true
                            self.replyAudibleAt = ProcessInfo.processInfo.systemUptime
                            self.thinking = false
                            audio.capturing = self.allowsBargeIn(audio)
                        }
                        audioBytes += pcm.count
                        audio.play(pcm16: pcm)
                    }
                }
                guard let self, self.currentTurn == turn else { return }
                Self.logger.notice(
                    "Live reply streamed \(self.replySpoken.count) characters, \(audioBytes) audio bytes")
                await audio.drained()
            } catch {
                guard let self, self.generation == current, self.currentTurn == turn else { return }
                if (error as? LivePracticeGatewayError)?.code == "session_closed" {
                    self.finish(reason: "session_closed")
                    return
                }
                Self.logger.error("Live reply failed: \(String(describing: error), privacy: .public)")
                self.message = L("Kalabaw couldn’t answer. Try saying that again.")
            }
            guard let self, self.generation == current, self.currentTurn == turn else { return }
            if !self.replySpoken.isEmpty { self.history.append(.init(speaker: "assistant", text: self.replySpoken)) }
            self.lastSpoken = self.replySpoken
            self.lastSpokenEndedAt = ProcessInfo.processInfo.systemUptime
            self.currentTurn = nil
            self.replyCaptionID = nil
            self.replySpoken = ""
            self.thinking = false
            self.replyTask = nil
            // Let the room's echo of the last syllable fade before listening.
            try? await Task.sleep(for: .milliseconds(250))
            guard self.generation == current, self.phase == .active, self.currentTurn == nil else { return }
            if self.waitingTurn {
                self.respond(current: current)
            } else {
                audio.capturing = true
            }
        }
    }

    private func offsetMs() -> Int? {
        activatedAt.map { max(0, Int(Date.now.timeIntervalSince($0) * 1000)) }
    }

    /// Drops expressive voice tags such as "[Happy]" that the voice model
    /// performs but the learner should not read.
    private static func withoutAudioTags(_ text: String) -> String {
        text.replacing(/\[[^\]\n]{1,40}\]/, with: "")
            .replacing(/[ \t]{2,}/, with: " ")
    }

    // MARK: Monitor

    private func startMonitor(current: UUID) {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == current, self.phase == .active else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func tick() {
        guard let audio else { return }
        if audio.failed {
            message = L("The microphone couldn’t be changed, so the conversation ended.")
            finish(reason: "audio_failed")
            return
        }
        if let deadline {
            remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
            elapsed = max(elapsed, roundStartingRemaining - remaining)
            if remaining == 0 { stop(reason: "session_limit"); return }
        }

        let now = ProcessInfo.processInfo.systemUptime
        let frame = audio.outputFrame
        assistantSpeech = frame
        assistantSpeaking = speakingActivity.update(audible: frame.energy > 0.015, at: now)
        assistantLevel = CGFloat(frame.energy)
        updatePlaybackGlow(speaking: assistantSpeaking, level: assistantLevel)

        if currentTurn != nil || thinking || assistantSpeaking || !audio.capturing {
            lastActivity = now
        } else if now - lastActivity >= Self.inactivityLimit {
            message = L("The conversation ended after 10 seconds of silence.")
            stop(reason: "inactivity")
            return
        }

        let listening = !muted && audio.capturing
        microphoneActivity.update(level: listening ? audio.inputFrame.energy : 0, at: now)
        userSpeaking = listening && microphoneActivity.isSpeaking
        voiceLevel = listening && !assistantSpeaking ? CGFloat(microphoneActivity.level) : 0
        updateMicrophoneGlow(userSpeaking ? voiceLevel : 0)
    }

    func toggleMute() {
        guard phase == .active, let audio else { return }
        muted.toggle()
        audio.muted = muted
        if muted {
            mutes += 1
            microphoneActivity = LiveMicrophoneActivity()
            userSpeaking = false
            voiceLevel = 0
            updateMicrophoneGlow(0)
        }
    }

    func stop() { stop(reason: "user_ended") }

    private func stop(reason: String) {
        guard phase == .connecting || phase == .active else { return }
        startTask?.cancel()
        phase = .stopping
        finish(reason: reason)
    }

    private func finish(reason: String) {
        guard isOpen else { return }
        generation = UUID()
        startTask?.cancel(); monitorTask?.cancel(); transcriptTask?.cancel(); replyTask?.cancel()
        replyTask = nil
        currentTurn = nil
        unfinishedTurn = nil
        transcriber?.close()
        transcriber = nil
        audio?.stop()
        audio = nil
        if let partialCaptionID { captions.removeAll { $0.id == partialCaptionID } }
        partialCaptionID = nil
        thinking = false
        if let deadline, didBecomeActive {
            remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
            elapsed = max(elapsed, roundStartingRemaining - remaining)
        }
        deadline = nil
        resetAudioActivity()
        endReason = reason
        phase = .ended

        let gateway = gateway
        let sessionID = serverSessionID
        let mutes = mutes
        let transcript = captions.map {
            LivePracticeTranscriptLine(
                speaker: $0.isUser ? "user" : "assistant", text: $0.text, start_ms: $0.startMs)
        }
        serverSessionID = nil
        let savedMessage = message
        Task {
            if let gateway, let sessionID {
                for attempt in 1...2 {
                    do {
                        try await gateway.finish(
                            sessionID: sessionID, conversationID: nil, reason: reason,
                            mutes: mutes, transcript: transcript,
                            function: LivePracticeGateway.pipelineFunction)
                        break
                    } catch {
                        try? await Task.sleep(for: .milliseconds(500 * attempt))
                    }
                }
            }
            await load(gateway)
            if let savedMessage { message = savedMessage }
        }
    }

    #if DEBUG
    private var demoPlayer: AVAudioPlayer?

    /// Marketing capture: plays a local clip as the buddy's voice so the mascot
    /// and border glow animate as in a live call, without any provider.
    func startDemo(clip url: URL) {
        guard !isOpen,
              let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatInt16, interleaved: true),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let samples = buffer.int16ChannelData?[0],
              let player = try? AVAudioPlayer(contentsOf: url)
        else { message = "Demo clip unreadable: \(url.path)"; return }
        var timeline = MascotSpeechTimeline()
        timeline.append(pcm16: Data(bytes: samples, count: Int(buffer.frameLength) * 2))
        let rate = file.processingFormat.sampleRate
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        generation = UUID()
        let current = generation
        phase = .active; message = nil; captions = []; elapsed = 0
        demoPlayer = player
        player.play()
        NSLog("liveDemoClip started at %f", Date().timeIntervalSince1970)
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == current, self.phase == .active else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let frame = player.isPlaying ? timeline.sample(at: Int64(player.currentTime * rate)) : .silent
                self.assistantSpeech = frame
                self.assistantSpeaking = self.speakingActivity.update(audible: frame.energy > 0.015, at: now)
                self.assistantLevel = CGFloat(frame.energy)
                self.updatePlaybackGlow(speaking: self.assistantSpeaking, level: self.assistantLevel)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }
    #endif

    private func resetAudioActivity() {
        #if DEBUG
        demoPlayer?.stop(); demoPlayer = nil
        #endif
        updatePlaybackGlow(speaking: false, level: 0)
        updateMicrophoneGlow(0)
        assistantSpeaking = false; assistantLevel = 0; assistantSpeech = .silent
        speakingActivity = LiveSpeakingActivity()
        microphoneActivity = LiveMicrophoneActivity()
        userSpeaking = false; voiceLevel = 0
    }

    private func updateMicrophoneGlow(_ level: CGFloat) {
        // Match the session's "I hear you" threshold so ambient noise does
        // not keep the microphone palette active during the buddy's turn.
        guard level > 0.08 else {
            AudioReactiveBorderState.shared.end(microphoneGlowToken)
            microphoneGlowToken = nil
            return
        }
        if microphoneGlowToken == nil {
            microphoneGlowToken = AudioReactiveBorderState.shared.begin(microphone: true)
        }
        if let microphoneGlowToken {
            // The meter scales PCM RMS by five for the voice UI.
            AudioReactiveBorderState.shared.update(microphoneGlowToken, amplitude: Double(level) / 5)
        }
    }

    private func updatePlaybackGlow(speaking: Bool, level: CGFloat) {
        guard speaking else {
            AudioReactiveBorderState.shared.end(glowToken)
            glowToken = nil
            return
        }
        AudioReactiveBorderState.shared.end(microphoneGlowToken)
        microphoneGlowToken = nil
        if glowToken == nil { glowToken = AudioReactiveBorderState.shared.begin() }
        if let glowToken {
            AudioReactiveBorderState.shared.update(glowToken, amplitude: Double(level) / 5)
        }
    }
}

// MARK: - Transcriber

/// One Scribe realtime session for the whole conversation. The server commits
/// a learner turn after a second of silence (VAD).
enum LivePipelineTranscriptEvent: Sendable {
    case partial(String)
    case committed(String)
}

/// A realtime transcription socket fed 16 kHz mono PCM16.
protocol LivePipelineTranscribing: Sendable {
    var events: AsyncThrowingStream<LivePipelineTranscriptEvent, Error> { get }
    /// Called on the audio capture thread.
    func send(_ pcm: Data)
    func close()
}

/// What the server hands out for one conversation: ElevenLabs Scribe (the
/// session lives in the URL) or Soniox (a temporary key and the start
/// request the app sends first).
struct LivePipelineTranscriberGrant: Sendable {
    let provider: String
    let url: URL
    let token: String?
    let config: Data?
    /// Whether to turn on iOS voice processing; the server decides so it can
    /// be switched off without an app update.
    let echoCancellation: Bool

    init(_ data: Data) throws {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["version"] as? Int == 1,
            object["sampleRate"] as? Int == RealtimeSpeechGrant.sampleRate,
            let urlString = object["url"] as? String,
            let url = URL(string: urlString), url.scheme == "wss"
        else { throw URLError(.badServerResponse) }
        provider = object["provider"] as? String ?? "elevenlabs"
        self.url = url
        token = object["token"] as? String
        echoCancellation = object["echoCancellation"] as? Bool ?? false
        config = try (object["config"] as? [String: Any]).map { try JSONSerialization.data(withJSONObject: $0) }
    }

    /// Only the expected hosts, over TLS, are accepted.
    func connect() throws -> any LivePipelineTranscribing {
        switch provider {
        case "soniox":
            guard url.host() == "stt-rt.soniox.com", let token, !token.isEmpty, let config else {
                throw URLError(.badServerResponse)
            }
            return LivePipelineSonioxTranscriber(url: url, token: token, config: config)
        default:
            guard url.host() == "api.elevenlabs.io" || url.host()?.hasSuffix(".elevenlabs.io") == true else {
                throw URLError(.badServerResponse)
            }
            return LivePipelineTranscriber(url: url)
        }
    }
}

/// ElevenLabs Scribe realtime.
final class LivePipelineTranscriber: LivePipelineTranscribing {
    typealias Event = LivePipelineTranscriptEvent

    let events: AsyncThrowingStream<Event, Error>
    private let socket: URLSessionWebSocketTask
    private let audio: AsyncStream<Data>.Continuation
    private let sender: Task<Void, Never>

    init(url: URL, session: URLSession = .shared) {
        let socket = session.webSocketTask(with: url)
        self.socket = socket
        let (chunks, audio) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .bufferingNewest(200))
        self.audio = audio
        sender = Task {
            for await chunk in chunks {
                let message = "{\"message_type\":\"input_audio_chunk\",\"audio_base_64\":\""
                    + chunk.base64EncodedString()
                    + "\",\"commit\":false,\"sample_rate\":\(RealtimeSpeechGrant.sampleRate)}"
                do { try await socket.send(.string(message)) } catch { return }
            }
        }
        events = AsyncThrowingStream { continuation in
            let receiver = Task {
                do {
                    while !Task.isCancelled {
                        let data: Data
                        switch try await socket.receive() {
                        case .string(let text): data = Data(text.utf8)
                        case .data(let bytes): data = bytes
                        @unknown default: continue
                        }
                        guard let event = try? JSONDecoder().decode(Message.self, from: data) else { continue }
                        switch event.message_type {
                        case "partial_transcript":
                            continuation.yield(.partial(event.text ?? ""))
                        case "committed_transcript":
                            continuation.yield(.committed(event.text ?? ""))
                        case "session_started", "warning", "insufficient_audio_activity",
                             "committed_transcript_with_timestamps":
                            continue
                        default:
                            if event.error != nil { throw URLError(.cannotParseResponse) }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in receiver.cancel() }
        }
        socket.resume()
    }

    /// 16 kHz mono PCM16. Called on the audio capture thread.
    func send(_ pcm: Data) {
        audio.yield(pcm)
    }

    func close() {
        audio.finish()
        sender.cancel()
        socket.cancel(with: .normalClosure, reason: nil)
    }

    private struct Message: Decodable {
        let message_type: String
        let text: String?
        let error: String?
    }
}

/// Soniox realtime: audio goes as binary PCM16 frames after the start request.
/// Final tokens arrive once each; the provisional tail is resent whole every
/// time. The `<end>` token closes the learner's turn.
final class LivePipelineSonioxTranscriber: LivePipelineTranscribing {
    let events: AsyncThrowingStream<LivePipelineTranscriptEvent, Error>
    private let socket: URLSessionWebSocketTask
    private let audio: AsyncStream<Data>.Continuation
    private let sender: Task<Void, Never>

    init(url: URL, token: String, config: Data, session: URLSession = .shared) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let socket = session.webSocketTask(with: request)
        self.socket = socket
        let (chunks, audio) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .bufferingNewest(200))
        self.audio = audio
        sender = Task {
            do {
                try await socket.send(.string(String(decoding: config, as: UTF8.self)))
                for await chunk in chunks { try await socket.send(.data(chunk)) }
                // An empty text frame ends the stream.
                try await socket.send(.string(""))
            } catch {
                return
            }
        }
        events = AsyncThrowingStream { continuation in
            let receiver = Task {
                var finals = ""
                do {
                    while !Task.isCancelled {
                        let data: Data
                        switch try await socket.receive() {
                        case .string(let text): data = Data(text.utf8)
                        case .data(let bytes): data = bytes
                        @unknown default: continue
                        }
                        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { continue }
                        if response.error_type != nil || response.error_code != nil {
                            throw URLError(.cannotParseResponse)
                        }
                        // Progress reports without words are not speech.
                        guard response.tokens?.isEmpty == false else {
                            if response.finished == true { break }
                            continue
                        }
                        var provisional = ""
                        var ended = false
                        for token in response.tokens ?? [] {
                            if token.text == "<end>" {
                                ended = true
                            } else if token.is_final {
                                finals += token.text
                            } else {
                                provisional += token.text
                            }
                        }
                        let heard = (finals + provisional).trimmingCharacters(in: .whitespacesAndNewlines)
                        if ended {
                            continuation.yield(.committed(finals.trimmingCharacters(in: .whitespacesAndNewlines)))
                            finals = ""
                        } else if !heard.isEmpty {
                            continuation.yield(.partial(heard))
                        }
                        if response.finished == true { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in receiver.cancel() }
        }
        socket.resume()
    }

    func send(_ pcm: Data) {
        audio.yield(pcm)
    }

    func close() {
        audio.finish()
        sender.cancel()
        socket.cancel(with: .normalClosure, reason: nil)
    }

    private struct Response: Decodable {
        struct Token: Decodable {
            let text: String
            let is_final: Bool
        }
        let tokens: [Token]?
        let finished: Bool?
        let error_code: Int?
        let error_type: String?
    }
}

// MARK: - Audio

/// The conversation's audio engine: microphone capture converted to 16 kHz
/// PCM16 for the transcriber, and reply playback. Voice processing cancels
/// Kalabaw's echo so the learner can interrupt her. While capture is paused or
/// muted, silence is sent so the realtime session stays alive.
final class LivePipelineAudio: @unchecked Sendable {
    struct Failure: Error {}

    private static let speechFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(RealtimeSpeechGrant.sampleRate),
        channels: 1,
        interleaved: false
    )!

    /// Matches the reply audio, so playback is never resampled.
    static let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    private struct State {
        var capturing = true
        var muted = false
        var failed = false
        var pendingBuffers = 0
        /// Bumped by an interruption, so late callbacks of flushed buffers
        /// are not counted against the next reply.
        var epoch = 0
        var drainWaiters: [CheckedContinuation<Void, Never>] = []
        var input = (frame: MascotSpeechFrame.silent, at: 0.0)
        var output = (frame: MascotSpeechFrame.silent, at: 0.0)
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Rebuilt when the route changes the input format; read on the audio thread.
    private var converter: AVAudioConverter?
    private let converterLock = NSLock()
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let onMicrophone: @Sendable (Data) -> Void
    private var observers: [NSObjectProtocol] = []

    init(echoCancellation: Bool, onMicrophone: @escaping @Sendable (Data) -> Void) throws {
        self.onMicrophone = onMicrophone
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(
                .playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            throw Failure()
        }
        guard session.isInputAvailable else { throw Failure() }

        // Echo cancellation lets the learner cut in while Kalabaw talks on the
        // speaker. Other audio is ducked as little as possible. The
        // simulator's voice processing unit captures and plays silence.
        #if !targetEnvironment(simulator)
        if echoCancellation, (try? engine.inputNode.setVoiceProcessingEnabled(true)) != nil {
            engine.inputNode.voiceProcessingOtherAudioDuckingConfiguration =
                AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
                    enableAdvancedDucking: false, duckingLevel: .min)
        }
        #endif
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: Self.playbackFormat)
        player.installTap(onBus: 0, bufferSize: 1_024, format: Self.playbackFormat, block: playbackBlock)
        do {
            try startEngine()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            player.removeTap(onBus: 0)
            throw Failure()
        }
        // Enabling voice processing, a new headset or a sample-rate change
        // reconfigures the engine, which stops it: restart on the new format
        // and only end the conversation when that fails.
        let restart: @Sendable (Notification) -> Void = { [weak self] _ in
            guard let self else { return }
            do {
                try self.startEngine()
            } catch {
                self.state.withLock { $0.failed = true }
            }
        }
        observers = [
            NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main, using: restart)
        ]
    }

    private func startEngine() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let converter = AVAudioConverter(from: inputFormat, to: Self.speechFormat)
        else { throw Failure() }
        converterLock.withLock { self.converter = converter }
        input.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat, block: captureBlock)
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        player.play()
        Self.routeToSpeakerIfNeeded()
        Self.logger.notice("""
            Live audio started: VP \(input.isVoiceProcessingEnabled, privacy: .public), \
            input \(inputFormat, privacy: .public), output \(self.engine.outputNode.outputFormat(forBus: 0), privacy: .public), \
            route \(AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType.rawValue), privacy: .public), \
            volume \(AVAudioSession.sharedInstance().outputVolume, privacy: .public)
            """)
    }

    private static let logger = Logger(subsystem: "com.kumusta.app", category: "LivePractice")

    /// Voice processing can move playback to the earpiece receiver, where it
    /// is inaudible away from the ear. Headphones are left alone.
    private static func routeToSpeakerIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        guard session.currentRoute.outputs.contains(where: { $0.portType == .builtInReceiver }) else { return }
        try? session.overrideOutputAudioPort(.speaker)
    }

    var capturing: Bool {
        get { state.withLock { $0.capturing } }
        set { state.withLock { $0.capturing = newValue } }
    }

    var muted: Bool {
        get { state.withLock { $0.muted } }
        set { state.withLock { $0.muted = newValue } }
    }

    var failed: Bool { state.withLock { $0.failed } }

    var echoCancelled: Bool { engine.inputNode.isVoiceProcessingEnabled }

    var inputFrame: MascotSpeechFrame { Self.recent(state.withLock { $0.input }) }
    var outputFrame: MascotSpeechFrame { Self.recent(state.withLock { $0.output }) }

    private static func recent(_ sample: (frame: MascotSpeechFrame, at: Double)) -> MascotSpeechFrame {
        ProcessInfo.processInfo.systemUptime - sample.at < 0.25 ? sample.frame : .silent
    }

    func play(pcm16 data: Data) {
        let count = data.count / 2
        guard count > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: Self.playbackFormat, frameCapacity: AVAudioFrameCount(count)),
              let samples = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        data.withUnsafeBytes { raw in
            for index in 0..<count {
                let value = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: index * 2, as: Int16.self))
                samples[index] = Float(value) / 32768
            }
        }
        let epoch = state.withLock { state in
            state.pendingBuffers += 1
            return state.epoch
        }
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.bufferPlayed(epoch: epoch)
        }
    }

    /// Returns once everything scheduled so far has been heard.
    func drained() async {
        await withCheckedContinuation { continuation in
            let ready = state.withLock { state in
                if state.pendingBuffers == 0 { return true }
                state.drainWaiters.append(continuation)
                return false
            }
            if ready { continuation.resume() }
        }
    }

    private func bufferPlayed(epoch: Int) {
        let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            guard state.epoch == epoch else { return [] }
            state.pendingBuffers = max(0, state.pendingBuffers - 1)
            guard state.pendingBuffers == 0 else { return [] }
            defer { state.drainWaiters = [] }
            return state.drainWaiters
        }
        waiters.forEach { $0.resume() }
    }

    /// Silences the reply immediately and drops what is still queued.
    func interrupt() {
        player.stop()
        releaseDrainWaiters()
        player.play()
    }

    private func releaseDrainWaiters() {
        let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            state.epoch += 1
            state.pendingBuffers = 0
            defer { state.drainWaiters = [] }
            return state.drainWaiters
        }
        waiters.forEach { $0.resume() }
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        player.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        releaseDrainWaiters()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Built here, outside the main actor: a tap closure written inside a
    // @MainActor type inherits its isolation, and Swift 6 then traps when the
    // audio thread calls it.
    private var captureBlock: AVAudioNodeTapBlock {
        { [weak self] buffer, _ in self?.capture(buffer) }
    }

    private var playbackBlock: AVAudioNodeTapBlock {
        { [weak self] buffer, _ in
            let frame = LiveAudioMeter.features(of: buffer)
            let now = ProcessInfo.processInfo.systemUptime
            self?.state.withLock { $0.output = (frame, now) }
        }
    }

    private func capture(_ buffer: AVAudioPCMBuffer) {
        converterLock.lock()
        defer { converterLock.unlock() }
        guard let converter, converter.inputFormat == buffer.format else { return }
        let ratio = Self.speechFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: Self.speechFormat, frameCapacity: capacity) else {
            return
        }
        // The input block runs synchronously inside convert(), on this thread.
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let input = buffer
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, converted.frameLength > 0, let samples = converted.floatChannelData?[0] else {
            return
        }
        let count = Int(converted.frameLength)
        let (listening, now) = state.withLock { ($0.capturing && !$0.muted, ProcessInfo.processInfo.systemUptime) }
        let frame = listening ? LiveAudioMeter.features(of: converted) : .silent
        state.withLock { $0.input = (frame, now) }
        var pcm = Data(count: count * 2)
        if listening {
            pcm.withUnsafeMutableBytes { raw in
                let output = raw.bindMemory(to: Int16.self)
                for index in 0..<count {
                    output[index] = Int16(max(-1, min(1, samples[index])) * Float(Int16.max)).littleEndian
                }
            }
        }
        onMicrophone(pcm)
    }
}
