import SwiftUI

enum KumustaTypography {
    static let patriotBrand = Font.custom("Patriot-Black", size: 22, relativeTo: .headline)
    static let hero = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title, design: .rounded, weight: .bold)
    static let title2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded, weight: .regular)
    static let bodyStrong = Font.system(.body, design: .rounded, weight: .semibold)
    static let supporting = Font.system(.callout, design: .rounded, weight: .regular)
    static let supportingStrong = Font.system(.callout, design: .rounded, weight: .semibold)
    static let caption = Font.system(.callout, design: .rounded, weight: .medium)
    static let vietnameseHero = Font.system(.largeTitle, design: .rounded, weight: .bold)

    /// Maps a hand-tuned point size to the text style it visually matches,
    /// so Dynamic Type scaling stays proportional across the app.
    static func style(forPointSize size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: .caption2
        case ..<14: .caption
        case ..<16: .footnote
        case ..<18: .subheadline
        case ..<20: .body
        case ..<22: .title3
        case ..<28: .title2
        default: .title
        }
    }
}

/// A fixed design size that still grows and shrinks with the user's
/// Dynamic Type setting. Use instead of `.font(.system(size:))`.
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: KumustaTypography.style(forPointSize: size))
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

private struct ScaledTrackingModifier: ViewModifier {
    @ScaledMetric private var scaledTracking: CGFloat

    init(tracking: CGFloat, relativeTo textStyle: Font.TextStyle) {
        _scaledTracking = ScaledMetric(wrappedValue: tracking, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.tracking(scaledTracking)
    }
}

extension View {
    /// System font at a designed point size that scales with Dynamic Type.
    func scaledFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }

    /// Letter tracking that loosens proportionally with Dynamic Type.
    func scaledTracking(_ tracking: CGFloat, forPointSize size: CGFloat) -> some View {
        modifier(
            ScaledTrackingModifier(
                tracking: tracking,
                relativeTo: KumustaTypography.style(forPointSize: size)
            )
        )
    }
}
