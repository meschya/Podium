//
//  RacesView.swift
//  Podium
//

import SwiftUI

struct RacesView: View {
    @EnvironmentObject var loader: SeasonDataLoader
    @State private var selectedMeetingKey: Int? = nil

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Text("Podium")
                        .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                    Spacer()
                    Text(headerDate)
                        .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        SeasonSectionView(selection: $selectedMeetingKey)

                        if selectedMeetingKey != nil {
                            podiumSection
                            resultsTableSection
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        Color(.systemGroupedBackground)
                        LandscapeStripesView()
                    }
                )
            }
            .navigationBarHidden(true)
            .onChange(of: selectedMeetingKey) { _, newValue in
                if newValue == nil {
                    loader.clearSelectedResults()
                }
            }
        }
    }

    private static let podiumStepHeight2: CGFloat = 120
    private static let podiumStepHeight1: CGFloat = 160
    private static let podiumStepHeight3: CGFloat = 108
    private static let podiumPhotoHeight: CGFloat = 96
    private static let podiumPhotoWidth: CGFloat = 88

    @ViewBuilder
    private var podiumSection: some View {
        let showForSelected = loader.displayedResultsMeetingKey == selectedMeetingKey
        let results = showForSelected ? loader.displayedResults : []
        let top3 = Array(results.prefix(3))

        if !top3.isEmpty {
            let second = top3.count > 1 ? top3[1] : nil
            let first = top3.first
            let third = top3.count > 2 ? top3[2] : nil

            HStack(alignment: .bottom, spacing: 8) {
                if let row = second {
                    podiumStep(height: Self.podiumStepHeight2, position: 2, row: row)
                        .offset(y: 10)
                }
                if let row = first {
                    podiumStep(height: Self.podiumStepHeight1, position: 1, row: row)
                }
                if let row = third {
                    podiumStep(height: Self.podiumStepHeight3, position: 3, row: row)
                        .offset(y: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private func podiumStep(height: CGFloat, position: Int, row: RaceResultRow) -> some View {
        let tint = teamColor(for: row.teamName ?? "")
        let driverPhotoName = String.AppImage.driverPhoto(driverId: driverIdFromName(row.driverName))
        let photoH = min(Self.podiumPhotoHeight, height)
        let teamLogoName = teamLogoImageName(row.teamName ?? "")

        return ZStack(alignment: .leading) {
            // Фото гонщика справа внизу
            HStack {
                Spacer(minLength: 0)
                if let photoName = driverPhotoName {
                    Image(photoName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Self.podiumPhotoWidth, height: photoH * 2.8, alignment: .top)
                        .frame(width: Self.podiumPhotoWidth, height: photoH, alignment: .top)
                        .clipped()
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Текст — может заходить на фото, больше места. Имя в две строки: фамилия сверху, имя снизу.
            VStack(alignment: .leading, spacing: 3) {
                driverNameTwoLines(row.driverName)
                Text(cleanTeamName(row.teamName ?? "—"))
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: 50, alignment: .leading)
                Spacer(minLength: 2)
                Text("\(row.points) pts")
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 10))
                    .foregroundStyle(.secondary)
                Text(row.time.isEmpty ? "—" : row.time)
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.vertical, 10)

            // Кружок цвета команды + лого в правом верхнем углу
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .fill(tint)
                            .frame(width: 22, height: 22)
                        if let logoName = teamLogoName {
                            Image(logoName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            ZStack {
                if let g = Color.AppColors.teamGradient(for: row.teamName ?? "") {
                    LinearGradient(colors: [g.start, g.end], startPoint: .bottom, endPoint: .top)
                } else {
                    ZStack {
                        Color(.secondarySystemGroupedBackground)
                        tint.opacity(0.25)
                    }
                }
                Image(String.AppImage.background_drivers)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFill()
                    .foregroundStyle(tint)
                    .frame(minWidth: 0, minHeight: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.3)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func teamLogoImageName(_ teamName: String) -> String? {
        let lower = teamName.lowercased()
        if lower.contains("red bull") && !lower.contains("racing bulls") { return String.AppImage.redbullracing_logo }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return String.AppImage.racingbulls_logo }
        if lower.contains("ferrari") { return String.AppImage.ferrari_logo }
        if lower.contains("mclaren") { return String.AppImage.mclaren_logo }
        if lower.contains("mercedes") { return String.AppImage.mercedes_logo }
        if lower.contains("aston martin") { return String.AppImage.astonmartin_logo }
        if lower.contains("alpine") { return String.AppImage.alpine_logo }
        if lower.contains("williams") { return String.AppImage.williams_logo }
        if lower.contains("haas") { return String.AppImage.haas_logo }
        if lower.contains("sauber") || lower.contains("kick") { return String.AppImage.haas_logo }
        if lower.contains("audi") { return String.AppImage.audi_logo }
        if lower.contains("cadillac") { return String.AppImage.cadillac_logo }
        return nil
    }

    private func driverIdFromName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "é", with: "e")
            .replacingOccurrences(of: "ö", with: "o")
    }

    /// Имя гонщика в две строки: фамилия сверху, имя снизу.
    @ViewBuilder
    private func driverNameTwoLines(_ fullName: String) -> some View {
        let parts = fullName.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if parts.count <= 1 {
            Text(fullName)
                .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 13))
                .lineLimit(1)
                .foregroundStyle(.primary)
        } else {
            let surname = parts.last ?? ""
            let first = parts.dropLast().joined(separator: " ")
            VStack(alignment: .leading, spacing: 1) {
                Text(surname)
                    .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 13))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(first)
                    .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 13))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
    }

    /// Убирает из названия команды "Formula 1", "F1" и т.п.
    private func cleanTeamName(_ raw: String) -> String {
        var s = raw
        let lower = s.lowercased()
        let prefixes = ["formula 1 ", "formula 1", "f1 ", "f1", "formula one ", "formula one"]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
                break
            }
        }
        if s.lowercased().hasSuffix(" team") { s = String(s.dropLast(5)) }
        if s.lowercased().hasSuffix(" f1 team") { s = String(s.dropLast(8)) }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func teamColor(for teamName: String) -> Color {
        let lower = teamName.lowercased()
        if lower.contains("red bull") && !lower.contains("racing bulls") { return Color.AppColors.redBull }
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
        return Color(.tertiarySystemFill)
    }

    private var resultsTableSection: some View {
        let key = selectedMeetingKey ?? -1
        let showForSelected = loader.displayedResultsMeetingKey == selectedMeetingKey
        let results = showForSelected ? loader.displayedResults : []
        let isLoading = loader.loadingMeetingKey == selectedMeetingKey

        return VStack(alignment: .leading, spacing: 0) {
            Text("Results")
                .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                .padding(.leading, 4)
                .padding(.trailing, 20)
                .padding(.bottom, 10)

            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if results.isEmpty {
                    Text("No results")
                        .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        resultsTableHeader
                        ForEach(results) { row in
                            resultsTableRow(row)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .id(key)
    }

    private var resultsTableHeader: some View {
        HStack(spacing: 8) {
            Text("Pos")
                .frame(width: 32, alignment: .leading)
            Text("Driver")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Team")
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
            Text("Time")
                .frame(width: 56, alignment: .trailing)
            Text("Score")
                .frame(width: 44, alignment: .trailing)
        }
        .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 11))
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func positionText(_ position: Int) -> String {
        switch position {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(position)"
        }
    }

    private func resultsTableRow(_ row: RaceResultRow) -> some View {
        let tint = teamColor(for: row.teamName ?? "")
        let teamLogoName = teamLogoImageName(row.teamName ?? "")
        return HStack(spacing: 8) {
            Text(positionText(row.position))
                .frame(width: 32, alignment: .leading)
            HStack(spacing: 6) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 2)
                Text(row.driverName)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let logoName = teamLogoName {
                    ZStack {
                        Circle()
                            .fill(tint)
                            .frame(width: 24, height: 24)
                        Image(logoName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    }
                    .frame(width: 90, alignment: .leading)
                } else {
                    Text(cleanTeamName(row.teamName ?? "—"))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                }
            }
            Text(row.time.isEmpty ? "—" : row.time)
                .frame(width: 56, alignment: .trailing)
                .lineLimit(1)
            Text("\(row.points)")
                .frame(width: 44, alignment: .trailing)
        }
        .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 13))
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}
