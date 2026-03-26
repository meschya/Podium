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

                if seasonLoader.isLoaded {
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
                // Пока нет isLoaded — всегда показываем слой сплэша (иначе при сбое состояния окно остаётся пустым/чёрным).
                .opacity(
                    seasonLoader.isLoaded
                        ? (showSplash ? splashOpacity : 0)
                        : 1
                )
                .allowsHitTesting(showSplash && (!seasonLoader.isLoaded || splashOpacity > 0.01))
                .ignoresSafeArea()
            }
            .animation(.easeOut(duration: transitionDuration), value: splashOpacity)
            .preferredColorScheme(.dark)
            .task {
                await seasonLoader.load()
                await seasonLoader.finalizeBootstrapIfIncomplete()
            }
        }
    }
}
