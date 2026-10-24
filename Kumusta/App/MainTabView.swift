import SwiftUI

struct MainTabView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            TodayView()
                .tag(AppNavigation.Tab.today)
                .tabItem { Label(L("Today"), systemImage: "house.fill") }

            PracticeHomeView()
                .tag(AppNavigation.Tab.practice)
                .tabItem { Label(L("Practice"), systemImage: "headphones") }

            WordsView()
                .tag(AppNavigation.Tab.words)
                .tabItem { Label(L("Words"), systemImage: "rectangle.stack.fill") }

            ProfileView()
                .tag(AppNavigation.Tab.profile)
                .tabItem { Label(L("Profile"), systemImage: "person.crop.circle.fill") }
        }
        .onAppear { trackVisibleTab() }
        .onChange(of: navigation.selectedTab) { _, tab in
            dependencies.analytics.track(.tabSelected, properties: ["screen_name": tab.rawValue])
            trackVisibleTab()
        }
        .tint(KumustaColors.accentDeep)
        .toolbarBackground(KumustaColors.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
    private func trackVisibleTab() {
        dependencies.analytics.track(.screenViewed, properties: ["screen_name": navigation.selectedTab.rawValue])
    }
}
