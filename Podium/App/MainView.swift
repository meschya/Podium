import SwiftUI
import UIKit

struct MainView: View {
    @EnvironmentObject private var loader: SeasonDataLoader
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastResumeBootstrapAt: Date?

    private func handleAppBecameActive() {
        let now = Date()
        if let t = lastResumeBootstrapAt, now.timeIntervalSince(t) < 1.5 { return }
        lastResumeBootstrapAt = now
        loader.refreshConstructorWidgetFromStandings()
        Task { await loader.resumeBootstrapIfNeeded() }
    }

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
            DriversCupView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(.white)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            loader.refreshConstructorWidgetFromStandings()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { handleAppBecameActive() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleAppBecameActive()
        }
    }
}
