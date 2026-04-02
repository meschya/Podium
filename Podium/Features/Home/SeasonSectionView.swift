//
//  SeasonSectionView.swift
//  Podium
//
//  Reusable "Season YYYY" block with horizontal race cards (used on Home and Seasons tab).
//

import SwiftUI

struct SeasonSectionView: View {
    @EnvironmentObject var loader: SeasonDataLoader
    /// When non-nil, cards are tappable and show red border when selected (e.g. on Seasons tab); also uses year picker data.
    var selection: Binding<Int?>? = nil

    private var displayYear: Int {
        selection != nil ? loader.selectedSeasonYear : Calendar.current.component(.year, from: Date())
    }

    /// Гонки из Jolpica/F1APIClient: календарь должен соответствовать `displayYear`.
    private var useF1APICards: Bool {
        guard !loader.f1apiRacesForSelectedYear.isEmpty else { return false }
        guard loader.f1apiSeasonYearLoaded == displayYear else { return false }
        if selection != nil { return loader.selectedSeasonYear == displayYear }
        return true
    }

    private var meetingsForDisplay: [OpenF1Meeting] {
        let list = selection != nil ? loader.meetingsForSelectedYear : loader.seasonMeetings
        let filtered = list.filter { !$0.meetingName.lowercased().contains("test") }
        return filtered.sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }
    }

    private var f1apiRacesForDisplay: [F1APIRaceInfo] {
        loader.f1apiRacesForSelectedYear.sorted {
            let d1 = $0.schedule?.race?.date ?? ""
            let d2 = $1.schedule?.race?.date ?? ""
            if d1 != d2 { return d1 < d2 }
            return $0.round < $1.round
        }
    }

    /// На Home с Jolpica — в приоритете `circuitInfoByMeetingKey` из bootstrap (все трассы сезона по meetingKey);
    /// иначе карты после `loadSeasonForYear` часто пустые/не совпадают, и карточки рисуются «не тем» кругом.
    private var circuitInfoMap: [Int: CircuitInfo] {
        if useF1APICards && selection == nil {
            return loader.circuitInfoByMeetingKey.isEmpty ? loader.circuitInfoForSelectedYear : loader.circuitInfoByMeetingKey
        }
        if selection != nil || useF1APICards {
            return loader.circuitInfoForSelectedYear
        }
        return loader.circuitInfoByMeetingKey
    }

    private static let liquidGlassCornerRadius: CGFloat = 24

    var body: some View {
        let isSeasonsTab = selection != nil
        let showingF1API = useF1APICards
        let listEmpty = isSeasonsTab
            ? (loader.f1apiRacesForSelectedYear.isEmpty && !loader.isLoadingYear)
            : (meetingsForDisplay.isEmpty && !useF1APICards && !loader.isLoadingYear)
        if listEmpty && !isSeasonsTab {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if isSeasonsTab {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Season \(displayYear)")
                            .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                        Picker("", selection: yearBinding) {
                            ForEach(SeasonDataLoader.availableSeasonYears, id: \.self) { y in
                                Text("\(y)").tag(y)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .foregroundStyle(.white)
                        .tint(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 0)
                } else {
                    Text("Season \(displayYear)")
                        .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 0)
                        .lineLimit(1)
                }
                if (isSeasonsTab || useF1APICards) && loader.f1apiRacesForSelectedYear.isEmpty {
                    if loader.isLoadingYear {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 20)
                    } else {
                        Text("No races")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 14))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 20)
                    }
                } else if showingF1API {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .center, spacing: 0) {
                            ForEach(Array(f1apiRacesForDisplay.enumerated()), id: \.element.round) { index, race in
                                if index > 0 {
                                    Spacer().frame(width: 12)
                                    Rectangle()
                                        .fill(Color(.separator))
                                        .frame(width: 32, height: 2)
                                    Spacer().frame(width: 12)
                                }
                                if let selection = selection {
                                    Button {
                                        if selection.wrappedValue == race.round {
                                            selection.wrappedValue = nil
                                        } else {
                                            loader.loadRaceResults(year: displayYear, round: race.round)
                                            selection.wrappedValue = race.round
                                        }
                                    } label: {
                                        f1apiRaceCard(race, meetings: meetingsForDisplay, circuitInfoMap: circuitInfoMap)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius)
                                            .stroke(selection.wrappedValue == race.round ? Color.red : Color.clear, lineWidth: 3)
                                    )
                                } else {
                                    f1apiRaceCard(race, meetings: meetingsForDisplay, circuitInfoMap: circuitInfoMap)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                    }
                } else if !meetingsForDisplay.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .center, spacing: 0) {
                            ForEach(Array(meetingsForDisplay.enumerated()), id: \.element.meetingKey) { index, m in
                                if index > 0 {
                                    Spacer().frame(width: 12)
                                    Rectangle()
                                        .fill(Color(.separator))
                                        .frame(width: 32, height: 2)
                                    Spacer().frame(width: 12)
                                }
                                if let selection = selection {
                                    Button {
                                        if selection.wrappedValue == m.meetingKey {
                                            selection.wrappedValue = nil
                                        } else {
                                            let raceDate: String = !m.dateStart.isEmpty
                                                ? String(m.dateStart.prefix(10))
                                                : (m.parsedDateStart.map { d in
                                                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                                                    return f.string(from: d)
                                                } ?? "")
                                            loader.loadRaceResults(meetingKey: m.meetingKey, year: displayYear, raceDate: raceDate, roundHint: index + 1)
                                            selection.wrappedValue = m.meetingKey
                                        }
                                    } label: {
                                        upcomingRaceCard(m, circuitInfoMap: circuitInfoMap)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selection.wrappedValue == m.meetingKey ? Color.red : Color.clear, lineWidth: 3)
                                    )
                                } else {
                                    upcomingRaceCard(m, circuitInfoMap: circuitInfoMap)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .task(id: "\(selection != nil)_\(displayYear)") {
                let year = selection != nil ? loader.selectedSeasonYear : Calendar.current.component(.year, from: Date())
                await loader.loadSeasonFromF1API(year, bindSelectedYear: selection != nil)
            }
        }
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { loader.selectedSeasonYear },
            set: { new in
                loader.selectedSeasonYear = new
                selection?.wrappedValue = nil
                loader.clearSelectedResults()
                Task { await loader.loadSeasonFromF1API(new) }
            }
        )
    }

    private static let seasonCardWidth: CGFloat = 260
    private static let seasonCardHeight: CGFloat = 104

    private static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func f1apiRaceCard(_ race: F1APIRaceInfo, meetings: [OpenF1Meeting], circuitInfoMap: [Int: CircuitInfo]) -> some View {
        let dateStr: String = {
            guard let raw = race.schedule?.race?.date, !raw.isEmpty else { return "—" }
            guard let d = Self.inputDateFormatter.date(from: String(raw.prefix(10))) else { return raw }
            return Self.displayDateFormatter.string(from: d)
        }()
        let country = race.circuit?.country ?? ""
        let location = [race.circuit?.city, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let matched = matchingMeeting(for: race, from: meetings)
        let info = matched.flatMap { circuitInfoMap[$0.meetingKey] }
        let imageURL = matched?.circuitImage
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    flagView(countryCode: countryCode(from: country))
                    Text(cleanGrandPrixName(race.raceName) ?? "Round \(race.round)")
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if !location.isEmpty {
                    Text(location)
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(dateStr)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.vertical, 10)

            VStack(spacing: 4) {
                TrackMapView(
                    circuitInfo: info,
                    imageURL: imageURL,
                    localTrackImageName: String.AppImage.trackImage(circuitName: race.circuit?.circuitName),
                    compact: true,
                    compactSize: CGSize(width: 72, height: 44),
                    strokeColor: .white,
                    cardBackground: .clear
                )
                Text(race.circuit?.circuitName ?? "")
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 84)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
        }
        .frame(width: Self.seasonCardWidth, height: Self.seasonCardHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .drawingGroup()
    }

    /// Сопоставление гонки f1api с встречей Open F1 по дате (один уик-энд).
    private func matchingMeeting(for race: F1APIRaceInfo, from meetings: [OpenF1Meeting]) -> OpenF1Meeting? {
        guard let raceDateStr = race.schedule?.race?.date, !raceDateStr.isEmpty else { return nil }
        guard let raceDate = Self.inputDateFormatter.date(from: String(raceDateStr.prefix(10))) else { return nil }
        return meetings.first { m in
            guard let start = m.parsedDateStart else { return false }
            let days = Calendar.current.dateComponents([.day], from: start, to: raceDate).day ?? 99
            return abs(days) <= 3
        }
    }

    /// Название ГП без спонсоров и года: "Formula 1 Qatar Airways Australian Grand Prix" → "Australian Grand Prix".
    private func cleanGrandPrixName(_ raw: String?) -> String? {
        guard var s = raw, !s.isEmpty else { return raw }
        if s.hasPrefix("Formula 1 ") { s = String(s.dropFirst("Formula 1 ".count)) }
        if let r = s.range(of: " \\d{4}$", options: .regularExpression) {
            s = String(s[..<r.lowerBound])
        }
        let sponsors = [
            "Louis Vuitton ", "Heineken ", "Aramco ", "Rolex ", "STC ", "Crypto.com ", "CRYPTO.COM ",
            "Dell ", "Lenovo ", "Pirelli ", "AWS ", "MSC Cruises ", "Qatar Airways ", "Singapore Airlines ",
            "Singapore Airlanes ", "Heineken Silver Las Vegas ", "Heineken Las Vegas ", "Heineken Dutch ",
            "Dell Emilia Romagna ", "AWS Gran Premio del Made in Italy e Dell Emilia-Romagna ", "AWS Gran Premio ", "AWS ",
            "MSC Cruises United States ", "MSC Cruises Grande Premio ", "MSC Cruises Gran Premio de Barcelona-Catalunya ", "MSC Cruises ",
            "Pirelli Gran Premio D'Italia ", "Pirelli Gran D'Italia ", "Pirelli ",
            "Aramco Gran Premio de España ", "Aramco ",
            "Qatar Airways British ", "Qatar Airways Austrian ", "Qatar Airways Azerbaijan ", "Qatar Airways ",
            "Lenovo Grand Prix Du Canada ", "Lenovo Grande Premio ", "Lenovo Chinese ", "Lenovo Austrian ", "Lenovo ",
            "Rolex Belgian ", "Rolex ",
            "Gulf Air ", "Tag Heuer ", "Tag Heuer Gran Premio de España ", "Etihad Airways ",
            "Gran Premio de La Ciudad de México "
        ]
        for prefix in sponsors {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)); break }
        }
        if s.contains("Ciudad de México") { s = "Mexican Grand Prix" }
        else if s == "Gran D'Italia" { s = "Italian Grand Prix" }
        else if s == "Grand Prix Du Canada" { s = "Canadian Grand Prix" }
        else if s.hasSuffix(" Gran Premio de España") || s == "Gran Premio de España" { s = "Spanish Grand Prix" }
        else if s.hasSuffix(" Gran Premio de Barcelona-Catalunya") || s == "Gran Premio de Barcelona-Catalunya" { s = "Spanish Grand Prix" }
        else if s == "Grande Premio de Sao Paulo" { s = "Brazilian Grand Prix" }
        else if s.hasPrefix("Gran Premio ") { s = String(s.dropFirst("Gran Premio ".count)) + " Grand Prix" }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func countryCode(from country: String) -> String {
        let lower = country.lowercased()
        let map: [String: String] = [
            "australia": "AU", "bahrain": "BH", "china": "CN", "japan": "JP", "saudi arabia": "SA",
            "united states": "US", "italy": "IT", "monaco": "MC", "spain": "ES", "canada": "CA",
            "austria": "AT", "great britain": "GB", "hungary": "HU", "belgium": "BE",
            "netherlands": "NL", "azerbaijan": "AZ", "singapore": "SG", "mexico": "MX",
            "brazil": "BR", "united arab emirates": "AE", "qatar": "QA"
        ]
        return map[lower] ?? String(country.prefix(2)).uppercased()
    }

    private func upcomingRaceCard(_ m: OpenF1Meeting, circuitInfoMap: [Int: CircuitInfo]) -> some View {
        let startStr: String = {
            guard let start = m.parsedDateStart else { return m.dateStart }
            return Self.displayDateFormatter.string(from: start)
        }()
        let info = circuitInfoMap[m.meetingKey]
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    flagView(countryCode: m.countryCode)
                    Text(m.meetingName)
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(m.location)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                    .foregroundStyle(.secondary)
                Text(startStr)
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.vertical, 10)

            VStack(spacing: 4) {
                TrackMapView(
                    circuitInfo: info,
                    imageURL: m.circuitImage,
                    localTrackImageName: String.AppImage.trackImage(circuitName: circuitDisplayName(m)),
                    compact: true,
                    compactSize: CGSize(width: 72, height: 44),
                    strokeColor: .white,
                    cardBackground: .clear
                )
                Text(circuitDisplayName(m))
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 84)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
        }
        .frame(width: Self.seasonCardWidth, height: Self.seasonCardHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .drawingGroup()
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

    private func alpha2CountryCode(_ code: String) -> String {
        let c = code.uppercased().trimmingCharacters(in: .whitespaces)
        if c.count == 2 { return c }
        let iso3To2: [String: String] = [
            "BHR": "BH", "SAU": "SA", "MCO": "MC", "NLD": "NL", "AUS": "AU", "CHN": "CN", "JPN": "JP",
            "USA": "US", "ESP": "ES", "CAN": "CA", "GBR": "GB", "AUT": "AT", "FRA": "FR",
            "HUN": "HU", "BEL": "BE", "ITA": "IT", "SGP": "SG", "MEX": "MX", "BRA": "BR",
            "ARE": "AE", "QAT": "QA", "AZE": "AZ"
        ]
        return iso3To2[c] ?? String(c.prefix(2))
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
