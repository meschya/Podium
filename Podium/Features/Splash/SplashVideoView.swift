//
//  SplashVideoView.swift
//  Podium
//
//  Видео на сплэше: из бандла, без звука, зациклено, заполняет область (aspect fill).
//  Чтобы использовать: добавь в проект файл «splash.mp4» и отметь таргет Podium.
//

import AVFoundation
import SwiftUI
import UIKit

/// Имя видео в бандле (без расширения). Файл `splash_background.mov` в проекте и таргете Podium.
private let splashVideoName = "splash_background"
private let splashVideoExtension = "mov"

struct SplashVideoView: View {
    /// Режим заполнения: true = aspect fill (обрезает по краям), false = aspect fit.
    var aspectFill: Bool = true
    /// На полноэкранном фоне — `true`; в уменьшенной рамке родитель задаёт размер без bleed.
    var ignoresSafeArea: Bool = true

    var body: some View {
        SplashVideoUIView(
            resourceName: splashVideoName,
            resourceExtension: splashVideoExtension,
            aspectFill: aspectFill
        )
        .modifier(ConditionalIgnoreSafeArea(enabled: ignoresSafeArea))
    }
}

private struct ConditionalIgnoreSafeArea: ViewModifier {
    var enabled: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.ignoresSafeArea()
        } else {
            content
        }
    }
}

private struct SplashVideoUIView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String
    let aspectFill: Bool

    func makeUIView(context: Context) -> SplashVideoLayerView {
        let view = SplashVideoLayerView(aspectFill: aspectFill)
        if let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) {
            view.setVideoURL(url)
        }
        return view
    }

    func updateUIView(_ uiView: SplashVideoLayerView, context: Context) {}
}

private final class SplashVideoLayerView: UIView {
    private let aspectFill: Bool
    private var player: AVPlayer?
    private var looper: AVPlayerLooper?
    private let layerView = UIView()

    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(aspectFill: Bool) {
        self.aspectFill = aspectFill
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.videoGravity = aspectFill ? .resizeAspectFill : .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setVideoURL(_ url: URL) {
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = true
        playerLayer.player = queuePlayer
        player = queuePlayer
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.play()
    }
}
