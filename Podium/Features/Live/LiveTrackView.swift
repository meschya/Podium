//
//  LiveTrackView.swift
//  Podium
//
//  Карта 2D: линия трассы + кружки гонщиков с плавной анимацией при обновлении позиций.
//

import SwiftUI

struct LiveTrackView: View {
    var circuitInfo: CircuitInfo?
    var drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    var locations: [Int: (x: Int, y: Int)] = [:]
    var progress: Double = 0
    var locationsVersion: Int = 0
    var animationDate: Date?

    /// Прогресс по трассе (0...1): из времени, если есть animationDate, иначе из progress.
    private var effectiveProgress: Double {
        if let d = animationDate {
            return (d.timeIntervalSinceReferenceDate * 0.025).truncatingRemainder(dividingBy: 1)
        }
        return progress
    }

    var body: some View {
        GeometryReader { geo in
            LiveTrackCanvas(
                progress: effectiveProgress,
                locations: locations,
                circuitInfo: circuitInfo,
                drivers: drivers,
                locationsVersion: locationsVersion,
                animationDate: animationDate,
                width: geo.size.width,
                height: geo.size.height
            )
        }
        .aspectRatio(1.6, contentMode: .fit)
    }
}

private struct LiveTrackCanvas: View {
    let progress: Double
    let locations: [Int: (x: Int, y: Int)]
    let circuitInfo: CircuitInfo?
    let drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    let locationsVersion: Int
    let animationDate: Date?
    let width: CGFloat
    let height: CGFloat

    private let spacing = 0.048
    private let dotRadius: CGFloat = 8
    private let animDuration: TimeInterval = 0.2

    /// Текущие целевые позиции (из API или по прогрессу).
    private func targetPositions(w: CGFloat, h: CGFloat) -> [Int: (CGFloat, CGFloat)] {
        drivers.reduce(into: [:]) { r, d in
            r[d.driverNumber] = dotPosition(driverNumber: d.driverNumber, position: d.position, w: w, h: h)
        }
    }

    /// Позиции для отрисовки: при анимации — плавный lerp к цели, иначе текущая цель.
    private func displayedPositions(
        interpolated: [Int: (CGFloat, CGFloat)],
        targetAnim: [Int: (CGFloat, CGFloat)],
        startTime: Date?
    ) -> [Int: (CGFloat, CGFloat)] {
        guard let start = startTime, let now = animationDate else {
            return targetAnim
        }
        let t = min(1, now.timeIntervalSince(start) / animDuration)
        let ease = t * t * (3 - 2 * t)
        return Dictionary(uniqueKeysWithValues: targetAnim.map { num, pt in
            let (x1, y1) = pt
            let (x0, y0) = interpolated[num] ?? (x1, y1)
            let sx = x0 + (x1 - x0) * CGFloat(ease)
            let sy = y0 + (y1 - y0) * CGFloat(ease)
            return (num, (sx, sy))
        })
    }

    var body: some View {
        let w = width
        let h = height
        let target = targetPositions(w: w, h: h)
        let isAnimating = animationStartTime != nil
        let displayed = isAnimating
            ? displayedPositions(interpolated: interpolatedPositions, targetAnim: targetPositionsForAnim, startTime: animationStartTime)
            : target
        Canvas { context, size in
            let sw = size.width
            let sh = size.height
            let trackPath = makeTrackPath(w: sw, h: sh)
            context.stroke(trackPath, with: .color(.primary.opacity(0.85)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            for d in drivers.sorted(by: { $0.position < $1.position }) {
                guard let (sx, sy) = displayed[d.driverNumber] else { continue }
                let rect = CGRect(x: sx - dotRadius, y: sy - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(d.teamColor))
                context.stroke(Path(ellipseIn: rect), with: .color(Color(.systemBackground)), lineWidth: 1)
            }
        }
        .task(id: circuitInfo?.x.count) {
            cachedPathPoints = circuitInfo?.normalizedPathPoints()
        }
        .onChange(of: circuitInfo?.x.count) { _, _ in
            cachedPathPoints = circuitInfo?.normalizedPathPoints()
        }
        .onChange(of: animationDate) {
            guard let now = animationDate else { return }
            if let start = animationStartTime {
                if now.timeIntervalSince(start) >= animDuration {
                    interpolatedPositions = targetPositionsForAnim
                    animationStartTime = nil
                    targetPositionsForAnim = [:]
                }
            } else {
                interpolatedPositions = target
            }
        }
        .onChange(of: locationsVersion) {
            let newTarget = targetPositions(w: w, h: h)
            if interpolatedPositions.isEmpty {
                interpolatedPositions = newTarget
            } else {
                targetPositionsForAnim = newTarget
                animationStartTime = animationDate
            }
        }
    }

    @State private var interpolatedPositions: [Int: (CGFloat, CGFloat)] = [:]
    @State private var targetPositionsForAnim: [Int: (CGFloat, CGFloat)] = [:]
    @State private var animationStartTime: Date?
    /// Кэш точек трассы, чтобы не вызывать normalizedPathPoints() при каждой отрисовке.
    @State private var cachedPathPoints: [(CGFloat, CGFloat)]?

    private func dotPosition(driverNumber: Int, position: Int, w: CGFloat, h: CGFloat) -> (CGFloat, CGFloat) {
        if let (tx, ty) = locations[driverNumber], let info = circuitInfo {
            // Проекция на трассу (кружки на линии). Координаты как в OpenF1/circuit_info.
            let (u, v) = info.normalizedUVProjected(trackX: tx, trackY: ty)
            return (u * w, (1 - v) * h)
        }
        return pointOnTrack(driverProgress(position), w: w, h: h)
    }

    private func driverProgress(_ position: Int) -> CGFloat {
        let off = Double(position - 1) * spacing
        var p = (progress - off).truncatingRemainder(dividingBy: 1)
        if p < 0 { p += 1 }
        return CGFloat(p)
    }

    private func makeTrackPath(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        let points: [(CGFloat, CGFloat)]
        if let cached = cachedPathPoints, !cached.isEmpty {
            points = cached.map { ($0.0 * w, (1 - $0.1) * h) }
        } else {
            points = (0..<80).map { i in
                let t = CGFloat(i) / 80
                let a = t * 2 * .pi
                let u = 0.5 + 0.38 * cos(a)
                let v = 0.5 + 0.38 * sin(a)
                return (u * w, (1 - v) * h)
            }
        }
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0, y: first.1))
        for p in points.dropFirst() { path.addLine(to: CGPoint(x: p.0, y: p.1)) }
        path.closeSubpath()
        return path
    }

    private func pointOnTrack(_ p: CGFloat, w: CGFloat, h: CGFloat) -> (CGFloat, CGFloat) {
        if let info = circuitInfo {
            let (u, v) = info.pointAtProgress(p)
            return (u * w, (1 - v) * h)
        }
        let a = Double(p) * 2 * .pi
        let u = 0.5 + 0.38 * cos(a)
        let v = 0.5 + 0.38 * sin(a)
        return (CGFloat(u) * w, CGFloat(1 - v) * h)
    }
}

struct LiveTrackViewWithAnimation: View {
    var circuitInfo: CircuitInfo?
    var drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    var locations: [Int: (x: Int, y: Int)]
    var locationsVersion: Int = 0
    var animationDate: Date?

    var body: some View {
        LiveTrackView(
            circuitInfo: circuitInfo,
            drivers: drivers,
            locations: locations,
            progress: 0,
            locationsVersion: locationsVersion,
            animationDate: animationDate
        )
    }
}
