import SwiftUI
import UIKit

private final class SplashArcView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let duration: CFTimeInterval = 0.9

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 4
        shapeLayer.lineCap = .round
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r = min(bounds.width, bounds.height) / 2
        shapeLayer.frame = bounds
        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY), radius: r, startAngle: 0, endAngle: .pi * 1.5, clockwise: true)
        shapeLayer.path = path.cgPath
        shapeLayer.strokeStart = 0
        shapeLayer.strokeEnd = 1
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimation()
        } else {
            shapeLayer.removeAllAnimations()
        }
    }

    private func startAnimation() {
        shapeLayer.removeAllAnimations()
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.fromValue = 0
        anim.toValue = CGFloat.pi * 2
        anim.duration = duration
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        shapeLayer.add(anim, forKey: "rotate")
    }
}

private struct SplashArcUIView: UIViewRepresentable {
    func makeUIView(context: Context) -> SplashArcView {
        SplashArcView()
    }

    func updateUIView(_ uiView: SplashArcView, context: Context) {}
}

struct SplashLoaderView: View {
    private let size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size + 12, height: size + 12)
            SplashArcUIView()
                .frame(width: size, height: size)
        }
    }
}
