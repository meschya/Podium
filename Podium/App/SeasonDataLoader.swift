import Foundation
import SwiftUI
import Combine
import CoreGraphics
import UIKit

/// Обновление точек на карте без SwiftUI — позиции и цвета команд.
protocol LiveDotsViewUpdating: AnyObject {
    func setPositions(_ positions: [CGPoint], colors: [UIColor])
}

/// Состояние только для лайв-карты. Подписывается только карта.
final class LiveMapState: ObservableObject {
    /// Прогресс 0...1 по трассе (официальный F1 тайминг / Position.z fallback).
    @Published var positionProgressByDriver: [Int: CGFloat] = [:]
    /// Реальные координаты машин по Position.z (официальный тайминг).
    @Published var coordinatesByDriver: [Int: F1LiveCoordinate] = [:]
    /// Сырые OpenF1 location (последние известные точки) — источник для SwiftUI карт (Home + Live).
    @Published var locations: [OpenF1Location] = []
    /// Версия locations: инкремент при каждом апдейте, чтобы карты могли анимировать изменения.
    @Published var locationsVersion: Int = 0
    /// Топ‑3 в лайве по позиции на трассе (из OpenF1 location): (позиция 1–3, номер, имя, команда для цвета).
    @Published var top3LiveDrivers: [(position: Int, driverNumber: Int, name: String, teamName: String)] = []
}

/// Буфер позиций MQTT в акторе — приём с любого потока, отдача снэпшота без лагов main thread.
private actor LiveLocationBuffer {
    private var byDriver: [Int: OpenF1Location] = [:]
    func add(_ loc: OpenF1Location) { byDriver[loc.driverNumber] = loc }
    func snapshot() -> [OpenF1Location] { Array(byDriver.values) }
    func reset() { byDriver = [:] }
}

@MainActor
final class SeasonDataLoader: ObservableObject {
    @Published var meeting: OpenF1Meeting?
    @Published var circuitInfo: CircuitInfo?
    @Published var circuitInfoByMeetingKey: [Int: CircuitInfo] = [:]
    @Published var seasonMeetings: [OpenF1Meeting] = []
    @Published var championshipTop: [(position: Int, name: String, points: Int)] = []
    @Published var championshipTeamsTop: [(position: Int, name: String, points: Int)] = []
    @Published var nextMeetingSessions: [OpenF1Session] = []
    /// Состояние лайв-карты (обновляется часто; подписывается только карта).
    let liveMapState = LiveMapState()
    /// Прямое обновление точек без @Published — ноль перерисовок SwiftUI от лайва.
    weak var liveDotsView: (any LiveDotsViewUpdating)?
    private var liveDotsCircuitInfo: CircuitInfo?
    private var liveDotsSize: CGSize?
    /// Цвет кружка по номеру гонщика (загружаем при старте стрима по session_key).
    private var liveDriverColors: [Int: UIColor] = [:]
    /// Имя и команда гонщика по номеру (для топ‑3 в Hero).
    private var liveDriverNames: [Int: String] = [:]
    private var liveDriverTeamNames: [Int: String] = [:]
    /// Стрим включён, когда герой на главном экране или открыт таб Live.
    @Published var isHeroSectionVisible = true
    @Published var isLiveViewVisible = false
    /// Буфер MQTT в акторе — не грузим main thread каждым сообщением.
    private let liveLocationBuffer = LiveLocationBuffer()
    private var lastLiveStreamSessionKey: Int?
    private var liveStreamStarted = false
    /// Таск: раз в 1 с снэпшот → считаем точки → обновляем только UIKit, без SwiftUI.
    private var liveFlushTask: Task<Void, Never>?
    /// Опрос позиций в гонке для топ‑3 лидеров (REST OpenF1).
    private var livePositionsPollTask: Task<Void, Never>?
    @Published var fiaNews: [FIANewsItem] = []
    @Published var isLoaded = false
    @Published var isLoading = false
    /// Кэш результатов по meetingKey (для повторного показа без загрузки).
    @Published var resultsByMeetingKey: [Int: [RaceResultRow]] = [:]
    /// Результаты, которые сейчас показываются в UI (только для последнего запрошенного meeting).
    @Published var displayedResults: [RaceResultRow] = []
    /// Для какой встречи показаны displayedResults (nil = не показывать таблицу).
    @Published var displayedResultsMeetingKey: Int?
    /// Для какой встречи идёт загрузка.
    @Published var loadingMeetingKey: Int?
    private var loadResultsTask: Task<Void, Never>?
    private var lastRequestedMeetingKey: Int?

    /// Year chosen in Seasons tab picker; meetings/circuits for that year.
    @Published var selectedSeasonYear: Int = Calendar.current.component(.year, from: Date())
    @Published var meetingsForSelectedYear: [OpenF1Meeting] = []
    @Published var circuitInfoForSelectedYear: [Int: CircuitInfo] = [:]
    @Published var isLoadingYear = false

    /// Календарь сезона из f1api.dev (для таба Seasons — карточки и round совпадают с API).
    @Published var f1apiRacesForSelectedYear: [F1APIRaceInfo] = []

    /// Years available in picker: от текущего года до 2014 (текущий выбран по умолчанию).
    static var availableSeasonYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((2014...current).reversed())
    }

    /// Загрузка календаря сезона из f1api + Open F1 (трассы для карт на карточках).
    func loadSeasonFromF1API(_ year: Int) async {
        await MainActor.run { isLoadingYear = true }
        defer { Task { @MainActor in self.isLoadingYear = false } }
        do {
            let races = try await F1APIClient.shared.seasonCalendar(year: year)
            await MainActor.run {
                selectedSeasonYear = year
                f1apiRacesForSelectedYear = races
            }
            let client = OpenF1Client.shared
            let meetings = (try? await client.meetings(year: year)) ?? []
            let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
            await MainActor.run { meetingsForSelectedYear = raceMeetings }
            var loaded: [Int: CircuitInfo] = [:]
            await withTaskGroup(of: (Int, CircuitInfo?).self) { group in
                for m in raceMeetings {
                    guard let urlString = m.circuitInfoUrl else { continue }
                    let key = m.meetingKey
                    group.addTask {
                        let info: CircuitInfo? = try? await client.circuitInfo(urlString: urlString)
                        return (key, info.flatMap { $0.x.isEmpty || $0.y.isEmpty ? nil : $0 })
                    }
                }
                for await (key, info) in group {
                    if let info = info { loaded[key] = info }
                }
            }
            await MainActor.run { circuitInfoForSelectedYear = loaded }
        } catch {
            await MainActor.run { f1apiRacesForSelectedYear = [] }
        }
    }

    func loadMeetingsForYear(_ year: Int) async {
        await MainActor.run { isLoadingYear = true }
        defer { Task { @MainActor in self.isLoadingYear = false } }
        let client = OpenF1Client.shared
        do {
            let meetings = try await client.meetings(year: year)
            let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
            await MainActor.run {
                selectedSeasonYear = year
                meetingsForSelectedYear = raceMeetings
            }
            var loaded: [Int: CircuitInfo] = [:]
            await withTaskGroup(of: (Int, CircuitInfo?).self) { group in
                for m in raceMeetings {
                    guard let urlString = m.circuitInfoUrl else { continue }
                    let key = m.meetingKey
                    group.addTask {
                        let info: CircuitInfo? = try? await client.circuitInfo(urlString: urlString)
                        return (key, info.flatMap { $0.x.isEmpty || $0.y.isEmpty ? nil : $0 })
                    }
                }
                for await (key, info) in group {
                    if let info = info { loaded[key] = info }
                }
            }
            await MainActor.run { circuitInfoForSelectedYear = loaded }
        } catch {
            await MainActor.run {
                meetingsForSelectedYear = []
                circuitInfoForSelectedYear = [:]
            }
        }
    }

    /// Результаты из f1api по year + round (для карточек из f1api календаря). Ключ для кэша = round.
    func loadRaceResults(year: Int, round: Int) {
        loadResultsTask?.cancel()
        let key = round
        lastRequestedMeetingKey = key
        loadingMeetingKey = key
        loadResultsTask = Task {
            guard (1950...2030).contains(year), round > 0 else {
                await setResults([], for: key)
                return
            }
            do {
                let results = try await F1APIClient.shared.raceResults(year: year, round: round)
                if Task.isCancelled { return }
                await setResults(results.isEmpty ? [] : results, for: key)
            } catch {
                if Task.isCancelled { return }
                await setResults([], for: key)
            }
        }
    }

    /// Результаты только из f1api.dev. Round — из календаря API по дате/уик-энду; при неудаче — roundHint (индекс+1).
    func loadRaceResults(meetingKey: Int, year: Int, raceDate: String, roundHint: Int? = nil) {
        loadResultsTask?.cancel()
        let key = meetingKey
        lastRequestedMeetingKey = key
        loadingMeetingKey = key
        loadResultsTask = Task {
            guard (1950...2030).contains(year) else {
                await setResults([], for: key)
                return
            }
            var round: Int?
            do {
                round = try await F1APIClient.shared.roundForRaceDate(year: year, raceDate: raceDate)
            } catch { }
            if round == nil, let hint = roundHint, hint > 0 { round = hint }
            guard let r = round, r > 0 else {
                await setResults([], for: key)
                return
            }
            do {
                let results = try await F1APIClient.shared.raceResults(year: year, round: r)
                if Task.isCancelled { return }
                await setResults(results.isEmpty ? [] : results, for: key)
            } catch {
                if Task.isCancelled { return }
                await setResults([], for: key)
            }
        }
    }

    private func setResults(_ results: [RaceResultRow], for meetingKey: Int) async {
        await MainActor.run {
            var copy = resultsByMeetingKey
            copy[meetingKey] = results
            resultsByMeetingKey = copy
            if self.lastRequestedMeetingKey == meetingKey {
                self.displayedResults = results
                self.displayedResultsMeetingKey = meetingKey
            }
            if self.loadingMeetingKey == meetingKey { self.loadingMeetingKey = nil }
        }
    }

    func loadRaceResults(meetingKey: Int) {
        let year = selectedSeasonYear
        let meetings = !meetingsForSelectedYear.isEmpty ? meetingsForSelectedYear : seasonMeetings
        let byDate = meetings.sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }
        guard let meeting = byDate.first(where: { $0.meetingKey == meetingKey }), (1950...2030).contains(year) else {
            loadResultsTask?.cancel()
            lastRequestedMeetingKey = meetingKey
            loadingMeetingKey = meetingKey
            loadResultsTask = Task { await setResults([], for: meetingKey) }
            return
        }
        let raceDate: String = !meeting.dateStart.isEmpty
            ? String(meeting.dateStart.prefix(10))
            : (meeting.parsedDateStart.map { d in
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                return f.string(from: d)
            } ?? "")
        let idx = byDate.firstIndex(where: { $0.meetingKey == meetingKey }).map { $0 + 1 }
        loadRaceResults(meetingKey: meetingKey, year: year, raceDate: raceDate, roundHint: idx)
    }

    func clearSelectedResults() {
        loadResultsTask?.cancel()
        loadResultsTask = nil
        loadingMeetingKey = nil
        lastRequestedMeetingKey = nil
        displayedResults = []
        displayedResultsMeetingKey = nil
    }

    /// Таймаут загрузки: если за это время не дошли до bootstrap — показываем главный экран.
    private let loadTimeout: Duration = .seconds(10)

    /// Вся сеть и обработка — в фоне (Task.detached), на main только быстрые обновления состояния (по доке Apple).
    func load() async {
        guard !isLoaded, !isLoading else { return }
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        Task { @MainActor in
            try? await Task.sleep(for: loadTimeout)
            if !self.isLoaded { self.isLoaded = true }
        }

        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let client = OpenF1Client.shared
            let year = Calendar.current.component(.year, from: Date())
            let now = Date()
            do {
                let meetings = try await client.meetings(year: year)
                let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
                let sortedByDate = raceMeetings.sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }
                await MainActor.run { self.seasonMeetings = sortedByDate }

                let currentOrNext = sortedByDate.first { m in
                    let start = m.parsedDateStart ?? .distantPast
                    let end = m.parsedDateEnd ?? .distantFuture
                    return (start <= now && now <= end) || start >= now
                }
                let first = currentOrNext ?? sortedByDate.first
                if let first = first {
                    await MainActor.run { self.meeting = first }
                    // Параллельно: circuitInfo и сессии — MQTT стартует сразу, не ждём circuitInfo.
                    let circuitTask = first.circuitInfoUrl.map { url in Task { try? await client.circuitInfo(urlString: url) } }
                    let sessionsTask = Task { try? await client.sessions(meetingKey: first.meetingKey) }
                    let info: CircuitInfo? = if let t = circuitTask { await t.value } else { nil }
                    let nextSessions = (await sessionsTask.value) ?? []
                    await MainActor.run {
                        if let info = info { self.circuitInfo = info }
                        self.nextMeetingSessions = nextSessions.sorted { ($0.dateStart ?? "") < ($1.dateStart ?? "") }
                        self.startLiveStreamIfNeeded()
                        self.isLoaded = true
                    }
                } else {
                    await MainActor.run { self.isLoaded = true }
                }

                var loadedCircuits: [Int: CircuitInfo] = [:]
                await withTaskGroup(of: (Int, CircuitInfo?).self) { group in
                    for m in raceMeetings {
                        guard m.circuitInfoUrl != nil else { continue }
                        let key = m.meetingKey
                        let meetingUrl = m.circuitInfoUrl
                        group.addTask {
                            guard let url = meetingUrl else { return (key, nil) }
                            let info: CircuitInfo? = try? await client.circuitInfo(urlString: url)
                            return (key, info.flatMap { $0.x.isEmpty || $0.y.isEmpty ? nil : $0 })
                        }
                    }
                    for await (key, info) in group {
                        if let info = info { loadedCircuits[key] = info }
                    }
                }
                await MainActor.run { self.circuitInfoByMeetingKey = loadedCircuits }

                var teamsLoadedFromChampionship = false
                let lastCompleted = sortedByDate.last { m in (m.parsedDateEnd ?? .distantFuture) < now }
                if let last = lastCompleted {
                    let sessions = try await client.sessions(meetingKey: last.meetingKey)
                    let raceSession = sessions.first { s in
                        s.sessionName == "Race" || (s.sessionType?.lowercased().contains("race") == true)
                    }
                    if let race = raceSession {
                        let standings = try await client.championshipDrivers(sessionKey: race.sessionKey)
                        let drivers = try await client.drivers(sessionKey: race.sessionKey)
                        let names = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.fullName) })
                        let top = standings
                            .sorted { $0.positionCurrent < $1.positionCurrent }
                            .prefix(5)
                            .map { row in (position: row.positionCurrent, name: names[row.driverNumber] ?? "\(row.driverNumber)", points: row.pointsCurrent) }
                        await MainActor.run { self.championshipTop = top }
                        let teams = try? await client.championshipTeams(sessionKey: race.sessionKey)
                        let teamsAll = (teams ?? [])
                            .sorted { $0.positionCurrent < $1.positionCurrent }
                            .map { (position: $0.positionCurrent, name: $0.teamName, points: $0.pointsCurrent) }
                        await MainActor.run {
                            self.championshipTeamsTop = teamsAll
                            self.syncConstructorWidgetFromStandings()
                        }
                        teamsLoadedFromChampionship = !teamsAll.isEmpty
                    }
                }
                if !teamsLoadedFromChampionship {
                    func teamsFromDrivers(_ drivers: [OpenF1Driver]) -> [(position: Int, name: String, points: Int)] {
                        var seen: Set<String> = []
                        let names = drivers.compactMap { d -> String? in
                            guard let name = d.teamName, !name.isEmpty, seen.insert(name).inserted else { return nil }
                            return name
                        }
                        return names.enumerated().map { (position: $0.offset + 1, name: $0.element, points: 0) }
                    }
                    var teamsList: [(position: Int, name: String, points: Int)] = []
                    if let driversLatest = try? await client.driversLatest(), !driversLatest.isEmpty {
                        teamsList = teamsFromDrivers(driversLatest)
                    }
                    if teamsList.isEmpty, let firstMeeting = raceMeetings.first {
                        let sessions = (try? await client.sessions(meetingKey: firstMeeting.meetingKey)) ?? []
                        if let firstSession = sessions.sorted(by: { ($0.dateStart ?? "") < ($1.dateStart ?? "") }).first {
                            let drivers = (try? await client.drivers(sessionKey: firstSession.sessionKey)) ?? []
                            teamsList = teamsFromDrivers(drivers)
                        }
                    }
                    if !teamsList.isEmpty {
                        await MainActor.run {
                            self.championshipTeamsTop = teamsList
                            self.syncConstructorWidgetFromStandings()
                        }
                    } else {
                        let fallback = Self.fallbackSeasonTeams(year: year)
                        if !fallback.isEmpty {
                            await MainActor.run {
                                self.championshipTeamsTop = fallback
                                self.syncConstructorWidgetFromStandings()
                            }
                        }
                    }
                }
                if let nextMeeting = first {
                    let sessions = (try? await client.sessions(meetingKey: nextMeeting.meetingKey)) ?? []
                    await MainActor.run { self.nextMeetingSessions = sessions.sorted { ($0.dateStart ?? "") < ($1.dateStart ?? "") } }
                }
                let news = (try? await FIAFeedService.shared.fetchNews()) ?? []
                await MainActor.run { self.fiaNews = news }
            } catch {
                await MainActor.run { self.isLoaded = true }
            }
        }.value
    }

    private nonisolated static func fallbackSeasonTeams(year: Int) -> [(position: Int, name: String, points: Int)] {
        let names = [
            "Red Bull Racing", "Ferrari", "McLaren", "Mercedes", "Aston Martin",
            "Alpine", "Williams", "Racing Bulls", "Haas", "Kick Sauber"
        ]
        return names.enumerated().map { (position: $0.offset + 1, name: $0.element, points: 0) }
    }

    /// Лайв только OpenF1 MQTT. MQTT пишет в актор (не main), UI обновляется по таймеру — без лагов.
    func startLiveStreamIfNeeded() {
        guard !liveStreamStarted else { return }
        liveStreamStarted = true
        let sessionKeyToUse: Int?
        if let current = currentLiveSessionKey() {
            lastLiveStreamSessionKey = current
            sessionKeyToUse = current
            print("[Live] MQTT session=\(current)")
        } else {
            sessionKeyToUse = nil
        }

        // Принимаем все сообщения MQTT — не фильтруем по session_key, чтобы лайв всегда показывал данные.
        OpenF1LiveMQTTService.shared.onLocation = { [weak self] loc in
            guard let self = self else { return }
            Task { await self.liveLocationBuffer.add(loc) }
        }
        Task { await OpenF1LiveMQTTService.shared.connect() }
        let skForColors = sessionKeyToUse ?? nextMeetingSessions.first?.sessionKey
        if let sk = skForColors {
            Task { await loadLiveDriverColors(sessionKey: sk) }
        }

        // Топ‑3 лидеров — из API позиций (реальный порядок в гонке), не по прогрессу на трассе.
        startLivePositionsPoll(sessionKey: sessionKeyToUse ?? skForColors)

        // Часть 1: locations каждые 8 ms. Часть 2: кэш circuitInfo/view обновляем каждые 48 ms; кружки на карте — каждые 8 ms по кэшу.
        var cachedInfo: CircuitInfo?
        var cachedSize: CGSize?
        var cachedView: (any LiveDotsViewUpdating)?
        var cachedPointsByDriver: [Int: CGPoint] = [:]
        var tick = 0
        liveFlushTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                let snapshot = await self.liveLocationBuffer.snapshot()

                // Всегда пушим locations и версию — карта обновляется часто.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.liveMapState.locations = snapshot
                    self.liveMapState.locationsVersion &+= 1
                    self.objectWillChange.send()
                }

                let doHeavy = (tick % 6 == 0)
                tick += 1

                if doHeavy {
                    let ctx = await MainActor.run {
                        (self.liveDotsCircuitInfo, self.liveDotsSize, self.liveDotsView, self.circuitInfo)
                    }
                    cachedInfo = ctx.0 ?? ctx.3
                    cachedSize = ctx.1 ?? (ctx.2 != nil ? CGSize(width: 400, height: 250) : nil)
                    cachedView = ctx.2
                }

                // Кружки на карте обновляем каждые 8 ms (по кэшу circuitInfo/view), чтобы не ждать 48 ms.
                if let info = cachedInfo, let size = cachedSize, let view = cachedView, !snapshot.isEmpty {
                    let latestByDriver = Self.latestByDriver(from: snapshot)
                    let driverNumbers = latestByDriver.keys.sorted()
                    for driverNum in driverNumbers {
                        guard let (x, y) = latestByDriver[driverNum] else { continue }
                        cachedPointsByDriver[driverNum] = Self.computeOnePoint(trackX: x, trackY: y, circuitInfo: info, size: size)
                    }
                    cachedPointsByDriver = cachedPointsByDriver.filter { latestByDriver[$0.key] != nil }
                    let points = driverNumbers.compactMap { cachedPointsByDriver[$0] }
                    let driverNumbersCopy = driverNumbers
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let colors = driverNumbersCopy.map { self.liveDriverColors[$0] ?? .gray }
                        view.setPositions(points, colors: colors)
                    }
                }

                try? await Task.sleep(nanoseconds: 8_333_333)
            }
        }
    }

    /// Последняя позиция по каждому гонщику из снэпшота.
    private nonisolated static func latestByDriver(from snapshot: [OpenF1Location]) -> [Int: (Int, Int)] {
        Dictionary(grouping: snapshot) { $0.driverNumber }
            .compactMapValues { locs in
                guard let last = locs.max(by: { $0.date < $1.date }) else { return nil }
                return (last.x, last.y)
            }
    }

    /// Топ‑3 номера гонщиков по прогрессу вдоль трассы (лидер первым). Координаты как в OpenF1/circuit_info.
    private nonisolated static func top3DriverNumbersByProgress(snapshot: [OpenF1Location], circuitInfo: CircuitInfo) -> [Int] {
        let latest = latestByDriver(from: snapshot)
        let withProgress: [(Int, CGFloat)] = latest.compactMap { (driverNum, xy) in
            let p = circuitInfo.progressAlongTrack(trackX: xy.0, trackY: xy.1)
            return (driverNum, p)
        }
        return withProgress.sorted { $0.1 > $1.1 }.prefix(3).map(\.0)
    }

    /// Позиция на карте по координатам OpenF1 (trackX, trackY). Проекция на трассу. Координаты в одной системе с circuit_info (OpenF1 doc).
    private nonisolated static func computeOnePoint(trackX: Int, trackY: Int, circuitInfo: CircuitInfo, size: CGSize) -> CGPoint {
        let (u, v) = circuitInfo.normalizedUVProjected(trackX: trackX, trackY: trackY)
        let uClamp = min(1, max(0, CGFloat(u)))
        let vClamp = min(1, max(0, CGFloat(v)))
        return CGPoint(x: uClamp * size.width, y: (1 - vClamp) * size.height)
    }

    /// Полный расчёт всех точек (для первого кадра или fallback).
    private nonisolated static func computeDotsPoints(snapshot: [OpenF1Location], circuitInfo: CircuitInfo, size: CGSize) -> [CGPoint] {
        let latest = latestByDriver(from: snapshot)
        return latest.keys.sorted().compactMap { driverNum in
            guard let (x, y) = latest[driverNum] else { return nil }
            return computeOnePoint(trackX: x, trackY: y, circuitInfo: circuitInfo, size: size)
        }
    }

    private func loadLiveDriverColors(sessionKey: Int) async {
        let drivers = (try? await OpenF1Client.shared.drivers(sessionKey: sessionKey)) ?? []
        await MainActor.run {
            for d in drivers {
                let team = d.teamName ?? ""
                liveDriverColors[d.driverNumber] = Self.uiColor(forTeam: team)
                liveDriverNames[d.driverNumber] = d.fullName ?? d.broadcastName ?? "#\(d.driverNumber)"
                liveDriverTeamNames[d.driverNumber] = team
            }
        }
    }

    private static func uiColor(forTeam teamName: String) -> UIColor {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return UIColor(red: 20/255, green: 41/255, blue: 72/255, alpha: 1) }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return UIColor(red: 0/255, green: 56/255, blue: 194/255, alpha: 1) }
        if lower.contains("ferrari") { return UIColor(red: 92/255, green: 0/255, blue: 18/255, alpha: 1) }
        if lower.contains("mclaren") { return UIColor(red: 128/255, green: 64/255, blue: 0/255, alpha: 1) }
        if lower.contains("mercedes") { return UIColor(red: 6/255, green: 126/255, blue: 106/255, alpha: 1) }
        if lower.contains("aston martin") { return UIColor(red: 15/255, green: 67/255, blue: 49/255, alpha: 1) }
        if lower.contains("alpine") { return UIColor(red: 0/255, green: 78/255, blue: 112/255, alpha: 1) }
        if lower.contains("williams") { return UIColor(red: 8/255, green: 33/255, blue: 69/255, alpha: 1) }
        if lower.contains("haas") { return UIColor(red: 102/255, green: 113/255, blue: 117/255, alpha: 1) }
        if lower.contains("sauber") || lower.contains("kick") || lower.contains("stake") { return UIColor(red: 102/255, green: 113/255, blue: 117/255, alpha: 1) }
        if lower.contains("audi") { return UIColor(red: 117/255, green: 21/255, blue: 0/255, alpha: 1) }
        if lower.contains("cadillac") { return UIColor(red: 88/255, green: 88/255, blue: 91/255, alpha: 1) }
        return .gray
    }

    private func syncConstructorWidgetFromStandings() {
        guard let leader = championshipTeamsTop.min(by: { $0.position < $1.position }) else { return }
        PodiumWidgetDataSync.pushConstructorLeader(
            position: leader.position,
            teamName: leader.name,
            points: leader.points,
            accentColor: WidgetTeamAccent.color(for: leader.name)
        )
    }

    /// Обновить виджет конструкторов из уже загруженного топа (после открытия приложения).
    func refreshConstructorWidgetFromStandings() {
        syncConstructorWidgetFromStandings()
    }

    func registerLiveDotsView(_ view: some LiveDotsViewUpdating, circuitInfo: CircuitInfo?, size: CGSize) {
        liveDotsView = view
        liveDotsCircuitInfo = circuitInfo
        liveDotsSize = size
    }

    /// Топ‑3 лидеров из API позиций (реальный порядок в гонке). Опрос раз в ~1.5 с.
    private func startLivePositionsPoll(sessionKey initialSk: Int?) {
        livePositionsPollTask?.cancel()
        livePositionsPollTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                let sk = await MainActor.run {
                    self.currentLiveSessionKey() ?? self.lastLiveStreamSessionKey ?? self.nextMeetingSessions.first?.sessionKey ?? initialSk
                }
                if let sk = sk {
                    let list = (try? await OpenF1Client.shared.positions(sessionKey: sk)) ?? []
                    // Последняя запись по каждому гонщику (по date), затем сортировка по position — это реальный порядок в гонке.
                    let byDriver: [Int: OpenF1Position] = list.reduce(into: [:]) { acc, p in
                        if acc[p.driverNumber] == nil || (p.date > acc[p.driverNumber]!.date) { acc[p.driverNumber] = p }
                    }
                    let sorted = byDriver.values.sorted { $0.position < $1.position }
                    let top3 = Array(sorted.prefix(3))
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        let names = self.liveDriverNames
                        let teams = self.liveDriverTeamNames
                        self.liveMapState.top3LiveDrivers = top3.enumerated().map { idx, p in
                            (idx + 1, p.driverNumber, names[p.driverNumber] ?? "#\(p.driverNumber)", teams[p.driverNumber] ?? "")
                        }
                        self.objectWillChange.send()
                    }
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func stopLiveStream() {
        liveStreamStarted = false
        liveFlushTask?.cancel()
        liveFlushTask = nil
        livePositionsPollTask?.cancel()
        livePositionsPollTask = nil
        OpenF1LiveMQTTService.shared.onLocation = nil
        OpenF1LiveMQTTService.shared.disconnect()
        Task { await liveLocationBuffer.reset() }
        liveDotsView?.setPositions([], colors: [])
        liveDriverColors = [:]
        liveDriverNames = [:]
        liveDriverTeamNames = [:]
        liveMapState.coordinatesByDriver = [:]
        liveMapState.positionProgressByDriver = [:]
        liveMapState.locations = []
        liveMapState.top3LiveDrivers = []
    }

    /// session_key сессии, которая идёт сейчас (now между date_start и date_end), или nil.
    func currentLiveSessionKey() -> Int? {
        let now = Date()
        for s in nextMeetingSessions {
            guard let start = parseSessionDate(s.dateStart),
                  let end = parseSessionDate(s.dateEnd) else { continue }
            if now >= start && now <= end {
                return s.sessionKey
            }
        }
        return nil
    }

    /// Для логов: текущий session_key или nil, число сессий у next meeting.
    func liveDebugInfo() -> (sessionKey: Int?, sessionsCount: Int) {
        (currentLiveSessionKey(), nextMeetingSessions.count)
    }

    private func parseSessionDate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: String(s.prefix(19)))
    }
}
