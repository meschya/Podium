//
//  F1APIClient.swift
//  Podium
//

import Foundation

/// Client for https://f1api.dev — historical race results (1950+).
final class F1APIClient {
    static let shared = F1APIClient()
    private let baseURL = "https://f1api.dev"
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

    /// GET /api/{year} — календарь сезона (список гонок для карточек).
    func seasonCalendar(year: Int) async throws -> [F1APIRaceInfo] {
        guard let url = URL(string: "\(baseURL)/api/\(year)") else { throw F1APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw F1APIError.noData }
        let decoded = try JSONDecoder().decode(F1APISeasonResponse.self, from: data)
        return decoded.races.sorted { (r1, r2) in
            let d1 = r1.schedule?.race?.date ?? ""
            let d2 = r2.schedule?.race?.date ?? ""
            return d1 < d2
        }
    }

    /// Round по дате гонки или по уик-энду (пятница/суббота → воскресная гонка).
    func roundForRaceDate(year: Int, raceDate: String) async throws -> Int? {
        let datePrefix = String(raceDate.prefix(10))
        guard !datePrefix.isEmpty else { return nil }
        guard let url = URL(string: "\(baseURL)/api/\(year)") else { throw F1APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let decoded = try? JSONDecoder().decode(F1APISeasonResponse.self, from: data)
        guard let races = decoded?.races, !races.isEmpty else { return nil }
        let withDate = races.compactMap { r -> (round: Int, date: String)? in
            guard let date = r.schedule?.race?.date, !date.isEmpty else { return nil }
            return (r.round, date)
        }
        if let match = withDate.first(where: { $0.date.hasPrefix(datePrefix) || String($0.date.prefix(10)) == datePrefix }) {
            return match.round
        }
        guard let given = Self.dateOnlyFormatter.date(from: datePrefix) else {
            return withDate.first?.round ?? races.first?.round
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
        return best?.round ?? withDate.first?.round ?? races.first?.round
    }

    /// GET /api/{year}/{round}/race — returns results for one race.
    func raceResults(year: Int, round: Int) async throws -> [RaceResultRow] {
        let urlString = "\(baseURL)/api/\(year)/\(round)/race"
        guard let url = URL(string: urlString) else { throw F1APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw F1APIError.noData }
        guard (200..<300).contains(http.statusCode) else { throw F1APIError.server(http.statusCode) }
        let decoded = try JSONDecoder().decode(F1APIRaceResponse.self, from: data)
        return decoded.races.results.map { r in
            RaceResultRow(
                position: r.position,
                driverNumber: r.driver.number,
                driverName: "\(r.driver.name) \(r.driver.surname)".trimmingCharacters(in: .whitespaces),
                teamName: r.team.teamName,
                time: r.time ?? "—",
                points: r.points
            )
        }
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
