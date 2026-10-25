import SwiftUI

/// The account entry point shown after sign-out and after an anonymous learner
/// starts a trial or completes a purchase. The optional name is asked only when
/// onboarding didn't already give one, while returning learners can resume
/// their course.
struct AccountCreationView: View {
    private enum Mode {
        case create
        case signIn
        case confirmEmail(String)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?
    @State private var lastTrackedMode: String?
    @State private var mode: Mode = .create
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    /// Read once, so the field doesn't vanish when the account saves the name.
    @State private var asksForName = false

    private enum Field: Hashable {
        case email
        case password
        case confirmation
    }

    var body: some View {
        ZStack {
            PaperBackground()
            KumustaAmbientShapes()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    content
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 22)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
            }
        }
        .interactiveDismissDisabled(isSubmitting)
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: modeLabel)
        .onAppear {
            if appState.prefersExistingAccountSignIn, case .create = mode {
                mode = .signIn
            }
            asksForName = appState.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            trackScreen()
        }
        .onChange(of: modeLabel) { _, _ in trackScreen() }
    }

    private func trackScreen() {
        guard lastTrackedMode != modeLabel else { return }
        lastTrackedMode = modeLabel
        appState.dependencies.analytics.track(.screenViewed, properties: ["screen_name": "account_\(modeLabel)"])
    }

    private var header: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(KumustaColors.accentSoft.opacity(0.3))
                    .frame(width: 144, height: 144)
                BuddyMark(size: 126, mood: .proud)
            }

            Text("KUMUSTA")
                .font(KumustaTypography.brand)
                .tracking(-0.45)
                .foregroundStyle(KumustaColors.accentDeep)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .create:
            credentialForm(
                eyebrow: L("START YOUR KUMUSTA JOURNEY"),
                title: L("Make your progress\ntravel with you."),
                subtitle: "",
                actionTitle: L("Create account and continue"),
                requiresConfirmation: true,
                action: createAccount
            )
        case .signIn:
            credentialForm(
                eyebrow: L("WELCOME BACK"),
                title: L("Pick up where\nyou left off."),
                subtitle: "",
                actionTitle: L("Sign in to Kumusta"),
                requiresConfirmation: false,
                action: signIn
            )
        case let .confirmEmail(email):
            confirmationView(email: email)
        }
    }

    private func credentialForm(
        eyebrow: String,
        title: String,
        subtitle: String,
        actionTitle: String,
        requiresConfirmation: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)

            VStack(spacing: 14) {
                if requiresConfirmation, asksForName {
                    TextField(L("First name (optional)"), text: $name)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(KumustaTypography.body)
                        .padding(16)
                        .background(KumustaColors.surface, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel(L("First name, optional"))
                    if ProfanityFilter.containsProfanity(name) {
                        Text(L("Please choose a respectful name."))
                            .font(KumustaTypography.supporting)
                            .foregroundStyle(KumustaColors.accentDeep)
                    }
                }
                credentialField(
                    title: L("Email address"),
                    text: $email,
                    prompt: L("you@example.com"),
                    field: .email,
                    contentType: .emailAddress,
                    secure: false
                )
                credentialField(
                    title: L("Password"),
                    text: $password,
                    prompt: requiresConfirmation ? L("At least 8 characters") : L("Your password"),
                    field: .password,
                    contentType: requiresConfirmation ? .newPassword : .password,
                    secure: true
                )
                if requiresConfirmation {
                    credentialField(
                        title: L("Confirm password"),
                        text: $confirmation,
                        prompt: L("Type it once more"),
                        field: .confirmation,
                        contentType: .newPassword,
                        secure: true
                    )
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(KumustaTypography.supporting)
                    .foregroundStyle(KumustaColors.errorDeep)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }

            Button(action: action) {
                HStack(spacing: 9) {
                    if isSubmitting {
                        ProgressView().tint(.white).accessibilityHidden(true)
                    }
                    Text(isSubmitting ? L("Saving your account…") : actionTitle)
                    if !isSubmitting {
                        Image(systemName: "arrow.right").font(.body.weight(.bold))
                    }
                }
            }
            .buttonStyle(KumustaPrimaryButtonStyle())
            .disabled(!canSubmit(requiresConfirmation: requiresConfirmation) || isSubmitting)

            Text(requiresConfirmation
                 ? L("Use an email you can access. It lets you keep your progress across devices.")
                 : L("Use the email and password linked to your Kumusta account."))
                .font(KumustaTypography.supporting)
                .foregroundStyle(KumustaColors.muted)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(KumustaColors.line)

            Button {
                clearFeedback()
                mode = requiresConfirmation ? .signIn : .create
                focusedField = .email
            } label: {
                Text(requiresConfirmation ? L("Already have an account? Sign in") : L("New to Kumusta? Create an account"))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .font(KumustaTypography.bodyStrong)
            .foregroundStyle(KumustaColors.accentDeep)

            HStack(spacing: 18) {
                Link(L("Terms"), destination: KumustaLinks.terms)
                Link(L("Privacy"), destination: KumustaLinks.privacy)
            }
            .font(KumustaTypography.supporting)
            .foregroundStyle(KumustaColors.accentDeep)
            .frame(maxWidth: .infinity)
        }
    }

    private func credentialField(
        title: String,
        text: Binding<String>,
        prompt: String,
        field: Field,
        contentType: UITextContentType,
        secure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(KumustaTypography.supportingStrong)
                .foregroundStyle(KumustaColors.ink)
            Group {
                if secure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
            }
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .submitLabel(field == .confirmation || (!isCreating && field == .password) ? .done : .next)
            .onSubmit { advance(from: field) }
            .font(KumustaTypography.body)
            .foregroundStyle(KumustaColors.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focusedField == field ? KumustaColors.accent : KumustaColors.line, lineWidth: focusedField == field ? 2 : 1)
            }
        }
    }

    private func confirmationView(email: String) -> some View {
        VStack(alignment: .leading, spacing: 19) {
            ScreenHeader(
                eyebrow: L("ONE LAST TAP"),
                title: L("Check your inbox."),
                subtitle: L("We sent a confirmation link to %@. Confirm it, then sign in here to start your course.", email)
            )

            VStack(alignment: .leading, spacing: 10) {
                Label(L("Your account is almost ready."), systemImage: "checkmark.shield.fill")
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                Text(L("After you confirm your email, this account will let you keep your learning history on another device."))
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(KumustaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KumustaColors.line, lineWidth: 1)
            }

            Button(L("I confirmed my email")) {
                clearFeedback()
                mode = .signIn
                focusedField = .password
            }
            .buttonStyle(KumustaPrimaryButtonStyle())

            Button(L("Use a different email")) {
                clearFeedback()
                self.email = ""
                password = ""
                confirmation = ""
                mode = .create
                focusedField = .email
            }
            .buttonStyle(KumustaSecondaryButtonStyle())
        }
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var modeLabel: String {
        switch mode {
        case .create: "create"
        case .signIn: "sign-in"
        case .confirmEmail: "confirm-email"
        }
    }

    private func canSubmit(requiresConfirmation: Bool) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmailPlausible = trimmedEmail.contains("@") && trimmedEmail.contains(".")
        guard isEmailPlausible, password.count >= 8 else { return false }
        return !requiresConfirmation || (password == confirmation && !ProfanityFilter.containsProfanity(name))
    }

    private func advance(from field: Field) {
        switch field {
        case .email: focusedField = .password
        case .password where isCreating: focusedField = .confirmation
        case .password, .confirmation:
            if canSubmit(requiresConfirmation: isCreating) {
                isCreating ? createAccount() : signIn()
            }
        }
    }

    private func createAccount() {
        guard canSubmit(requiresConfirmation: true), !isSubmitting else { return }
        submit {
            let result = try await appState.createAccountForOnboarding(email: email, password: password, name: name)
            if case let .awaitingEmailConfirmation(address) = result {
                mode = .confirmEmail(address)
            }
        }
    }

    private func signIn() {
        guard canSubmit(requiresConfirmation: false), !isSubmitting else { return }
        submit {
            try await appState.signInToPaidAccount(email: email, password: password)
        }
    }

    private func submit(_ work: @escaping () async throws -> Void) {
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        let properties = ["screen_name": "account_\(modeLabel)", "mode": modeLabel]
        appState.dependencies.analytics.track(.accountActionStarted, properties: properties)
        Task {
            do {
                try await work()
                appState.dependencies.analytics.track(.accountActionCompleted, properties: properties)
            } catch {
                appState.dependencies.analytics.track(.accountActionFailed, properties: properties.merging(["error_category": "auth_error"], uniquingKeysWith: { _, new in new }))
                errorMessage = userFacingMessage(for: error)
            }
            isSubmitting = false
        }
    }

    private func clearFeedback() {
        errorMessage = nil
        isSubmitting = false
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return L("We couldn’t secure your account just now. Please try again.")
    }
}
