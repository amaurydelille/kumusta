import Foundation
import Testing
@testable import Kumusta

@Suite("Account data service")
struct AccountDataServiceTests {
    @Test("Accepts the versioned account export envelope")
    func acceptsValidExport() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "generated_at": "2026-07-31T12:00:00.000Z",
            "user": ["id": UUID().uuidString],
            "tables": ["kumusta_profiles": []],
        ])

        #expect(SupabaseAccountDataService.isValidExport(data))
    }

    @Test("Rejects partial or unknown export versions")
    func rejectsInvalidExport() throws {
        let missingTables = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "generated_at": "2026-07-31T12:00:00.000Z",
            "user": [:],
        ])
        let futureVersion = try JSONSerialization.data(withJSONObject: [
            "version": 2,
            "generated_at": "2026-07-31T12:00:00.000Z",
            "user": [:],
            "tables": [:],
        ])

        #expect(!SupabaseAccountDataService.isValidExport(missingTables))
        #expect(!SupabaseAccountDataService.isValidExport(futureVersion))
    }

    @Test("Deletion confirmation is intentionally exact")
    func exactDeletionConfirmation() {
        #expect(SupabaseAccountDataService.deletionConfirmation == "DELETE MY ACCOUNT")
        #expect(SupabaseAccountDataService.deletionConfirmation != "delete my account")
    }
}
