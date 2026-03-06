import SwiftUI

struct LandscapeStripesView: View {
    /// Компактный вариант: полоски мельче и только в верхней части экрана (для сплэша).
    var compact: Bool = false

    private var amplitudes: [(CGFloat, CGFloat)] {
        if compact {
            return [(0.012, 0.22), (0.016, 0.35), (0.018, 0.48), (0.014, 0.58), (0.01, 0.68)]
        }
        return [(0.026, 0.92), (0.036, 0.78), (0.04, 0.63), (0.034, 0.5), (0.03, 0.38), (0.024, 0.26), (0.016, 0.12)]
    }

    private var lineWidth: CGFloat { compact ? 0.5 : 0.8 }
    private var step: CGFloat { compact ? 8 : 5 }

    var body: some View {
        Canvas { context, canvasSize in
            let cw = canvasSize.width
            let ch = canvasSize.height
            var path = Path()
            for (amp, yFrac) in amplitudes {
                let y = ch * yFrac
                path.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x <= cw + 30 {
                    let wave = sin(x / cw * .pi * 2.8) * ch * amp
                    path.addLine(to: CGPoint(x: x, y: y + wave))
                    x += step
                }
            }
            context.stroke(path, with: .color(Color.primary.opacity(compact ? 0.1 : 0.14)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
