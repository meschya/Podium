import SwiftUI

@main
struct PodiumApp: App {
    @State private var splashOpacity: Double = 1
    @State private var showSplash = true
    @StateObject private var seasonLoader = SeasonDataLoader()

    private let transitionDuration: Double = 0.65

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()

                if seasonLoader.isPresentationReady {
                    MainView()
                        .environmentObject(seasonLoader)
                        .environmentObject(seasonLoader.liveMapState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Один вызов на cold start — не гоняем load() из Splash и Home параллельно.
                SplashScreenView(loader: seasonLoader, onFinish: {
                    withAnimation(.easeOut(duration: transitionDuration)) {
                        splashOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration + 0.3) {
                        showSplash = false
                    }
                })
                // Пока нет готового bootstrap — слой сплэша; `isPresentationReady` поднимается после полного набора данных.
                .opacity(
                    seasonLoader.isPresentationReady
                        ? (showSplash ? splashOpacity : 0)
                        : 1
                )
                .allowsHitTesting(showSplash && (!seasonLoader.isPresentationReady || splashOpacity > 0.01))
                .ignoresSafeArea()
            }
            .animation(.easeOut(duration: transitionDuration), value: splashOpacity)
            .preferredColorScheme(.dark)
            .task {
                await seasonLoader.load()
                await seasonLoader.finalizeBootstrapIfIncomplete()
                await seasonLoader.awaitPresentationReadyOrTimeout(seconds: 14)
            }
        }
    }
}
