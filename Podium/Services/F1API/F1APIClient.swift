//
//  F1APIClient.swift
//  Podium
//

import Foundation

/// Совместимый слой над Jolpica (`https://api.jolpi.ca/ergast/f1`): те же типы, что раньше с f1api.dev.
final class F1APIClient {
    static let shared = F1APIClient()
    private let baseURL = "https://api.jolpi.ca/ergast/f1"
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func jolpicaURL(path: String) throws -> URL {
        let sep = path.contains("?") ? "&" : "?"
        guard let u = URL(string: "\(baseURL)\(path)\(sep)limit=2000") else { throw F1APIError.invalidURL }
        return u
    }

    private func fetch(path: String) async throws -> Data {
        let url = try jolpicaURL(path: path)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw F1APIError.noData }
        guard (200..<300).contains(http.statusCode) else { throw F1APIError.server(http.statusCode) }
        return data
    }

    /// 404 → `nil` data (нет спринта / нет ресурса).
    private func fetchOptional(path: String) async throws -> Data? {
        let url = try jolpicaURL(path: path)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw F1APIError.server(http.statusCode) }
        return data
    }

    /// GET `/{year}.json` — календарь сезона.
    func seasonCalendar(year: Int) async throws -> [F1APIRaceInfo] {
        let data = try await fetch(path: "/\(year).json")
        let decoded = try JSONDecoder().decode(JolpicaSeasonResponse.self, from: data)
        return decoded.MRData.RaceTable.Races
            .map { r in
                F1APIRaceInfo(
                    round: r.roundInt,
                    raceName: r.raceName,
                    schedule: F1APISchedule(race: F1APIRaceDate(date: r.date)),
                    circuit: F1APICircuitInfo(
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
        let data = try await fetch(path: "/\(year).json")
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
        var best: (round: Int, days: Int)? = nil
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
        let data = try await fetch(path: "/\(year)/\(round)/results.json")
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

    func sprintPointsByDriverNumber(year: Int, round: Int) async -> [Int: Int] {
        guard let data = try? await fetchOptional(path: "/\(year)/\(round)/sprint.json"),
              let decoded = try? JSONDecoder().decode(JolpicaRoundSprintResponse.self, from: data),
              let rows = decoded.MRData.RaceTable.Races.first?.SprintResults
        else { return [:] }
        var m: [Int: Int] = [:]
        for row in rows {
            m[row.driverNumber] = row.pointsInt
        }
        return m
    }

    func sprintRaceResults(year: Int, round: Int) async -> [F1APISprintRow] {
        guard let data = try? await fetchOptional(path: "/\(year)/\(round)/sprint.json"),
              let decoded = try? JSONDecoder().decode(JolpicaRoundSprintResponse.self, from: data),
              let rows = decoded.MRData.RaceTable.Races.first?.SprintResults
        else { return [] }
        return rows.map {
            F1APISprintRow(
                position: $0.positionInt,
                points: $0.pointsInt,
                driver: F1APIDriver(
                    number: $0.driverNumber,
                    name: $0.Driver.givenName,
                    surname: $0.Driver.familyName
                )
            )
        }
    }

    func poleDriverNumber(year: Int, round: Int) async throws -> Int? {
        let data = try await fetch(path: "/\(year)/\(round)/qualifying.json")
        let decoded = try JSONDecoder().decode(JolpicaRoundQualifyingResponse.self, from: data)
        guard let list = decoded.MRData.RaceTable.Races.first?.QualifyingResults else { return nil }
        return list.first(where: { $0.gridPosition == 1 })?.driverNumber
    }

    func qualyResults(year: Int, round: Int) async throws -> [F1APIQualyRow] {
        let data = try await fetch(path: "/\(year)/\(round)/qualifying.json")
        let decoded = try JSONDecoder().decode(JolpicaRoundQualifyingResponse.self, from: data)
        guard let list = decoded.MRData.RaceTable.Races.first?.QualifyingResults else { return [] }
        return list.map {
            F1APIQualyRow(
                gridPosition: $0.gridPosition,
                driver: F1APIDriver(
                    number: $0.driverNumber,
                    name: $0.Driver.givenName,
                    surname: $0.Driver.familyName
                )
            )
        }
    }

    /// Jolpica не отдаёт отдельный sprint qualy; берём старт с поула спринта (`grid == 1`).
    func sprintPoleDriverNumber(year: Int, round: Int) async -> Int? {
        guard let data = try? await fetchOptional(path: "/\(year)/\(round)/sprint.json"),
              let decoded = try? JSONDecoder().decode(JolpicaRoundSprintResponse.self, from: data),
              let rows = decoded.MRData.RaceTable.Races.first?.SprintResults
        else { return nil }
        return rows.first(where: { $0.gridInt == 1 })?.driverNumber
    }
}

enum F1APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data"
        case .server(let code): return "Server error: \(code)"
        }
    }
}
