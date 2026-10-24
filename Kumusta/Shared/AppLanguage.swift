import Foundation
import Observation
import os

/// The interface language. Kumusta ships in English only; Tagalog learning
/// content is never translated.
enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"

    var id: Self { self }

    var locale: Locale { Locale(identifier: rawValue) }
}

/// Thread-safe lookup into `AppStrings.xcstrings` for the active language.
/// Keys are the English source text, so a missing translation shows English
/// rather than a raw key.
enum AppLocalization {
    static let table = "AppStrings"

    private struct State: @unchecked Sendable {
        var language: AppLanguage
        var bundle: Bundle?
    }

    private static let state = OSAllocatedUnfairLock(initialState: State(language: .english, bundle: nil))

    static var language: AppLanguage { state.withLock { $0.language } }

    static var locale: Locale { language.locale }

    static func use(_ language: AppLanguage) {
        let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
        state.withLock { $0 = State(language: language, bundle: bundle) }
    }

    static func string(_ key: String) -> String {
        guard let bundle = state.withLock({ $0.bundle }) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: table)
    }
}

/// Localized interface text. Pass the English source string; use `%@` and
/// `%lld` placeholders with arguments for dynamic values.
func L(_ key: String) -> String {
    AppLocalization.string(key)
}

func L(_ format: String, _ arguments: any CVarArg...) -> String {
    String(format: AppLocalization.string(format), locale: AppLocalization.locale, arguments: arguments)
}

/// Count-dependent text. Both forms are catalog keys and take `count` as
/// their argument.
func L(one: String, other: String, count: Int) -> String {
    L(count == 1 ? one : other, count)
}
