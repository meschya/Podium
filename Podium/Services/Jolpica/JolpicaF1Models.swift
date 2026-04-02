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

/// Слот сессии в календаре Ergast (`date` + `time` UTC).
struct JolpicaErgastSessionTime: Decodable {
    var date: String
    var time: String?
}

/// Уик-энд сезона: дата ГП, трасса, сессии (FP / спринт / квалификация / гонка).
struct JolpicaSeasonRace: Decodable {
    var round: String
    var date: String
    var time: String?
    var raceName: String?
    var Circuit: JolpicaSeasonCircuit?
    var FirstPractice: JolpicaErgastSessionTime?
    var SecondPractice: JolpicaErgastSessionTime?
    var ThirdPractice: JolpicaErgastSessionTime?
    var Qualifying: JolpicaErgastSessionTime?
    var Sprint: JolpicaErgastSessionTime?
    var SprintQualifying: JolpicaErgastSessionTime?

    struct JolpicaSeasonCircuit: Decodable {
        var circuitId: String?
        var circuitName: String?
        var Location: JolpicaSeasonLocation?
    }

    struct JolpicaSeasonLocation: Decodable {
        var locality: String?
        var country: String?
    }

    var roundInt: Int { JolpicaDecode.intString(round) }
}

// MARK: - Ergast driver/constructor on result rows

struct JolpicaErgastNameDriver: Decodable {
    var givenName: String
    var familyName: String
    var permanentNumber: String?
}

struct JolpicaErgastConstructor: Decodable {
    var name: String
}

// MARK: - Single round race results (GET /f1/{year}/{round}/results.json)

struct JolpicaRoundResultsResponse: Decodable {
    var MRData: JolpicaRoundResultsMRData
}

struct JolpicaRoundResultsMRData: Decodable {
    var RaceTable: JolpicaRoundResultsRaceTable
}

struct JolpicaRoundResultsRaceTable: Decodable {
    var Races: [JolpicaRoundRaceWithResults]
}

struct JolpicaRoundRaceWithResults: Decodable {
    var Results: [JolpicaRaceResultRow]
}

struct JolpicaRaceResultRow: Decodable {
    var number: String
    var position: String
    var points: String
    var status: String?
    var Time: JolpicaGpResultRow.JolpicaResultTime?
    var Driver: JolpicaErgastNameDriver
    var Constructor: JolpicaErgastConstructor

    var positionInt: Int { JolpicaDecode.intString(position) }
    var driverNumber: Int { JolpicaDecode.intString(number) }
    var pointsInt: Int { JolpicaDecode.intString(points) }
}

// MARK: - Qualifying (GET /f1/{year}/{round}/qualifying.json)

struct JolpicaRoundQualifyingResponse: Decodable {
    var MRData: JolpicaRoundQualifyingMRData
}

struct JolpicaRoundQualifyingMRData: Decodable {
    var RaceTable: JolpicaRoundQualifyingRaceTable
}

struct JolpicaRoundQualifyingRaceTable: Decodable {
    var Races: [JolpicaRoundQualifyingRace]
}

struct JolpicaRoundQualifyingRace: Decodable {
    var QualifyingResults: [JolpicaQualifyingResultRow]
}

struct JolpicaQualifyingResultRow: Decodable {
    var number: String
    var position: String
    var Driver: JolpicaErgastNameDriver

    var gridPosition: Int { JolpicaDecode.intString(position) }
    var driverNumber: Int { JolpicaDecode.intString(number) }
}

// MARK: - Sprint race (GET /f1/{year}/{round}/sprint.json)

struct JolpicaRoundSprintResponse: Decodable {
    var MRData: JolpicaRoundSprintMRData
}

struct JolpicaRoundSprintMRData: Decodable {
    var RaceTable: JolpicaRoundSprintRaceTable
}

struct JolpicaRoundSprintRaceTable: Decodable {
    var Races: [JolpicaRoundSprintRace]
}

struct JolpicaRoundSprintRace: Decodable {
    var SprintResults: [JolpicaSprintTableRow]
}

struct JolpicaSprintTableRow: Decodable {
    var number: String
    var position: String
    var points: String
    var grid: String
    var Driver: JolpicaErgastNameDriver

    var positionInt: Int { JolpicaDecode.intString(position) }
    var pointsInt: Int { JolpicaDecode.intString(points) }
    var driverNumber: Int { JolpicaDecode.intString(number) }
    var gridInt: Int { JolpicaDecode.intString(grid) }
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
