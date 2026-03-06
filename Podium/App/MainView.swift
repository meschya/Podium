import SwiftUI

struct MainView: View {
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
    }
}
