import Foundation
import Testing

@testable import Kumusta

@Suite("Tuko performance continuity")
struct MascotPerformanceTests {
  @MainActor @Test("The compiled app contains every puppet part and its placement manifest")
  func packagedArtwork() {
    #expect(ConversationMascotRenderer.hasCompleteRig)
  }
  @Test("Every gesture has finite poses and returns to the common skeleton")
  func gestureBounds() {
    for gesture in MascotGesture.allCases {
      #expect(MascotChoreography.gesture(gesture, time: -1) == MascotPose())
      #expect(MascotChoreography.gesture(gesture, time: gesture.duration + 0.01) == MascotPose())
      for frame in 0...240 {
        let pose = MascotChoreography.gesture(gesture, time: gesture.duration * Double(frame) / 240)
        #expect(pose.isFinite, "\(gesture.rawValue), frame \(frame)")
        #expect(abs(pose.bodyX) < 0.02)
        #expect(abs(pose.bodyTurn) < 5)
        #expect(pose.bodyScaleY > 0.97 && pose.bodyScaleY < 1.03)
        #expect(pose.eyelid >= 0 && pose.eyelid <= 1)
      }
    }
  }
  @Test("Interruptions preserve the exact displayed pose in every state pair")
  func interruptionContinuity() {
    for source in MascotActivity.allCases {
      for destination in MascotActivity.allCases {
        var driver = MascotAnimationDriver(activity: source, time: 100)
        let before = driver.pose(at: 102.2)
        driver.transition(to: destination, at: 102.2)
        #expect(driver.pose(at: 102.2) == before)
        #expect(driver.pose(at: 102.201).isFinite)
        #expect(driver.pose(at: 103).isFinite)
      }
    }
  }
  @Test("Repeated interruptions and preview changes remain continuous")
  func repeatedTransitions() {
    var driver = MascotAnimationDriver(time: 0)
    for (index, activity) in MascotActivity.allCases.enumerated() {
      let time = 0.1 * Double(index)
      let before = driver.pose(at: time)
      driver.transition(to: activity, at: time)
      #expect(driver.pose(at: time) == before)
    }
    let before = driver.pose(at: 1)
    driver.preview(.signatureGreeting, at: 1)
    #expect(driver.pose(at: 1) == before)
  }
  @Test("Reduced motion is stable and contains no automatic displacement")
  func reducedMotion() {
    for activity in MascotActivity.allCases {
      let driver = MascotAnimationDriver(activity: activity, time: 0)
      let first = driver.pose(at: 0, reduceMotion: true)
      #expect(first == driver.pose(at: 90, reduceMotion: true))
      #expect(first.headTilt == 0 && first.bodyY == 0 && first.footLift == 0)
    }
  }
  @Test("Double blink closes the eyelids twice")
  func doubleBlink() {
    let duration = MascotGesture.doubleBlink.duration
    #expect(MascotChoreography.gesture(.doubleBlink, time: duration * 0.25).eyelid > 0.99)
    #expect(MascotChoreography.gesture(.doubleBlink, time: duration * 0.5).eyelid < 0.01)
    #expect(MascotChoreography.gesture(.doubleBlink, time: duration * 0.75).eyelid > 0.99)
  }
  @Test("Listening reacts smoothly to microphone activity and releases during silence")
  func microphoneAttention() {
    var response = MascotListeningResponse()
    response.update(level: 0.7, at: 10)
    #expect(response.amount(at: 10) == 0)
    #expect(response.amount(at: 10.3) > 0.5)
    let before = response.amount(at: 10.4)
    response.update(level: 0, at: 10.4)
    #expect(abs(response.amount(at: 10.4) - before) < 0.000001)
    #expect(response.amount(at: 13) < 0.03)
    let resting = MascotPose()
    #expect(response.applying(to: resting, at: 11, enabled: false) == resting)
  }
  @Test("Listening animation continues without transcript or audio updates")
  func listeningMotion() {
    let driver = MascotAnimationDriver(activity: .listening, time: 0)
    let poses = (0...600).map { driver.pose(at: Double($0) / 60) }
    let tilts = poses.map(\.headTilt)
    #expect((tilts.max()! - tilts.min()!) > 5)
    let allFinite = poses.allSatisfy { $0.isFinite }
    #expect(allFinite)
  }
  @Test("Gesture scheduling preserves continuity across slot boundaries")
  func slotContinuity() {
    for activity in [MascotActivity.listening, .speaking, .idle] {
      let driver = MascotAnimationDriver(activity: activity, time: 0)
      for frame in 1...3000 {
        let time = Double(frame) / 60
        let before = driver.pose(at: time - 0.00001)
        let after = driver.pose(at: time + 0.00001)
        #expect(abs(after.headTilt - before.headTilt) < 0.01)
        #expect(abs(after.rightArm - before.rightArm) < 0.02)
      }
    }
  }
  @Test("Arrival and celebration settle, rather than repeating indefinitely")
  func singlePerformance() {
    for activity in [MascotActivity.greeting, .celebrating, .farewell] {
      let driver = MascotAnimationDriver(activity: activity, time: 0)
      let settled = driver.pose(at: 20)
      #expect(settled.leftArm == 0 && settled.rightArm == 0 && settled.footLift == 0)
    }
  }
}

@Suite("Playback-synchronized mascot speech")
struct MascotSpeechTimelineTests {
  private func pcm(_ samples: [Int16]) -> Data {
    var values = samples.map(\.littleEndian)
    return values.withUnsafeMutableBytes { Data($0) }
  }
  @Test("Future network chunks do not affect the current audible frame")
  func queuedAudio() {
    var timeline = MascotSpeechTimeline()
    timeline.append(pcm16: pcm([Int16](repeating: 0, count: 480)))
    timeline.append(pcm16: pcm([Int16](repeating: 8000, count: 480)))
    #expect(timeline.sample(at: 200) == .silent)
    #expect(timeline.sample(at: 600).energy > 0.5)
    #expect(timeline.sample(at: 960) == .silent)
    #expect(timeline.sample(at: -1) == .silent)
  }
  @Test("PCM after a playback gap uses the actual render position")
  func renderClockGap() {
    var timeline = MascotSpeechTimeline()
    timeline.append(pcm16: pcm([Int16](repeating: 4000, count: 480)))
    timeline.append(pcm16: pcm([Int16](repeating: 4000, count: 480)), at: 24000)
    #expect(timeline.scheduledFrames == 24480)
    #expect(!timeline.containsAudio(at: 12000))
    #expect(timeline.sample(at: 12000) == .silent)
    #expect(timeline.containsAudio(at: 24100))
    #expect(timeline.sample(at: 24100).openness > 0)
    timeline.discard(before: 480)
    #expect(timeline.containsAudio(at: 24100))
  }
  @Test("Silence within an utterance closes the mouth")
  func silentPause() {
    var timeline = MascotSpeechTimeline()
    timeline.append(
      pcm16: pcm(
        [Int16](repeating: 4000, count: 480) + [Int16](repeating: 0, count: 480)
          + [Int16](repeating: 4000, count: 480)))
    #expect(timeline.sample(at: 100).openness > 0)
    #expect(timeline.sample(at: 700).openness == 0)
    #expect(timeline.sample(at: 1000).openness > 0)
  }
  @Test("Draining and resetting cannot leak articulation into another session")
  func drainAndReset() {
    var timeline = MascotSpeechTimeline()
    timeline.append(pcm16: pcm([Int16](repeating: 4000, count: 960)))
    timeline.discard(before: 480)
    #expect(timeline.sample(at: 200) == .silent)
    #expect(timeline.sample(at: 600).energy > 0)
    timeline.reset()
    #expect(timeline.scheduledFrames == 0 && timeline.windows.isEmpty)
    #expect(timeline.sample(at: 600) == .silent)
  }
  @Test("Short and partial windows remain safe")
  func partialWindows() {
    var timeline = MascotSpeechTimeline()
    timeline.append(pcm16: Data())
    timeline.append(pcm16: Data([0]))
    timeline.append(pcm16: pcm([1000, -1000, 1000]))
    #expect(timeline.scheduledFrames == 3)
    #expect(timeline.sample(at: 2).energy.isFinite)
    #expect(timeline.sample(at: 3) == .silent)
  }
}

@Suite("Live streaming and turn stability")
struct LivePracticeStreamingTests {
  @Test("Continuous silent PCM cannot keep the assistant's speaking turn active")
  func silentProviderBuffers() {
    var activity = LiveSpeakingActivity()
    let spoken = activity.update(frame: MascotSpeechFrame(energy: 0.2), isPlaying: true, at: 0)
    let phrasePause = activity.update(frame: .silent, isPlaying: true, at: 0.3)
    let silentOutput = activity.update(frame: .silent, isPlaying: true, at: 0.7)
    let noise = activity.update(frame: MascotSpeechFrame(energy: 0.004), isPlaying: true, at: 1)
    let nextReply = activity.update(frame: MascotSpeechFrame(energy: 0.2), isPlaying: true, at: 2)
    #expect(spoken && phrasePause && nextReply)
    #expect(!silentOutput && !noise)
  }

  @Test("Half-second streaming gaps do not repeatedly hand the visual turn to the user")
  func streamingGaps() {
    var activity = LiveSpeakingActivity()
    let beforePlayback = activity.update(audible: false, at: 0)
    #expect(!beforePlayback)
    for chunk in 0..<20 {
      let start = Double(chunk) * 0.7
      let first = activity.update(audible: true, at: start)
      let ongoing = activity.update(audible: true, at: start + 0.19)
      let gap = activity.update(audible: false, at: start + 0.4)
      let gapEnd = activity.update(audible: false, at: start + 0.69)
      #expect(first && ongoing && gap && gapEnd)
    }
    let afterPlayback = activity.update(audible: false, at: 14.2)
    #expect(!afterPlayback)
    activity = LiveSpeakingActivity()
    let afterReset = activity.update(audible: false, at: 14.3)
    #expect(!afterReset)
  }

  @Test("A noise spike does not start a speaking turn, and a real voice survives short pauses")
  func microphoneHysteresis() {
    var microphone = LiveMicrophoneActivity()
    microphone.update(level: 0, at: 0)
    microphone.update(level: 0.8, at: 0.02)
    for frame in 2...50 { microphone.update(level: 0, at: Double(frame) * 0.02) }
    #expect(!microphone.isSpeaking)
    for frame in 51...80 { microphone.update(level: 0.5, at: Double(frame) * 0.02) }
    #expect(microphone.isSpeaking)
    for frame in 81...90 { microphone.update(level: 0, at: Double(frame) * 0.02) }
    #expect(microphone.isSpeaking)
    for frame in 91...160 { microphone.update(level: 0, at: Double(frame) * 0.02) }
    #expect(!microphone.isSpeaking)
    #expect(microphone.level < 0.06)
  }
}
