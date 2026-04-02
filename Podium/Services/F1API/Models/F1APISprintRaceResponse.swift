//
//  F1APISprintRaceResponse.swift
//  Podium — спринт маппится из Jolpica `/{year}/{round}/sprint.json`
//

import Foundation

struct F1APISprintRaceResponse: Decodable {
    var races: F1APISprintRacePayload
}

struct F1APISprintRacePayload: Decodable {
    var sprintRaceResults: [F1APISprintRow]
}

struct F1APISprintRow: Decodable {
    var position: Int
    var points: Int
    var driver: F1APIDriver

    enum CodingKeys: String, CodingKey {
        case position, points, driver
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        position = Self.decodeInt(from: c, key: .position)
        points = Self.decodeInt(from: c, key: .points)
        driver = try c.decode(F1APIDriver.self, forKey: .driver)
    }

    private static func decodeInt(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
        return 0
    }

    init(position: Int, points: Int, driver: F1APIDriver) {
        self.position = position
        self.points = points
        self.driver = driver
    }
}
