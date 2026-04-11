//
//  HomeChampionshipStatsGrid.swift
//  Podium — championship leader strip + stat chips.
//

import SwiftUI
import UIKit

struct HomeChampionshipStatsGrid: View {
    @EnvironmentObject private var loader: SeasonDataLoader

    private var standings: [(position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)] {
        let year = Calendar.current.component(.year, from: Date())
        if !loader.championshipDriverStandings.isEmpty {
            return loader.championshipDriverStandings
        }
        if loader.driversCupTabStandingsYear == year, !loader.driversCupTabStandings.isEmpty {
            return loader.driversCupTabStandings
        }
        return []
    }

    private var leader: (position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)? {
        standings.first
    }

    private var p2Points: Double? {
        guard standings.count > 1 else { return nil }
        return standings[1].points
    }

    /// Лидер кубка конструкторов: при реальных очках из OpenF1 — по позиции; иначе (фолбэк списка с нулями) — по сумме очков пилотов из `standings`.
    private var constructorLeaderResolved: (position: Int, name: String, points: Int)? {
        let teams = loader.championshipTeamsTop
        let hasConstructorPoints = teams.contains { $0.points > 0 }
        if hasConstructorPoints, let api = teams.min(by: { $0.position < $1.position }) {
            return api
        }
        if let agg = constructorLeaderFromAggregatedDriverStandings() {
            return agg
        }
        return teams.min(by: { $0.position < $1.position })
    }

    private func constructorLeaderFromAggregatedDriverStandings() -> (position: Int, name: String, points: Int)? {
        guard !standings.isEmpty else { return nil }
        var byTeam: [String: Double] = [:]
        for row in standings {
            let t = row.teamName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            byTeam[t, default: 0] += row.points
        }
        let sorted = byTeam.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key.localizedCaseInsensitiveCompare(b.key) == .orderedAscending
        }
        guard let best = sorted.first else { return nil }
        return (1, best.key, Int(best.value.rounded()))
    }

    private static let cardCorner: CGFloat = 28
    private static let cardFill = Color.black
    /// Обводка как у карточки гонщика (`leaderTallCard`).
    private static let cardStrokeBorder = Color.white.opacity(0.12)
    private static let rightColumnWidth: CGFloat = 168
    private static let smallCardHeight: CGFloat = 108
    private static let constructorRowHeight: CGFloat = 100
    private static let gridSpacing: CGFloat = 12

    var body: some View {
        Group {
            if let l = leader {
                leaderGrid(leader: l)
            } else {
                loadingPlaceholder
            }
        }
        .transaction { $0.animation = nil }
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: Self.gridSpacing) {
            HStack(alignment: .top, spacing: Self.gridSpacing) {
                RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                    .fill(Self.cardFill)
                    .frame(height: Self.smallCardHeight * 2 + Self.gridSpacing)
                    .overlay {
                        Text("—")
                            .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 22))
                            .foregroundStyle(.white.opacity(0.22))
                    }
                VStack(spacing: Self.gridSpacing) {
                    RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                        .fill(Self.cardFill)
                        .frame(width: Self.rightColumnWidth, height: Self.smallCardHeight)
                    RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                        .fill(Self.cardFill)
                        .frame(width: Self.rightColumnWidth, height: Self.smallCardHeight)
                }
            }
            .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                .fill(Self.cardFill)
                .frame(maxWidth: .infinity)
                .frame(height: Self.constructorRowHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private func leaderGrid(
        leader: (position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)
    ) -> some View {
        let tint = teamColor(for: leader.teamName)
        let wins = winsForDriver(leader.driverNumber)
        let gapToP2: Double? = {
            guard let p2 = p2Points else { return nil }
            return max(0, leader.points - p2)
        }()

        return VStack(alignment: .leading, spacing: Self.gridSpacing) {
            HStack(alignment: .top, spacing: Self.gridSpacing) {
                leaderTallCard(
                    fullName: leader.fullName,
                    teamName: leader.teamName,
                    driverNumber: leader.driverNumber,
                    gapToP2: gapToP2,
                    sparklineAccessibilityLabel: "Championship \(formatPoints(leader.points)) points",
                    tint: tint
                )
                .frame(maxWidth: .infinity)

                VStack(spacing: Self.gridSpacing) {
                    statChip(
                        title: "Points",
                        value: formatPoints(leader.points),
                        unit: "pts",
                        icon: "chart.line.uptrend.xyaxis",
                        iconBackground: Color(red: 0.20, green: 0.52, blue: 0.58)
                    )
                    statChip(
                        title: "Wins",
                        value: "\(wins)",
                        unit: "races",
                        icon: "flag.checkered",
                        iconBackground: Color(red: 0.34, green: 0.33, blue: 0.32)
                    )
                }
                .frame(width: Self.rightColumnWidth)
            }
            .frame(maxWidth: .infinity)

            if let c = constructorLeaderResolved {
                constructorLeaderRow(position: c.position, teamName: c.name, points: c.points)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Полная ширина: сверху чёрный → снизу `teamGradientBottomColor`; слева подписи и болид снизу колонки, справа очки по центру по вертикали.
    private func constructorLeaderRow(position: Int, teamName: String, points: Int) -> some View {
        let cleaned = cleanTeamName(teamName)
        let tint = teamColor(for: teamName)
        let bottomBrand = Color.AppColors.teamGradientBottomColor(for: teamName)
        let bolid = TeamBolidAssetName.resolve(teamName)
        let corner = Self.cardCorner
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Constructors · P\(position)")
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 10))
                    .foregroundStyle(.white.opacity(0.55))
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                Text(cleaned)
                    .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)

                Spacer(minLength: 0)

                Image(bolid)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, alignment: .leading)
                    .frame(height: 34)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPoints(Double(points)))
                    .font(Font.custom(FontWeight.outfitBold.rawValue, size: 20))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                Text("pts")
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 56, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .frame(height: Self.constructorRowHeight)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.black, bottomBrand],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(String.AppImage.background_drivers)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFill()
                    .foregroundStyle(tint)
                    .frame(minWidth: 0, minHeight: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.28)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Self.cardStrokeBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Constructors leader, \(cleaned), \(formatPoints(Double(points))) points")
    }

    /// Prefer the higher of OpenF1 championship trophies vs Jolpica cup totals (cup may be filled first).
    private func winsForDriver(_ driverNumber: Int) -> Int {
        let ch = loader.championshipDriverTrophyStats[driverNumber]?.wins ?? 0
        let cup = loader.cupTrophyByDriver[driverNumber]?.wins ?? 0
        return max(ch, cup)
    }

    private func leaderTallCard(
        fullName: String,
        teamName: String,
        driverNumber: Int,
        gapToP2: Double?,
        sparklineAccessibilityLabel: String,
        tint: Color
    ) -> some View {
        let parts = splitGivenFamily(fullName)
        let driverId = String.AppImage.driverIdFromFullName(fullName)
        let assetName = String.AppImage.driverPhoto(driverId: driverId)
            ?? String.AppImage.driverPhotoAsset(forFullName: fullName)
        let totalHeight = Self.smallCardHeight * 2 + Self.gridSpacing
        let photoWidth: CGFloat = 108
        let corner = Self.cardCorner
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        return ZStack(alignment: .bottomTrailing) {
            shape.fill(Self.cardFill)
            LinearGradient(
                colors: [Color.black.opacity(0.35), tint.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)
            Image(String.AppImage.background_element)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(tint.opacity(0.35))
                .frame(maxWidth: .infinity)
                .opacity(0.35)
                .clipShape(shape)

            HomeDriverCroppedPhotoView(assetName: assetName, width: photoWidth, height: totalHeight)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    if !parts.given.isEmpty {
                        Text(parts.given)
                            .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 13))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                            .lineLimit(2)
                    }
                    Text(parts.family)
                        .font(Font.custom(FontWeight.outfitBold.rawValue, size: 15))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                        .lineLimit(2)
                }
                .multilineTextAlignment(.leading)

                Text(cleanTeamName(teamName))
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 12))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .lineLimit(2)

                leaderDriverNumberGlyph(driverNumber: driverNumber)
                    .padding(.top, 4)
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)

                if let gap = gapToP2 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gap to 2nd place")
                            .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 10))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        Text("+\(formatPoints(gap)) pts")
                            .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 11))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    }
                    .padding(.top, 2)
                } else {
                    Text("Championship leader")
                        .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 11))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        .padding(.top, 2)
                }

                LeaderPtsSparklineCard(tint: tint, accessibilityLabel: sparklineAccessibilityLabel)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Self.cardStrokeBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func leaderDriverNumberGlyph(driverNumber: Int) -> some View {
        let asset = "\(driverNumber)"
        if UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: 15)
                .accessibilityLabel("Driver number \(driverNumber)")
        } else {
            Text(asset)
                .font(Font.custom(FontWeight.outfitBold.rawValue, size: 15))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    /// Только мини‑график очков (половина ширины карточки), линия рисуется с анимацией.
    private struct LeaderPtsSparklineCard: View {
        let tint: Color
        let accessibilityLabel: String

        @State private var drawProgress: CGFloat = 0

        private var lineAccent: Color {
            Color(red: 0.58, green: 0.42, blue: 0.95)
        }

        var body: some View {
            GeometryReader { geo in
                let fullW = geo.size.width
                let chartW = fullW * 0.5
                let h = geo.size.height
                HStack(alignment: .bottom, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        sparklineFill(width: chartW, height: h)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        lineAccent.opacity(0.42),
                                        lineAccent.opacity(0.12),
                                        Color.black.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(Double(drawProgress))

                        sparklineLine(width: chartW, height: h)
                            .trim(from: 0, to: drawProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [tint.opacity(0.9), lineAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                    }
                    .frame(width: chartW, height: h, alignment: .bottomLeading)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 42)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isImage)
            .onAppear {
                drawProgress = 0
                withAnimation(.easeOut(duration: 1.05)) {
                    drawProgress = 1
                }
            }
        }

        private func sparklineY(t: CGFloat, height: CGFloat) -> CGFloat {
            let wave = sin(t * .pi * 2.12) * 0.09
            let rise = t * t * 0.17
            // Меньше `n` → выше на экране (не прижимаем волну к низу области графика).
            let n = 0.55 - rise - wave - t * 0.12
            return height * max(0.06, min(0.78, n))
        }

        private func sparklineLine(width: CGFloat, height: CGFloat) -> Path {
            var p = Path()
            let steps = 48
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps - 1)
                let x = t * width
                let y = sparklineY(t: t, height: height)
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            return p
        }

        private func sparklineFill(width: CGFloat, height: CGFloat) -> Path {
            var p = sparklineLine(width: width, height: height)
            p.addLine(to: CGPoint(x: width, y: height))
            p.addLine(to: CGPoint(x: 0, y: height))
            p.closeSubpath()
            return p
        }
    }

    private func statChip(title: String, value: String, unit: String, icon: String, iconBackground: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(title)
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 13))
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .fill(iconBackground)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                }
                .frame(width: 32, height: 32)
            }
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(Font.custom(FontWeight.outfitBold.rawValue, size: 28))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text(unit)
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 12))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: Self.smallCardHeight)
        .background(
            RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                .fill(Self.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                .strokeBorder(Self.cardStrokeBorder, lineWidth: 1)
        )
    }

    private func formatPoints(_ p: Double) -> String {
        if abs(p - Double(Int(p))) < 0.001 { return "\(Int(p))" }
        return String(format: "%.1f", p)
    }

    private func splitGivenFamily(_ fullName: String) -> (given: String, family: String) {
        let parts = fullName.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let last = parts.last else { return ("", fullName) }
        if parts.count == 1 { return ("", last) }
        return (parts.dropLast().joined(separator: " "), last)
    }

    private func cleanTeamName(_ raw: String) -> String {
        var s = raw
        for prefix in ["Formula 1 ", "F1 ", "Formula One "] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)); break }
        }
        if s.hasSuffix(" Team") { s = String(s.dropLast(5)) }
        if s.hasSuffix(" F1 Team") { s = String(s.dropLast(8)) }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func teamColor(for teamName: String) -> Color {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return Color.AppColors.redBull }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return Color.AppColors.racingBulls }
        if lower.contains("ferrari") { return Color.AppColors.ferrari }
        if lower.contains("mclaren") { return Color.AppColors.mclaren }
        if lower.contains("mercedes") { return Color.AppColors.mercedes }
        if lower.contains("aston martin") { return Color.AppColors.astonMartin }
        if lower.contains("alpine") { return Color.AppColors.alpine }
        if lower.contains("williams") { return Color.AppColors.williams }
        if lower.contains("haas") { return Color.AppColors.haas }
        if lower.contains("sauber") || lower.contains("kick") { return Color.AppColors.haas }
        if lower.contains("audi") { return Color.AppColors.audi }
        if lower.contains("cadillac") { return Color.AppColors.cadillac }
        return Color.AppColors.accentBlue
    }
}
