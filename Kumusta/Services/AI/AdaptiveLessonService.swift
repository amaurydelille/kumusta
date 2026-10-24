import Foundation
import OSLog
import Supabase

struct PersonalizedLearningContent: Equatable, Sendable {
    let lesson: Lesson
    let vocabulary: [VocabularyItem]
    let generatedLessonID: UUID
    let queueDepth: Int
    let deliveryPriority: Int
}

enum PersonalizedLearningError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case requestRejected
    case generationFailed
    case generationPacingLimit
    case generationDailyLimit

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            L("Your personalized lesson is still warming up.")
        case .requestRejected:
            L("We couldn’t prepare that lesson request. Please try again.")
        case .generationFailed:
            L("We couldn’t prepare that lesson correctly. Tap Try again to retry it.")
        case .generationPacingLimit:
            L("You’re creating lessons quickly. Wait one minute, then try again.")
        case .generationDailyLimit:
            L("You generated too many lessons, wait for tomorrow.")
        }
    }
}

protocol PersonalizedLearningProviding: Sendable {
    func nextContent(for profile: UserProfile) async throws -> PersonalizedLearningContent?
    func preparedContent(for profile: UserProfile, after lessonID: UUID, generatedAfter: Date?, requestedTopic: String?, retry: Bool) async throws -> PersonalizedLearningContent?
    /// Returns already-delivered content without fetching the queue or
    /// registering background generation work.
    func cachedContent(for profile: UserProfile) async -> PersonalizedLearningContent?
    func retryNextContent(for profile: UserProfile) async throws -> PersonalizedLearningContent?
    func requestNextLesson(
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile
    ) async throws
    func completeLesson(
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile
    ) async throws
    func recordGeneratedVocabularyReview(
        vocabularyID: UUID,
        generatedLessonID: UUID,
        rating: ReviewRating,
        profile: UserProfile
    ) async throws
    func reset() async
}

extension PersonalizedLearningProviding {
    func preparedContent(for profile: UserProfile, after lessonID: UUID, generatedAfter: Date?, requestedTopic: String?, retry: Bool) async throws -> PersonalizedLearningContent? {
        if retry { return try await retryNextContent(for: profile) }
        return try await nextContent(for: profile)
    }

    func cachedContent(for profile: UserProfile) async -> PersonalizedLearningContent? {
        _ = profile
        return nil
    }

    func retryNextContent(for profile: UserProfile) async throws -> PersonalizedLearningContent? {
        try await nextContent(for: profile)
    }

    func requestNextLesson(
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile
    ) async throws {
        _ = generatedLessonID
        _ = feedback
        _ = profile
        throw PersonalizedLearningError.requestRejected
    }

    func reset() async {}
}

/// The app sends only bounded learner preferences and enum feedback. Curriculum
/// prompts, model selection, provider credentials, validation, and queue state
/// remain in the authenticated Edge Function.
actor SupabaseAdaptiveLessonService: PersonalizedLearningProviding {
    private let logger = Logger(subsystem: "com.kumusta.app", category: "adaptive-learning-outbox")
    private static let lessonFunctionName = "kumusta-lessons"
    private static let cacheTTL: TimeInterval = 60
    private let client: SupabaseClient
    private let authSessionProvider: any AuthSessionProviding
    private let outbox: AdaptiveLearningOutboxStore
    private var cached: (
        userID: UUID,
        signature: String,
        content: PersonalizedLearningContent,
        fetchedAt: Date
    )?
    private var inFlightFetch: (
        signature: String,
        task: Task<PersonalizedLearningContent?, Error>
    )?

    init(
        client: SupabaseClient,
        authSessionProvider: any AuthSessionProviding,
        outbox: AdaptiveLearningOutboxStore = AdaptiveLearningOutboxStore()
    ) {
        self.client = client
        self.authSessionProvider = authSessionProvider
        self.outbox = outbox
    }

    func reset() async {
        cached = nil
        inFlightFetch?.task.cancel()
        inFlightFetch = nil
        outbox.reset()
    }

    func nextContent(for profile: UserProfile) async throws -> PersonalizedLearningContent? {
        let signature = Self.signature(for: profile)
        if let inFlightFetch, inFlightFetch.signature == signature {
            return try await inFlightFetch.task.value
        }

        let task = Task { try await self.loadNextContent(for: profile, signature: signature) }
        inFlightFetch = (signature, task)
        defer {
            if inFlightFetch?.signature == signature {
                inFlightFetch = nil
            }
        }
        return try await task.value
    }

    func cachedContent(for profile: UserProfile) async -> PersonalizedLearningContent? {
        guard let cached,
              cached.signature == Self.signature(for: profile),
              cached.fetchedAt.timeIntervalSinceNow > -Self.cacheTTL
        else {
            return nil
        }

        guard let identity = try? await authSessionProvider.currentBackendIdentity(),
              cached.userID == identity.id
        else {
            return nil
        }
        return cached.content
    }

    func retryNextContent(for profile: UserProfile) async throws -> PersonalizedLearningContent? {
        try await fetchPreparedContent(for: profile, excluding: nil, generatedAfter: nil, requestedTopic: nil, retry: true)
    }

    func preparedContent(for profile: UserProfile, after lessonID: UUID, generatedAfter: Date?, requestedTopic: String?, retry: Bool) async throws -> PersonalizedLearningContent? {
        try await fetchPreparedContent(for: profile, excluding: lessonID, generatedAfter: generatedAfter, requestedTopic: requestedTopic, retry: retry)
    }

    private func fetchPreparedContent(for profile: UserProfile, excluding lessonID: UUID?, generatedAfter: Date?, requestedTopic: String?, retry: Bool) async throws -> PersonalizedLearningContent? {
        cached = nil
        inFlightFetch?.task.cancel()
        inFlightFetch = nil
        let identity = try await authSessionProvider.currentBackendIdentity()
        do {
            try await flushOutbox(for: identity.id)
        } catch {
            throw Self.presentationError(for: error)
        }
        let response: LessonEngineResponse
        do {
            response = try await client.functions.invoke(
                Self.lessonFunctionName,
                options: FunctionInvokeOptions(
                    body: NextLessonRequest(
                        action: retry ? "retry_generation" : "get_next",
                        requestID: UUID(),
                        clientMaxPromptVersion: 14,
                        profile: AdaptiveLearnerSnapshot(profile: profile),
                        excludingLessonID: lessonID,
                        generatedAfter: generatedAfter.map { ISO8601DateFormatter().string(from: $0) },
                        topicPreference: retry ? requestedTopic : nil
                    ),
                    timeoutInterval: 8
                )
            )
        } catch {
            throw Self.presentationError(for: error)
        }
        guard response.version == 3 else { throw PersonalizedLearningError.invalidResponse }
        guard let remoteLesson = response.lesson else { return nil }
        let content = try Self.map(remoteLesson, queueDepth: response.queueDepth)
        cached = (identity.id, Self.signature(for: profile), content, .now)
        return content
    }

    func requestNextLesson(
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile
    ) async throws {
        cached = nil
        inFlightFetch?.task.cancel()
        inFlightFetch = nil
        let response: CompletionResponse
        do {
            response = try await client.functions.invoke(
                Self.lessonFunctionName,
                options: FunctionInvokeOptions(
                    body: RequestLessonGenerationRequest(
                        action: "request_generation",
                        requestID: UUID(),
                        clientEventID: UUID(),
                        generatedLessonID: generatedLessonID,
                        feedback: feedback.difficulty.rawValue,
                        paceFeedback: feedback.audioPace.rawValue,
                        topicPreference: feedback.nextLessonTopic,
                        profile: AdaptiveLearnerSnapshot(profile: profile)
                    ),
                    timeoutInterval: 12
                )
            )
        } catch {
            throw Self.presentationError(for: error)
        }
        guard response.version == 3, response.accepted else {
            throw PersonalizedLearningError.invalidResponse
        }
    }

    private func loadNextContent(
        for profile: UserProfile,
        signature: String
    ) async throws -> PersonalizedLearningContent? {
        let identity = try await authSessionProvider.currentBackendIdentity()
        if let cached,
           cached.userID == identity.id,
           cached.signature == signature,
           cached.fetchedAt.timeIntervalSinceNow > -Self.cacheTTL {
            // Cached queue content is the fastest path between Today and
            // Practice. Mutations keep retrying without delaying the screen.
            Task { try? await self.flushOutbox(for: identity.id) }
            return cached.content
        }

        // Completion clears the cache, so it must be acknowledged before a
        // new queue entry is fetched. After the backend change this contains
        // database work only; lesson generation runs in the background.
        do {
            try await flushOutbox(for: identity.id)
        } catch {
            throw Self.presentationError(for: error)
        }

        let response: LessonEngineResponse
        do {
            response = try await client.functions.invoke(
                Self.lessonFunctionName,
                options: FunctionInvokeOptions(
                    body: NextLessonRequest(
                        action: "get_next",
                        requestID: UUID(),
                        clientMaxPromptVersion: 14,
                        profile: AdaptiveLearnerSnapshot(profile: profile)
                    ),
                    timeoutInterval: 8
                )
            )
        } catch {
            throw Self.presentationError(for: error)
        }
        try Task.checkCancellation()
        guard response.version == 3 else { throw PersonalizedLearningError.invalidResponse }
        guard let remoteLesson = response.lesson else { return nil }
        let mapped = try Self.map(remoteLesson, queueDepth: response.queueDepth)
        let content = Self.applyingPendingVocabularyReviews(
            outbox.events(for: identity.id),
            to: mapped
        )
        cached = (identity.id, signature, content, .now)
        return content
    }

    func completeLesson(
        generatedLessonID: UUID?,
        feedback: SessionFeedback,
        profile: UserProfile
    ) async throws {
        cached = nil
        inFlightFetch?.task.cancel()
        inFlightFetch = nil
        let identity = try await authSessionProvider.currentBackendIdentity()
        try? await flushOutbox(for: identity.id)
        let event = AdaptiveLearningOutboxEvent.lessonCompletion(
            userID: identity.id,
            generatedLessonID: generatedLessonID,
            feedback: feedback,
            profile: profile
        )
        try outbox.enqueue(event)
        // Persistence is the success boundary for the client. Connectivity can
        // disappear after the learner taps submit; delivery retries later with
        // this exact event ID instead of asking the learner to repeat feedback.
        try? await flushOutbox(for: identity.id)
    }

    func recordGeneratedVocabularyReview(
        vocabularyID: UUID,
        generatedLessonID: UUID,
        rating: ReviewRating,
        profile: UserProfile
    ) async throws {
        cached = nil
        let identity = try await authSessionProvider.currentBackendIdentity()
        try? await flushOutbox(for: identity.id)
        let event = AdaptiveLearningOutboxEvent.vocabularyReview(
            userID: identity.id,
            generatedLessonID: generatedLessonID,
            vocabularyID: vocabularyID,
            rating: Self.remoteRating(rating),
            profile: profile
        )
        try outbox.enqueue(event)
        try? await flushOutbox(for: identity.id)
    }

    private func flushOutbox(for userID: UUID) async throws {
        for event in outbox.events(for: userID) {
            do {
                try await send(event)
                try outbox.remove(id: event.id)
            } catch {
                if let code = Self.discardableOutboxErrorCode(from: error) {
                    // The server has proven this old reference can never become
                    // valid again. Quarantine it so a stale mutation cannot
                    // block every newer completion in the FIFO outbox.
                    logger.error("Discarding permanently stale adaptive event: \(code, privacy: .public)")
                    try outbox.remove(id: event.id)
                    continue
                }
                throw error
            }
        }
    }

    private static func discardableOutboxErrorCode(from error: Error) -> String? {
        guard case let FunctionsError.httpError(_, data) = error,
              let envelope = try? JSONDecoder().decode(EdgeFunctionFailure.self, from: data),
              ["invalid_lesson_completion", "invalid_vocabulary_reference"].contains(envelope.code)
        else { return nil }
        return envelope.code
    }

    private static func presentationError(for error: Error) -> Error {
        guard case let FunctionsError.httpError(status, data) = error else { return error }
        if let envelope = try? JSONDecoder().decode(EdgeFunctionFailure.self, from: data) {
            switch envelope.code {
            case "generation_pacing_limit":
                return PersonalizedLearningError.generationPacingLimit
            case "generation_daily_limit":
                return PersonalizedLearningError.generationDailyLimit
            case "lesson_generation_failed":
                return PersonalizedLearningError.generationFailed
            default:
                break
            }
        }
        if (400 ... 499).contains(status), status != 408 {
            return PersonalizedLearningError.requestRejected
        }
        return error
    }

    private func send(_ event: AdaptiveLearningOutboxEvent) async throws {
        switch event.kind {
        case .lessonCompletion:
            guard let feedback = event.difficultyFeedback,
                  let paceFeedback = event.paceFeedback else {
                throw PersonalizedLearningError.invalidResponse
            }
            let response: CompletionResponse = try await client.functions.invoke(
                Self.lessonFunctionName,
                options: FunctionInvokeOptions(
                    body: CompleteLessonRequest(
                        action: "complete",
                        requestID: UUID(),
                        clientEventID: event.id,
                        generatedLessonID: event.generatedLessonID,
                        feedback: feedback,
                        paceFeedback: paceFeedback,
                        topicPreference: event.nextLessonTopic,
                        profile: event.profile
                    ),
                    timeoutInterval: 12
                )
            )
            guard response.version == 3, response.accepted else {
                throw PersonalizedLearningError.invalidResponse
            }

        case .vocabularyReview:
            guard let generatedLessonID = event.generatedLessonID,
                  let vocabularyID = event.vocabularyID,
                  let rating = event.reviewRating else {
                throw PersonalizedLearningError.invalidResponse
            }
            let response: VocabularyReviewResponse = try await client.functions.invoke(
                Self.lessonFunctionName,
                options: FunctionInvokeOptions(
                    body: GeneratedVocabularyReviewRequest(
                        action: "review_word",
                        requestID: UUID(),
                        clientEventID: event.id,
                        generatedLessonID: generatedLessonID,
                        vocabularyID: vocabularyID,
                        rating: rating,
                        profile: event.profile
                    ),
                    timeoutInterval: 15
                )
            )
            guard response.version == 3, response.accepted else {
                throw PersonalizedLearningError.invalidResponse
            }
        }
    }

    private static func map(
        _ remote: RemoteGeneratedLesson,
        queueDepth: Int
    ) throws -> PersonalizedLearningContent {
        let expectedRoundCount = LessonSessionPlan.roundCount(for: remote.minutes)
        let responseRoundIndexes: Set<Int>
        switch remote.promptVersion {
        case 13...:
            responseRoundIndexes = LessonSessionPlan.hearRespondRoundIndexes(for: expectedRoundCount)
        default:
            responseRoundIndexes = []
        }
        let expectedKinds = (0 ..< expectedRoundCount).flatMap { roundIndex in
            [
                LessonStepKind.coldListen,
                responseRoundIndexes.contains(roundIndex) ? .hearRespond : .decode,
                .speak,
            ]
        }
        let hasCompleteRounds = remote.steps.count == expectedRoundCount * LessonSessionPlan.stagesPerRound
        let roundContentIsAligned = hasCompleteRounds && stride(
            from: 0,
            to: remote.steps.count,
            by: LessonSessionPlan.stagesPerRound
        ).allSatisfy { start in
            let round = remote.steps[start ..< start + LessonSessionPlan.stagesPerRound]
            return Set(round.map(\.tagalog)).count == 1
                && Set(round.map(\.translation)).count == 1
        }
        guard
            remote.schemaVersion == 3,
            remote.promptVersion == 10 || (13 ... 14).contains(remote.promptVersion),
            remote.source == "generated",
            (5 ... 15).contains(remote.minutes),
            (1 ... 5).contains(remote.difficulty),
            GeneratedLessonCopyValidator.isSafeInterfaceText(
                remote.title,
                spokenUtterances: remote.steps.map(\.tagalog)
            ),
            GeneratedLessonCopyValidator.isSafeInterfaceText(
                remote.scenario,
                spokenUtterances: remote.steps.map(\.tagalog)
            ),
            remote.steps.map(\.kind) == expectedKinds,
            roundContentIsAligned,
            remote.steps.enumerated().allSatisfy { index, step in
                let expectedHearRespond = responseRoundIndexes.contains(index / LessonSessionPlan.stagesPerRound)
                    && index % LessonSessionPlan.stagesPerRound == 1
                return expectedHearRespond == (step.hearRespond != nil)
                    && (step.hearRespond == nil || Self.isValidHearRespond(
                        step.hearRespond!,
                        target: step.tagalog,
                        targetTranslation: step.translation
                    ))
            },
            remote.steps.allSatisfy({ (2 ... 5).contains($0.chunks.count) }),
            remote.steps.allSatisfy({ step in
                Self.lexicalGlossesCoverPhrase(step.wordGlosses, phrase: step.tagalog)
                    && step.wordGlosses.allSatisfy { !$0.translation.isEmpty }
            }),
            remote.steps.allSatisfy({
                !SpokenUtterance.hasLeadingSpeakerLabel($0.tagalog)
                    && !SpokenUtterance.hasLeadingSpeakerLabel($0.translation)
            }),
            remote.vocabulary.allSatisfy({
                !SpokenUtterance.hasLeadingSpeakerLabel($0.example)
                    && !SpokenUtterance.hasLeadingSpeakerLabel($0.exampleTranslation)
            }),
            (8 ... 18).contains(remote.vocabulary.count)
        else {
            throw PersonalizedLearningError.invalidResponse
        }

        let lesson = Lesson(
            id: remote.id,
            scenario: remote.scenario,
            minutes: remote.minutes,
            steps: remote.steps.map { step in
                LessonStep(
                    id: step.id,
                    kind: step.kind,
                    prompt: step.prompt,
                    tagalog: step.tagalog,
                    translation: step.translation,
                    chunks: step.chunks.map {
                        PhraseChunk(
                            id: $0.id,
                            tagalog: $0.tagalog,
                            english: $0.english,
                            note: $0.note
                        )
                    },
                    wordGlosses: step.wordGlosses.map {
                        LessonWordGloss(
                            id: $0.id,
                            token: $0.token,
                            translation: $0.translation
                        )
                    },
                    hearRespond: step.hearRespond
                )
            }
        )
        let vocabulary = remote.vocabulary.map {
            VocabularyItem(
                id: $0.id,
                tagalog: $0.tagalog,
                english: $0.english,
                example: $0.example,
                exampleTranslation: $0.exampleTranslation,
                mastery: min(1, max(0, $0.mastery ?? 0.05)),
                nextReviewAt: $0.dueAt.flatMap(parseProviderDate) ?? .now,
                // Generated vocabulary is a recommendation until the learner
                // explicitly saves it from a lesson or vocabulary surface.
                isSaved: false
            )
        }
        return PersonalizedLearningContent(
            lesson: lesson,
            vocabulary: vocabulary,
            generatedLessonID: remote.id,
            queueDepth: max(0, queueDepth),
            deliveryPriority: max(0, remote.queuePriority ?? 0)
        )
    }

    private static func isValidHearRespond(
        _ exercise: HearRespondExercise,
        target: String,
        targetTranslation: String
    ) -> Bool {
        guard
            exercise.options.count == 3,
            let correctOption = exercise.correctOption,
            Set(exercise.options.map(\.id)).count == exercise.options.count,
            !exercise.promptTagalog.isEmpty,
            normalizePhrase(exercise.promptTagalog) == normalizePhrase(target),
            GeneratedLessonCopyValidator.isSafeInterfaceText(exercise.promptTranslation),
            normalizePhrase(exercise.promptTranslation) == normalizePhrase(targetTranslation),
            !SpokenUtterance.hasLeadingSpeakerLabel(exercise.promptTagalog),
            normalizePhrase(correctOption.englishTranslation) == normalizePhrase(targetTranslation),
            Set(exercise.options.map { normalizePhrase($0.englishTranslation) }).count == exercise.options.count,
            exercise.options.allSatisfy({ option in
                !option.englishTranslation.isEmpty &&
                    !SpokenUtterance.hasLeadingSpeakerLabel(option.englishTranslation) &&
                    GeneratedLessonCopyValidator.isSafeInterfaceText(option.englishTranslation)
            })
        else {
            return false
        }
        return true
    }

    private static func normalizePhrase(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "fil_PH"))
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func lexicalGlossesCoverPhrase(
        _ glosses: [RemoteGeneratedWordGloss],
        phrase: String
    ) -> Bool {
        let expectedTokens = phrase
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !glosses.isEmpty, glosses.count <= 40 else { return false }

        var cursor = 0
        for gloss in glosses {
            let glossTokens = gloss.token
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            guard (1 ... 2).contains(glossTokens.count) else { return false }
            guard cursor + glossTokens.count <= expectedTokens.count else { return false }
            for (offset, glossToken) in glossTokens.enumerated() {
                guard normalizedGlossToken(glossToken) == normalizedGlossToken(expectedTokens[cursor + offset]) else {
                    return false
                }
            }
            cursor += glossTokens.count
        }
        return cursor == expectedTokens.count
    }

    private static func normalizedGlossToken(_ value: String) -> String {
        let lowercased = value.lowercased(with: Locale(identifier: "fil_PH"))
        return String(lowercased.unicodeScalars.filter {
            !CharacterSet.punctuationCharacters.contains($0)
                && !CharacterSet.symbols.contains($0)
        })
    }

    private static func applyingPendingVocabularyReviews(
        _ events: [AdaptiveLearningOutboxEvent],
        to content: PersonalizedLearningContent
    ) -> PersonalizedLearningContent {
        var vocabulary = content.vocabulary
        for event in events where
            event.kind == .vocabularyReview
                && event.generatedLessonID == content.generatedLessonID
        {
            guard
                let vocabularyID = event.vocabularyID,
                let rating = event.reviewRating,
                let index = vocabulary.firstIndex(where: { $0.id == vocabularyID })
            else { continue }

            let interval: TimeInterval
            let masteryDelta: Double
            switch rating {
            case "again":
                interval = 30
                masteryDelta = -0.08
            case "almost":
                interval = 86_400
                masteryDelta = 0.03
            case "got_it":
                interval = 345_600
                masteryDelta = 0.12
            default:
                continue
            }
            vocabulary[index].nextReviewAt = event.createdAt.addingTimeInterval(interval)
            vocabulary[index].mastery = min(
                1,
                max(0, vocabulary[index].mastery + masteryDelta)
            )
        }
        return PersonalizedLearningContent(
            lesson: content.lesson,
            vocabulary: vocabulary,
            generatedLessonID: content.generatedLessonID,
            queueDepth: content.queueDepth,
            deliveryPriority: content.deliveryPriority
        )
    }

    private static func parseProviderDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func signature(for profile: UserProfile) -> String {
        [
            profile.goal.rawValue,
            profile.level.rawValue,
            String(profile.adaptiveTargetLevel),
            (profile.challengePreference ?? .balanced).rawValue,
            String(profile.dailyMinutes)
        ].joined(separator: ":")
    }

    private static func remoteRating(_ rating: ReviewRating) -> String {
        switch rating {
        case .again: "again"
        case .almost: "almost"
        case .gotIt: "got_it"
        }
    }
}

enum GeneratedLessonCopyValidator {
    static func isSafeInterfaceText(
        _ value: String,
        spokenUtterances: [String] = []
    ) -> Bool {
        let copy = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.isEmpty else { return false }
        guard !containsTagalogSentence(copy) else { return false }

        let normalizedCopy = normalizedForAnswerLeakage(copy)
        return !spokenUtterances.contains { utterance in
            let normalizedUtterance = normalizedForAnswerLeakage(utterance)
            guard normalizedCopy.count >= 8, normalizedUtterance.count >= 8 else {
                return false
            }
            return normalizedCopy.contains(normalizedUtterance)
                || normalizedUtterance.contains(normalizedCopy)
        }
    }

    /// Mirrors the server's `containsTagalogSentence`: one Tagalog culture
    /// word is fine in English copy, two distinct function words are not.
    private static func containsTagalogSentence(_ value: String) -> Bool {
        let words = value
            .lowercased(with: Locale(identifier: "fil"))
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        return Set(words.filter(tagalogFunctionWords.contains)).count >= 2
    }

    private static let tagalogFunctionWords: Set<String> = [
        "ang", "ng", "mga", "ako", "ikaw", "siya", "kami", "tayo", "kayo", "sila",
        "hindi", "opo", "po", "salamat", "kumusta", "ito", "iyan", "iyon", "dito",
        "doon", "naman", "lang", "rin", "yung", "ninyo", "natin", "namin", "akin",
        "magkano", "saan", "ano", "paano",
    ]

    private static func normalizedForAnswerLeakage(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fil_PH"))
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

private struct NextLessonRequest: Encodable {
    let action: String
    let requestID: UUID
    let clientMaxPromptVersion: Int
    let profile: AdaptiveLearnerSnapshot
    var excludingLessonID: UUID? = nil
    var generatedAfter: String? = nil
    var topicPreference: String? = nil

    enum CodingKeys: String, CodingKey {
        case action, profile
        case requestID = "request_id"
        case clientMaxPromptVersion = "client_max_prompt_version"
        case excludingLessonID = "excluding_lesson_id"
        case generatedAfter = "generated_after"
        case topicPreference = "topic_preference"
    }
}

private struct RequestLessonGenerationRequest: Encodable {
    let action: String
    let requestID: UUID
    let clientEventID: UUID
    let generatedLessonID: UUID?
    let feedback: String
    let paceFeedback: String
    let topicPreference: String?
    let profile: AdaptiveLearnerSnapshot

    enum CodingKeys: String, CodingKey {
        case action, feedback, profile
        case requestID = "request_id"
        case clientEventID = "client_event_id"
        case generatedLessonID = "generated_lesson_id"
        case paceFeedback = "pace_feedback"
        case topicPreference = "topic_preference"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(requestID, forKey: .requestID)
        try container.encode(clientEventID, forKey: .clientEventID)
        if let generatedLessonID {
            try container.encode(generatedLessonID, forKey: .generatedLessonID)
        } else {
            try container.encodeNil(forKey: .generatedLessonID)
        }
        try container.encode(feedback, forKey: .feedback)
        try container.encode(paceFeedback, forKey: .paceFeedback)
        try container.encodeIfPresent(topicPreference, forKey: .topicPreference)
        try container.encode(profile, forKey: .profile)
    }
}

struct CompleteLessonRequest: Encodable {
    let action: String
    let requestID: UUID
    let clientEventID: UUID
    let generatedLessonID: UUID?
    let feedback: String
    let paceFeedback: String
    let topicPreference: String?
    let profile: AdaptiveLearnerSnapshot

    enum CodingKeys: String, CodingKey {
        case action, feedback, profile
        case requestID = "request_id"
        case clientEventID = "client_event_id"
        case generatedLessonID = "generated_lesson_id"
        case paceFeedback = "pace_feedback"
        case topicPreference = "topic_preference"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(requestID, forKey: .requestID)
        try container.encode(clientEventID, forKey: .clientEventID)
        if let generatedLessonID {
            try container.encode(generatedLessonID, forKey: .generatedLessonID)
        } else {
            // The server contract requires this key even for authored lessons.
            // Synthesized Optional encoding omitted it and caused an endless
            // HTTP 400 retry loop at the head of the durable outbox.
            try container.encodeNil(forKey: .generatedLessonID)
        }
        try container.encode(feedback, forKey: .feedback)
        try container.encode(paceFeedback, forKey: .paceFeedback)
        try container.encodeIfPresent(topicPreference, forKey: .topicPreference)
        try container.encode(profile, forKey: .profile)
    }
}

private struct EdgeFunctionFailure: Decodable {
    let code: String
}

private struct GeneratedVocabularyReviewRequest: Encodable {
    let action: String
    let requestID: UUID
    let clientEventID: UUID
    let generatedLessonID: UUID
    let vocabularyID: UUID
    let rating: String
    let profile: AdaptiveLearnerSnapshot

    enum CodingKeys: String, CodingKey {
        case action, rating, profile
        case requestID = "request_id"
        case clientEventID = "client_event_id"
        case generatedLessonID = "generated_lesson_id"
        case vocabularyID = "vocabulary_id"
    }
}

private struct LessonEngineResponse: Decodable {
    let version: Int
    let lesson: RemoteGeneratedLesson?
    let queueDepth: Int

    enum CodingKeys: String, CodingKey {
        case version, lesson
        case queueDepth = "queue_depth"
    }
}

private struct CompletionResponse: Decodable {
    let version: Int
    let accepted: Bool
}

private struct VocabularyReviewResponse: Decodable {
    let version: Int
    let accepted: Bool
}

private struct RemoteGeneratedLesson: Decodable {
    let id: UUID
    let schemaVersion: Int
    let promptVersion: Int
    let model: String
    let source: String
    let title: String
    let scenario: String
    let minutes: Int
    let difficulty: Double
    let steps: [RemoteGeneratedStep]
    let vocabulary: [RemoteGeneratedVocabulary]
    let queuePriority: Int?

    enum CodingKeys: String, CodingKey {
        case id, model, source, title, scenario, minutes, difficulty, steps, vocabulary
        case schemaVersion = "schema_version"
        case promptVersion = "prompt_version"
        case queuePriority = "queue_priority"
    }
}

private struct RemoteGeneratedStep: Decodable {
    let id: UUID
    let kind: LessonStepKind
    let prompt: String
    let tagalog: String
    let translation: String
    let chunks: [RemoteGeneratedChunk]
    let wordGlosses: [RemoteGeneratedWordGloss]
    let hearRespond: HearRespondExercise?

    enum CodingKeys: String, CodingKey {
        case id, kind, prompt, tagalog, translation, chunks
        case wordGlosses = "word_glosses"
        case hearRespond = "hear_respond"
    }
}

private struct RemoteGeneratedWordGloss: Decodable {
    let id: UUID
    let token: String
    let translation: String
}

private struct RemoteGeneratedChunk: Decodable {
    let id: UUID
    let tagalog: String
    let english: String
    let note: String
}

private struct RemoteGeneratedVocabulary: Decodable {
    let id: UUID
    let tagalog: String
    let english: String
    let example: String
    let exampleTranslation: String
    let mastery: Double?
    let dueAt: String?

    enum CodingKeys: String, CodingKey {
        case id, tagalog, english, example, mastery
        case exampleTranslation = "example_translation"
        case dueAt = "due_at"
    }
}
