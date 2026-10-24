import Foundation
import Observation

@MainActor
@Observable
final class DependencyContainer {
    let configuration: AppConfiguration
    var goalCurriculum: (any GoalCurriculumProviding)?
    var livePracticeGateway: LivePracticeGateway?
    let profileRepository: any ProfileRepository
    let learningRepository: any LearningRepository
    let purchaseService: any PurchaseService
    let audioService: any AudioService
    let offlineAudioService: any AudioService
    let onboardingDemoAudioService: any OnboardingDemoAudioService
    let onboardingConversationAudio: OnboardingConversationAudio
    let analytics: any AnalyticsTracking
    let authSessionProvider: (any AuthSessionProviding)?
    let signedInRepository: (any SignedInKumustaSyncing)?
    let speechRecognitionService: (any TagalogSpeechRecognizing)?
    let personalizedLearningService: (any PersonalizedLearningProviding)?
    let accountDataService: (any AccountDataServicing)?
    let savedLessonWordStore: SavedLessonWordStore
    let memoryStore: MemoryStore
    let learningJourneyStore: LearningJourneyStore
    let lessonProgressStore: LessonProgressStore
    let learningActivityStore: LocalLearningActivityStore
    let achievementStore: AchievementStore
    let firstStepsCourseStore: FirstStepsCourseStore
    let ratingPromptManager: RatingPromptManager
    let notificationService: NotificationService

    init(
        configuration: AppConfiguration,
        profileRepository: any ProfileRepository,
        learningRepository: any LearningRepository,
        purchaseService: any PurchaseService,
        audioService: any AudioService,
        offlineAudioService: (any AudioService)? = nil,
        onboardingDemoAudioService: any OnboardingDemoAudioService,
        onboardingConversationAudio: OnboardingConversationAudio? = nil,
        analytics: any AnalyticsTracking,
        authSessionProvider: (any AuthSessionProviding)? = nil,
        signedInRepository: (any SignedInKumustaSyncing)? = nil,
        speechRecognitionService: (any TagalogSpeechRecognizing)? = nil,
        personalizedLearningService: (any PersonalizedLearningProviding)? = nil,
        accountDataService: (any AccountDataServicing)? = nil,
        savedLessonWordStore: SavedLessonWordStore = SavedLessonWordStore(),
        memoryStore: MemoryStore = MemoryStore(),
        learningJourneyStore: LearningJourneyStore = LearningJourneyStore(),
        lessonProgressStore: LessonProgressStore = LessonProgressStore(),
        learningActivityStore: LocalLearningActivityStore = LocalLearningActivityStore(),
        achievementStore: AchievementStore = AchievementStore(),
        firstStepsCourseStore: FirstStepsCourseStore = FirstStepsCourseStore(),
        ratingPromptManager: RatingPromptManager = RatingPromptManager(),
        notificationService: NotificationService = NotificationService()
    ) {
        self.configuration = configuration
        self.profileRepository = profileRepository
        self.learningRepository = learningRepository
        self.purchaseService = purchaseService
        self.audioService = audioService
        self.offlineAudioService = offlineAudioService ?? audioService
        self.onboardingDemoAudioService = onboardingDemoAudioService
        self.onboardingConversationAudio = onboardingConversationAudio ?? OnboardingConversationAudio()
        self.analytics = analytics
        self.authSessionProvider = authSessionProvider
        self.signedInRepository = signedInRepository
        self.speechRecognitionService = speechRecognitionService
        self.personalizedLearningService = personalizedLearningService
        self.accountDataService = accountDataService
        self.savedLessonWordStore = savedLessonWordStore
        self.memoryStore = memoryStore
        self.learningJourneyStore = learningJourneyStore
        self.lessonProgressStore = lessonProgressStore
        self.learningActivityStore = learningActivityStore
        learningActivityStore.reconcile(with: learningJourneyStore.completedLessons)
        self.achievementStore = achievementStore
        self.firstStepsCourseStore = firstStepsCourseStore
        self.ratingPromptManager = ratingPromptManager
        self.notificationService = notificationService

        // Everything already learned joins the review deck, including what
        // was learned before the deck existed; later lessons and saved words
        // join the moment they happen.
        reconcileMemory()
        learningJourneyStore.configureCompletionObserver { [memoryStore] record in
            memoryStore.enroll(
                lesson: record.lesson,
                at: record.completedAt
            )
        }
        savedLessonWordStore.configureMemoryEnrollment { [memoryStore] word in
            memoryStore.enroll(savedWord: word)
        }

        self.savedLessonWordStore.configureAudioPrewarming { [audioService] word in
            let speed = AudioPreferences().defaultSpeed
            Task {
                await audioService.prewarm(
                    texts: [word.word],
                    speed: speed,
                    purpose: .vocabulary
                )
            }
        }
    }

    /// Re-derives review cards from lesson history and saved words, e.g.
    /// after an account restore replaced them.
    func reconcileMemory() {
        memoryStore.reconcile(
            completedLessons: learningJourneyStore.completedLessons,
            savedWords: savedLessonWordStore.words
        )
    }

    static func live(bundle: Bundle = .main) -> DependencyContainer {
        #if DEBUG
        // UI tests must remain deterministic and must never spend provider
        // quota or wait on external auth/LLM/TTS services.
        if ProcessInfo.processInfo.arguments.contains("-UITestScenario") {
            return preview()
        }
        #endif

        let configuration = AppConfiguration(bundle: bundle)
        let analytics = AppAnalytics()
        let purchaseService = RevenueCatPurchaseService(
            configuration: configuration,
            analytics: analytics
        )
        let fallbackAudio = SystemTagalogAudioService()
        let bundledOnboardingAudio = BundledOnboardingAudioService(bundle: bundle)

        guard
            configuration.hasSupabaseConfiguration,
            let supabase = try? SupabaseClientProvider(configuration: configuration)
        else {
            return DependencyContainer(
                configuration: configuration,
                profileRepository: LocalFirstProfileRepository(configuration: configuration),
                learningRepository: SeededLearningRepository(),
                purchaseService: purchaseService,
                audioService: fallbackAudio,
                offlineAudioService: fallbackAudio,
                onboardingDemoAudioService: bundledOnboardingAudio,
                analytics: analytics
            )
        }

        let authSessionProvider = SupabaseAuthSessionProvider(client: supabase.client)
        let signedInRepository = SupabaseSignedInRepository(
            client: supabase.client,
            authSessionProvider: authSessionProvider
        )
        analytics.attachRemoteRepository(signedInRepository)
        let ttsGateway = SupabaseElevenLabsTTSGateway(
            client: supabase.client,
            authSessionProvider: authSessionProvider
        )
        let productionAudio = AuthenticatedElevenLabsAudioService(gateway: ttsGateway)
        #if DEBUG
        let lessonAudio: any AudioService = (
            ProcessInfo.processInfo.arguments.contains("debugUnlock")
                || UserDefaults.standard.bool(forKey: "kumusta.development.paywall-bypass")
        )
            ? ResilientAudioService(primary: productionAudio, fallback: fallbackAudio)
            : productionAudio
        #else
        let lessonAudio: any AudioService = productionAudio
        #endif
        let container = DependencyContainer(
            configuration: configuration,
            profileRepository: LocalFirstProfileRepository(configuration: configuration),
            learningRepository: SeededLearningRepository(),
            purchaseService: purchaseService,
            // A regional learning voice must never be silently replaced by
            // Apple's generic Tagalog synthesizer. Provider failures stay
            // visible and retryable instead of teaching the wrong speaker.
            audioService: lessonAudio,
            offlineAudioService: fallbackAudio,
            onboardingDemoAudioService: bundledOnboardingAudio,
            onboardingConversationAudio: OnboardingConversationAudio(
                client: supabase.client,
                authSessionProvider: authSessionProvider
            ),
            analytics: analytics,
            authSessionProvider: authSessionProvider,
            signedInRepository: signedInRepository,
            speechRecognitionService: FallbackSpeechRecognitionService(
                primary: SupabaseElevenLabsSpeechRecognitionService(
                    client: supabase.client,
                    authSessionProvider: authSessionProvider
                ),
                fallback: AppleSpeechRecognitionService()
            ),
            personalizedLearningService: SupabaseAdaptiveLessonService(
                client: supabase.client,
                authSessionProvider: authSessionProvider
            ),
            accountDataService: SupabaseAccountDataService(
                client: supabase.client,
                authSessionProvider: authSessionProvider
            )
        )
        container.livePracticeGateway = LivePracticeGateway(client: supabase.client, configuration: configuration)
        container.goalCurriculum = SupabaseGoalCurriculum(client: supabase.client)
        return container
    }

    static func preview() -> DependencyContainer {
        let bundledOnboardingAudio = PreviewOnboardingAudioService()
        let container = DependencyContainer(
            configuration: .preview,
            profileRepository: LocalFirstProfileRepository(configuration: .preview),
            learningRepository: SeededLearningRepository(),
            purchaseService: PreviewPurchaseService(),
            audioService: PreviewAudioService(),
            onboardingDemoAudioService: bundledOnboardingAudio,
            analytics: AppAnalytics(),
            speechRecognitionService: PreviewSpeechRecognitionService(),
            accountDataService: PreviewAccountDataService()
        )
        container.goalCurriculum = PreviewGoalCurriculum()
        return container
    }
}
