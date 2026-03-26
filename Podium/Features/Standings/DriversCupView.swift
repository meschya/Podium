//
//  DriversCupView.swift
//  Podium
//

import SwiftUI
import UIKit

/// Модель для `NavigationStack` — у каждого гонщика своё значение навигации (корректный `@State` на деталке).
private struct DriverCupNavRow: Hashable {
    let position: Int
    let driverNumber: Int
    let fullName: String
    let teamName: String
    let points: Double
    let countryCode: String
}

struct DriversCupView: View {
    @EnvironmentObject private var loader: SeasonDataLoader

    private static let heroHeight: CGFloat = 300
    private static let heroPhotoWidth: CGFloat = 118
    private static let photoFillOverscan: CGFloat = 2.6
    /// Лого команды и флаг — один размер.
    private static let metaIconSide: CGFloat = 20

    private func formatStandingsPoints(_ p: Double) -> String {
        if abs(p - Double(Int(p))) < 0.001 { return "\(Int(p))" }
        return String(format: "%.1f", p)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                GeometryReader { geo in
                    let safeTop = geo.safeAreaInsets.top
                    Group {
                        if loader.driversCupTabStandings.isEmpty {
                            Color.black
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay {
                                    if loader.isLoadingDriversCupStandings || loader.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    if let leader = loader.driversCupTabStandings.first {
                                        let nav = DriverCupNavRow(
                                            position: leader.position,
                                            driverNumber: leader.driverNumber,
                                            fullName: leader.fullName,
                                            teamName: leader.teamName,
                                            points: leader.points,
                                            countryCode: leader.countryCode
                                        )
                                        NavigationLink(value: nav) {
                                            leaderHero(
                                                position: leader.position,
                                                driverNumber: leader.driverNumber,
                                                fullName: leader.fullName,
                                                teamName: leader.teamName,
                                                points: leader.points,
                                                countryCode: leader.countryCode,
                                                safeTopInset: safeTop
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    VStack(spacing: 8) {
                                        ForEach(
                                            Array(loader.driversCupTabStandings.dropFirst().map {
                                                DriverCupNavRow(
                                                    position: $0.position,
                                                    driverNumber: $0.driverNumber,
                                                    fullName: $0.fullName,
                                                    teamName: $0.teamName,
                                                    points: $0.points,
                                                    countryCode: $0.countryCode
                                                )
                                            }),
                                            id: \.driverNumber
                                        ) { nav in
                                            driverRowCard(nav: nav)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 0)
                                    .padding(.bottom, 28)
                                    .offset(y: -10)
                                }
                            }
                            .scrollIndicators(.hidden)
                            .ignoresSafeArea(edges: .top)
                            .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(for: DriverCupNavRow.self) { row in
                DriverCupDetailView(
                    fullName: row.fullName,
                    teamName: row.teamName,
                    countryCode: row.countryCode,
                    points: row.points,
                    driverNumber: row.driverNumber,
                    championshipPosition: row.position
                )
                // Иначе SwiftUI переиспользует одну копию деталки — @State (wins/chart) остаётся от предыдущего пилота.
                .id(row.driverNumber)
            }
        }
        .task(id: loader.selectedSeasonYear) {
            await loader.loadDriversCupTabStandings(year: loader.selectedSeasonYear)
            if loader.cupTrophyYear != loader.selectedSeasonYear {
                loader.scheduleCupTrophiesForYear(loader.selectedSeasonYear)
            }
        }
    }

    private func leaderHero(
        position: Int,
        driverNumber: Int,
        fullName: String,
        teamName: String,
        points: Double,
        countryCode: String,
        safeTopInset: CGFloat
    ) -> some View {
        let blobs = fluidBlobUIColors(for: teamName)
        let topPad = safeTopInset + 10
        /// Фото на всю высоту под safe area, без отступа снизу у героя.
        let photoH = Self.heroHeight - topPad

        return ZStack {
            FluidGradient(blobs: blobs, blur: 0.75, speed: 0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Фото: только справа, низ героя, без нижнего отступа
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer(minLength: 0)
                    driverPhotoTopCrop(
                        fullName: fullName,
                        width: Self.heroPhotoWidth,
                        height: photoH
                    )
                }
            }
            .padding(.top, topPad)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Как в карточке: позиция слева, имя + meta в одной колонке — иконки/PTS под именем по leading.
            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    positionLeadingColumn(
                        position: position,
                        teamName: teamName,
                        digitSize: 22,
                        accentLineHeight: 26
                    )
                    VStack(alignment: .leading, spacing: 12) {
                        Text(fullName)
                            .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: 22))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        teamCountryPointsRow(
                            teamName: teamName,
                            countryCode: countryCode,
                            points: points,
                            iconSide: Self.metaIconSide,
                            numberSize: 13,
                            ptsFontSize: 10,
                            ptsHPadding: 11,
                            ptsVPadding: 1,
                            ptsCornerRadius: 18
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear
                    .frame(width: Self.heroPhotoWidth)
            }
            .padding(.leading, 16)
            .padding(.trailing, 0)
            .padding(.top, topPad)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            heroBottomFadeToBlack
        }
        .frame(height: Self.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// Низ героя: заметный градиент в чёрный, последний стоп — полный чёрный, стык со списком без шва.
    private var heroBottomFadeToBlack: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0), location: 0),
                    .init(color: Color.black.opacity(0.18), location: 0.35),
                    .init(color: Color.black.opacity(0.55), location: 0.72),
                    .init(color: Color.black.opacity(0.92), location: 0.92),
                    .init(color: Color.black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
        }
        .allowsHitTesting(false)
    }

    private func driverRowCard(nav: DriverCupNavRow) -> some View {
        NavigationLink(value: nav) {
            ZStack(alignment: .topLeading) {
                HStack(alignment: .top, spacing: 8) {
                    positionLeadingColumn(position: nav.position, teamName: nav.teamName)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(nav.fullName)
                            .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: 16))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        teamCountryPointsRow(
                            teamName: nav.teamName,
                            countryCode: nav.countryCode,
                            points: nav.points,
                            iconSide: Self.metaIconSide,
                            numberSize: 12,
                            ptsFontSize: 9,
                            ptsHPadding: 9,
                            ptsVPadding: 1,
                            ptsCornerRadius: 18
                        )
                    }
                    .padding(.trailing, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.32))
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(Color.black)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.leading, 34)
            }
        }
        .buttonStyle(.plain)
    }

    /// Полоска + цифра слева; в герое кегль как у ФИО (`digitSize` 22).
    private func positionLeadingColumn(
        position: Int,
        teamName: String,
        digitSize: CGFloat = 14,
        accentLineHeight: CGFloat = 18
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            teamAccentSlash(color: teamAccentSolidColor(for: teamName), lineHeight: accentLineHeight)
            Text("\(position)")
                .font(
                    digitSize >= 20
                        ? Font.custom(FontWeight.titilliumWebBold.rawValue, size: digitSize)
                        : Font.system(size: digitSize, weight: .bold, design: .rounded)
                )
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    /// Один сплошной цвет «снизу» градиента команды (`start` при направлении снизу вверх).
    private func teamAccentSolidColor(for teamName: String) -> Color {
        if let g = Color.AppColors.teamGradient(for: teamName) {
            return g.start
        }
        return teamColor(for: teamName)
    }

    /// Наклонная полоска; `lineHeight` в паре с кеглем цифры (герой — выше).
    private func teamAccentSlash(color: Color, lineHeight: CGFloat = 18) -> some View {
        let lineW: CGFloat = lineHeight >= 22 ? 3.5 : 3
        return ZStack {
            RoundedRectangle(cornerRadius: lineW / 2, style: .continuous)
                .fill(color)
                .frame(width: lineW, height: lineHeight)
                .rotationEffect(.degrees(15))
        }
        .frame(width: max(24, lineHeight * 0.95), height: lineHeight + 10)
    }

    private func teamCountryPointsRow(
        teamName: String,
        countryCode: String,
        points: Double,
        iconSide: CGFloat,
        numberSize: CGFloat,
        ptsFontSize: CGFloat,
        ptsHPadding: CGFloat,
        ptsVPadding: CGFloat,
        ptsCornerRadius: CGFloat
    ) -> some View {
        // Порядок: флаг страны ● название команды ● очки (PTS).
        HStack(alignment: .center, spacing: 11) {
            driverCountryFlag(code: countryCode, side: iconSide)

            if !teamName.isEmpty {
                metaSeparatorDot
                Text(teamName)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                metaSeparatorDot
            }

            pointsValueBadge(
                points: points,
                numberSize: numberSize,
                ptsFontSize: ptsFontSize,
                ptsHPadding: ptsHPadding,
                ptsVPadding: ptsVPadding,
                ptsCornerRadius: ptsCornerRadius
            )
        }
    }

    /// Тоньше и светлее, чем в виджете — не «жирные» кружки.
    private var metaSeparatorDot: some View {
        Circle()
            .fill(Color.white.opacity(0.4))
            .frame(width: 2.5, height: 2.5)
    }

    /// Число обычным шрифтом; «PTS» жирным в низкой белой плашке.
    private func pointsValueBadge(
        points: Double,
        numberSize: CGFloat,
        ptsFontSize: CGFloat,
        ptsHPadding: CGFloat,
        ptsVPadding: CGFloat,
        ptsCornerRadius: CGFloat
    ) -> some View {
        HStack(spacing: 5) {
            Text(formatStandingsPoints(points))
                .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: numberSize))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("PTS")
                .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: ptsFontSize))
                .foregroundStyle(.black)
                .padding(.horizontal, ptsHPadding)
                .padding(.vertical, ptsVPadding)
                .background(Color.white, in: RoundedRectangle(cornerRadius: ptsCornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private func driverCountryFlag(code: String, side: CGFloat) -> some View {
        let alpha2 = String(code.uppercased().filter { $0.isLetter }.prefix(2))
        if alpha2.count == 2, let asset = String.AppImage.flagImage(countryCode: alpha2) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .aspectRatio(3 / 2, contentMode: .fit)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        } else if alpha2.count == 2 {
            Text(flagEmoji(alpha2: alpha2))
                .font(.system(size: 12))
                .frame(width: side, height: side, alignment: .center)
        } else {
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: side, height: side)
        }
    }

    private func flagEmoji(alpha2: String) -> String {
        alpha2.unicodeScalars
            .compactMap { scalar -> String? in
                guard scalar.value >= 0x41, scalar.value <= 0x5A,
                      let u = Unicode.Scalar(0x1F1E6 - 0x41 + Int(scalar.value)) else { return nil }
                return String(u)
            }
            .joined()
    }

    private func driverPhotoTopCrop(fullName: String, width: CGFloat, height: CGFloat) -> some View {
        let asset = String.AppImage.driverPhoto(driverId: String.AppImage.driverIdFromFullName(fullName))
        return Group {
            if let name = asset {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height * Self.photoFillOverscan, alignment: .top)
                    .frame(width: width, height: height, alignment: .top)
                    .clipped()
            } else {
                Color.clear
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height, alignment: .top)
    }

    private func teamLogoImageName(_ teamName: String) -> String? {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return String.AppImage.redbullracing_logo }
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

    private func fluidBlobUIColors(for teamName: String) -> [UIColor] {
        if let g = Color.AppColors.teamGradient(for: teamName) {
            let a = UIColor(g.start)
            let b = UIColor(g.end)
            return [a, b, a]
        }
        let c = teamColor(for: teamName)
        let u = UIColor(c)
        return [u, u.withAlphaComponent(0.65), UIColor(white: 0.12, alpha: 1)]
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
        return Color(white: 0.35)
    }
}

private struct DriverCupDetailView: View {
    @EnvironmentObject private var loader: SeasonDataLoader

    private static let detailNumberFontSize: CGFloat = 44
    private static let detailSuffixFontSize: CGFloat = 14

    let fullName: String
    let teamName: String
    let countryCode: String
    let points: Double
    let driverNumber: Int
    let championshipPosition: Int

    @State private var chartPointsByRound: [Double] = Array(repeating: 0, count: 25)

    /// Wins / podiums / poles — один расчёт на сезон в `SeasonDataLoader` (не по этапу на каждого пилота).
    private var cupWins: Int {
        if loader.cupTrophyYear == loader.selectedSeasonYear,
           let t = loader.cupTrophyByDriver[driverNumber] { return t.wins }
        return 0
    }

    private var cupPodiums: Int {
        if loader.cupTrophyYear == loader.selectedSeasonYear,
           let t = loader.cupTrophyByDriver[driverNumber] { return t.podiums }
        return 0
    }

    private var cupPoles: Int {
        if loader.cupTrophyYear == loader.selectedSeasonYear,
           let t = loader.cupTrophyByDriver[driverNumber] { return t.poles }
        return 0
    }

    private func formatDetailPoints(_ p: Double) -> String {
        if abs(p - Double(Int(p))) < 0.001 { return "\(Int(p))" }
        return String(format: "%.1f", p)
    }

    private var driverInfoPillBar: some View {
        HStack(spacing: 0) {
            metaInfoCell(label: "Name", value: fullName)
            Rectangle().fill(Color.white.opacity(0.4)).frame(width: 1, height: 40)
            countryInfoCell(label: "Country", countryCode: countryCode)
            Rectangle().fill(Color.white.opacity(0.4)).frame(width: 1, height: 40)
            teamInfoCell(label: "Team", teamName: teamName)
        }
        .padding(.vertical, 10)
    }

    private func metaInfoCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 15))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private func countryInfoCell(label: String, countryCode: String) -> some View {
        let alpha2 = alpha2CountryCode(countryCode)
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                .foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .center, spacing: 4) {
                detailHeroFlagView(countryCode: countryCode)
                Text(countryName(from: alpha2))
                    .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    @ViewBuilder
    private func detailHeroFlagView(countryCode: String) -> some View {
        if let name = String.AppImage.flagImage(countryCode: alpha2CountryCode(countryCode)) {
            Image(name)
                .resizable()
                .scaledToFit()
                .aspectRatio(3 / 2, contentMode: .fit)
                .frame(width: 18, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        } else {
            Text(flagEmoji(countryCode: countryCode))
                .font(.system(size: 12))
        }
    }

    private func teamInfoCell(label: String, teamName: String) -> some View {
        let tint = teamColor(for: teamName)
        let logoName = detailTeamLogoImageName(teamName)
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(tint)
                    if let logoName {
                        Image(logoName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    }
                }
                .frame(width: 20, height: 20)
                Text(teamName)
                    .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private func detailTeamLogoImageName(_ teamName: String) -> String? {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return String.AppImage.redbullracing_logo }
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

    private func alpha2CountryCode(_ code: String) -> String {
        let raw = code.trimmingCharacters(in: .whitespaces)
        let c = raw.uppercased()
        if c.count == 2 { return c }
        let iso3To2: [String: String] = [
            "BHR": "BH", "BAH": "BH", "BRN": "BH",
            "SAU": "SA", "KSA": "SA", "SAUD": "SA",
            "MCO": "MC", "MON": "MC", "NLD": "NL", "NED": "NL", "DUT": "NL",
            "AUS": "AU", "CHN": "CN", "JPN": "JP", "USA": "US",
            "ESP": "ES", "CAN": "CA", "GBR": "GB", "AUT": "AT", "FRA": "FR",
            "HUN": "HU", "BEL": "BE", "ITA": "IT", "SGP": "SG", "MEX": "MX",
            "BRA": "BR", "ARE": "AE", "UAE": "AE", "QAT": "QA", "AZE": "AZ"
        ]
        if let two = iso3To2[c] { return two }
        let nameTo2: [String: String] = [
            "AUSTRALIA": "AU", "BAHRAIN": "BH", "SAUDI ARABIA": "SA", "CHINA": "CN", "JAPAN": "JP",
            "UNITED STATES": "US", "SPAIN": "ES", "CANADA": "CA", "UNITED KINGDOM": "GB", "AUSTRIA": "AT",
            "FRANCE": "FR", "HUNGARY": "HU", "BELGIUM": "BE", "ITALY": "IT", "SINGAPORE": "SG",
            "MEXICO": "MX", "BRAZIL": "BR", "UAE": "AE", "QATAR": "QA", "AZERBAIJAN": "AZ",
            "MONACO": "MC", "NETHERLANDS": "NL"
        ]
        let nameKey = raw.uppercased().replacingOccurrences(of: "-", with: " ")
        if let two = nameTo2[nameKey] { return two }
        return String(c.prefix(2))
    }

    private func flagEmoji(countryCode: String) -> String {
        let alpha2 = alpha2CountryCode(countryCode)
        return alpha2.unicodeScalars
            .compactMap { scalar in
                guard scalar.value >= 0x41, scalar.value <= 0x5A,
                      let u = Unicode.Scalar(0x1F1E6 - 0x41 + Int(scalar.value)) else { return nil }
                return String(u)
            }
            .joined()
    }

    private func countryName(from alpha2: String) -> String {
        let code = alpha2.uppercased()
        let names: [String: String] = [
            "AU": "Australia", "BH": "Bahrain", "SA": "Saudi Arabia", "CN": "China", "JP": "Japan",
            "US": "United States", "ES": "Spain", "CA": "Canada", "GB": "United Kingdom", "AT": "Austria",
            "FR": "France", "HU": "Hungary", "BE": "Belgium", "IT": "Italy", "SG": "Singapore",
            "MX": "Mexico", "BR": "Brazil", "AE": "UAE", "QA": "Qatar", "AZ": "Azerbaijan", "MC": "Monaco",
            "NL": "Netherlands", "AR": "Argentina", "FI": "Finland", "DE": "Germany", "NZ": "New Zealand",
            "TH": "Thailand", "CL": "Chile", "CO": "Colombia", "PL": "Poland", "DK": "Denmark", "SE": "Sweden",
            "KR": "South Korea", "ZA": "South Africa", "ID": "Indonesia", "IN": "India"
        ]
        return names[code] ?? alpha2
    }

    var body: some View {
        let blobs = fluidBlobUIColors(for: teamName)

        return GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top

            VStack(spacing: 0) {
                ZStack {
                    FluidGradient(blobs: blobs, blur: 0.75, speed: 0.6)
                        .ignoresSafeArea(edges: .top)

                    HStack(alignment: .bottom, spacing: 0) {
                        Spacer(minLength: 0)
                        driverDetailPhotoWaistCrop(
                            fullName: fullName,
                            width: min(232, geo.size.width * 0.48),
                            height: 420
                        )
                        .opacity(0.95)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 0)

                    VStack(alignment: .leading, spacing: 0) {
                        driverInfoPillBar
                            .padding(.top, 4)

                        detailNumberSuffixRow(
                            number: String(format: "%02d", championshipPosition),
                            suffix: "pos"
                        )
                        .padding(.top, 20)

                        detailNumberSuffixRow(
                            number: formatDetailPoints(points),
                            suffix: "pts"
                        )
                        .padding(.top, 10)

                        detailTrophyStatRow(
                            value: "\(cupWins)",
                            suffix: "wins",
                            systemImage: "trophy.fill"
                        )
                        .padding(.top, 10)

                        detailTrophyStatRow(
                            value: "\(cupPodiums)",
                            suffix: "podiums",
                            systemImage: "chart.bar.fill"
                        )
                        .padding(.top, 10)

                        detailTrophyStatRow(
                            value: "\(cupPoles)",
                            suffix: "poles",
                            systemImage: "scope"
                        )
                        .padding(.top, 10)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geo.safeAreaInsets.top + 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0), location: 0),
                                .init(color: Color.black.opacity(0.35), location: 0.35),
                                .init(color: Color.black.opacity(0.85), location: 0.82),
                                .init(color: Color.black, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 230)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 500 + safeTop)
                .offset(y: -safeTop)

                VStack(alignment: .leading, spacing: 12) {
                    DriverMiniBars(pointsByRound: chartPointsByRound, teamName: teamName)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .background(Color.black)
            }
            .background(Color.black)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: "\(driverNumber)-\(loader.selectedSeasonYear)") {
            await loadSeasonDetailData()
        }
    }

    /// Только график очков по этапам (championship). Трофеи — из `loader.cupTrophyByDriver` после `scheduleCupTrophiesForYear`.
    private func loadSeasonDetailData() async {
        let year = loader.selectedSeasonYear
        let client = OpenF1Client.shared
        var newValues = Array(repeating: 0.0, count: 25)

        await MainActor.run { chartPointsByRound = newValues }

        do {
            let meetings = try await client.meetings(year: year)
                .filter { !$0.meetingName.lowercased().contains("test") }
                .sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }

            let allSessions = try await client.sessions(year: year)
            let byMeeting = Dictionary(grouping: allSessions, by: \.meetingKey)
            var raceSessionKeyByMeeting: [Int: Int] = [:]
            for (mk, sess) in byMeeting {
                if let r = OpenF1Session.grandPrixRaceSession(in: sess) {
                    raceSessionKeyByMeeting[mk] = r.sessionKey
                }
            }

            let rounds = Array(meetings.prefix(25).enumerated())
            let raceMap = raceSessionKeyByMeeting

            guard !Task.isCancelled else { return }

            // По этапам по порядку: если есть `points_start` — очки за гонку напрямую; иначе разница `points_current`.
            var prevCumulative = 0.0
            for (index, meeting) in rounds {
                if Task.isCancelled { return }
                guard let raceSK = raceMap[meeting.meetingKey] else {
                    newValues[index] = 0
                    continue
                }
                guard let standings = try? await client.championshipDrivers(sessionKey: raceSK),
                      let row = standings.first(where: { $0.driverNumber == driverNumber }) else {
                    newValues[index] = 0
                    continue
                }
                if let ps = row.pointsStart {
                    newValues[index] = max(0, row.pointsCurrent - ps)
                } else {
                    newValues[index] = max(0, row.pointsCurrent - prevCumulative)
                }
                prevCumulative = row.pointsCurrent
            }

            await MainActor.run { chartPointsByRound = newValues }
        } catch {
            if Task.isCancelled { return }
            await MainActor.run { chartPointsByRound = Array(repeating: 0, count: 25) }
        }
    }

    private func detailNumberSuffixRow(number: String, suffix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(number)
                .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: Self.detailNumberFontSize))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(suffix)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: Self.detailSuffixFontSize))
                .foregroundStyle(.white)
        }
    }

    private func detailTrophyStatRow(value: String, suffix: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: Self.detailNumberFontSize))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(suffix)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: Self.detailSuffixFontSize))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func fluidBlobUIColors(for teamName: String) -> [UIColor] {
        if let g = Color.AppColors.teamGradient(for: teamName) {
            let a = UIColor(g.start)
            let b = UIColor(g.end)
            return [a, b, a]
        }
        let c = teamColor(for: teamName)
        let u = UIColor(c)
        return [u, u.withAlphaComponent(0.65), UIColor(white: 0.12, alpha: 1)]
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
        return Color(white: 0.35)
    }

    /// Полный рост в ассете: `scaledToFill` по ширине, сверху голова, снизу клип по высоте слота — нижняя граница кадра ниже живота, ближе к поясу.
    private func driverDetailPhotoWaistCrop(fullName: String, width: CGFloat, height: CGFloat) -> some View {
        let asset = String.AppImage.driverPhoto(driverId: String.AppImage.driverIdFromFullName(fullName))
        let innerH = height * 2.35
        return Group {
            if let name = asset {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: innerH, alignment: .top)
                    .frame(width: width, height: height, alignment: .top)
                    .clipped()
            } else {
                Color.clear
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height, alignment: .top)
    }
}

private struct DriverMiniBars: View {
    let pointsByRound: [Double]
    let teamName: String

    private let barsCount = 25
    private let labelColumnWidth: CGFloat = 20
    private let plotHeight: CGFloat = 102
    private let bottomLabelRowHeight: CGFloat = 14
    /// Макет: подписи 1…25 не равномерны по числам, но **линии** на графике через равный шаг по высоте.
    /// Нижняя граница — 0 очков (точка на базовой линии), дальше уровни как на референсе.
    private static let axisLevels: [Double] = [0, 1, 2, 4, 6, 8, 10, 12, 15, 18, 25]
    private var axisMuted: Color { Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255) }

    private var barFill: Color {
        if let g = Color.AppColors.teamGradient(for: teamName) {
            return g.start
        }
        return Color(red: 86 / 255, green: 200 / 255, blue: 195 / 255)
    }

    private var axisLabelFont: Font { .system(size: 6, weight: .regular) }
    private var roundLabelFont: Font { .system(size: 5.5, weight: .regular) }

    @State private var barReveal: CGFloat = 0

    var body: some View {
        let raw: [Double] = (0..<barsCount).map { i in
            i < pointsByRound.count ? pointsByRound[i] : 0
        }
        let levels = Self.axisLevels

        HStack(alignment: .top, spacing: 5) {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let h = geo.size.height
                    let w = geo.size.width
                    ZStack(alignment: .topLeading) {
                        // Подписи только 1…25 (ноль — базовая линия графика, без текста слева).
                        ForEach(1..<levels.count, id: \.self) { idx in
                            let val = levels[idx]
                            let y = yForFractionalIndex(Double(idx), plotHeight: h)
                            HStack(alignment: .center, spacing: 2) {
                                Text("\(Int(val))")
                                    .font(axisLabelFont)
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                    .frame(width: 16, alignment: .trailing)
                                Rectangle()
                                    .fill(axisMuted)
                                    .frame(width: 5, height: 1)
                            }
                            .position(x: w * 0.5, y: y)
                        }
                    }
                }
                .frame(width: labelColumnWidth, height: plotHeight)

                Text("Rounds")
                    .font(axisLabelFont)
                    .foregroundStyle(.white)
                    .frame(width: labelColumnWidth, height: bottomLabelRowHeight, alignment: .trailing)
            }

            VStack(spacing: 0) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let slot = w / CGFloat(barsCount)
                    let barRatio: CGFloat = 0.22
                    let barW = max(2, slot * barRatio)
                    let dotR: CGFloat = 1.35
                    let fill = barFill

                    Canvas { ctx, size in
                        var base = Path()
                        base.move(to: CGPoint(x: 0, y: h - 0.5))
                        base.addLine(to: CGPoint(x: w, y: h - 0.5))
                        ctx.stroke(base, with: .color(axisMuted.opacity(0.85)), lineWidth: 1)

                        for gi in 0..<levels.count {
                            let gy = yForFractionalIndex(Double(gi), plotHeight: h)
                            var grid = Path()
                            grid.move(to: CGPoint(x: 0, y: gy))
                            grid.addLine(to: CGPoint(x: w, y: gy))
                            ctx.stroke(grid, with: .color(axisMuted.opacity(0.35)), lineWidth: 1)
                        }

                        for i in 0..<barsCount {
                            let v = raw[i]
                            let xCenter = (CGFloat(i) + 0.5) * slot
                            if v <= 0 {
                                var dot = Path()
                                dot.addEllipse(in: CGRect(x: xCenter - dotR, y: h - dotR * 2, width: dotR * 2, height: dotR * 2))
                                ctx.fill(dot, with: .color(axisMuted))
                                continue
                            }

                            let yTop = yForPointsValue(v, plotHeight: h)
                            let fullH = h - yTop
                            let barH = max(fullH * barReveal, barW * 0.5 * barReveal)
                            let rect = CGRect(x: xCenter - barW / 2, y: h - barH, width: barW, height: barH)
                            let corner = min(barW * 0.5, barH * 0.5)
                            var cap = Path()
                            cap.addRoundedRect(in: rect, cornerSize: CGSize(width: corner, height: corner))
                            ctx.fill(cap, with: .color(fill))
                        }
                    }
                }
                .frame(height: plotHeight)

                HStack(spacing: 0) {
                    ForEach(0..<barsCount, id: \.self) { i in
                        Text(String(format: "%02d", i + 1))
                            .font(roundLabelFont)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: bottomLabelRowHeight)
            }
        }
        .frame(height: plotHeight + bottomLabelRowHeight)
        .onAppear {
            barReveal = 0
            withAnimation(.easeOut(duration: 0.85)) {
                barReveal = 1
            }
        }
        .onChange(of: pointsByRound) { _, _ in
            barReveal = 0
            withAnimation(.easeOut(duration: 0.85)) {
                barReveal = 1
            }
        }
    }

    /// Равный шаг по **высоте** между уровнями `axisLevels`; индекс 0 = низ (0 очков), 10 = верх (25).
    private func yForFractionalIndex(_ fractionalIndex: Double, plotHeight: CGFloat) -> CGFloat {
        let n = Double(Self.axisLevels.count - 1)
        let t = min(max(fractionalIndex / n, 0), 1)
        return plotHeight * (1 - CGFloat(t))
    }

    /// Очки за этап → Y (малый y = выше столбец; plotHeight = база 0 очков).
    private func yForPointsValue(_ points: Double, plotHeight: CGFloat) -> CGFloat {
        let levels = Self.axisLevels
        let maxV = levels.last!
        let clamped = max(0, points)
        if clamped >= maxV { return 0 }
        if clamped <= levels[0] { return plotHeight }
        for i in 0..<(levels.count - 1) {
            let a = levels[i]
            let b = levels[i + 1]
            if clamped >= a && clamped <= b {
                let span = b - a
                let t = span > 0 ? (clamped - a) / span : 0
                let frac = Double(i) + t
                return yForFractionalIndex(frac, plotHeight: plotHeight)
            }
        }
        return 0
    }
}
