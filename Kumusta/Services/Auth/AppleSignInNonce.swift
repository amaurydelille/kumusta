import CryptoKit
import Foundation
import Security

struct AppleSignInNonce: Equatable, Sendable {
    /// Pass this value to `signInWithApple(identityToken:rawNonce:)`.
    let raw: String
    /// Assign this value to `ASAuthorizationAppleIDRequest.nonce`.
    let sha256: String
}

enum AppleSignInNonceError: LocalizedError, Sendable {
    case generationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            L("A secure Apple sign-in request could not be created.")
        }
    }
}

enum AppleSignInNonceGenerator {
    private static let characters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    static func make(length: Int = 32) throws -> AppleSignInNonce {
        precondition(length > 0)
        let unbiasedUpperBound = UInt8(
            characters.count * (256 / characters.count)
        )
        var result = [Character]()
        result.reserveCapacity(length)
        while result.count < length {
            var randomBytes = [UInt8](repeating: 0, count: 64)
            let status = randomBytes.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(
                    kSecRandomDefault,
                    buffer.count,
                    buffer.baseAddress!
                )
            }
            guard status == errSecSuccess else {
                throw AppleSignInNonceError.generationFailed(status)
            }
            for byte in randomBytes where byte < unbiasedUpperBound {
                result.append(characters[Int(byte) % characters.count])
                if result.count == length { break }
            }
        }
        let raw = String(result)
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hashed = digest.map { String(format: "%02x", $0) }.joined()
        return AppleSignInNonce(raw: raw, sha256: hashed)
    }
}
