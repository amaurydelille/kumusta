import SwiftUI
import UIKit

enum KumustaColors {
    static let paper = Color.dynamic(light: 0xE9D4B5, dark: 0x192B35)
    static let canvas = Color.dynamic(light: 0xF8E8CF, dark: 0x131F27)
    static let surface = Color.dynamic(light: 0xFFF3DF, dark: 0x1D303B)
    static let surfaceStrong = Color.dynamic(light: 0xF2DDBE, dark: 0x29424F)
    static let surfaceMuted = Color.dynamic(light: 0xEAD3B2, dark: 0x243945)
    static let ink = Color.dynamic(light: 0x24221E, dark: 0xF1F5F7)
    /// Meets 4.5:1 for normal text on canvas, surface, and surfaceMuted in both modes.
    static let muted = Color.dynamic(light: 0x6E6255, dark: 0xB0C3CC)
    static let line = Color.dynamic(light: 0xD9BFA0, dark: 0x43606E)
    /// Filled actions retain white labels; text accents use the brighter companion.
    static let accent = Color.dynamic(light: 0xDE5640, dark: 0xC44C3C)
    static let accentDeep = Color.dynamic(light: 0xA83A2D, dark: 0xFFAB96)
    static let accentSoft = Color.dynamic(light: 0xF4B4A1, dark: 0x6A403D)
    static let accentShadow = Color.dynamic(light: 0x963426, dark: 0x78342D)
    static let accentPanel = Color.dynamic(light: 0xA83A2D, dark: 0x873D36)
    static let focusFill = Color.dynamic(light: 0x456A80, dark: 0x366B86)
    /// A cool companion color for lesson surfaces, with white text contrast in both modes.
    static let lessonAccent = Color.dynamic(light: 0x3F6E70, dark: 0x29616A)
    static let lessonAccentShadow = Color.dynamic(light: 0x2B5052, dark: 0x173D46)
    static let darkControl = Color.dynamic(light: 0x25231F, dark: 0xF1F5F7)
    static let success = Color.dynamic(light: 0x4F8060, dark: 0x44815C)
    /// "Almost right" marks such as a wrong tone; the deep companion is for text.
    static let caution = Color.dynamic(light: 0xE0A43A, dark: 0xC98F2E)
    static let cautionDeep = Color.dynamic(light: 0x8A5A10, dark: 0xF2C877)
    static let focus = Color.dynamic(light: 0x456A80, dark: 0x78BDDF)
}

enum AppAppearance: String, CaseIterable, Identifiable {
    static let storageKey = "kumusta.appearance"
    case system, light, dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }

    static func dynamic(light: UInt, dark: UInt, alpha: Double = 1) -> Color {
        Color(uiColor: UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 08) & 0xff) / 255,
                blue: CGFloat((hex >> 00) & 0xff) / 255,
                alpha: alpha
            )
        })
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 08) & 0xff) / 255,
            blue: CGFloat((hex >> 00) & 0xff) / 255,
            alpha: alpha
        )
    }
}
