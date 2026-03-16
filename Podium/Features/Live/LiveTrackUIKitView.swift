//
//  LiveTrackUIKitView.swift
//  Podium
//
//  Плавное движение кружков: один UIView + CADisplayLink 60fps, без лагов SwiftUI.
//

import SwiftUI
import UIKit

struct LiveTrackUIKitView: View {
    var circuitInfo: CircuitInfo?
    var drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    var locations: [Int: (x: Int, y: Int)]
    var locationsVersion: Int

    var body: some View {
        LiveTrackUIKitRepresentable(
            circuitInfo: circuitInfo,
            drivers: drivers,
            locations: locations,
            locationsVersion: locationsVersion
        )
        .aspectRatio(1.6, contentMode: .fit)
    }
}

private struct LiveTrackUIKitRepresentable: UIViewRepresentable {
    var circuitInfo: CircuitInfo?
    var drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    var locations: [Int: (x: Int, y: Int)]
    var locationsVersion: Int

    func makeUIView(context: Context) -> TrackUIView {
        let v = TrackUIView()
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: TrackUIView, context: Context) {
        let pathPoints = normalizedPathPoints()
        let driverDots: [(driverNumber: Int, positionIndex: Int, color: UIColor)] = drivers.sorted(by: { $0.position < $1.position }).map { ($0.driverNumber, $0.position, uiColor($0.teamName)) }
        var apiPositions: [Int: (CGFloat, CGFloat)]?
        if !locations.isEmpty, let info = circuitInfo {
            apiPositions = drivers.reduce(into: [:]) { r, d in
                if let (tx, ty) = locations[d.driverNumber] {
                    let (u, v) = info.normalizedUVProjected(trackX: tx, trackY: ty)
                    r[d.driverNumber] = (u, CGFloat(1 - v))
                }
            }
        }
        uiView.update(pathPoints: pathPoints, driverDots: driverDots, apiPositions: apiPositions, locationsVersion: locationsVersion)
    }

    private func normalizedPathPoints() -> [(CGFloat, CGFloat)] {
        if let info = circuitInfo, !info.normalizedPathPoints().isEmpty {
            return info.normalizedPathPoints().map { ($0.0, 1 - $0.1) }
        }
        return (0..<80).map { i in
            let t = CGFloat(i) / 80 * 2 * .pi
            let u = 0.5 + 0.38 * cos(t)
            let v = 0.5 + 0.38 * sin(t)
            return (u, v)
        }
    }

    private func uiColor(_ teamName: String) -> UIColor {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return UIColor(red: 20/255, green: 41/255, blue: 72/255, alpha: 1) }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return UIColor(red: 0/255, green: 56/255, blue: 194/255, alpha: 1) }
        if lower.contains("ferrari") { return UIColor(red: 92/255, green: 0/255, blue: 18/255, alpha: 1) }
        if lower.contains("mclaren") { return UIColor(red: 128/255, green: 64/255, blue: 0/255, alpha: 1) }
        if lower.contains("mercedes") { return UIColor(red: 6/255, green: 126/255, blue: 106/255, alpha: 1) }
        if lower.contains("aston martin") { return UIColor(red: 15/255, green: 67/255, blue: 49/255, alpha: 1) }
        if lower.contains("alpine") { return UIColor(red: 0/255, green: 78/255, blue: 112/255, alpha: 1) }
        if lower.contains("williams") { return UIColor(red: 8/255, green: 33/255, blue: 69/255, alpha: 1) }
        if lower.contains("haas") { return UIColor(red: 102/255, green: 113/255, blue: 117/255, alpha: 1) }
        if lower.contains("sauber") || lower.contains("kick") || lower.contains("stake") { return UIColor(red: 102/255, green: 113/255, blue: 117/255, alpha: 1) }
        return .gray
    }
}

// MARK: - UIKit view with display link

private final class TrackUIView: UIView {
    private var pathPoints: [(CGFloat, CGFloat)] = []
    private var driverDots: [(driverNumber: Int, positionIndex: Int, color: UIColor)] = []
    private var apiPositions: [Int: (CGFloat, CGFloat)]?
    private var lastLocationsVersion: Int = -1

    private var currentPositions: [Int: (CGFloat, CGFloat)] = [:]
    private var targetPositions: [Int: (CGFloat, CGFloat)] = [:]
    private let spacing: CGFloat = 0.048
    private let dotRadius: CGFloat = 8
    private let lerpFactor: CGFloat = 0.5

    private var displayLink: CADisplayLink?
    private var pathLengths: [CGFloat] = []
    private var totalPathLength: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(pathPoints: [(CGFloat, CGFloat)], driverDots: [(driverNumber: Int, positionIndex: Int, color: UIColor)], apiPositions: [Int: (CGFloat, CGFloat)]?, locationsVersion: Int) {
        self.pathPoints = pathPoints
        self.driverDots = driverDots
        self.apiPositions = apiPositions
        if pathPoints.count >= 2 {
            var lengths: [CGFloat] = []
            var total: CGFloat = 0
            for i in 0..<pathPoints.count {
                let j = (i + 1) % pathPoints.count
                let (x0, y0) = pathPoints[i], (x1, y1) = pathPoints[j]
                let d = hypot(x1 - x0, y1 - y0)
                lengths.append(d)
                total += d
            }
            pathLengths = lengths
            totalPathLength = total
        } else {
            pathLengths = []
            totalPathLength = 0
        }

        let useAPI = apiPositions != nil && !(apiPositions?.isEmpty ?? true)
        if useAPI, let targets = apiPositions {
            if lastLocationsVersion != locationsVersion {
                var newTargets: [Int: (CGFloat, CGFloat)] = [:]
                for (idx, dot) in driverDots.enumerated() {
                    if let pt = targets[dot.driverNumber] ?? targets.values.first {
                        newTargets[idx] = pt
                        if currentPositions[idx] == nil { currentPositions[idx] = pt }
                    }
                }
                targetPositions = newTargets
                lastLocationsVersion = locationsVersion
            }
        } else {
            lastLocationsVersion = locationsVersion
        }

        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    private func pointAtProgress(_ p: CGFloat) -> (CGFloat, CGFloat) {
        let n = pathPoints.count
        guard n >= 2, totalPathLength > 0 else { return (0.5, 0.5) }
        var t = p.truncatingRemainder(dividingBy: 1)
        if t < 0 { t += 1 }
        var acc: CGFloat = 0
        for i in 0..<n {
            let seg = pathLengths[i]
            if t <= (acc + seg) / totalPathLength {
                let localT = seg > 0 ? (t * totalPathLength - acc) / seg : 0
                let (x0, y0) = pathPoints[i], (x1, y1) = pathPoints[(i + 1) % n]
                return (x0 + (x1 - x0) * localT, y0 + (y1 - y0) * localT)
            }
            acc += seg
        }
        return (pathPoints[0].0, pathPoints[0].1)
    }

    @objc private func tick() {
        let useAPI = apiPositions != nil && !(apiPositions?.isEmpty ?? true)
        if useAPI {
            for (idx, _) in driverDots.enumerated() {
                guard let target = targetPositions[idx] else { continue }
                let cur = currentPositions[idx] ?? target
                let nx = cur.0 + (target.0 - cur.0) * lerpFactor
                let ny = cur.1 + (target.1 - cur.1) * lerpFactor
                currentPositions[idx] = (nx, ny)
            }
        } else {
            let progress = CGFloat(CACurrentMediaTime() * 0.025).truncatingRemainder(dividingBy: 1)
            for (idx, dot) in driverDots.enumerated() {
                let off = CGFloat(dot.positionIndex - 1) * spacing
                var p = (progress - off).truncatingRemainder(dividingBy: 1)
                if p < 0 { p += 1 }
                currentPositions[idx] = pointAtProgress(p)
            }
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = rect.width
        let h = rect.height
        guard w > 0, h > 0 else { return }

        UIColor.label.withAlphaComponent(0.85).setStroke()
        if pathPoints.count >= 2 {
            let path = CGMutablePath()
            let (x0, y0) = pathPoints[0]
            path.move(to: CGPoint(x: x0 * w, y: (1 - y0) * h))
            for i in 1..<pathPoints.count {
                let (x, y) = pathPoints[i]
                path.addLine(to: CGPoint(x: x * w, y: (1 - y) * h))
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setLineWidth(5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        }

        for (idx, dot) in driverDots.enumerated() {
            guard let (u, v) = currentPositions[idx] else { continue }
            let sx = u * w
            let sy = (1 - v) * h
            let r = dotRadius
            let rect = CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)
            dot.color.setFill()
            ctx.fillEllipse(in: rect)
            UIColor.systemBackground.setStroke()
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: rect)
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}
