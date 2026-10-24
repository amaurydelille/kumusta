import Foundation

@MainActor
protocol ProfileRepository: AnyObject {
    var cachedProfile: UserProfile { get }
    func loadProfile() async throws -> UserProfile
    func saveProfile(_ profile: UserProfile) async throws
    func reset()
}

@MainActor
final class LocalFirstProfileRepository: ProfileRepository {
    private enum Keys {
        static let profile = "kumusta.profile.v1"
    }

    private let defaults: UserDefaults
    private let configuration: AppConfiguration
    private(set) var cachedProfile: UserProfile

    init(configuration: AppConfiguration, defaults: UserDefaults = .standard) {
        self.configuration = configuration
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Keys.profile),
            let saved = try? JSONDecoder().decode(UserProfile.self, from: data)
        {
            cachedProfile = saved
        } else {
            cachedProfile = .newUser
        }
    }

    func loadProfile() async throws -> UserProfile {
        // Local-first by design: the user can enter the app offline. Supabase sync is
        // handled by an adapter once a configured anonymous/authenticated session exists.
        cachedProfile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        let data = try JSONEncoder().encode(profile)
        defaults.set(data, forKey: Keys.profile)
        cachedProfile = profile
    }

    func reset() {
        defaults.removeObject(forKey: Keys.profile)
        cachedProfile = .newUser
    }
}
