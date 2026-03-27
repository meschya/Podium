//
//  F1APIQualyResponse.swift
//  Podium — GET https://f1api.dev/api/{year}/{round}/qualy
//

import Foundation

struct F1APIQualyResponse: Decodable {
    var races: F1APIQualyRacePayload
}

struct F1APIQualyRacePayload: Decodable {
    var qualyResults: [F1APIQualyRow]
}

struct F1APIQualyRow: Decodable {
    var gridPosition: Int
    var driver: F1APIDriver

    enum CodingKeys: String, CodingKey {
        case gridPosition, driver
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gridPosition = Self.decodeInt(from: c, key: .gridPosition)
        driver = try c.decode(F1APIDriver.self, forKey: .driver)
    }

    private static func decodeInt(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
        return 0
    }
}
