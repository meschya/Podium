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
                if seasonLoader.isLoaded {
                    MainView()
                        .environmentObject(seasonLoader)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                SplashScreenView(loader: seasonLoader, onFinish: {
                    withAnimation(.easeOut(duration: transitionDuration)) {
                        splashOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration + 0.3) {
                        showSplash = false
                    }
                })
                .opacity(showSplash ? (seasonLoader.isLoaded ? splashOpacity : 1) : 0)
                .allowsHitTesting(showSplash && (!seasonLoader.isLoaded || splashOpacity > 0.01))
                .ignoresSafeArea()
            }
            .animation(.easeOut(duration: transitionDuration), value: splashOpacity)
            .preferredColorScheme(.dark)
        }
    }
}
