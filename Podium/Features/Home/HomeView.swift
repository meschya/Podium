//
//  HomeView.swift
//  Podium
//

import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var loader: SeasonDataLoader
    /// UIKit SessionTimeline — после первых кадров, чтобы не рвать scroll.
    @State private var showCircuitHeavyHomeRows = false

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let safeTop = geo.safeAreaInsets.top
                ZStack {
                    Color.black.ignoresSafeArea()
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            heroBanner(safeAreaTop: safeTop)
                                .frame(height: Self.heroBlockHeight)
                                .clipped()
                            // VStack: первая ячейка с Leader не откладывается на следующий кадр, в отличие от LazyVStack.
                            VStack(spacing: Self.sectionSpacing) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Leader")
                                        .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 20))
                                        .foregroundStyle(.white.opacity(0.92))
                                    HomeChampionshipStatsGrid()
                                        .padding(.top, 16)
                                }
                                .padding(.horizontal, 20)
                                if showCircuitHeavyHomeRows {
                                    sessionScheduleSection
                                }
                            }
                            .padding(.horizontal, 0)
                            .padding(.top, -56)
                        }
                        .padding(.bottom, 24)
                    }
                    .ignoresSafeArea(edges: .top)
                }
            }
            }
            // Иначе GeometryReader в NavigationStack часто схлопывается по высоте до 0 — виден только чёрный фон.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarHidden(true)
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                let year = Calendar.current.component(.year, from: Date())
                guard loader.selectedSeasonYear == year else { return }
                if loader.championshipDriverStandings.isEmpty,
                   loader.driversCupTabStandingsYear != year || loader.driversCupTabStandings.isEmpty {
                    await loader.loadDriversCupTabStandings(year: year)
                }
            }
            .task {
                while !Task.isCancelled {
                    await MainActor.run {
                        let meeting = loader.meeting
                        let heroVisible = loader.isHeroSectionVisible
                        let sessionLive = loader.currentLiveSessionKey() != nil
                        let shouldRun = meeting != nil && heroVisible && sessionLive
                        if shouldRun {
                            loader.startLiveStreamIfNeeded()
                        } else if loader.liveStreamStarted {
                            loader.stopLiveStream()
                        }
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                showCircuitHeavyHomeRows = true
            }
            .onAppear {
                loader.isHeroSectionVisible = true
            }
            .onDisappear { loader.isHeroSectionVisible = false }
    }

    /// Герой: флаг-градиент + затемнение снизу; весь блок в одном ScrollView — скроллится вместе с контентом.
    private func heroBanner(safeAreaTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            heroGradientStack
            VStack(spacing: 0) {
                topBar(safeAreaTop: safeAreaTop)
                grandPrixInfoBar
                HStack(alignment: .center, spacing: 16) {
                    HomeHeroLeftContentView()
                    Spacer(minLength: 12)
                    if loader.meeting != nil { heroCircuitMapView }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, -70)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var heroGradientStack: some View {
        let alpha2 = loader.meeting.map { alpha2CountryCode($0.countryCode) } ?? "GB"
        return ZStack {
            LinearGradient(
                colors: Self.heroFlagGradientColors(alpha2: alpha2),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            BottomDarkeningOverlay()
        }
    }

    private func topBar(safeAreaTop: CGFloat) -> some View {
        HStack(spacing: 5) {
            Text("Podium")
                .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                .foregroundStyle(.white)
            Spacer()
            Text(headerDate)
                .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 15))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTop + 6)
        .padding(.bottom, 8)
    }

    private var grandPrixInfoBar: some View {
        Group {
            if let m = loader.meeting {
            HStack(spacing: 0) {
                    heroCountryCell(countryName: countryName(from: m), countryCode: m.countryCode)
                    Rectangle().fill(Color.white.opacity(0.4)).frame(width: 1, height: 40)
                    heroInfoCell(label: "City", value: m.location)
                    Rectangle().fill(Color.white.opacity(0.4)).frame(width: 1, height: 40)
                    heroInfoCell(label: "Circuit", value: circuitDisplayName(m))
                }
                .padding(.vertical, 10)
            }
        }
            .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func heroCountryCell(countryName: String, countryCode: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Country")
                .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 12))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 4) {
                heroFlagView(countryCode: countryCode)
                Text(countryName)
                    .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private func heroFlagView(countryCode: String) -> some View {
        let alpha2 = alpha2CountryCode(countryCode)
        if let name = String.AppImage.flagImage(countryCode: alpha2) {
            return AnyView(
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(3/2, contentMode: .fit)
                    .frame(width: 18, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            )
        }
        return AnyView(Text(flagEmoji(countryCode: countryCode)).font(.system(size: 12)))
    }

    private func heroInfoCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 12))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 15))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private func countryName(from m: OpenF1Meeting) -> String {
        let code = alpha2CountryCode(m.countryCode)
        let names: [String: String] = [
            "AU": "Australia", "BH": "Bahrain", "SA": "Saudi Arabia", "CN": "China", "JP": "Japan",
            "US": "United States", "ES": "Spain", "CA": "Canada", "GB": "United Kingdom", "AT": "Austria",
            "FR": "France", "HU": "Hungary", "BE": "Belgium", "IT": "Italy", "SG": "Singapore",
            "MX": "Mexico", "BR": "Brazil", "AE": "UAE", "QA": "Qatar", "AZ": "Azerbaijan", "MC": "Monaco", "NL": "Netherlands"
        ]
        return names[code] ?? m.location
    }

    private func heroTrackLocalAssetName(for m: OpenF1Meeting) -> String? {
        String.AppImage.trackImage(circuitName: m.circuitShortName)
            ?? String.AppImage.trackImage(circuitName: m.location)
    }

    /// Стабильный ключ: при появлении `circuitInfo` после splash пересобираем карту, иначе SwiftUI иногда не обновляет слой контура.
    private func heroTrackMapIdentity(meetingKey: Int, circuit: CircuitInfo?) -> String {
        let n = circuit.map { min($0.x.count, $0.y.count) } ?? 0
        return "\(meetingKey)-\(n)"
    }

    private var heroCircuitMapView: some View {
        Group {
            if let m = loader.meeting {
                let trackLocal = heroTrackLocalAssetName(for: m)
                if loader.liveStreamStarted, loader.currentLiveSessionKey() != nil {
                    HeroCircuitMapWithDotsView(
                        circuitInfo: loader.circuitInfo,
                        meeting: m,
                        localTrackImageName: trackLocal
                    )
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.trailing, 20)
                    .allowsHitTesting(false)
                } else {
                    // Герой: сначала вектор OpenF1 (та же сетка, что у live-точек), затем ассет трассы. `circuit_image` у meeting часто промо, не схема — не показываем.
                    TrackMapView(
                        circuitInfo: loader.circuitInfo,
                        imageURL: nil,
                        localTrackImageName: trackLocal,
                        compact: true,
                        compactSize: CGSize(width: 208, height: 130),
                        preferRasterTrackInCompact: false,
                        strokeColor: .white,
                        cardBackground: .clear
                    )
                    .frame(width: 208, height: 130)
                    .fixedSize(horizontal: true, vertical: true)
                    .id(heroTrackMapIdentity(meetingKey: m.meetingKey, circuit: loader.circuitInfo))
                    .padding(.trailing, 20)
                    .allowsHitTesting(false)
                    .onAppear { loader.unregisterLiveDotsView() }
                }
            }
        }
    }

    private var sessionScheduleSection: some View {
        guard !loader.nextMeetingSessions.isEmpty else { return AnyView(EmptyView()) }
            let title = (loader.meeting?.meetingName ?? "Next race") + " sessions"
        return AnyView(
            sectionBlock(title: title) {
                SessionTimelineChart(sessions: loader.nextMeetingSessions, eventGmtOffset: loader.meeting?.gmtOffset)
                    .padding(.horizontal, 20)
            }
        )
    }

    /// Два стопа под `LinearGradient` героя (страна ГП).
    private static func heroFlagGradientColors(alpha2: String) -> [Color] {
        switch alpha2 {
        case "BH": return [Color(red: 0.86, green: 0.16, blue: 0.22), Color(red: 0.12, green: 0.05, blue: 0.08)]
        case "SA": return [Color(red: 0.1, green: 0.42, blue: 0.22), Color(red: 0.04, green: 0.14, blue: 0.1)]
        case "AU": return [Color(red: 0.05, green: 0.12, blue: 0.35), Color(red: 0.75, green: 0.12, blue: 0.18)]
        case "JP": return [Color(red: 0.72, green: 0.12, blue: 0.2), Color(red: 0.08, green: 0.06, blue: 0.22)]
        case "CN": return [Color(red: 0.82, green: 0.14, blue: 0.12), Color(red: 0.1, green: 0.05, blue: 0.06)]
        case "US": return [Color(red: 0.08, green: 0.14, blue: 0.38), Color(red: 0.55, green: 0.1, blue: 0.16)]
        case "IT": return [Color(red: 0.06, green: 0.32, blue: 0.16), Color(red: 0.55, green: 0.12, blue: 0.14)]
        case "MC": return [Color(red: 0.14, green: 0.22, blue: 0.52), Color(red: 0.62, green: 0.14, blue: 0.18)]
        case "CA": return [Color(red: 0.78, green: 0.14, blue: 0.16), Color(red: 0.08, green: 0.12, blue: 0.32)]
        case "ES": return [Color(red: 0.75, green: 0.55, blue: 0.08), Color(red: 0.12, green: 0.08, blue: 0.28)]
        case "AT": return [Color(red: 0.72, green: 0.1, blue: 0.12), Color(red: 0.12, green: 0.06, blue: 0.18)]
        case "GB": return [Color(red: 0.06, green: 0.14, blue: 0.42), Color(red: 0.52, green: 0.08, blue: 0.14)]
        case "HU": return [Color(red: 0.12, green: 0.38, blue: 0.18), Color(red: 0.62, green: 0.14, blue: 0.12)]
        case "BE": return [Color(red: 0.1, green: 0.1, blue: 0.12), Color(red: 0.72, green: 0.12, blue: 0.14)]
        case "NL": return [Color(red: 0.1, green: 0.22, blue: 0.62), Color(red: 0.78, green: 0.5, blue: 0.08)]
        case "FR": return [Color(red: 0.12, green: 0.2, blue: 0.55), Color(red: 0.62, green: 0.14, blue: 0.22)]
        case "SG": return [Color(red: 0.72, green: 0.12, blue: 0.18), Color(red: 0.06, green: 0.18, blue: 0.42)]
        case "MX": return [Color(red: 0.08, green: 0.38, blue: 0.2), Color(red: 0.68, green: 0.14, blue: 0.12)]
        case "BR": return [Color(red: 0.06, green: 0.32, blue: 0.14), Color(red: 0.72, green: 0.55, blue: 0.08)]
        case "AE": return [Color(red: 0.06, green: 0.28, blue: 0.22), Color(red: 0.55, green: 0.42, blue: 0.1)]
        case "QA": return [Color(red: 0.52, green: 0.08, blue: 0.28), Color(red: 0.08, green: 0.14, blue: 0.42)]
        case "AZ": return [Color(red: 0.12, green: 0.42, blue: 0.62), Color(red: 0.72, green: 0.2, blue: 0.12)]
        default:
            return [Color(red: 0.11, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.06, blue: 0.12)]
        }
    }

    private static let heroBlockHeight: CGFloat = 430
    /// Отступ между блоком статистики чемпионата и сессиями.
    private static let sectionSpacing: CGFloat = 30

    /// Секция: заголовок и контент без зазора (слиплены).
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 20))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 20)
            content()
                .padding(.top, 16)
        }
    }

    private static let circuitNameOverrides: [String: String] = [
        "sakhir": "Bahrain International Circuit",
        "melbourne": "Albert Park",
        "shanghai": "Shanghai International Circuit",
        "suzuka": "Suzuka International Racing Course",
        "jeddah": "Jeddah Corniche Circuit",
        "miami": "Miami International Autodrome",
        "miami gardens": "Miami International Autodrome",
        "imola": "Autodromo Enzo e Dino Ferrari",
        "monte carlo": "Circuit de Monaco",
        "catalunya": "Circuit de Barcelona-Catalunya",
        "barcelona": "Circuit de Barcelona-Catalunya",
        "madrid": "Madrid Street Circuit",
        "madring": "Madrid Street Circuit",
        "montreal": "Circuit Gilles Villeneuve",
        "montréal": "Circuit Gilles Villeneuve",
        "spielberg": "Red Bull Ring",
        "silverstone": "Silverstone Circuit",
        "spa-francorchamps": "Circuit de Spa-Francorchamps",
        "budapest": "Hungaroring",
        "hungaroring": "Hungaroring",
        "zandvoort": "Circuit Zandvoort",
        "monza": "Autodromo Nazionale di Monza",
        "baku": "Baku City Circuit",
        "singapore": "Marina Bay Street Circuit",
        "marina bay": "Marina Bay Street Circuit",
        "austin": "Circuit of the Americas",
        "mexico city": "Autódromo Hermanos Rodríguez",
        "interlagos": "Autódromo José Carlos Pace",
        "são paulo": "Autódromo José Carlos Pace",
        "las vegas": "Las Vegas Street Circuit",
        "lusail": "Lusail International Circuit",
        "yas marina circuit": "Yas Marina Circuit",
        "yas island": "Yas Marina Circuit",
    ]

    private func circuitDisplayName(_ m: OpenF1Meeting) -> String {
        let key = m.circuitShortName.lowercased()
        if let name = Self.circuitNameOverrides[key] {
            return name
        }
        let locKey = m.location.lowercased()
        if let name = Self.circuitNameOverrides[locKey] {
            return name
        }
        return m.circuitShortName.isEmpty ? m.location : (m.circuitShortName.prefix(1).uppercased() + m.circuitShortName.dropFirst())
    }

    private func alpha2CountryCode(_ code: String) -> String {
        let raw = code.trimmingCharacters(in: .whitespaces)
        let c = raw.uppercased()
        if c == "UK" || c == "U.K." { return "GB" }
        if c == "UAE" { return "AE" }
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
}

/// Левая колонка героя: подписана только на `LiveMapState`, чтобы MQTT не перерисовывал весь `HomeView` ~120×/с.
private struct HomeHeroLeftContentView: View {
    @EnvironmentObject private var loader: SeasonDataLoader
    @EnvironmentObject private var liveMapState: LiveMapState

    var body: some View {
        let top3 = liveMapState.top3LiveDrivers
        let hasLocations = !liveMapState.locations.isEmpty
        let isLiveNow = hasLocations
        return VStack(alignment: .leading, spacing: 6) {
            if isLiveNow {
                Text("Live")
                    .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                if !top3.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(top3, id: \.driverNumber) { row in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(heroTeamColor(for: row.teamName))
                                    .frame(width: 14, height: 14)
                                Text("\(row.position). \(row.name)")
                                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 13))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.28), value: top3.map { "\($0.driverNumber)-\($0.position)" }.joined(separator: ","))
                } else {
                    Text("\(liveMapState.locations.count) машин на трассе")
                        .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if let m = loader.meeting {
                Text(m.meetingName)
                    .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let str = heroGpDateString(m) {
                    Text(str)
                        .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 13))
                        .foregroundStyle(Color(.systemGray))
                }
                if let (start, eventName) = heroNextEventTarget(), start > Date() {
                    heroCountdownView(to: start, eventName: eventName)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .allowsHitTesting(false)
    }

    private func heroGpDateString(_ m: OpenF1Meeting) -> String? {
        let cal = Calendar.current
        guard let start = m.parsedDateStart else { return nil }
        let startDay = cal.startOfDay(for: start)
        let end: Date
        if let e = m.parsedDateEnd {
            end = e
        } else {
            end = start
        }
        let endDay = cal.startOfDay(for: end)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM"
        let year = cal.component(.year, from: start)
        if startDay != endDay {
            return "\(f.string(from: start)) - \(f.string(from: end)), \(year)"
        }
        return "\(f.string(from: start)), \(year)"
    }

    private func heroCountdownView(to date: Date, eventName: String?) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let c = heroCountdownComponents(from: context.date, to: date)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    heroCountdownBlock(value: c.days, label: "d")
                    heroCountdownBlock(value: c.hours, label: "h")
                    heroCountdownBlock(value: c.minutes, label: "m")
                    heroCountdownBlock(value: c.seconds, label: "s")
                }
                if let name = eventName, !name.isEmpty {
                    HStack(spacing: 2) {
                        Text("until ")
                            .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(name)
                            .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 11))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func heroNextEventTarget() -> (Date, String)? {
        let now = Date()
        let tz = loader.meeting.flatMap { eventTimeZone(from: $0.gmtOffset) } ?? .current
        for s in loader.nextMeetingSessions {
            guard let start = parseSessionDate(s.dateStart, eventTimeZone: tz), start > now else { continue }
            return (start, heroSessionShortName(s.sessionName))
        }
        guard let m = loader.meeting, let start = m.parsedDateStart, start > now else { return nil }
        return (start, "Race")
    }

    private func eventTimeZone(from gmtOffset: String?) -> TimeZone? {
        guard let s = gmtOffset?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let sign = s.hasPrefix("-") ? -1 : 1
        let cleaned = s.replacingOccurrences(of: "UTC", with: "").trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":")
        let h = Int(parts.first ?? "0") ?? 0
        let m = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return TimeZone(secondsFromGMT: sign * (abs(h) * 3600 + min(59, m) * 60))
    }

    private func parseSessionDate(_ s: String?, eventTimeZone: TimeZone?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        if !s.contains("Z"), let tz = eventTimeZone ?? TimeZone(identifier: "UTC") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            if let d = f.date(from: s) { return d }
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let d = f.date(from: s) { return d }
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private func heroCountdownBlock(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%02d", value))
                .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 13))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.16), value: value)
            Text(label)
                .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 8))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(minWidth: 26)
        .padding(.vertical, 4)
        .padding(.horizontal, 3)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.14))
        }
    }

    private func heroCountdownComponents(from now: Date, to target: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let delta = max(0, target.timeIntervalSince(now))
        let d = Int(delta) / 86400
        let h = (Int(delta) % 86400) / 3600
        let m = (Int(delta) % 3600) / 60
        let s = Int(delta) % 60
        return (d, h, m, s)
    }

    private func heroSessionShortName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("practice") || lower.contains("fp") {
            if lower.contains("1") { return "FP1" }
            if lower.contains("2") { return "FP2" }
            if lower.contains("3") { return "FP3" }
            return "FP"
        }
        if lower.contains("qualifying") || lower.contains("quali") { return "Quali" }
        if lower.contains("race") { return "Race" }
        if lower.contains("sprint") { return "Sprint" }
        return name
    }

    private func heroTeamColor(for teamName: String) -> Color {
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
        return Color(.secondarySystemGroupedBackground)
    }
}

/// Герой-карта с точками. Точки обновляются через UIKit (loader.registerLiveDotsView) — без @Published и без лагов SwiftUI.
private struct HeroCircuitMapWithDotsView: View {
    @EnvironmentObject var loader: SeasonDataLoader
    var circuitInfo: CircuitInfo?
    var meeting: OpenF1Meeting
    var localTrackImageName: String?

    private let size = CGSize(width: 208, height: 130)

    var body: some View {
        ZStack(alignment: .topLeading) {
            TrackMapView(
                circuitInfo: circuitInfo,
                imageURL: nil,
                localTrackImageName: localTrackImageName,
                compact: true,
                compactSize: size,
                preferRasterTrackInCompact: false,
                strokeColor: .white,
                cardBackground: .clear
            )
            .frame(width: size.width, height: size.height)
            LiveCircuitDotsUIKitView(
                loader: loader,
                meetingKey: meeting.meetingKey,
                circuitInfo: circuitInfo,
                size: size
            )
            .zIndex(1)
        }
        .frame(width: size.width, height: size.height)
        .onDisappear { loader.unregisterLiveDotsView() }
    }
}

/// Точки на карте: целевые позиции приходят ~40 раз/с, отрисовка 60 FPS с плавной интерполяцией из точки в точку.
private final class LiveDotsUIView: UIView, LiveDotsViewUpdating {
    private var targetByDriver: [Int: CGPoint] = [:]
    private var displayByDriver: [Int: CGPoint] = [:]
    private var colorByDriver: [Int: UIColor] = [:]
    private let dotRadius: CGFloat = 5
    private var displayLink: CADisplayLink?
    private let lerpFactor: CGFloat = 0.22
    private let maxStepPerFrame: CGFloat = 18.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        displayLink = link
    }

    @objc private func tick() {
        if targetByDriver.isEmpty {
            if !displayByDriver.isEmpty {
                displayByDriver = [:]
                setNeedsDisplay()
            }
            displayLink?.isPaused = true
            return
        }

        // Удаляем ушедших гонщиков без «скачка» индексов.
        displayByDriver = displayByDriver.filter { targetByDriver[$0.key] != nil }

        var changed = false
        for (num, t) in targetByDriver {
            let d = displayByDriver[num] ?? t
            let dxRaw = (t.x - d.x) * lerpFactor
            let dyRaw = (t.y - d.y) * lerpFactor
            let dx = max(-maxStepPerFrame, min(maxStepPerFrame, dxRaw))
            let dy = max(-maxStepPerFrame, min(maxStepPerFrame, dyRaw))
            let nx = d.x + dx
            let ny = d.y + dy
            if abs(nx - d.x) > 0.01 || abs(ny - d.y) > 0.01 { changed = true }
            displayByDriver[num] = CGPoint(x: nx, y: ny)
        }
        if changed { setNeedsDisplay() }
    }

    func setPositions(_ positions: [CGPoint], colors: [UIColor], driverNumbers: [Int]) {
        var newTarget: [Int: CGPoint] = [:]
        var newColors: [Int: UIColor] = [:]
        for (idx, num) in driverNumbers.enumerated() {
            guard idx < positions.count else { continue }
            let p = positions[idx]
            newTarget[num] = p
            newColors[num] = idx < colors.count ? colors[idx] : .gray
        }
        targetByDriver = newTarget
        colorByDriver = newColors

        if newTarget.isEmpty {
            displayByDriver = [:]
            displayLink?.isPaused = true
            setNeedsDisplay()
            return
        }
        displayLink?.isPaused = false

        // Новый гонщик — начинаем сразу с target, чтобы не вылетал из угла.
        for (num, p) in newTarget where displayByDriver[num] == nil {
            displayByDriver[num] = p
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1 else { return }
        for num in displayByDriver.keys.sorted() {
            guard let p = displayByDriver[num] else { continue }
            let fillColor = (colorByDriver[num] ?? .gray).cgColor
            let r = CGRect(x: p.x - dotRadius, y: p.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            ctx.setFillColor(fillColor)
            ctx.fillEllipse(in: r)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: r)
        }
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }
}

private struct LiveCircuitDotsUIKitView: UIViewRepresentable {
    var loader: SeasonDataLoader
    var meetingKey: Int
    var circuitInfo: CircuitInfo?
    var size: CGSize

    final class Coordinator {
        var registrationKey: (Int, Int, CGFloat, CGFloat)?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> LiveDotsUIView {
        let v = LiveDotsUIView()
        v.backgroundColor = .clear
        v.isOpaque = false
        context.coordinator.registrationKey = registrationFingerprint()
        loader.registerLiveDotsView(v, circuitInfo: circuitInfo, size: size)
        return v
    }

    func updateUIView(_ uiView: LiveDotsUIView, context: Context) {
        let fp = registrationFingerprint()
        if let existing = context.coordinator.registrationKey, existing == fp { return }
        context.coordinator.registrationKey = fp
        loader.registerLiveDotsView(uiView, circuitInfo: circuitInfo, size: size)
    }

    private func registrationFingerprint() -> (Int, Int, CGFloat, CGFloat) {
        let pathCount = circuitInfo?.cachedNormalizedPath?.count
            ?? (circuitInfo.map { max($0.x.count, $0.y.count) } ?? 0)
        return (meetingKey, pathCount, size.width, size.height)
    }
}

/// Кружки позиций машин на карте трассы при прямой трансляции (SwiftUI Canvas — оставлен для других экранов при необходимости).
/// Приоритет: 1) coordinatesByDriver (реальные X,Y из Position.z по подписке), 2) positionProgressByDriver, 3) locations (OpenF1).
/// Координаты как в CircuitPathShape: x = u*w, y = (1-v)*h.
private struct LiveCircuitDotsOverlay: View {
    var circuitInfo: CircuitInfo?
    var locations: [OpenF1Location]
    var positionProgressByDriver: [Int: CGFloat] = [:]
    /// Реальное расположение из F1 Position.z (подписка): координаты на трассе.
    var coordinatesByDriver: [Int: F1LiveCoordinate] = [:]
    var size: CGSize

    private static let dotRadius: CGFloat = 5

    private var latestByDriver: [(driverNumber: Int, x: Int, y: Int)] {
        let byDriver = Dictionary(grouping: locations) { $0.driverNumber }
        return byDriver.compactMap { num, locs -> (Int, Int, Int)? in
            guard let last = locs.max(by: { $0.date < $1.date }) else { return nil }
            return (num, last.x, last.y)
        }
    }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            guard w > 1, h > 1 else { return }

            if !coordinatesByDriver.isEmpty, let info = circuitInfo {
                for (_, coord) in coordinatesByDriver {
                    let (u, v) = info.normalizedUVProjected(trackX: coord.x, trackY: coord.y)
                    let uClamp = min(1, max(0, CGFloat(u)))
                    let vClamp = min(1, max(0, CGFloat(v)))
                    let sx = uClamp * w
                    let sy = (1 - vClamp) * h
                    let rect = CGRect(x: sx - Self.dotRadius, y: sy - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.red))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 1))
                }
            } else if !positionProgressByDriver.isEmpty, let info = circuitInfo {
                for (_, progress) in positionProgressByDriver {
                    let (u, v) = info.pointAtProgress(progress)
                    let uClamp = min(1, max(0, u))
                    let vClamp = min(1, max(0, v))
                    let sx = uClamp * w
                    let sy = (1 - vClamp) * h
                    let rect = CGRect(x: sx - Self.dotRadius, y: sy - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.red))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 1))
                }
            } else if !positionProgressByDriver.isEmpty {
                let sorted = positionProgressByDriver.sorted { $0.key < $1.key }
                let n = CGFloat(max(1, sorted.count))
                for (index, _) in sorted.enumerated() {
                    let sx = (CGFloat(index) + 0.5) / n * w
                    let sy = h - Self.dotRadius
                    let rect = CGRect(x: sx - Self.dotRadius, y: sy - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.red))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 1))
                }
            } else if let info = circuitInfo {
                for item in latestByDriver {
                    let (u, v) = info.normalizedUVProjected(trackX: item.x, trackY: item.y)
                    let uClamp = min(1, max(0, CGFloat(u)))
                    let vClamp = min(1, max(0, CGFloat(v)))
                    let sx = uClamp * w
                    let sy = (1 - vClamp) * h
                    let rect = CGRect(x: sx - Self.dotRadius, y: sy - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.red))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 1))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

