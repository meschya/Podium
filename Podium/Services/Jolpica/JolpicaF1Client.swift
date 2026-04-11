//
//  JolpicaF1Client.swift
//  Podium — https://api.jolpi.ca/ergast/f1 (Jolpica, Ergast-compatible).
//

import Foundation

enum JolpicaF1Error: Error, LocalizedError {
    case invalidURL
    case http(Int)
    case decode
    case driverNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Jolpica URL"
        case .http(let c): return "Jolpica HTTP \(c)"
        case .decode: return "Jolpica decode error"
        case .driverNotFound: return "Driver not found in Jolpica list"
        }
    }
}

/// Клиент Jolpica F1 API — агрегаты по сезону для экрана гонщика (пакетные запросы вместо N× раундов).
final class JolpicaF1Client {
    static let shared = JolpicaF1Client()

    private let baseURL = "https://api.jolpi.ca/ergast/f1"
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    /// `limit` поднят: в сезоне бывает >30 пилотов.
    private func url(path: String) throws -> URL {
        let q = path.contains("?") ? "&" : "?"
        guard let u = URL(string: "\(baseURL)\(path)\(q)limit=2000") else { throw JolpicaF1Error.invalidURL }
        return u
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let u = try url(path: path)
        let (data, response) = try await session.data(from: u)
        guard let http = response as? HTTPURLResponse else { throw JolpicaF1Error.decode }
        guard (200..<300).contains(http.statusCode) else { throw JolpicaF1Error.http(http.statusCode) }
        do {
            let dec = JSONDecoder()
            return try dec.decode(T.self, from: data)
        } catch {
            throw JolpicaF1Error.decode
        }
    }

    func seasonRaces(year: Int) async throws -> [JolpicaSeasonRace] {
        let r = try await fetch(JolpicaSeasonResponse.self, path: "/\(year).json")
        return r.MRData.RaceTable.Races.sorted { $0.roundInt < $1.roundInt }
    }

    func drivers(year: Int) async throws -> [JolpicaDriver] {
        let r = try await fetch(JolpicaDriversResponse.self, path: "/\(year)/drivers.json")
        return r.MRData.DriverTable.Drivers
    }

    func driverGpRaces(year: Int, driverId: String) async throws -> [JolpicaDriverGpRace] {
        let enc = driverId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? driverId
        let r = try await fetch(JolpicaDriverGpResultsResponse.self, path: "/\(year)/drivers/\(enc)/results.json")
        return r.MRData.RaceTable.Races.sorted { $0.roundInt < $1.roundInt }
    }

    func driverSprintRaces(year: Int, driverId: String) async throws -> [JolpicaDriverSprintRace] {
        let enc = driverId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? driverId
        let r = try await fetch(JolpicaDriverSprintResponse.self, path: "/\(year)/drivers/\(enc)/sprint.json")
        return r.MRData.RaceTable.Races.sorted { $0.roundInt < $1.roundInt }
    }

    /// Сопоставление номера/имени из кубка с `driverId` Jolpica.
    static func resolveDriverId(drivers: [JolpicaDriver], driverNumber: Int, fullName: String) -> String? {
        if let d = drivers.first(where: { JolpicaDecode.intString($0.permanentNumber) == driverNumber }) {
            return d.driverId
        }
        let key = normalizedDriverNameKey(fullName)
        return drivers.first(where: {
            normalizedDriverNameKey("\($0.givenName) \($0.familyName)") == key
        })?.driverId
    }

    private static func normalizedDriverNameKey(_ name: String) -> String {
        name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .split { $0.isWhitespace }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Calendar / round / results (Ergast JSON on Jolpica)

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func fetchData(path: String) async throws -> Data {
        let u = try url(path: path)
        let (data, response) = try await session.data(from: u)
        guard let http = response as? HTTPURLResponse else { throw JolpicaF1Error.decode }
        guard (200..<300).contains(http.statusCode) else { throw JolpicaF1Error.http(http.statusCode) }
        return data
    }

    private func fetchOptionalData(path: String) async throws -> Data? {
        let u = try url(path: path)
        let (data, response) = try await session.data(from: u)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw JolpicaF1Error.http(http.statusCode) }
        return data
    }

    /// GET `/{year}.json` — календарь сезона для карточек сезона.
    func seasonCalendar(year: Int) async throws -> [JolpicaCalendarRace] {
        let data = try await fetchData(path: "/\(year).json")
        let decoded = try JSONDecoder().decode(JolpicaSeasonResponse.self, from: data)
        return decoded.MRData.RaceTable.Races
            .map { r in
                JolpicaCalendarRace(
                    round: r.roundInt,
                    raceName: r.raceName ?? "Round \(r.roundInt)",
                    schedule: JolpicaRaceSchedule(race: JolpicaRaceDay(date: r.date)),
                    circuit: JolpicaCircuitSummary(
                        circuitName: r.Circuit?.circuitName,
                        country: r.Circuit?.Location?.country,
                        city: r.Circuit?.Location?.locality
                    )
                )
            }
            .sorted {
                let d1 = $0.schedule?.race?.date ?? ""
                let d2 = $1.schedule?.race?.date ?? ""
                return d1 < d2
            }
    }

    func roundForRaceDate(year: Int, raceDate: String) async throws -> Int? {
        let datePrefix = String(raceDate.prefix(10))
        guard !datePrefix.isEmpty else { return nil }
        let data = try await fetchData(path: "/\(year).json")
        let decoded = try JSONDecoder().decode(JolpicaSeasonResponse.self, from: data)
        let races = decoded.MRData.RaceTable.Races
        guard !races.isEmpty else { return nil }
        let withDate = races.compactMap { r -> (round: Int, date: String)? in
            let d = r.date
            guard !d.isEmpty else { return nil }
            return (r.roundInt, d)
        }
        if let match = withDate.first(where: { $0.date.hasPrefix(datePrefix) || String($0.date.prefix(10)) == datePrefix }) {
            return match.round
        }
        guard let given = Self.dateOnlyFormatter.date(from: datePrefix) else {
            return withDate.first?.round ?? races.first?.roundInt
        }
        var best: (round: Int, days: Int)?
        for r in withDate {
            guard let raceDay = Self.dateOnlyFormatter.date(from: String(r.date.prefix(10))) else { continue }
            let days = Calendar.current.dateComponents([.day], from: given, to: raceDay).day ?? 999
            let absDays = abs(days)
            if absDays <= 3, best == nil || absDays < best!.days {
                best = (r.round, absDays)
            }
        }
        return best?.round ?? withDate.first?.round ?? races.first?.roundInt
    }

    func raceResults(year: Int, round: Int) async throws -> [RaceResultRow] {
        let data = try await fetchData(path: "/\(year)/\(round)/results.json")
        let decoded = try JSONDecoder().decode(JolpicaRoundResultsResponse.self, from: data)
        guard let rows = decoded.MRData.RaceTable.Races.first?.Results else { return [] }
        return rows.map { r in
            RaceResultRow(
                position: r.positionInt,
                driverNumber: r.driverNumber,
                driverName: "\(r.Driver.givenName) \(r.Driver.familyName)".trimmingCharacters(in: .whitespaces),
                teamName: r.Constructor.name,
                time: r.Time?.time ?? r.status ?? "—",
                points: r.pointsInt
            )
        }
    }

    func sprintRaceResults(year: Int, round: Int) async -> [JolpicaSprintStandingRow] {
        guard let data = try? await fetchOptionalData(path: "/\(year)/\(round)/sprint.json"),
              let decoded = try? JSONDecoder().decode(JolpicaRoundSprintResponse.self, from: data),
              let rows = decoded.MRData.RaceTable.Races.first?.SprintResults
        else { return [] }
        return rows.map {
            JolpicaSprintStandingRow(
                position: $0.positionInt,
                points: $0.pointsInt,
                driver: JolpicaDriverBrief(
                    number: $0.driverNumber,
                    name: $0.Driver.givenName,
                    surname: $0.Driver.familyName
                )
            )
        }
    }

    func poleDriverNumber(year: Int, round: Int) async throws -> Int? {
        let data = try await fetchData(path: "/\(year)/\(round)/qualifying.json")
        let decoded = try JSONDecoder().decode(JolpicaRoundQualifyingResponse.self, from: data)
        guard let list = decoded.MRData.RaceTable.Races.first?.QualifyingResults else { return nil }
        return list.first(where: { $0.gridPosition == 1 })?.driverNumber
    }

    func qualyResults(year: Int, round: Int) async throws -> [JolpicaQualyGridRow] {
        let data = try await fetchData(path: "/\(year)/\(round)/qualifying.json")
        let decoded = try JSONDecoder().decode(JolpicaRoundQualifyingResponse.self, from: data)
        guard let list = decoded.MRData.RaceTable.Races.first?.QualifyingResults else { return [] }
        return list.map {
            JolpicaQualyGridRow(
                gridPosition: $0.gridPosition,
                driver: JolpicaDriverBrief(
                    number: $0.driverNumber,
                    name: $0.Driver.givenName,
                    surname: $0.Driver.familyName
                )
            )
        }
    }

    func sprintPointsByDriverNumber(year: Int, round: Int) async -> [Int: Int] {
        guard let data = try? await fetchOptionalData(path: "/\(year)/\(round)/sprint.json"),
              let decoded = try? JSONDecoder().decode(JolpicaRoundSprintResponse.self, from: data),
              let rows = decoded.MRData.RaceTable.Races.first?.SprintResults
        else { return [:] }
        var m: [Int: Int] = [:]
        for row in rows {
            m[row.driverNumber] = row.pointsInt
        }
        return m
    }

    /// Jolpica не отдаёт отдельный sprint qualy; берём старт с поула спринта (`grid == 1`).
    func sprintPoleDriverNumber(year: Int, round: Int) async -> Int? {
        guard let data = try? await fetchOptionalData(path: "/\(year)/\(round)/sprint.json"),
              let decoded = try? JSONDecoder().decode(JolpicaRoundSprintResponse.self, from: data),
              let rows = decoded.MRData.RaceTable.Races.first?.SprintResults
        else { return nil }
        return rows.first(where: { $0.gridInt == 1 })?.driverNumber
    }
}
