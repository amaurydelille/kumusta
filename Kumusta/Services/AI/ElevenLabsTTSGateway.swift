import AVFoundation
import CryptoKit
import Foundation
import Supabase

enum TTSGatewayError: LocalizedError, Sendable {
    case invalidText
    case invalidAudio

    var errorDescription: String? {
        switch self {
        case .invalidText:
            L("That phrase cannot be played.")
        case .invalidAudio:
            L("The voice audio could not be loaded.")
        }
    }
}

protocol TagalogTTSProviding: Sendable {
    func audio(
        for text: String,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data

    /// Generates/cache-warms multiple phrases without coupling their audio
    /// bytes into one response. Implementations should treat each phrase as
    /// independently cacheable and tolerate partial failure.
    func prefetch(
        texts: [String],
        speed: PlaybackSpeed
    ) async

    func prefetch(
        texts: [String],
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async

    /// Reads only the local memory/disk cache. Implementations must not
    /// invoke the Edge Function from this method.
    func cachedAudio(
        for text: String,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data?
    func reset() async
}

extension TagalogTTSProviding {
    func audio(
        for text: String,
        speed: PlaybackSpeed
    ) async throws -> Data {
        try await audio(for: text, speed: speed, purpose: .lesson)
    }

    func prefetch(
        texts: [String],
        speed: PlaybackSpeed
    ) async {
        await prefetch(
            texts: texts,
            speed: speed,
            purpose: .lesson
        )
    }

    func prefetch(
        texts: [String],
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async {
        for text in texts {
            _ = try? await audio(
                for: text,
                speed: speed,
                purpose: purpose
            )
        }
    }

    func cachedAudio(
        for text: String,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data? {
        _ = text
        _ = speed
        _ = purpose
        return nil
    }

    func reset() async {}
}

/// Fetches audio through the authenticated Edge Function. The client never
/// supplies a voice ID, so provider configuration stays server-owned.
actor SupabaseElevenLabsTTSGateway: TagalogTTSProviding {
    private static let maximumCachedItems = 32
    private static let maximumDiskCachedItems = 160
    private static let maximumPrefetchConcurrency = 3
    private static let transientRetryDelay = Duration.milliseconds(650)
    // Keep the local cache version stable. The server-side cache key includes
    // the provider model and settings version, so the first V3 request cannot
    // reuse an older Flash response.
    private static let diskCacheVersion = "elevenlabs-v4"

    private let client: SupabaseClient
    private let authSessionProvider: any AuthSessionProviding
    private let diskCacheDirectory: URL
    private var memoryCache: [String: Data] = [:]
    private var cacheOrder: [String] = []
    private var inFlightRequests: [String: InFlightRequest] = [:]

    private struct InFlightRequest: Sendable {
        let id: UUID
        let task: Task<Data, Error>
    }

    init(client: SupabaseClient, authSessionProvider: any AuthSessionProviding) {
        self.client = client
        self.authSessionProvider = authSessionProvider
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        diskCacheDirectory = caches
            .appendingPathComponent("Kumusta", isDirectory: true)
            .appendingPathComponent("VoiceAudio", isDirectory: true)
    }

    func audio(
        for text: String,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data {
        let (normalizedText, key) = try requestMaterial(
            for: text,
            speed: speed,
            purpose: purpose
        )
        if let cached = memoryCache[key] {
            touchCacheKey(key)
            return cached
        }
        if let cached = loadFromDisk(for: key) {
            insertIntoMemoryCache(cached, for: key)
            return cached
        }
        if let inFlight = inFlightRequests[key] {
            return try await inFlightValue(for: key, request: inFlight)
        }

        let requestID = UUID()
        let request = TTSGatewayRequest(
            text: normalizedText,
            speed: speed.sourceSpeed.rawValue,
            purpose: purpose.rawValue
        )
        let task = Task { [self] in
            try await fetchAndCache(request, key: key)
        }
        inFlightRequests[key] = InFlightRequest(id: requestID, task: task)
        return try await inFlightValue(
            for: key,
            request: InFlightRequest(id: requestID, task: task)
        )
    }

    func prefetch(
        texts: [String],
        speed: PlaybackSpeed
    ) async {
        await prefetch(
            texts: texts,
            speed: speed,
            purpose: .lesson
        )
    }

    func prefetch(
        texts: [String],
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async {
        let uniqueTexts = normalizedUniqueTexts(from: texts)
        guard !uniqueTexts.isEmpty else { return }

        var nextIndex = 0
        await withTaskGroup(of: Void.self) { group in
            while nextIndex < min(Self.maximumPrefetchConcurrency, uniqueTexts.count) {
                let text = uniqueTexts[nextIndex]
                nextIndex += 1
                group.addTask { [self] in
                    _ = try? await audio(
                        for: text,
                        speed: speed,
                        purpose: purpose
                    )
                }
            }

            while await group.next() != nil {
                guard nextIndex < uniqueTexts.count else { continue }
                let text = uniqueTexts[nextIndex]
                nextIndex += 1
                group.addTask { [self] in
                    _ = try? await audio(
                        for: text,
                        speed: speed,
                        purpose: purpose
                    )
                }
            }
        }
    }

    func cachedAudio(
        for text: String,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) async throws -> Data? {
        let (_, key) = try requestMaterial(
            for: text,
            speed: speed,
            purpose: purpose
        )
        if let cached = memoryCache[key] {
            touchCacheKey(key)
            return cached
        }
        guard let cached = loadFromDisk(for: key) else { return nil }
        insertIntoMemoryCache(cached, for: key)
        return cached
    }

    func reset() async {
        inFlightRequests.values.forEach { $0.task.cancel() }
        inFlightRequests.removeAll()
        memoryCache.removeAll()
        cacheOrder.removeAll()

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func requestMaterial(
        for text: String,
        speed: PlaybackSpeed,
        purpose: AudioPlaybackPurpose
    ) throws -> (normalizedText: String, key: String) {
        let normalizedText = SpokenUtterance.playbackText(from: text)
        guard (1 ... 500).contains(normalizedText.count) else {
            throw TTSGatewayError.invalidText
        }
        let sourceSpeed = speed.sourceSpeed
        let purposeSuffix = purpose == .vocabulary ? "|\(purpose.rawValue)" : ""
        return (
            normalizedText,
            "\(sourceSpeed.rawValue)\(purposeSuffix)|\(normalizedText)"
        )
    }

    private func normalizedUniqueTexts(from texts: [String]) -> [String] {
        var seen = Set<String>()
        return texts.compactMap { text in
            let normalized = SpokenUtterance.playbackText(from: text)
            guard
                (1 ... 500).contains(normalized.count),
                seen.insert(normalized).inserted
            else {
                return nil
            }
            return normalized
        }
    }

    private func inFlightValue(
        for key: String,
        request: InFlightRequest
    ) async throws -> Data {
        do {
            let data = try await request.task.value
            removeInFlightRequest(key: key, id: request.id)
            return data
        } catch {
            removeInFlightRequest(key: key, id: request.id)
            throw error
        }
    }

    private func removeInFlightRequest(key: String, id: UUID) {
        guard inFlightRequests[key]?.id == id else { return }
        inFlightRequests.removeValue(forKey: key)
    }

    private func fetchAndCache(
        _ request: TTSGatewayRequest,
        key: String
    ) async throws -> Data {
        // Provider access is valid for the bootstrapped anonymous identity only
        // when the server-side entitlement mirror is active.
        _ = try await authSessionProvider.currentBackendIdentity()

        let data: Data
        do {
            data = try await invokeTTS(request)
        } catch {
            guard Self.isRetryable(error) else { throw error }
            try await Task.sleep(for: Self.transientRetryDelay)
            try Task.checkCancellation()
            data = try await invokeTTS(request)
        }
        insertIntoMemoryCache(data, for: key)
        saveToDisk(data, for: key)
        return data
    }

    private func invokeTTS(_ request: TTSGatewayRequest) async throws -> Data {
        try await client.functions.invoke(
            "kumusta-elevenlabs-tts",
            options: FunctionInvokeOptions(
                body: request,
                // Eleven v3 is more expressive but slower than the previous
                // Flash model.
                timeoutInterval: 30
            ),
            decode: { data, response in
                guard
                    response.value(forHTTPHeaderField: "Content-Type")?
                        .lowercased()
                        .hasPrefix("audio/") == true,
                    data.count > 128
                else {
                    throw TTSGatewayError.invalidAudio
                }
                return data
            }
        )
    }

    private static func isRetryable(_ error: Error) -> Bool {
        if case let FunctionsError.httpError(code, _) = error {
            return code == 502 || code == 503
        }
        guard let urlError = error as? URLError else { return false }
        return urlError.code == .timedOut || urlError.code == .networkConnectionLost
    }

    private func touchCacheKey(_ key: String) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    private func insertIntoMemoryCache(_ data: Data, for key: String) {
        memoryCache[key] = data
        touchCacheKey(key)
        while cacheOrder.count > Self.maximumCachedItems, let oldest = cacheOrder.first {
            cacheOrder.removeFirst()
            memoryCache.removeValue(forKey: oldest)
        }
    }

    private func loadFromDisk(for key: String) -> Data? {
        let url = diskCacheURL(for: key)
        guard let data = try? Data(contentsOf: url), data.count > 128 else { return nil }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date.now],
            ofItemAtPath: url.path
        )
        return data
    }

    private func saveToDisk(_ data: Data, for key: String) {
        do {
            try FileManager.default.createDirectory(
                at: diskCacheDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: diskCacheURL(for: key), options: [.atomic, .completeFileProtection])
            pruneDiskCacheIfNeeded()
        } catch {
            // Voice playback already succeeded. A cache write failure must
            // never turn successful audio into a user-facing error.
        }
    }

    private func diskCacheURL(for key: String) -> URL {
        let digest = SHA256.hash(
            data: Data("\(Self.diskCacheVersion)|\(key)".utf8)
        ).map { String(format: "%02x", $0) }.joined()
        return diskCacheDirectory.appendingPathComponent("\(digest).mp3", isDirectory: false)
    }

    private func pruneDiskCacheIfNeeded() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ), files.count > Self.maximumDiskCachedItems else { return }
        let oldestFirst = files.sorted { left, right in
            let leftDate = try? left.resourceValues(forKeys: keys).contentModificationDate
            let rightDate = try? right.resourceValues(forKeys: keys).contentModificationDate
            return (leftDate ?? .distantPast) < (rightDate ?? .distantPast)
        }
        for url in oldestFirst.prefix(files.count - Self.maximumDiskCachedItems) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private struct TTSGatewayRequest: Encodable {
    let text: String
    let speed: String
    let purpose: String
}

// MARK: - Onboarding first conversation

/// Fixed lines of the pre-paywall first conversation. The server turns each
/// line (plus an optional validated first name) into Tagalog text, so the
/// client can never request arbitrary speech before the paywall.
enum OnboardingConversationLine: String, CaseIterable, Sendable {
    case greeting
    case askName = "ask_name"
    case replyHello = "reply_hello"
    case replyName = "reply_name"
    case askWellbeing = "ask_wellbeing"
    case replyWellbeing = "reply_wellbeing"
    case niceToMeet = "nice_to_meet"

    var usesName: Bool {
        self == .greeting || self == .replyName || self == .niceToMeet
    }

    /// Every line except the name reply has a shared, nameless version.
    var hasGenericVersion: Bool {
        self != .replyName
    }
}

enum OnboardingConversationAudioSource: String, Sendable {
    case personalized
    case generic
    case system
}

/// Fetches the first-conversation clips from the TTS Edge Function, keeps
/// them in memory for replays, and plays them. Personalized clips fall back
/// to the shared generic clip (cached server-side for every learner), then to
/// Apple's Tagalog voice when the device is offline.
@MainActor
final class OnboardingConversationAudio {
    private static let clipWaitTimeout = Duration.seconds(4)

    private let client: SupabaseClient?
    private let authSessionProvider: (any AuthSessionProviding)?
    private let systemVoice = SystemTagalogAudioService()
    private var clips: [String: Task<Data?, Never>] = [:]
    private var delegate = DataPlaybackDelegate()
    private var player: AVAudioPlayer?
    private var glowToken: UUID?

    init(client: SupabaseClient? = nil, authSessionProvider: (any AuthSessionProviding)? = nil) {
        self.client = client
        self.authSessionProvider = authSessionProvider
    }

    /// The first word of the onboarding name, if it is a plain name the
    /// server will accept. Anything else uses the generic wording.
    nonisolated static func spokenFirstName(from rawName: String) -> String? {
        guard let firstWord = rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .first
        else { return nil }
        let name = String(firstWord).precomposedStringWithCanonicalMapping
        guard
            (1 ... 30).contains(name.count),
            name.range(
                of: #"^[\p{L}\p{M}]+(?:['’.-][\p{L}\p{M}]+)*\.?$"#,
                options: .regularExpression
            ) != nil
        else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Starts generating every clip the conversation can need, including the
    /// generic fallbacks, so playback is instant when the learner arrives.
    func prefetch(lines: [OnboardingConversationLine], name: String?) {
        for line in lines {
            if line.usesName, let name {
                _ = clipTask(line: line, name: name)
            }
            if line.hasGenericVersion {
                _ = clipTask(line: line, name: nil)
            }
        }
    }

    /// Plays the best available version of a line and reports which one.
    @discardableResult
    func play(
        line: OnboardingConversationLine,
        text: String,
        name: String?,
    ) async throws -> OnboardingConversationAudioSource {
        if line.usesName, let name,
           let data = await clipData(line: line, name: name) {
            try await play(data: data)
            return .personalized
        }
        if line.hasGenericVersion,
           let data = await clipData(line: line, name: nil) {
            try await play(data: data)
            return .generic
        }
        try await systemVoice.play(text: text, speed: .natural, purpose: .lesson)
        return .system
    }

    func stop() async {
        delegate.gate.finish(false)
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        player = nil
        await systemVoice.stop()
    }

    private func clipData(
        line: OnboardingConversationLine,
        name: String?,
    ) async -> Data? {
        let task = clipTask(line: line, name: name)
        let timeout = Self.clipWaitTimeout
        return await withTaskGroup(of: Data?.self) { group in
            // Waiting is bounded, but the fetch itself keeps running so a slow
            // clip is still ready for the replay button.
            group.addTask { await task.value }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func clipTask(
        line: OnboardingConversationLine,
        name: String?,
    ) -> Task<Data?, Never> {
        let key = "\(line.rawValue)|\(name ?? "")"
        if let existing = clips[key] { return existing }
        let client = client
        let authSessionProvider = authSessionProvider
        let task = Task<Data?, Never> { [weak self] in
            guard let client, let authSessionProvider else { return nil }
            let data = try? await Self.fetchClip(
                client: client,
                authSessionProvider: authSessionProvider,
                body: OnboardingConversationTTSBody(
                    line: line.rawValue,
                    name: name
                )
            )
            // Forget failures so the next request retries instead of
            // replaying a cached miss.
            if data == nil { self?.clips[key] = nil }
            return data
        }
        clips[key] = task
        return task
    }

    private nonisolated static func fetchClip(
        client: SupabaseClient,
        authSessionProvider: any AuthSessionProviding,
        body: OnboardingConversationTTSBody
    ) async throws -> Data {
        do {
            _ = try await authSessionProvider.currentBackendIdentity()
        } catch {
            _ = try await authSessionProvider.bootstrapAnonymousSession()
        }
        return try await client.functions.invoke(
            "kumusta-elevenlabs-tts",
            options: FunctionInvokeOptions(body: body, timeoutInterval: 20),
            decode: { data, response in
                guard
                    response.value(forHTTPHeaderField: "Content-Type")?
                        .lowercased()
                        .hasPrefix("audio/") == true,
                    data.count > 128
                else {
                    throw TTSGatewayError.invalidAudio
                }
                return data
            }
        )
    }

    private func play(data: Data) async throws {
        delegate.gate.finish(false)
        player?.stop()
        AudioReactiveBorderState.shared.end(glowToken)
        glowToken = nil
        player = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio)
        try audioSession.setActive(true)

        let delegate = DataPlaybackDelegate()
        self.delegate = delegate
        let audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer.delegate = delegate
        audioPlayer.prepareToPlay()
        delegate.gate.reset()
        // Retain before playing: short clips can finish synchronously.
        player = audioPlayer
        guard audioPlayer.play() else {
            player = nil
            throw BundledAudioError.playbackFailed
        }
        glowToken = AudioReactiveBorderState.shared.follow(audioPlayer)

        let completed = await withTaskCancellationHandler {
            await delegate.gate.wait()
        } onCancel: {
            delegate.gate.finish(false)
        }
        if player === audioPlayer {
            AudioReactiveBorderState.shared.end(glowToken)
            glowToken = nil
            audioPlayer.stop()
            player = nil
        }
        try Task.checkCancellation()
        guard completed else { throw CancellationError() }
    }
}

private struct OnboardingConversationTTSBody: Encodable, Sendable {
    let purpose = "onboarding_conversation"
    let line: String
    let name: String?
}
