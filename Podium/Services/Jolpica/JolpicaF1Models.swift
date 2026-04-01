//
//  JolpicaF1Models.swift
//  Podium — JSON shapes for https://api.jolpi.ca/ergast/f1 (Jolpica / Ergast-compatible).
//

import Foundation

// MARK: - Shared helpers

enum JolpicaDecode {
    static func intString(_ s: String?) -> Int {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return 0 }
        return Int(s) ?? 0
    }
}

// MARK: - Season schedule (GET /f1/{year}.json)

struct JolpicaSeasonResponse: Decodable {
    var MRData: JolpicaSeasonMRData
}

struct JolpicaSeasonMRData: Decodable {
    var RaceTable: JolpicaSeasonRaceTable
}

struct JolpicaSeasonRaceTable: Decodable {
    var Races: [JolpicaSeasonRace]
}

/// Уик-энд сезона: дата ГП и признак спринта (ключ `Sprint` в JSON).
struct JolpicaSeasonRace: Decodable {
    var round: String
    var date: String
    var Sprint: JolpicaSessionStub?

    struct JolpicaSessionStub: Decodable {}

    var roundInt: Int { JolpicaDecode.intString(round) }
}

// MARK: - Drivers list (GET /f1/{year}/drivers.json)

struct JolpicaDriversResponse: Decodable {
    var MRData: JolpicaDriversMRData
}

struct JolpicaDriversMRData: Decodable {
    var DriverTable: JolpicaDriverTable
}

struct JolpicaDriverTable: Decodable {
    var Drivers: [JolpicaDriver]
}

struct JolpicaDriver: Decodable {
    var driverId: String
    var permanentNumber: String?
    var givenName: String
    var familyName: String
}

// MARK: - Driver GP results (GET /f1/{year}/drivers/{id}/results.json)

struct JolpicaDriverGpResultsResponse: Decodable {
    var MRData: JolpicaDriverGpMRData
}

struct JolpicaDriverGpMRData: Decodable {
    var RaceTable: JolpicaDriverGpRaceTable
}

struct JolpicaDriverGpRaceTable: Decodable {
    var Races: [JolpicaDriverGpRace]
}

struct JolpicaDriverGpRace: Decodable {
    var round: String
    var date: String
    var Results: [JolpicaGpResultRow]

    var roundInt: Int { JolpicaDecode.intString(round) }
}

struct JolpicaGpResultRow: Decodable {
    var number: String
    var position: String
    var positionText: String?
    var points: String
    var grid: String
    var status: String
    var Time: JolpicaResultTime?

    struct JolpicaResultTime: Decodable {
        var time: String?
    }

    var driverNumber: Int { JolpicaDecode.intString(number) }
    var positionInt: Int { JolpicaDecode.intString(position) }
    var pointsInt: Int { JolpicaDecode.intString(points) }
    var gridInt: Int { JolpicaDecode.intString(grid) }
}

// MARK: - Driver sprint races (GET /f1/{year}/drivers/{id}/sprint.json)

struct JolpicaDriverSprintResponse: Decodable {
    var MRData: JolpicaDriverSprintMRData
}

struct JolpicaDriverSprintMRData: Decodable {
    var RaceTable: JolpicaDriverSprintRaceTable
}

struct JolpicaDriverSprintRaceTable: Decodable {
    var Races: [JolpicaDriverSprintRace]
}

struct JolpicaDriverSprintRace: Decodable {
    var round: String
    var date: String
    var SprintResults: [JolpicaSprintResultRow]

    var roundInt: Int { JolpicaDecode.intString(round) }
}

struct JolpicaSprintResultRow: Decodable {
    var number: String
    var position: String
    var positionText: String?
    var points: String
    var grid: String
    var status: String

    var driverNumber: Int { JolpicaDecode.intString(number) }
    var positionInt: Int { JolpicaDecode.intString(position) }
    var pointsInt: Int { JolpicaDecode.intString(points) }
    var gridInt: Int { JolpicaDecode.intString(grid) }
}
