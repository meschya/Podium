//
//  CircuitInfo.swift
//  Podium
//

import Foundation
import CoreGraphics

struct CircuitInfo: Codable {
    var x: [Int]
    var y: [Int]
    var rotation: Double?

    enum CodingKeys: String, CodingKey {
        case x, y
        case rotation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode([Int].self, forKey: .x)
        y = try c.decode([Int].self, forKey: .y)
        if let d = try c.decodeIfPresent(Double.self, forKey: .rotation) {
            rotation = d
        } else if let i = try c.decodeIfPresent(Int.self, forKey: .rotation) {
            rotation = Double(i)
        } else {
            rotation = nil
        }
    }

    init(x: [Int], y: [Int], rotation: Double?) {
        self.x = x
        self.y = y
        self.rotation = rotation
    }

    private func rotatedPoints() -> [(Double, Double)] {
        let n = min(x.count, y.count)
        guard n > 0 else { return [] }
        let raw = (0..<n).map { (Double(x[$0]), Double(y[$0])) }
        guard let r = rotation, r != 0 else { return raw }
        return raw.map { rotatePoint($0.0, $0.1) }
    }

    private var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let pts = rotatedPoints()
        guard !pts.isEmpty else { return (0, 0, 1, 1) }
        let xs = pts.map(\.0), ys = pts.map(\.1)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return (0, 0, 1, 1)
        }
        return (minX, minY, maxX, maxY)
    }

    private var rawCenter: (Double, Double) {
        let n = min(x.count, y.count)
        guard n > 0,
              let minX = x.map(Double.init).min(), let maxX = x.map(Double.init).max(),
              let minY = y.map(Double.init).min(), let maxY = y.map(Double.init).max() else {
            return (0, 0)
        }
        return ((minX + maxX) / 2, (minY + maxY) / 2)
    }

    private func rotatePoint(_ px: Double, _ py: Double) -> (Double, Double) {
        guard let r = rotation, r != 0 else { return (px, py) }
        let (cx, cy) = rawCenter
        let rad = r * .pi / 180
        let c = cos(rad), s = sin(rad)
        let dx = px - cx, dy = py - cy
        return (cx + dx * c - dy * s, cy + dx * s + dy * c)
    }

    func normalizedUV(trackX: Int, trackY: Int) -> (u: CGFloat, v: CGFloat) {
        let pt = rotatePoint(Double(trackX), Double(trackY))
        let b = bounds
        let spanX = b.maxX - b.minX, spanY = b.maxY - b.minY
        guard spanX > 0, spanY > 0 else { return (0.5, 0.5) }
        let u = CGFloat((pt.0 - b.minX) / spanX)
        let v = CGFloat((pt.1 - b.minY) / spanY)
        return (u, v)
    }

    /// Проекция точки (например из OpenF1 location) на ближайшую точку трассы; возвращает (u,v) для отрисовки на карте.
    func normalizedUVProjected(trackX: Int, trackY: Int) -> (u: CGFloat, v: CGFloat) {
        let pts = rotatedPoints()
        let n = pts.count
        guard n >= 2 else { return normalizedUV(trackX: trackX, trackY: trackY) }
        let px = Double(trackX), py = Double(trackY)
        var bestDist: Double = .infinity
        var bestT: Double = 0
        var bestSeg: Int = 0
        var totalLen: Double = 0
        var segStarts: [Double] = [0]
        for i in 0..<n {
            let j = (i + 1) % n
            let dx = pts[j].0 - pts[i].0, dy = pts[j].1 - pts[i].1
            let segLen = (dx * dx + dy * dy).squareRoot()
            totalLen += segLen
            segStarts.append(totalLen)
        }
        guard totalLen > 0 else { return normalizedUV(trackX: trackX, trackY: trackY) }
        for i in 0..<n {
            let j = (i + 1) % n
            let ax = pts[i].0, ay = pts[i].1
            let bx = pts[j].0, by = pts[j].1
            let dx = bx - ax, dy = by - ay
            let segLen = (dx * dx + dy * dy).squareRoot()
            guard segLen > 0 else { continue }
            let t = ((px - ax) * dx + (py - ay) * dy) / (segLen * segLen)
            let tClamp = max(0, min(1, t))
            let projX = ax + dx * tClamp
            let projY = ay + dy * tClamp
            let d = (px - projX) * (px - projX) + (py - projY) * (py - projY)
            if d < bestDist {
                bestDist = d
                bestSeg = i
                let segStart = segStarts[i]
                bestT = (segStart + tClamp * (segStarts[i + 1] - segStart)) / totalLen
            }
        }
        return pointAtProgress(CGFloat(bestT))
    }

    func pointAtProgress(_ progress: CGFloat) -> (u: CGFloat, v: CGFloat) {
        let pts = rotatedPoints()
        let n = pts.count
        guard n >= 2 else { return (0.5, 0.5) }
        var lengths: [Double] = []
        var total: Double = 0
        for i in 0..<n {
            let j = (i + 1) % n
            let dx = pts[j].0 - pts[i].0, dy = pts[j].1 - pts[i].1
            let d = (dx * dx + dy * dy).squareRoot()
            lengths.append(d)
            total += d
        }
        guard total > 0 else { return normalizedUV(trackX: x[0], trackY: y[0]) }
        let t = (progress.truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0)
        var acc: Double = 0
        for i in 0..<n {
            let seg = lengths[i]
            if t <= (acc + seg) / total {
                let localT = seg > 0 ? (Double(t) * total - acc) / seg : 0
                let xi = pts[i].0 + (pts[(i + 1) % n].0 - pts[i].0) * localT
                let yi = pts[i].1 + (pts[(i + 1) % n].1 - pts[i].1) * localT
                let b = bounds
                let spanX = b.maxX - b.minX, spanY = b.maxY - b.minY
                guard spanX > 0, spanY > 0 else { return (0.5, 0.5) }
                return (CGFloat((xi - b.minX) / spanX), CGFloat((yi - b.minY) / spanY))
            }
            acc += seg
        }
        return normalizedUV(trackX: x[0], trackY: y[0])
    }

    func normalizedPathPoints() -> [(CGFloat, CGFloat)] {
        let pts = rotatedPoints()
        let b = bounds
        let spanX = b.maxX - b.minX, spanY = b.maxY - b.minY
        guard spanX > 0, spanY > 0 else { return [(0.5, 0.5)] }
        return pts.map { (CGFloat(($0.0 - b.minX) / spanX), CGFloat(($0.1 - b.minY) / spanY)) }
    }
}
