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

    /// Число этапов в календаре Jolpica для текущего года (иначе 24 — запасной знаменатель для кольца).
    private var seasonRaceCountForRing: Int {
        let y = Calendar.current.component(.year, from: Date())
        if loader.seasonCalendarYearLoaded == y, !loader.seasonCalendarRaces.isEmpty {
            return max(1, loader.seasonCalendarRaces.count)
        }
        return 24
    }

    private static let cardCorner: CGFloat = 28
    private static let cardFill = Color.black
    private static let rightColumnWidth: CGFloat = 168
    private static let smallCardHeight: CGFloat = 108
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

        return HStack(alignment: .top, spacing: Self.gridSpacing) {
            leaderTallCard(
                fullName: leader.fullName,
                teamName: leader.teamName,
                driverNumber: leader.driverNumber,
                gapToP2: gapToP2,
                wins: wins,
                tint: tint
            )
            .frame(maxWidth: .infinity)

            VStack(spacing: Self.gridSpacing) {
                statChip(
                    title: "Points",
                    value: formatPoints(leader.points),
                    unit: "pts",
                    icon: "flame.fill",
                    iconBackground: Color(red: 0.72, green: 0.22, blue: 0.18)
                )
                statChip(
                    title: "Wins",
                    value: "\(wins)",
                    unit: "races",
                    icon: "flag.checkered",
                    iconBackground: Color(red: 0.45, green: 0.32, blue: 0.78)
                )
            }
            .frame(width: Self.rightColumnWidth)
        }
        .frame(maxWidth: .infinity)
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
        wins: Int,
        tint: Color
    ) -> some View {
        let parts = splitGivenFamily(fullName)
        let driverId = String.AppImage.driverIdFromFullName(fullName)
        let assetName = String.AppImage.driverPhoto(driverId: driverId)
            ?? String.AppImage.driverPhotoAsset(forFullName: fullName)
        let ringProgress = ringProgressValue(wins: wins, totalRaces: seasonRaceCountForRing)
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

                Spacer(minLength: 0)

                leaderRingWithFraction(tint: tint, progress: ringProgress, wins: wins, totalRaces: seasonRaceCountForRing)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
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

    private func leaderRingWithFraction(tint: Color, progress: CGFloat, wins: Int, totalRaces: Int) -> some View {
        let size: CGFloat = 56
        let lineWidth: CGFloat = 4.5
        let inner = size - lineWidth * 3.2
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: inner, height: inner)
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(wins)/\(totalRaces)")
                .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 11))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(wins) wins out of \(totalRaces) races")
    }

    private func ringProgressValue(wins: Int, totalRaces: Int) -> CGFloat {
        let cap = max(1, totalRaces)
        return min(1, CGFloat(max(0, wins)) / CGFloat(cap))
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
                        .fill(iconBackground.opacity(0.95))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
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
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
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
