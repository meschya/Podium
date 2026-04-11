import SwiftUI

/// Сплэш не ходит в API: анимация и `loader.isPresentationReady` (полный bootstrap). Сеть — `SeasonDataLoader.load()` в `PodiumApp` (`.task`).

/// URL видео сплэша в бандле. Если файл не добавлен — nil, тогда показывается статичный контент (полоски).
private let splashVideoURL = Bundle.main.url(forResource: "splash_background", withExtension: "mov")

struct SplashScreenView: View {
    @ObservedObject var loader: SeasonDataLoader
    var onFinish: () -> Void

    @State private var startTime: Date?
    /// После готовности данных лоадер остаётся на экране, пока не истечёт пауза — `MainView` успевает смонтироваться и отдать первый layout.
    @State private var keepLoaderVisibleAfterLoad = false
    @State private var hasScheduledSplashEnd = false

    private let animDuration: Double = 1.8
    /// Показываем лоадер ещё столько секунд после готовности данных, затем запускаем fade сплэша в `PodiumApp`.
    private let postLoadSettleDuration: TimeInterval = 0.55
    private let stagger: CGFloat = 0.15

    /// Пока идёт загрузка — реже тикаем, чтобы не грузить рендер 60×/с под анимацией.
    private var timelineInterval: TimeInterval {
        loader.isPresentationReady ? 1.0 : 1.0 / 24
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: timelineInterval)) { context in
            let progress = progressAt(context.date)
            let podium = elementProgress(global: progress)

            GeometryReader { geo in
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    if splashVideoURL != nil {
                        // aspectFit — весь кадр видео внутри рамки; полосы по краям — чёрный фон, без обрезки контента.
                        SplashVideoView(aspectFill: false, ignoresSafeArea: false)
                            .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.75),
                                Color.black.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    } else {
                        LandscapeStripesView(compact: true)
                            .frame(width: geo.size.width, height: geo.size.height * 0.55)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(.ultraThinMaterial)
                    }
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text("Podium")
                            .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 52))
                            .foregroundStyle(.white)
                        .opacity(podium)
                        .scaleEffect(0.92 + 0.08 * podium)
                        Text("Races, standings and results — all in one place.")
                            .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(0)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                            .opacity(podium)
                        Spacer().frame(height: 28)
                        if !loader.isPresentationReady || keepLoaderVisibleAfterLoad {
                            SplashLoaderView()
                                .opacity(podium)
                        }
                        Spacer().frame(height: geo.safeAreaInsets.bottom + 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                if startTime == nil { startTime = Date() }
                if loader.isPresentationReady { keepLoaderVisibleAfterLoad = true }
                scheduleSplashEndAfterSettle()
            }
            .onChange(of: loader.isPresentationReady) { _, ready in
                if ready { keepLoaderVisibleAfterLoad = true }
                scheduleSplashEndAfterSettle()
            }
        }
    }

    private func scheduleSplashEndAfterSettle() {
        guard loader.isPresentationReady, !hasScheduledSplashEnd else { return }
        hasScheduledSplashEnd = true
        DispatchQueue.main.asyncAfter(deadline: .now() + postLoadSettleDuration) {
            Task { @MainActor in
                await Task.yield()
                await Task.yield()
                onFinish()
            }
        }
    }

    private func progressAt(_ now: Date) -> CGFloat {
        guard let start = startTime else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        let t = min(1, elapsed / animDuration)
        return CGFloat(1 - (1 - t) * (1 - t))
    }

    private func elementProgress(global: CGFloat) -> CGFloat {
        guard global > stagger else { return 0 }
        return min(1, (global - stagger) / (1 - stagger))
    }

}

#Preview {
    SplashScreenView(loader: SeasonDataLoader(), onFinish: {})
}
