//
//  FluidGradient.swift
//  Podium
//
//  Fluid gradient via CoreAnimation (Cindori style).
//  https://cindori.com/developer/animated-gradient
//  https://cindori.com/developer/animated-gradient-2
//

import Combine
import SwiftUI
import UIKit
import QuartzCore


// MARK: - CGPoint helpers
private extension CGPoint {
    func displace(by point: CGPoint = .zero) -> CGPoint {
        CGPoint(x: x + point.x, y: y + point.y)
    }
    func capped() -> CGPoint {
        CGPoint(x: max(0, min(1, x)), y: max(0, min(1, y)))
    }
}

// MARK: - ResizableLayer
private final class ResizableLayer: CALayer {
    override init() {
        super.init()
        sublayers = []
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSublayers() {
        super.layoutSublayers()
        sublayers?.forEach { $0.frame = bounds }
    }
}

// MARK: - BlobLayer (radial gradient blob)
private final class BlobLayer: CAGradientLayer {
    init(color: UIColor) {
        super.init()
        type = .radial
        let position = newPosition()
        startPoint = position
        let radius = newRadius()
        endPoint = position.displace(by: radius)
        set(color: color)
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func set(color: UIColor) {
        colors = [color.cgColor, color.cgColor, color.withAlphaComponent(0).cgColor]
        locations = [0.0, 0.9, 1.0] as [NSNumber]
    }
    /// Позиции смещены вправо — анимация по большей части справа.
    func newPosition() -> CGPoint {
        let x = CGFloat.random(in: 0.4...1)
        let y = CGFloat.random(in: 0...1)
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }
    func newRadius() -> CGPoint {
        let size = CGFloat.random(in: 0.15...0.75)
        let h = max(frame.height, 1)
        let w = frame.width
        let viewRatio = w / h
        let safeRatio = viewRatio.isNaN ? 1 : max(viewRatio, 0.25)
        let ratio = safeRatio * CGFloat.random(in: 0.25...1.75)
        return CGPoint(x: size, y: size * ratio)
    }
    func animate(speed: CGFloat) {
        guard speed > 0 else { return }
        removeAllAnimations()
        let current = presentation() ?? self
        let position = newPosition()
        let radius = newRadius()
        let duration = 2.8 / Double(speed)
        let timing = CAMediaTimingFunction(name: .easeInEaseOut)
        let start = CABasicAnimation(keyPath: "startPoint")
        start.fromValue = current.startPoint
        start.toValue = position
        start.duration = duration
        start.timingFunction = timing
        start.isRemovedOnCompletion = false
        start.fillMode = .forwards
        let end = CABasicAnimation(keyPath: "endPoint")
        end.fromValue = current.endPoint
        end.toValue = position.displace(by: radius)
        end.duration = duration
        end.timingFunction = timing
        end.isRemovedOnCompletion = false
        end.fillMode = .forwards
        let newOpacity = Float.random(in: 0.5...1)
        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = current.opacity
        opacityAnim.toValue = newOpacity
        opacityAnim.duration = duration
        opacityAnim.timingFunction = timing
        opacityAnim.isRemovedOnCompletion = false
        opacityAnim.fillMode = .forwards
        startPoint = position
        endPoint = position.displace(by: radius)
        opacity = newOpacity
        add(start, forKey: "startPoint")
        add(end, forKey: "endPoint")
        add(opacityAnim, forKey: "opacity")
    }
}

// MARK: - Delegate
private protocol FluidGradientDelegate: AnyObject {
    func updateBlur(_ value: CGFloat)
}

// MARK: - FluidGradientNativeView (UIKit)
private final class FluidGradientNativeView: UIView {
    private let baseLayer = ResizableLayer()
    private var speed: CGFloat = 1
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: FluidGradientDelegate?
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(baseLayer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        baseLayer.frame = bounds
        baseLayer.layoutSublayers()
        updateBlur()
    }
    private func updateBlur() {
        delegate?.updateBlur(min(bounds.width, bounds.height))
    }
    func create(colors: [UIColor], layer target: CALayer) {
        let count = target.sublayers?.count ?? 0
        let toRemove = count - colors.count
        if toRemove > 0 {
            target.sublayers?.removeLast(toRemove)
        }
        for (i, color) in colors.enumerated() {
            if i < count, let blob = target.sublayers?[i] as? BlobLayer {
                blob.set(color: color)
            } else {
                target.addSublayer(BlobLayer(color: color))
            }
        }
    }
    func setBlobs(_ colors: [UIColor]) {
        create(colors: colors, layer: baseLayer)
        update(speed: speed)
    }
    func update(speed: CGFloat) {
        cancellables.removeAll()
        self.speed = speed
        guard speed > 0 else { return }
        let layers = baseLayer.sublayers ?? []
        for layer in layers {
            guard let blob = layer as? BlobLayer else { continue }
            Timer.publish(every: .random(in: (2.2 / speed)...(3.2 / speed)), on: .main, in: .common)
                .autoconnect()
                .sink { [weak blob, weak self] _ in
                    guard let self, let blob else { return }
                    blob.animate(speed: self.speed)
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - FluidGradient (SwiftUI)
struct FluidGradient: View {
    private let blobs: [UIColor]
    private let blurExponent: CGFloat
    private let speed: CGFloat
    @State private var blurValue: CGFloat = 0
    init(blobs: [UIColor], blur: CGFloat = 0.75, speed: CGFloat = 1) {
        self.blobs = blobs
        self.blurExponent = blur
        self.speed = speed
    }
    var body: some View {
        FluidGradientRepresentable(
            blobs: blobs,
            speed: speed,
            blurValue: $blurValue
        )
        .blur(radius: pow(max(blurValue, 1), blurExponent))
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - UIViewRepresentable
private struct FluidGradientRepresentable: UIViewRepresentable {
    var blobs: [UIColor]
    var speed: CGFloat
    @Binding var blurValue: CGFloat
    func makeUIView(context: Context) -> FluidGradientNativeView {
        let view = FluidGradientNativeView()
        view.delegate = context.coordinator
        context.coordinator.view = view
        view.setBlobs(blobs)
        DispatchQueue.main.async {
            view.update(speed: speed)
        }
        return view
    }
    func updateUIView(_ view: FluidGradientNativeView, context: Context) {
        view.setBlobs(blobs)
        context.coordinator.update(speed: speed)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(blurValue: $blurValue, speed: speed)
    }
    final class Coordinator: FluidGradientDelegate {
        var view: FluidGradientNativeView!
        @Binding var blurValue: CGFloat
        var speed: CGFloat
        init(blurValue: Binding<CGFloat>, speed: CGFloat) {
            _blurValue = blurValue
            self.speed = speed
        }
        func updateBlur(_ value: CGFloat) {
            blurValue = value
        }
        func update(speed: CGFloat) {
            guard speed != self.speed else { return }
            self.speed = speed
            view.update(speed: speed)
        }
    }
}
