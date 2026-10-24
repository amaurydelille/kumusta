import Foundation
import Testing
@testable import Kumusta

@MainActor
@Suite("Local profile")
struct ProfileRepositoryTests {
    @Test("Profile round trips")
    func profileRoundTrip() async throws {
        let suiteName = "KumustaTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = LocalFirstProfileRepository(configuration: .preview, defaults: defaults)
        try await repository.saveProfile(.preview)

        #expect(try await repository.loadProfile() == .preview)
    }
}
