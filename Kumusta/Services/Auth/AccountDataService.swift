import Foundation
import Supabase

struct AccountDataExport: Sendable {
    let json: Data
    let suggestedFilename: String
}

struct AccountDeletionReceipt: Decodable, Equatable, Sendable {
    let version: Int
    let deleted: Bool
    let userID: UUID
    let deletedAt: Date

    enum CodingKeys: String, CodingKey {
        case version
        case deleted
        case userID = "user_id"
        case deletedAt = "deleted_at"
    }
}

enum AccountDataServiceError: LocalizedError, Sendable {
    case invalidConfirmation
    case invalidExport
    case exportTooLarge
    case invalidDeletionReceipt

    var errorDescription: String? {
        switch self {
        case .invalidConfirmation:
            L("Enter DELETE MY ACCOUNT to confirm account deletion.")
        case .invalidExport:
            L("Your account export could not be verified.")
        case .exportTooLarge:
            L("Your account export is too large for an in-app download. Contact contact@kumusta.app.")
        case .invalidDeletionReceipt:
            L("Account deletion could not be verified.")
        }
    }
}

protocol AccountDataServicing: Sendable {
    func exportAccountData() async throws -> AccountDataExport
    func deleteAccount(confirmation: String) async throws -> AccountDeletionReceipt
}

/// Typed iOS boundary for the account-data Edge Function.
/// The app never receives or stores the server's service-role credential.
/// Deletion accepts both registered and automatically-created anonymous
/// sessions; export remains restricted to registered accounts.
actor SupabaseAccountDataService: AccountDataServicing {
    static let deletionConfirmation = "DELETE MY ACCOUNT"
    private static let maximumExportBytes = 5_242_880

    private let client: SupabaseClient
    private let authSessionProvider: any AuthSessionProviding

    init(client: SupabaseClient, authSessionProvider: any AuthSessionProviding) {
        self.client = client
        self.authSessionProvider = authSessionProvider
    }

    func exportAccountData() async throws -> AccountDataExport {
        _ = try await authSessionProvider.currentAuthenticatedUser()
        let data: Data = try await client.functions.invoke(
            "kumusta-account-data",
            options: FunctionInvokeOptions(
                body: AccountDataRequest(action: "export", confirmation: nil),
                timeoutInterval: 30
            ),
            decode: { data, response in
                guard data.count <= Self.maximumExportBytes else {
                    throw AccountDataServiceError.exportTooLarge
                }
                guard
                    response.value(forHTTPHeaderField: "Content-Type")?
                        .lowercased()
                        .hasPrefix("application/json") == true,
                    Self.isValidExport(data)
                else {
                    throw AccountDataServiceError.invalidExport
                }
                return data
            }
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return AccountDataExport(
            json: data,
            suggestedFilename: "kumusta-account-data-\(formatter.string(from: .now)).json"
        )
    }

    func deleteAccount(confirmation: String) async throws -> AccountDeletionReceipt {
        guard confirmation == Self.deletionConfirmation else {
            throw AccountDataServiceError.invalidConfirmation
        }
        let identity = try await authSessionProvider.currentBackendIdentity()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let receipt: AccountDeletionReceipt = try await client.functions.invoke(
            "kumusta-account-data",
            options: FunctionInvokeOptions(
                body: AccountDataRequest(action: "delete", confirmation: confirmation),
                timeoutInterval: 30
            ),
            decoder: decoder
        )
        guard
            receipt.version == 1,
            receipt.deleted,
            receipt.userID == identity.id
        else {
            throw AccountDataServiceError.invalidDeletionReceipt
        }
        // The auth user is already gone. Make a best-effort local token cleanup;
        // callers must still erase app-local profile and learning state.
        try? await authSessionProvider.signOut()
        return receipt
    }

    static func isValidExport(_ data: Data) -> Bool {
        guard
            data.count <= maximumExportBytes,
            let object = try? JSONSerialization.jsonObject(with: data),
            let payload = object as? [String: Any],
            payload["version"] as? Int == 1,
            payload["generated_at"] is String,
            payload["user"] is [String: Any],
            payload["tables"] is [String: Any]
        else {
            return false
        }
        return true
    }
}

/// Local-only account-data boundary used by SwiftUI previews and deterministic
/// UI tests. Production builds always inject `SupabaseAccountDataService` when
/// account features are configured.
actor PreviewAccountDataService: AccountDataServicing {
    func exportAccountData() async throws -> AccountDataExport {
        AccountDataExport(
            json: Data("{}".utf8),
            suggestedFilename: "kumusta-account-data-preview.json"
        )
    }

    func deleteAccount(confirmation: String) async throws -> AccountDeletionReceipt {
        guard confirmation == SupabaseAccountDataService.deletionConfirmation else {
            throw AccountDataServiceError.invalidConfirmation
        }
        return AccountDeletionReceipt(
            version: 1,
            deleted: true,
            userID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            deletedAt: .now
        )
    }
}

private struct AccountDataRequest: Encodable {
    let action: String
    let confirmation: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        if let confirmation {
            try container.encode(confirmation, forKey: .confirmation)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case action
        case confirmation
    }
}
