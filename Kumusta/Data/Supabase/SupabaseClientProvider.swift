import Foundation
import Supabase

#if targetEnvironment(simulator)
/// Simulator command-line builds are ad-hoc signed and may not receive a
/// Keychain access group. Supabase otherwise accepts password sign-in but
/// silently fails to persist the returned session, causing an immediate
/// sign-in loop. This storage is simulator-only; device and App Store builds
/// continue to use Supabase's Keychain-backed default.
private struct SimulatorAuthLocalStorage: AuthLocalStorage {
    private static let prefix = "com.kumusta.simulator.auth."

    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: Self.prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: Self.prefix + key)
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: Self.prefix + key)
    }
}
#endif

enum SupabaseClientConfigurationError: LocalizedError, Sendable {
    case missingProjectURL
    case missingPublishableKey

    var errorDescription: String? {
        switch self {
        case .missingProjectURL:
            L("The Supabase project URL is missing from this build.")
        case .missingPublishableKey:
            L("The Supabase publishable key is missing from this build.")
        }
    }
}

/// Owns the app's single Supabase client. Provider and service secrets are
/// intentionally absent: an iOS binary may contain only the publishable key.
final class SupabaseClientProvider: Sendable {
    let client: SupabaseClient

    init(configuration: AppConfiguration) throws {
        guard let url = configuration.supabaseURL else {
            throw SupabaseClientConfigurationError.missingProjectURL
        }
        guard !configuration.supabasePublishableKey.isEmpty else {
            throw SupabaseClientConfigurationError.missingPublishableKey
        }

        #if targetEnvironment(simulator)
        let authOptions = SupabaseClientOptions.AuthOptions(
            storage: SimulatorAuthLocalStorage(),
            flowType: .pkce,
            emitLocalSessionAsInitialSession: true
        )
        #else
        let authOptions = SupabaseClientOptions.AuthOptions(
            flowType: .pkce,
            emitLocalSessionAsInitialSession: true
        )
        #endif

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: configuration.supabasePublishableKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public"),
                auth: authOptions
            )
        )
    }
}
