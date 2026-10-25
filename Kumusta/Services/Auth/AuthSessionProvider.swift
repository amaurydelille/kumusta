import Foundation
import OSLog
import Supabase

struct AuthenticatedUser: Equatable, Sendable {
    let id: UUID
    let email: String?
}

struct BackendIdentity: Equatable, Sendable {
    let id: UUID
    let isAnonymous: Bool
}

enum AuthSessionState: Equatable, Sendable {
    case signedOut
    case anonymous(BackendIdentity)
    case signedIn(AuthenticatedUser)
}

enum AuthSignUpResult: Equatable, Sendable {
    case signedIn(AuthenticatedUser)
    case awaitingEmailConfirmation(email: String)
}

/// Result of turning the temporary anonymous learner into a recoverable account.
/// Keeping the existing auth user ID is important: it preserves the RevenueCat
/// identity and every row already created under that learner's RLS boundary.
enum AuthAccountUpgradeResult: Equatable, Sendable {
    case signedIn(AuthenticatedUser)
    case awaitingEmailConfirmation(email: String)
}

enum AuthSessionError: LocalizedError, Sendable {
    case notAuthenticated
    case anonymousSessionUnsupported
    case invalidAppleCredential

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            L("Sign in to sync your Kumusta progress.")
        case .anonymousSessionUnsupported:
            L("This account must be upgraded before progress can be synced.")
        case .invalidAppleCredential:
            L("Apple did not provide a valid sign-in credential.")
        }
    }
}

protocol AuthSessionProviding: Sendable {
    func bootstrapAnonymousSession() async throws -> BackendIdentity
    func currentBackendIdentity() async throws -> BackendIdentity
    func refreshBackendSession() async throws -> BackendIdentity
    func currentAuthenticatedUser() async throws -> AuthenticatedUser
    func sessionStates() async -> AsyncStream<AuthSessionState>
    func signIn(email: String, password: String) async throws -> AuthenticatedUser
    func signUp(email: String, password: String) async throws -> AuthSignUpResult
    func upgradeAnonymousAccount(email: String, password: String) async throws -> AuthAccountUpgradeResult
    func signInWithApple(identityToken: String, rawNonce: String?) async throws -> AuthenticatedUser
    func signOut() async throws
}

/// The only component that turns a Supabase Auth session into an app identity.
/// Private Kumusta data rejects anonymous sessions; product analytics is the
/// intentional owner-scoped exception used during onboarding.
actor SupabaseAuthSessionProvider: AuthSessionProviding {
    private static let logger = Logger(
        subsystem: "com.kumusta.app",
        category: "Authentication"
    )
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func bootstrapAnonymousSession() async throws -> BackendIdentity {
        if client.auth.currentSession != nil {
            let existing = try await client.auth.session
            return BackendIdentity(
                id: existing.user.id,
                isAnonymous: existing.user.isAnonymous
            )
        }
        do {
            let session = try await client.auth.signInAnonymously()
            return BackendIdentity(id: session.user.id, isAnonymous: true)
        } catch {
            Self.logger.error(
                "Supabase anonymous session bootstrap failed: \(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    func currentBackendIdentity() async throws -> BackendIdentity {
        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            Self.logger.error(
                "Supabase session unavailable. Cached session present: \(self.client.auth.currentSession != nil, privacy: .public). Error: \(String(describing: error), privacy: .public)"
            )
            throw AuthSessionError.notAuthenticated
        }
        return BackendIdentity(
            id: session.user.id,
            isAnonymous: session.user.isAnonymous
        )
    }

    func refreshBackendSession() async throws -> BackendIdentity {
        let wasAnonymous = client.auth.currentSession?.user.isAnonymous == true
        do {
            let session = try await client.auth.refreshSession()
            return BackendIdentity(
                id: session.user.id,
                isAnonymous: session.user.isAnonymous
            )
        } catch {
            // A pre-account learner has no credentials to type again. If its
            // temporary refresh token was revoked, replace only that anonymous
            // session so the onboarding speech exercise remains recoverable.
            if wasAnonymous {
                do {
                    let session = try await client.auth.signInAnonymously()
                    return BackendIdentity(id: session.user.id, isAnonymous: true)
                } catch {
                    Self.logger.error(
                        "Supabase anonymous session recovery failed: \(String(describing: error), privacy: .public)"
                    )
                }
            } else {
                Self.logger.error(
                    "Supabase session refresh failed: \(String(describing: error), privacy: .public)"
                )
            }
            throw AuthSessionError.notAuthenticated
        }
    }

    func currentAuthenticatedUser() async throws -> AuthenticatedUser {
        let session: Session
        do {
            // `session` refreshes an expired access token before returning.
            session = try await client.auth.session
        } catch {
            Self.logger.error(
                "Supabase authenticated session unavailable. Cached session present: \(self.client.auth.currentSession != nil, privacy: .public). Error: \(String(describing: error), privacy: .public)"
            )
            throw AuthSessionError.notAuthenticated
        }
        return try Self.authenticatedUser(from: session)
    }

    func sessionStates() async -> AsyncStream<AuthSessionState> {
        let client = client
        return AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    guard !Task.isCancelled else { break }
                    guard let session else {
                        continuation.yield(.signedOut)
                        continue
                    }
                    if session.user.isAnonymous {
                        continuation.yield(
                            .anonymous(
                                BackendIdentity(id: session.user.id, isAnonymous: true)
                            )
                        )
                        continue
                    }
                    continuation.yield(
                        .signedIn(
                            AuthenticatedUser(
                                id: session.user.id,
                                email: session.user.email
                            )
                        )
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        let session = try await client.auth.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        return try Self.authenticatedUser(from: session)
    }

    func signUp(email: String, password: String) async throws -> AuthSignUpResult {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response = try await client.auth.signUp(email: normalizedEmail, password: password)
        guard let session = response.session else {
            return .awaitingEmailConfirmation(email: normalizedEmail)
        }
        return .signedIn(try Self.authenticatedUser(from: session))
    }

    func upgradeAnonymousAccount(
        email: String,
        password: String
    ) async throws -> AuthAccountUpgradeResult {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let identity = try await currentBackendIdentity()

        // A restore on a second device can already be signed in. Do not create
        // a second account or break the existing RevenueCat user mapping.
        guard identity.isAnonymous else {
            return .signedIn(try await currentAuthenticatedUser())
        }

        let attributes = UserAttributes(email: normalizedEmail, password: password)
        let updatedUser: User
        do {
            updatedUser = try await client.auth.update(user: attributes)
        } catch where Self.isDeletedUser(error) {
            try await replaceDeletedAnonymousSession()
            updatedUser = try await client.auth.update(user: attributes)
        }

        // Supabase projects with confirm-email enabled keep this identity in a
        // verification state until the user taps the email link. The screen
        // explicitly guides them back to sign in after confirmation.
        guard updatedUser.emailConfirmedAt != nil else {
            return .awaitingEmailConfirmation(email: normalizedEmail)
        }

        // The upgrade does not reissue the access token, which still claims
        // `is_anonymous: true` until it expires. RLS rejects registered-only
        // writes (profile, preferences, analytics) with that token, so refresh
        // before the account's first sync.
        _ = try await client.auth.refreshSession()
        return .signedIn(try await currentAuthenticatedUser())
    }

    func signInWithApple(identityToken: String, rawNonce: String?) async throws -> AuthenticatedUser {
        guard !identityToken.isEmpty else {
            throw AuthSessionError.invalidAppleCredential
        }
        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: identityToken,
            nonce: rawNonce
        )
        // Linking upgrades the anonymous user in place. Its UUID therefore
        // remains the RevenueCat App User ID and entitlement mirror key.
        let session: Session
        if client.auth.currentSession?.user.isAnonymous == true {
            do {
                session = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
            } catch where Self.isDeletedUser(error) {
                try await replaceDeletedAnonymousSession()
                session = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
            }
        } else {
            session = try await client.auth.signInWithIdToken(credentials: credentials)
        }
        return try Self.authenticatedUser(from: session)
    }

    /// A cached session can outlive its user (deleted from the dashboard or by
    /// account deletion elsewhere). Its access token still looks valid locally,
    /// but Supabase answers `user_not_found` to every authenticated call.
    private static func isDeletedUser(_ error: any Error) -> Bool {
        (error as? AuthError)?.errorCode == .userNotFound
    }

    /// Only an anonymous learner is replaced: it has nothing to recover, and
    /// onboarding answers live on the device until the account is created.
    private func replaceDeletedAnonymousSession() async throws {
        Self.logger.error("Cached anonymous Supabase user no longer exists; starting a new anonymous session")
        try? await client.auth.signOut(scope: .local)
        _ = try await client.auth.signInAnonymously()
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private static func authenticatedUser(from session: Session) throws -> AuthenticatedUser {
        guard !session.user.isAnonymous else {
            throw AuthSessionError.anonymousSessionUnsupported
        }
        return AuthenticatedUser(id: session.user.id, email: session.user.email)
    }
}
