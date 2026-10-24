import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Mechanical atlas extraction only. Artwork is authored by ImageGen; this
// removes isolated alpha specks and preserves the authored pixels and shading.
// Usage: swift extract_mascot_rig.swift parts.png mouths.png output.xcassets
let args = CommandLine.arguments
guard args.count == 4 else { fatalError("Expected parts atlas, mouth atlas, and asset catalog") }
let manager = FileManager.default
let destination = URL(fileURLWithPath: args[3], isDirectory: true)

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

let parts = Atlas(path: args[1])
let names = [
  "Head", "Body", "EarLeft", "EarRight", "ArmLeft", "ArmRight", "LegLeft", "LegRight", "Tail",
  "Scarf", "EyeLeft", "EyeRight", "LidLeft", "LidRight", "Flower", "Forelock",
]
for (index, name) in names.enumerated() {
  // ImageGen preserves the layout but does not guarantee equal pixel cells.
  // These measured gutters belong to the approved, checked-in source atlas.
  let xEdges = index / 4 == 3 ? [0, 350, 662, 930, 1261] : [0, 350, 662, 954, 1261]
  let yEdges = [0, 380, 700, 986, 1247]
  let col = index % 4
  let row = index / 4
  let sx = Double(parts.width) / 1261
  let sy = Double(parts.height) / 1247
  let cell = parts.region(
    CGRect(
      x: Double(xEdges[col]) * sx, y: Double(yEdges[row]) * sy,
      width: Double(xEdges[col + 1] - xEdges[col]) * sx,
      height: Double(yEdges[row + 1] - yEdges[row]) * sy))
  if index == 10 || index == 11 {
    let components = cell.components()
    try cell.save("Rig\(name)", groups: [components[0]])
    let brows = components.dropFirst().filter { $0.count > components[0].count / 30 }
    if let brow = brows.first {
      try cell.save(index == 10 ? "RigBrowLeft" : "RigBrowRight", groups: [brow])
    }
  } else if index == 12 || index == 13 {
    let components = cell.components().filter { $0.count > 100 }
    let lower = components.max { a, b in
      a.map { $0 / cell.width }.reduce(0, +) / a.count < b.map { $0 / cell.width }.reduce(0, +)
        / b.count
    }!
    try cell.save("Rig\(name)", groups: [lower])
  } else {
    try cell.save("Rig\(name)")
  }
}
let mouths = Atlas(path: args[2])
for index in 0..<12 {
  let cell = mouths.cell(index, columns: 4, rows: 3)
  // Keep authored widths. Align the top articulation line in a common canvas;
  // the generator's cells have slightly different vertical whitespace.
  let largest = cell.components()[0]
  let top = largest.map { $0 / cell.width }.min()!
  try cell.save(
    "RigMouth\(index)", canvas: CGRect(x: 0, y: top - 12, width: cell.width, height: 180))
}
