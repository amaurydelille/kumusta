import SwiftUI

/// A single layered puppet. No animation swaps out the character's body or face.
struct ConversationMascot: View {
  var activity: MascotActivity
  var speech: MascotSpeechFrame = .silent
  var listeningLevel: Double = 0
  var previewGesture: MascotGesture? = nil
  var previewMouth: Int? = nil
  var reduceMotion = false
  @Environment(\.scenePhase) private var scenePhase
  @State private var driver = MascotAnimationDriver(time: ProcessInfo.processInfo.systemUptime)
  @State private var clockOffset = ProcessInfo.processInfo.systemUptime - Date().timeIntervalSinceReferenceDate
  @State private var listeningResponse = MascotListeningResponse()

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion || scenePhase != .active))
    { timeline in
      // Depend on the timeline's date so Canvas receives a new pose every frame,
      // including periods without audio or transcript updates.
      let time = timeline.date.timeIntervalSinceReferenceDate + clockOffset
      let pose = listeningResponse.applying(
        to: driver.pose(at: time, reduceMotion: reduceMotion), at: time,
        enabled: activity == .listening && !reduceMotion)
      Canvas { context, size in
        ConversationMascotRenderer.draw(
          in: &context, size: size, pose: pose,
          speech: speech, speaking: activity == .speaking || activity == .reassuring,
          mouthOverride: previewMouth
        )
      }
    }
    .onAppear {
      driver.transition(to: activity, at: ProcessInfo.processInfo.systemUptime)
      if let previewGesture {
        driver.preview(previewGesture, at: ProcessInfo.processInfo.systemUptime)
      }
    }
    .onChange(of: activity) { _, next in
      driver.transition(to: next, at: ProcessInfo.processInfo.systemUptime)
      listeningResponse.update(level: next == .listening ? listeningLevel : 0, at: ProcessInfo.processInfo.systemUptime)
    }
    .onChange(of: listeningLevel) { _, level in
      listeningResponse.update(level: activity == .listening ? level : 0, at: ProcessInfo.processInfo.systemUptime)
    }
    .onChange(of: previewGesture) { _, next in
      driver.preview(next, at: ProcessInfo.processInfo.systemUptime)
    }
    .accessibilityLabel(L("Tuko, your conversation buddy"))
    .accessibilityValue(activity.rawValue)
  }
}

enum ConversationMascotRenderer {
  static let stage = CGSize(width: 1183, height: 1329)
  private struct PartBounds: Decodable {
    let x: Double, y: Double, width: Double, height: Double
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
  }
  private static let bounds: [String: PartBounds] = {
    guard let data = NSDataAsset(name: "ConversationRigV2")?.data,
      let manifest = try? JSONDecoder().decode([String: PartBounds].self, from: data)
    else { return [:] }
    return manifest
  }()

  static var hasCompleteRig: Bool {
    let names = ["Head", "Body", "EarLeft", "EarRight", "ArmLeft", "ArmRight", "LegLeft",
                 "LegRight", "Tail", "Scarf", "EyeLeft", "EyeRight", "BrowLeft", "BrowRight", "Smile"]
    return names.allSatisfy { bounds[$0] != nil && UIImage(named: "RigV2\($0)") != nil }
      && (0..<12).allSatisfy { UIImage(named: "RigMouth\($0)") != nil }
  }

  static func draw(
    in context: inout GraphicsContext, size: CGSize, pose p: MascotPose,
    speech: MascotSpeechFrame, speaking: Bool, mouthOverride: Int? = nil
  ) {
    let scale = min(size.width / stage.width, size.height / stage.height)
    context.translateBy(
      x: (size.width - stage.width * scale) / 2, y: (size.height - stage.height * scale) / 2)
    context.scaleBy(x: scale, y: scale)

    var feet = context
    feet.translateBy(x: 0, y: -p.footLift * stage.height)
    part("LegLeft", in: feet)
    part("LegRight", in: feet)

    var body = context
    body.translateBy(x: p.bodyX * stage.width, y: p.bodyY * stage.height)
    pivot(&body, at: CGPoint(x: 604, y: 1030), degrees: p.bodyTurn)
    body.translateBy(x: 604, y: 1030)
    body.scaleBy(x: 1, y: p.bodyScaleY)
    body.translateBy(x: -604, y: -1030)
    part("Tail", in: body, angle: p.tail, anchor: CGPoint(x: 807, y: 977))
    part("Body", in: body)
    let armsInFront = p.rightArm > 55 || p.leftArm < -45
    if !armsInFront { arms(in: body, pose: p) }
    part("Scarf", in: body, angle: p.scarf * 0.22, anchor: CGPoint(x: 590, y: 672))

    var head = body
    head.translateBy(x: p.headX * stage.width, y: p.headY * stage.height)
    pivot(&head, at: CGPoint(x: 600, y: 648), degrees: p.headTilt)
    // A very small perspective shift, without squashing the painted face.
    head.translateBy(x: p.headTurn * 0.7, y: 0)
    part("EarLeft", in: head, angle: p.leftEar, anchor: CGPoint(x: 421, y: 276))
    part("EarRight", in: head, angle: p.rightEar, anchor: CGPoint(x: 885, y: 436))
    part("Head", in: head)
    eye("Left", in: head, pose: p)
    eye("Right", in: head, pose: p)
    part("BrowLeft", in: head, offset: CGSize(width: 0, height: -p.brow * 7), angle: -p.brow * 2)
    part("BrowRight", in: head, offset: CGSize(width: 0, height: -p.brow * 7), angle: p.brow * 2)

    drawMouth(in: head, pose: p, speech: speech, speaking: speaking, override: mouthOverride)
    if armsInFront { arms(in: body, pose: p) }
  }

  private static func arms(in context: GraphicsContext, pose: MascotPose) {
    let lift = CGSize(width: 0, height: -pose.armLift * stage.height)
    part("ArmLeft", in: context, offset: lift, angle: pose.leftArm, anchor: CGPoint(x: 416, y: 736))
    part(
      "ArmRight", in: context, offset: lift, angle: pose.rightArm, anchor: CGPoint(x: 760, y: 769))
  }
  private static func eye(_ side: String, in context: GraphicsContext, pose: MascotPose) {
    guard let rect = bounds["Eye\(side)"]?.rect else { return }
    let closure = max(0, min(1, pose.eyelid))
    let shifted = rect.offsetBy(dx: pose.gazeX * stage.width, dy: pose.gazeY * stage.height)
    var open = context
    open.opacity = 1 - MascotChoreography.smooth((closure - 0.72) / 0.22)
    // Occlude the painted eye rather than compressing its iris during a blink.
    let aperture = shifted.insetBy(dx: 0, dy: shifted.height * closure * 0.5)
    open.clip(to: Path(ellipseIn: aperture))
    open.draw(Image("RigV2Eye\(side)"), in: shifted)
    var lid = context
    lid.opacity = MascotChoreography.smooth((closure - 0.64) / 0.25)
    var path = Path()
    let left = CGPoint(x: shifted.minX + 8, y: shifted.midY - 9)
    let right = CGPoint(x: shifted.maxX - 8, y: shifted.midY + 14)
    path.move(to: left)
    path.addQuadCurve(to: right, control: CGPoint(x: shifted.midX, y: shifted.midY + 29))
    lid.stroke(
      path, with: .color(Color(red: 0.22, green: 0.22, blue: 0.24)),
      style: StrokeStyle(lineWidth: 6, lineCap: .round))
  }
  private static func drawMouth(
    in context: GraphicsContext, pose: MascotPose, speech: MascotSpeechFrame,
    speaking: Bool, override: Int?
  ) {
    let opening = speaking ? speech.openness : 0
    if override == nil, opening < 0.025 {
      part("Smile", in: context)
      return
    }
    var mouthContext = context
    pivot(&mouthContext, at: CGPoint(x: 554, y: 558), degrees: 13)
    let rect = CGRect(x: 448, y: 535 + opening * 2, width: 212, height: 106)
    if let override {
      if override == 0 || override == 11 {
        part("Smile", in: context)
      } else {
        mouth(override, weight: 1, in: mouthContext, rect: rect)
      }
      return
    }
    let openWeight = MascotChoreography.smooth(opening / 0.18)
    var resting = context
    resting.opacity = 1 - openWeight
    part("Smile", in: resting)
    let rounded = MascotChoreography.smooth((speech.roundness - 0.3) / 0.5)
    let broad = MascotChoreography.smooth((speech.brightness - 0.35) / 0.35) * (1 - rounded)
    // Draw the two neighboring articulation shapes with continuous weights.
    let anchors = [0.0, 0.18, 0.44, 0.78, 1.0]
    for index in 0..<4 {
      let lower =
        index == 0
        ? 1
        : MascotChoreography.smooth(
          (opening - anchors[index - 1]) / (anchors[index] - anchors[index - 1]))
      let upper =
        index == 3
        ? 0
        : MascotChoreography.smooth(
          (opening - anchors[index]) / (anchors[index + 1] - anchors[index]))
      mouth(
        index + 1, weight: openWeight * (1 - rounded - broad) * lower * (1 - upper),
        in: mouthContext, rect: rect)
    }
    let roundOpen = MascotChoreography.smooth((opening - 0.25) / 0.45)
    mouth(6, weight: openWeight * rounded * (1 - roundOpen), in: mouthContext, rect: rect)
    mouth(5, weight: openWeight * rounded * roundOpen, in: mouthContext, rect: rect)
    mouth(7, weight: openWeight * broad, in: mouthContext, rect: rect)
  }
  private static func mouth(_ index: Int, weight: Double, in context: GraphicsContext, rect: CGRect)
  {
    guard weight > 0.005 else { return }
    var layer = context
    layer.opacity = max(0, min(1, weight))
    layer.draw(Image("RigMouth\(index)"), in: rect)
  }
  private static func part(
    _ name: String, in context: GraphicsContext, offset: CGSize = .zero,
    angle: Double = 0, anchor: CGPoint? = nil
  ) {
    guard let rect = bounds[name]?.rect else { return }
    var local = context
    local.translateBy(x: offset.width, y: offset.height)
    if angle != 0 {
      pivot(&local, at: anchor ?? CGPoint(x: rect.midX, y: rect.midY), degrees: angle)
    }
    local.draw(Image("RigV2\(name)"), in: rect)
  }
  private static func pivot(_ context: inout GraphicsContext, at point: CGPoint, degrees: Double) {
    context.translateBy(x: point.x, y: point.y)
    context.rotate(by: .degrees(degrees))
    context.translateBy(x: -point.x, y: -point.y)
  }
}

#if DEBUG
  /// Local review harness: every authored gesture, state transition, and mouth
  /// can be inspected without a microphone, account, network, or practice quota.
  struct MascotAnimationReview: View {
    @State private var activity: MascotActivity = .greeting
    @State private var gesture: MascotGesture?
    @State private var mouth = -1
    @State private var reduced = false
    @State private var autoTour = true
    @State private var tick = 0.0
    private let tour: [MascotActivity] = [
      .greeting, .idle, .speaking, .listening, .thinking, .reassuring, .speaking, .celebrating,
      .farewell, .idle,
    ]

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 18) {
            ConversationMascot(
              activity: activity, speech: previewSpeech,
              previewGesture: gesture, previewMouth: mouth < 0 ? nil : mouth, reduceMotion: reduced
            )
            .frame(height: 350)
            .accessibilityIdentifier("mascotReviewStage")
            Text("Tuko").font(.system(size: 28, weight: .bold, design: .rounded))
            Text(gesture?.title ?? activity.rawValue.capitalized).foregroundStyle(.secondary)
            Picker("Conversation state", selection: $activity) {
              ForEach(MascotActivity.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Individual movement", selection: $gesture) {
              Text("Natural performance").tag(Optional<MascotGesture>.none)
              ForEach(MascotGesture.allCases) { Text($0.title).tag(Optional($0)) }
            }.pickerStyle(.menu)
            Picker("Mouth shape", selection: $mouth) {
              Text("Audio driven").tag(-1)
              ForEach(0..<12) { Text("Shape \($0 + 1)").tag($0) }
            }.pickerStyle(.menu)
            Toggle("Reduced motion", isOn: $reduced)
            Toggle("Automatic conversation tour", isOn: $autoTour)
            Text("\(MascotGesture.allCases.count) movements · 12 mouth shapes · one shared puppet")
              .font(.footnote).foregroundStyle(.secondary)
          }.padding(24)
        }
        .background(KumustaColors.canvas)
        .navigationTitle("Animation review")
      }
      .task {
        if ProcessInfo.processInfo.arguments.contains("exportMascotReview") {
          MascotReviewExporter.export()
        }
        let origin = ProcessInfo.processInfo.systemUptime
        while !Task.isCancelled {
          tick = ProcessInfo.processInfo.systemUptime - origin
          if autoTour, gesture == nil { activity = tour[Int(tick / 5) % tour.count] }
          try? await Task.sleep(for: .milliseconds(33))
        }
      }
    }
    private var previewSpeech: MascotSpeechFrame {
      guard activity == .speaking || activity == .reassuring else { return .silent }
      // Explicitly synthetic only in this review harness. Live speech uses PCM.
      let phrase = tick.truncatingRemainder(dividingBy: 3.4)
      guard phrase < 2.6 else { return .silent }
      return MascotSpeechFrame(
        energy: 0.04 + abs(sin(tick * 8.1)) * 0.26,
        brightness: 0.1 + abs(sin(tick * 2.3)) * 0.25, voicing: 0.8)
    }
  }

  @MainActor
  private enum MascotReviewExporter {
    static func export() {
      let folder = URL.documentsDirectory.appendingPathComponent("MascotReview", isDirectory: true)
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let gestures = MascotGesture.allCases
      for page in 0..<Int(ceil(Double(gestures.count) / 8)) {
        let slice = Array(gestures.dropFirst(page * 8).prefix(8))
        let width = 1200.0
        let height = Double(slice.count) * 320
        let canvas = Canvas { context, _ in
          context.fill(
            Path(CGRect(x: 0, y: 0, width: width, height: height)),
            with: .color(KumustaColors.canvas))
          for (row, gesture) in slice.enumerated() {
            for column in 0..<4 {
              let fraction = [0.0, 0.28, 0.48, 0.76][column]
              let pose = MascotChoreography.gesture(gesture, time: gesture.duration * fraction)
              var tile = context
              tile.translateBy(x: Double(column) * 300, y: Double(row) * 320 + 18)
              ConversationMascotRenderer.draw(
                in: &tile, size: CGSize(width: 300, height: 270),
                pose: pose, speech: .silent, speaking: false)
              context.draw(
                Text("\(gesture.title) · \(Int(fraction*100))%")
                  .font(.system(size: 12)).foregroundColor(.black),
                at: CGPoint(x: Double(column) * 300 + 150, y: Double(row) * 320 + 302))
            }
          }
        }.frame(width: width, height: height)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        if let data = renderer.uiImage?.pngData() {
          try? data.write(
            to: folder.appendingPathComponent(String(format: "gestures-%02d.png", page + 1)))
        }
      }
      let mouths = Canvas { context, _ in
        context.fill(
          Path(CGRect(x: 0, y: 0, width: 1200, height: 960)), with: .color(KumustaColors.canvas))
        for index in 0..<12 {
          var tile = context
          tile.translateBy(x: Double(index % 4) * 300, y: Double(index / 4) * 320)
          ConversationMascotRenderer.draw(
            in: &tile, size: CGSize(width: 300, height: 290), pose: MascotPose(),
            speech: .silent, speaking: false, mouthOverride: index)
          context.draw(
            Text("Mouth \(index+1)").font(.system(size: 13)).foregroundColor(.black),
            at: CGPoint(x: Double(index % 4) * 300 + 150, y: Double(index / 4) * 320 + 308))
        }
      }.frame(width: 1200, height: 960)
      if let data = ImageRenderer(content: mouths).uiImage?.pngData() {
        try? data.write(to: folder.appendingPathComponent("mouths.png"))
      }
    }
  }

  #Preview("Tuko animation review") { MascotAnimationReview() }
#endif
