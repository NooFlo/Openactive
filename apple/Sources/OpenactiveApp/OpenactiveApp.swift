import SwiftUI

@main
struct OpenactiveApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(state)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            TripsView()
                .tabItem { Label("Trips", systemImage: "square.and.arrow.down") }
            TourMapScreen()
                .tabItem { Label("Map", systemImage: "map") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
