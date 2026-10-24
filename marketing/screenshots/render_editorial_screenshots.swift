import AppKit
import ImageIO
import UniformTypeIdentifiers

// Five code-rendered panels using only VietBuddy assets and real simulator UI.
struct Panel {
    let file: String
    let screen: String?
    let line1: String
    let prefix: String
    let highlight: String
    let caption: String
    let background: NSColor
    let marker: NSColor
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let page = NSSize(width: 1242, height: 2688)
let ink = NSColor(hex: 0x24221E)
let coral = NSColor(hex: 0xDE5640)
let teal = NSColor(hex: 0x3F6E70)
let cream = NSColor(hex: 0xF8E8CF)
let white = NSColor(hex: 0xFFFCF7)

let sets: [(String, [Panel])] = [
    ("french", [
        Panel(file: "01-le-vietnamien-du-quotidien.png", screen: nil, line1: "Le vietnamien", prefix: "pour la ", highlight: "vraie vie.", caption: "ÉCOUTER  ·  DÉCODER  ·  PARLER", background: white, marker: coral),
        Panel(file: "02-parlez-avec-assurance.png", screen: "01-today.png", line1: "Parlez vietnamien", prefix: "avec ", highlight: "assurance", caption: "UNE SCÈNE DE LA VRAIE VIE, CHAQUE JOUR", background: NSColor(hex: 0xE8F1EE), marker: coral),
        Panel(file: "03-ecoutez-dabord.png", screen: "02-cold-listen.png", line1: "Écoutez une scène", prefix: "avant de ", highlight: "traduire", caption: "L’OREILLE D’ABORD", background: NSColor(hex: 0xF5ECDD), marker: teal),
        Panel(file: "04-des-mots-qui-restent.png", screen: "03-word-gym.png", line1: "Gardez les mots", prefix: "qui ", highlight: "comptent", caption: "DES RÉVISIONS COURTES ET UTILES", background: NSColor(hex: 0xF9E9E2), marker: coral),
        Panel(file: "05-votre-rythme.png", screen: "04-profile.png", line1: "Apprenez à", prefix: "votre ", highlight: "rythme", caption: "ACCENT DU NORD OU DU SUD", background: NSColor(hex: 0xE8EEEA), marker: teal)
    ]),
    ("english", [
        Panel(file: "01-vietnamese-for-real-life.png", screen: nil, line1: "Vietnamese", prefix: "for ", highlight: "real life.", caption: "LISTEN  ·  DECODE  ·  SPEAK", background: white, marker: coral),
        Panel(file: "02-speak-with-confidence.png", screen: "01-today.png", line1: "Speak Vietnamese", prefix: "with ", highlight: "confidence", caption: "ONE REAL-LIFE SCENE AT A TIME", background: NSColor(hex: 0xE8F1EE), marker: coral),
        Panel(file: "03-listen-first.png", screen: "02-cold-listen.png", line1: "Listen to a scene", prefix: "before you ", highlight: "read", caption: "LET YOUR EARS LEAD", background: NSColor(hex: 0xF5ECDD), marker: teal),
        Panel(file: "04-words-that-stick.png", screen: "03-word-gym.png", line1: "Keep the words", prefix: "that ", highlight: "matter", caption: "SHORT, USEFUL WORD REPS", background: NSColor(hex: 0xF9E9E2), marker: coral),
        Panel(file: "05-your-pace.png", screen: "04-profile.png", line1: "Learn at", prefix: "your own ", highlight: "pace", caption: "NORTHERN OR SOUTHERN VIETNAMESE", background: NSColor(hex: 0xE8EEEA), marker: teal)
    ])
]

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: page.height - y - height, width: width, height: height)
}

func fill(_ r: NSRect, _ color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
}

func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat,
          height: CGFloat, size: CGFloat, color: NSColor,
          weight: NSFont.Weight = .regular, kern: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .kern: kern
    ]
    (value as NSString).draw(in: box(x, y, width, height), withAttributes: attributes)
}

func width(_ value: String, size: CGFloat) -> CGFloat {
    (value as NSString).size(withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .black),
        .kern: -3.2
    ]).width
}

func image(_ path: String) -> NSImage {
    guard let result = NSImage(contentsOf: root.appendingPathComponent(path)) else {
        fatalError("Missing asset: \(path)")
    }
    return result
}

let mascot = image("mobile-app/vietbuddy/VietBuddy/Resources/Assets.xcassets/BeTrauBuddy.imageset/be-trau-buddy@3x.png")

func drawHeadline(_ panel: Panel, y: CGFloat, hero: Bool) {
    var size: CGFloat = hero ? 133 : 113
    while max(width(panel.line1, size: size), width(panel.prefix + panel.highlight, size: size)) > 1085 && size > 76 {
        size -= 2
    }
    let x: CGFloat = hero ? 74 : 64
    text(panel.line1, x: x, y: y, width: 1120, height: 155,
         size: size, color: ink, weight: .black, kern: -3.2)
    let secondY = y + (hero ? 166 : 137)
    let prefixWidth = width(panel.prefix, size: size)
    let wordWidth = width(panel.highlight, size: size)
    text(panel.prefix, x: x, y: secondY, width: prefixWidth + 8, height: 150,
         size: size, color: ink, weight: .black, kern: -3.2)
    let markerX = x + prefixWidth - 2
    fill(box(markerX, secondY + 10, wordWidth + 18, size + 12), panel.marker, radius: 5)
    text(panel.highlight, x: markerX + 9, y: secondY, width: wordWidth + 10,
         height: 150, size: size, color: white, weight: .black, kern: -3.2)
}

func drawStep(_ number: Int) {
    fill(box(64, 90, 70, 70), ink, radius: 35)
    text("\(number)", x: 86, y: 98, width: 40, height: 50,
         size: 39, color: white, weight: .black)
    let path = NSBezierPath()
    path.lineWidth = 4
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: 164, y: page.height - 125))
    path.line(to: NSPoint(x: 1170, y: page.height - 125))
    path.move(to: NSPoint(x: 1138, y: page.height - 145))
    path.line(to: NSPoint(x: 1170, y: page.height - 125))
    path.line(to: NSPoint(x: 1138, y: page.height - 105))
    ink.setStroke()
    path.stroke()
}

func drawAppScreen(_ source: String) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current!.cgContext.setShadow(offset: CGSize(width: 0, height: -13),
                                                    blur: 31, color: ink.withAlphaComponent(0.13).cgColor)
    fill(box(27, 751, 1188, 2030), white, radius: 82)
    NSGraphicsContext.restoreGraphicsState()
    let screenshot = image("mobile-app/app-store-screenshots/real-simulator-1242x2688/\(source)")
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: box(50, 774, 1142, 2410), xRadius: 65, yRadius: 65).addClip()
    screenshot.draw(in: box(50, 774, 1142, 2471), from: .zero,
                    operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func drawHero(_ panel: Panel, locale: String) {
    fill(NSRect(origin: .zero, size: page), panel.background)
    fill(box(74, 83, 110, 13), coral, radius: 6)
    text("VIETBUDDY", x: 74, y: 115, width: 420, height: 62,
         size: 36, color: ink, weight: .black, kern: 1.4)
    drawHeadline(panel, y: 270, hero: true)
    text(panel.caption, x: 78, y: 686, width: 1030, height: 62,
         size: 32, color: teal, weight: .bold, kern: 2)
    let french = locale == "french"
    text("7", x: 76, y: 883, width: 290, height: 280,
         size: 248, color: ink, weight: .black, kern: -8)
    text(french ? "MINUTES PAR JOUR" : "MINUTES A DAY", x: 328, y: 1011,
         width: 760, height: 89, size: 58, color: ink, weight: .black, kern: -1.8)
    fill(box(78, 1224, 558, 102), cream, radius: 51)
    text(french ? "ACCENTS NORD + SUD" : "NORTHERN + SOUTHERN", x: 119, y: 1255,
         width: 490, height: 62, size: 35, color: ink, weight: .bold, kern: 0.1)

    // Rising route and Bé Trâu replace the reference's photography with the
    // app's own character and a simple, hand-drawn growth motif.
    let route = NSBezierPath()
    route.lineWidth = 22
    route.lineCapStyle = .round
    route.move(to: NSPoint(x: 80, y: page.height - 2390))
    route.curve(to: NSPoint(x: 1127, y: page.height - 1460),
                controlPoint1: NSPoint(x: 420, y: page.height - 2300),
                controlPoint2: NSPoint(x: 850, y: page.height - 1800))
    coral.setStroke()
    route.stroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 22
    arrow.lineCapStyle = .round
    arrow.move(to: NSPoint(x: 1019, y: page.height - 1499))
    arrow.line(to: NSPoint(x: 1127, y: page.height - 1460))
    arrow.line(to: NSPoint(x: 1094, y: page.height - 1570))
    arrow.stroke()
    fill(box(475, 1620, 716, 716), NSColor(hex: 0xF4B4A1), radius: 358)
    mascot.draw(in: box(528, 1600, 650, 730), from: .zero,
                operation: .sourceOver, fraction: 1)
    fill(box(73, 2466, 654, 113), teal, radius: 56)
    text(french ? "VIETNAMIEN DU QUOTIDIEN" : "REAL-LIFE VIETNAMESE",
         x: 119, y: 2497, width: 600, height: 70,
         size: french ? 37 : 40, color: white, weight: .black, kern: -0.5)
}

func drawFeature(_ panel: Panel, step: Int) {
    fill(NSRect(origin: .zero, size: page), panel.background)
    drawStep(step)
    drawHeadline(panel, y: 230, hero: false)
    text(panel.caption, x: 68, y: 588, width: 1080, height: 48,
         size: 27, color: ink.withAlphaComponent(0.66), weight: .bold, kern: 1.6)
    drawAppScreen(panel.screen!)
}

func render(_ panel: Panel, index: Int, locale: String, pixels: NSSize) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Could not create bitmap") }
    bitmap.size = page
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: pixels.width / page.width, y: pixels.height / page.height)
    if index == 0 { drawHero(panel, locale: locale) } else { drawFeature(panel, step: index) }
    NSGraphicsContext.restoreGraphicsState()

    let folder = root.appendingPathComponent("mobile-app/app-store-screenshots/story-\(locale)-\(Int(pixels.width))x\(Int(pixels.height))")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let destination = folder.appendingPathComponent(panel.file)
    guard let source = bitmap.cgImage,
          let opaque = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height),
                                 bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
          let output = CGImageDestinationCreateWithURL(destination as CFURL,
                                                       UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not prepare opaque PNG")
    }
    opaque.draw(source, in: CGRect(origin: .zero, size: CGSize(width: pixels.width, height: pixels.height)))
    guard let finalImage = opaque.makeImage() else { fatalError("Could not flatten PNG") }
    CGImageDestinationAddImage(output, finalImage, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Could not export PNG") }
    print(destination.path)
}

for (locale, panels) in sets {
    for pixels in [NSSize(width: 1242, height: 2688), NSSize(width: 1320, height: 2868)] {
        for (index, panel) in panels.enumerated() {
            try render(panel, index: index, locale: locale, pixels: pixels)
        }
    }
}
