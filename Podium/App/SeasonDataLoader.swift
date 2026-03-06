import Foundation
import SwiftUI
import Combine

@MainActor
final class SeasonDataLoader: ObservableObject {
    @Published var meeting: OpenF1Meeting?
    @Published var circuitInfo: CircuitInfo?
    @Published var circuitInfoByMeetingKey: [Int: CircuitInfo] = [:]
    @Published var seasonMeetings: [OpenF1Meeting] = []
    @Published var championshipTop: [(position: Int, name: String, points: Int)] = []
    @Published var championshipTeamsTop: [(position: Int, name: String, points: Int)] = []
    @Published var nextMeetingSessions: [OpenF1Session] = []
    /// Позиции машин с API при прямой трансляции (для кружков на карте в герое).
    @Published var liveLocations: [OpenF1Location] = []
    /// Позиции от официального F1 Live Timing (SignalR Position.z): прогресс по кругу 0...1 (fallback).
    @Published var livePositionProgressByDriver: [Int: CGFloat] = [:]
    /// Реальное расположение из Position.z по подписке (X, Y на трассе). Приоритет над progress.
    @Published var liveCoordinatesByDriver: [Int: F1LiveCoordinate] = [:]
    /// Накопление по водителю для MQTT стрима (только для текущей сессии).
    private var liveLocationByDriver: [Int: OpenF1Location] = [:]
    private var lastLiveStreamSessionKey: Int?
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

    /// Таймаут загрузки: если за это время не успели — показываем главный экран.
    private let loadTimeout: Duration = .seconds(25)

    func load() async {
        guard !isLoaded, !isLoading else { return }
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        Task { @MainActor in
            try? await Task.sleep(for: loadTimeout)
            if !self.isLoaded { self.isLoaded = true }
        }

        let client = OpenF1Client.shared
        let year = Calendar.current.component(.year, from: Date())
        let now = Date()
        do {
            let meetings = try await client.meetings(year: year)
            let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
            let sortedByDate = raceMeetings.sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }
            await MainActor.run { seasonMeetings = sortedByDate }

            let now = Date()
            // Текущий уик-энд (now между date_start и date_end) или ближайший предстоящий.
            let currentOrNext = sortedByDate.first { m in
                let start = m.parsedDateStart ?? .distantPast
                let end = m.parsedDateEnd ?? .distantFuture
                return (start <= now && now <= end) || start >= now
            }
            let first = currentOrNext ?? sortedByDate.first
            if let first = first {
                await MainActor.run { meeting = first }
                if let url = first.circuitInfoUrl {
                    let info = try? await client.circuitInfo(urlString: url)
                    await MainActor.run { circuitInfo = info }
                }
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
                    if let info = info {
                        loadedCircuits[key] = info
                    }
                }
            }
            await MainActor.run { circuitInfoByMeetingKey = loadedCircuits }

            var teamsLoadedFromChampionship = false
            let lastCompleted = sortedByDate.last { m in
                (m.parsedDateEnd ?? .distantFuture) < now
            }
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
                        .map { row in
                            (position: row.positionCurrent, name: names[row.driverNumber] ?? "\(row.driverNumber)", points: row.pointsCurrent)
                        }
                    await MainActor.run { championshipTop = top }
                    let teams = try? await client.championshipTeams(sessionKey: race.sessionKey)
                    let teamsAll = (teams ?? [])
                        .sorted { $0.positionCurrent < $1.positionCurrent }
                        .map { (position: $0.positionCurrent, name: $0.teamName, points: $0.pointsCurrent) }
                    await MainActor.run { championshipTeamsTop = teamsAll }
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
                    await MainActor.run { championshipTeamsTop = teamsList }
                } else {
                    let fallback = Self.fallbackSeasonTeams(year: year)
                    if !fallback.isEmpty {
                        await MainActor.run { championshipTeamsTop = fallback }
                    }
                }
            }
            if let nextMeeting = first {
                let sessions = (try? await client.sessions(meetingKey: nextMeeting.meetingKey)) ?? []
                await MainActor.run { nextMeetingSessions = sessions.sorted { ($0.dateStart ?? "") < ($1.dateStart ?? "") } }
            }
            let news = (try? await FIAFeedService.shared.fetchNews()) ?? []
            await MainActor.run { fiaNews = news }
            await MainActor.run { isLoaded = true }
        } catch {
            await MainActor.run { isLoaded = true }
        }
    }

    private static func fallbackSeasonTeams(year: Int) -> [(position: Int, name: String, points: Int)] {
        let names = [
            "Red Bull Racing", "Ferrari", "McLaren", "Mercedes", "Aston Martin",
            "Alpine", "Williams", "Racing Bulls", "Haas", "Kick Sauber"
        ]
        return names.enumerated().map { (position: $0.offset + 1, name: $0.element, points: 0) }
    }

    /// Обновление позиции из MQTT (вызывается на MainActor). Только текущая сессия; при смене сессии сбрасываем кэш.
    func mergeLiveLocation(_ loc: OpenF1Location) {
        let current = currentLiveSessionKey()
        guard let current = current, loc.sessionKey == current else { return }
        if current != lastLiveStreamSessionKey {
            lastLiveStreamSessionKey = current
            liveLocationByDriver = [:]
            print("[Live] MQTT merge session=\(current) drivers=\(liveLocationByDriver.count)")
        }
        liveLocationByDriver[loc.driverNumber] = loc
        liveLocations = Array(liveLocationByDriver.values)
    }

    /// Запуск лайва только через официальный F1 (SignalR Position.z). OpenF1 для карты не используем.
    func startLiveStreamIfNeeded() {
        F1LiveTimingSignalRService.shared.onCoordinates = { [weak self] coords in
            Task { @MainActor in
                guard let self = self else { return }
                self.liveCoordinatesByDriver = coords
                self.livePositionProgressByDriver = [:]
                if !coords.isEmpty { print("[F1Live] loader got \(coords.count) coordinates (real)") }
            }
        }
        F1LiveTimingSignalRService.shared.onPositions = { [weak self] positions in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.liveCoordinatesByDriver.isEmpty { return }
                self.livePositionProgressByDriver = positions
                if !positions.isEmpty { print("[F1Live] loader got \(positions.count) positions") }
            }
        }
        Task { await F1LiveTimingSignalRService.shared.connect() }
    }

    func stopLiveStream() {
        F1LiveTimingSignalRService.shared.onCoordinates = nil
        F1LiveTimingSignalRService.shared.onPositions = nil
        F1LiveTimingSignalRService.shared.disconnect()
        liveCoordinatesByDriver = [:]
        livePositionProgressByDriver = [:]
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
