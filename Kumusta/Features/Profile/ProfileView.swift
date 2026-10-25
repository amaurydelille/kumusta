import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies
    @State private var isEditingProfile = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var isShowingEraseConfirmation = false
    @State private var isShowingAccountDeletionConfirmation = false
    @State private var isShowingSignOutConfirmation = false
    @State private var isShowingCancellationFlow = false
    @State private var isShowingSubscriptionManagement = false
    @State private var hasPremiumAccess = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var accountDeletionMessage: ProfileAccountDeletionMessage?
    @AppStorage(AudioPreferences.defaultSpeedKey)
    private var defaultSpeed = AudioPreferences.fallbackSpeed.rawValue
    @AppStorage(AudioPreferences.autoplayKey)
    private var autoplayAudio = AudioPreferences.fallbackAutoplay
    @AppStorage(SoundEffectsVolume.storageKey)
    private var soundEffectsVolume = SoundEffectsVolume.fallback
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        identityCard
                        leaderboardCard
                        firstStepsCard
                        weeklyProgress
                        achievements
                        lessonHistory
                        learningPreferences
                        notificationPreferences
                        audioPreferences
                        appearancePreferences
                        dataAndSupport
                        membership
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                    .screenContentWidth()
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                activity.reconcile(with: dependencies.learningJourneyStore.completedLessons)
            }
            .onChange(of: defaultSpeed) { _, value in trackSetting("playback_speed", value: value) }
            .onChange(of: autoplayAudio) { _, value in trackSetting("autoplay", value: String(value)) }
            .onChange(of: appearance) { _, value in trackSetting("appearance", value: value) }
            .sheet(isPresented: $isEditingProfile) {
                ProfileEditorView(profile: appState.profile) { updated in
                    try await appState.updateProfile(updated)
                    dependencies.analytics.track(.profileUpdated, properties: ["screen_name": "profile_editor", "goal": updated.goal.rawValue, "level": updated.level.rawValue, "daily_minutes": String(updated.dailyMinutes)])
                }
                .onAppear { dependencies.analytics.track(.screenViewed, properties: ["screen_name": "profile_editor"]) }
            }
            .sheet(isPresented: $isShowingCancellationFlow) {
                SubscriptionCancellationFlowView()
            }
            .sheet(isPresented: $isShowingSubscriptionManagement) {
                SubscriptionManagementView { restored in
                    if restored { hasPremiumAccess = true }
                }
            }
            .task(id: isShowingSubscriptionManagement) {
                // Re-read after Customer Center closes: a cancellation or
                // refund made there can end premium access.
                guard !isShowingSubscriptionManagement else { return }
                hasPremiumAccess = await dependencies.purchaseService.hasPremiumAccess()
            }
            .alert(L("Erase app data?"), isPresented: $isShowingEraseConfirmation) {
                Button(L("Cancel"), role: .cancel) {}
                Button(L("Erase data"), role: .destructive) {
                    Task { await appState.eraseLocalData() }
                }
            } message: {
                Text(L("This removes your profile and locally saved learning activity from this device. It cannot be undone."))
            }
            .confirmationDialog(
                L("Delete your Kumusta account?"),
                isPresented: $isShowingAccountDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button(L("Delete account permanently"), role: .destructive) {
                    deleteAccount()
                }
                Button(L("Keep my account"), role: .cancel) {}
            } message: {
                Text(L("This permanently removes your account, learning progress, and associated data. Your Apple subscription is managed separately and may continue to renew."))
            }
            .alert(item: $accountDeletionMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.detail),
                    dismissButton: .default(Text(L("OK")))
                )
            }
            .confirmationDialog(
                L("Sign out of Kumusta?"),
                isPresented: $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button(L("Sign out")) {
                    signOut()
                }
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                Text(L("This signs you out on this device and clears local learning activity. You can sign in again to access your account."))
            }
        }
    }

    private func trackAction(_ action: String) {
        dependencies.analytics.track(.featureAction, properties: ["screen_name": "profile", "step": action])
    }

    private func trackSetting(_ key: String, value: String) {
        dependencies.analytics.track(.settingChanged, properties: ["screen_name": "profile", "step": key, "value": value])
    }

    private var identityCard: some View {
        HStack(spacing: 18) {
            UserAvatar(
                userID: appState.profile.id,
                persistedSeed: appState.profile.avatarSeed,
                fallbackText: AvatarFallback.initials(from: appState.profile.name),
                size: 98
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(L("PROFILE"))
                    .font(.body.bold())
                    .fontDesign(.rounded)
                    .tracking(1)
                    .foregroundStyle(KumustaColors.accentDeep)
                Text(displayName)
                    .font(KumustaTypography.title)
                    .foregroundStyle(KumustaColors.ink)
                    .lineLimit(2)
                Label(L("Everyday Tagalog"), systemImage: "waveform")
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(KumustaColors.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                ShareLink(
                    item: shareText,
                    subject: Text(L("My Kumusta progress")),
                    message: Text(shareText)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .scaledFont(18, weight: .bold)
                        .foregroundStyle(KumustaColors.ink)
                        .frame(width: 48, height: 48)
                        .background(KumustaColors.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel(L("Share your streak"))
                .simultaneousGesture(TapGesture().onEnded { trackAction("share_streak_requested") })

                Button {
                    isEditingProfile = true
                } label: {
                    Image(systemName: "pencil")
                        .scaledFont(18, weight: .bold)
                        .foregroundStyle(KumustaColors.ink)
                        .frame(width: 48, height: 48)
                        .background(KumustaColors.surface)
                        .clipShape(Circle())
                }
                .padding(0)
                .accessibilityLabel(L("Edit profile"))
            }
            .padding(12)
        }
    }

    private var firstStepsCard: some View {
        let store = dependencies.firstStepsCourseStore
        let isComplete = store.hasCompletedLesson
        let isInProgress = store.lessonStatus == .inProgress
        // Learners past the beginner level go straight to the cheat sheet,
        // where they can replay their welcome lesson.
        let opensCheatSheet = isComplete || appState.profile.level != .beginner
        let title = isComplete
            ? L("Review First Steps")
            : opensCheatSheet
                ? L("Your basics cheat sheet")
                : isInProgress
                    ? L("Resume First Steps")
                    : L("Start First Steps")
        let detail = isComplete
            ? L("Your basics cheat sheet is unlocked. Replay your lessons anytime.")
            : opensCheatSheet
                ? L("Sounds, respect words, people words, and a replay of your welcome lesson.")
                : isInProgress
                    ? L("Finish your first lesson: three phrases and a mini-conversation.")
                    : L("A 6-minute first lesson: say hello, your name, and thank you.")

        return NavigationLink {
            FirstStepsCourseView(reviewMode: opensCheatSheet)
        } label: {
            FirstStepsQuestCardLabel(
                status: opensCheatSheet ? .completed : store.lessonStatus,
                title: title,
                detail: detail
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(opensCheatSheet ? L("Opens the basics cheat sheet and lesson replays") : L("Open the First Steps course"))
    }

    private var leaderboardCard: some View {
        ProfileSection(title: L("Leaderboard"), subtitle: nil) {
            LeaderboardInlinePreview()
        }
    }

    private var achievements: some View {
        let store = dependencies.achievementStore
        let badges = store.allAchievements
        if badges.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            ProfileSection(
                title: L("Badges"),
                subtitle: L("%lld of %lld earned", store.unlockedCount, store.totalCount)
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                    ForEach(badges) { badge in
                        let isUnlocked = badge.isUnlocked
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isUnlocked
                                        ? KumustaColors.accentSoft.opacity(0.3)
                                        : KumustaColors.surfaceMuted.opacity(0.5))
                                    .frame(width: 52, height: 52)
                                Image(systemName: badge.symbol)
                                    .scaledFont(22, weight: .bold)
                                    .foregroundStyle(isUnlocked
                                        ? KumustaColors.accentDeep
                                        : KumustaColors.muted.opacity(0.5))
                            }
                            Text(badge.title)
                                .scaledFont(11, weight: .semibold, design: .rounded)
                                .foregroundStyle(isUnlocked ? KumustaColors.ink : KumustaColors.muted)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 72)
                        .opacity(isUnlocked ? 1 : 0.55)
                    }
                }
            }
        )
    }

    private var weeklyProgress: some View {
        ProfileSection(title: L("Your last 7 days"), subtitle: L("Only completed sessions count here.")) {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(activity.lastSevenDays) { day in
                        VStack(spacing: 8) {
                            Text(day.date.formatted(.dateTime.weekday(.narrow).locale(AppLocalization.locale)))
                                .font(.body.bold())
                                .fontDesign(.rounded)
                                .foregroundStyle(KumustaColors.muted)
                                .accessibilityHidden(true)
                            ZStack {
                                Circle()
                                    .fill(day.sessions > 0 ? KumustaColors.success : KumustaColors.surfaceMuted)
                                    .frame(width: 36, height: 36)
                                Image(systemName: day.sessions > 0 ? "checkmark" : "minus")
                                    .scaledFont(16, weight: .bold)
                                    .foregroundStyle(day.sessions > 0 ? .white : KumustaColors.muted)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.date.formatted(Date.FormatStyle(date: .complete, time: .omitted).locale(AppLocalization.locale)))
                        .accessibilityValue(day.sessions > 0 ? L(one: "%lld minute completed", other: "%lld minutes completed", count: day.minutes) : L("No session"))
                    }
                }

                Divider().overlay(KumustaColors.line)

                HStack(spacing: 0) {
                    fact(value: "\(activity.weekSessions)", label: L(one: "session", other: "sessions", count: activity.weekSessions))
                    Divider().overlay(KumustaColors.line).frame(height: 48)
                    fact(value: "\(activity.weekMinutes)", label: L("minutes"))
                    Divider().overlay(KumustaColors.line).frame(height: 48)
                    fact(value: "\(activity.currentStreak())", label: L(one: "day streak (singular)", other: "day streak", count: activity.currentStreak()))
                }
            }
            .padding(18)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var activity: LocalLearningActivityStore {
        dependencies.learningActivityStore
    }

    private var lessonHistory: some View {
        ProfileSection(
            title: L("Lesson history"),
            subtitle: dependencies.learningJourneyStore.completedLessons.isEmpty
                ? L("Complete a lesson and it will be saved here.")
                : L("Listen again, read every line, and revisit useful chunks.")
        ) {
            if dependencies.learningJourneyStore.completedLessons.isEmpty {
                HStack(spacing: 15) {
                    Image(systemName: "books.vertical.fill")
                        .scaledFont(23, weight: .semibold)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .frame(width: 52, height: 52)
                        .background(KumustaColors.accentSoft.opacity(0.34))
                        .clipShape(Circle())
                    Text(L("Your completed lessons will become a personal review library."))
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KumustaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(dependencies.learningJourneyStore.completedLessons.prefix(3)) { record in
                        NavigationLink {
                            CompletedLessonDetailView(record: record)
                        } label: {
                            CompletedLessonRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink(L("See all completed lessons")) {
                        LessonHistoryView()
                    }
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
        }
    }

    private var learningPreferences: some View {
        ProfileSection(title: L("Learning plan"), subtitle: nil) {
            VStack(spacing: 0) {
                PreferenceRow(
                    symbol: appState.profile.goal.systemImage,
                    label: L("Goal"),
                    value: appState.profile.goal.title
                )
                rowDivider
                PreferenceRow(
                    symbol: "clock.fill",
                    label: L("Daily pace"),
                    value: L(one: "%lld minute", other: "%lld minutes", count: appState.profile.dailyMinutes)
                )
                rowDivider
                PreferenceRow(
                    symbol: "chart.bar.fill",
                    label: L("Starting level"),
                    value: appState.profile.level.title
                )
                rowDivider
                PreferenceRow(
                    symbol: "scope",
                    label: L("Desired level"),
                    value: (appState.profile.desiredProficiency ?? .confident).title
                )
                rowDivider
                PreferenceRow(
                    symbol: "slider.horizontal.3",
                    label: L("Challenge"),
                    value: (appState.profile.challengePreference ?? .balanced).title
                )
            }
            .padding(.horizontal, 16)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button(L("Edit learning plan")) {
                isEditingProfile = true
            }
            .buttonStyle(KumustaSecondaryButtonStyle())
        }
    }

    private var appearancePreferences: some View {
        ProfileSection(title: L("Appearance"), subtitle: L("Your space, your light.")) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        ForEach(AppAppearance.allCases) { option in
                            appearanceOption(option)
                        }
                    }
                    VStack(spacing: 10) {
                        ForEach(AppAppearance.allCases) { option in
                            appearanceOption(option)
                        }
                    }
                }
                Text(appearance == AppAppearance.system.rawValue
                     ? L("Follows your device’s appearance automatically.")
                     : appearance == AppAppearance.dark.rawValue
                        ? L("Always uses dark mode, whatever your device setting.")
                        : L("Always uses light mode, whatever your device setting."))
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func appearanceOption(_ option: AppAppearance) -> some View {
        let selected = appearance == option.rawValue
        return Button {
            appearance = option.rawValue
        } label: {
            VStack(spacing: 10) {
                Image(systemName: option.symbol)
                    .font(.system(size: 23, weight: .semibold))
                    .frame(height: 30)
                Text(appearanceTitle(option))
                    .font(KumustaTypography.bodyStrong)
                    .fixedSize()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(selected ? KumustaColors.accentDeep : KumustaColors.muted)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 17)
            .background(selected ? KumustaColors.accentSoft.opacity(0.25) : KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(selected ? KumustaColors.accentDeep : KumustaColors.line, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearanceTitle(option))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("appearance-\(option.rawValue)")
    }

    private var notificationPreferences: some View {
        let service = dependencies.notificationService
        return ProfileSection(title: L("Notifications"), subtitle: L("Stay on track with gentle reminders")) {
            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { service.remindersEnabled },
                    set: { service.remindersEnabled = $0; trackSetting("reminders_enabled", value: String($0)) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Daily practice reminder"))
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.ink)
                        Text(L("%@ each day", "\(service.reminderHour.formatted(.number.precision(.integerLength(2)))):\(String(format: "%02d", service.reminderMinute))"))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                    }
                }
                .tint(KumustaColors.accent)
                .frame(minHeight: 54)

                Divider().overlay(KumustaColors.line)

                Toggle(isOn: Binding(
                    get: { service.streakWarningEnabled },
                    set: { service.streakWarningEnabled = $0; trackSetting("streak_warning_enabled", value: String($0)) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Streak at risk warning"))
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.ink)
                        Text(L("Alert at 8 PM if you haven't practiced"))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                    }
                }
                .tint(KumustaColors.accent)
                .frame(minHeight: 54)
            }
            .padding(18)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var audioPreferences: some View {
        ProfileSection(title: L("Listening"), subtitle: L("Choose how new audio behaves.")) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L("Default speed"), systemImage: "speedometer")
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.ink)

                    Picker(L("Default speed"), selection: $defaultSpeed) {
                        ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                            Text(speed.title).tag(speed.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(KumustaTypography.body)
                    .accessibilityHint(L("Sets the first playback speed in lessons"))
                }

                Divider().overlay(KumustaColors.line)

                Toggle(isOn: $autoplayAudio) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Play audio automatically"))
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.ink)
                        Text(L("Off keeps lessons quieter in public."))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                    }
                }
                .tint(KumustaColors.accent)
                .frame(minHeight: 54)

                Divider().overlay(KumustaColors.line)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(L("Sound effects"), systemImage: "speaker.wave.2")
                            .font(KumustaTypography.bodyStrong)
                            .foregroundStyle(KumustaColors.ink)
                        Spacer(minLength: 10)
                        Text(soundEffectsVolume == 0 ? L("Off") : L("%lld%%", Int((soundEffectsVolume * 100).rounded())))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted)
                            .monospacedDigit()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(KumustaColors.muted)
                            .accessibilityHidden(true)
                        Slider(value: $soundEffectsVolume, in: 0...1, step: 0.05) { isEditing in
                            if !isEditing {
                                SelectionFeedbackPlayer.shared.play()
                            }
                        }
                        .tint(KumustaColors.accent)
                        .accessibilityLabel(L("Sound effects volume"))
                        .accessibilityValue(L("%lld percent", Int((soundEffectsVolume * 100).rounded())))
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(KumustaColors.muted)
                            .accessibilityHidden(true)
                    }

                    Text(L("Pops, answer chimes and badges. Voices stay the same."))
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                }
            }
            .padding(18)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var membership: some View {
        ProfileSection(title: L("Membership"), subtitle: L("Your purchase is handled securely by the App Store.")) {
            VStack(spacing: 12) {
                Button {
                    trackAction("sign_out_confirmation_opened")
                    isShowingSignOutConfirmation = true
                } label: {
                    SettingsActionRow(
                        symbol: "rectangle.portrait.and.arrow.right",
                        title: isSigningOut ? L("Signing out…") : L("Sign out"),
                        detail: L("Sign out on this device. Your account stays available when you sign in again."),
                        showsChevron: false,
                        isBusy: isSigningOut
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSigningOut)

                Button {
                    restorePurchases()
                } label: {
                    SettingsActionRow(
                        symbol: "arrow.clockwise",
                        title: isRestoring ? L("Checking purchases…") : L("Restore purchases"),
                        detail: restoreMessage,
                        showsChevron: false,
                        isBusy: isRestoring
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)

                if hasPremiumAccess {
                    Button {
                        trackAction("customer_center_opened")
                        isShowingSubscriptionManagement = true
                    } label: {
                        SettingsActionRow(
                            symbol: "creditcard",
                            title: L("Manage subscription"),
                            detail: L("Change your plan, cancel or request a refund."),
                            showsChevron: true,
                            isBusy: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isShowingCancellationFlow = true
                } label: {
                    Text(L("Cancel subscription"))
                        .font(.footnote)
                        .foregroundStyle(KumustaColors.muted)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(L("Tell us why, then continue in App Store settings"))
            }
        }
    }

    private var dataAndSupport: some View {
        ProfileSection(title: L("Your data & help"), subtitle: nil) {
            VStack(spacing: 12) {
                Link(destination: KumustaLinks.privacy) {
                    SettingsActionRow(
                        symbol: "hand.raised.fill",
                        title: L("Privacy policy"),
                        detail: L("How Kumusta protects your data"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { trackAction("privacy_policy_opened") })

                Link(destination: KumustaLinks.terms) {
                    SettingsActionRow(
                        symbol: "doc.text.fill",
                        title: L("Terms of use"),
                        detail: L("Subscriptions and using Kumusta"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { trackAction("terms_opened") })

                Link(destination: KumustaLinks.support) {
                    SettingsActionRow(
                        symbol: "lifepreserver.fill",
                        title: L("Help & support"),
                        detail: L("Subscriptions, refunds and your account"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { trackAction("support_page_opened") })

                Link(destination: URL(string: "mailto:amaurydelille92500@gmail.com?subject=Kumusta%20support")!) {
                    SettingsActionRow(
                        symbol: "questionmark.bubble.fill",
                        title: L("Contact support"),
                        detail: L("Email amaurydelille92500@gmail.com"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { trackAction("contact_support_opened") })

                Button {
                    trackAction("delete_account_confirmation_opened")
                    isShowingAccountDeletionConfirmation = true
                } label: {
                    SettingsActionRow(
                        symbol: "person.crop.circle.badge.minus",
                        title: isDeletingAccount ? L("Deleting account…") : L("Delete account"),
                        detail: L("Permanently remove your account and learning data"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
                .accessibilityIdentifier("delete-account")
                .accessibilityLabel(L("Delete account"))

                Button(role: .destructive) {
                    trackAction("erase_data_confirmation_opened")
                    isShowingEraseConfirmation = true
                } label: {
                    SettingsActionRow(
                        symbol: "trash.fill",
                        title: L("Erase app data"),
                        detail: L("Remove this device’s profile and activity"),
                        showsChevron: false,
                        tint: KumustaColors.accentDeep
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(KumustaColors.line)
            .padding(.leading, 54)
    }

    private func fact(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .fontDesign(.rounded)
                .foregroundStyle(KumustaColors.ink)
            Text(label)
                .font(.body.weight(.medium))
                .fontDesign(.rounded)
                .foregroundStyle(KumustaColors.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayName: String {
        let name = appState.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? L("Tagalog learner") : name
    }

    private func appearanceTitle(_ option: AppAppearance) -> String {
        switch option {
        case .system: L("System")
        case .light: L("Light")
        case .dark: L("Dark")
        }
    }

    private var shareText: String {
        L("I'm learning Tagalog with Kumusta — %lld day streak, %lld words.", activity.currentStreak(), appState.profile.totalWordsLearned)
    }

    private var exportText: String {
        let days = activity.lastSevenDays.map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.minutes) minutes"
        }.joined(separator: "\n")

        return """
        Kumusta data export

        Name: \(displayName)
        Goal: \(appState.profile.goal.title)
        Daily pace: \(appState.profile.dailyMinutes) minutes
        Level: \(appState.profile.level.title)
        Current streak: \(appState.profile.currentStreak)
        Words learned: \(appState.profile.totalWordsLearned)
        Saved lesson vocabulary: \(dependencies.savedLessonWordStore.words.count)
        Completed lessons: \(dependencies.learningJourneyStore.completedLessons.count)

        Saved words:
        \(savedWordsExport)

        Last 7 days:
        \(days)
        """
    }

    private var savedWordsExport: String {
        if dependencies.savedLessonWordStore.words.isEmpty { return "None" }
        return dependencies.savedLessonWordStore.words.map {
            "\($0.word) — \($0.translation)"
        }.joined(separator: "\n")
    }

    private func restorePurchases() {
        isRestoring = true
        restoreMessage = nil
        Task {
            do {
                let restored = try await dependencies.purchaseService.restore()
                restoreMessage = restored ? L("Premium access is active.") : L("No active purchase was found for this Apple ID.")
                if restored { hasPremiumAccess = true }
            } catch {
                restoreMessage = L("The App Store couldn’t check right now. Please try again.")
            }
            isRestoring = false
        }
    }

    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        accountDeletionMessage = nil
        Task {
            do {
                try await appState.deleteAccount()
            } catch {
                accountDeletionMessage = ProfileAccountDeletionMessage(
                    title: L("We couldn’t delete your account"),
                    detail: error.localizedDescription
                )
                isDeletingAccount = false
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        Task {
            await appState.signOut()
            isSigningOut = false
        }
    }
}

private struct ProfileAccountDeletionMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct FirstStepsQuestCardLabel: View {
    let status: FirstStepsCourseStatus
    let title: String
    let detail: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAlive = false

    private var isComplete: Bool { status == .completed }

    private var activeStage: Int {
        switch status {
        case .completed: 2
        case .inProgress: 1
        case .notStarted, .skipped: 0
        }
    }

    private var actionTitle: String {
        switch status {
        case .completed: L("OPEN CHEAT SHEET")
        case .inProgress: L("JUMP BACK IN")
        case .notStarted, .skipped: L("BEGIN THE QUEST")
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(KumustaColors.accentSoft.opacity(0.2))
                .frame(width: 168, height: 168)
                .offset(x: 78, y: -92)
                .accessibilityHidden(true)

            Capsule()
                .fill(KumustaColors.surface.opacity(0.5))
                .frame(width: 154, height: 24)
                .rotationEffect(.degrees(-9))
                .offset(x: 54, y: 88)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 15) {
                    questArt

                    VStack(alignment: .leading, spacing: 6) {
                        Label(L("FOUNDATION QUEST"), systemImage: "sparkles")
                            .scaledFont(11, weight: .bold, design: .rounded)
                            .scaledTracking(0.9, forPointSize: 11)
                            .foregroundStyle(KumustaColors.accentDeep)

                        Text(title)
                            .font(KumustaTypography.title2)
                            .foregroundStyle(KumustaColors.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(detail)
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                questTrail
            }
            .padding(18)
        }
        .background(KumustaColors.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .shadow(color: KumustaColors.accentShadow.opacity(0.1), radius: 14, y: 7)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            isAlive = true
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            isAlive = !shouldReduceMotion
        }
    }

    private var questArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(KumustaColors.surface.opacity(0.86))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(KumustaColors.accentSoft.opacity(0.72), lineWidth: 1.5)
                }

            HStack(alignment: .center, spacing: 4) {
                ForEach(Array([CGFloat(13), 25, 18, 31, 20].enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(KumustaColors.accent.opacity(0.56))
                        .frame(width: 4, height: height)
                        .scaleEffect(
                            y: isAlive ? 1 : 0.48,
                            anchor: .center
                        )
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeInOut(duration: 0.72 + Double(index) * 0.08)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.07),
                            value: isAlive
                        )
                }
            }
            .offset(y: 24)

            BuddyMark(size: 64, mood: isComplete ? .proud : .listening)
                .offset(y: isAlive ? -8 : -4)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.35).repeatForever(autoreverses: true),
                    value: isAlive
                )

            if isComplete {
                Image(systemName: "checkmark.seal.fill")
                    .scaledFont(20, weight: .bold)
                    .foregroundStyle(KumustaColors.success)
                    .background(KumustaColors.surface)
                    .clipShape(Circle())
                    .offset(x: 28, y: -31)
            }
        }
        .frame(width: 88, height: 104)
        .accessibilityHidden(true)
    }

    private var questTrail: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= activeStage ? KumustaColors.accent : KumustaColors.line)
                        .frame(width: index == activeStage ? 18 : 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            Text(actionTitle)
                .scaledFont(11, weight: .bold, design: .rounded)
                .scaledTracking(0.7, forPointSize: 11)
                .foregroundStyle(KumustaColors.ink)

            Spacer(minLength: 4)

            Image(systemName: "arrow.right")
                .scaledFont(14, weight: .bold)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(KumustaColors.accent)
                .clipShape(Circle())
        }
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .frame(minHeight: 48)
        .background(KumustaColors.surface.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(KumustaColors.line.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct SubscriptionCancellationFlowView: View {
    private enum Step: Equatable {
        case warning
        case reason
    }

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .warning
    @State private var reason = ""
    @State private var didAttemptSubmit = false
    @State private var isSubmittingReason = false
    @State private var submissionError: String?
    @FocusState private var isReasonFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch step {
                        case .warning:
                            warningContent
                        case .reason:
                            reasonContent
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .onAppear { trackCancellationScreen() }
            .onChange(of: step) { _, _ in trackCancellationScreen() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .reason {
                        Button {
                            withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
                                step = .warning
                            }
                        } label: {
                            Label(L("Back"), systemImage: "chevron.left")
                        }
                    } else {
                        Button(L("Not now")) {
                            dismiss()
                        }
                    }
                }
            }
            .animation(reduceMotion ? nil : KumustaMotion.screen, value: step == .reason)
        }
        .presentationDragIndicator(.visible)
    }

    private func trackCancellationScreen() {
        dependencies.analytics.track(.screenViewed, properties: ["screen_name": "subscription_cancellation", "step": step == .warning ? "warning" : "reason"])
    }

    private var warningContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            cancellationIcon

            ScreenHeader(
                eyebrow: L("BEFORE YOU GO"),
                title: L("Do you want to cancel?"),
                subtitle: L("Your Kumusta Pro subscription will stop renewing. You will keep premium access until the end of your current billing period.")
            )

            VStack(alignment: .leading, spacing: 12) {
                CancellationImpactRow(
                    symbol: "headphones",
                    title: L("No more premium lessons"),
                    detail: L("Listening, speaking, and review features will lock after your access ends.")
                )
                CancellationImpactRow(
                    symbol: "clock.arrow.circlepath",
                    title: L("Your progress stays safe"),
                    detail: L("Your account and saved learning progress will remain available if you return.")
                )
            }

            VStack(spacing: 12) {
                Button(L("Yes, continue to cancel")) {
                    withAnimation(reduceMotion ? nil : KumustaMotion.screen) {
                        step = .reason
                    }
                }
                .buttonStyle(KumustaPrimaryButtonStyle())

                Button(L("Keep my subscription")) {
                    dependencies.analytics.track(.featureAction, properties: ["screen_name": "subscription_cancellation", "step": "subscription_kept"])
                    dismiss()
                }
                .buttonStyle(KumustaSecondaryButtonStyle())
            }
        }
    }

    private var reasonContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScreenHeader(
                eyebrow: L("ONE LAST QUESTION"),
                title: L("What made you decide to cancel?"),
                subtitle: L("A short note is enough. Your feedback helps us improve Kumusta.")
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Your reason"))
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)

                ZStack(alignment: .topLeading) {
                    if reason.isEmpty {
                        Text(L("I’m canceling because…"))
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.muted.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 19)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $reason)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.ink)
                        .scrollContentBackground(.hidden)
                        .focused($isReasonFocused)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .frame(minHeight: 156)
                        .accessibilityLabel(L("Cancellation reason"))
                        .onChange(of: reason) { _, newValue in
                            if newValue.count > 500 {
                                reason = String(newValue.prefix(500))
                            }
                            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                didAttemptSubmit = false
                            }
                        }
                }
                .background(KumustaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            didAttemptSubmit && trimmedReason.isEmpty
                                ? KumustaColors.accentDeep
                                : KumustaColors.line,
                            lineWidth: didAttemptSubmit && trimmedReason.isEmpty ? 1.5 : 1
                        )
                }

                HStack(alignment: .top, spacing: 8) {
                    if didAttemptSubmit && trimmedReason.isEmpty {
                        Label(L("Please enter a reason before continuing."), systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(KumustaColors.accentDeep)
                    } else {
                        Text(L("Your answer is required to continue."))
                            .foregroundStyle(KumustaColors.muted)
                    }

                    Spacer(minLength: 8)

                    Text("\(reason.count)/500")
                        .foregroundStyle(KumustaColors.muted)
                }
                .font(KumustaTypography.supporting)

                if let submissionError {
                    Label(submissionError, systemImage: "exclamationmark.triangle.fill")
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.errorDeep)
                }
            }

            Button {
                submitReason()
            } label: {
                if isSubmittingReason {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L("Continue to App Store settings"))
                }
            }
            .buttonStyle(KumustaPrimaryButtonStyle())
            .disabled(isSubmittingReason)
        }
    }

    private var cancellationIcon: some View {
        Image(systemName: "arrow.uturn.left.circle.fill")
            .scaledFont(30, weight: .semibold)
            .foregroundStyle(KumustaColors.accentDeep)
            .frame(width: 72, height: 72)
            .background(KumustaColors.accentSoft.opacity(0.5))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitReason() {
        guard !trimmedReason.isEmpty else {
            didAttemptSubmit = true
            isReasonFocused = true
            return
        }

        guard let signedInRepository = dependencies.signedInRepository else {
            submissionError = L("We couldn’t save your feedback. Please try again while signed in.")
            return
        }

        let submittedReason = trimmedReason
        isSubmittingReason = true
        submissionError = nil

        Task {
            do {
                try await signedInRepository.submitCancellationFeedback(submittedReason)
                isSubmittingReason = false
                dependencies.analytics.track(.featureAction, properties: ["screen_name": "subscription_cancellation", "step": "feedback_submitted"])
                dismiss()
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            } catch {
                dependencies.analytics.track(.featureAction, properties: ["screen_name": "subscription_cancellation", "step": "feedback_failed", "error_category": "save_failed"])
                isSubmittingReason = false
                submissionError = L("We couldn’t save your feedback. Please try again.")
            }
        }
    }
}

private struct CancellationImpactRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .scaledFont(18, weight: .semibold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 42, height: 42)
                .background(KumustaColors.accentSoft.opacity(0.5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                Text(detail)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(KumustaColors.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(KumustaTypography.title2)
                .foregroundStyle(KumustaColors.ink)
            if let subtitle {
                Text(subtitle)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
    }
}

private struct PreferenceRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .scaledFont(19, weight: .semibold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 40, height: 46)
                .accessibilityHidden(true)

            Text(label)
                .font(KumustaTypography.bodyStrong)
                .foregroundStyle(KumustaColors.ink)

            Spacer(minLength: 10)

            Text(value)
                .font(KumustaTypography.body)
                .foregroundStyle(KumustaColors.muted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsActionRow: View {
    let symbol: String
    let title: String
    let detail: String?
    let showsChevron: Bool
    var isBusy = false
    var tint = KumustaColors.accentDeep

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(0.12))
                if isBusy {
                    ProgressView().tint(tint)
                } else {
                    Image(systemName: symbol)
                        .scaledFont(19, weight: .semibold)
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                if let detail {
                    Text(detail)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .scaledFont(17, weight: .bold)
                    .foregroundStyle(KumustaColors.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let dependencies = DependencyContainer.preview()
    ProfileView()
        .environment(AppState(dependencies: dependencies))
        .environment(dependencies)
}

private enum LeaderboardPeriod: String, Identifiable {
    case allTime

    var id: String { rawValue }

    var periodKind: String {
        "all_time"
    }

    var periodKey: String {
        "all_time"
    }
}

private enum LeaderboardLoadState {
    case idle
    case loading
    case loaded
    case offline
    case failed
}

private struct LeaderboardInlinePreview: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var selectedPeriod: LeaderboardPeriod = .allTime
    @State private var snapshot: RemoteLeaderboardSnapshot?
    @State private var loadState: LeaderboardLoadState = .idle
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            previewContent
        }
        .padding(17)
        .background(KumustaColors.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .task {
            await loadLeaderboard()
            await observeLeaderboardChanges()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch loadState {
        case .idle, .loading:
            VStack(spacing: 1) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(KumustaColors.surface)
                        .frame(height: 52)
                }
            }
            .redacted(reason: .placeholder)
            .accessibilityLabel(L("Loading leaderboard"))
        case .offline:
            inlineState(
                symbol: "person.3.fill",
                title: L("Sign in to join the board"),
                detail: L("Your completed practice will show here.")
            )
        case .failed:
            VStack(alignment: .leading, spacing: 10) {
                inlineState(
                    symbol: "wifi.exclamationmark",
                    title: L("The board is unavailable"),
                    detail: L("Your XP is safe. Try loading the rankings again.")
                )
                Button(L("Try again")) {
                    Task { await loadLeaderboard() }
                }
                .buttonStyle(KumustaSecondaryButtonStyle())
            }
        case .loaded:
            if let snapshot {
                loadedPreview(snapshot)
            } else {
                inlineState(
                    symbol: "arrow.up.right",
                    title: L("Complete a session to appear"),
                    detail: L("Earn XP and your place will be ready here.")
                )
            }
        }
    }

    private func loadedPreview(_ snapshot: RemoteLeaderboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let leader = snapshot.entries.min(by: { $0.leaderboardRank < $1.leaderboardRank }) {
                HStack(spacing: 16) {
                    UserAvatar(
                        userID: leader.userID,
                        persistedSeed: leader.avatarSeed,
                        fallbackText: AvatarFallback.initials(from: leader.displayName),
                        size: 62
                    )
                    .padding(5)
                    .background(KumustaColors.surface, in: Circle())
                    .overlay(Circle().stroke(Color(red: 0.85, green: 0.61, blue: 0.19), lineWidth: 3))
                    .overlay(alignment: .top) {
                        Image(systemName: "crown.fill")
                            .scaledFont(25, weight: .bold)
                            .foregroundStyle(Color(red: 0.85, green: 0.61, blue: 0.19))
                            .rotationEffect(.degrees(-12))
                            .offset(x: -17, y: -16)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inlineName(for: leader, isCurrentUser: leader.userID == snapshot.currentUserID))
                            .scaledFont(21, weight: .heavy, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                            .lineLimit(2)
                        Label(L("%lld XP", leader.xp), systemImage: "bolt.fill")
                            .scaledFont(13, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.accentDeep)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
            }

            if let current = snapshot.entries.first(where: { $0.userID == snapshot.currentUserID }) {
                let target = snapshot.entries.filter { $0.leaderboardRank < current.leaderboardRank }.max(by: { $0.leaderboardRank < $1.leaderboardRank })
                HStack(spacing: 10) {
                    Image(systemName: target == nil ? "sparkles" : "arrow.up.forward")
                        .scaledFont(19, weight: .bold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.map { L("Next stop: #%lld", $0.leaderboardRank) } ?? L("Number one looks good on you"))
                            .scaledFont(13, weight: .bold, design: .rounded)
                        Text(target.map { L("%lld more XP to move up", max(0, $0.xp - current.xp) + 1) } ?? L("Keep the momentum. Get a little practice in."))
                            .scaledFont(11, weight: .medium, design: .rounded)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(KumustaColors.accentDeep)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KumustaColors.accentSoft.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            }

            HStack {
                Text(L("THE FRIENDLY COMPETITION"))
                    .scaledFont(9, weight: .heavy, design: .rounded)
                    .scaledTracking(0.8, forPointSize: 9)
                Spacer()
                Text(L("All-time XP"))
                    .scaledFont(10, weight: .semibold, design: .rounded)
            }
            .foregroundStyle(KumustaColors.muted)

            VStack(spacing: 7) {
                ForEach(nearbyEntries(snapshot)) { entry in
                    inlineRow(entry, isCurrentUser: entry.userID == snapshot.currentUserID)
                }
            }

            if snapshot.entries.isEmpty {
                inlineState(symbol: "flag.checkered", title: L("Be the first on the board"), detail: L("Finish a practice session to earn your first XP."))
            }

            NavigationLink {
                LeaderboardView(initialPeriod: selectedPeriod)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                    Text(L("Explore the leaderboard"))
                        .font(KumustaTypography.bodyStrong)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .scaledFont(15, weight: .bold)
                }
                .foregroundStyle(KumustaColors.surface)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .background(KumustaColors.accent, in: RoundedRectangle(cornerRadius: 17))
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(KumustaColors.accentShadow)
                        .offset(y: 4)
                }
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
            .tactile()
            .accessibilityHint(L("Open all leaderboard positions"))
        }
    }

    private func nearbyEntries(_ snapshot: RemoteLeaderboardSnapshot) -> [RemoteLeaderboardEntry] {
        let sortedEntries = snapshot.entries.sorted { $0.leaderboardRank < $1.leaderboardRank }
        guard let currentIndex = sortedEntries.firstIndex(where: { $0.userID == snapshot.currentUserID }) else {
            return Array(sortedEntries.prefix(5))
        }

        let start = max(0, currentIndex - 2)
        let end = min(sortedEntries.count, start + 5)
        let adjustedStart = max(0, end - 5)
        return Array(sortedEntries[adjustedStart ..< end])
    }

    private func inlineRow(_ entry: RemoteLeaderboardEntry, isCurrentUser: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.leaderboardRank)")
                .scaledFont(13, weight: .bold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(isCurrentUser ? KumustaColors.accentDeep : KumustaColors.muted)
                .frame(width: 27, height: 30)
                .background(entry.leaderboardRank <= 3 ? KumustaColors.surfaceStrong : .clear, in: RoundedRectangle(cornerRadius: 9))
                .overlay(alignment: .bottom) {
                    if entry.leaderboardRank <= 3 {
                        Image(systemName: "star.fill")
                            .scaledFont(7, weight: .bold)
                            .foregroundStyle(KumustaColors.accentDeep)
                            .offset(y: 3)
                    }
                }

            UserAvatar(
                userID: entry.userID,
                persistedSeed: entry.avatarSeed,
                fallbackText: AvatarFallback.initials(from: entry.displayName),
                size: 36
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(inlineName(for: entry, isCurrentUser: isCurrentUser))
                .font(KumustaTypography.supportingStrong)
                .foregroundStyle(KumustaColors.ink)
                .lineLimit(1)
                if isCurrentUser {
                    Text(L("YOU"))
                        .scaledFont(8, weight: .heavy, design: .rounded)
                        .foregroundStyle(KumustaColors.accentDeep)
                }
            }

            Spacer(minLength: 8)

            Text(L("%lld XP", entry.xp))
                .scaledFont(12, weight: .semibold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(isCurrentUser ? KumustaColors.accentDeep : KumustaColors.muted)
                .fixedSize()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(isCurrentUser ? KumustaColors.accentSoft.opacity(0.24) : KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isCurrentUser ? KumustaColors.accent.opacity(0.65) : .clear, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCurrentUser
            ? L("Rank %lld, %@, %lld XP, that’s you", entry.leaderboardRank, inlineName(for: entry, isCurrentUser: isCurrentUser), entry.xp)
            : L("Rank %lld, %@, %lld XP", entry.leaderboardRank, inlineName(for: entry, isCurrentUser: isCurrentUser), entry.xp))
    }

    private func inlineName(for entry: RemoteLeaderboardEntry, isCurrentUser: Bool) -> String {
        let name = entry.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? L("Tagalog learner") : name
    }

    private func inlineState(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .scaledFont(16, weight: .bold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 36, height: 36)
                .background(KumustaColors.accentSoft.opacity(0.38))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(KumustaTypography.supportingStrong)
                    .foregroundStyle(KumustaColors.ink)
                Text(detail)
                    .font(KumustaTypography.caption)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func loadLeaderboard() async {
        guard !isLoading else { return }
        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        guard let repository = dependencies.signedInRepository else {
            loadState = .offline
            return
        }

        do {
            snapshot = try await repository.fetchLeaderboard(
                periodKind: selectedPeriod.periodKind,
                periodKey: selectedPeriod.periodKey,
                limit: 1_000
            )
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    private func observeLeaderboardChanges() async {
        guard let repository = dependencies.signedInRepository else { return }

        for await _ in await repository.leaderboardChanges() {
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await repository.fetchLeaderboard(
                    periodKind: selectedPeriod.periodKind,
                    periodKey: selectedPeriod.periodKey,
                    limit: 1_000
                )
                loadState = .loaded
            } catch {
                // Keep the last good board visible while the stream reconnects.
            }
        }
    }
}

private struct LeaderboardView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var selectedPeriod: LeaderboardPeriod = .allTime
    @State private var snapshot: RemoteLeaderboardSnapshot?
    @State private var loadState: LeaderboardLoadState = .idle
    @State private var isLoading = false

    init(initialPeriod: LeaderboardPeriod = .allTime) {
        _selectedPeriod = State(initialValue: initialPeriod)
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    leaderboardContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .screenContentWidth()
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await loadLeaderboard()
            }
        }
        .navigationTitle(L("Leaderboard"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KumustaColors.canvas, for: .navigationBar)
        .onAppear { dependencies.analytics.track(.screenViewed, properties: ["screen_name": "leaderboard"]) }
        .onChange(of: selectedPeriod) { _, period in
            dependencies.analytics.track(.featureAction, properties: ["screen_name": "leaderboard", "step": "period_selected", "value": period.rawValue])
        }
        .task {
            await loadLeaderboard()
            await observeLeaderboardChanges()
        }
    }

    @ViewBuilder
    private var leaderboardContent: some View {
        switch loadState {
        case .idle, .loading:
            leaderboardLoading
        case .offline:
            leaderboardStateCard(
                symbol: "person.3.fill",
                title: L("Your board is waiting"),
                detail: L("Sign in and your completed practice will turn into a place on the board.")
            )
        case .failed:
            VStack(spacing: 12) {
                leaderboardStateCard(
                    symbol: "wifi.exclamationmark",
                    title: L("The board is out of reach"),
                    detail: L("We couldn’t load the latest rankings. Your XP is safe.")
                )

                Button(L("Try again")) {
                    Task { await loadLeaderboard() }
                }
                .buttonStyle(KumustaSecondaryButtonStyle())
            }
        case .loaded:
            if let snapshot {
                loadedLeaderboard(snapshot)
            } else {
                leaderboardLoading
            }
        }
    }

    private var leaderboardLoading: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(KumustaColors.surface)
                .frame(height: 112)

            HStack(spacing: 10) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(KumustaColors.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 128)
                }
            }

            VStack(spacing: 1) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KumustaColors.surface)
                        .frame(height: 62)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel(L("Loading leaderboard"))
    }

    private func loadedLeaderboard(_ snapshot: RemoteLeaderboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("A little practice.\nA little higher."))
                        .scaledFont(28, weight: .heavy, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("All-time XP · Every session counts"))
                        .scaledFont(12, weight: .semibold, design: .rounded)
                        .foregroundStyle(KumustaColors.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "trophy.fill")
                    .scaledFont(32, weight: .bold)
                    .foregroundStyle(medalColor(for: 1))
                    .rotationEffect(.degrees(10))
                    .frame(width: 64, height: 70)
                    .background(medalColor(for: 1).opacity(0.13), in: RoundedRectangle(cornerRadius: 22))
            }
            if snapshot.entries.isEmpty {
                leaderboardStateCard(
                    symbol: "arrow.up.right",
                    title: L("Make your first move"),
                    detail: L("Complete a session to earn XP and appear on the leaderboard.")
                )
            } else {
                let podiumEntries = snapshot.entries.filter { $0.leaderboardRank <= 3 }
                if !podiumEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        podium(podiumEntries)
                    }
                }

                personalStanding(snapshot)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L("The standings"))
                            .scaledFont(18, weight: .bold, design: .rounded)
                            .foregroundStyle(KumustaColors.ink)
                        Spacer()
                        Text(L(one: "%lld learner", other: "%lld learners", count: snapshot.entries.count))
                            .scaledFont(12, weight: .semibold, design: .rounded)
                            .foregroundStyle(KumustaColors.muted)
                    }

                    LazyVStack(spacing: 6) {
                        ForEach(snapshot.entries) { entry in
                            leaderboardRow(entry, isCurrentUser: entry.userID == snapshot.currentUserID)
                        }
                    }
                }
            }
        }
    }

    private func podium(_ entries: [RemoteLeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            podiumEntry(rank: 2, entries: entries, height: 48)
            podiumEntry(rank: 1, entries: entries, height: 76)
            podiumEntry(rank: 3, entries: entries, height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func personalStanding(_ snapshot: RemoteLeaderboardSnapshot) -> some View {
        if let entry = snapshot.entries.first(where: { $0.userID == snapshot.currentUserID }) {
            let rival = snapshot.entries.last(where: { $0.leaderboardRank < entry.leaderboardRank })
            HStack(spacing: 13) {
                Text("#\(entry.leaderboardRank)")
                    .scaledFont(25, weight: .heavy, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(KumustaColors.accentDeep)
                    .frame(minWidth: 52, minHeight: 56)
                    .background(KumustaColors.surface, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.leaderboardRank == 1 ? L("You’re leading the way!") : L("Your next milestone"))
                        .scaledFont(15, weight: .bold, design: .rounded)
                        .foregroundStyle(KumustaColors.ink)
                    Text(rival.map { L("%lld XP to reach #%lld", max(0, $0.xp - entry.xp) + 1, $0.leaderboardRank) } ?? L("Keep showing up. Every listen adds up."))
                        .scaledFont(12, weight: .medium, design: .rounded)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: entry.leaderboardRank == 1 ? "sparkles" : "arrow.up.right")
                    .scaledFont(22, weight: .bold)
                    .foregroundStyle(KumustaColors.accentDeep)
            }
            .padding(13)
            .background(KumustaColors.accentSoft.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
        } else if !snapshot.entries.isEmpty {
            leaderboardStateCard(symbol: "flag.fill", title: L("Your climb starts here"), detail: L("Finish a practice session to earn XP and join the board."))
        }
    }

    @ViewBuilder
    private func podiumEntry(
        rank: Int64,
        entries: [RemoteLeaderboardEntry],
        height: CGFloat
    ) -> some View {
        if let entry = entries.first(where: { $0.leaderboardRank == rank }) {
            VStack(spacing: 7) {
                Image(systemName: rank == 1 ? "crown.fill" : "sparkle")
                    .scaledFont(rank == 1 ? 23 : 14, weight: .bold)
                    .foregroundStyle(medalColor(for: rank))

                avatar(for: entry, size: rank == 1 ? 62 : 50)
                    .padding(4)
                    .overlay(Circle().stroke(medalColor(for: rank), lineWidth: 3))

                Text(entryName(for: entry))
                    .scaledFont(13, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 34)

                Text(L("%lld XP", entry.xp))
                    .scaledFont(12, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(KumustaColors.accentDeep)
                Text("\(rank)")
                    .scaledFont(rank == 1 ? 32 : 25, weight: .heavy, design: .rounded)
                    .foregroundStyle(medalColor(for: rank))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(medalColor(for: rank).opacity(0.19), in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                    .overlay(alignment: .top) {
                        Capsule().fill(medalColor(for: rank).opacity(0.4))
                            .frame(height: 3).padding(.horizontal, 12)
                    }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("%@, rank %lld, %@, %lld XP", medalName(for: rank), rank, entryName(for: entry), entry.xp))
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
    }

    private func leaderboardRow(
        _ entry: RemoteLeaderboardEntry,
        isCurrentUser: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.leaderboardRank)")
                .scaledFont(15, weight: .bold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(entry.leaderboardRank <= 3 ? medalColor(for: entry.leaderboardRank) : KumustaColors.muted)
                .frame(width: 26, height: 30)
                .background(entry.leaderboardRank <= 3 ? medalColor(for: entry.leaderboardRank).opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 9))

            avatar(for: entry, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(entryName(for: entry))
                    .scaledFont(15, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .lineLimit(1)
                if isCurrentUser {
                    Text(L("YOU"))
                        .scaledFont(9, weight: .heavy, design: .rounded)
                        .foregroundStyle(KumustaColors.accentDeep)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.xp)")
                    .scaledFont(17, weight: .heavy, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(isCurrentUser ? KumustaColors.accentDeep : KumustaColors.ink)
                Text("XP").scaledFont(9, weight: .bold, design: .rounded)
                    .foregroundStyle(KumustaColors.muted)
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isCurrentUser ? KumustaColors.accentSoft.opacity(0.24) : KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(isCurrentUser ? KumustaColors.accent : .clear, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCurrentUser
            ? L("Rank %lld, %@, %lld XP, that’s you", entry.leaderboardRank, entryName(for: entry), entry.xp)
            : L("Rank %lld, %@, %lld XP", entry.leaderboardRank, entryName(for: entry), entry.xp))
    }

    private func avatar(for entry: RemoteLeaderboardEntry, size: CGFloat) -> some View {
        UserAvatar(
            userID: entry.userID,
            persistedSeed: entry.avatarSeed,
            fallbackText: AvatarFallback.initials(from: entry.displayName),
            size: size
        )
    }

    private func entryName(for entry: RemoteLeaderboardEntry) -> String {
        let name = entry.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? L("Tagalog learner") : name
    }

    private func medalColor(for rank: Int64) -> Color {
        switch rank {
        case 1:
            Color(red: 0.86, green: 0.62, blue: 0.16)
        case 2:
            Color(red: 0.55, green: 0.59, blue: 0.62)
        default:
            Color(red: 0.72, green: 0.39, blue: 0.22)
        }
    }

    private func medalName(for rank: Int64) -> String {
        switch rank {
        case 1: L("Gold medal")
        case 2: L("Silver medal")
        default: L("Bronze medal")
        }
    }

    private func leaderboardStateCard(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .scaledFont(20, weight: .bold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 48, height: 48)
                .background(KumustaColors.accentSoft.opacity(0.38))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                Text(detail)
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(17)
        .background(KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func loadLeaderboard() async {
        guard !isLoading else { return }
        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        guard let repository = dependencies.signedInRepository else {
            loadState = .offline
            return
        }

        do {
            snapshot = try await repository.fetchLeaderboard(
                periodKind: selectedPeriod.periodKind,
                periodKey: selectedPeriod.periodKey,
                limit: 1_000
            )
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    private func observeLeaderboardChanges() async {
        guard let repository = dependencies.signedInRepository else { return }

        for await _ in await repository.leaderboardChanges() {
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await repository.fetchLeaderboard(
                    periodKind: selectedPeriod.periodKind,
                    periodKey: selectedPeriod.periodKey,
                    limit: 1_000
                )
                loadState = .loaded
            } catch {
                // Keep the last good board visible while the stream reconnects.
            }
        }
    }
}

#Preview("Leaderboard") {
    let dependencies = DependencyContainer.preview()
    NavigationStack {
        LeaderboardView()
    }
    .environment(dependencies)
}
