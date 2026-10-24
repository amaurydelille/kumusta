import Foundation

enum ProfanityFilter {
    static func containsProfanity(_ input: String) -> Bool {
        let normalized = normalize(input)
        guard !normalized.isEmpty else { return false }

        for term in blockedTerms where term.count >= 3 {
            if normalized.contains(term) {
                return true
            }
        }
        return false
    }

    static func sanitize(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count)
        for scalar in input.unicodeScalars {
            if let mapped = mapScalar(scalar.value) {
                output.unicodeScalars.append(mapped)
            }
        }
        return output
    }

    private static let blockedTerms: [String] = [
        "fuck", "fuk", "fck", "phuck", "fuq",
        "shit", "shyt", "sht", "bullshit",
        "asshole", "asshat", "ass",
        "bitch", "bich", "biatch",
        "nazi", "nazis",
        "cunt", "kunt",
        "hoe", "whore", "hore",
        "dick", "dck", "dik",
        "cock", "cok",
        "pussy", "pussi", "pusy",
        "nigga", "nigger", "niggas", "niggers",
        "negro", "negra", "neegy", "nigro", "niggro", "knewgrow",
        "rape", "rapist",
        "violence", "violent",
        "abuse", "abusive",
        "porn", "porno", "pornography",
        "slut", "skank", "tramp",
        "bastard", "btard",
        "damn", "dammit",
        "fag", "faggot", "fgt",
        "retard", "retarded",
        "kill", "killer",
        "terror", "terrorist",
        "pedo", "pedophile",
        "molest", "molester",
        "suck", "sucks"
    ]

    private static func normalize(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count)
        for scalar in input.unicodeScalars {
            let mapped = mapScalar(scalar.value)
            if mapped != nil {
                output.append(Character(mapped!))
            }
        }
        let collapsed = output
            .lowercased()
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "!", with: "i")
            .replacingOccurrences(of: "|", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "7", with: "t")
            .replacingOccurrences(of: "+", with: "t")
            .replacingOccurrences(of: "8", with: "b")
            .replacingOccurrences(of: "9", with: "g")
            .replacingOccurrences(of: "ph", with: "f")
            .replacingOccurrences(of: "ck", with: "k")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
        return collapsed
    }

    private static func mapScalar(_ value: UInt32) -> Unicode.Scalar? {
        switch value {
        case 0x00DF: return Unicode.Scalar(0x0073)
        case 0x00E0...0x00E6, 0x00E8...0x00EB, 0x00EC...0x00EF,
             0x00F2...0x00F6, 0x00F8...0x00FB, 0x0101, 0x0103,
             0x0105, 0x0107, 0x010D, 0x010F, 0x0119, 0x011B,
             0x011F, 0x0121, 0x0125, 0x0127:
            return Unicode.Scalar(value - 0x0020)
        case 0x00F0, 0x00FE:
            return nil
        default:
            return Unicode.Scalar(value)
        }
    }
}
