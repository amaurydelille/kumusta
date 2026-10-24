import SwiftUI

struct LessonHistoryView: View {
    @Environment(DependencyContainer.self) private var dependencies

    var body: some View {
        ZStack {
            PaperBackground()

            if dependencies.learningJourneyStore.completedLessons.isEmpty {
                ContentUnavailableView(
                    L("No completed lessons yet"),
                    systemImage: "books.vertical",
                    description: Text(L("Finished lessons will be saved here for listening and reading again."))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dependencies.learningJourneyStore.completedLessons) { record in
                            NavigationLink {
                                CompletedLessonDetailView(record: record)
                            } label: {
                                CompletedLessonRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(L("Lesson history"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dependencies.analytics.track(
                .lessonHistoryOpened,
                properties: ["screen_name": "lesson_history"]
            )
        }
    }
}

struct CompletedLessonRow: View {
    let record: CompletedLessonRecord

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(KumustaColors.accentSoft.opacity(0.55))
                Image(systemName: "checkmark")
                    .scaledFont(18, weight: .bold)
                    .foregroundStyle(KumustaColors.accentDeep)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.lesson.scenario)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                Text(L("%@ · %lld min", completedDate, record.lesson.minutes))
                    .font(KumustaTypography.caption)
                    .foregroundStyle(KumustaColors.accentDeep)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .scaledFont(14, weight: .bold)
                .foregroundStyle(KumustaColors.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(KumustaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KumustaColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var completedDate: String {
        record.completedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocalization.locale))
    }
}

struct CompletedLessonDetailView: View {
    let record: CompletedLessonRecord

    @Environment(DependencyContainer.self) private var dependencies
    @State private var playingStepID: UUID?
    @State private var audioError: String?
    @State private var isUsingOfflineAudio = false

    private var rounds: [LessonStep] {
        record.lesson.steps.enumerated().compactMap { index, step in
            index.isMultiple(of: LessonSessionPlan.stagesPerRound) ? step : nil
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        KumustaEyebrow(text: L("Completed %@", record.completedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocalization.locale))))
                        Text(record.lesson.scenario)
                            .font(KumustaTypography.title)
                            .foregroundStyle(KumustaColors.ink)
                    }

                    if let audioError {
                        Label(audioError, systemImage: "speaker.slash.fill")
                            .font(KumustaTypography.body)
                            .foregroundStyle(KumustaColors.accentDeep)
                    }

                    if isUsingOfflineAudio {
                        Label(
                            L("Using your device’s Tagalog voice for this replay."),
                            systemImage: "iphone"
                        )
                        .font(KumustaTypography.caption)
                        .foregroundStyle(KumustaColors.muted)
                    }

                    ForEach(Array(rounds.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(L("ROUND %lld", index + 1))
                                    .font(KumustaTypography.caption)
                                    .tracking(0.8)
                                    .foregroundStyle(KumustaColors.accentDeep)

                                Spacer()

                                Button { play(step) } label: {
                                    Image(systemName: playingStepID == step.id ? "waveform" : "speaker.wave.2.fill")
                                        .scaledFont(18, weight: .bold)
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(KumustaColors.accent)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(playingStepID != nil)
                                .accessibilityLabel(L("Play round %lld", index + 1))
                            }

                            Text(step.tagalog)
                                .scaledFont(24, weight: .bold, design: .rounded)
                                .foregroundStyle(KumustaColors.ink)
                                .textSelection(.enabled)

                            Text(step.translation)
                                .font(KumustaTypography.body)
                                .foregroundStyle(KumustaColors.muted)
                                .textSelection(.enabled)

                            if !step.chunks.isEmpty {
                                Divider().overlay(KumustaColors.line)
                                ForEach(step.chunks) { chunk in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(chunk.tagalog)
                                            .font(KumustaTypography.bodyStrong)
                                            .foregroundStyle(KumustaColors.ink)
                                        Spacer(minLength: 10)
                                        Text(chunk.english)
                                            .font(KumustaTypography.body)
                                            .foregroundStyle(KumustaColors.muted)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .background(KumustaColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(KumustaColors.line, lineWidth: 1)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("Review lesson"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dependencies.analytics.track(
                .lessonHistoryOpened,
                properties: [
                    "screen_name": "lesson_history_detail",
                    "lesson_id": record.lesson.id.uuidString,
                    "entry_point": "history",
                    "is_replay": "true"
                ]
            )
        }
        .onDisappear {
            Task {
                await dependencies.audioService.stop()
                await dependencies.offlineAudioService.stop()
            }
        }
    }

    private func play(_ step: LessonStep) {
        guard playingStepID == nil else { return }
        playingStepID = step.id
        audioError = nil
        isUsingOfflineAudio = false
        Task { @MainActor in
            do {
                try await dependencies.audioService.play(
                    text: step.tagalog,
                    speed: AudioPreferences().defaultSpeed,
                    purpose: .lesson
                )
                trackPlayback(step: step, source: "provider", result: "completed")
            } catch is CancellationError {
                // Leaving the screen or stopping another clip is normal
                // playback control, not an audio failure.
                trackPlayback(step: step, source: "provider", result: "cancelled")
            } catch {
                trackPlayback(step: step, source: "provider", result: "failed")
                do {
                    // History is intentionally useful offline: the lesson
                    // text is local, so a temporary provider/session failure
                    // should not make its replay button unusable. The label
                    // above makes the voice substitution explicit.
                    try await dependencies.offlineAudioService.play(
                        text: step.tagalog,
                        speed: AudioPreferences().defaultSpeed,
                        purpose: .lesson
                    )
                    isUsingOfflineAudio = true
                    trackPlayback(step: step, source: "offline_fallback", result: "completed")
                } catch is CancellationError {
                    // The user left the detail screen while fallback audio
                    // was starting.
                    trackPlayback(step: step, source: "offline_fallback", result: "cancelled")
                } catch {
                    audioError = L("That phrase couldn’t play. Check your connection and try again.")
                    trackPlayback(step: step, source: "offline_fallback", result: "failed")
                }
            }
            playingStepID = nil
        }
    }

    private func trackPlayback(step: LessonStep, source: String, result: String) {
        dependencies.analytics.track(
            .lessonHistoryAudioPlayed,
            properties: [
                "screen_name": "lesson_history_detail",
                "lesson_id": record.lesson.id.uuidString,
                "step_id": step.id.uuidString,
                "playback_source": source,
                "playback_result": result,
                "is_replay": "true",
                "entry_point": "history"
            ]
        )
    }
}
