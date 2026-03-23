import SwiftUI

struct MainView: View {
    @EnvironmentObject private var loader: SeasonDataLoader
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                }
            RacesView()
                .tabItem {
                    Image(systemName: "flag.checkered")
                }
            LiveView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                }
        }
        .tint(.white)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            loader.refreshConstructorWidgetFromStandings()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loader.refreshConstructorWidgetFromStandings()
            }
        }
    }
}
