//
//  OpenF1Client.swift
//  Podium
//

import Foundation

/// Кэш ответов по `session_key` / году — один и тот же JSON для всех пилотов; без этого каждый экран деталки заново тянул сотни запросов.
private actor OpenF1ResponseCache {
    private var championshipBySession: [Int: [OpenF1ChampionshipDriver]] = [:]
    private var positionsBySession: [Int: [OpenF1Position]] = [:]
    private var meetingsByYear: [Int: [OpenF1Meeting]] = [:]
    private var sessionsByYear: [Int: [OpenF1Session]] = [:]

    func championship(_ sessionKey: Int) -> [OpenF1ChampionshipDriver]? { championshipBySession[sessionKey] }
    func setChampionship(_ sessionKey: Int, _ rows: [OpenF1ChampionshipDriver]) { championshipBySession[sessionKey] = rows }

    func positions(_ sessionKey: Int) -> [OpenF1Position]? { positionsBySession[sessionKey] }
    func setPositions(_ sessionKey: Int, _ rows: [OpenF1Position]) { positionsBySession[sessionKey] = rows }

    func meetings(year: Int) -> [OpenF1Meeting]? { meetingsByYear[year] }
    func setMeetings(year: Int, _ rows: [OpenF1Meeting]) { meetingsByYear[year] = rows }

    func sessions(year: Int) -> [OpenF1Session]? { sessionsByYear[year] }
    func setSessions(year: Int, _ rows: [OpenF1Session]) { sessionsByYear[year] = rows }
}

enum OpenF1Error: Error, LocalizedError {
    case invalidURL
    case noData
    case decoding(Error)
    case network(Error)
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .noData: return "Нет данных"
        case .decoding(let e): return "Ошибка данных: \(e.localizedDescription)"
        case .network(let e): return "Сеть: \(e.localizedDescription)"
        case .server(let code): return "Ошибка сервера: \(code)"
        }
    }
}

final class OpenF1Client {
    static let shared = OpenF1Client()
    private let baseURL = "https://api.openf1.org/v1"
    private let session: URLSession
    private let responseCache = OpenF1ResponseCache()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func meetings(year: Int? = nil, countryName: String? = nil) async throws -> [OpenF1Meeting] {
        if let y = year, countryName == nil, let cached = await responseCache.meetings(year: y) {
            return cached
        }
        var components = URLComponents(string: "\(baseURL)/meetings")!
        var queryItems: [URLQueryItem] = []
        if let year { queryItems.append(URLQueryItem(name: "year", value: "\(year)")) }
        if let countryName { queryItems.append(URLQueryItem(name: "country_name", value: countryName)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw OpenF1Error.invalidURL }
        let result = try await decode([OpenF1Meeting].self, url: url)
        if let y = year, countryName == nil {
            await responseCache.setMeetings(year: y, result)
        }
        return result
    }

    func sessions(year: Int? = nil, meetingKey: Int? = nil) async throws -> [OpenF1Session] {
        if let y = year, meetingKey == nil, let cached = await responseCache.sessions(year: y) {
            return cached
        }
        var components = URLComponents(string: "\(baseURL)/sessions")!
        var queryItems: [URLQueryItem] = []
        if let year { queryItems.append(URLQueryItem(name: "year", value: "\(year)")) }
        if let meetingKey { queryItems.append(URLQueryItem(name: "meeting_key", value: "\(meetingKey)")) }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw OpenF1Error.invalidURL }
        let result = try await decode([OpenF1Session].self, url: url)
        if let y = year, meetingKey == nil {
            await responseCache.setSessions(year: y, result)
        }
        return result
    }

    func sessionsLatest() async throws -> [OpenF1Session] {
        guard let url = URL(string: "\(baseURL)/sessions?session_key=latest") else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1Session].self, url: url)
    }

    func drivers(sessionKey: Int? = nil, driverNumber: Int? = nil) async throws -> [OpenF1Driver] {
        var components = URLComponents(string: "\(baseURL)/drivers")!
        var queryItems: [URLQueryItem] = []
        if let sessionKey { queryItems.append(URLQueryItem(name: "session_key", value: "\(sessionKey)")) }
        if let driverNumber { queryItems.append(URLQueryItem(name: "driver_number", value: "\(driverNumber)")) }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1Driver].self, url: url)
    }

    func driversLatest() async throws -> [OpenF1Driver] {
        guard let url = URL(string: "\(baseURL)/drivers?session_key=latest") else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1Driver].self, url: url)
    }

    func championshipDrivers(sessionKey: Int) async throws -> [OpenF1ChampionshipDriver] {
        if let cached = await responseCache.championship(sessionKey) {
            return cached
        }
        guard let url = URL(string: "\(baseURL)/championship_drivers?session_key=\(sessionKey)") else { throw OpenF1Error.invalidURL }
        let result = try await decode([OpenF1ChampionshipDriver].self, url: url)
        await responseCache.setChampionship(sessionKey, result)
        return result
    }

    func championshipTeams(sessionKey: Int) async throws -> [OpenF1ChampionshipTeam] {
        guard let url = URL(string: "\(baseURL)/championship_teams?session_key=\(sessionKey)") else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1ChampionshipTeam].self, url: url)
    }

    func intervals(sessionKey: Int) async throws -> [OpenF1Interval] {
        guard let url = URL(string: "\(baseURL)/intervals?session_key=\(sessionKey)") else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1Interval].self, url: url)
    }

    func positions(sessionKey: Int) async throws -> [OpenF1Position] {
        if let cached = await responseCache.positions(sessionKey) {
            return cached
        }
        // API path is "position" (singular); try both for compatibility
        let urlString = "\(baseURL)/position?session_key=\(sessionKey)"
        guard let url = URL(string: urlString) else { throw OpenF1Error.invalidURL }
        let result: [OpenF1Position]
        do {
            result = try await decode([OpenF1Position].self, url: url)
        } catch {
            guard let url2 = URL(string: "\(baseURL)/positions?session_key=\(sessionKey)") else { throw error }
            result = try await decode([OpenF1Position].self, url: url2)
        }
        await responseCache.setPositions(sessionKey, result)
        return result
    }

    /// Позиции машин на трассе. Для real-time нужна подписка OpenF1 + MQTT (wss://mqtt.openf1.org:8084/mqtt, topic v1/location).
    /// REST при частом опросе даёт 429 — опрашивать не чаще ~1–2 раз в секунду.
    func location(sessionKey: Int) async throws -> [OpenF1Location] {
        let key = sessionKey == -1 ? "latest" : "\(sessionKey)"
        guard let url = URL(string: "\(baseURL)/location?session_key=\(key)") else { throw OpenF1Error.invalidURL }
        print("[Live] REST GET \(url.absoluteString)")
        let result = try await decode([OpenF1Location].self, url: url)
        print("[Live] REST location -> \(result.count) items")
        return result
    }

    func laps(sessionKey: Int) async throws -> [OpenF1Lap] {
        let key = sessionKey == -1 ? "latest" : "\(sessionKey)"
        guard let url = URL(string: "\(baseURL)/laps?session_key=\(key)") else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1Lap].self, url: url)
    }

    func pit(sessionKey: Int) async throws -> [OpenF1Pit] {
        guard let url = URL(string: "\(baseURL)/pit?session_key=\(sessionKey)") else { throw OpenF1Error.invalidURL }
        return try await decode([OpenF1Pit].self, url: url)
    }

    func circuitInfo(urlString: String) async throws -> CircuitInfo {
        guard let url = URL(string: urlString) else { throw OpenF1Error.invalidURL }
        return try await decode(CircuitInfo.self, url: url)
    }

    /// Порядок номеров по полю `position` (снимок с максимальным числом машин): `[P1, P2, …]`.
    /// У каждого пилота берём **лучшую** (минимальную) позицию в снимке — так убираем дубликаты строк.
    func driverOrderByLatestPositionSnapshot(sessionKey: Int) async -> [Int] {
        guard let positions = try? await positions(sessionKey: sessionKey), !positions.isEmpty else { return [] }
        let byDate = Dictionary(grouping: positions, by: { $0.date })
        var bestDate: String?
        var maxCount = 0
        for (date, list) in byDate {
            let count = Set(list.map(\.driverNumber)).count
            if count > maxCount || (count == maxCount && (bestDate == nil || date > bestDate!)) {
                maxCount = count
                bestDate = date
            }
        }
        guard let bestDate, let snapshot = byDate[bestDate] else { return [] }
        var bestPosByDriver: [Int: Int] = [:]
        for p in snapshot where p.position > 0 {
            let n = p.driverNumber
            if let old = bestPosByDriver[n] {
                if p.position < old { bestPosByDriver[n] = p.position }
            } else {
                bestPosByDriver[n] = p.position
            }
        }
        return bestPosByDriver
            .sorted { a, b in
                if a.value != b.value { return a.value < b.value }
                return a.key < b.key
            }
            .map(\.key)
    }

    /// Финиш в гонке (1 = победа). Сначала лёгкий `position`; `raceResults` — только при `allowHeavyRaceResultsFallback`.
    func raceFinishPosition(
        meetingKey: Int,
        raceSessionKey: Int,
        driverNumber: Int,
        allowHeavyRaceResultsFallback: Bool = true
    ) async -> Int? {
        let order = await driverOrderByLatestPositionSnapshot(sessionKey: raceSessionKey)
        if let idx = order.firstIndex(of: driverNumber) {
            return idx + 1
        }
        guard allowHeavyRaceResultsFallback else { return nil }
        if let results = try? await raceResults(meetingKey: meetingKey),
           let row = results.first(where: { $0.driverNumber == driverNumber }) {
            return row.position
        }
        return nil
    }

    func raceResults(meetingKey: Int) async throws -> [RaceResultRow] {
        let sessions = try await self.sessions(meetingKey: meetingKey)
        let raceSession: OpenF1Session? = OpenF1Session.grandPrixRaceSession(in: sessions)
            ?? sessions.sorted(by: { ($0.dateStart ?? "") > ($1.dateStart ?? "") }).first
        guard let raceSession = raceSession else {
            return []
        }

        let sessionKey = raceSession.sessionKey

        let drivers = try await self.drivers(sessionKey: sessionKey)
        guard !drivers.isEmpty else { return [] }

        let driverNames = Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.fullName) })
        let driverTeams = Dictionary(uniqueKeysWithValues: drivers.compactMap { d -> (Int, String)? in
            guard let t = d.teamName, !t.isEmpty else { return nil }
            return (d.driverNumber, t)
        })

        let championship = (try? await championshipDrivers(sessionKey: sessionKey)) ?? []
        let pointsScoredByDriver: [Int: Int] = Dictionary(uniqueKeysWithValues: championship.map { d in
            let raw = max(0, d.pointsCurrent - (d.pointsStart ?? 0))
            return (d.driverNumber, Int(round(raw)))
        })
        let allDriverNumbers = drivers.map(\.driverNumber)

        func formatRaceDuration(_ seconds: Double) -> String {
            let totalMillis = Int((seconds * 1000).rounded())
            let hours = totalMillis / 3_600_000
            let minutes = (totalMillis % 3_600_000) / 60_000
            let secsMillis = totalMillis % 60_000
            let secs = secsMillis / 1000
            let millis = secsMillis % 1000
            if hours > 0 {
                return String(format: "%d:%02d:%02d.%03d", hours, minutes, secs, millis)
            } else {
                return String(format: "%d:%02d.%03d", minutes, secs, millis)
            }
        }

        var orderedDriverNumbers: [Int] = []
        var timeByDriver: [Int: String] = [:]

        // 1) Intervals = единственный источник порядка и времени (gap_to_leader = отставание от лидера).
        let intervals = try? await intervals(sessionKey: sessionKey)
        if let intervals = intervals, !intervals.isEmpty {
            let lastPerDriver: [Int: OpenF1Interval] = intervals.reduce(into: [:]) { acc, i in
                let existing = acc[i.driverNumber]
                if existing == nil || (i.date > existing!.date) {
                    acc[i.driverNumber] = i
                }
            }
            for (num, interval) in lastPerDriver {
                if let gap = interval.gapToLeader {
                    switch gap {
                    case .seconds(let s):
                        timeByDriver[num] = s <= 0.0005 ? "—" : (s >= 60 ? String(format: "+%d:%.3f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60)) : String(format: "+%.3f", s))
                    case .lap(let str):
                        timeByDriver[num] = str
                    }
                } else {
                    timeByDriver[num] = "—"
                }
            }
            // Важно: сортируем по последнему интервалу каждого пилота.
            // Использование "последней даты из всех интервалов" часто даёт снэпшот с 1 пилотом.
            orderedDriverNumbers = lastPerDriver.values
                .sorted { a, b in
                    let ga = a.gapToLeader?.secondsValue ?? .infinity
                    let gb = b.gapToLeader?.secondsValue ?? .infinity
                    if ga != gb { return ga < gb }
                    return a.driverNumber < b.driverNumber
                }
                .map(\.driverNumber)
        }

        // 2) Position API = только если intervals пустые (резервный порядок).
        if orderedDriverNumbers.isEmpty {
            let positions = try? await positions(sessionKey: sessionKey)
            if let positions = positions, !positions.isEmpty {
                let byDate = Dictionary(grouping: positions, by: { $0.date })
                var bestDate: String?
                var maxCount = 0
                for (date, list) in byDate {
                    let count = Set(list.map { $0.driverNumber }).count
                    if count > maxCount || (count == maxCount && (bestDate == nil || date > bestDate!)) {
                        maxCount = count
                        bestDate = date
                    }
                }
                if let bestDate = bestDate, let snapshot = byDate[bestDate] {
                    orderedDriverNumbers = snapshot
                        .sorted(by: { $0.position < $1.position })
                        .map { $0.driverNumber }
                }
            }
        }

        // 3) Laps: leader total time; if no intervals, compute time for all from laps (leader duration, others +gap)
        let laps = try? await self.laps(sessionKey: sessionKey)
        if let laps = laps, !laps.isEmpty {
            let leaderNum = orderedDriverNumbers.first
            if let leaderNum = leaderNum {
                let leaderLaps = laps.filter { ($0.driverNumber ?? -1) == leaderNum }
                let totalSeconds = leaderLaps.compactMap { $0.effectiveLapDuration }.reduce(0, +)
                if totalSeconds > 0 {
                    timeByDriver[leaderNum] = formatRaceDuration(totalSeconds)
                }
            }
            if timeByDriver.values.allSatisfy({ $0 == "—" }) {
                struct DriverRaceStats {
                    var driverNumber: Int
                    var completedLaps: Int
                    var totalTime: Double
                }
                let grouped = Dictionary(grouping: laps, by: { $0.driverNumber ?? -1 }).filter { $0.key > 0 }
                var lapsStats: [DriverRaceStats] = []
                for (num, list) in grouped {
                    let completed = list.compactMap { $0.lapNumber }.max() ?? 0
                    let total = list.compactMap { $0.effectiveLapDuration }.reduce(0, +)
                    guard completed > 0, total > 0 else { continue }
                    lapsStats.append(DriverRaceStats(driverNumber: num, completedLaps: completed, totalTime: total))
                }
                let maxLaps = lapsStats.map { $0.completedLaps }.max() ?? 0
                let leader = lapsStats.filter { $0.completedLaps == maxLaps }.min(by: { $0.totalTime < $1.totalTime })
                let leaderTime = leader?.totalTime
                for s in lapsStats {
                    if s.driverNumber == leader?.driverNumber, let t = leaderTime {
                        timeByDriver[s.driverNumber] = formatRaceDuration(t)
                    } else if s.completedLaps == maxLaps, let lt = leaderTime {
                        let diff = s.totalTime - lt
                        timeByDriver[s.driverNumber] = diff <= 0.0005 ? "—" : String(format: "+%.3f", diff)
                    } else {
                        timeByDriver[s.driverNumber] = "—"
                    }
                }
            }
        }

        // 3) Fallback when no intervals: order and time from laps (use effectiveLapDuration = lap_duration or sector sum)
        if orderedDriverNumbers.isEmpty, let laps = laps, !laps.isEmpty {
            struct DriverRaceStats {
                var driverNumber: Int
                var completedLaps: Int
                var totalTime: Double
            }
            let grouped = Dictionary(grouping: laps, by: { $0.driverNumber ?? -1 }).filter { $0.key > 0 }
            var lapsStats: [DriverRaceStats] = []
            for (num, list) in grouped {
                let completed = list.compactMap { $0.lapNumber }.max() ?? 0
                let total = list.compactMap { $0.effectiveLapDuration }.reduce(0, +)
                guard completed > 0, total > 0 else { continue }
                lapsStats.append(DriverRaceStats(driverNumber: num, completedLaps: completed, totalTime: total))
            }
            let maxLaps = lapsStats.map { $0.completedLaps }.max() ?? 0
            let leader = lapsStats.filter { $0.completedLaps == maxLaps }.min(by: { $0.totalTime < $1.totalTime })
            let leaderTime = leader?.totalTime

            orderedDriverNumbers = lapsStats.sorted { a, b in
                if a.completedLaps != b.completedLaps { return a.completedLaps > b.completedLaps }
                return a.totalTime < b.totalTime
            }.map(\.driverNumber)

            for s in lapsStats {
                if s.driverNumber == leader?.driverNumber, let t = leaderTime {
                    timeByDriver[s.driverNumber] = formatRaceDuration(t)
                } else if s.completedLaps == maxLaps, let lt = leaderTime {
                    let diff = s.totalTime - lt
                    timeByDriver[s.driverNumber] = diff <= 0.0005 ? "—" : String(format: "+%.3f", diff)
                } else {
                    timeByDriver[s.driverNumber] = "—"
                }
            }
        }

        let missing = allDriverNumbers.filter { !Set(orderedDriverNumbers).contains($0) }
        orderedDriverNumbers.append(contentsOf: missing)

        let pointsByPosition: [Int] = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

        return orderedDriverNumbers.enumerated().map { index, driverNumber in
            let position = index + 1
            let points = pointsScoredByDriver[driverNumber] ?? (position <= pointsByPosition.count ? pointsByPosition[position - 1] : 0)
            let timeStr = timeByDriver[driverNumber] ?? "—"

            return RaceResultRow(
                position: position,
                driverNumber: driverNumber,
                driverName: driverNames[driverNumber] ?? "\(driverNumber)",
                teamName: driverTeams[driverNumber],
                time: timeStr,
                points: points
            )
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        let token = await OpenF1Auth.shared.getToken()
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if url.absoluteString.contains("location") {
            print("[Live] decode location request, hasToken=\(token != nil)")
        }
        var (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            let seconds = http.value(forHTTPHeaderField: "Retry-After").flatMap { UInt64($0) } ?? 2
            if url.absoluteString.contains("location") { print("[Live] 429 rate limit, retry after \(seconds)s") }
            try await Task.sleep(nanoseconds: min(seconds, 10) * 1_000_000_000)
            (data, response) = try await session.data(for: request)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if url.absoluteString.contains("location") { print("[Live] location response status=\(http.statusCode)") }
            throw OpenF1Error.server(http.statusCode)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw OpenF1Error.decoding(error)
        }
    }
}
