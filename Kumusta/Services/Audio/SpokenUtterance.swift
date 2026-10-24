import Foundation

/// Separates screenplay-style metadata from the words a learner should hear.
/// Generated lesson phrases are required to contain only the utterance, but
/// this remains a defensive boundary for stale or externally-authored content.
enum SpokenUtterance {
    static func playbackText(from source: String) -> String {
        let normalized = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard let split = leadingSpeakerLabel(in: normalized) else {
            return normalized
        }
        return split.utterance
    }

    static func hasLeadingSpeakerLabel(_ source: String) -> Bool {
        leadingSpeakerLabel(in: source) != nil
    }

    private static func leadingSpeakerLabel(
        in source: String
    ) -> (label: String, utterance: String)? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let separator = trimmed.firstIndex(where: { $0 == ":" || $0 == "：" })
        else { return nil }

        let label = trimmed[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        let utteranceStart = trimmed.index(after: separator)
        let utterance = trimmed[utteranceStart...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            (1 ... 60).contains(label.count),
            !utterance.isEmpty,
            label.allSatisfy({ $0.isLetter || $0.isWhitespace || $0 == "-" || $0 == "·" })
        else { return nil }
        return (label, utterance)
    }
}
