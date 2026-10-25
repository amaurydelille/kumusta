import Foundation

/// The same skeleton and coordinate system are used for every performance.
/// Angles are degrees; distances are fractions of the 1,000-unit stage.
enum MascotActivity: String, CaseIterable, Identifiable {
  case greeting, idle, speaking, listening, thinking, reassuring, celebrating, farewell
  var id: String { rawValue }
}

enum MascotGesture: String, CaseIterable, Identifiable {
  case breathe, blink, doubleBlink, gazeAdjust, headSettle, weightShift, shoulderRelax, hoofAdjust
  case earTwitch, tailFlick, smileSoften, postureReset
  case curiousTilt, tiltReturn, acknowledge, thoughtfulNod, enthusiasticNod, gentleShake
  case contentGlance, eyeContact, thinkingGlance, recognition, browLift, reassure, amused, surprise
  case speechBeat, explainLeft, explainRight, explainBoth, present, selfReference, invite, question
  case contrast, sequence, emphasize, reflect, chuckle, phraseSettle, handReturn
  case listeningPrepare, listenLean, earsAttend, quietListen, listeningNod, interestedTilt
  case concentrate, patientPause, listeningRecover, interrupted
  case processing, chinThink, reflectiveTilt, waitingShift, exhale, responseReady, extendedWait
  case warmAcknowledge, tryAgain, slowDemonstration, improvement, smallSuccess, clap, bounce
  case proud, milestone, appreciation, farewellWave
  case earPerk, happyEars, relaxedEars, tailCurl, tailSwish, scarfFollow, flowerFollow
  case forelockFollow, muzzleSmile, bashful, playfulLean, signatureGreeting

  var id: String { rawValue }
  var title: String {
    rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
      .capitalized
  }
  var duration: Double {
    switch self {
    case .blink: 0.22
    case .doubleBlink: 0.48
    case .earTwitch, .tailFlick, .earPerk: 0.9
    case .signatureGreeting, .farewellWave, .milestone: 3.2
    case .breathe, .extendedWait, .quietListen, .patientPause: 4.6
    default: 2.4
    }
  }
}

struct MascotPose: Equatable {
  var bodyX = 0.0, bodyY = 0.0, bodyTurn = 0.0, bodyScaleY = 1.0
  var headX = 0.0, headY = 0.0, headTilt = 0.0, headTurn = 0.0
  var leftArm = 0.0, rightArm = 0.0, armLift = 0.0
  var leftEar = 0.0, rightEar = 0.0, tail = 0.0
  var scarf = 0.0, flower = 0.0, forelock = 0.0
  var gazeX = 0.0, gazeY = 0.0, eyelid = 0.0, brow = 0.0
  var smile = 0.0, jaw = 0.0, footLift = 0.0

  private var values: [Double] {
    [
      bodyX, bodyY, bodyTurn, bodyScaleY, headX, headY, headTilt, headTurn,
      leftArm, rightArm, armLift, leftEar, rightEar, tail, scarf, flower, forelock,
      gazeX, gazeY, eyelid, brow, smile, jaw, footLift,
    ]
  }
  private init(_ v: [Double]) {
    bodyX = v[0]
    bodyY = v[1]
    bodyTurn = v[2]
    bodyScaleY = v[3]
    headX = v[4]
    headY = v[5]
    headTilt = v[6]
    headTurn = v[7]
    leftArm = v[8]
    rightArm = v[9]
    armLift = v[10]
    leftEar = v[11]
    rightEar = v[12]
    tail = v[13]
    scarf = v[14]
    flower = v[15]
    forelock = v[16]
    gazeX = v[17]
    gazeY = v[18]
    eyelid = v[19]
    brow = v[20]
    smile = v[21]
    jaw = v[22]
    footLift = v[23]
  }
  init() {}
  func blended(to other: Self, amount: Double) -> Self {
    let a = max(0, min(1, amount))
    return Self(zip(values, other.values).map { $0 + ($1 - $0) * a })
  }
  func adding(_ other: Self, weight: Double = 1) -> Self {
    var delta = other.values
    delta[3] -= 1
    return Self(zip(values, delta).map { $0 + $1 * weight })
  }
  var isFinite: Bool { values.allSatisfy(\.isFinite) }
}

enum MascotChoreography {
  static func smooth(_ x: Double) -> Double {
    let t = max(0, min(1, x))
    return t * t * (3 - 2 * t)
  }
  static func envelope(_ t: Double) -> Double {
    smooth(t / 0.23) * (1 - smooth((t - 0.65) / 0.35))
  }
  static func gesture(_ gesture: MascotGesture, time: Double, strength: Double = 1) -> MascotPose {
    guard time >= 0, time <= gesture.duration else { return MascotPose() }
    let t = time / gesture.duration
    let e = envelope(t) * strength
    let beat = sin(t * .pi * 4) * e
    var p = MascotPose()
    switch gesture {
    case .breathe: p.bodyScaleY += sin(t * .pi * 2) * 0.009
    case .blink, .doubleBlink:
      let count = gesture == .doubleBlink ? 2.0 : 1.0
      p.eyelid = pow(abs(sin(t * .pi * count)), 1.4)
    case .gazeAdjust:
      p.gazeX = 0.005 * e
      p.gazeY = -0.002 * e
    case .headSettle, .postureReset:
      p.headTilt = 2.5 * e
      p.bodyX = -0.003 * e
    case .weightShift, .waitingShift:
      p.bodyX = 0.008 * e
      p.bodyTurn = -1.5 * e
      p.headTilt = 1.5 * e
    case .shoulderRelax, .exhale:
      p.bodyY = 0.004 * e
      p.armLift = -0.003 * e
    case .hoofAdjust, .handReturn:
      p.leftArm = -5 * e
      p.rightArm = 4 * e
    case .earTwitch: p.leftEar = 7 * beat
    case .tailFlick: p.tail = 13 * beat
    case .smileSoften, .muzzleSmile: p.smile = 0.8 * e
    case .curiousTilt, .interestedTilt, .reflectiveTilt:
      p.headTilt = 7 * e
      p.brow = 0.5 * e
      p.rightEar = -4 * e
    case .tiltReturn, .listeningRecover:
      p.headTilt = -3 * e
      p.headY = 0.002 * e
    case .acknowledge, .listeningNod, .warmAcknowledge:
      p.headY = 0.009 * e
      p.headTilt = -2 * e
      p.smile = 0.5 * e
    case .thoughtfulNod:
      p.headY = 0.011 * e
      p.eyelid = 0.2 * e
    case .enthusiasticNod, .improvement:
      p.headY = 0.009 * abs(beat)
      p.smile = e
      p.brow = 0.4 * e
    case .gentleShake:
      p.headTurn = 4 * beat
      p.headTilt = 2 * beat
    case .contentGlance:
      p.gazeX = 0.008 * e
      p.gazeY = 0.004 * e
      p.headTurn = 3 * e
    case .eyeContact, .responseReady:
      p.headY = -0.003 * e
      p.brow = 0.3 * e
      p.smile = 0.4 * e
    case .thinkingGlance, .processing:
      p.gazeX = -0.008 * e
      p.gazeY = -0.004 * e
      p.headTilt = -4 * e
    case .recognition:
      p.brow = e
      p.smile = e
      p.headY = -0.005 * e
    case .browLift: p.brow = e
    case .reassure, .patientPause, .tryAgain:
      p.headTilt = 5 * e
      p.smile = 0.7 * e
      p.eyelid = 0.12 * e
      p.rightArm = -16 * e
    case .amused, .chuckle:
      p.smile = e
      p.eyelid = 0.3 * e
      p.bodyY = -0.003 * abs(beat)
    case .surprise:
      p.brow = 1.2 * e
      p.headY = -0.006 * e
      p.leftEar = -6 * e
      p.rightEar = 6 * e
    case .speechBeat:
      p.rightArm = -12 * e
      p.headY = 0.002 * beat
    case .explainLeft:
      p.leftArm = 28 * e
      p.headTilt = -3 * e
    case .explainRight, .present, .slowDemonstration:
      p.rightArm = -28 * e
      p.headTilt = 3 * e
    case .explainBoth:
      p.leftArm = 24 * e
      p.rightArm = -24 * e
      p.brow = 0.4 * e
    case .selfReference, .appreciation:
      p.rightArm = 65 * e
      p.smile = 0.6 * e
      p.headY = 0.004 * e
    case .invite, .question:
      p.leftArm = 22 * e
      p.headTilt = 6 * e
      p.brow = 0.7 * e
    case .contrast:
      p.leftArm = 24 * e * smooth(t * 3)
      p.rightArm = -24 * e * (1 - smooth((t - 0.4) * 3))
      p.headTurn = 3 * beat
    case .sequence:
      p.rightArm = -20 * e - 5 * beat
      p.headY = 0.002 * beat
    case .emphasize, .listenLean:
      p.headY = -0.004 * e
      p.headX = 0.002 * e
      p.bodyTurn = -1 * e
      p.brow = 0.4 * e
    case .reflect:
      p.headTilt = -4 * e
      p.bodyY = 0.003 * e
    case .phraseSettle:
      p.headY = 0.003 * e
      p.armLift = -0.002 * e
    case .listeningPrepare, .earsAttend, .concentrate:
      p.leftEar = -6 * e
      p.rightEar = 6 * e
      p.brow = 0.35 * e
    case .quietListen, .extendedWait:
      p.headTilt = 2 * e
      p.smile = 0.2 * e
    case .interrupted:
      p.headTilt = 3 * e
      p.brow = 0.4 * e
      p.leftArm = -3 * e
      p.rightArm = 3 * e
    case .chinThink:
      // Tuko's arm hangs out to the side; this brings the hand up to the chin.
      p.rightArm = 165 * e
      p.armLift = 0.004 * e
      p.gazeX = -0.006 * e
      p.headTilt = -5 * e
    case .smallSuccess, .proud:
      p.headY = -0.005 * e
      p.bodyScaleY += 0.008 * e
      p.smile = e
      p.leftEar = -4 * e
      p.rightEar = 4 * e
    case .clap:
      p.leftArm = -35 * e + 4 * beat
      p.rightArm = 35 * e - 4 * beat
      p.armLift = 0.018 * e
      p.smile = e
    case .bounce, .milestone:
      let jump = pow(max(0, sin(t * .pi)), 2)
      p.bodyY = -0.025 * jump * strength
      p.footLift = 0.025 * jump * strength
      p.leftArm = 35 * e
      p.rightArm = -35 * e
      p.smile = e
      p.tail = 12 * beat
    case .farewellWave, .signatureGreeting:
      // Raises the hand beside the head, not above it.
      p.leftArm = (100 + 9 * sin(t * .pi * 6)) * e
      p.headTilt = -4 * e
      p.smile = e
      p.rightEar = 3 * e
    case .earPerk: p.leftEar = -9 * e
    case .happyEars:
      p.leftEar = -7 * e
      p.rightEar = 7 * e
      p.smile = 0.6 * e
    case .relaxedEars:
      p.leftEar = 3 * e
      p.rightEar = -3 * e
    case .tailCurl: p.tail = 10 * e
    case .tailSwish: p.tail = 18 * beat
    case .scarfFollow:
      p.scarf = 8 * beat
      p.bodyTurn = 2 * e
    case .flowerFollow:
      p.flower = 5 * beat
      p.headTilt = 3 * e
    case .forelockFollow:
      p.forelock = 4 * beat
      p.headY = 0.006 * e
    case .bashful:
      p.headY = 0.008 * e
      p.headTilt = -6 * e
      p.eyelid = 0.2 * e
      p.smile = e
    case .playfulLean:
      p.bodyTurn = 3 * e
      p.headTilt = -5 * e
      p.leftArm = 12 * e
      p.smile = e
    }
    return p
  }

  static func baseline(time: Double, activity: MascotActivity, seed: UInt64) -> MascotPose {
    var p = MascotPose()
    let breath = sin(time * 2 * .pi / 4.3)
    p.bodyScaleY = 1 + 0.012 * breath
    p.headY = -0.003 * breath
    p.bodyX = 0.0015 * sin(time * 0.71)
    p.headTilt = 0.65 * sin(time * 0.49)
    // Independent, reproducible blink windows, with a minimum quiet gap.
    let slot = Int(floor(time / 5))
    for candidate in max(0, slot - 1)...max(0, slot) {
      let random = unit(seed &+ UInt64(candidate) &* 7919)
      let start = Double(candidate) * 5 + 1.2 + random * 2.7
      let doubleBlink = unit(seed &+ UInt64(candidate) &* 3571) > 0.88
      p = p.adding(gesture(doubleBlink ? .doubleBlink : .blink, time: time - start))
    }
    let glance = sin(time * 0.31)
    p.gazeX = 0.0014 * glance
    p.tail = 1.8 * sin(time * 0.82)
    switch activity {
    case .listening:
      p.headTilt += 3
      p.brow = 0.15
      p.leftEar = -3
      p.rightEar = 3
    case .thinking:
      p.headTilt -= 3
      p.gazeX -= 0.003
      p.gazeY -= 0.002
    case .reassuring:
      p.headTilt += 3
      p.smile = 0.6
    case .celebrating: p.smile = 0.7
    default: break
    }
    return p
  }

  static func unit(_ seed: UInt64) -> Double {
    var n = seed &+ 0x9e37_79b9_7f4a_7c15
    n = (n ^ (n >> 30)) &* 0xbf58_476d_1ce4_e5b9
    n = (n ^ (n >> 27)) &* 0x94d0_49bb_1331_11eb
    return Double((n ^ (n >> 31)) & 0xFFFFFF) / Double(0xFFFFFF)
  }

  static func repertoire(_ activity: MascotActivity) -> [MascotGesture] {
    switch activity {
    case .greeting: [.signatureGreeting]
    case .idle:
      [.weightShift, .earTwitch, .tailFlick, .smileSoften, .headSettle, .hoofAdjust, .postureReset]
    case .speaking:
      [
        .explainRight, .speechBeat, .explainLeft, .present, .explainBoth, .sequence, .emphasize,
        .phraseSettle,
      ]
    case .listening: [.interestedTilt, .listeningNod, .earPerk, .listenLean, .quietListen]
    case .thinking: [.thinkingGlance, .reflectiveTilt, .waitingShift, .extendedWait]
    case .reassuring: [.reassure, .tryAgain, .warmAcknowledge, .invite]
    case .celebrating: [.smallSuccess]
    case .farewell: [.farewellWave]
    }
  }
}

/// Transitions begin at the currently displayed pose, including interruptions.
/// Sampling is pure: frame rate changes do not change choreography or blink timing.
struct MascotAnimationDriver {
  let seed: UInt64
  let origin: Double
  private(set) var activity: MascotActivity
  private var transitionTime: Double
  private var previous = MascotPose()
  private var hasTransition = false
  var previewGesture: MascotGesture?

  init(activity: MascotActivity = .greeting, time: Double, seed: UInt64 = 20_261_008) {
    self.seed = seed
    origin = time
    transitionTime = time
    self.activity = activity
  }
  mutating func transition(to next: MascotActivity, at time: Double) {
    guard next != activity else { return }
    previous = pose(at: time)
    activity = next
    transitionTime = time
    hasTransition = true
  }
  mutating func preview(_ gesture: MascotGesture?, at time: Double) {
    previous = pose(at: time)
    previewGesture = gesture
    transitionTime = time
    hasTransition = true
  }
  func pose(at time: Double, reduceMotion: Bool = false) -> MascotPose {
    if reduceMotion {
      var p = MascotPose()
      p.smile = activity == .reassuring || activity == .celebrating ? 0.6 : 0
      p.brow = activity == .listening ? 0.15 : 0
      return p
    }
    let age = max(0, time - origin)
    let elapsed = max(0, time - transitionTime)
    var p = MascotChoreography.baseline(time: age, activity: activity, seed: seed)
    if let previewGesture {
      let cycle = previewGesture.duration + 1.2
      p = p.adding(
        MascotChoreography.gesture(
          previewGesture, time: elapsed.truncatingRemainder(dividingBy: cycle)))
    } else {
      let choices = MascotChoreography.repertoire(activity)
      if [.greeting, .farewell, .celebrating].contains(activity) {
        p = p.adding(MascotChoreography.gesture(choices[0], time: elapsed))
      } else {
        let interval = activity == .speaking ? 3.8 : activity == .listening ? 4.8 : 6.4
        let slot = Int(elapsed / interval)
        // Rotate through the repertoire, then vary strength and start time.
        // Adjacent slots never repeat a gesture.
        // Let a longer gesture finish across a slot boundary instead of
        // snapping it back when the next movement is scheduled.
        for candidate in max(0, slot - 1)...slot {
          let offset = activity == .listening ? 0 : Int(seed % UInt64(choices.count))
          let index = (candidate + offset) % choices.count
          let jitter = 0.6 + MascotChoreography.unit(seed &+ UInt64(candidate) &* 31) * 1.0
          let local = elapsed - Double(candidate) * interval - jitter
          let strength = 0.7 + MascotChoreography.unit(seed &+ UInt64(candidate) &* 97) * 0.3
          p = p.adding(MascotChoreography.gesture(choices[index], time: local, strength: strength))
        }
      }
    }
    // Follow-through is driven by the primary movement, rather than wind.
    p.scarf += p.bodyTurn * -1.4 + p.rightArm * 0.035
    p.flower += p.headTilt * -0.25
    p.forelock += p.headTilt * -0.18
    if hasTransition {
      p = previous.blended(to: p, amount: MascotChoreography.smooth(elapsed / 0.42))
    }
    return p
  }
}

/// Smooth attention follows the user's voice without copying syllables into
/// mouth movements or making the head shake with every microphone buffer.
struct MascotListeningResponse {
  private var start = 0.0
  private var target = 0.0
  private var changedAt = 0.0

  func amount(at time: Double) -> Double {
    let duration = target > start ? 0.28 : 0.75
    return start + (target - start) * (1 - exp(-max(0, time - changedAt) / duration))
  }

  mutating func update(level: Double, at time: Double) {
    start = amount(at: time)
    target = min(1, max(0, (level - 0.06) * 3))
    changedAt = time
  }

  func applying(to pose: MascotPose, at time: Double, enabled: Bool) -> MascotPose {
    guard enabled else { return pose }
    let attention = amount(at: time)
    var result = pose
    result.headTilt += attention * 4
    result.headY -= attention * 0.008
    result.bodyTurn -= attention * 0.7
    result.leftEar -= attention * 5
    result.rightEar += attention * 5
    result.brow += attention * 0.2
    return result
  }
}

/// Features are measured from PCM windows and sampled at the player's render
/// position. They are audio-driven articulation estimates, not phoneme labels.
struct MascotSpeechFrame: Equatable, Sendable {
  var energy = 0.0
  var brightness = 0.0
  var voicing = 0.0
  static let silent = Self()
  var openness: Double { min(0.85, max(0, (energy - 0.025) * 1.7)) }
  var roundness: Double { max(0, min(1, 1 - brightness * 4)) * voicing }
}

struct MascotSpeechTimeline {
  struct Window {
    let start: Int64
    let end: Int64
    let features: MascotSpeechFrame
  }
  private(set) var windows: [Window] = []
  private(set) var scheduledFrames: Int64 = 0

  mutating func append(pcm16 bytes: Data, at startFrame: Int64? = nil) {
    let count = bytes.count / 2
    guard count > 0 else { return }
    // Playback keeps advancing through network gaps. New PCM must use its
    // actual scheduled player position rather than the sum of received bytes.
    let base = max(scheduledFrames, startFrame ?? scheduledFrames)
    bytes.withUnsafeBytes { raw in
      for start in stride(from: 0, to: count, by: 480) {
        let end = min(count, start + 480)
        var squares = 0.0
        var difference = 0.0
        var previous = 0.0
        for index in start..<end {
          let sample =
            Double(
              Int16(littleEndian: raw.loadUnaligned(fromByteOffset: index * 2, as: Int16.self)))
            / 32768
          squares += sample * sample
          if index > start { difference += abs(sample - previous) }
          previous = sample
        }
        let rms = sqrt(squares / Double(end - start))
        let brightness = difference / Double(max(1, end - start - 1)) / max(0.0001, rms)
        let frame = MascotSpeechFrame(
          energy: min(1, rms * 5),
          brightness: min(1, brightness),
          voicing: rms < 0.003 ? 0 : max(0, 1 - brightness * 1.3)
        )
        windows.append(
          Window(
            start: base + Int64(start), end: base + Int64(end),
            features: frame))
      }
    }
    scheduledFrames = base + Int64(count)
  }
  func containsAudio(at frame: Int64) -> Bool {
    window(at: frame) != nil
  }
  func sample(at frame: Int64) -> MascotSpeechFrame {
    window(at: frame)?.features ?? .silent
  }
  private func window(at frame: Int64) -> Window? {
    guard frame >= 0, frame < scheduledFrames, !windows.isEmpty else { return nil }
    var low = 0
    var high = windows.count
    while low < high {
      let middle = (low + high) / 2
      if windows[middle].end <= frame { low = middle + 1 } else { high = middle }
    }
    guard low < windows.count, windows[low].start <= frame else { return nil }
    return windows[low]
  }
  mutating func discard(before frame: Int64) {
    windows.removeAll { $0.end <= frame }
  }
  mutating func reset() {
    windows.removeAll(keepingCapacity: true)
    scheduledFrames = 0
  }
}
