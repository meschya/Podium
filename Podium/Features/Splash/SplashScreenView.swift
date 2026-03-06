import SwiftUI

/// URL видео сплэша в бандле. Если файл не добавлен — nil, тогда показывается статичный контент (полоски).
private let splashVideoURL = Bundle.main.url(forResource: "splash_background", withExtension: "mov")

struct SplashScreenView: View {
    @ObservedObject var loader: SeasonDataLoader
    var onFinish: () -> Void

    @State private var startTime: Date?
    @State private var hasCalledFinish = false
    @State private var hasStartedLoad = false
    /// 0...1: анимация появления свайпа после лоадера (снизу вверх).
    @State private var swipeAppear: CGFloat = 0

    private let animDuration: Double = 1.8
    private let stagger: CGFloat = 0.15
    private let swipeAppearDuration: Double = 0.5
    private let swipeAppearOffset: CGFloat = 44

    /// Во время появления свайпа крутим чаще для плавной анимации; после — реже.
    private var timelineInterval: TimeInterval {
        if loader.isLoaded && swipeAppear < 0.99 { return 1.0 / 30 }
        if loader.isLoaded { return 1.0 }
        return 1.0 / 60
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: timelineInterval)) { context in
            let progress = progressAt(context.date)
            let podium = elementProgress(global: progress)

            GeometryReader { geo in
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    if splashVideoURL != nil {
                        SplashVideoView(aspectFill: true)
                            .frame(width: geo.size.width, height: geo.size.height)
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
                        HStack(spacing: 12) {
                            Text("Podium")
                                .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 52))
                                .foregroundStyle(.white)
                            Image(String.AppImage.f1_logo)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 28)
                        }
                        .opacity(podium)
                        .scaleEffect(0.92 + 0.08 * podium)
                        Text("Races, standings and results — all in one place.")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(0)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                            .opacity(podium)
                        Spacer().frame(height: 28)
                        if loader.isLoaded {
                            SplashSwipeCircleView(onSwipeComplete: {
                                if !hasCalledFinish {
                                    hasCalledFinish = true
                                    onFinish()
                                }
                            })
                            .opacity(podium * swipeAppear)
                            .offset(y: (1 - swipeAppear) * swipeAppearOffset)
                        } else {
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
                if loader.isLoaded { swipeAppear = 1 }
                guard !hasStartedLoad else { return }
                hasStartedLoad = true
                Task { await loader.load() }
            }
            .onChange(of: loader.isLoaded) { _, isLoaded in
                if isLoaded {
                    withAnimation(.easeOut(duration: swipeAppearDuration)) {
                        swipeAppear = 1
                    }
                }
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

// Как в GoodRequest: BackgroundComponent (трек + текст) сзади, DraggingComponent (кружок) спереди.
// https://www.goodrequest.com/blog/how-to-make-a-slide-to-unlock-button-in-swiftui
private struct SplashSwipeCircleView: View {
    var onSwipeComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggered = false

    private let thumbSize: CGFloat = 56
    private let trackHeight: CGFloat = 56
    private let trackPadding: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let maxDrag = w - trackPadding * 2 - thumbSize
            let threshold = maxDrag * 0.7

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(.clear)
                    .frame(width: w, height: trackHeight)
                    .glassEffect(.regular.tint(.black.opacity(0.6)).interactive(), in: .rect(cornerRadius: trackHeight / 2))

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ShimmerLabel(text: "Get Started")
                        .padding(.trailing, 20)
                }
                .frame(width: w, height: trackHeight)
                .allowsHitTesting(false)

                Image(String.AppImage.bolid_icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .frame(width: thumbSize + 4, height: thumbSize + 4)
                    .contentShape(Circle())
                    .glassEffect(.clear.tint(.clear), in: .circle)
                    .offset(x: trackPadding + max(0, min(dragOffset, maxDrag)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !hasTriggered else { return }
                                dragOffset = min(maxDrag, max(0, value.translation.width))
                            }
                            .onEnded { value in
                                guard !hasTriggered else { return }
                                if value.translation.width >= threshold {
                                    hasTriggered = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        dragOffset = maxDrag
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        onSwipeComplete()
                                    }
                                } else {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
            .frame(width: w, height: trackHeight)
        }
        .frame(height: 56)
        .padding(.horizontal, 28)
    }
}

/// Шиммер слева направо: полоса полностью уходит вправо, потом новый цикл.
private struct ShimmerLabel: View {
    let text: String
    private let font = Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 17)
    private let duration: Double = 2.8
    private let updateInterval: Double = 1 / 20
    /// Фаза 0...1.25: полоса успевает уйти за правый край (1.08) до сброса.
    private let phaseMax: Double = 1.25

    var body: some View {
        TimelineView(.animation(minimumInterval: updateInterval)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t / duration).truncatingRemainder(dividingBy: phaseMax)

            Text(text)
                .font(font)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                .mask {
                    LinearGradient(
                        colors: [.black.opacity(0.4), .black, .black.opacity(0.4)],
                        startPoint: UnitPoint(x: phase - 0.4, y: 0.5),
                        endPoint: UnitPoint(x: phase + 0.08, y: 0.5)
                    )
                }
        }
    }
}

#Preview {
    SplashScreenView(loader: SeasonDataLoader(), onFinish: {})
}
