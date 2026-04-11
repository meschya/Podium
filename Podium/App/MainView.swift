import SwiftUI
import UIKit

struct MainView: View {
    @EnvironmentObject private var loader: SeasonDataLoader
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastResumeBootstrapAt: Date?
    @State private var selectedTab = 0

    private func handleAppBecameActive() {
        let now = Date()
        if let t = lastResumeBootstrapAt, now.timeIntervalSince(t) < 1.5 { return }
        lastResumeBootstrapAt = now
        loader.refreshConstructorWidgetFromStandings()
        Task { await loader.resumeBootstrapIfNeeded() }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if selectedTab == 0 {
                    HomeView()
                } else {
                    Color.black
                }
            }
            .tabItem {
                Image(systemName: "house.fill")
            }
            .tag(0)
            Group {
                if selectedTab == 1 {
                    RacesView()
                } else {
                    Color(.systemBackground)
                }
            }
            .tabItem {
                Image(systemName: "flag.checkered")
            }
            .tag(1)
            Group {
                if selectedTab == 2 {
                    DriversCupView()
                } else {
                    Color(.systemBackground)
                }
            }
            .tabItem {
                Image(systemName: "trophy.fill")
            }
            .tag(2)
            Group {
                if selectedTab == 3 {
                    SettingsView()
                } else {
                    Color(.systemBackground)
                }
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
            }
            .tag(3)
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
