import AppKit

struct Slide {
    let source: String
    let outputName: String
    let label: String
    let headline: String
    let subheadline: String
    let sticker: String
    let accent: NSColor
    let secondary: NSColor
    let mascotSide: MascotSide
    let mirrorBackground: Bool
}

enum MascotSide {
    case left
    case right
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let canvasSize = NSSize(width: 1242, height: 2688)
let backgroundURL = root.appendingPathComponent("mobile-app/app-store-screenshots/source-assets/playful-vietnamese-background.png")
let mascotURL = root.appendingPathComponent("mobile-app/vietbuddy/VietBuddy/Resources/Assets.xcassets/BeTrauBuddy.imageset/be-trau-buddy@3x.png")

let cream = NSColor(calibratedRed: 0.985, green: 0.933, blue: 0.815, alpha: 1)
let ink = NSColor(calibratedRed: 0.075, green: 0.065, blue: 0.055, alpha: 1)
let mutedInk = NSColor(calibratedRed: 0.27, green: 0.235, blue: 0.19, alpha: 1)
let coral = NSColor(calibratedRed: 0.92, green: 0.25, blue: 0.15, alpha: 1)
let saffron = NSColor(calibratedRed: 0.98, green: 0.67, blue: 0.12, alpha: 1)
let teal = NSColor(calibratedRed: 0.12, green: 0.50, blue: 0.47, alpha: 1)
let lavender = NSColor(calibratedRed: 0.54, green: 0.42, blue: 0.73, alpha: 1)

let englishSlides = [
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/2.png",
        outputName: "01-listen-first.png",
        label: "LISTENING FIRST",
        headline: "Vietnamese\nstarts with your ears.",
        subheadline: "Listen first. The words land later.",
        sticker: "HEAR IT",
        accent: coral,
        secondary: saffron,
        mascotSide: .right,
        mirrorBackground: false
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/3.png",
        outputName: "02-say-it-out-loud.png",
        label: "SPEAKING PRACTICE",
        headline: "Say it.\nEven if it’s messy.",
        subheadline: "Tiny speaking reps. Real progress.",
        sticker: "SAY IT",
        accent: teal,
        secondary: saffron,
        mascotSide: .left,
        mirrorBackground: true
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/1.png",
        outputName: "03-real-life-audio.png",
        label: "REAL-LIFE AUDIO",
        headline: "Hear a real scene.\nNot a word list.",
        subheadline: "Coffee, directions, everyday Vietnamese.",
        sticker: "PLAY THE SCENE",
        accent: saffron,
        secondary: coral,
        mascotSide: .right,
        mirrorBackground: false
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/4.png",
        outputName: "04-choose-your-accent.png",
        label: "VIETNAMESE ACCENTS",
        headline: "Your ears deserve\nmore than one voice.",
        subheadline: "Choose Northern or Southern Vietnamese.",
        sticker: "PICK A VOICE",
        accent: lavender,
        secondary: teal,
        mascotSide: .left,
        mirrorBackground: true
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/1.png",
        outputName: "05-seven-minute-habit.png",
        label: "A LITTLE EVERY DAY",
        headline: "7 minutes.\nA Vietnamese habit.",
        subheadline: "A little listening beats a lot of someday.",
        sticker: "START SMALL",
        accent: coral,
        secondary: lavender,
        mascotSide: .right,
        mirrorBackground: false
    )
]

let frenchSlides = [
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/2.png",
        outputName: "01-ecouter-dabord.png",
        label: "ÉCOUTE D’ABORD",
        headline: "Le vietnamien\ncommence par l’oreille.",
        subheadline: "Écoutez d’abord. Le sens vient ensuite.",
        sticker: "ÉCOUTER",
        accent: coral,
        secondary: saffron,
        mascotSide: .right,
        mirrorBackground: false
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/3.png",
        outputName: "02-parler-a-voix-haute.png",
        label: "PRATIQUE ORALE",
        headline: "Parlez.\nMême si c’est brouillon.",
        subheadline: "De petites répétitions. De vrais progrès.",
        sticker: "PARLER",
        accent: teal,
        secondary: saffron,
        mascotSide: .left,
        mirrorBackground: true
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/1.png",
        outputName: "03-audio-du-quotidien.png",
        label: "AUDIO DU QUOTIDIEN",
        headline: "Écoutez une scène.\nPas une liste de mots.",
        subheadline: "Café, directions, vie de tous les jours.",
        sticker: "LANCER LA SCÈNE",
        accent: saffron,
        secondary: coral,
        mascotSide: .right,
        mirrorBackground: false
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/4.png",
        outputName: "04-choisir-son-accent.png",
        label: "ACCENTS VIETNAMIENS",
        headline: "Vos oreilles méritent\nplus d’une seule voix.",
        subheadline: "Choisissez l’accent du Nord ou du Sud.",
        sticker: "CHOISIR UNE VOIX",
        accent: lavender,
        secondary: teal,
        mascotSide: .left,
        mirrorBackground: true
    ),
    Slide(
        source: "mobile-app/app-store-screenshots/source-assets/1.png",
        outputName: "05-habitude-de-sept-minutes.png",
        label: "UN PEU CHAQUE JOUR",
        headline: "7 minutes.\nUne habitude vietnamienne.",
        subheadline: "Un peu d’écoute vaut mieux que beaucoup de « un jour ».",
        sticker: "COMMENCER PETIT",
        accent: coral,
        secondary: lavender,
        mascotSide: .right,
        mirrorBackground: false
    )
]

func topRect(_ rect: NSRect) -> NSRect {
    NSRect(x: rect.minX, y: canvasSize.height - rect.minY - rect.height, width: rect.width, height: rect.height)
}

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

func drawAspectFit(_ image: NSImage, in rect: NSRect) {
    let scale = min(rect.width / image.size.width, rect.height / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let drawRect = NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    image.draw(in: drawRect)
}

func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 0) {
    fill.setFill()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0, kern: CGFloat = 0) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineSpacing = lineSpacing
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: kern
    ]
    (text as NSString).draw(in: topRect(rect), withAttributes: attributes)
}

func heavyFont(_ size: CGFloat) -> NSFont {
    NSFont(name: "Arial Rounded MT Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .heavy)
}

func roundedFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont(name: "Avenir Next", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

func drawWave(in rect: NSRect, color: NSColor, count: Int = 11, maxHeight: CGFloat = 78) {
    color.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 12
    path.lineCapStyle = .round
    let step = rect.width / CGFloat(max(count - 1, 1))
    for index in 0..<count {
        let x = rect.minX + CGFloat(index) * step
        let height = maxHeight * (0.34 + CGFloat((index * 7) % 9) / 12)
        path.move(to: NSPoint(x: x, y: rect.midY - height / 2))
        path.line(to: NSPoint(x: x, y: rect.midY + height / 2))
    }
    path.stroke()
}

func drawSpark(at point: NSPoint, color: NSColor, scale: CGFloat = 1) {
    color.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 8 * scale
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: point.x, y: point.y - 24 * scale))
    path.line(to: NSPoint(x: point.x, y: point.y + 24 * scale))
    path.move(to: NSPoint(x: point.x - 24 * scale, y: point.y))
    path.line(to: NSPoint(x: point.x + 24 * scale, y: point.y))
    path.stroke()
}

func drawDecor(for slide: Slide, in context: CGContext) {
    let accent = slide.accent
    let secondary = slide.secondary

    NSGraphicsContext.saveGraphicsState()
    context.setBlendMode(.normal)

    accent.withAlphaComponent(0.94).setFill()
    NSBezierPath(ovalIn: topRect(NSRect(x: 915, y: 106, width: 430, height: 430))).fill()
    secondary.withAlphaComponent(0.78).setFill()
    NSBezierPath(ovalIn: topRect(NSRect(x: -100, y: 490, width: 360, height: 360))).fill()

    NSColor.white.withAlphaComponent(0.35).setFill()
    NSBezierPath(ovalIn: topRect(NSRect(x: 850, y: 610, width: 160, height: 160))).fill()

    drawSpark(at: NSPoint(x: 1050, y: canvasSize.height - 282), color: ink.withAlphaComponent(0.68), scale: 0.72)
    drawSpark(at: NSPoint(x: 138, y: canvasSize.height - 570), color: accent.withAlphaComponent(0.85), scale: 0.58)

    drawWave(in: NSRect(x: 76, y: canvasSize.height - 704, width: 230, height: 120), color: accent.withAlphaComponent(0.9), count: 9, maxHeight: 82)

    NSGraphicsContext.restoreGraphicsState()
}

func drawMascot(_ mascot: NSImage, for slide: Slide) {
    let rect: NSRect
    switch slide.mascotSide {
    case .left:
        // Keep the headline unobstructed; the alternate side is carried by the sticker and mirrored art.
        rect = topRect(NSRect(x: 892, y: 244, width: 300, height: 372))
    case .right:
        rect = topRect(NSRect(x: 900, y: 214, width: 300, height: 372))
    }
    mascot.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}

func drawSticker(_ text: String, for slide: Slide) {
    let width = max(178, CGFloat(text.count) * 17 + 58)
    let x: CGFloat = slide.mascotSide == .left ? 330 : 716
    let rect = topRect(NSRect(x: x, y: 535, width: width, height: 62))
    rounded(rect, radius: 31, fill: ink)
    drawText(text, in: NSRect(x: x, y: 548, width: width, height: 28), font: roundedFont(22, weight: .bold), color: cream, alignment: .center, kern: 1.5)
}

func drawPhone(source: NSImage, accent: NSColor, context: CGContext) {
    let outerTop = NSRect(x: 138, y: 700, width: 966, height: 1946)
    let screenTop = NSRect(x: 166, y: 731, width: 910, height: 1884)
    let outer = topRect(outerTop)
    let screen = topRect(screenTop)
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: 92, yRadius: 92)

    NSGraphicsContext.saveGraphicsState()
    context.setShadow(offset: CGSize(width: 0, height: -34), blur: 42, color: NSColor.black.withAlphaComponent(0.30).cgColor)
    NSColor(calibratedRed: 0.055, green: 0.05, blue: 0.045, alpha: 1).setFill()
    outerPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let screenPath = NSBezierPath(roundedRect: screen, xRadius: 75, yRadius: 75)
    NSGraphicsContext.saveGraphicsState()
    screenPath.addClip()
    drawAspectFit(source, in: screen)
    NSGraphicsContext.restoreGraphicsState()

    accent.withAlphaComponent(0.72).setStroke()
    screenPath.lineWidth = 5
    screenPath.stroke()

    // A simple speaker-like glint makes the hardware feel illustrated rather than sterile.
    NSColor.white.withAlphaComponent(0.72).setStroke()
    let glint = NSBezierPath()
    glint.lineWidth = 6
    glint.move(to: NSPoint(x: outer.minX + 58, y: outer.midY - 430))
    glint.line(to: NSPoint(x: outer.minX + 58, y: outer.midY - 350))
    glint.stroke()
}

func render(_ slide: Slide, languageFolder: String, background: NSImage, mascot: NSImage) {
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
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("Could not create graphics context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    let context = graphics.cgContext

    drawCover(background, in: NSRect(origin: .zero, size: canvasSize), mirrored: slide.mirrorBackground)
    NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()
    drawDecor(for: slide, in: context)

    // The marketing copy stays deliberately short so it reads instantly in a store carousel.
    drawText("VIETBUDDY", in: NSRect(x: 78, y: 88, width: 330, height: 42), font: heavyFont(32), color: ink, kern: 1.3)
    rounded(topRect(NSRect(x: 874, y: 84, width: 290, height: 46)), radius: 23, fill: NSColor.white.withAlphaComponent(0.76), stroke: accentColor(slide.accent).withAlphaComponent(0.35), lineWidth: 2)
    drawText(slide.label, in: NSRect(x: 882, y: 98, width: 274, height: 22), font: roundedFont(16, weight: .bold), color: mutedInk, alignment: .center, kern: 1.5)

    drawMascot(mascot, for: slide)
    let headlineSize: CGFloat = slide.headline.count > 30 ? 92 : 104
    drawText(slide.headline, in: NSRect(x: 78, y: 162, width: 980, height: 274), font: heavyFont(headlineSize), color: ink, lineSpacing: -9, kern: -2.2)
    drawText(slide.subheadline, in: NSRect(x: 84, y: 430, width: 900, height: 92), font: roundedFont(38), color: mutedInk, lineSpacing: 2)
    drawSticker(slide.sticker, for: slide)

    let source = load(root.appendingPathComponent(slide.source))
    drawPhone(source: source, accent: slide.accent, context: context)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode \(slide.outputName)") }
    let outputDir = root.appendingPathComponent("mobile-app/app-store-screenshots/\(languageFolder)")
    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    let outputURL = outputDir.appendingPathComponent(slide.outputName)
    try! data.write(to: outputURL)
    print(outputURL.path)
}

func accentColor(_ color: NSColor) -> NSColor { color }

let background = load(backgroundURL)
let mascot = load(mascotURL)

for slide in englishSlides {
    render(slide, languageFolder: "playful-english-1242x2688", background: background, mascot: mascot)
}
for slide in frenchSlides {
    render(slide, languageFolder: "playful-french-1242x2688", background: background, mascot: mascot)
}
