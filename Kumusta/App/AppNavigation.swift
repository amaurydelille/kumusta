import Foundation
import Observation

@Observable
final class AppNavigation {
    enum Tab: String, Hashable {
        case today
        case practice
        case words
        case profile
    }

    var selectedTab: Tab

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("practiceTab") {
            selectedTab = .practice
        } else if arguments.contains("wordsTab") {
            selectedTab = .words
        } else if arguments.contains("profileTab") {
            selectedTab = .profile
        } else {
            selectedTab = .today
        }
    }
}
