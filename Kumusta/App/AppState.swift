import Foundation
import Observation
import OSLog
import PostHog

@MainActor
@Observable
final class AppState {
    #if DEBUG
    private static let developmentAccessKey = "kumusta.development.paywall-bypass"
    #endif

    enum LaunchPhase: Equatable {
        case loading
        case onboarding
        case paywall
        case paywallExit
        case accountCreation
        case firstStepsOffer
        case firstSteps
        case main
        case failed(message: String)
    }

    let dependencies: DependencyContainer
    var launchPhase: LaunchPhase = .loading
    var prefersExistingAccountSignIn = false
    var profile: UserProfile
    private(set) var pendingAchievements: [Achievement] = []
    private var hasTrackedAppOpen = false
    private var cloudSyncTask: Task<Void, Never>?
    private var achievementXPSyncTask: Task<Void, Never>?
    private var appSessionID = UUID()
    private var appSessionStartedAt = Date.now
    private var appSessionActive = false
    /// Changes each time an armed rating request reaches a natural break.
    /// RootView observes it and asks StoreKit once the screen is calm.
    private(set) var reviewRequestToken: UUID?

    init(dependencies: DependencyContainer) {
        self.dependencies = dependencies
        self.profile = dependencies.profileRepository.cachedProfile
    }

    func bootstrap() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("paywall") {
            // A simulator paywall preview must undo any earlier debugUnlock
            // stored in this app's sandbox before routing begins.
            UserDefaults.standard.removeObject(forKey: Self.developmentAccessKey)
        }
        if ProcessInfo.processInfo.arguments.contains("debugUnlock") {
            UserDefaults.standard.set(true, forKey: Self.developmentAccessKey)
        }
        if ProcessInfo.processInfo.arguments.contains("badgeDemo") {
            dependencies.achievementStore.reset()
            profile = UserProfile.preview
            pendingAchievements = dependencies.achievementStore.evaluate(
                streak: 0,
                lessonsCompleted: 1,
                wordsMastered: 0,
                hasDonePronunciation: false
            )
            launchPhase = .main
            return
        }
        if ProcessInfo.processInfo.arguments.contains("firstLesson") {
            dependencies.firstStepsCourseStore.reset()
            profile = UserProfile.preview
            launchPhase = .firstSteps
            return
        }
        if ProcessInfo.processInfo.arguments.contains("mainApp") {
            // A simulator shortcut must never display the paid app while its
            // backend session is absent. That split-brain state made every
            // ElevenLabs request silently fall back to the Apple voice.
            if let authSessionProvider = dependencies.authSessionProvider {
                guard let identity = try? await authSessionProvider.currentBackendIdentity(),
                      !identity.isAnonymous
                else {
                    launchPhase = .accountCreation
                    return
                }
                try? await dependencies.purchaseService.configure(
                    appUserID: identity.id.uuidString.lowercased()
                )
            }
            profile = UserProfile(
                id: profile.id,
                name: "Amaury",
                goal: .family,
                dailyMinutes: 7,
                level: .intermediate,
                hasCompletedOnboarding: true,
                currentStreak: dependencies.learningActivityStore.currentStreak(),
                totalWordsLearned: 12,
                avatarSeed: DiceBearAvatar.seed(for: profile.id)
            )
            launchPhase = .main
            return
        }
        let forcePaywall = ProcessInfo.processInfo.arguments.contains("paywall")
        #else
        let forcePaywall = false
        #endif

        do {
            var signedInUser: AuthenticatedUser?
            var backendIdentity: BackendIdentity?
            if let authSessionProvider = dependencies.authSessionProvider {
                do {
                    let identity = try await authSessionProvider.bootstrapAnonymousSession()
                    backendIdentity = identity
                    // Use the Supabase UUID as the PostHog person from the very
                    // first screen, so PostHog funnels join with Supabase rows
                    // and RevenueCat purchases (which use the same app user ID).
                    if identity.isAnonymous {
                        PostHogSDK.shared.identify(identity.id.uuidString.lowercased())
                    }
                    try await dependencies.purchaseService.configure(
                        appUserID: identity.id.uuidString.lowercased()
                    )
                    if !identity.isAnonymous {
                        signedInUser = try await authSessionProvider.currentAuthenticatedUser()
                    }
                } catch {
                    // Onboarding remains available offline. RevenueCat can
                    // still present its configured paywall and exit offer;
                    // account identity is attached when the learner proceeds.
                }
            }
            profile = try await dependencies.profileRepository.loadProfile()
            let actualStreak = dependencies.learningActivityStore.currentStreak()
            if profile.currentStreak != actualStreak {
                profile.currentStreak = actualStreak
                try? await dependencies.profileRepository.saveProfile(profile)
            }
            #if DEBUG
            // The simulator's explicit paywall bypass is a local testing tool.
            // Keep the freshly bootstrapped anonymous backend session attached,
            // but do not force account creation before opening the lesson UI.
            if UserDefaults.standard.bool(forKey: Self.developmentAccessKey) {
                // Use the same deliberate simulator identity as the main-app
                // shortcut instead of exposing whichever onboarding profile
                // happened to be cached by an earlier run.
                profile = UserProfile(
                    id: profile.id,
                    name: "Amaury",
                    goal: .family,
                    dailyMinutes: 7,
                    level: .intermediate,
                    hasCompletedOnboarding: true,
                    currentStreak: dependencies.learningActivityStore.currentStreak(),
                    totalWordsLearned: max(profile.totalWordsLearned, 12),
                    desiredProficiency: profile.desiredProficiency,
                    challengePreference: profile.challengePreference,
                    avatarSeed: profile.avatarSeed ?? DiceBearAvatar.seed(for: profile.id)
                )
                launchPhase = .main
                return
            }
            #endif
            if forcePaywall {
                profile.hasCompletedOnboarding = true
                launchPhase = .paywall
                return
            }
            if let signedInUser {
                await restoreSignedInAccount(signedInUser)
            } else {
                let hasAccess = await hasAppAccess(restoreStorePurchase: true)
                let requiresAccountCreation = dependencies.authSessionProvider != nil &&
                    backendIdentity?.isAnonymous != false
                let hasRecoverableLocalAccount = profile.hasCompletedOnboarding &&
                    backendIdentity.map { $0.id != profile.id } == true

                if !profile.hasCompletedOnboarding {
                    // Onboarding is mandatory: no learner reaches account
                    // creation, the paywall, or the app before finishing it,
                    // whatever the session or entitlement state.
                    launchPhase = .onboarding
                } else if requiresAccountCreation && (hasAccess || hasRecoverableLocalAccount) {
                    // A learner who already started a trial must secure that
                    // anonymous Supabase identity before continuing. A
                    // returning learner whose local profile belongs to a
                    // different UUID must sign back into that existing account
                    // before RevenueCat or private voice services are checked.
                    prefersExistingAccountSignIn = hasRecoverableLocalAccount
                    launchPhase = .accountCreation
                } else if !hasAccess {
                    // Show the value proposition before asking a new learner
                    // to create an account or sign in to an existing paid
                    // account.
                    launchPhase = .paywall
                } else {
                    enterMainExperience()
                }
            }
            if !hasTrackedAppOpen {
                hasTrackedAppOpen = true
                dependencies.analytics.track(.appOpened)
            }
        } catch {
            launchPhase = .failed(message: L("We couldn’t prepare your lesson. Check your connection and try again."))
        }
    }

    func completeOnboarding(_ draft: OnboardingDraft) async {
        profile = UserProfile(
            id: profile.id,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: draft.goal,
            dailyMinutes: draft.dailyMinutes,
            level: draft.level,
            hasCompletedOnboarding: true,
            currentStreak: 0,
            totalWordsLearned: 0,
            avatarSeed: DiceBearAvatar.seed(for: profile.id)
        )
        do {
            try await dependencies.profileRepository.saveProfile(profile)

            // Completion is a durable product milestone. Emit it only after
            // the learner's onboarding profile has been saved successfully;
            // otherwise a failed save would inflate the completion funnel.
            dependencies.analytics.track(
                .onboardingCompleted,
                properties: [
                    "screen_name": "onboarding_first_lesson",
                    "step": "first_lesson",
                    "position": "7",
                    "goal": profile.goal.rawValue,
                    "level": profile.level.rawValue,
                    "daily_minutes": String(profile.dailyMinutes)
                ]
            )
            TikTokAppEvents.trackCompleteTutorial()
            AppsFlyerAppEvents.trackTutorialCompletion(
                success: true,
                tutorialID: "onboarding",
                content: "Kumusta onboarding"
            )
            MetaAppEvents.trackTutorialCompletion(
                success: true,
                tutorialID: "onboarding",
                content: "Kumusta onboarding"
            )

            if let remote = dependencies.signedInRepository {
                let completedAt = Date.now
                try? await remote.syncProfile(
                    profile,
                    onboardingCompletedAt: completedAt
                )
                try? await remote.syncLearningPreferences(from: profile)
                try? await remote.syncOnboarding(
                    OnboardingSyncInput(
                        motivation: profile.goal.commitmentCopy,
                        currentStep: 9,
                        demoCompleted: true,
                        completedAt: completedAt
                    )
                )
                await syncCloudState()
            }
            if let authSessionProvider = dependencies.authSessionProvider,
               let identity = try? await authSessionProvider.currentBackendIdentity(),
               !identity.isAnonymous {
                if await hasAppAccess(restoreStorePurchase: true) {
                    enterMainExperience()
                } else {
                    launchPhase = .paywall
                }
            } else if dependencies.authSessionProvider != nil {
                launchPhase = .paywall
            } else {
                launchPhase = .paywall
            }
        } catch {
            dependencies.analytics.track(
                .onboardingSaveFailed,
                properties: [
                    "screen_name": "onboarding_first_lesson",
                    "step": "first_lesson",
                    "position": "7"
                ]
            )
            launchPhase = .paywall
        }
    }

    func updateProfile(_ updatedProfile: UserProfile) async throws {
        try await dependencies.profileRepository.saveProfile(updatedProfile)
        profile = updatedProfile

        if let remote = dependencies.signedInRepository {
            try? await remote.syncProfile(
                updatedProfile,
                onboardingCompletedAt: updatedProfile.hasCompletedOnboarding ? .now : nil
            )
            try? await remote.syncLearningPreferences(from: updatedProfile)
        }
        scheduleCloudStateSync()
    }

    @discardableResult
    func evaluateAchievements(hasDonePronunciation: Bool = false) -> [Achievement] {
        let newlyUnlocked = dependencies.achievementStore.evaluate(
            streak: profile.currentStreak,
            lessonsCompleted: dependencies.learningJourneyStore.completedLessons.count,
            wordsMastered: profile.totalWordsLearned,
            hasDonePronunciation: hasDonePronunciation
        )
        pendingAchievements.append(contentsOf: newlyUnlocked)
        scheduleCloudStateSync()
        scheduleAchievementXPSync()
        return newlyUnlocked
    }

    var hasPendingAchievements: Bool {
        !pendingAchievements.isEmpty
    }

    func dismissPendingAchievement() {
        guard !pendingAchievements.isEmpty else { return }
        pendingAchievements.removeFirst()
        if pendingAchievements.isEmpty {
            reviewMomentReached()
        }
    }

    /// Records a newly completed subscription. It raises the engagement score
    /// but never asks for a rating on its own. Restores do not call this.
    func markSubscriptionPurchased() {
        dependencies.ratingPromptManager.record(.subscriptionPurchased)
    }

    /// Records a finished activity for the rating policy. Pass
    /// `isAtNaturalBreak` when the learner has already left the session screen.
    func recordReviewSignal(_ signal: ReviewSignal, isAtNaturalBreak: Bool = false) {
        dependencies.ratingPromptManager.record(signal)
        if isAtNaturalBreak {
            reviewMomentReached()
        }
    }

    func recordReviewFriction() {
        dependencies.ratingPromptManager.recordFriction()
    }

    /// Call when the learner returns to a calm screen after a session. If a
    /// recent win armed the rating request, RootView will hand it to StoreKit.
    func reviewMomentReached() {
        guard canPresentReviewRequest else { return }
        reviewRequestToken = UUID()
    }

    var canPresentReviewRequest: Bool {
        launchPhase == .main
            && pendingAchievements.isEmpty
            && dependencies.ratingPromptManager.isArmed
    }

    /// Spends the armed request. Returns true only when the caller should
    /// invoke StoreKit's `requestReview` right now.
    func commitReviewRequest() -> Bool {
        guard canPresentReviewRequest,
              let request = dependencies.ratingPromptManager.commitRequest()
        else { return false }
        reviewRequestToken = nil
        dependencies.analytics.track(
            .appReviewRequested,
            properties: [
                "screen_name": "app",
                "trigger": request.trigger.rawValue,
                "engagement_score": String(Int(request.score.rounded())),
                "active_days": String(request.activeDays),
                "prior_requests": String(request.priorRequests)
            ]
        )
        return true
    }

    /// A completed purchase or restored trial must be followed by account
    /// creation when the entitlement belongs to an anonymous Supabase user.
    /// The account-creation screen upgrades that same user ID, preserving the
    /// RevenueCat entitlement and all anonymous learner data.
    func beginPremiumAccountSetup() async {
        prefersExistingAccountSignIn = false
        if let authSessionProvider = dependencies.authSessionProvider {
            guard let identity = try? await authSessionProvider.currentBackendIdentity() else {
                launchPhase = .accountCreation
                return
            }

            if identity.isAnonymous {
                launchPhase = .accountCreation
                return
            }

            try? await dependencies.purchaseService.configure(
                appUserID: identity.id.uuidString.lowercased()
            )
        }
        enterMainExperience()
    }

    func createAccountForOnboarding(
        email: String,
        password: String,
        name: String = ""
    ) async throws -> AuthSignUpResult {
        guard let authSessionProvider = dependencies.authSessionProvider else {
            throw AuthSessionError.notAuthenticated
        }

        let result: AuthSignUpResult
        if let identity = try? await authSessionProvider.currentBackendIdentity(), identity.isAnonymous {
            let upgradeResult = try await authSessionProvider.upgradeAnonymousAccount(
                email: email,
                password: password
            )
            result = switch upgradeResult {
            case let .signedIn(user): .signedIn(user)
            case let .awaitingEmailConfirmation(address): .awaitingEmailConfirmation(email: address)
            }
        } else {
            result = try await authSessionProvider.signUp(
                email: email,
                password: password
            )
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty, !ProfanityFilter.containsProfanity(trimmedName) {
            profile.name = trimmedName
            try? await dependencies.profileRepository.saveProfile(profile)
        }
        if case let .signedIn(user) = result {
            AppsFlyerAppEvents.setCustomerUserID(user.id)
            TikTokAppEvents.identify(
                externalID: user.id,
                externalUserName: profile.name,
                email: user.email
            )
            TikTokAppEvents.trackRegistration()
            AppsFlyerAppEvents.trackRegistration(method: "email")
            MetaAppEvents.setUserID(user.id)
            MetaAppEvents.trackRegistration(method: "email")
            await restoreSignedInAccount(user)
        }
        return result
    }

    func signInToPaidAccount(email: String, password: String) async throws {
        guard let authSessionProvider = dependencies.authSessionProvider else {
            throw AuthSessionError.notAuthenticated
        }
        let user = try await authSessionProvider.signIn(email: email, password: password)
        AppsFlyerAppEvents.setCustomerUserID(user.id)
        TikTokAppEvents.identify(
            externalID: user.id,
            externalUserName: profile.name,
            email: user.email
        )
        TikTokAppEvents.trackLogin()
        AppsFlyerAppEvents.trackLogin()
        MetaAppEvents.setUserID(user.id)
        MetaAppEvents.trackLogin()
        await restoreSignedInAccount(user)
    }

    private func beginOnboarding(for user: AuthenticatedUser) async {
        try? await dependencies.purchaseService.configure(
            appUserID: user.id.uuidString.lowercased()
        )
        profile = UserProfile(
            id: user.id,
            name: "",
            goal: .family,
            dailyMinutes: 7,
            level: .beginner,
            hasCompletedOnboarding: false,
            currentStreak: 0,
            totalWordsLearned: 0,
            avatarSeed: DiceBearAvatar.seed(for: user.id)
        )
        try? await dependencies.profileRepository.saveProfile(profile)
        launchPhase = .onboarding
    }

    private func identifyPostHogUser(_ user: AuthenticatedUser) {
        var personProperties: [String: Any] = [:]
        if let email = user.email, !email.isEmpty {
            personProperties["email"] = email
        }
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            personProperties["name"] = name
        }
        PostHogSDK.shared.identify(
            user.id.uuidString.lowercased(),
            userProperties: personProperties
        )
    }

    private func restoreSignedInAccount(_ user: AuthenticatedUser) async {
        identifyPostHogUser(user)
        AppsFlyerAppEvents.setCustomerUserID(user.id)
        MetaAppEvents.setUserID(user.id)
        try? await dependencies.purchaseService.configure(
            appUserID: user.id.uuidString.lowercased()
        )
        // Flush onboarding/app-open events that were queued while the learner
        // was anonymous now that the stable account identity is available.
        dependencies.analytics.flush()

        let remoteProfile: RemoteProfile?
        do {
            remoteProfile = try await dependencies.signedInRepository?.fetchProfile()
        } catch {
            // A returning account must never be mistaken for a brand-new
            // account when the profile request temporarily fails. Keep a
            // completed local profile, or stop on a retryable error, instead
            // of sending the user through onboarding again.
            if profile.hasCompletedOnboarding {
                if await hasAppAccess(restoreStorePurchase: true) {
                    enterMainExperience()
                } else {
                    launchPhase = .paywall
                }
            } else {
                launchPhase = .failed(message: L("We couldn’t load your account yet. Please try again."))
            }
            return
        }

        let remoteState: CloudUserState?
        do {
            remoteState = try await dependencies.signedInRepository?.fetchUserState()
        } catch {
            // Do not migrate a possibly stale device cache when the cloud
            // state request failed. The next foreground refresh can retry.
            if profile.hasCompletedOnboarding {
                if await hasAppAccess(restoreStorePurchase: true) {
                    enterMainExperience()
                } else {
                    launchPhase = .paywall
                }
            } else {
                launchPhase = .failed(message: L("We couldn’t load your account yet. Please try again."))
            }
            return
        }

        if let remoteState {
            await applyCloudState(remoteState, userID: user.id)
            try? await dependencies.profileRepository.saveProfile(profile)
            await repairMissingRemoteProfile()
            scheduleCloudStateSync()
            if profile.hasCompletedOnboarding {
                if await hasAppAccess(restoreStorePurchase: true) {
                    enterMainExperience()
                } else {
                    launchPhase = .paywall
                }
            } else {
                launchPhase = .onboarding
            }
            return
        }

        if let remoteProfile, remoteProfile.onboardingCompletedAt != nil {
            // A profile row without a state row belongs to an older build (or
            // a newly created account). Only migrate local data when its
            // profile is already stamped with this exact account ID; otherwise
            // never mix another account's device cache into this account.
            if profile.hasCompletedOnboarding, profile.id == user.id {
                profile = profileWithID(user.id)
            } else {
                await discardLocalLearnerCache()
                profile = UserProfile(
                    id: user.id,
                    name: remoteProfile.displayName ?? "",
                    goal: .family,
                    dailyMinutes: 7,
                    level: .intermediate,
                    hasCompletedOnboarding: true,
                    currentStreak: dependencies.learningActivityStore.currentStreak(),
                    totalWordsLearned: 0,
                    avatarSeed: remoteProfile.avatarSeed ?? DiceBearAvatar.seed(for: user.id)
                )
            }
            try? await dependencies.profileRepository.saveProfile(profile)
            try? await dependencies.signedInRepository?.syncProfile(
                profile,
                onboardingCompletedAt: .now
            )
            try? await dependencies.signedInRepository?.syncLearningPreferences(from: profile)
            await syncCloudState()
            if await hasAppAccess(restoreStorePurchase: true) {
                enterMainExperience()
            } else {
                launchPhase = .paywall
            }
            return
        }

        // Email/password sign-in uses the existing account UUID. Preserve a
        // completed local onboarding profile when the remote account has not
        // been populated yet, instead of sending the learner through setup a
        // second time.
        if profile.hasCompletedOnboarding {
            // This is the first migration of a pre-cloud local account. The
            // same snapshot is immediately written under the authenticated
            // Supabase user ID, so a later device can restore it.
            profile = profileWithID(user.id)
            try? await dependencies.profileRepository.saveProfile(profile)
            await repairMissingRemoteProfile()
            await syncCloudState()
            if await hasAppAccess(restoreStorePurchase: true) {
                enterMainExperience()
            } else {
                launchPhase = .paywall
            }
            return
        }

        await discardLocalLearnerCache()
        await beginOnboarding(for: user)
    }

    func showAccountCreation() {
        prefersExistingAccountSignIn = false
        launchPhase = .accountCreation
    }

    private func hasAppAccess(restoreStorePurchase: Bool = false) async -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Self.developmentAccessKey) {
            return true
        }
        #endif
        if await dependencies.purchaseService.hasPremiumAccess() {
            return true
        }

        if restoreStorePurchase, (try? await dependencies.purchaseService.restore(source: "account_recovery")) == true {
            return true
        }

        guard let signedInRepository = dependencies.signedInRepository,
              let entitlement = try? await signedInRepository.fetchEntitlement(
                  id: dependencies.configuration.entitlementID
              )
        else {
            return false
        }
        return entitlement.isActive &&
            (entitlement.expiresAt == nil || entitlement.expiresAt ?? .distantPast > .now)
    }

    func unlockApp() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: Self.developmentAccessKey)
        #endif
        enterMainExperience()
    }

    func startFirstSteps() {
        dependencies.firstStepsCourseStore.start()
        scheduleCloudStateSync()
        launchPhase = .firstSteps
    }

    func markFirstStepsOfferSeen() {
        dependencies.firstStepsCourseStore.markOfferSeen()
        scheduleCloudStateSync()
    }

    func skipFirstSteps() {
        dependencies.firstStepsCourseStore.skip()
        scheduleCloudStateSync()
        launchPhase = .main
    }

    func finishFirstSteps() {
        launchPhase = .main
    }

    /// Presents the intentional exit path after the learner closes the
    /// subscription paywall.
    func showPaywallExit() {
        launchPhase = .paywallExit
    }

    func returnToPaywall() {
        launchPhase = .paywall
    }

    /// Flushes the current learner to Supabase before signing out, then clears
    /// the device cache. The cloud row remains available on another device.
    func signOut() async {
        await syncCloudState()
        PostHogSDK.shared.reset()
        TikTokAppEvents.logout()
        MetaAppEvents.logout()
        try? await dependencies.authSessionProvider?.signOut()
        // RevenueCat keeps its own login. Without this, a purchase made by the
        // next learner on this device lands on the account that just left.
        await dependencies.purchaseService.logOut()
        if let authSessionProvider = dependencies.authSessionProvider,
           let identity = try? await authSessionProvider.bootstrapAnonymousSession() {
            try? await dependencies.purchaseService.configure(
                appUserID: identity.id.uuidString.lowercased()
            )
        }
        // The device cache is wiped, so the next learner starts with the
        // mandatory onboarding; an existing account can sign in after it.
        await clearLocalLearnerState(nextPhase: .onboarding)
    }

    /// Permanently deletes the current Kumusta account through the
    /// authenticated account-data Edge Function. This includes the anonymous
    /// Auth identity created automatically for a learner who has not yet
    /// registered. A fresh anonymous session is prepared after deletion so the
    /// app can continue to be used without resurrecting the deleted account.
    func deleteAccount() async throws {
        guard let accountDataService = dependencies.accountDataService else {
            throw AccountExitError.deletionUnavailable
        }
        _ = try await accountDataService.deleteAccount(
            confirmation: SupabaseAccountDataService.deletionConfirmation
        )
        PostHogSDK.shared.reset()
        await clearLocalLearnerState()

        if let authSessionProvider = dependencies.authSessionProvider,
           let identity = try? await authSessionProvider.bootstrapAnonymousSession() {
            try? await dependencies.purchaseService.configure(
                appUserID: identity.id.uuidString.lowercased()
            )
        }
    }

    /// Removes all private, on-device learner state without changing the
    /// remote account or authentication session. This is intentionally kept
    /// separate from account deletion so the UI cannot mistake a device wipe
    /// for deletion of the account itself.
    func eraseLocalData() async {
        await clearLocalLearnerState()
    }

    func retryBootstrap() async {
        launchPhase = .loading
        await bootstrap()
    }

    /// Re-check the real Supabase session whenever the app returns to the
    /// foreground. A cached local profile or RevenueCat entitlement is not an
    /// authentication token and must never keep private services unlocked.
    func validateAuthenticatedSession() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Self.developmentAccessKey) {
            return
        }
        #endif
        guard [.main, .firstStepsOffer, .firstSteps].contains(launchPhase),
              let authSessionProvider = dependencies.authSessionProvider
        else { return }

        guard let identity = try? await authSessionProvider.currentBackendIdentity(),
              !identity.isAnonymous
        else {
            prefersExistingAccountSignIn = true
            launchPhase = .accountCreation
            return
        }

        try? await dependencies.purchaseService.configure(
            appUserID: identity.id.uuidString.lowercased()
        )
        await repairMissingRemoteProfile()
        scheduleCloudStateSync()
    }

    /// A profile save can fail silently (offline, or a token issued before the
    /// account upgrade). Without the row the server treats the learner as
    /// still onboarding and leaves them off the leaderboard, so restore it
    /// from this device's completed profile.
    private func repairMissingRemoteProfile() async {
        guard profile.hasCompletedOnboarding,
              let remote = dependencies.signedInRepository
        else { return }
        // A failed fetch proves nothing; only a confirmed missing or
        // unfinished row is repaired.
        let remoteProfile: RemoteProfile?
        do {
            remoteProfile = try await remote.fetchProfile()
        } catch {
            return
        }
        guard remoteProfile?.onboardingCompletedAt == nil else { return }
        do {
            try await remote.syncProfile(profile, onboardingCompletedAt: .now)
            try await remote.syncLearningPreferences(from: profile)
        } catch {
            Self.syncLogger.error("Profile repair failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static let syncLogger = Logger(subsystem: "com.kumusta.app", category: "ProfileSync")

    func requireAuthentication() {
        #if DEBUG
        // The explicit simulator unlock intentionally uses an anonymous
        // session. A failed protected request must not kick that development
        // session out of the lesson it is being used to test.
        if UserDefaults.standard.bool(forKey: Self.developmentAccessKey) {
            return
        }
        #endif
        guard [.main, .firstStepsOffer, .firstSteps].contains(launchPhase) else { return }
        prefersExistingAccountSignIn = true
        launchPhase = .accountCreation
    }

    private func discardLocalLearnerCache() async {
        await dependencies.personalizedLearningService?.reset()
        await dependencies.learningRepository.reset()
        await dependencies.audioService.reset()
        dependencies.learningActivityStore.reset()
        dependencies.savedLessonWordStore.reset()
        dependencies.memoryStore.reset()
        dependencies.learningJourneyStore.reset()
        dependencies.lessonProgressStore.reset()
        dependencies.firstStepsCourseStore.reset()
        dependencies.achievementStore.reset()
        pendingAchievements = []
        UserDefaults.standard.removeObject(forKey: AudioPreferences.defaultSpeedKey)
        UserDefaults.standard.removeObject(forKey: AudioPreferences.autoplayKey)
        UserDefaults.standard.removeObject(forKey: LessonEducation.formatSeenKey)
    }

    private func clearLocalLearnerState(nextPhase: LaunchPhase = .onboarding) async {
        await dependencies.personalizedLearningService?.reset()
        await dependencies.learningRepository.reset()
        await dependencies.audioService.reset()
        dependencies.learningActivityStore.reset()
        dependencies.savedLessonWordStore.reset()
        dependencies.memoryStore.reset()
        dependencies.learningJourneyStore.reset()
        dependencies.lessonProgressStore.reset()
        dependencies.firstStepsCourseStore.reset()
        dependencies.achievementStore.reset()
        pendingAchievements = []
        dependencies.notificationService.resetForAccountDeletion()
        dependencies.profileRepository.reset()
        UserDefaults.standard.removeObject(forKey: AudioPreferences.defaultSpeedKey)
        UserDefaults.standard.removeObject(forKey: AudioPreferences.autoplayKey)
        profile = .newUser
        launchPhase = nextPhase
    }

    /// Debounces writes caused by several UI changes in one completion moment.
    /// The device copy remains usable offline; Supabase is the durable source
    /// of truth whenever a verified, non-anonymous session is available.
    func scheduleCloudStateSync() {
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.syncCloudState()
        }
    }

    /// Promotes a learner once every lesson in the currently authored roadmap
    /// has been completed. The current profile level is checked again here so
    /// a stale completion callback cannot promote a different roadmap, and the
    /// local profile is persisted before the in-memory level changes.
    @discardableResult
    func advanceRoadmapLevelIfComplete(
        currentLevel: ProficiencyLevel,
        roadmapLessonIDs: Set<UUID>,
        completedLessonIDs: Set<UUID>
    ) async -> ProficiencyLevel? {
        guard
            profile.level == currentLevel,
            !roadmapLessonIDs.isEmpty,
            roadmapLessonIDs.isSubset(of: completedLessonIDs),
            let nextLevel = currentLevel.nextRoadmapLevel
        else {
            return nil
        }

        var promotedProfile = profile
        promotedProfile.level = nextLevel
        do {
            try await dependencies.profileRepository.saveProfile(promotedProfile)
        } catch {
            return nil
        }

        profile = promotedProfile
        scheduleCloudStateSync()
        return nextLevel
    }

    /// Replays every locally unlocked achievement through the server-side XP
    /// ledger. The idempotency key makes this safe to retry after an offline
    /// completion or an interrupted app session.
    private func scheduleAchievementXPSync() {
        achievementXPSyncTask?.cancel()
        achievementXPSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.syncAchievementXP()
        }
    }

    private func syncAchievementXP() async {
        achievementXPSyncTask = nil
        guard let remote = dependencies.signedInRepository,
              let authSessionProvider = dependencies.authSessionProvider,
              let identity = try? await authSessionProvider.currentBackendIdentity(),
              !identity.isAnonymous
        else { return }

        // The Edge Function verifies the achievement against the durable
        // cloud state before allowing the XP award. Write that state first so
        // a badge earned offline can be retried safely when connectivity
        // returns.
        let state = await makeCloudState(for: identity.id)
        guard (try? await remote.syncUserState(state)) != nil else { return }

        for achievement in dependencies.achievementStore.achievements {
            guard !Task.isCancelled else { return }
            let achievementID = achievement.kind.rawValue
            _ = try? await remote.awardXP(
                XPAwardRequest(
                    reasonCode: "achievement_\(achievementID)",
                    sourceID: achievementID,
                    idempotencyKey: "achievement:\(achievementID)",
                    metadata: [
                        "achievement_id": achievementID,
                        "unlocked_at": ISO8601DateFormatter().string(from: achievement.unlockedAt)
                    ]
                )
            )
        }
    }

    func syncCloudState() async {
        cloudSyncTask = nil
        guard let remote = dependencies.signedInRepository,
              let authSessionProvider = dependencies.authSessionProvider,
              let identity = try? await authSessionProvider.currentBackendIdentity(),
              !identity.isAnonymous
        else { return }

        let state = await makeCloudState(for: identity.id)
        try? await remote.syncUserState(state)
    }

    func beginAppSession() async {
        guard !appSessionActive else { return }
        appSessionActive = true
        appSessionID = UUID()
        appSessionStartedAt = .now
        await syncAppSession(endedAt: nil)
    }

    func endAppSession() async {
        guard appSessionActive else { return }
        appSessionActive = false
        await syncAppSession(endedAt: .now)
    }

    func syncDailyProgress() async {
        guard let remote = dependencies.signedInRepository,
              let authSessionProvider = dependencies.authSessionProvider,
              let identity = try? await authSessionProvider.currentBackendIdentity(),
              !identity.isAnonymous
        else { return }

        let calendar = Calendar.autoupdatingCurrent
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: .now)
        let completedLessonsToday = dependencies.learningJourneyStore.completedLessons.filter {
            calendar.isDate($0.completedAt, inSameDayAs: today)
        }.count
        let input = DailyProgressSyncInput(
            progressDate: formatter.string(from: today),
            activeSeconds: min(86_400, dependencies.learningActivityStore.todayMinutes * 60),
            lessonsCompleted: completedLessonsToday,
            wordsLearned: 0,
            wordsReviewed: 0,
            xp: 0,
            dailyGoalMet: dependencies.learningActivityStore.isTodayComplete
        )
        try? await remote.syncDailyProgress(input)
    }

    private func makeCloudState(for userID: UUID) async -> CloudUserState {
        CloudUserState(
            profile: profileWithID(userID),
            learningJourney: dependencies.learningJourneyStore.snapshot(),
            savedLessonWords: dependencies.savedLessonWordStore.words,
            lessonProgress: dependencies.lessonProgressStore.snapshot(),
            learningActivity: dependencies.learningActivityStore.snapshot(),
            firstSteps: dependencies.firstStepsCourseStore.snapshot(),
            achievements: dependencies.achievementStore.achievements,
            authoredVocabulary: await dependencies.learningRepository.authoredVocabularySnapshot(),
            audioPreferences: AudioPreferences(),
            notificationPreferences: dependencies.notificationService.snapshot(),
            hasClaimedFirstExperiencePrompt: dependencies.ratingPromptManager.hasClaimedFirstExperiencePrompt,
            hasSeenLessonFormatEducation: UserDefaults.standard.bool(forKey: LessonEducation.formatSeenKey),
            memory: dependencies.memoryStore.snapshot()
        )
    }

    private func applyCloudState(_ state: CloudUserState, userID: UUID) async {
        guard state.schemaVersion == CloudUserState.currentSchemaVersion else { return }
        profile = profileWithID(state.profile, userID: userID)
        dependencies.learningJourneyStore.replace(with: state.learningJourney)
        dependencies.savedLessonWordStore.replace(with: state.savedLessonWords)
        dependencies.lessonProgressStore.replace(with: state.lessonProgress)
        dependencies.learningActivityStore.replace(with: state.learningActivity)
        dependencies.firstStepsCourseStore.replace(with: state.firstSteps)
        dependencies.achievementStore.replace(with: state.achievements)
        await dependencies.learningRepository.replaceAuthoredVocabulary(
            with: state.authoredVocabulary
        )
        // Merge rather than replace: a state written by an older build has no
        // memory, and per-card merging keeps the most recent review anywhere.
        dependencies.memoryStore.merge(state.memory)
        dependencies.reconcileMemory()
        UserDefaults.standard.set(
            state.audioPreferences.defaultSpeed.rawValue,
            forKey: AudioPreferences.defaultSpeedKey
        )
        UserDefaults.standard.set(
            state.audioPreferences.autoplay,
            forKey: AudioPreferences.autoplayKey
        )
        dependencies.notificationService.replace(with: state.notificationPreferences)
        dependencies.ratingPromptManager.replaceClaimedState(
            state.hasClaimedFirstExperiencePrompt
        )
        UserDefaults.standard.set(
            state.hasSeenLessonFormatEducation,
            forKey: LessonEducation.formatSeenKey
        )
        pendingAchievements = []
        try? await dependencies.profileRepository.saveProfile(profile)
    }

    private func profileWithID(_ userID: UUID) -> UserProfile {
        profileWithID(profile, userID: userID)
    }

    private func profileWithID(_ source: UserProfile, userID: UUID) -> UserProfile {
        UserProfile(
            id: userID,
            name: source.name,
            goal: source.goal,
            dailyMinutes: source.dailyMinutes,
            level: source.level,
            hasCompletedOnboarding: source.hasCompletedOnboarding,
            currentStreak: source.currentStreak,
            totalWordsLearned: source.totalWordsLearned,
            desiredProficiency: source.desiredProficiency,
            challengePreference: source.challengePreference,
            avatarSeed: source.id == userID
                ? source.avatarSeed ?? DiceBearAvatar.seed(for: userID)
                : DiceBearAvatar.seed(for: userID)
        )
    }

    private func enterMainExperience() {
        if dependencies.firstStepsCourseStore.shouldOffer {
            launchPhase = .firstStepsOffer
        } else {
            launchPhase = .main
        }
        dependencies.ratingPromptManager.noteActiveDay()
        scheduleAchievementXPSync()
        Task { await beginAppSession() }
    }

    private func syncAppSession(endedAt: Date?) async {
        guard let remote = dependencies.signedInRepository,
              let authSessionProvider = dependencies.authSessionProvider,
              let identity = try? await authSessionProvider.currentBackendIdentity(),
              !identity.isAnonymous
        else { return }

        let activeSeconds = min(
            86_400,
            max(0, Int((endedAt ?? .now).timeIntervalSince(appSessionStartedAt)))
        )
        let input = AppSessionSyncInput(
            clientSessionID: appSessionID,
            startedAt: appSessionStartedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )
        _ = try? await remote.syncAppSession(input)
    }

    #if DEBUG
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: Self.developmentAccessKey)
        dependencies.profileRepository.reset()
        dependencies.firstStepsCourseStore.reset()
        profile = .newUser
        launchPhase = .onboarding
    }
    #endif
}

enum AccountExitError: LocalizedError {
    case deletionUnavailable

    var errorDescription: String? {
        switch self {
        case .deletionUnavailable:
            L("Account deletion is temporarily unavailable. Please try again when you’re connected to the internet.")
        }
    }
}
