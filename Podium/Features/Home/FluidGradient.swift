//
//  FluidGradient.swift
//  Podium
//
//  Лёгкий фон: один линейный CAGradientLayer + одна медленная CA-анимация (autoreverses).
//  Раньше — несколько радиальных блобов + Combine-таймеры → лаги скролла и после splash.

import SwiftUI
import UIKit

// MARK: - UIKit

private final class StableFluidGradientView: UIView {
    private let gradient = CAGradientLayer()
    private var lastFingerprint: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.type = .axial
        gradient.contentsScale = UIScreen.main.scale
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }

    func apply(blobs: [UIColor], speed: CGFloat) {
        let fp = fingerprint(blobs: blobs, speed: speed)
        guard fp != lastFingerprint else { return }
        lastFingerprint = fp

        gradient.removeAllAnimations()

        let stops = Self.linearStops(from: blobs)
        gradient.colors = stops.cgColors
        gradient.locations = stops.locations
        backgroundColor = stops.backdrop

        let sp = CGPoint(x: 0.18, y: 0.02)
        let ep = CGPoint(x: 0.82, y: 0.98)
        gradient.startPoint = sp
        gradient.endPoint = ep

        guard speed > 0.02 else { return }

        // Длинный цикл — стабильно и дёшево для композитора.
        let duration = CFTimeInterval(min(40, max(16, 26 / max(0.2, Double(speed)))))
        let spEnd = CGPoint(x: 0.42, y: 0.12)
        let epEnd = CGPoint(x: 0.58, y: 0.88)

        let aStart = CABasicAnimation(keyPath: "startPoint")
        aStart.fromValue = NSValue(cgPoint: sp)
        aStart.toValue = NSValue(cgPoint: spEnd)
        aStart.duration = duration
        aStart.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let aEnd = CABasicAnimation(keyPath: "endPoint")
        aEnd.fromValue = NSValue(cgPoint: ep)
        aEnd.toValue = NSValue(cgPoint: epEnd)
        aEnd.duration = duration
        aEnd.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let group = CAAnimationGroup()
        group.animations = [aStart, aEnd]
        group.duration = duration
        group.autoreverses = true
        group.repeatCount = .greatestFiniteMagnitude
        group.isRemovedOnCompletion = false
        gradient.add(group, forKey: "stableDrift")
    }

    private func fingerprint(blobs: [UIColor], speed: CGFloat) -> String {
        "\(blobs.count)_\(String(format: "%.2f", speed))_" + blobs.prefix(6).map { $0.rgbaKey }.joined(separator: "|")
    }

    private struct LinearStops {
        let cgColors: [CGColor]
        let locations: [NSNumber]
        let backdrop: UIColor
    }

    private static func linearStops(from blobs: [UIColor]) -> LinearStops {
        var u = blobs
        if u.isEmpty {
            u = [
                UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1),
                UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1)
            ]
        }
        while u.count < 2 {
            u.append(u[0])
        }
        let c0 = u[0]
        let c1 = u[min(1, u.count - 1)]
        let c2 = u.count > 2 ? u[2] : blend(c1, towards: .black, amount: 0.35)
        let c3 = u.count > 3 ? u[3] : blend(c2, towards: .black, amount: 0.5)
        let cgColors: [CGColor] = [
            c0.cgColor,
            c1.cgColor,
            c2.cgColor,
            blend(c3, towards: .black, amount: 0.25).cgColor
        ]
        let locations: [NSNumber] = [0, 0.38, 0.68, 1]
        let backdrop = blend(c0, towards: .black, amount: 0.55)
        return LinearStops(cgColors: cgColors, locations: locations, backdrop: backdrop)
    }

    private static func blend(_ a: UIColor, towards b: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return a }
        let t = max(0, min(1, amount))
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}

private extension UIColor {
    var rgbaKey: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return "x" }
        return String(format: "%.3f,%.3f,%.3f,%.3f", r, g, b, a)
    }
}

// MARK: - SwiftUI

struct FluidGradient: View {
    private let blobs: [UIColor]
    private let speed: CGFloat

    /// `blur` оставлен в сигнатуре для совместимости вызовов (игнорируется).
    init(blobs: [UIColor], blur: CGFloat = 0.75, speed: CGFloat = 1) {
        self.blobs = blobs
        self.speed = speed
    }

    var body: some View {
        FluidGradientRepresentable(blobs: blobs, speed: speed)
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct FluidGradientRepresentable: UIViewRepresentable {
    var blobs: [UIColor]
    var speed: CGFloat

    func makeUIView(context: Context) -> StableFluidGradientView {
        let v = StableFluidGradientView()
        v.apply(blobs: blobs, speed: speed)
        return v
    }

    func updateUIView(_ uiView: StableFluidGradientView, context: Context) {
        uiView.apply(blobs: blobs, speed: speed)
    }
}
