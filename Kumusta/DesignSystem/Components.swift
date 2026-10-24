import SwiftUI
import WebKit

struct KumustaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        KumustaRaisedButtonContent(
            label: configuration.label,
            face: isEnabled ? KumustaColors.accent : KumustaColors.surfaceMuted,
            shadow: isEnabled ? KumustaColors.accentShadow : KumustaColors.line,
            foreground: isEnabled ? .white : KumustaColors.muted,
            faceHeight: 56,
            depth: 6,
            cornerRadius: 18,
            horizontalPadding: 20,
            font: KumustaTypography.bodyStrong,
            border: .clear,
            borderWidth: 0,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

struct KumustaSuccessButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        KumustaRaisedButtonContent(
            label: configuration.label,
            face: isEnabled ? KumustaColors.success : KumustaColors.surfaceMuted,
            shadow: isEnabled ? KumustaColors.success.opacity(0.65) : KumustaColors.line,
            foreground: isEnabled ? .white : KumustaColors.muted,
            faceHeight: 56,
            depth: 6,
            cornerRadius: 18,
            horizontalPadding: 20,
            font: KumustaTypography.bodyStrong,
            border: .clear,
            borderWidth: 0,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

/// A tactile, raised action button used for onboarding decisions and forward
/// navigation. The darker lower face keeps the existing accent color while
/// making the action read as something that can be pressed.
struct KumustaOnboardingButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        KumustaRaisedButtonContent(
            label: configuration.label,
            face: isEnabled ? KumustaColors.accent : KumustaColors.surfaceMuted,
            shadow: isEnabled ? KumustaColors.accentShadow : KumustaColors.line,
            foreground: isEnabled ? .white : KumustaColors.muted,
            faceHeight: 56,
            depth: 6,
            cornerRadius: 18,
            horizontalPadding: 20,
            font: KumustaTypography.bodyStrong,
            border: .clear,
            borderWidth: 0,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

struct KumustaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        KumustaRaisedButtonContent(
            label: configuration.label,
            face: isEnabled ? KumustaColors.surface : KumustaColors.surfaceMuted,
            shadow: isEnabled ? KumustaColors.surfaceStrong : KumustaColors.line,
            foreground: isEnabled ? KumustaColors.ink : KumustaColors.muted,
            faceHeight: 54,
            depth: 5,
            cornerRadius: 18,
            horizontalPadding: 18,
            font: KumustaTypography.bodyStrong,
            border: KumustaColors.line,
            borderWidth: 1.5,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

/// Shared raised-button geometry: a darker lower face stays visible beneath the
/// button and the face sinks into it while pressed, giving every primary action
/// the same tactile Duolingo-style affordance.
struct KumustaRaisedButtonContent<Label: View>: View {
    let label: Label
    let face: Color
    let shadow: Color
    let foreground: Color
    let faceHeight: CGFloat
    let depth: CGFloat
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let font: Font
    let border: Color
    let borderWidth: CGFloat
    let isPressed: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(shadow)
                .frame(maxWidth: .infinity)
                .frame(height: faceHeight + depth)

            label
                .font(font)
                .frame(maxWidth: .infinity)
                .frame(height: faceHeight)
                .padding(.horizontal, horizontalPadding)
                .foregroundStyle(foreground)
                .background(face)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(border, lineWidth: borderWidth)
                }
                .offset(y: reduceMotion ? 0 : (isPressed ? depth : 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: faceHeight + depth)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(reduceMotion ? nil : KumustaMotion.press, value: isPressed)
    }
}

/// A round, raised icon button (play audio, slow audio) with the same pressable
/// lower face as ``KumustaRaisedButtonContent``.
struct KumustaRaisedCircleButtonStyle: ButtonStyle {
    var diameter: CGFloat = 52
    var depth: CGFloat = 4
    var face: Color = KumustaColors.focusFill
    var shadow: Color = KumustaColors.lessonAccentShadow

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        ZStack(alignment: .top) {
            Circle()
                .fill(shadow)
                .frame(width: diameter, height: diameter)
                .offset(y: depth)
            configuration.label
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(face))
                .offset(y: pressed ? depth : 0)
        }
        .frame(width: diameter, height: diameter + depth, alignment: .top)
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Circle())
        .animation(reduceMotion ? nil : KumustaMotion.press, value: configuration.isPressed)
    }
}

struct ChoiceRow<Leading: View>: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    let leadingSize: CGFloat
    @ViewBuilder let leading: Leading

    init(
        title: String,
        detail: String? = nil,
        isSelected: Bool,
        leadingSize: CGFloat = 32,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.detail = detail
        self.isSelected = isSelected
        self.leadingSize = leadingSize
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: 14) {
            leading
                .frame(width: leadingSize, height: leadingSize)
                .foregroundStyle(KumustaColors.muted)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                if let detail {
                    Text(detail)
                        .font(KumustaTypography.supporting)
                        .foregroundStyle(KumustaColors.muted)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(isSelected ? KumustaColors.accentSoft.opacity(0.32) : KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? KumustaColors.accent : KumustaColors.line, lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ScreenHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(KumustaTypography.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(KumustaColors.accentDeep)
            }
            Text(title)
                .font(KumustaTypography.title)
                .foregroundStyle(KumustaColors.ink)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(KumustaTypography.body)
                    .foregroundStyle(KumustaColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            KumustaColors.canvas
            Canvas { context, size in
                var path = Path()
                for x in stride(from: 4.0, through: size.width, by: 9) {
                    for y in stride(from: 4.0, through: size.height, by: 9) {
                        path.addEllipse(in: CGRect(x: x, y: y, width: 0.7, height: 0.7))
                    }
                }
                context.fill(path, with: .color(KumustaColors.ink.opacity(colorScheme == .dark ? 0.018 : 0.055)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct KumustaScreenTopBar: View {
    let centerTitle: String?
    let streak: Int

    init(centerTitle: String? = nil, streak: Int) {
        self.centerTitle = centerTitle
        self.streak = streak
    }

    var body: some View {
        ZStack {
            HStack {
                Text("KUMUSTA")
                    .font(KumustaTypography.patriotBrand)
                    .tracking(-0.45)
                    .foregroundStyle(KumustaColors.accentDeep)
                    .accessibilityLabel("Kumusta")

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(KumustaColors.accent)
                    Text("\(streak)")
                        .foregroundStyle(KumustaColors.ink)
                }
                .scaledFont(15, weight: .bold, design: .rounded)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(KumustaColors.surfaceMuted.opacity(0.72))
                .clipShape(Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L(one: "%lld day streak", other: "%lld-day streak", count: streak))
            }

            if let centerTitle {
                Text(centerTitle.uppercased())
                    .scaledFont(13, weight: .bold, design: .rounded)
                    .scaledTracking(1.7, forPointSize: 13)
                    .foregroundStyle(KumustaColors.muted)
            }
        }
        .frame(height: 38)
    }
}

struct KumustaAmbientShapes: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(KumustaColors.accentSoft.opacity(0.32))
                    .overlay {
                        Circle().stroke(KumustaColors.accent.opacity(0.36), lineWidth: 1)
                    }
                    .frame(width: 94, height: 94)
                    .position(x: proxy.size.width + 5, y: 50)

                Capsule()
                    .fill(KumustaColors.accentSoft.opacity(0.26))
                    .frame(width: 128, height: 20)
                    .rotationEffect(.degrees(-7))
                    .position(x: proxy.size.width - 4, y: proxy.size.height * 0.48)

                Circle()
                    .fill(KumustaColors.surfaceMuted.opacity(0.32))
                    .overlay {
                        Circle()
                            .stroke(
                                KumustaColors.line.opacity(0.72),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    }
                    .frame(width: 108, height: 108)
                    .position(x: -18, y: proxy.size.height * 0.78)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct KumustaEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .scaledFont(13, weight: .bold, design: .rounded)
            .scaledTracking(1.1, forPointSize: 13)
            .foregroundStyle(KumustaColors.accentDeep)
    }
}

/// Opens the app's Settings page — shown next to microphone-permission errors.
struct OpenSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            Label(L("Open Settings"), systemImage: "gearshape.fill")
        }
        .buttonStyle(KumustaSecondaryButtonStyle())
    }
}

/// Caps screen content to a comfortable reading width on iPad while staying
/// full-bleed on iPhone. Backgrounds stay outside this modifier.
private struct ScreenContentWidthModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func screenContentWidth() -> some View {
        modifier(ScreenContentWidthModifier())
    }
}

/// Centralized DiceBear identity generation. Only the opaque account UUID is
/// used as a seed; personal profile data never appears in the avatar URL.
enum DiceBearAvatar {
    static let style = "big-ears"
    private static let endpoint = "https://api.dicebear.com/9.x/\(style)/svg"
    private static let svgStore = DiceBearSVGStore()

    static func seed(for userID: UUID) -> String {
        userID.uuidString.lowercased()
    }

    static func seed(for userID: UUID, persistedSeed: String?) -> String {
        let normalized = persistedSeed?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.flatMap { $0.isEmpty ? nil : $0 } ?? seed(for: userID)
    }

    static func url(seed: String) -> URL? {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [URLQueryItem(name: "seed", value: seed)]
        return components?.url
    }

    static func svgData(seed: String) async throws -> Data {
        guard let url = url(seed: seed) else {
            throw URLError(.badURL)
        }
        return try await svgStore.data(for: url)
    }
}

enum AvatarFallback {
    static func initials(from name: String?) -> String {
        let parts = (name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")

        if let first = parts.first {
            if let last = parts.dropFirst().last {
                return String(first.prefix(1) + last.prefix(1)).uppercased()
            }
            return String(first.prefix(2)).uppercased()
        }

        return "VB"
    }
}

/// A lightweight SVG-backed avatar with a local initials fallback underneath.
/// Keeping the fallback visible means a transient network failure never leaves
/// the profile or leaderboard with an empty box.
struct UserAvatar: View {
    let userID: UUID
    let persistedSeed: String?
    let fallbackText: String
    let size: CGFloat
    @State private var svgData: Data?

    init(
        userID: UUID,
        persistedSeed: String? = nil,
        fallbackText: String? = nil,
        size: CGFloat
    ) {
        self.userID = userID
        self.persistedSeed = persistedSeed
        self.fallbackText = fallbackText ?? "VB"
        self.size = size
    }

    var body: some View {
        let seed = DiceBearAvatar.seed(for: userID, persistedSeed: persistedSeed)

        ZStack {
            Text(fallbackText)
                .scaledFont(max(11, size * 0.31), weight: .bold, design: .rounded)
                .foregroundStyle(KumustaColors.accentDeep)
                .frame(width: size, height: size)
                .background(KumustaColors.accentSoft.opacity(0.48))

            if let svgData {
                DiceBearSVGView(data: svgData)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(KumustaColors.line.opacity(0.75), lineWidth: 1)
        }
        .accessibilityHidden(true)
        .task(id: seed) {
            svgData = nil
            do {
                svgData = try await DiceBearAvatar.svgData(seed: seed)
            } catch {
                // The initials layer remains visible when DiceBear is offline.
            }
        }
    }
}

private actor DiceBearSVGStore {
    private var values: [URL: Data] = [:]

    func data(for url: URL) async throws -> Data {
        if let cached = values[url] {
            return cached
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200 ... 299).contains(httpResponse.statusCode),
            !data.isEmpty
        else {
            throw URLError(.badServerResponse)
        }

        values[url] = data
        return data
    }
}

private struct DiceBearSVGView: UIViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedData != data else { return }
        context.coordinator.loadedData = data
        // A bare SVG document uses WebKit's default document viewport, which
        // can crop the 440x440 illustration inside a 30–98 point avatar.
        // An explicit viewport and fitted image make every size render fully.
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#FFF3DF}
        img{display:block;width:100%;height:100%;object-fit:contain}</style>
        </head><body><img src="data:image/svg+xml;base64,\(data.base64EncodedString())"></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedData: Data?
    }
}
