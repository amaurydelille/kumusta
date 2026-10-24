import AppKit

struct Slide {
    let source: String
    let output: String
    let kicker: String
    let headline: String
    let accent: NSColor
    let mirrorBackground: Bool
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let canvasSize = NSSize(width: 1242, height: 2688)

func topRect(_ rect: NSRect) -> NSRect {
    NSRect(x: rect.minX, y: canvasSize.height - rect.minY - rect.height, width: rect.width, height: rect.height)
}

let backgroundURL = root.appendingPathComponent("mobile-app/app-store-screenshots/source-assets/vietbuddy-editorial-background.png")
let mascotURL = root.appendingPathComponent("mobile-app/vietbuddy/VietBuddy/Resources/Assets.xcassets/BeTrauBuddy.imageset/be-trau-buddy@3x.png")

let slides = [
    Slide(
        source: "mobile-app/app-store-screenshots/real-simulator-1242x2688/01-today.png",
        output: "mobile-app/app-store-screenshots/premium-real-ui-1242x2688/01-speak-vietnamese-for-real.png",
        kicker: "VIETBUDDY · REAL-LIFE VIETNAMESE",
        headline: "Vietnamese.\nFor real.",
        accent: NSColor(calibratedRed: 0.90, green: 0.25, blue: 0.16, alpha: 1),
        mirrorBackground: false
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/real-simulator-1242x2688/02-cold-listen.png",
        output: "mobile-app/app-store-screenshots/premium-real-ui-1242x2688/02-hear-it-then-it-clicks.png",
        kicker: "LISTEN FIRST · TRANSLATE LATER",
        headline: "Hear it.\nThen it clicks.",
        accent: NSColor(calibratedRed: 0.88, green: 0.45, blue: 0.10, alpha: 1),
        mirrorBackground: true
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/real-simulator-1242x2688/03-word-gym.png",
        output: "mobile-app/app-store-screenshots/premium-real-ui-1242x2688/03-make-words-stick.png",
        kicker: "TWO-MINUTE WORD GYM",
        headline: "Make words\nstick.",
        accent: NSColor(calibratedRed: 0.72, green: 0.19, blue: 0.13, alpha: 1),
        mirrorBackground: false
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/real-simulator-1242x2688/04-profile.png",
        output: "mobile-app/app-store-screenshots/premium-real-ui-1242x2688/04-your-accent-your-pace.png",
        kicker: "NORTHERN OR SOUTHERN",
        headline: "Your accent.\nYour pace.",
        accent: NSColor(calibratedRed: 0.09, green: 0.42, blue: 0.38, alpha: 1),
        mirrorBackground: true
    )
]

func load(_ url: URL) -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        fatalError("Could not load \(url.path)")
    }
    return image
}

func drawCover(_ image: NSImage, in rect: NSRect, mirrored: Bool = false) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let drawRect = NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    if mirrored {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.maxX + rect.minX, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        image.draw(in: drawRect)
        NSGraphicsContext.restoreGraphicsState()
    } else {
        image.draw(in: drawRect)
    }
}

func drawAspectFill(_ image: NSImage, in rect: NSRect) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let drawRect = NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    image.draw(in: drawRect)
}

let background = load(backgroundURL)
let mascot = load(mascotURL)

for slide in slides {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Could not create canvas") }

    rep.size = canvasSize
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    let context = graphics.cgContext

    drawCover(background, in: NSRect(origin: .zero, size: canvasSize), mirrored: slide.mirrorBackground)

    // A quiet translucent wash keeps the campaign cohesive and the copy crisp.
    NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

    slide.accent.setFill()
    NSBezierPath(roundedRect: topRect(NSRect(x: 84, y: 108, width: 76, height: 14)), xRadius: 7, yRadius: 7).fill()

    let kickerStyle = NSMutableParagraphStyle()
    kickerStyle.lineBreakMode = .byClipping
    let kickerAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 29, weight: .bold),
        .foregroundColor: slide.accent,
        .kern: 1.8,
        .paragraphStyle: kickerStyle
    ]
    (slide.kicker as NSString).draw(in: topRect(NSRect(x: 84, y: 146, width: 900, height: 48)), withAttributes: kickerAttributes)

    let headlineStyle = NSMutableParagraphStyle()
    headlineStyle.lineSpacing = -8
    headlineStyle.lineBreakMode = .byWordWrapping
    let headlineAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 112, weight: .heavy),
        .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.09, blue: 0.07, alpha: 1),
        .kern: -2.7,
        .paragraphStyle: headlineStyle
    ]
    (slide.headline as NSString).draw(in: topRect(NSRect(x: 80, y: 202, width: 900, height: 290)), withAttributes: headlineAttributes)

    mascot.draw(in: topRect(NSRect(x: 945, y: 160, width: 210, height: 236)), from: .zero, operation: .sourceOver, fraction: 1)

    // The real simulator capture is never redrawn: it is clipped and framed as-is.
    let outer = topRect(NSRect(x: 82, y: 570, width: 1078, height: 2265))
    let screen = topRect(NSRect(x: 108, y: 596, width: 1026, height: 2221))
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: 104, yRadius: 104)

    NSGraphicsContext.saveGraphicsState()
    context.setShadow(offset: CGSize(width: 0, height: -30), blur: 38, color: NSColor.black.withAlphaComponent(0.27).cgColor)
    NSColor(calibratedRed: 0.08, green: 0.065, blue: 0.055, alpha: 1).setFill()
    outerPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let screenPath = NSBezierPath(roundedRect: screen, xRadius: 82, yRadius: 82)
    NSGraphicsContext.saveGraphicsState()
    screenPath.addClip()
    let sourceImage = load(root.appendingPathComponent(slide.source))
    drawAspectFill(sourceImage, in: screen)
    NSGraphicsContext.restoreGraphicsState()

    slide.accent.withAlphaComponent(0.50).setStroke()
    screenPath.lineWidth = 3
    screenPath.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(slide.output)")
    }
    let outputURL = root.appendingPathComponent(slide.output)
    try data.write(to: outputURL)
    print(outputURL.path)
}
