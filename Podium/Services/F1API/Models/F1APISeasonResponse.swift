//
//  F1APISeasonResponse.swift
//  Podium
//

import Foundation

/// Response for GET https://f1api.dev/api/{year} — календарь сезона с официальными round.
struct F1APISeasonResponse: Decodable {
    var season: Int
    var races: [F1APIRaceInfo]
}

struct F1APIRaceInfo: Decodable {
    var round: Int
    var raceName: String?
    var schedule: F1APISchedule?
    var circuit: F1APICircuitInfo?
}

struct F1APICircuitInfo: Decodable {
    var circuitName: String?
    var country: String?
    var city: String?
}

struct F1APISchedule: Decodable {
    var race: F1APIRaceDate?
}

struct F1APIRaceDate: Decodable {
    var date: String?
}
