import Foundation
import SwiftUI
import Combine
import CoreGraphics
import UIKit

private enum SeasonLoaderLog {
    nonisolated static func line(_ message: String) {
        Swift.print("[SeasonLoader] \(message)")
    }
}

/// Обновление точек на карте без SwiftUI — позиции и цвета команд.
protocol LiveDotsViewUpdating: AnyObject {
    func setPositions(_ positions: [CGPoint], colors: [UIColor], driverNumbers: [Int])
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
    private nonisolated static func liveLog(_ message: String) {
        let ms = Int(Date().timeIntervalSince1970 * 1000) % 1_000_000
        Swift.print("[LiveDiag \(ms)] \(message)")
    }
    @Published var meeting: OpenF1Meeting?
    @Published var circuitInfo: CircuitInfo?
    @Published var circuitInfoByMeetingKey: [Int: CircuitInfo] = [:]
    @Published var seasonMeetings: [OpenF1Meeting] = []
    @Published var championshipTop: [(position: Int, name: String, points: Double)] = []
    /// Полный список пилотов в кубке (после последней завершённой гонки сезона).
    @Published var championshipDriverStandings: [(position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)] = []
    /// Wins / podiums / poles из OpenF1 `championship_drivers`.
    @Published var championshipDriverTrophyStats: [Int: (wins: Int, podiums: Int, poles: Int)] = [:]
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
    /// Стрим включён, когда герой на главном экране виден.
    @Published var isHeroSectionVisible = true
    /// Буфер MQTT в акторе — не грузим main thread каждым сообщением.
    private let liveLocationBuffer = LiveLocationBuffer()
    private var lastLiveStreamSessionKey: Int?
    private var liveStreamStarted = false
    /// Таск: раз в 1 с снэпшот → считаем точки → обновляем только UIKit, без SwiftUI.
    private var liveFlushTask: Task<Void, Never>?
    /// Опрос позиций в гонке для топ‑3 лидеров (REST OpenF1).
    private var livePositionsPollTask: Task<Void, Never>?
    /// Диагностика: время последнего апдейта top3 на UI.
    private var lastTop3UpdateAt: Date?
    /// Стабилизация списка: последний показанный порядок top‑3.
    private var lastTop3DriverOrder: [Int] = []
    /// MQTT top3: свежесть и анти-дребезг кандидата.
    private var lastMqttTop3UpdateAt: Date?
    private var mqttTop3Candidate: [Int] = []
    private var mqttTop3CandidateHits: Int = 0
    @Published var fiaNews: [FIANewsItem] = []
    @Published var isLoaded = false
    @Published var isLoading = false
    /// В текущем году уже есть завершённый этап — тогда ждём непустую таблицу пилотов; иначе пустые пилоты не считаем «дырой» bootstrap.
    @Published private(set) var bootstrapHadCompletedRace = false
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

    /// Wins / podiums / poles по сезону из f1api.dev (`/race` + `/qualy` по round).
    @Published var cupTrophyByDriver: [Int: (wins: Int, podiums: Int, poles: Int)] = [:]
    @Published var cupTrophyYear: Int?
    private var cupTrophyComputeTask: Task<Void, Never>?

    /// Таблица на вкладке «Кубок» по выбранному сезону (подгружается здесь, не только из bootstrap главной).
    @Published var driversCupTabStandings: [(position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)] = []
    @Published var driversCupTabStandingsYear: Int?
    @Published var isLoadingDriversCupStandings = false

    /// Years available in picker: от текущего года до 2014 (текущий выбран по умолчанию).
    static var availableSeasonYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((2014...current).reversed())
    }

    /// Минимум данных для главной: календарь и конструкторы; пилоты обязательны только если в сезоне уже был завершённый ГП.
    var isBootstrapDataComplete: Bool {
        guard !seasonMeetings.isEmpty, !championshipTeamsTop.isEmpty else { return false }
        if bootstrapHadCompletedRace {
            return !championshipDriverStandings.isEmpty
        }
        return true
    }

    /// Cold start: если после первого `load()` bootstrap неполный — повтор с `forceRefresh`.
    func finalizeBootstrapIfIncomplete() async {
        if isBootstrapDataComplete {
            SeasonLoaderLog.line("finalizeBootstrapIfIncomplete: skip (bootstrap already complete)")
            return
        }
        SeasonLoaderLog.line("finalizeBootstrapIfIncomplete: calling load(forceRefresh: true) — incomplete bootstrap")
        await load(forceRefresh: true)
    }

    /// Возврат из фона: обновляем данные (после cold start `load()` сам дождётся текущего in-flight).
    func resumeBootstrapIfNeeded() async {
        guard isLoaded else {
            SeasonLoaderLog.line("resumeBootstrapIfNeeded: skip (!isLoaded)")
            return
        }
        SeasonLoaderLog.line("resumeBootstrapIfNeeded: load(forceRefresh: true)")
        await load(forceRefresh: true)
    }

    /// Загрузка календаря сезона из f1api + Open F1 (трассы для карт на карточках).
    func loadSeasonFromF1API(_ year: Int) async {
        SeasonLoaderLog.line("loadSeasonFromF1API(year: \(year)) start")
        await MainActor.run { isLoadingYear = true }
        defer { Task { @MainActor in self.isLoadingYear = false } }
        do {
            let races = try await F1APIClient.shared.seasonCalendar(year: year)
            SeasonLoaderLog.line("loadSeasonFromF1API: F1APIClient.seasonCalendar → \(races.count) races")
            await MainActor.run {
                selectedSeasonYear = year
                f1apiRacesForSelectedYear = races
                cupTrophyByDriver = [:]
                cupTrophyYear = nil
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
            scheduleCupTrophiesForYear(year)
            SeasonLoaderLog.line("loadSeasonFromF1API(year: \(year)) done")
        } catch {
            SeasonLoaderLog.line("loadSeasonFromF1API(year: \(year)) error: \(error.localizedDescription)")
            await MainActor.run { f1apiRacesForSelectedYear = [] }
        }
    }

    func loadMeetingsForYear(_ year: Int) async {
        SeasonLoaderLog.line("loadMeetingsForYear(\(year)) start")
        await MainActor.run { isLoadingYear = true }
        defer { Task { @MainActor in self.isLoadingYear = false } }
        let client = OpenF1Client.shared
        do {
            let meetings = try await client.meetings(year: year)
            SeasonLoaderLog.line("loadMeetingsForYear: OpenF1 meetings → \(meetings.count) raw")
            let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
            await MainActor.run {
                selectedSeasonYear = year
                meetingsForSelectedYear = raceMeetings
                cupTrophyByDriver = [:]
                cupTrophyYear = nil
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
            scheduleCupTrophiesForYear(year)
            SeasonLoaderLog.line("loadMeetingsForYear(\(year)) done")
        } catch {
            SeasonLoaderLog.line("loadMeetingsForYear(\(year)) error: \(error.localizedDescription)")
            await MainActor.run {
                meetingsForSelectedYear = []
                circuitInfoForSelectedYear = [:]
            }
        }
    }

    /// Один расчёт трофеев на сезон: на этап 1× `position` по гонке + 1× по квалификации, дальше раздаём всем номерам (без `raceResults` и без повторов на каждого пилота).
    func scheduleCupTrophiesForYear(_ year: Int) {
        cupTrophyComputeTask?.cancel()
        cupTrophyComputeTask = Task(priority: .utility) { [weak self] in
            await self?.computeCupTrophiesFromF1API(year: year)
        }
    }

    /// Результат загрузки кубка: не затираем таблицу, если для текущего года уже пришли данные с главной (`load()`), иначе гонка даёт «то есть, то нет».
    private func applyDriversCupTabStandingsFromFetch(
        year: Int,
        rows: [(position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)]
    ) {
        let calendarYear = Calendar.current.component(.year, from: Date())
        if !rows.isEmpty {
            driversCupTabStandings = rows
            driversCupTabStandingsYear = year
            return
        }
        if year == calendarYear, !championshipDriverStandings.isEmpty {
            driversCupTabStandings = championshipDriverStandings
            driversCupTabStandingsYear = year
        } else {
            driversCupTabStandings = []
            driversCupTabStandingsYear = year
        }
    }

    /// Загрузка чемпионата для вкладки «Кубок» по году из селектора (последняя завершённая гонка сезона в OpenF1).
    func loadDriversCupTabStandings(year: Int) async {
        let calendarYear = Calendar.current.component(.year, from: Date())
        SeasonLoaderLog.line("loadDriversCupTabStandings(year: \(year)) enter")
        // Не стартовать отдельную сеть, пока идёт общий bootstrap — иначе долгий ProgressView и дубли запросов.
        if year == calendarYear {
            let deadline = Date().addingTimeInterval(120)
            while isLoading && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }
            if isLoading {
                SeasonLoaderLog.line("loadDriversCupTabStandings: waited 120s, isLoading still true — continuing")
            }
        }
        if year == calendarYear, !championshipDriverStandings.isEmpty {
            driversCupTabStandings = championshipDriverStandings
            driversCupTabStandingsYear = year
            SeasonLoaderLog.line("loadDriversCupTabStandings: copy from championshipDriverStandings (\(championshipDriverStandings.count) rows)")
            return
        }
        if driversCupTabStandingsYear == year, !driversCupTabStandings.isEmpty {
            SeasonLoaderLog.line("loadDriversCupTabStandings: cache hit year=\(year), rows=\(driversCupTabStandings.count)")
            return
        }
        isLoadingDriversCupStandings = true
        defer { isLoadingDriversCupStandings = false }

        let client = OpenF1Client.shared
        let now = Date()
        do {
            SeasonLoaderLog.line("loadDriversCupTabStandings: OpenF1 meetings(year: \(year))")
            let meetings = try await client.meetings(year: year)
            let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
            let sortedByDate = raceMeetings.sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }
            let lastCompleted = sortedByDate.last { m in (m.parsedDateEnd ?? .distantFuture) < now }
            guard let last = lastCompleted else {
                if Task.isCancelled { return }
                SeasonLoaderLog.line("loadDriversCupTabStandings: no lastCompleted race for year \(year)")
                applyDriversCupTabStandingsFromFetch(year: year, rows: [])
                return
            }
            SeasonLoaderLog.line("loadDriversCupTabStandings: sessions(meetingKey: \(last.meetingKey)) last completed")
            let sessions = try await client.sessions(meetingKey: last.meetingKey)
            guard let race = OpenF1Session.grandPrixRaceSession(in: sessions) else {
                if Task.isCancelled { return }
                SeasonLoaderLog.line("loadDriversCupTabStandings: no GP race session for meeting \(last.meetingKey)")
                applyDriversCupTabStandingsFromFetch(year: year, rows: [])
                return
            }
            SeasonLoaderLog.line("loadDriversCupTabStandings: championshipDrivers + drivers sessionKey=\(race.sessionKey)")
            async let standingsTask = client.championshipDrivers(sessionKey: race.sessionKey)
            async let driversTask = client.drivers(sessionKey: race.sessionKey)
            let standings = try await standingsTask
            let drivers = try await driversTask
            let names = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.fullName) })
            let sortedStandings = standings.sorted { $0.positionCurrent < $1.positionCurrent }
            let fullRows: [(position: Int, driverNumber: Int, fullName: String, teamName: String, points: Double, countryCode: String)] = sortedStandings.map { row in
                let d = drivers.first { $0.driverNumber == row.driverNumber }
                let full = names[row.driverNumber] ?? "\(row.driverNumber)"
                let team = d?.teamName ?? ""
                let cc = DriverNationality.resolveCountryCode(apiCode: d?.countryCode, fullName: full)
                return (row.positionCurrent, row.driverNumber, full, team, row.pointsCurrent, cc)
            }
            if Task.isCancelled { return }
            applyDriversCupTabStandingsFromFetch(year: year, rows: fullRows)
            SeasonLoaderLog.line("loadDriversCupTabStandings(year: \(year)) done, rows=\(fullRows.count)")
        } catch {
            if Task.isCancelled { return }
            SeasonLoaderLog.line("loadDriversCupTabStandings(year: \(year)) error: \(error.localizedDescription)")
            applyDriversCupTabStandingsFromFetch(year: year, rows: [])
        }
    }

    /// Wins / podiums / poles — только f1api.dev: `/race` и `/qualy` по round (без OpenF1, без лавины 429).
    private func computeCupTrophiesFromF1API(year: Int) async {
        guard !Task.isCancelled else { return }
        do {
            let calendar = try await F1APIClient.shared.seasonCalendar(year: year)
            let races = calendar.sorted { $0.round < $1.round }
            let rounds = Array(races.prefix(25))
            var totalWins: [Int: Int] = [:]
            var totalPodiums: [Int: Int] = [:]
            var totalPoles: [Int: Int] = [:]

            let batchSize = 6
            SeasonLoaderLog.line("cupTrophies: f1api race+qualy per round, batches of \(batchSize) (\(rounds.count) rounds)")
            for chunkStart in stride(from: 0, to: rounds.count, by: batchSize) {
                guard !Task.isCancelled else { return }
                let end = min(chunkStart + batchSize, rounds.count)
                let slice = Array(rounds[chunkStart..<end])
                await withTaskGroup(of: CupRoundTrophyResult.self) { group in
                    for race in slice {
                        group.addTask {
                            await Self.cupRoundTrophiesFromF1API(year: year, round: race.round)
                        }
                    }
                    for await delta in group {
                        Self.mergeTrophyMaps(&totalWins, delta.wins)
                        Self.mergeTrophyMaps(&totalPodiums, delta.podiums)
                        Self.mergeTrophyMaps(&totalPoles, delta.poles)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            var merged: [Int: (wins: Int, podiums: Int, poles: Int)] = [:]
            let keys = Set(totalWins.keys).union(totalPodiums.keys).union(totalPoles.keys)
            for d in keys {
                merged[d] = (totalWins[d] ?? 0, totalPodiums[d] ?? 0, totalPoles[d] ?? 0)
            }
            await MainActor.run {
                self.cupTrophyByDriver = merged
                self.cupTrophyYear = year
            }
        } catch {
            if Task.isCancelled { return }
        }
    }

    private static func cupRoundTrophiesFromF1API(year: Int, round: Int) async -> CupRoundTrophyResult {
        async let raceRows = try? await F1APIClient.shared.raceResults(year: year, round: round)
        async let poleNum = try? await F1APIClient.shared.poleDriverNumber(year: year, round: round)
        let results = await raceRows
        let pole = await poleNum
        var w: [Int: Int] = [:]
        var p: [Int: Int] = [:]
        var poles: [Int: Int] = [:]
        if let results = results {
            for row in results {
                if row.position == 1 { w[row.driverNumber, default: 0] += 1 }
                if row.position <= 3 { p[row.driverNumber, default: 0] += 1 }
            }
        }
        if let n = pole { poles[n, default: 0] += 1 }
        return CupRoundTrophyResult(wins: w, podiums: p, poles: poles)
    }

    private struct CupRoundTrophyResult: Sendable {
        var wins: [Int: Int]
        var podiums: [Int: Int]
        var poles: [Int: Int]
    }

    private static func mergeTrophyMaps(_ acc: inout [Int: Int], _ delta: [Int: Int]) {
        for (k, v) in delta { acc[k, default: 0] += v }
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

    /// Вся сеть и обработка — в фоне (Task.detached), на main только быстрые обновления состояния (по доке Apple).
    /// - `forceRefresh`: при возврате из фона — не выходим раньше времени, если кэш «полный»; иначе старые данные не перезапрашиваются.
    func load(forceRefresh: Bool = false) async {
        // Раньше: `guard !isLoading else { return }` — второй вызов (foreground, другой экран)
        // молча выходил и НЕ ждал первый таск → пустой UI и «ничего не меняется» при повторных заходах.
        SeasonLoaderLog.line("load(forceRefresh: \(forceRefresh)) enter — isLoaded=\(isLoaded) isLoading=\(isLoading) complete=\(isBootstrapDataComplete)")
        let waitDeadline = Date().addingTimeInterval(120)
        while isLoading && Date() < waitDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if !forceRefresh && isLoaded && isBootstrapDataComplete {
            SeasonLoaderLog.line("load: skip (already loaded + bootstrap complete)")
            return
        }
        guard !isLoading else {
            SeasonLoaderLog.line("load: skip (isLoading still true after wait)")
            return
        }

        isLoading = true
        cupTrophyComputeTask?.cancel()
        SeasonLoaderLog.line("load: start bootstrap task (year=\(Calendar.current.component(.year, from: Date())))")

        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let client = OpenF1Client.shared
            let year = Calendar.current.component(.year, from: Date())
            let now = Date()
            do {
                SeasonLoaderLog.line("load: OpenF1 meetings(year: \(year))")
                let meetings = try await client.meetings(year: year)
                let raceMeetings = meetings.filter { !$0.meetingName.lowercased().contains("test") }
                let sortedByDate = raceMeetings.sorted { ($0.parsedDateStart ?? .distantPast) < ($1.parsedDateStart ?? .distantPast) }
                SeasonLoaderLog.line("load: meetings → \(raceMeetings.count) races (sorted \(sortedByDate.count))")
                await MainActor.run { self.seasonMeetings = sortedByDate }

                let currentOrNext = sortedByDate.first { m in
                    let start = m.parsedDateStart ?? .distantPast
                    let end = m.parsedDateEnd ?? .distantFuture
                    return (start <= now && now <= end) || start >= now
                }
                let first = currentOrNext ?? sortedByDate.first
                if let first = first {
                    SeasonLoaderLog.line("load: current/next meeting key=\(first.meetingKey) name=\(first.meetingName)")
                    await MainActor.run { self.meeting = first }
                    // Параллельно: circuitInfo и сессии — MQTT стартует сразу, не ждём circuitInfo.
                    SeasonLoaderLog.line("load: circuitInfo + sessions(meetingKey: \(first.meetingKey))")
                    let circuitTask = first.circuitInfoUrl.map { url in Task { try? await client.circuitInfo(urlString: url) } }
                    let sessionsTask = Task { try? await client.sessions(meetingKey: first.meetingKey) }
                    let info: CircuitInfo? = if let t = circuitTask { await t.value } else { nil }
                    let nextSessions = (await sessionsTask.value) ?? []
                    await MainActor.run {
                        if let info = info { self.circuitInfo = info }
                        self.nextMeetingSessions = nextSessions.sorted { ($0.dateStart ?? "") < ($1.dateStart ?? "") }
                        self.syncUpcomingRaceWidget()
                        self.startLiveStreamIfNeeded()
                    }
                }

                var loadedCircuits: [Int: CircuitInfo] = [:]
                let withCircuitUrl = raceMeetings.filter { $0.circuitInfoUrl != nil }
                let circuitFetchCount = withCircuitUrl.count
                let batchSize = 4
                SeasonLoaderLog.line("load: circuitInfo batched (\(batchSize) concurrent) for \(circuitFetchCount) meetings")
                for chunkStart in stride(from: 0, to: withCircuitUrl.count, by: batchSize) {
                    let end = min(chunkStart + batchSize, withCircuitUrl.count)
                    let slice = Array(withCircuitUrl[chunkStart..<end])
                    await withTaskGroup(of: (Int, CircuitInfo?).self) { group in
                        for m in slice {
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
                    if end < withCircuitUrl.count {
                        try? await Task.sleep(nanoseconds: 120_000_000)
                    }
                }
                await MainActor.run { self.circuitInfoByMeetingKey = loadedCircuits }
                SeasonLoaderLog.line("load: circuitInfoByMeetingKey keys=\(loadedCircuits.count)")

                var teamsLoadedFromChampionship = false
                let lastCompleted = sortedByDate.last { m in (m.parsedDateEnd ?? .distantFuture) < now }
                await MainActor.run { self.bootstrapHadCompletedRace = lastCompleted != nil }
                if let last = lastCompleted {
                    SeasonLoaderLog.line("load: championship path — last completed meetingKey=\(last.meetingKey)")
                    let sessions = try await client.sessions(meetingKey: last.meetingKey)
                    let raceSession = OpenF1Session.grandPrixRaceSession(in: sessions)
                    if let race = raceSession {
                        SeasonLoaderLog.line("load: championshipDrivers + drivers + teams sessionKey=\(race.sessionKey)")
                        async let standingsTask = client.championshipDrivers(sessionKey: race.sessionKey)
                        async let driversTask = client.drivers(sessionKey: race.sessionKey)
                        let standings = try await standingsTask
                        let drivers = try await driversTask
                        let names = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.fullName) })
                        let sortedStandings = standings.sorted { $0.positionCurrent < $1.positionCurrent }
                        var trophyStatsByDriverNumber: [Int: (wins: Int, podiums: Int, poles: Int)] = [:]
                        for row in sortedStandings {
                            trophyStatsByDriverNumber[row.driverNumber] = (wins: row.wins, podiums: row.podiums, poles: row.poles)
                        }
                        let fullRows = sortedStandings.map { row -> (Int, Int, String, String, Double, String) in
                            let d = drivers.first { $0.driverNumber == row.driverNumber }
                            let full = names[row.driverNumber] ?? "\(row.driverNumber)"
                            let team = d?.teamName ?? ""
                            let cc = DriverNationality.resolveCountryCode(apiCode: d?.countryCode, fullName: full)
                            return (row.positionCurrent, row.driverNumber, full, team, row.pointsCurrent, cc)
                        }
                        let top = fullRows.prefix(5).map { ($0.0, $0.2, $0.4) }
                        await MainActor.run {
                            self.championshipDriverStandings = fullRows
                            self.championshipDriverTrophyStats = trophyStatsByDriverNumber
                            self.championshipTop = top
                            // Кубок: если селектор сезона = тот же год, что поднял bootstrap — сразу та же таблица (и позже не затирается отдельным запросом).
                            if year == self.selectedSeasonYear {
                                self.driversCupTabStandings = fullRows
                                self.driversCupTabStandingsYear = year
                            }
                        }
                        if let leaderStanding = standings.min(by: { $0.positionCurrent < $1.positionCurrent }),
                           let leaderDriver = drivers.first(where: { $0.driverNumber == leaderStanding.driverNumber }) {
                            let leaderName = leaderDriver.fullName
                            let leaderTeam = leaderDriver.teamName ?? ""
                            let photoAsset = String.AppImage.driverPhotoAsset(forFullName: leaderName)
                            PodiumWidgetDataSync.pushDriverLeader(
                                fullName: leaderName,
                                points: leaderStanding.pointsCurrent,
                                teamName: leaderTeam,
                                photoAssetName: photoAsset
                            )
                        }
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
                    SeasonLoaderLog.line("load: teams fallback (driversLatest / first meeting / static)")
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
                // Трофеи кубка — фоном (OpenF1 `positions` × этапы даёт 429 при параллели и блокирует сплэш на минуты).
                await MainActor.run {
                    self.isLoaded = true
                    self.scheduleCupTrophiesForYear(year)
                }
                SeasonLoaderLog.line("load: isLoaded=true; cup trophies scheduled in background")
                if let nextMeeting = first {
                    SeasonLoaderLog.line("load: refresh nextMeetingSessions meetingKey=\(nextMeeting.meetingKey)")
                    let sessions = (try? await client.sessions(meetingKey: nextMeeting.meetingKey)) ?? []
                    await MainActor.run {
                        self.nextMeetingSessions = sessions.sorted { ($0.dateStart ?? "") < ($1.dateStart ?? "") }
                        self.syncUpcomingRaceWidget()
                    }
                }
                SeasonLoaderLog.line("load: FIA fetchNews")
                let news = (try? await FIAFeedService.shared.fetchNews()) ?? []
                await MainActor.run { self.fiaNews = news }
                SeasonLoaderLog.line("load: news items=\(news.count)")
                SeasonLoaderLog.line("load: bootstrap finished OK")
            } catch {
                SeasonLoaderLog.line("load: catch — \(error.localizedDescription)")
                await MainActor.run { self.isLoaded = true }
            }
        }.value
        await MainActor.run { self.isLoading = false }
        SeasonLoaderLog.line("load: isLoading=false (task completed)")
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

        // Снэпшот locations ~60×/с (без objectWillChange на SeasonDataLoader — иначе лагает весь Home).
        var cachedInfo: CircuitInfo?
        var cachedSize: CGSize?
        var cachedView: (any LiveDotsViewUpdating)?
        var cachedPointsByDriver: [Int: CGPoint] = [:]
        var tick = 0
        var diagLastAt = Date.distantPast
        var diagPrevLocationsVersion: Int = 0
        liveFlushTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                let snapshot = await self.liveLocationBuffer.snapshot()
                let newestDateString = snapshot.max(by: { $0.date < $1.date })?.date
                let snapshotAgeMs: Int = {
                    guard let newestDateString else { return -1 }
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let parsed = iso.date(from: newestDateString) ?? {
                        let iso2 = ISO8601DateFormatter()
                        iso2.formatOptions = [.withInternetDateTime]
                        return iso2.date(from: newestDateString)
                    }()
                    guard let newestDate = parsed else { return -1 }
                    return max(0, Int(Date().timeIntervalSince(newestDate) * 1000))
                }()

                // Всегда пушим locations и версию — карта обновляется часто.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.liveMapState.locations = snapshot
                    self.liveMapState.locationsVersion &+= 1
                }

                let doHeavy = (tick % 3 == 0)
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

                    // Top-3 из MQTT: только подтверждённый порядок (анти-дребезг).
                    if !driverNumbersCopy.isEmpty {
                        let top3Nums = Self.top3DriverNumbersByProgress(snapshot: snapshot, circuitInfo: info)
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            if Self.sameTop3(self.mqttTop3Candidate, top3Nums) {
                                self.mqttTop3CandidateHits += 1
                            } else {
                                self.mqttTop3Candidate = top3Nums
                                self.mqttTop3CandidateHits = 1
                            }
                            // Применяем только когда один и тот же порядок пришёл минимум дважды подряд.
                            guard self.mqttTop3CandidateHits >= 2 else { return }
                            self.lastMqttTop3UpdateAt = Date()
                            self.lastTop3UpdateAt = Date()
                            guard !Self.sameTop3(self.lastTop3DriverOrder, top3Nums) else { return }
                            let names = self.liveDriverNames
                            let teams = self.liveDriverTeamNames
                            withAnimation(.easeInOut(duration: 0.35)) {
                                self.liveMapState.top3LiveDrivers = top3Nums.enumerated().map { idx, num in
                                    (idx + 1, num, names[num] ?? "#\(num)", teams[num] ?? "")
                                }
                            }
                            self.lastTop3DriverOrder = top3Nums
                        }
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let colors = driverNumbersCopy.map { self.liveDriverColors[$0] ?? .gray }
                        view.setPositions(points, colors: colors, driverNumbers: driverNumbersCopy)
                    }
                }

                if Date().timeIntervalSince(diagLastAt) >= 2.0 {
                    diagLastAt = Date()
                    let uiInfo = await MainActor.run { () -> (Int, Int, Int) in
                        let currentVersion = self.liveMapState.locationsVersion
                        let delta = currentVersion - diagPrevLocationsVersion
                        diagPrevLocationsVersion = currentVersion
                        let top3Count = self.liveMapState.top3LiveDrivers.count
                        let top3AgeMs = self.lastTop3UpdateAt.map { max(0, Int(Date().timeIntervalSince($0) * 1000)) } ?? -1
                        return (delta, top3Count, top3AgeMs)
                    }
                    Self.liveLog("flush snapshot=\(snapshot.count) ageMs=\(snapshotAgeMs) locVersionDelta=\(uiInfo.0) top3=\(uiInfo.1) top3AgeMs=\(uiInfo.2)")
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

    private nonisolated static func sameTop3(_ lhs: [Int], _ rhs: [Int]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy(==)
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

    /// Топ‑3 лидеров из API позиций (реальный порядок в гонке). Опрос раз в ~0.7 с.
    private func startLivePositionsPoll(sessionKey initialSk: Int?) {
        livePositionsPollTask?.cancel()
        livePositionsPollTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            var pollIdx = 0
            while !Task.isCancelled {
                let sk = await MainActor.run {
                    self.currentLiveSessionKey() ?? self.lastLiveStreamSessionKey ?? self.nextMeetingSessions.first?.sessionKey ?? initialSk
                }
                if let sk = sk {
                    let startedAt = Date()
                    let list = (try? await OpenF1Client.shared.positions(sessionKey: sk)) ?? []
                    // Последняя запись по каждому гонщику (по date), затем сортировка по position — это реальный порядок в гонке.
                    let byDriver: [Int: OpenF1Position] = list.reduce(into: [:]) { acc, p in
                        if acc[p.driverNumber] == nil || (p.date > acc[p.driverNumber]!.date) { acc[p.driverNumber] = p }
                    }
                    let sorted = byDriver.values.sorted { $0.position < $1.position }
                    let top3 = Array(sorted.prefix(3))
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.lastTop3UpdateAt = Date()
                        let mqttFresh = self.lastMqttTop3UpdateAt.map { Date().timeIntervalSince($0) < 2.5 } ?? false
                        // Пока MQTT свежий, REST не перетирает top3.
                        guard !mqttFresh || self.lastTop3DriverOrder.isEmpty else { return }
                        let newOrder = top3.map(\.driverNumber)
                        guard !Self.sameTop3(self.lastTop3DriverOrder, newOrder) else { return }
                        let names = self.liveDriverNames
                        let teams = self.liveDriverTeamNames
                        withAnimation(.easeInOut(duration: 0.35)) {
                            self.liveMapState.top3LiveDrivers = top3.enumerated().map { idx, p in
                                (idx + 1, p.driverNumber, names[p.driverNumber] ?? "#\(p.driverNumber)", teams[p.driverNumber] ?? "")
                            }
                        }
                        self.lastTop3DriverOrder = newOrder
                        self.lastTop3UpdateAt = Date()
                    }
                    pollIdx += 1
                    if pollIdx % 4 == 0 {
                        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                        Self.liveLog("positionsPoll sk=\(sk) rows=\(list.count) uniq=\(byDriver.count) top3=\(top3.count) reqMs=\(elapsedMs)")
                    }
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
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
        liveDotsView?.setPositions([], colors: [], driverNumbers: [])
        liveDriverColors = [:]
        liveDriverNames = [:]
        liveDriverTeamNames = [:]
        liveMapState.coordinatesByDriver = [:]
        liveMapState.positionProgressByDriver = [:]
        liveMapState.locations = []
        liveMapState.top3LiveDrivers = []
        lastTop3DriverOrder = []
        lastMqttTop3UpdateAt = nil
        mqttTop3Candidate = []
        mqttTop3CandidateHits = 0
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

    private func syncUpcomingRaceWidget() {
        guard let m = meeting else { return }
        let now = Date()
        let futureSessions = nextMeetingSessions
            .compactMap { s -> (Date, String)? in
                guard let start = parseSessionDate(s.dateStart), start > now else { return nil }
                return (start, sessionShortName(s.sessionName))
            }
            .sorted { $0.0 < $1.0 }

        let targetDate = futureSessions.first?.0 ?? m.parsedDateStart ?? Date()
        let eventName = futureSessions.first?.1 ?? "Race"
        let circuitKey = m.circuitShortName.isEmpty ? m.location : m.circuitShortName
        PodiumWidgetDataSync.pushUpcomingRace(
            city: m.location,
            country: m.countryName,
            eventDate: targetDate,
            eventName: eventName,
            circuitNameOrLocation: circuitKey
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
}
