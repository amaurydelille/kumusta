import SwiftUI

struct ProfileEditorView: View {
    let onSave: (UserProfile) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile
    @State private var isSaving = false
    @State private var saveError: String?

    init(profile: UserProfile, onSave: @escaping (UserProfile) async throws -> Void) {
        _profile = State(initialValue: profile)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        nameField
                        goalChoice
                        dailyPace
                        levelChoice
                        desiredLevelChoice
                        challengeChoice

                        if let saveError {
                            Label(saveError, systemImage: "exclamationmark.circle.fill")
                                .font(KumustaTypography.body)
                                .foregroundStyle(KumustaColors.errorDeep)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            save()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(L("Save my plan"))
                            }
                        }
                        .buttonStyle(KumustaPrimaryButtonStyle())
                        .disabled(isSaving)
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("Edit your plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { dismiss() }
                        .font(KumustaTypography.bodyStrong)
                        .foregroundStyle(KumustaColors.ink)
                        .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var nameField: some View {
        editorSection(
            title: L("What should we call you?"),
            subtitle: L("Your name only appears inside Kumusta.")
        ) {
            TextField(L("Your name"), text: $profile.name)
                .font(KumustaTypography.body)
                .textContentType(.name)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(KumustaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(KumustaColors.line, lineWidth: 1.5)
                }
        }
    }

    private var goalChoice: some View {
        editorSection(
            title: L("What matters most?"),
            subtitle: L("We use this to prioritize situations and vocabulary.")
        ) {
            VStack(spacing: 12) {
                ForEach(LearningGoal.allCases) { goal in
                    Button {
                        profile.goal = goal
                    } label: {
                        ProfileChoiceRow(title: goal.title, isSelected: profile.goal == goal) {
                            Image(systemName: goal.systemImage)
                                .scaledFont(21, weight: .semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(profile.goal == goal ? .isSelected : [])
                }
            }
        }
    }

    private var dailyPace: some View {
        editorSection(
            title: L("A pace you can keep"),
            subtitle: L("Small, consistent listening beats a heroic weekend.")
        ) {
            VStack(spacing: 14) {
                Text(L(one: "%lld minute a day", other: "%lld minutes a day", count: profile.dailyMinutes))
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(KumustaColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    ForEach([5, 7, 10, 15], id: \.self) { minutes in
                        Button {
                            profile.dailyMinutes = minutes
                        } label: {
                            Text("\(minutes)")
                                .font(KumustaTypography.bodyStrong)
                                .foregroundStyle(profile.dailyMinutes == minutes ? .white : KumustaColors.ink)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(profile.dailyMinutes == minutes ? KumustaColors.accent : KumustaColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L(one: "%lld minute a day", other: "%lld minutes a day", count: minutes))
                        .accessibilityAddTraits(
                            profile.dailyMinutes == minutes ? .isSelected : []
                        )
                    }
                }
            }
        }
    }

    private var levelChoice: some View {
        editorSection(
            title: L("Where are you starting?"),
            subtitle: L("There is no test and no judgment.")
        ) {
            VStack(spacing: 12) {
                ForEach(ProficiencyLevel.allCases) { level in
                    Button {
                        profile.level = level
                    } label: {
                        ProfileChoiceRow(
                            title: level.title,
                            detail: level.detail,
                            isSelected: profile.level == level
                        ) {
                            Image(systemName: level.systemImage)
                                .scaledFont(21, weight: .semibold)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(profile.level == level ? .isSelected : [])
                }
            }
        }
    }

    private var desiredLevelChoice: some View {
        editorSection(
            title: L("Where do you want to get?"),
            subtitle: L("The lesson engine uses this as the destination, not as a test score.")
        ) {
            VStack(spacing: 12) {
                ForEach(DesiredProficiency.allCases) { level in
                    Button {
                        profile.desiredProficiency = level
                    } label: {
                        ProfileChoiceRow(
                            title: level.title,
                            isSelected: (profile.desiredProficiency ?? .confident) == level
                        ) {
                            Image(systemName: "scope")
                                .scaledFont(21, weight: .semibold)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var challengeChoice: some View {
        editorSection(
            title: L("How much should lessons stretch you?"),
            subtitle: L("Your quick post-session answers will keep tuning this automatically.")
        ) {
            VStack(spacing: 12) {
                ForEach(LearningChallengePreference.allCases) { preference in
                    Button {
                        profile.challengePreference = preference
                    } label: {
                        ProfileChoiceRow(
                            title: preference.title,
                            isSelected: (profile.challengePreference ?? .balanced) == preference
                        ) {
                            Image(systemName: "slider.horizontal.3")
                                .scaledFont(21, weight: .semibold)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func editorSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(KumustaTypography.title2)
                .foregroundStyle(KumustaColors.ink)
            Text(subtitle)
                .font(KumustaTypography.body)
                .foregroundStyle(KumustaColors.muted)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func save() {
        isSaving = true
        saveError = nil
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await onSave(profile)
                dismiss()
            } catch {
                saveError = L("Your changes couldn’t be saved. Please try again.")
                isSaving = false
            }
        }
    }
}

private struct ProfileChoiceRow<Leading: View>: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    @ViewBuilder let leading: Leading

    init(
        title: String,
        detail: String? = nil,
        isSelected: Bool,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.detail = detail
        self.isSelected = isSelected
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: 14) {
            leading
                .frame(width: 34, height: 34)
                .foregroundStyle(isSelected ? KumustaColors.accentDeep : KumustaColors.muted)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KumustaTypography.bodyStrong)
                    .foregroundStyle(KumustaColors.ink)
                if let detail {
                    Text(detail)
                        .font(KumustaTypography.body)
                        .foregroundStyle(KumustaColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .scaledFont(24, weight: .semibold)
                .foregroundStyle(isSelected ? KumustaColors.accent : KumustaColors.line)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 70)
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
