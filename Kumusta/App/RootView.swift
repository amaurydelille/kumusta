import StoreKit
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @State private var navigation = AppNavigation()

    var body: some View {
        ZStack {
            KumustaColors.canvas.ignoresSafeArea()

            Group {
                switch appState.launchPhase {
                case .loading:
                    LaunchView()
                        .transition(.opacity)
                case .onboarding:
                    OnboardingFlowView { draft in
                        await appState.completeOnboarding(draft)
                    }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .trailing).combined(with: .opacity)
                    )
                case .paywall:
                    RevenueCatHostedPaywallView(
                        onPremiumAccess: appState.beginPremiumAccountSetup,
                        onSubscriptionPurchased: appState.markSubscriptionPurchased,
                        onDismissed: appState.showPaywallExit
                    )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                case .paywallExit:
                    PaywallExitView()
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .trailing).combined(with: .opacity)
                        )
                case .accountCreation:
                    AccountCreationView()
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .trailing).combined(with: .opacity)
                        )
                case .firstStepsOffer:
                    FirstStepsOfferView(
                        onStart: appState.startFirstSteps,
                        onSkip: appState.skipFirstSteps,
                        onSeen: appState.markFirstStepsOfferSeen
                    )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
                case .firstSteps:
                    FirstStepsCourseView(onExit: appState.finishFirstSteps)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .trailing).combined(with: .opacity)
                        )
                case .main:
                    MainTabView()
                        .environment(navigation)
                        .transition(.opacity)
                case let .failed(message):
                    ContentUnavailableView {
                        Label(L("Couldn’t load Kumusta"), systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button(L("Try again")) {
                            Task { await appState.retryBootstrap() }
                        }
                        .buttonStyle(KumustaPrimaryButtonStyle())
                    }
                }
            }

            if let achievement = appState.pendingAchievements.first {
                BadgeCelebrationView(achievement: achievement) {
                    appState.dismissPendingAchievement()
                }
                .id(achievement.id)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(2)
            }
        }
        .task(id: appState.reviewRequestToken) {
            await requestReviewWhenCalm()
        }
        .animation(reduceMotion ? nil : KumustaMotion.screen, value: appState.launchPhase)
        .onReceive(NotificationCenter.default.publisher(for: .kumustaAuthenticationRequired)) { _ in
            appState.requireAuthentication()
        }
        .overlay { AudioReactiveBorder() }
    }

    /// Waits for dismiss animations, sheets, alerts and celebrations to clear
    /// so the system rating prompt lands on a still screen, then spends the
    /// armed request. If the screen never settles the request stays armed for
    /// the next natural break.
    private func requestReviewWhenCalm() async {
        guard appState.reviewRequestToken != nil else { return }
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, appState.canPresentReviewRequest else { return }
            if ReviewPresentationSurface.isCalm, appState.commitReviewRequest() {
                requestReview()
                return
            }
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 18) {
            BuddyMotionView(motion: .launch, size: 184)
                .frame(height: 184)
            Text("Kumusta")
                .font(.custom("Fredoka-Bold", size: 30, relativeTo: .largeTitle))
                .foregroundStyle(KumustaColors.ink)
            Text(L("Your Tagalog is warming up"))
                .scaledFont(15, weight: .medium, design: .rounded)
                .foregroundStyle(KumustaColors.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("Kumusta is loading"))
    }
}

@MainActor
private enum ReviewPresentationSurface {
    /// True when the app is frontmost and nothing (sheet, cover, alert) is
    /// presented over the root screen.
    static var isCalm: Bool {
        guard UIApplication.shared.applicationState == .active else { return false }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let root = window?.rootViewController else { return false }
        return !hasPresentation(in: root)
    }

    /// SwiftUI may present from a child controller (for example inside a tab),
    /// so the whole controller tree is checked.
    private static func hasPresentation(in controller: UIViewController) -> Bool {
        controller.presentedViewController != nil
            || controller.children.contains(where: hasPresentation(in:))
    }
}
