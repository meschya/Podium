//
//  HomeView.swift
//  Podium
//

import SafariServices
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var loader: SeasonDataLoader
    @State private var newsURLInApp: IdentifiableURL?
    @State private var showHeroCircuitMap = false
    @State private var heroCircuitPathPoints: [(CGFloat, CGFloat)]?

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
                        ZStack(alignment: .top) {
                                heroGradientSection(safeAreaTop: safeTop)
                            VStack(spacing: 0) {
                                    topBar(safeAreaTop: safeTop)
                                grandPrixInfoBar
                                    HStack(alignment: .center, spacing: 16) {
                                        if showHeroCircuitMap { heroLeftContentView }
                                        Spacer(minLength: 12)
                                        if showHeroCircuitMap { heroCircuitMapView }
                            }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, -70)
                        }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(height: Self.heroBlockHeight)
                        .clipped()

                        VStack(spacing: Self.sectionSpacing) {
                            upcomingRacesSection
                                .padding(.top, -50)
                                .zIndex(1)
                            teamsChampionshipSection
                                .zIndex(1)
                            sessionScheduleSection
                            fiaNewsSection
                        }
                        .padding(.horizontal, 0)
                    }
                    .padding(.bottom, 24)
                }
                .ignoresSafeArea(edges: .top)
            }
            }
            .sheet(item: $newsURLInApp) { wrap in
                SafariView(url: wrap.url) { newsURLInApp = nil }
            }
            .navigationBarHidden(true)
            .task { await loader.load() }
            .task {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showHeroCircuitMap = true
                }
            }
            .task {
                // Лайв только через официальный F1 (livetiming.formula1.com SignalR). OpenF1 для карты не используем.
                while !Task.isCancelled {
                    if await MainActor.run(body: { loader.meeting }) != nil {
                        loader.startLiveStreamIfNeeded()
                    } else {
                        loader.stopLiveStream()
                    }
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }

    private var raceInfoSection: some View {
        VStack(spacing: 8) {
            if loader.isLoading && !loader.isLoaded {
                ProgressView()
                    .padding(.vertical, 24)
            } else if let m = loader.meeting {
                TrackMapView(circuitInfo: loader.circuitInfo, imageURL: m.circuitImage)
                    .frame(maxWidth: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Text(circuitDisplayName(m))
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    flagView(countryCode: m.countryCode)
                    Text(m.meetingName)
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Text(m.location)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
                    .foregroundStyle(.secondary)
                if let start = m.parsedDateStart, let end = m.parsedDateEnd {
                    Text(formattedDateRange(start: start, end: end))
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                        .foregroundStyle(.secondary)
                }
                if let start = m.parsedDateStart, start > Date() {
                    countdownView(to: start, showLabel: true, meetingName: m.meetingName)
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                }
            } else {
                Text("No upcoming race")
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }

    /// Hero: градиент в цветах флага страны гран-при (country_code / country_name из API).
    private func heroGradientSection(safeAreaTop: CGFloat) -> some View {
        let code = heroGradientCountryCode()
        let colors = flagColorsForGradient(countryCode: code)
        return ZStack {
            FluidGradient(blobs: colors, blur: 0.75, speed: 0.6)
            BottomDarkeningOverlay()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func topBar(safeAreaTop: CGFloat) -> some View {
        HStack(spacing: 5) {
            Text("Podium")
                .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                .foregroundStyle(.white)
            Image(String.AppImage.f1_logo)
                .resizable()
                .scaledToFit()
                .frame(height: 20)
            Spacer()
            Text(headerDate)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 15))
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
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 4) {
                heroFlagView(countryCode: countryCode)
                Text(countryName)
                    .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 15))
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

    private var heroLeftContentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let m = loader.meeting {
                    Text(m.meetingName)
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                        .foregroundStyle(.white)
                    .lineLimit(2)
                if let str = heroGpDateString(m) {
                    Text(str)
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
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

    private func heroDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// "6 Mar - 8 Mar, 2026" если несколько дней, иначе "8 Mar, 2026"
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
            let c = countdownComponents(from: context.date, to: date)
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
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(name)
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 11))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    /// Следующее по времени событие: дата и название для таймера и подписи "until Race" / "until Quali".
    private func heroNextEventTarget() -> (Date, String)? {
        let now = Date()
        let tz = loader.meeting.flatMap { eventTimeZone(from: $0.gmtOffset) } ?? .current
        for s in loader.nextMeetingSessions {
            guard let start = parseSessionDate(s.dateStart, eventTimeZone: tz), start > now else { continue }
            return (start, sessionShortName(s.sessionName))
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
                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 8))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(minWidth: 26)
        .padding(.vertical, 4)
        .padding(.horizontal, 3)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var heroCircuitMapView: some View {
        Group {
            if let m = loader.meeting {
                let size = CGSize(width: 208, height: 130)
                ZStack(alignment: .topLeading) {
                    TrackMapView(
                        circuitInfo: loader.circuitInfo,
                        imageURL: m.circuitImage,
                        localTrackImageName: nil,
                        compact: true,
                        compactSize: size,
                        strokeColor: .white,
                        cardBackground: .clear
                    )
                    .frame(width: size.width, height: size.height)
                    LiveCircuitDotsOverlay(
                        circuitInfo: loader.circuitInfo,
                        locations: loader.liveLocations,
                        positionProgressByDriver: loader.livePositionProgressByDriver,
                        coordinatesByDriver: loader.liveCoordinatesByDriver,
                        size: size
                    )
                    .zIndex(1)
                    .id("\(loader.liveCoordinatesByDriver.count)-\(loader.livePositionProgressByDriver.count)" + (loader.circuitInfo != nil ? "c" : "n"))
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.trailing, 20)
        .allowsHitTesting(false)
    }

    private var upcomingRacesSection: some View {
        SeasonSectionView()
    }

    /// Teams — те же карточки что и в Season (горизонтальный скролл, 260×104), внутри название команды
    private var teamsChampionshipSection: some View {
        let teams = loader.championshipTeamsTop
        guard !teams.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            sectionBlock(title: "Teams") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(Array(teams.enumerated()), id: \.offset) { index, row in
                            if index > 0 {
                                Spacer().frame(width: 12)
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(width: 32, height: 2)
                                Spacer().frame(width: 12)
                            }
                            teamCard(position: row.position, name: row.name, points: row.points)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        )
    }

    private func teamCard(position: Int, name: String, points: Int) -> some View {
        let logoName = teamLogoImageName(name)
        let bolidName = teamBolidImageName(name)
        let tint = teamColor(for: name)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanTeamName(name))
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(points) pts")
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .fill(tint)
                    if let logoName = logoName {
                        Image(logoName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(width: Self.seasonCardWidth, height: Self.seasonCardHeight)
        .background(
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color.black, tint], startPoint: .top, endPoint: .bottom)
                Image(String.AppImage.background_element)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .opacity(0.3)
                if let bolidName = bolidName {
                    HStack(alignment: .bottom, spacing: 0) {
                        Image(bolidName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .scaleEffect(1.0, anchor: .bottom)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.teamCardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Self.teamCardCornerRadius).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
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
        return cardBackground
    }

    private func teamBolidImageName(_ teamName: String) -> String? {
        let lower = teamName.lowercased()
        if lower.contains("red bull") && !lower.contains("racing bulls") { return String.AppImage.rebullracing_bolid }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return String.AppImage.racingbulls_bolid }
        if lower.contains("ferrari") { return String.AppImage.ferrari_bolid }
        if lower.contains("mclaren") { return String.AppImage.mclaren_bolid }
        if lower.contains("mercedes") { return String.AppImage.mercedes_bolid }
        if lower.contains("aston martin") { return String.AppImage.astonmartin_bolid }
        if lower.contains("alpine") { return String.AppImage.alpine_bolid }
        if lower.contains("williams") { return String.AppImage.williams_bolid }
        if lower.contains("haas") { return String.AppImage.haas_bolid }
        if lower.contains("sauber") || lower.contains("kick") { return String.AppImage.haas_bolid }
        if lower.contains("audi") { return String.AppImage.audi_bolid }
        if lower.contains("cadillac") { return String.AppImage.cadillac_bolid }
        return nil
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

    private func sessionShortName(_ name: String) -> String {
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

    private func formatSessionDate(_ dateString: String?) -> String {
        guard let s = dateString, !s.isEmpty else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: s)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: s)
        }
        if date == nil {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            date = f.date(from: s)
        }
        guard let date = date else { return s }
        let out = DateFormatter()
        out.dateFormat = "EEE d MMM, HH:mm"
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: date)
    }

    private func sessionDateParts(_ dateString: String?) -> (date: String, time: String) {
        guard let s = dateString, !s.isEmpty else { return ("—", "—") }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: s)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: s)
        }
        if date == nil {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            date = f.date(from: s)
        }
        guard let date = date else { return (s, "") }
        let outDate = DateFormatter()
        outDate.locale = Locale(identifier: "en_US_POSIX")
        outDate.timeZone = .current
        outDate.dateFormat = "EEE d MMM"
        let outTime = DateFormatter()
        outTime.locale = Locale(identifier: "en_US_POSIX")
        outTime.timeZone = .current
        outTime.dateFormat = "HH:mm"
        return (outDate.string(from: date), outTime.string(from: date))
    }

    private func sectionHeader(title: String, systemImage: String?, subtitle: String?) -> some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.AppColors.accentBlue)
                    .frame(width: 28, height: 28)
                    .background(Color.AppColors.accentBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 20))
                if let subtitle {
                    Text(subtitle)
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - FIA News
    private var fiaNewsSection: some View {
        guard !loader.fiaNews.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            sectionBlock(title: "FIA News") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(loader.fiaNews.prefix(10)) { item in
                        FIANewsCard(item: item) { url in
                            newsURLInApp = IdentifiableURL(url: url)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        )
    }

    private var upcomingMeetings: [OpenF1Meeting] {
        loader.seasonMeetings.filter { !$0.meetingName.lowercased().contains("test") }
    }

    private static let seasonCardWidth: CGFloat = 260
    private static let seasonCardHeight: CGFloat = 104
    private static let teamCardCornerRadius: CGFloat = 24
    private static let heroBlockHeight: CGFloat = 500
    /// Отступ между блоками Season, Teams, Sessions.
    private static let sectionSpacing: CGFloat = 30
    private static let sectionTitleToContentHeight: CGFloat = 0

    /// Секция: заголовок и контент без зазора (слиплены).
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                .padding(.horizontal, 20)
            content()
                .padding(.top, 16)
        }
    }

    private var cardBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardBorder: Color {
        Color(.separator).opacity(0.8)
    }

    private func countdownView(to date: Date, showLabel: Bool = false, meetingName: String? = nil) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let c = countdownComponents(from: context.date, to: date)
            VStack(spacing: showLabel ? 4 : 8) {
            HStack(spacing: 8) {
                countdownBlock(value: c.days, label: "days")
                countdownBlock(value: c.hours, label: "hrs")
                countdownBlock(value: c.minutes, label: "min")
                countdownBlock(value: c.seconds, label: "sec")
                }
                if showLabel, let meetingName = meetingName {
                    HStack(spacing: 2) {
                        Text("until ")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(meetingName)
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private func countdownBlock(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 28)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func countdownComponents(from now: Date, to target: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let delta = max(0, target.timeIntervalSince(now))
        let d = Int(delta) / 86400
        let h = (Int(delta) % 86400) / 3600
        let m = (Int(delta) % 3600) / 60
        let s = Int(delta) % 60
        return (d, h, m, s)
    }

    private func formattedDateRange(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM"
        let startStr = f.string(from: start)
        let endStr = f.string(from: end)
        let year = Calendar.current.component(.year, from: start)
        return "\(startStr) – \(endStr), \(year)"
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

    /// 2-буквенный код страны, в которой проходит гран-при — для градиента в цветах флага.
    /// Порядок: город (location) → country_name → country_code, чтобы всегда получить страну ГП.
    private func heroGradientCountryCode() -> String {
        guard let m = loader.meeting else { return "" }
        let loc = m.location.trimmingCharacters(in: .whitespaces).uppercased()
        let cityToCountry: [String: String] = [
            "MELBOURNE": "AU", "SYDNEY": "AU", "SAKHIR": "BH", "JEDDAH": "SA", "SHANGHAI": "CN",
            "SUZUKA": "JP", "MIAMI": "US", "AUSTIN": "US", "LAS VEGAS": "US", "BARCELONA": "ES",
            "MADRID": "ES", "MONTREAL": "CA", "MONACO": "MC", "MONTE CARLO": "MC", "SPIELBERG": "AT",
            "SILVERSTONE": "GB", "SPA": "BE", "BUDAPEST": "HU", "ZANDVOORT": "NL", "MONZA": "IT",
            "BAKU": "AZ", "SINGAPORE": "SG", "MEXICO CITY": "MX", "MEXICO": "MX", "SÃO PAULO": "BR", "INTERLAGOS": "BR",
            "LUSAIL": "QA", "ABU DHABI": "AE", "YAS ISLAND": "AE", "IMOLA": "IT"
        ]
        for (city, code) in cityToCountry where loc.contains(city) && Self.flagGradientColors[code] != nil { return code }
        func toCode(_ raw: String) -> String {
            let s = raw.trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? "" : alpha2CountryCode(s)
        }
        let fromName = toCode(m.countryName)
        if !fromName.isEmpty, Self.flagGradientColors[fromName] != nil { return fromName }
        let fromCode = toCode(m.countryCode)
        if !fromCode.isEmpty, Self.flagGradientColors[fromCode] != nil { return fromCode }
        if !fromName.isEmpty { return fromName }
        if !fromCode.isEmpty { return fromCode }
        for (city, code) in cityToCountry where loc.contains(city) { return code }
        return ""
    }

    /// Цвета флага страны для анимированного градиента — по 2-буквенному коду (AU, BH, SA, …).
    private func flagColorsForGradient(countryCode: String) -> [UIColor] {
        let key = alpha2CountryCode(countryCode)
        guard !key.isEmpty else { return Self.flagGradientColors["default"] ?? [UIColor(white: 0.12, alpha: 1), UIColor(white: 0.06, alpha: 1)] }
        if let colors = Self.flagGradientColors[key] { return colors }
        return Self.flagGradientColors["default"] ?? [UIColor(white: 0.12, alpha: 1), UIColor(white: 0.06, alpha: 1)]
    }

    /// Цвета флагов для градиента: 1–3 цвета, белый не используем. По официальным/принятым hex кодам.
    private static let flagGradientColors: [String: [UIColor]] = [
        "default": [UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1), UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)],
        "AU": [UIColor(red: 0.004, green: 0.129, blue: 0.412, alpha: 1), UIColor(red: 0.894, green: 0, blue: 0.169, alpha: 1)],   // флаг: blue #012169, red #E4002B
        "BH": [UIColor(red: 0.808, green: 0.067, blue: 0.149, alpha: 1)],                                                       // red #CE1126
        "SA": [UIColor(red: 0.086, green: 0.365, blue: 0.192, alpha: 1)],                                                        // green #165D31
        "CN": [UIColor(red: 0.871, green: 0.161, blue: 0.063, alpha: 1), UIColor(red: 1, green: 0.871, blue: 0, alpha: 1)],      // red #DE2910, yellow #FFDE00
        "JP": [UIColor(red: 0.737, green: 0, blue: 0.176, alpha: 1)],                                                           // red #BC002D
        "US": [UIColor(red: 0.749, green: 0.039, blue: 0.188, alpha: 1), UIColor(red: 0, green: 0.157, blue: 0.408, alpha: 1)],  // red #BF0A30, blue #002868
        "ES": [UIColor(red: 0.776, green: 0.043, blue: 0.118, alpha: 1), UIColor(red: 1, green: 0.769, blue: 0, alpha: 1)],     // red #C60B1E, yellow #FFC400
        "CA": [UIColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1)],                                                         // red maple leaf
        "GB": [UIColor(red: 0.004, green: 0.129, blue: 0.412, alpha: 1), UIColor(red: 0.784, green: 0.063, blue: 0.18, alpha: 1)], // blue #012169, red #C8102E
        "AT": [UIColor(red: 0.929, green: 0.161, blue: 0.224, alpha: 1)],                                                        // red #ED2939
        "FR": [UIColor(red: 0, green: 0.138, blue: 0.584, alpha: 1), UIColor(red: 0.929, green: 0.161, blue: 0.224, alpha: 1)],  // blue #002395, red #ED2939
        "HU": [UIColor(red: 0.278, green: 0.439, blue: 0.314, alpha: 1), UIColor(red: 0.808, green: 0.161, blue: 0.224, alpha: 1)], // green, red
        "BE": [UIColor(red: 1, green: 0.804, blue: 0, alpha: 1), UIColor(red: 0.784, green: 0.063, blue: 0.18, alpha: 1)],       // yellow #FFCD00, red #C8102E
        "IT": [UIColor(red: 0, green: 0.549, blue: 0.271, alpha: 1), UIColor(red: 0.804, green: 0.129, blue: 0.165, alpha: 1)],  // green #008C45, red #CD212A
        "SG": [UIColor(red: 0.929, green: 0.161, blue: 0.224, alpha: 1)],                                                       // red #ED2939
        "MX": [UIColor(red: 0, green: 0.408, blue: 0.278, alpha: 1), UIColor(red: 0.808, green: 0.067, blue: 0.149, alpha: 1)],  // green #006847, red #CE1126
        "BR": [UIColor(red: 0, green: 0.592, blue: 0.224, alpha: 1), UIColor(red: 1, green: 0.867, blue: 0, alpha: 1)],          // green #009739, yellow #FEDD00
        "AE": [UIColor(red: 0, green: 0.451, blue: 0.184, alpha: 1), UIColor(red: 0, green: 0, blue: 0, alpha: 1)],             // green #00732F, black
        "QA": [UIColor(red: 0.541, green: 0.082, blue: 0.22, alpha: 1)],                                                       // maroon #8A1538
        "AZ": [UIColor(red: 0, green: 0.663, blue: 0.808, alpha: 1), UIColor(red: 0.929, green: 0.161, blue: 0.224, alpha: 1)],   // blue #00A9CE, red
        "MC": [UIColor(red: 0.808, green: 0.067, blue: 0.149, alpha: 1)],                                                     // red #CE1126
        "NL": [UIColor(red: 1, green: 0.4, blue: 0, alpha: 1), UIColor(red: 0.129, green: 0.275, blue: 0.545, alpha: 1)],        // orange #FF6600, blue #21468B
    ]

    /// Флаг: картинка из Assets/Flags (пропорции без обрезки), иначе эмодзи.
    private func flagView(countryCode: String) -> some View {
        let alpha2 = alpha2CountryCode(countryCode)
        if let name = String.AppImage.flagImage(countryCode: alpha2) {
            return AnyView(
                Image(name)
                .resizable()
                .scaledToFit()
                    .aspectRatio(3/2, contentMode: .fit)
                    .frame(width: 28, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            )
        }
        return AnyView(Text(flagEmoji(countryCode: countryCode)))
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

// MARK: - News card & in-app Safari
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct FIANewsCard: View {
    let item: FIANewsItem
    var onOpenURL: (URL) -> Void
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }
    private var cardBorder: Color { Color(.separator).opacity(0.8) }

    var body: some View {
        Button {
            guard let url = URL(string: item.link) else { return }
            onOpenURL(url)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Color(.tertiarySystemFill)
                        case .empty:
                            Color(.tertiarySystemFill)
                                .overlay { ProgressView() }
                        @unknown default:
                            Color(.tertiarySystemFill)
                        }
                    }
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(fiaNewsDateString(item.pubDate))
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                        .foregroundStyle(.secondary)
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func fiaNewsDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }
}

/// Кружки позиций машин на карте трассы при прямой трансляции.
/// Приоритет: 1) coordinatesByDriver (реальные X,Y из Position.z по подписке), 2) positionProgressByDriver, 3) locations (OpenF1).
/// Координаты как в CircuitPathShape: x = u*w, y = (1-v)*h.
private struct LiveCircuitDotsOverlay: View {
    var circuitInfo: CircuitInfo?
    var locations: [OpenF1Location]
    var positionProgressByDriver: [Int: CGFloat] = [:]
    /// Реальное расположение из F1 Position.z (подписка): координаты на трассе.
    var coordinatesByDriver: [Int: F1LiveCoordinate] = [:]
    var size: CGSize

    private static let dotRadius: CGFloat = 10

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
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 2))
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
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 2))
                }
            } else if !positionProgressByDriver.isEmpty {
                let sorted = positionProgressByDriver.sorted { $0.key < $1.key }
                let n = CGFloat(max(1, sorted.count))
                for (index, _) in sorted.enumerated() {
                    let sx = (CGFloat(index) + 0.5) / n * w
                    let sy = h - Self.dotRadius
                    let rect = CGRect(x: sx - Self.dotRadius, y: sy - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.red))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 2))
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
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), style: StrokeStyle(lineWidth: 2))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .id(coordinatesByDriver.count.description + positionProgressByDriver.map { "\($0.key):\($0.value)" }.joined(separator: "|"))
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss()
        }
    }
}
