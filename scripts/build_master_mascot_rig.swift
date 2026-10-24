import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 5 else {
  fatalError("Expected master, face underpainting, body underpainting and asset catalog")
}
let manager = FileManager.default
let destination = URL(fileURLWithPath: args[4], isDirectory: true)

struct Atlas {
  let width: Int, height: Int
  var pixels: [UInt8]
  init(path: String) {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("Cannot load \(path)") }
    width = image.width
    height = image.height
    pixels = [UInt8](repeating: 0, count: width * height * 4)
    let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
      guard
        let context = CGContext(
          data: raw.baseAddress, width: width, height: height,
          bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard ok else { fatalError("Cannot decode image") }
  }
  func cell(_ index: Int, columns: Int, rows: Int) -> Atlas {
    let x = index % columns * width / columns
    let y = index / columns * height / rows
    let w = width / columns
    let h = height / rows
    return region(CGRect(x: x, y: y, width: w, height: h))
  }
  func region(_ rect: CGRect) -> Atlas {
    let x = Int(rect.minX)
    let y = Int(rect.minY)
    let w = Int(rect.width)
    let h = Int(rect.height)
    var data = [UInt8](repeating: 0, count: w * h * 4)
    for row in 0..<h {
      data.replaceSubrange(
        row * w * 4..<(row + 1) * w * 4,
        with: pixels[((y + row) * width + x) * 4..<((y + row) * width + x + w) * 4])
    }
    return Atlas(width: w, height: h, pixels: data)
  }
  init(width: Int, height: Int, pixels: [UInt8]) {
    self.width = width
    self.height = height
    self.pixels = pixels
  }
  func components() -> [[Int]] {
    var visited = [Bool](repeating: false, count: width * height)
    var groups: [[Int]] = []
    for pixel in 0..<visited.count where !visited[pixel] && pixels[pixel * 4 + 3] > 40 {
      var queue = [pixel]
      var cursor = 0
      visited[pixel] = true
      while cursor < queue.count {
        let p = queue[cursor]
        cursor += 1
        let x = p % width
        let y = p / width
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
          let nx = x + dx
          let ny = y + dy
          guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
          let n = ny * width + nx
          if !visited[n], pixels[n * 4 + 3] > 40 {
            visited[n] = true
            queue.append(n)
          }
        }
      }
      groups.append(queue)
    }
    return groups.sorted { $0.count > $1.count }
  }
  func save(_ name: String, groups selected: [[Int]]? = nil, canvas: CGRect? = nil) throws {
    let groups = components()
    guard let largest = groups.first else { fatalError("Empty cell for \(name)") }
    let keep = selected ?? groups.filter { $0.count >= max(20, largest.count / 55) }
    var mask = [Bool](repeating: false, count: width * height)
    for group in keep {
      for p in group {
        let x = p % width
        let y = p / width
        for dy in -2...2 {
          for dx in -2...2 {
            let nx = x + dx
            let ny = y + dy
            if nx >= 0, nx < width, ny >= 0, ny < height { mask[ny * width + nx] = true }
          }
        }
      }
    }
    let points = mask.indices.filter { mask[$0] && pixels[$0 * 4 + 3] > 8 }
    let minX = points.map { $0 % width }.min()!
    let maxX = points.map { $0 % width }.max()!
    let minY = points.map { $0 / width }.min()!
    let maxY = points.map { $0 / width }.max()!
    let bounds =
      canvas
      ?? CGRect(
        x: max(0, minX - 2), y: max(0, minY - 2), width: min(width - minX + 2, maxX - minX + 5),
        height: min(height - minY + 2, maxY - minY + 5))
    let bx = Int(bounds.minX)
    let by = Int(bounds.minY)
    let w = Int(bounds.width)
    let h = Int(bounds.height)
    var data = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0..<h {
      for x in 0..<w {
        let sx = bx + x
        let sy = by + y
        guard sx >= 0, sx < width, sy >= 0, sy < height, mask[sy * width + sx] else { continue }
        let from = (sy * width + sx) * 4
        let to = (y * w + x) * 4
        data[to..<to + 4] = pixels[from..<from + 4]
      }
    }
    let folder = destination.appendingPathComponent("\(name).imageset", isDirectory: true)
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(name).png")
    guard let provider = CGDataProvider(data: Data(data) as CFData),
      let image = CGImage(
        width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
      let output = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Cannot encode \(name)") }
    CGImageDestinationAddImage(output, image, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Write failed") }
    let contents: [String: Any] = [
      "images": [["filename": "\(name).png", "idiom": "universal"]],
      "info": ["author": "xcode", "version": 1],
    ]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
      .write(to: folder.appendingPathComponent("Contents.json"))
    print("\(name): \(w) × \(h)")
  }
}

// Every visible feature is extracted from the same approved master painting.
// Underpainting supplies only regions hidden by the original eyes and limbs.
extension Atlas {
  func masked(_ path: CGPath, colorTest: ((UInt8, UInt8, UInt8) -> Bool)? = nil) -> Atlas {
    var mask = [UInt8](repeating: 0, count: width * height * 4)
    mask.withUnsafeMutableBytes { raw in
      let context = CGContext(
        data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      context.addPath(path)
      context.setFillColor(CGColor(gray: 1, alpha: 1))
      context.fillPath()
    }
    var output = pixels
    for p in 0..<width * height {
      var coverage = Double(mask[p * 4 + 3]) / 255
      if let colorTest, !colorTest(pixels[p * 4], pixels[p * 4 + 1], pixels[p * 4 + 2]) {
        coverage = 0
      }
      for c in 0..<4 { output[p * 4 + c] = UInt8(Double(pixels[p * 4 + c]) * coverage) }
    }
    return Atlas(width: width, height: height, pixels: output)
  }
  func fitted(width targetWidth: Int, height targetHeight: Int) -> Atlas {
    if width == targetWidth && height == targetHeight { return self }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let image = CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    var output = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
    output.withUnsafeMutableBytes { raw in
      let context = CGContext(
        data: raw.baseAddress, width: targetWidth, height: targetHeight, bitsPerComponent: 8,
        bytesPerRow: targetWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.interpolationQuality = .high
      context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    }
    return Atlas(width: targetWidth, height: targetHeight, pixels: output)
  }
}
func polygon(_ points: [(Double, Double)]) -> CGPath {
  let path = CGMutablePath()
  path.move(to: CGPoint(x: points[0].0, y: points[0].1))
  for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
  path.closeSubpath()
  return path
}
func rectangle(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGPath {
  CGPath(rect: CGRect(x: x, y: y, width: w, height: h), transform: nil)
}
let master = Atlas(path: args[1])
let face = Atlas(path: args[2]).fitted(width: master.width, height: master.height)
let body = Atlas(path: args[3]).fitted(width: master.width, height: master.height)
var manifest: [String: [String: Double]] = [:]
func write(_ name: String, _ image: Atlas) throws {
  let groups = image.components()
  guard let largest = groups.first else { fatalError("Empty component: \(name)") }
  let selected = groups.filter { $0.count >= max(20, largest.count / 55) }
  let points = selected.flatMap { $0 }
  let minX = max(0, points.map { $0 % image.width }.min()! - 4)
  let minY = max(0, points.map { $0 / image.width }.min()! - 4)
  let maxX = min(image.width, points.map { $0 % image.width }.max()! + 5)
  let maxY = min(image.height, points.map { $0 / image.width }.max()! + 5)
  let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  try image.save("RigV2\(name)", groups: selected, canvas: rect)
  manifest[name] = [
    "x": Double(minX), "y": Double(minY), "width": Double(maxX - minX),
    "height": Double(maxY - minY),
  ]
}

let head = CGMutablePath()
head.move(to: CGPoint(x: 443, y: 227))
head.addCurve(
  to: CGPoint(x: 330, y: 421), control1: CGPoint(x: 429, y: 275), control2: CGPoint(x: 362, y: 365))
head.addCurve(
  to: CGPoint(x: 399, y: 615), control1: CGPoint(x: 286, y: 520), control2: CGPoint(x: 329, y: 582))
head.addCurve(
  to: CGPoint(x: 819, y: 671), control1: CGPoint(x: 515, y: 687), control2: CGPoint(x: 725, y: 714))
head.addCurve(
  to: CGPoint(x: 873, y: 448), control1: CGPoint(x: 889, y: 639), control2: CGPoint(x: 889, y: 554))
for point in [
  (868.0, 378.0), (1035, 369), (1040, 204), (884, 171), (862, 88), (599, 89), (563, 30), (374, 25),
  (391, 187),
] {
  head.addLine(to: CGPoint(x: point.0, y: point.1))
}
head.closeSubpath()
// The rest head is the exact master. Only the small feature windows are
// replaced with underpainting, preserving every other original painted pixel.
var headPixels = master.pixels
let featureWindows = [
  CGRect(x: 386, y: 304, width: 165, height: 178), CGRect(x: 651, y: 387, width: 168, height: 179),
  CGRect(x: 475, y: 233, width: 98, height: 56), CGRect(x: 758, y: 299, width: 85, height: 79),
  CGRect(x: 499, y: 523, width: 104, height: 63),
]
for rect in featureWindows {
  for y in Int(rect.minY)..<Int(rect.maxY) {
    for x in Int(rect.minX)..<Int(rect.maxX) {
      let i = (y * master.width + x) * 4
      headPixels[i..<i + 4] = face.pixels[i..<i + 4]
    }
  }
}
// Exclude the red scarf pixels beneath the head boundary; never carry a strip
// of the collar with a head turn. Cheeks lie above these extraction windows.
for y in 615..<720 {
  for x in 300..<920 where y > 646 || x < 710 {
    let i = (y * master.width + x) * 4
    if Double(headPixels[i]) > Double(headPixels[i + 1]) * 1.35 {
      for c in 0..<4 { headPixels[i + c] = 0 }
    }
  }
}
try write(
  "Head", Atlas(width: master.width, height: master.height, pixels: headPixels).masked(head))
let torso = CGMutablePath()
torso.move(to: CGPoint(x: 415, y: 693))
torso.addCurve(
  to: CGPoint(x: 391, y: 917), control1: CGPoint(x: 358, y: 743), control2: CGPoint(x: 391, y: 845))
torso.addCurve(
  to: CGPoint(x: 580, y: 1044), control1: CGPoint(x: 375, y: 990),
  control2: CGPoint(x: 467, y: 1041))
torso.addCurve(
  to: CGPoint(x: 811, y: 949), control1: CGPoint(x: 689, y: 1054),
  control2: CGPoint(x: 816, y: 1026))
torso.addCurve(
  to: CGPoint(x: 785, y: 740), control1: CGPoint(x: 798, y: 890), control2: CGPoint(x: 824, y: 820))
torso.addLine(to: CGPoint(x: 744, y: 688))
torso.closeSubpath()
try write("Body", body.masked(torso))
try write(
  "EarLeft",
  master.masked(
    polygon([(75, 165), (389, 149), (455, 223), (417, 321), (342, 403), (149, 447), (75, 329)])))
try write(
  "EarRight",
  master.masked(
    polygon([(886, 371), (1000, 368), (1169, 529), (1180, 666), (921, 668), (877, 564), (861, 434)])
  ))

let leftArm = CGMutablePath()
leftArm.move(to: CGPoint(x: 397, y: 699))
leftArm.addCurve(
  to: CGPoint(x: 493, y: 866), control1: CGPoint(x: 439, y: 726), control2: CGPoint(x: 450, y: 801))
leftArm.addCurve(
  to: CGPoint(x: 424, y: 959), control1: CGPoint(x: 519, y: 918), control2: CGPoint(x: 481, y: 963))
leftArm.addCurve(
  to: CGPoint(x: 326, y: 866), control1: CGPoint(x: 368, y: 957), control2: CGPoint(x: 331, y: 924))
leftArm.addCurve(
  to: CGPoint(x: 397, y: 699), control1: CGPoint(x: 307, y: 794), control2: CGPoint(x: 336, y: 730))
leftArm.closeSubpath()
let rightArm = CGMutablePath()
rightArm.move(to: CGPoint(x: 754, y: 733))
rightArm.addCurve(
  to: CGPoint(x: 822, y: 902), control1: CGPoint(x: 819, y: 758), control2: CGPoint(x: 841, y: 830))
rightArm.addCurve(
  to: CGPoint(x: 644, y: 958), control1: CGPoint(x: 793, y: 942), control2: CGPoint(x: 697, y: 981))
rightArm.addCurve(
  to: CGPoint(x: 639, y: 846), control1: CGPoint(x: 600, y: 934), control2: CGPoint(x: 602, y: 894))
rightArm.addCurve(
  to: CGPoint(x: 754, y: 733), control1: CGPoint(x: 681, y: 793), control2: CGPoint(x: 704, y: 760))
rightArm.closeSubpath()
try write("ArmLeft", master.masked(leftArm))
try write("ArmRight", master.masked(rightArm))
try write(
  "LegLeft",
  master.masked(
    polygon([(399, 960), (593, 970), (612, 1100), (568, 1296), (336, 1288), (372, 1141)])))
try write(
  "LegRight",
  master.masked(
    polygon([(609, 976), (801, 949), (828, 1108), (895, 1298), (637, 1303), (592, 1123)])))
try write(
  "Tail", master.masked(polygon([(787, 936), (859, 883), (1024, 849), (1040, 1024), (799, 1053)])))
try write(
  "Scarf",
  master.masked(
    polygon([
      (412, 614), (484, 642), (742, 674), (813, 638), (940, 652), (951, 802), (822, 826),
      (730, 733), (577, 812), (511, 807), (427, 737), (391, 658),
    ])))

let leftEye = CGMutablePath()
leftEye.move(to: CGPoint(x: 485, y: 322))
leftEye.addCurve(
  to: CGPoint(x: 399, y: 400), control1: CGPoint(x: 445, y: 319), control2: CGPoint(x: 410, y: 353))
leftEye.addCurve(
  to: CGPoint(x: 459, y: 467), control1: CGPoint(x: 388, y: 441), control2: CGPoint(x: 415, y: 472))
leftEye.addCurve(
  to: CGPoint(x: 538, y: 378), control1: CGPoint(x: 506, y: 465), control2: CGPoint(x: 541, y: 425))
leftEye.addCurve(
  to: CGPoint(x: 485, y: 322), control1: CGPoint(x: 541, y: 340), control2: CGPoint(x: 522, y: 318))
leftEye.closeSubpath()
let rightEye = CGMutablePath()
rightEye.move(to: CGPoint(x: 762, y: 405))
rightEye.addCurve(
  to: CGPoint(x: 670, y: 487), control1: CGPoint(x: 718, y: 398), control2: CGPoint(x: 684, y: 436))
rightEye.addCurve(
  to: CGPoint(x: 722, y: 552), control1: CGPoint(x: 658, y: 523), control2: CGPoint(x: 681, y: 550))
rightEye.addCurve(
  to: CGPoint(x: 803, y: 466), control1: CGPoint(x: 763, y: 554), control2: CGPoint(x: 794, y: 515))
rightEye.addCurve(
  to: CGPoint(x: 762, y: 405), control1: CGPoint(x: 814, y: 430), control2: CGPoint(x: 795, y: 408))
rightEye.closeSubpath()
try write("EyeLeft", master.masked(leftEye))
try write("EyeRight", master.masked(rightEye))
try write(
  "BrowLeft",
  master.masked(
    rectangle(480, 238, 88, 47), colorTest: { r, g, b in Int(r) + Int(g) + Int(b) < 240 }))
try write(
  "BrowRight",
  master.masked(
    rectangle(767, 307, 69, 66), colorTest: { r, g, b in Int(r) + Int(g) + Int(b) < 240 }))
try write(
  "Smile",
  master.masked(
    rectangle(499, 523, 104, 63), colorTest: { r, g, b in r < 150 && r > g && g > b && Int(r) > Int(g) + 18 }))
let dataFolder = destination.appendingPathComponent("ConversationRigV2.dataset", isDirectory: true)
try manager.createDirectory(at: dataFolder, withIntermediateDirectories: true)
let manifestURL = dataFolder.appendingPathComponent("ConversationRigV2.json")
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(
  to: manifestURL)
let contents: [String: Any] = [
  "data": [["filename": "ConversationRigV2.json", "idiom": "universal"]],
  "info": ["author": "xcode", "version": 1],
]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(
  to: dataFolder.appendingPathComponent("Contents.json"))
print("Wrote aligned master rig manifest: \(manifestURL.path)")
