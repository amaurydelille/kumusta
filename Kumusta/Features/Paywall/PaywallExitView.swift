import SwiftUI

/// The deliberate exit route shown when a learner dismisses the paywall.
/// It keeps the subscription value clear while making sign-out and deletion
/// equally accessible, rather than silently trapping the learner on a plan.
struct PaywallExitView: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies

    @State private var isSigningOut = false
    @State private var isDeleting = false
    @State private var isShowingDeletionConfirmation = false
    @State private var message: ExitMessage?

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 24) {
                    BuddyMark(size: 104, mood: .listening)
                        .padding(.top, 18)

                    ScreenHeader(
                        eyebrow: L("YOUR COURSE IS READY"),
                        title: L("Keep real Vietnamese\nwithin reach."),
                        subtitle: L("A plan unlocks the listening, speaking, and review loop built around your life in Vietnam.")
                    )

                    VStack(spacing: 12) {
                        PaywallExitBenefit(
                            symbol: "ear.and.waveform",
                            title: L("Understand real situations"),
                            detail: L("Short listening lessons that sound like life, not a textbook.")
                        )
                        PaywallExitBenefit(
                            symbol: "waveform",
                            title: L("Choose your Vietnamese accent"),
                            detail: L("Practice with a consistent Northern or Southern female voice.")
                        )
                        PaywallExitBenefit(
                            symbol: "rectangle.stack.badge.plus",
                            title: L("Keep the words that matter"),
                            detail: L("Vocabulary reviews return when your memory needs them.")
                        )
                    }

                    VStack(spacing: 12) {
                        Button(L("Sign in to an existing account")) {
                            appState.showAccountCreation()
                        }
                        .buttonStyle(KumustaSecondaryButtonStyle())

                        Button(L("See plans again")) {
                            appState.returnToPaywall()
                        }
                        .buttonStyle(KumustaPrimaryButtonStyle())

                        Button {
                            signOut()
                        } label: {
                            if isSigningOut {
                                HStack(spacing: 9) {
                                    ProgressView()
                                        .tint(KumustaColors.ink)
                                    Text(L("Signing out…"))
                                }
                            } else {
                                Text(L("Sign out"))
                            }
                        }
                        .buttonStyle(KumustaSecondaryButtonStyle())
                        .disabled(isWorking)

                        Button(role: .destructive) {
                            isShowingDeletionConfirmation = true
                        } label: {
                            if isDeleting {
                                HStack(spacing: 9) {
                                    ProgressView()
                                        .tint(KumustaColors.accentDeep)
                                    Text(L("Deleting account…"))
                                }
                            } else {
                                Text(L("Delete account"))
                            }
                        }
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.accentDeep)
                        .frame(minHeight: 50)
                        .disabled(isWorking)
                        .accessibilityIdentifier("delete-account")

                        Text(L("Deleting your account permanently removes your Kumusta data. You can always return to plans before then."))
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { dependencies.analytics.track(.screenViewed, properties: ["screen_name": "paywall_exit"]) }
        .confirmationDialog(
            L("Delete your Kumusta account?"),
            isPresented: $isShowingDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("Delete account permanently"), role: .destructive) {
                deleteAccount()
            }
            Button(L("Keep my account"), role: .cancel) {}
        } message: {
            Text(L("This permanently deletes your Kumusta account and learning data. This cannot be undone."))
        }
        .alert(item: $message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.detail),
                dismissButton: .default(Text(L("OK")))
            )
        }
    }

    private var isWorking: Bool {
        isSigningOut || isDeleting
    }

    private func signOut() {
        isSigningOut = true
        Task {
            await appState.signOut()
            isSigningOut = false
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await appState.deleteAccount()
            } catch {
                message = ExitMessage(
                    title: L("We couldn’t delete your account"),
                    detail: error.localizedDescription
                )
            }
            isDeleting = false
        }
    }
}

private struct PaywallExitBenefit: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .scaledFont(19, weight: .semibold)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: 42, height: 42)
                .background(KumustaColors.accentSoft.opacity(0.55))
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

private struct ExitMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

#Preview {
    PaywallExitView()
        .environment(AppState(dependencies: .preview()))
        .environment(DependencyContainer.preview())
}
