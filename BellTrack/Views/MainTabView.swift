import SwiftUI
import FirebaseAuth

enum Tab: String, CaseIterable {
    case home = "Home"
    case log = "Log"
    case history = "History"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home: return "house"
        case .log: return "plus.circle"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var appViewModel = AppViewModel()

    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            LogView()
                .tabItem {
                    Label(Tab.log.rawValue, systemImage: Tab.log.icon)
                }
                .tag(Tab.log)

            HistoryView()
                .tabItem {
                    Label(Tab.history.rawValue, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(Color.brand.primary)
        .environmentObject(appViewModel)
        .task {
            appViewModel.userId = authService.user?.uid
            await appViewModel.loadData()
        }
        .onChange(of: authService.user) { _, newUser in
            appViewModel.userId = newUser?.uid
            Task {
                await appViewModel.loadData()
            }
        }
    }
}
