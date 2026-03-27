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

private struct DriverCupCountryFlag: View {
    let code: String
    let side: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        let alpha2 = String(code.uppercased().filter { $0.isLetter }.prefix(2))
        if alpha2.count == 2, let asset = String.AppImage.flagImage(countryCode: alpha2) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: side)
                .clipShape(shape)
        } else if alpha2.count == 2 {
            Text(flagEmoji(alpha2: alpha2))
                .font(.system(size: 12))
                .frame(height: side, alignment: .leading)
        } else {
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(height: side, alignment: .leading)
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
                    driverNumber: row.driverNumber,
                    countryCode: row.countryCode
                )
                // Иначе SwiftUI переиспользует одну копию деталки — @State графика остаётся от предыдущего пилота.
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

    private func driverCountryFlag(code: String, side: CGFloat) -> some View {
        DriverCupCountryFlag(code: code, side: side)
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

/// Клип баннера: лейаут и отрисовка не ниже низа карточки; вверх — зона вылета головы (как маска в виджете).
private struct DriverCupBannerTopBleedClipShape: Shape {
    private let bleedUp: CGFloat = 900
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - bleedUp, width: rect.width, height: bleedUp + rect.height))
    }
}

/// Тот же кроп, что `WidgetBundledImage.portraitTopAlignedFill`: aspect-fill от **верха** PNG, без «центрирования» SwiftUI.
private enum DriverCupBannerPhotoCrop {
    private static var rasterScale: CGFloat {
        max(UIScreen.main.scale, 2.0)
    }

    static func uiImageTopAspectFill(named: String, width: CGFloat, height: CGFloat) -> UIImage? {
        guard let raw = UIImage(named: named)?
            .withRenderingMode(.alwaysOriginal) else { return nil }
        let img = normalizedUp(raw)
        let w = max(width, 1)
        let h = max(height, 1)
        return aspectFillTopCenterAligned(img, targetSize: CGSize(width: w, height: h))
    }

    private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = Self.rasterScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func aspectFillTopCenterAligned(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0, targetSize.width > 0, targetSize.height > 0 else { return image }

        let s = max(targetSize.width / iw, targetSize.height / ih)
        let dw = iw * s
        let dh = ih * s
        let x = (targetSize.width - dw) / 2
        let y: CGFloat = 0

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = Self.rasterScale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            ctx.cgContext.setAllowsAntialiasing(true)
            ctx.cgContext.clip(to: CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(x: x, y: y, width: dw, height: dh))
        }
    }
}

/// Тот же `cornerRadius` и обводка, что у баннера гонщика; без `FluidGradient` — чёрная подложка.
/// Не generic-`struct` — в generic-типах Swift не допускает `static let` у вложенных сущностей в ряде версий.
private struct DriverCupPlainChromeCard: View {
    private let content: AnyView

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }

    var body: some View {
        let cornerRadius: CGFloat = 24
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(shape.fill(Color.black))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

/// Как карточки Teams на Home: только переливающийся `FluidGradient` и та же обводка (`white` 25%, 1 pt), radius 24.
private struct DriverCupShimmerBanner: View {
    let teamName: String
    let fullName: String
    let driverNumber: Int
    let countryCode: String

    private static let cornerRadius: CGFloat = 24
    private static let height: CGFloat = 185
    /// Зона над карточкой — только голова (остальное уже вырезано в bitmap как в виджете).
    private static let headBleedUp: CGFloat = 76

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        let photoW: CGFloat = 152
        let photoH = Self.height + Self.headBleedUp
        let driverId = String.AppImage.driverIdFromFullName(fullName)
        let assetName = String.AppImage.driverPhoto(driverId: driverId)
            ?? String.AppImage.driverPhotoAsset(forFullName: fullName)
        let nameParts = Self.splitGivenAndFamily(fullName)

        FluidGradient(blobs: Self.blobColors(for: teamName), blur: 0.85, speed: 0.52)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if !nameParts.given.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(nameParts.given)
                                    .font(Font.custom(FontWeight.northwellAlt.rawValue, size: 36))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(nameParts.family)
                                    .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: 18))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .padding(.top, -12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text(nameParts.family)
                                .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: 18))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }

                    if !teamName.isEmpty {
                        Text(teamName)
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Self.driverNumberImage(driverNumber: driverNumber)
                        .padding(.top, teamName.isEmpty ? 0 : 10)

                    Spacer(minLength: 0)

                    DriverCupCountryFlag(code: countryCode, side: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .padding(.trailing, photoW + 6)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Group {
                    if let ui = DriverCupBannerPhotoCrop.uiImageTopAspectFill(named: assetName, width: photoW, height: photoH) {
                        Image(uiImage: ui)
                            .interpolation(.high)
                            .antialiased(true)
                            .frame(width: photoW, height: photoH, alignment: .top)
                    } else {
                        Color.clear
                            .frame(width: photoW, height: photoH)
                    }
                }
                .frame(width: photoW, height: photoH, alignment: .bottom)
                .allowsHitTesting(false)
            }
            .clipShape(DriverCupBannerTopBleedClipShape())
    }

    private static func splitGivenAndFamily(_ fullName: String) -> (given: String, family: String) {
        let parts = fullName.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let last = parts.last else { return ("", fullName) }
        if parts.count == 1 { return ("", last) }
        return (parts.dropLast().joined(separator: " "), last)
    }

    /// PNG из `Assets.xcassets/Numbers` (имя imageset = номер, например `44`).
    @ViewBuilder
    private static func driverNumberImage(driverNumber: Int) -> some View {
        let asset = "\(driverNumber)"
        if UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: 17)
                .accessibilityLabel("Driver number \(driverNumber)")
        } else {
            Text(asset)
                .font(Font.custom(FontWeight.titilliumWebBold.rawValue, size: 17))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private static func blobColors(for teamName: String) -> [UIColor] {
        if let g = Color.AppColors.teamGradient(for: teamName) {
            let a = UIColor(g.start)
            let b = UIColor(g.end)
            return [a, b, a]
        }
        let c = UIColor(red: 86 / 255, green: 200 / 255, blue: 195 / 255, alpha: 1)
        return [c, c.withAlphaComponent(0.55), UIColor(white: 0.15, alpha: 1)]
    }
}

private struct DriverCupDetailView: View {
    @EnvironmentObject private var loader: SeasonDataLoader

    let fullName: String
    let teamName: String
    let driverNumber: Int
    let countryCode: String

    @State private var chartPointsByRound: [Double] = Array(repeating: 0, count: 25)
    @State private var chartGpPointsByRound: [Double] = Array(repeating: 0, count: 25)
    @State private var chartSprintPointsByRound: [Double] = Array(repeating: 0, count: 25)
    @State private var summaryStats = DriverCupSummaryStats.zero

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                DriverCupShimmerBanner(
                    teamName: teamName,
                    fullName: fullName,
                    driverNumber: driverNumber,
                    countryCode: countryCode
                )
                    .padding(.top, 13)

                DriverCupDetailStatsRow(
                    seasonYear: loader.selectedSeasonYear,
                    positionValue: standingPositionValue,
                    pointsValue: standingPointsValue
                )

                DriverCupPlainChromeCard {
                    DriverMiniBars(pointsByRound: chartPointsByRound, teamName: teamName)
                }

                HStack(spacing: 8) {
                    DriverCupPlainChromeCard {
                        DriverCumulativeLineChart(pointsByRound: chartPointsByRound, teamName: teamName)
                    }
                    .frame(maxWidth: .infinity)

                    DriverCupPlainChromeCard {
                        DriverGpSprintStackedBars(
                            gpPointsByRound: chartGpPointsByRound,
                            sprintPointsByRound: chartSprintPointsByRound,
                            teamName: teamName
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                DriverCupSummaryTable(stats: summaryStats)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .task(id: "\(driverNumber)-\(loader.selectedSeasonYear)") {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadSeasonDetailData() }
                group.addTask { await loadSeasonStatsData() }
            }
        }
    }

    private var standingRow: (position: Int, points: Double)? {
        if let row = loader.driversCupTabStandings.first(where: { $0.driverNumber == driverNumber }) {
            return (row.position, row.points)
        }
        let key = Self.normalizedDriverNameKey(fullName)
        if let row = loader.driversCupTabStandings.first(where: { Self.normalizedDriverNameKey($0.fullName) == key }) {
            return (row.position, row.points)
        }
        return nil
    }

    private var standingPositionValue: Int {
        standingRow?.position ?? 0
    }

    private var standingPointsValue: Int {
        Int((standingRow?.points ?? 0).rounded())
    }

    private func loadSeasonStatsData() async {
        let year = loader.selectedSeasonYear
        await MainActor.run { summaryStats = .zero }
        do {
            let calendar = try await F1APIClient.shared.seasonCalendar(year: year)
            let races = calendar.sorted { $0.round < $1.round }
            let now = Date()
            let dayFormatter: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(identifier: "UTC")
                return f
            }()

            var gpRaces = 0
            var gpPoints = 0
            var gpWins = 0
            var gpPodiums = 0
            var gpPoles = 0
            var gpTop10s = 0
            var gpDnfs = 0
            var sprintRaces = 0
            var sprintPoints = 0
            var sprintWins = 0
            var sprintPodiums = 0
            var sprintPoles = 0
            var sprintTop10s = 0

            for race in races.prefix(25) {
                if Task.isCancelled { return }
                if let dateStr = race.schedule?.race?.date, dateStr.count >= 10,
                   let d = dayFormatter.date(from: String(dateStr.prefix(10))), d > now {
                    continue
                }

                let results = try? await F1APIClient.shared.raceResults(year: year, round: race.round)
                if let row = resolvedRaceRow(results: results ?? []) {
                    gpRaces += 1
                    gpPoints += row.points
                    if row.position == 1 { gpWins += 1 }
                    if (1...3).contains(row.position) { gpPodiums += 1 }
                    if (1...10).contains(row.position) { gpTop10s += 1 }
                    if isDnfTime(row.time) { gpDnfs += 1 }
                }

                if let pole = try? await F1APIClient.shared.poleDriverNumber(year: year, round: race.round),
                   pole == driverNumber {
                    gpPoles += 1
                }

                let sprintRows = await F1APIClient.shared.sprintRaceResults(year: year, round: race.round)
                if let sprintRow = resolvedSprintRow(rows: sprintRows) {
                    sprintRaces += 1
                    sprintPoints += sprintRow.points
                    if sprintRow.position == 1 { sprintWins += 1 }
                    if (1...3).contains(sprintRow.position) { sprintPodiums += 1 }
                    if (1...10).contains(sprintRow.position) { sprintTop10s += 1 }
                }

                if let sprintPole = await F1APIClient.shared.sprintPoleDriverNumber(year: year, round: race.round),
                   sprintPole == driverNumber {
                    sprintPoles += 1
                }
            }

            await MainActor.run {
                summaryStats = DriverCupSummaryStats(
                    gpRaces: gpRaces,
                    gpPoints: gpPoints,
                    gpWins: gpWins,
                    gpPodiums: gpPodiums,
                    gpPoles: gpPoles,
                    gpTop10s: gpTop10s,
                    gpDnfs: gpDnfs,
                    sprintRaces: sprintRaces,
                    sprintPoints: sprintPoints,
                    sprintWins: sprintWins,
                    sprintPodiums: sprintPodiums,
                    sprintPoles: sprintPoles,
                    sprintTop10s: sprintTop10s
                )
            }
        } catch {
            if Task.isCancelled { return }
            await MainActor.run { summaryStats = .zero }
        }
    }

    private func resolvedRaceRow(results: [RaceResultRow]) -> RaceResultRow? {
        if let byNum = results.first(where: { $0.driverNumber == driverNumber }) { return byNum }
        let key = Self.normalizedDriverNameKey(fullName)
        return results.first(where: { Self.normalizedDriverNameKey($0.driverName) == key })
    }

    private func resolvedSprintRow(rows: [F1APISprintRow]) -> F1APISprintRow? {
        if let byNum = rows.first(where: { $0.driver.number == driverNumber }) { return byNum }
        let key = Self.normalizedDriverNameKey(fullName)
        return rows.first(where: { Self.normalizedDriverNameKey("\($0.driver.name) \($0.driver.surname)") == key })
    }

    private func isDnfTime(_ time: String) -> Bool {
        let t = time.lowercased()
        return t.contains("dnf") || t.contains("ret") || t.contains("dns") || t.contains("dsq")
    }

    /// Очки за этап по столбцам: f1api `.../race` (ГП) + при наличии `.../sprint/race` (спринт). Только ГП занижает столбцы на спринтовых уик-эндах.
    private func loadSeasonDetailData() async {
        let year = loader.selectedSeasonYear
        var newValues = Array(repeating: 0.0, count: 25)
        var gpValues = Array(repeating: 0.0, count: 25)
        var sprintValues = Array(repeating: 0.0, count: 25)

        await MainActor.run {
            chartPointsByRound = newValues
            chartGpPointsByRound = gpValues
            chartSprintPointsByRound = sprintValues
        }

        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }()
        let now = Date()

        do {
            let calendar = try await F1APIClient.shared.seasonCalendar(year: year)
            let races = calendar.sorted { $0.round < $1.round }
            guard !Task.isCancelled else { return }

            for (index, race) in races.prefix(25).enumerated() {
                if Task.isCancelled { return }
                if let dateStr = race.schedule?.race?.date, dateStr.count >= 10,
                   let d = dayFormatter.date(from: String(dateStr.prefix(10))), d > now {
                    newValues[index] = 0
                    gpValues[index] = 0
                    sprintValues[index] = 0
                    continue
                }
                async let gpResults = try? await F1APIClient.shared.raceResults(year: year, round: race.round)
                async let sprintMap = F1APIClient.shared.sprintPointsByDriverNumber(year: year, round: race.round)
                let results = await gpResults
                let sprintByNumber = await sprintMap
                guard let results, !results.isEmpty else {
                    newValues[index] = 0
                    gpValues[index] = 0
                    sprintValues[index] = 0
                    continue
                }
                let resolvedNum = Self.resolvedDriverNumber(in: results, driverNumber: driverNumber, fullName: fullName)
                let gp = Self.pointsInRaceResults(results, driverNumber: driverNumber, fullName: fullName)
                let sp = sprintByNumber[resolvedNum] ?? 0
                gpValues[index] = Double(gp)
                sprintValues[index] = Double(sp)
                newValues[index] = Double(gp + sp)
            }

            await MainActor.run {
                chartPointsByRound = newValues
                chartGpPointsByRound = gpValues
                chartSprintPointsByRound = sprintValues
            }
        } catch {
            if Task.isCancelled { return }
            await MainActor.run {
                chartPointsByRound = Array(repeating: 0, count: 25)
                chartGpPointsByRound = Array(repeating: 0, count: 25)
                chartSprintPointsByRound = Array(repeating: 0, count: 25)
            }
        }
    }

    /// Номер в таблице и в f1api обычно совпадает; при подмене пилота — fallback по имени.
    private static func pointsInRaceResults(_ results: [RaceResultRow], driverNumber: Int, fullName: String) -> Int {
        if let row = results.first(where: { $0.driverNumber == driverNumber }) {
            return row.points
        }
        let key = normalizedDriverNameKey(fullName)
        if let row = results.first(where: { normalizedDriverNameKey($0.driverName) == key }) {
            return row.points
        }
        return 0
    }

    /// Номер из строки ГП того же уик-энда (важно при подмене: в зачёте и в API может отличаться источник).
    private static func resolvedDriverNumber(in results: [RaceResultRow], driverNumber: Int, fullName: String) -> Int {
        if let r = results.first(where: { $0.driverNumber == driverNumber }) { return r.driverNumber }
        let key = normalizedDriverNameKey(fullName)
        if let r = results.first(where: { normalizedDriverNameKey($0.driverName) == key }) { return r.driverNumber }
        return driverNumber
    }

    private static func normalizedDriverNameKey(_ name: String) -> String {
        name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .split { $0.isWhitespace }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct DriverCupSummaryStats: Equatable {
    var gpRaces: Int
    var gpPoints: Int
    var gpWins: Int
    var gpPodiums: Int
    var gpPoles: Int
    var gpTop10s: Int
    var gpDnfs: Int
    var sprintRaces: Int
    var sprintPoints: Int
    var sprintWins: Int
    var sprintPodiums: Int
    var sprintPoles: Int
    var sprintTop10s: Int

    static let zero = DriverCupSummaryStats(
        gpRaces: 0, gpPoints: 0, gpWins: 0, gpPodiums: 0, gpPoles: 0, gpTop10s: 0, gpDnfs: 0,
        sprintRaces: 0, sprintPoints: 0, sprintWins: 0, sprintPodiums: 0, sprintPoles: 0, sprintTop10s: 0
    )
}

private struct DriverCupSummaryTable: View {
    let stats: DriverCupSummaryStats
    @State private var shown = DriverCupSummaryStats.zero
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        DriverCupPlainChromeCard {
            VStack(alignment: .leading, spacing: 14) {
                tableSection(rows: [
                    ("Grand Prix Races", shown.gpRaces, "Grand Prix Points", shown.gpPoints),
                    ("Grand Prix Wins", shown.gpWins, "Grand Prix Podiums", shown.gpPodiums),
                    ("Grand Prix Poles", shown.gpPoles, "Grand Prix Top 10s", shown.gpTop10s),
                    ("DNFs", shown.gpDnfs, nil, nil)
                ])

                Divider().overlay(Color.white.opacity(0.2))

                tableSection(rows: [
                    ("Sprint Races", shown.sprintRaces, "Sprint Points", shown.sprintPoints),
                    ("Sprint Wins", shown.sprintWins, "Sprint Podiums", shown.sprintPodiums),
                    ("Sprint Poles", shown.sprintPoles, "Sprint Top 10s", shown.sprintTop10s)
                ])
            }
            .padding(.vertical, 2)
        }
        .onAppear { animate(to: stats, forceFromZero: true) }
        .onChange(of: stats) { _, newValue in animate(to: newValue, forceFromZero: false) }
    }

    private func tableSection(rows: [(String, Int, String?, Int?)]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    metricCell(label: row.0, value: row.1)
                    metricCell(label: row.2, value: row.3)
                }
            }
        }
    }

    @ViewBuilder
    private func metricCell(label: String?, value: Int?) -> some View {
        if let label, let value {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Text("\(value)")
                    .font(Font.custom(FontWeight.titilliumWebBlack.rawValue, size: 20))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.14), value: value)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Spacer()
                .frame(maxWidth: .infinity)
        }
    }

    private func animate(to target: DriverCupSummaryStats, forceFromZero: Bool) {
        animationTask?.cancel()
        var current = forceFromZero ? .zero : shown
        if forceFromZero { shown = .zero }
        animationTask = Task { @MainActor in
            while true {
                if Task.isCancelled { return }
                var changed = false
                changed = setStep(&current.gpRaces, target.gpRaces) || changed
                changed = setStep(&current.gpPoints, target.gpPoints) || changed
                changed = setStep(&current.gpWins, target.gpWins) || changed
                changed = setStep(&current.gpPodiums, target.gpPodiums) || changed
                changed = setStep(&current.gpPoles, target.gpPoles) || changed
                changed = setStep(&current.gpTop10s, target.gpTop10s) || changed
                changed = setStep(&current.gpDnfs, target.gpDnfs) || changed
                changed = setStep(&current.sprintRaces, target.sprintRaces) || changed
                changed = setStep(&current.sprintPoints, target.sprintPoints) || changed
                changed = setStep(&current.sprintWins, target.sprintWins) || changed
                changed = setStep(&current.sprintPodiums, target.sprintPodiums) || changed
                changed = setStep(&current.sprintPoles, target.sprintPoles) || changed
                changed = setStep(&current.sprintTop10s, target.sprintTop10s) || changed
                shown = current
                if !changed { break }
                try? await Task.sleep(for: .milliseconds(40))
            }
            shown = target
        }
    }

    private func setStep(_ current: inout Int, _ target: Int) -> Bool {
        let next = stepTowardFast(current, target)
        let changed = next != current
        current = next
        return changed
    }

    private func stepTowardFast(_ current: Int, _ target: Int) -> Int {
        guard current != target else { return current }
        let delta = target - current
        let magnitude = abs(delta)
        let step = max(1, magnitude / 8)
        return current + (delta > 0 ? step : -step)
    }
}

private struct DriverCupDetailStatsRow: View {
    let seasonYear: Int
    let positionValue: Int
    let pointsValue: Int

    private let height: CGFloat = 70
    private let spacing: CGFloat = 8
    @State private var shownPosition: Int = 0
    @State private var shownPoints: Int = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let firstW = max(0, (total - (spacing * 2)) * 0.5)
            let smallW = max(0, (total - (spacing * 2) - firstW) / 2)

            HStack(spacing: spacing) {
                statCard {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(seasonYear)")
                            .font(Font.custom(FontWeight.titilliumWebBlack.rawValue, size: 30))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("SEASON")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(width: firstW, height: height)

                statCard {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(shownPosition > 0 ? "\(shownPosition)" : "-")
                            .font(Font.custom(FontWeight.titilliumWebBlack.rawValue, size: 28))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.14), value: shownPosition)
                        Text("POS")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(width: smallW, height: height)

                statCard {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(shownPoints > 0 ? "\(shownPoints)" : "0")
                            .font(Font.custom(FontWeight.titilliumWebBlack.rawValue, size: 28))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.14), value: shownPoints)
                        Text("PTS")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(width: smallW, height: height)
            }
        }
        .frame(height: height)
        .onAppear {
            animateTopCounters(forceFromZero: true)
        }
        .onChange(of: positionValue) { _, _ in
            animateTopCounters(forceFromZero: false)
        }
        .onChange(of: pointsValue) { _, _ in
            animateTopCounters(forceFromZero: false)
        }
    }

    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(shape.fill(Color.black))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }

    private func animateTopCounters(forceFromZero: Bool) {
        animationTask?.cancel()
        let targetPos = max(0, positionValue)
        let targetPts = max(0, pointsValue)
        if forceFromZero {
            shownPosition = 0
            shownPoints = 0
        }
        animationTask = Task { @MainActor in
            while true {
                if Task.isCancelled { return }
                var changed = false

                let nextPos = stepTowardFast(shownPosition, targetPos)
                if nextPos != shownPosition { shownPosition = nextPos; changed = true }

                let nextPts = stepTowardFast(shownPoints, targetPts)
                if nextPts != shownPoints { shownPoints = nextPts; changed = true }

                if !changed { break }
                try? await Task.sleep(for: .milliseconds(45))
            }
        }
    }

    private func stepTowardFast(_ current: Int, _ target: Int) -> Int {
        guard current != target else { return current }
        let delta = target - current
        let magnitude = abs(delta)
        let step = max(1, magnitude / 8)
        return current + (delta > 0 ? step : -step)
    }

}

private struct DriverMiniBars: View {
    let pointsByRound: [Double]
    let teamName: String

    private let barsCount = 25
    private let labelColumnWidth: CGFloat = 20
    private let plotHeight: CGFloat = 100
    private let bottomLabelRowHeight: CGFloat = 12
    /// Макет: подписи 1…25 не равномерны по числам, но **линии** на графике через равный шаг по высоте.
    /// Верх — до ~34: ГП (до 26) + спринт (до 8) на одном уик-энде.
    private static let axisLevels: [Double] = [0, 2, 4, 6, 8, 10, 12, 15, 18, 22, 26, 30, 34]
    private var axisMuted: Color { Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255) }

    private var barFill: Color {
        if let g = Color.AppColors.teamGradient(for: teamName) {
            return g.start
        }
        return Color(red: 86 / 255, green: 200 / 255, blue: 195 / 255)
    }

    private var axisLabelFont: Font { .system(size: 5.5, weight: .regular) }
    private var roundLabelFont: Font { .system(size: 5, weight: .regular) }

    @State private var barReveal: CGFloat = 0

    var body: some View {
        let raw: [Double] = (0..<barsCount).map { i in
            i < pointsByRound.count ? pointsByRound[i] : 0
        }
        let levels = Self.axisLevels

        HStack(alignment: .top, spacing: 4) {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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

                    ZStack(alignment: .topLeading) {
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
                        }

                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(0..<barsCount, id: \.self) { i in
                                let v = raw[i]
                                Group {
                                    if v <= 0 {
                                        Circle()
                                            .fill(axisMuted)
                                            .frame(width: dotR * 2, height: dotR * 2)
                                            .padding(.bottom, dotR)
                                    } else {
                                        let yTop = yForPointsValue(v, plotHeight: h)
                                        let fullH = h - yTop
                                        let barH = max(fullH * barReveal, barW * 0.5 * barReveal)
                                        let cr = min(barW * 0.5, max(barH * 0.5, 1))
                                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                                            .fill(fill)
                                            .frame(width: barW, height: barH)
                                    }
                                }
                                .frame(width: slot, height: h, alignment: .bottom)
                            }
                        }
                    }
                }
                .frame(height: plotHeight)

                HStack(spacing: 0) {
                    ForEach(0..<barsCount, id: \.self) { i in
                        Text("\(i + 1)")
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
        .onAppear { Self.scheduleBarReveal(barReveal: $barReveal) }
        .onChange(of: pointsByRound) { _, _ in Self.scheduleBarReveal(barReveal: $barReveal) }
    }

    /// Canvas не интерполирует кадры `withAnimation`; столбцы — SwiftUI layout. Сброс и подъём в разных тиках runloop, иначе анимация схлопывается.
    private static func scheduleBarReveal(barReveal: Binding<CGFloat>) {
        barReveal.wrappedValue = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(32))
            withAnimation(.easeOut(duration: 0.85)) {
                barReveal.wrappedValue = 1
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

private struct DriverCumulativeLineChart: View {
    let pointsByRound: [Double]
    let teamName: String

    private let roundsCount = 25
    private let chartHeight: CGFloat = 110
    private var gridColor: Color { Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255) }
    private var lineColor: Color {
        if let g = Color.AppColors.teamGradient(for: teamName) { return g.start }
        return Color(red: 86 / 255, green: 200 / 255, blue: 195 / 255)
    }
    private var labelFont: Font { .system(size: 8, weight: .regular) }
    private var roundFont: Font { .system(size: 5, weight: .regular) }

    @State private var lineReveal: CGFloat = 0
    @State private var endDotScale: CGFloat = 0.72

    var body: some View {
        let racePoints: [Double] = (0..<roundsCount).map { i in
            i < pointsByRound.count ? max(0, pointsByRound[i]) : 0
        }
        let cumulative = cumulativePoints(from: racePoints)
        let maxY = max(10, (cumulative.max() ?? 0) * 1.08)
        let tickValues = yTicks(maxY: maxY)

        VStack(alignment: .leading, spacing: 8) {
            Text("Cumulative Points")
                .font(labelFont)
                .foregroundStyle(.white.opacity(0.88))

            HStack(alignment: .top, spacing: 5) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        let w = geo.size.width
                        ZStack(alignment: .topLeading) {
                            ForEach(tickValues.indices, id: \.self) { idx in
                                let tick = tickValues[idx]
                                let y = yForValue(tick, maxY: maxY, plotHeight: h)
                                HStack(spacing: 2) {
                                    Text("\(Int(tick))")
                                        .font(.system(size: 5.5, weight: .regular))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                        .frame(width: 16, alignment: .trailing)
                                    Rectangle()
                                        .fill(gridColor)
                                        .frame(width: 6, height: 1)
                                }
                                .position(x: w * 0.5, y: y)
                            }
                        }
                    }
                    .frame(width: 20, height: chartHeight)

                    Text("Rounds")
                        .font(roundFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: 20, height: 12, alignment: .trailing)
                }

                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let xStep = roundsCount > 1 ? (w / CGFloat(roundsCount - 1)) : w

                        let points: [CGPoint] = (0..<roundsCount).map { i in
                            let x = CGFloat(i) * xStep
                            let y = yForValue(cumulative[i], maxY: maxY, plotHeight: h)
                            return CGPoint(x: x, y: y)
                        }

                        ZStack {
                            Canvas { ctx, size in
                                for tick in tickValues {
                                    let y = yForValue(tick, maxY: maxY, plotHeight: h)
                                    var grid = Path()
                                    grid.move(to: CGPoint(x: 0, y: y))
                                    grid.addLine(to: CGPoint(x: w, y: y))
                                    ctx.stroke(grid, with: .color(gridColor.opacity(0.35)), lineWidth: 1)
                                }

                                if points.count > 1 {
                                    var line = Path()
                                    line.move(to: points[0])
                                    for p in points.dropFirst() { line.addLine(to: p) }
                                    let trimmed = line.trimmedPath(from: 0, to: lineReveal)
                                    ctx.stroke(trimmed, with: .color(lineColor), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                }
                            }

                            if let last = points.last {
                                Circle()
                                    .fill(lineColor)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(endDotScale)
                                    .position(last)
                                    .opacity(lineReveal >= 0.98 ? 1 : 0)
                            }
                        }
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: max(0, w * lineReveal))
                        }
                    }
                    .frame(height: chartHeight)

                    HStack(spacing: 0) {
                        ForEach(0..<roundsCount, id: \.self) { i in
                            Text("\(i + 1)")
                                .font(roundFont)
                                .foregroundStyle(.white.opacity(0.9))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
        .frame(height: chartHeight + 28)
        .onAppear { scheduleReveal() }
        .onChange(of: pointsByRound) { _, _ in scheduleReveal() }
    }

    private func cumulativePoints(from values: [Double]) -> [Double] {
        var sum: Double = 0
        return values.map { v in sum += v; return sum }
    }

    private func yForValue(_ value: Double, maxY: Double, plotHeight: CGFloat) -> CGFloat {
        guard maxY > 0 else { return plotHeight }
        let t = min(max(value / maxY, 0), 1)
        return plotHeight * (1 - CGFloat(t))
    }

    private func yTicks(maxY: Double) -> [Double] {
        let nice: [Double] = [0, 20, 40, 60, 80, 100, 120, 150, 200, 250, 300, 400, 500]
        let filtered = nice.filter { $0 <= maxY }
        if filtered.count >= 4 { return filtered }
        let step = max(10.0, ceil(maxY / 4.0 / 10.0) * 10.0)
        return stride(from: 0.0, through: maxY, by: step).map { $0 }
    }

    private func scheduleReveal() {
        lineReveal = 0
        endDotScale = 0.72
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.timingCurve(0.16, 0.92, 0.22, 1.0, duration: 1.25)) {
                lineReveal = 1
            }
            try? await Task.sleep(for: .milliseconds(980))
            withAnimation(.interpolatingSpring(stiffness: 220, damping: 18)) {
                endDotScale = 1
            }
        }
    }
}

private struct DriverQualyRaceDeltaChart: View {
    let deltaByRound: [Int]
    let teamName: String

    private let roundsCount = 25
    private let chartHeight: CGFloat = 108
    private var gridColor: Color { Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255) }
    private var positiveColor: Color {
        if let g = Color.AppColors.teamGradient(for: teamName) { return g.start }
        return Color(red: 86 / 255, green: 200 / 255, blue: 195 / 255)
    }
    private var negativeColor: Color { Color(red: 222 / 255, green: 72 / 255, blue: 72 / 255) }
    private var labelFont: Font { .system(size: 10, weight: .regular) }
    private var roundFont: Font { .system(size: 8, weight: .regular) }

    @State private var reveal: CGFloat = 0

    var body: some View {
        let values: [Int] = (0..<roundsCount).map { i in i < deltaByRound.count ? deltaByRound[i] : 0 }
        let maxAbs = max(5, values.map { abs($0) }.max() ?? 0)
        let minY = -maxAbs
        let maxY = maxAbs

        VStack(alignment: .leading, spacing: 8) {
            Text("Qualy vs Race Delta")
                .font(labelFont)
                .foregroundStyle(.white.opacity(0.88))

            HStack(alignment: .top, spacing: 5) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        let w = geo.size.width
                        let ticks = [maxY, maxY / 2, 0, minY / 2, minY]
                        ZStack(alignment: .topLeading) {
                            ForEach(ticks.indices, id: \.self) { idx in
                                let tick = ticks[idx]
                                let y = yForValue(Double(tick), minY: Double(minY), maxY: Double(maxY), plotHeight: h)
                                HStack(spacing: 2) {
                                    Text(String(format: "%+d", tick))
                                        .font(.system(size: 7, weight: .regular))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                        .frame(width: 22, alignment: .trailing)
                                    Rectangle()
                                        .fill(gridColor)
                                        .frame(width: 6, height: 1)
                                }
                                .position(x: w * 0.5, y: y)
                            }
                        }
                    }
                    .frame(width: 26, height: chartHeight)

                    Text("Rounds")
                        .font(roundFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 26, height: 12, alignment: .trailing)
                }

                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let slot = w / CGFloat(roundsCount)
                        let barW = max(2.0, slot * 0.34)
                        let zeroY = yForValue(0, minY: Double(minY), maxY: Double(maxY), plotHeight: h)
                        let r = max(0.0, min(reveal, 1.0))
                        ZStack(alignment: .topLeading) {
                            Canvas { ctx, _ in
                                for t in [maxY, maxY / 2, 0, minY / 2, minY] {
                                    let y = yForValue(Double(t), minY: Double(minY), maxY: Double(maxY), plotHeight: h)
                                    var grid = Path()
                                    grid.move(to: CGPoint(x: 0, y: y))
                                    grid.addLine(to: CGPoint(x: w, y: y))
                                    let alpha: Double = t == 0 ? 0.85 : 0.35
                                    ctx.stroke(grid, with: .color(gridColor.opacity(alpha)), lineWidth: 1)
                                }
                            }

                            HStack(alignment: .center, spacing: 0) {
                                ForEach(0..<roundsCount, id: \.self) { i in
                                    let v = Double(values[i]) * Double(r)
                                    let y = yForValue(v, minY: Double(minY), maxY: Double(maxY), plotHeight: h)
                                    let barH = max(1, abs(zeroY - y))
                                    RoundedRectangle(cornerRadius: barW / 2, style: .continuous)
                                        .fill(v >= 0 ? positiveColor : negativeColor)
                                        .frame(width: barW, height: barH)
                                        .offset(y: v >= 0 ? (zeroY - barH / 2) - zeroY : (zeroY + barH / 2) - zeroY)
                                        .frame(width: slot, height: h, alignment: .center)
                                }
                            }
                            .position(x: w / 2, y: zeroY)
                        }
                    }
                    .frame(height: chartHeight)

                    HStack(spacing: 0) {
                        ForEach(0..<roundsCount, id: \.self) { i in
                            Text("\(i + 1)")
                                .font(roundFont)
                                .foregroundStyle(.white.opacity(0.9))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
        .frame(height: chartHeight + 28)
        .onAppear { scheduleReveal() }
        .onChange(of: deltaByRound) { _, _ in scheduleReveal() }
    }

    private func yForValue(_ value: Double, minY: Double, maxY: Double, plotHeight: CGFloat) -> CGFloat {
        let span = max(1, maxY - minY)
        let t = min(max((value - minY) / span, 0), 1)
        return plotHeight * (1 - CGFloat(t))
    }

    private func scheduleReveal() {
        reveal = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(32))
            withAnimation(.easeOut(duration: 0.85)) { reveal = 1 }
        }
    }
}

private struct DriverGpSprintStackedBars: View {
    let gpPointsByRound: [Double]
    let sprintPointsByRound: [Double]
    let teamName: String

    private let roundsCount = 25
    private let chartHeight: CGFloat = 110
    private var gridColor: Color { Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255) }
    private var gpColor: Color {
        if let g = Color.AppColors.teamGradient(for: teamName) { return g.start }
        return Color(red: 86 / 255, green: 200 / 255, blue: 195 / 255)
    }
    private var sprintColor: Color { Color(red: 255 / 255, green: 168 / 255, blue: 59 / 255) }
    private var labelFont: Font { .system(size: 8, weight: .regular) }
    private var roundFont: Font { .system(size: 5, weight: .regular) }

    @State private var reveal: CGFloat = 0

    var body: some View {
        let gp: [Double] = (0..<roundsCount).map { i in i < gpPointsByRound.count ? max(0, gpPointsByRound[i]) : 0 }
        let sp: [Double] = (0..<roundsCount).map { i in i < sprintPointsByRound.count ? max(0, sprintPointsByRound[i]) : 0 }
        let totals = zip(gp, sp).map { $0 + $1 }
        let maxY = max(10, (totals.max() ?? 0) * 1.1)
        let ticks = [0.0, maxY * 0.25, maxY * 0.5, maxY * 0.75, maxY]

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("GP / Sprint Stacked")
                    .font(labelFont)
                    .foregroundStyle(.white.opacity(0.88))
                legendDot(color: gpColor, text: "GP")
                legendDot(color: sprintColor, text: "Sprint")
            }

            HStack(alignment: .top, spacing: 5) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        let w = geo.size.width
                        ZStack(alignment: .topLeading) {
                            ForEach(ticks.indices, id: \.self) { idx in
                                let tick = ticks[idx]
                                let y = yForValue(tick, maxY: maxY, plotHeight: h)
                                HStack(spacing: 2) {
                                    Text("\(Int(tick))")
                                        .font(.system(size: 5.5, weight: .regular))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                        .frame(width: 16, alignment: .trailing)
                                    Rectangle()
                                        .fill(gridColor)
                                        .frame(width: 6, height: 1)
                                }
                                .position(x: w * 0.5, y: y)
                            }
                        }
                    }
                    .frame(width: 20, height: chartHeight)

                    Text("Rounds")
                        .font(roundFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: 20, height: 12, alignment: .trailing)
                }

                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let slot = w / CGFloat(roundsCount)
                        let barW = max(2, slot * 0.35)
                        let global = max(0.0, min(Double(reveal), 1.0))

                        ZStack(alignment: .topLeading) {
                            Canvas { ctx, _ in
                                for tick in ticks {
                                    let y = yForValue(tick, maxY: maxY, plotHeight: h)
                                    var grid = Path()
                                    grid.move(to: CGPoint(x: 0, y: y))
                                    grid.addLine(to: CGPoint(x: w, y: y))
                                    ctx.stroke(grid, with: .color(gridColor.opacity(0.35)), lineWidth: 1)
                                }
                            }

                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(0..<roundsCount, id: \.self) { i in
                                    let gpV = gp[i]
                                    let spV = sp[i]
                                    let gpH = h - yForValue(gpV, maxY: maxY, plotHeight: h)
                                    let totalH = h - yForValue(gpV + spV, maxY: maxY, plotHeight: h)
                                    let spH = max(0, totalH - gpH)
                                    VStack(spacing: 0) {
                                        if spH > 0 {
                                            RoundedRectangle(cornerRadius: barW / 2, style: .continuous)
                                                .fill(sprintColor)
                                                .frame(width: barW, height: spH)
                                        }
                                        if gpH > 0 {
                                            RoundedRectangle(cornerRadius: barW / 2, style: .continuous)
                                                .fill(gpColor)
                                                .frame(width: barW, height: gpH)
                                        }
                                    }
                                    .frame(width: slot, height: h, alignment: .bottom)
                                }
                            }
                        }
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: max(0, w * CGFloat(global)))
                        }
                    }
                    .frame(height: chartHeight)

                    HStack(spacing: 0) {
                        ForEach(0..<roundsCount, id: \.self) { i in
                            Text("\(i + 1)")
                                .font(roundFont)
                                .foregroundStyle(.white.opacity(0.9))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
        .frame(height: chartHeight + 28)
        .onAppear { scheduleReveal() }
        .onChange(of: gpPointsByRound) { _, _ in scheduleReveal() }
        .onChange(of: sprintPointsByRound) { _, _ in scheduleReveal() }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 7, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func yForValue(_ value: Double, maxY: Double, plotHeight: CGFloat) -> CGFloat {
        guard maxY > 0 else { return plotHeight }
        let t = min(max(value / maxY, 0), 1)
        return plotHeight * (1 - CGFloat(t))
    }

    private func scheduleReveal() {
        reveal = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.timingCurve(0.16, 0.92, 0.22, 1.0, duration: 1.25)) {
                reveal = 1
            }
        }
    }
}

