import SwiftUI

struct ContentView: View {

    @StateObject private var appViewModel = AppViewModel()
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(Tab.home)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .environmentObject(appViewModel)
    }
}
