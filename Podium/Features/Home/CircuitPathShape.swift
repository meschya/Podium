import SwiftUI

struct CircuitPathShape: Shape {
    var points: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        guard !points.isEmpty else { return Path() }
        var path = Path()
        let w = rect.width
        let h = rect.height
        let first = CGPoint(x: points[0].0 * w, y: (1 - points[0].1) * h)
        path.move(to: first)
        for i in 1..<points.count {
            path.addLine(to: CGPoint(x: points[i].0 * w, y: (1 - points[i].1) * h))
        }
        path.closeSubpath()
        return path
    }
}
