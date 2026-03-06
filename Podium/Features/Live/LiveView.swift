//
//  LiveView.swift
//  Podium
//
//  Пример гонки со всеми данными Open F1 API: сессия, пилоты, интервалы, позиции, круги, чемпионат, пит-стопы.
//

import SwiftUI

struct LiveView: View {
    @State private var session: OpenF1Session?
    @State private var meeting: OpenF1Meeting?
    @State private var drivers: [OpenF1Driver] = []
    @State private var intervals: [OpenF1Interval] = []
    @State private var positions: [OpenF1Position] = []
    @State private var laps: [OpenF1Lap] = []
    @State private var championshipDrivers: [OpenF1ChampionshipDriver] = []
    @State private var championshipTeams: [OpenF1ChampionshipTeam] = []
    @State private var pitStops: [OpenF1Pit] = []
    @State private var circuitInfo: CircuitInfo?
    @State private var liveLocations: [Int: (x: Int, y: Int)] = [:]
    @State private var liveLocationsVersion: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// Кэш standings, чтобы не пересчитывать при каждой перерисовке.
    @State private var cachedLiveStandings: [(driverNumber: Int, position: Int, gap: GapToLeader?)] = []
    /// Кэш по драйверам для строк таблицы.
    @State private var driverLookupCache: [Int: (name: String, teamDisplay: String, tint: Color, logoName: String?)] = [:]
    /// Показывать карту только после задержки, чтобы экран и таблица отрисовались сразу (карта тяжёлая).
    @State private var showTrackMap = false

    private let client = OpenF1Client.shared

    /// Массив для карты: номер, позиция, цвет команды, название — из standings и drivers.
    private var liveTrackDrivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)] {
        cachedLiveStandings.map { item in
            let team = drivers.first(where: { $0.driverNumber == item.driverNumber })?.teamName ?? ""
            return (item.driverNumber, item.position, teamColor(team), team)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Загрузка…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text(err)
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 16))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Повторить") {
                            loadData()
                        }
                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            if let s = session, let m = meeting {
                                sessionCard(session: s, meeting: m)
                            }
                            if showTrackMap, !cachedLiveStandings.isEmpty, !liveTrackDrivers.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Live")
                                        .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 15))
                                        .foregroundStyle(.secondary)
                                    LiveTrackView(
                                        circuitInfo: circuitInfo,
                                        drivers: liveTrackDrivers,
                                        locations: liveLocations,
                                        progress: 0,
                                        locationsVersion: liveLocationsVersion,
                                        animationDate: nil
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    if !liveLocations.isEmpty {
                                        Text("Позиции с трассы из Open F1 API (обновление каждые 2 сек)")
                                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 11))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            if !cachedLiveStandings.isEmpty {
                                LiveStandingsSectionView(
                                    cachedLiveStandings: cachedLiveStandings,
                                    driverLookup: driverLookupCache,
                                    locationsVersion: liveLocationsVersion
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.large)
            .task { loadData() }
            .refreshable { loadData() }
            .task(id: session?.sessionKey) {
                guard let sk = session?.sessionKey else { return }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                while !Task.isCancelled {
                    await fetchLiveLocations(sessionKey: sk)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            .task(id: cachedLiveStandings.isEmpty) {
                guard !cachedLiveStandings.isEmpty else { return }
                try? await Task.sleep(nanoseconds: 400_000_000)
                showTrackMap = true
            }
        }
    }

    /// Open F1 Location API: позиции машин (x, y) на трассе, ~3.7 Hz. Опрос раз в 2 сек — кружки двигаются по данным API.
    private func fetchLiveLocations(sessionKey: Int) async {
        do {
            let list = try await client.location(sessionKey: sessionKey)
            let latest = Dictionary(
                list.sorted { $0.date > $1.date }.map { ($0.driverNumber, ($0.x, $0.y)) },
                uniquingKeysWith: { first, _ in first }
            )
            await MainActor.run {
                liveLocations = latest
                liveLocationsVersion += 1
            }
        } catch { }
    }

    private func sessionCard(session s: OpenF1Session, meeting m: OpenF1Meeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(m.meetingName)
                .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 20))
            Text(s.sessionName)
                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
            if let start = s.dateStart {
                Text(formatDate(start))
                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
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
        if lower.contains("sauber") || lower.contains("kick") || lower.contains("stake") { return String.AppImage.haas_logo }
        if lower.contains("audi") { return String.AppImage.audi_logo }
        if lower.contains("cadillac") { return String.AppImage.cadillac_logo }
        return nil
    }

    private var positionsSection: some View {
        let latest = Dictionary(
            positions.sorted { $0.date > $1.date }.compactMap { p -> (Int, Int)? in
                parseISO8601(p.date).map { _ in (p.driverNumber, p.position) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let sorted = latest.sorted { $0.value < $1.value }
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Positions (snapshot)")
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.offset) { idx, pair in
                    if idx > 0 { Divider().padding(.leading, 52) }
                    let driver = drivers.first(where: { $0.driverNumber == pair.key })
                    HStack(spacing: 12) {
                        Text("\(pair.value)")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                            .frame(width: 24, alignment: .center)
                        teamCircle(teamName: driver?.teamName ?? "")
                        Text(driver?.fullName ?? "\(pair.key)")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 15))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var driversSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Drivers")
            VStack(spacing: 0) {
                ForEach(drivers.sorted(by: { $0.driverNumber < $1.driverNumber })) { d in
                    HStack(spacing: 12) {
                        Text("\(d.driverNumber)")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 14))
                            .frame(width: 24, alignment: .center)
                        teamCircle(teamName: d.teamName ?? "")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.fullName)
                                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 15))
                            if let t = d.teamName, !t.isEmpty {
                                Text(cleanTeamName(t))
                                    .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    if d.driverNumber != drivers.sorted(by: { $0.driverNumber < $1.driverNumber }).last?.driverNumber {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var lapsSection: some View {
        let sample = laps.sorted { ($0.lapNumber ?? 0) > ($1.lapNumber ?? 0) }.prefix(20)
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Laps (sample)")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(sample.enumerated()), id: \.offset) { _, lap in
                    let driver = lap.driverNumber.flatMap { num in drivers.first(where: { $0.driverNumber == num }) }
                    HStack(spacing: 12) {
                        if let num = lap.driverNumber {
                            Text("\(num)")
                                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 12))
                                .frame(width: 20, alignment: .center)
                        }
                        Text(driver?.fullName ?? "—")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 14))
                            .lineLimit(1)
                        if let lapNum = lap.lapNumber {
                            Text("Lap \(lapNum)")
                                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let dur = lap.effectiveLapDuration {
                            Text(formatLapTime(dur))
                                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var championshipDriversSection: some View {
        let driverNames = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.fullName) })
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Championship (drivers)")
            VStack(spacing: 0) {
                ForEach(Array(championshipDrivers.sorted(by: { $0.positionCurrent < $1.positionCurrent }).enumerated()), id: \.element.driverNumber) { idx, cd in
                    if idx > 0 { Divider().padding(.leading, 52) }
                    HStack(spacing: 12) {
                        Text("\(cd.positionCurrent)")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                            .frame(width: 24, alignment: .center)
                        Text(driverNames[cd.driverNumber] ?? "\(cd.driverNumber)")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 15))
                        Spacer()
                        Text("\(cd.pointsCurrent) pts")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 14))
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var championshipTeamsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Championship (teams)")
            VStack(spacing: 0) {
                ForEach(Array(championshipTeams.sorted(by: { $0.positionCurrent < $1.positionCurrent }).enumerated()), id: \.element.teamName) { idx, ct in
                    if idx > 0 { Divider().padding(.leading, 40) }
                    HStack(spacing: 12) {
                        Text("\(ct.positionCurrent)")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 16))
                            .frame(width: 24, alignment: .center)
                        Text(cleanTeamName(ct.teamName))
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 15))
                        Spacer()
                        Text("\(ct.pointsCurrent) pts")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 14))
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var pitStopsSection: some View {
        let driverNames = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.fullName) })
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Pit stops")
            VStack(spacing: 0) {
                ForEach(Array(pitStops.sorted { ($0.lapNumber ?? 0) < ($1.lapNumber ?? 0) }.enumerated()), id: \.offset) { idx, pit in
                    if idx > 0 { Divider().padding(.leading, 52) }
                    HStack(spacing: 12) {
                        Text("\(pit.driverNumber)")
                            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 14))
                            .frame(width: 24, alignment: .center)
                        Text(driverNames[pit.driverNumber] ?? "\(pit.driverNumber)")
                            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 14))
                        if let lap = pit.lapNumber {
                            Text("Lap \(lap)")
                                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let d = pit.pitDuration {
                            Text(String(format: "%.2fs", d))
                                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 15))
            .foregroundStyle(.secondary)
    }

    private func teamCircle(teamName: String) -> some View {
        Circle()
            .fill(teamColor(teamName))
            .frame(width: 28, height: 28)
    }

    private func teamColor(_ name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("red bull") && !lower.contains("racing bulls") { return Color.AppColors.redBull }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return Color.AppColors.racingBulls }
        if lower.contains("ferrari") { return Color.AppColors.ferrari }
        if lower.contains("mclaren") { return Color.AppColors.mclaren }
        if lower.contains("mercedes") { return Color.AppColors.mercedes }
        if lower.contains("aston martin") { return Color.AppColors.astonMartin }
        if lower.contains("alpine") { return Color.AppColors.alpine }
        if lower.contains("williams") { return Color.AppColors.williams }
        if lower.contains("haas") { return Color.AppColors.haas }
        if lower.contains("sauber") || lower.contains("kick") || lower.contains("stake") { return Color.AppColors.haas }
        return Color(.tertiaryLabel)
    }

    private func cleanTeamName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("red bull") && !lower.contains("racing bulls") { return "Red Bull" }
        if lower.contains("racing bulls") || lower == "rb" { return "Racing Bulls" }
        if lower.contains("ferrari") { return "Ferrari" }
        if lower.contains("mclaren") { return "McLaren" }
        if lower.contains("mercedes") { return "Mercedes" }
        if lower.contains("aston martin") { return "Aston Martin" }
        if lower.contains("alpine") { return "Alpine" }
        if lower.contains("williams") { return "Williams" }
        if lower.contains("haas") { return "Haas" }
        if lower.contains("sauber") || lower.contains("kick") || lower.contains("stake") { return "Stake" }
        return name
    }

    private func buildDriverLookup() -> [Int: (name: String, teamDisplay: String, tint: Color, logoName: String?)] {
        drivers.reduce(into: [:]) { r, d in
            let team = d.teamName ?? ""
            r[d.driverNumber] = (
                d.fullName ?? d.broadcastName ?? "\(d.driverNumber)",
                cleanTeamName(team.isEmpty ? "—" : team),
                teamColor(team),
                teamLogoImageName(team)
            )
        }
    }

    private func formatDate(_ iso: String) -> String {
        guard let d = parseISO8601(iso) else { return iso }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: d)
    }

    private func formatLapTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = seconds - Double(m * 60)
        if m > 0 {
            return String(format: "%d:%06.3f", m, s)
        }
        return String(format: "%06.3f", s)
    }

    private func parseISO8601(_ s: String) -> Date? {
        Self.parseISO8601Static(s)
    }

    private static func parseISO8601Static(_ s: String) -> Date? {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        let formatters = formats.map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }
        for f in formatters {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    /// Пауза между запросами, чтобы не получать 429 (Too Many Requests).
    private static let requestDelay: UInt64 = 400_000_000 // 0.4 сек

    /// Вычисляет standings в фоне (без блокировки main thread).
    private static func computeLiveStandings(
        positions: [OpenF1Position],
        intervals: [OpenF1Interval],
        driverNumbers: Set<Int>,
        parse: (String) -> Date?
    ) -> [(driverNumber: Int, position: Int, gap: GapToLeader?)] {
        let latestPositions = Dictionary(
            positions
                .sorted { $0.date > $1.date }
                .compactMap { p -> (Int, Int)? in
                    guard parse(p.date) != nil else { return nil }
                    return (p.driverNumber, p.position)
                },
            uniquingKeysWith: { first, _ in first }
        )
        let latestIntervals = Dictionary(
            intervals
                .sorted { $0.date > $1.date }
                .compactMap { i -> (Int, OpenF1Interval)? in
                    guard parse(i.date) != nil else { return nil }
                    return (i.driverNumber, i)
                },
            uniquingKeysWith: { first, _ in first }
        )
        let byPosition = driverNumbers
            .compactMap { num -> (Int, Int)? in
                guard let pos = latestPositions[num] else { return nil }
                return (num, pos)
            }
            .sorted { $0.1 < $1.1 }
        if !byPosition.isEmpty {
            return byPosition.map { num, pos in
                (num, pos, latestIntervals[num]?.gapToLeader ?? latestIntervals[num]?.interval)
            }
        }
        let byGap = driverNumbers.compactMap { num -> (Int, GapToLeader?)? in
            let iv = latestIntervals[num]
            let gap = iv?.gapToLeader ?? iv?.interval
            return (num, gap)
        }.sorted { a, b in
            let sa = a.1?.secondsValue ?? .infinity
            let sb = b.1?.secondsValue ?? .infinity
            if sa != sb { return sa < sb }
            return (a.1?.display ?? "") < (b.1?.display ?? "")
        }
        return byGap.enumerated().map { idx, pair in (pair.0, idx + 1, pair.1) }
    }

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let sessions = try await client.sessions(year: 2025)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                var raceSession = sessions.first(where: { $0.sessionName == "Race" || $0.sessionType?.lowercased().contains("race") == true })
                    ?? sessions.first
                if raceSession == nil {
                    let sessions24 = try await client.sessions(year: 2024)
                    try await Task.sleep(nanoseconds: Self.requestDelay)
                    raceSession = sessions24.first(where: { $0.sessionName == "Race" }) ?? sessions24.first
                }
                guard let session = raceSession else {
                    await MainActor.run {
                        errorMessage = "Нет сессий для примера"
                        isLoading = false
                    }
                    return
                }
                let year = session.year ?? 2025
                let meetings = try await client.meetings(year: year)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                let meeting = meetings.first(where: { $0.meetingKey == session.meetingKey })
                let sk = session.sessionKey

                let driversResult = try await client.drivers(sessionKey: sk)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                let intervalsResult = try await client.intervals(sessionKey: sk)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                let positionsResult = try await client.positions(sessionKey: sk)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                let lapsResult = try await client.laps(sessionKey: sk)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                let champDriversResult = try await client.championshipDrivers(sessionKey: sk)
                try await Task.sleep(nanoseconds: Self.requestDelay)
                let champTeamsResult = try await client.championshipTeams(sessionKey: sk)
                try await Task.sleep(nanoseconds: Self.requestDelay)

                var pitResult: [OpenF1Pit] = []
                do {
                    pitResult = try await client.pit(sessionKey: sk)
                } catch {
                    pitResult = []
                }

                var circuit: CircuitInfo? = nil
                if let urlString = meeting?.circuitInfoUrl, !urlString.isEmpty {
                    do {
                        circuit = try await client.circuitInfo(urlString: urlString)
                    } catch {
                        circuit = nil
                    }
                    try? await Task.sleep(nanoseconds: Self.requestDelay)
                }

                let standings = Self.computeLiveStandings(
                    positions: positionsResult,
                    intervals: intervalsResult,
                    driverNumbers: Set(driversResult.map(\.driverNumber)),
                    parse: Self.parseISO8601Static
                )

                await MainActor.run {
                    self.session = session
                    self.meeting = meeting
                    self.drivers = driversResult
                    self.intervals = intervalsResult
                    self.positions = positionsResult
                    self.laps = lapsResult
                    self.championshipDrivers = champDriversResult
                    self.championshipTeams = champTeamsResult
                    self.pitStops = pitResult
                    self.circuitInfo = circuit
                    self.driverLookupCache = self.buildDriverLookup()
                    self.isLoading = false
                }
                // Отдельный кадр для standings, чтобы не грузить один массивный рендер
                await MainActor.run {
                    self.cachedLiveStandings = standings
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// Вся секция со Switch и таблицей в отдельном View: при нажатии Switch перерисовывается
// только этот View, а не весь экран Live — лаг пропадает.
private struct LiveStandingsSectionView: View {
    let cachedLiveStandings: [(driverNumber: Int, position: Int, gap: GapToLeader?)]
    let driverLookup: [Int: (name: String, teamDisplay: String, tint: Color, logoName: String?)]
    let locationsVersion: Int

    @State private var simulationEnabled = false
    @State private var displayedStandings: [(driverNumber: Int, position: Int, gap: GapToLeader?)] = []
    @State private var previousPositionByDriver: [Int: Int] = [:]

    private var orderToShow: [(driverNumber: Int, position: Int, gap: GapToLeader?)] {
        if simulationEnabled, !displayedStandings.isEmpty { return displayedStandings }
        return cachedLiveStandings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Live standings")
                    .font(Font.custom(FontWeight.nastonRegular.rawValue, size: 22))
                Spacer()
                Toggle(isOn: $simulationEnabled) {
                    Text("Симуляция")
                        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
                }
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .padding(.bottom, 10)

            LiveStandingsTableContent(
                order: orderToShow,
                driverLookup: driverLookup,
                previousPositionByDriver: previousPositionByDriver
            )
        }
        .onChange(of: simulationEnabled) { _, _ in
            displayedStandings = cachedLiveStandings
            updatePreviousPositions(from: cachedLiveStandings)
        }
        .onChange(of: locationsVersion) {
            if !simulationEnabled { displayedStandings = cachedLiveStandings }
        }
        .task(id: cachedLiveStandings.isEmpty ? 0 : 1) {
            if !cachedLiveStandings.isEmpty, displayedStandings.isEmpty {
                displayedStandings = cachedLiveStandings
                updatePreviousPositions(from: cachedLiveStandings)
            }
        }
        .task(id: simulationEnabled) {
            guard simulationEnabled, !displayedStandings.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard simulationEnabled else { return }
                runSimulationTick()
            }
        }
    }

    private func updatePreviousPositions(from order: [(driverNumber: Int, position: Int, gap: GapToLeader?)]) {
        var next: [Int: Int] = [:]
        for (idx, row) in order.enumerated() { next[row.driverNumber] = idx + 1 }
        previousPositionByDriver = next
    }

    private func runSimulationTick() {
        guard simulationEnabled, displayedStandings.count >= 2 else { return }
        var list = displayedStandings
        let i = Int.random(in: 0..<(list.count - 1))
        list.swapAt(i, i + 1)
        let newOrder = list.enumerated().map { idx, row in (row.driverNumber, idx + 1, row.gap) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            displayedStandings = newOrder
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            updatePreviousPositions(from: newOrder)
        }
    }
}

// Отдельный View для таблицы: при переключении Switch пересобираются только заголовок и контейнер,
// сами строки берут данные из lookup (O(1)), плюс LazyVStack — только видимые строки.
private struct LiveStandingsTableContent: View {
    let order: [(driverNumber: Int, position: Int, gap: GapToLeader?)]
    let driverLookup: [Int: (name: String, teamDisplay: String, tint: Color, logoName: String?)]
    let previousPositionByDriver: [Int: Int]

    var body: some View {
        VStack(spacing: 0) {
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
            }
            .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 11))
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)

            LazyVStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element.driverNumber) { idx, item in
                    row(currentPosition: idx + 1, driverNumber: item.driverNumber, gap: item.gap)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: order.map(\.driverNumber))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(currentPosition: Int, driverNumber: Int, gap: GapToLeader?) -> some View {
        let info = driverLookup[driverNumber] ?? ("\(driverNumber)", "—", Color(.tertiaryLabel), nil)
        let prevPos = previousPositionByDriver[driverNumber]
        let arrow: (color: Color, icon: String)? = {
            guard let p = prevPos, p != currentPosition else { return nil }
            return currentPosition < p ? (Color.green, "arrow.up") : (Color.red, "arrow.down")
        }()
        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("\(currentPosition)")
                    .frame(width: 28, alignment: .leading)
                if let a = arrow {
                    Image(systemName: a.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(a.color)
                        .offset(x: -10)
                }
            }
            .frame(width: 32, alignment: .leading)
            HStack(spacing: 6) {
                Rectangle()
                    .fill(info.tint)
                    .frame(width: 2)
                Text(info.name)
                    .lineLimit(1)
            }
            .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let logoName = info.logoName {
                    ZStack {
                        Circle()
                            .fill(info.tint)
                            .frame(width: 24, height: 24)
                        Image(logoName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    }
                    .frame(width: 90, alignment: .leading)
                } else {
                    Text(info.teamDisplay)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                }
            }
            Text(gap?.display ?? "—")
                .lineLimit(1)
                .frame(width: 56, alignment: .trailing)
        }
        .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 13))
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

#Preview {
    LiveView()
}
