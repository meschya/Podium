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

/// Клиент Jolpica F1 API — агрегаты по сезону для экрана гонщика (мало запросов вместо N× f1api по раунду).
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
}
