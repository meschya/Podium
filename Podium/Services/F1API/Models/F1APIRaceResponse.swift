//
//  F1APIRaceResponse.swift
//  Podium
//

import Foundation

/// Старый формат f1api.dev; гонка маппится из Jolpica `/{year}/{round}/results.json`.
struct F1APIRaceResponse: Decodable {
    var season: Int
    var races: F1APIRace
}

struct F1APIRace: Decodable {
    var round: String
    var results: [F1APIResult]
}

struct F1APIResult: Decodable {
    var position: Int
    var points: Int
    var time: String?
    var driver: F1APIDriver
    var team: F1APITeam

    enum CodingKeys: String, CodingKey {
        case position, points, time, driver, team
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        position = Self.decodeInt(from: c, key: .position)
        points = Self.decodeInt(from: c, key: .points)
        time = try c.decodeIfPresent(String.self, forKey: .time)
        driver = try c.decode(F1APIDriver.self, forKey: .driver)
        team = try c.decode(F1APITeam.self, forKey: .team)
    }

    private static func decodeInt(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
        return 0
    }
}

struct F1APIDriver: Decodable {
    var number: Int
    var name: String
    var surname: String

    init(number: Int, name: String, surname: String) {
        self.number = number
        self.name = name
        self.surname = surname
    }
}

struct F1APITeam: Decodable {
    var teamName: String
}
