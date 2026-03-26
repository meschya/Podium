//
//  OpenF1ChampionshipDriver.swift
//  Podium
//

import Foundation

struct OpenF1ChampionshipDriver: Codable {
    var driverNumber: Int
    var sessionKey: Int
    var meetingKey: Int
    var positionCurrent: Int
    var positionStart: Int?
    /// Очки могут быть с половиной (0.5) — храним как `Double`.
    var pointsCurrent: Double
    var pointsStart: Double?
    var wins: Int
    var podiums: Int
    var poles: Int

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case positionCurrent = "position_current"
        case positionStart = "position_start"
        case pointsCurrent = "points_current"
        case pointsStart = "points_start"
        // Trophy stats: keys can vary between OpenF1 versions.
        case wins
        case winsCurrent = "wins_current"
        case podiums
        case podiumsCurrent = "podiums_current"
        case poles
        case polesCurrent = "poles_current"
        case polePositions = "pole_positions"
        case polePositionsCurrent = "pole_positions_current"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        driverNumber = try c.decode(Int.self, forKey: .driverNumber)
        sessionKey = try c.decode(Int.self, forKey: .sessionKey)
        meetingKey = try c.decode(Int.self, forKey: .meetingKey)
        positionCurrent = try c.decodeIntOrDouble(forKey: .positionCurrent)
        positionStart = try c.decodeIntOrDoubleIfPresent(forKey: .positionStart)
        pointsCurrent = try Self.decodePointsDouble(c, key: .pointsCurrent)
        pointsStart = try Self.decodePointsDoubleIfPresent(c, key: .pointsStart)
        wins =
            (try? c.decodeIntOrDoubleIfPresent(forKey: .wins)) ??
            (try? c.decodeIntOrDoubleIfPresent(forKey: .winsCurrent)) ??
            0
        podiums =
            (try? c.decodeIntOrDoubleIfPresent(forKey: .podiums)) ??
            (try? c.decodeIntOrDoubleIfPresent(forKey: .podiumsCurrent)) ??
            0
        poles =
            (try? c.decodeIntOrDoubleIfPresent(forKey: .poles)) ??
            (try? c.decodeIntOrDoubleIfPresent(forKey: .polesCurrent)) ??
            (try? c.decodeIntOrDoubleIfPresent(forKey: .polePositions)) ??
            (try? c.decodeIntOrDoubleIfPresent(forKey: .polePositionsCurrent)) ??
            0
    }

    private static func decodePointsDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        throw DecodingError.typeMismatch(Double.self, .init(codingPath: c.codingPath + [key], debugDescription: "points"))
    }

    private static func decodePointsDoubleIfPresent(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double? {
        if try c.decodeNil(forKey: key) { return nil }
        return try decodePointsDouble(c, key: key)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(driverNumber, forKey: .driverNumber)
        try c.encode(sessionKey, forKey: .sessionKey)
        try c.encode(meetingKey, forKey: .meetingKey)
        try c.encode(positionCurrent, forKey: .positionCurrent)
        try c.encodeIfPresent(positionStart, forKey: .positionStart)
        try c.encode(pointsCurrent, forKey: .pointsCurrent)
        try c.encodeIfPresent(pointsStart, forKey: .pointsStart)
        try c.encode(wins, forKey: .wins)
        try c.encode(podiums, forKey: .podiums)
        try c.encode(poles, forKey: .poles)
    }
}

private extension KeyedDecodingContainer {
    func decodeIntOrDouble(forKey key: Key) throws -> Int {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let d = try? decode(Double.self, forKey: key) { return Int(d.rounded()) }
        throw DecodingError.typeMismatch(Int.self, .init(codingPath: codingPath + [key], debugDescription: "Expected Int or Double"))
    }
    func decodeIntOrDoubleIfPresent(forKey key: Key) throws -> Int? {
        if try decodeNil(forKey: key) { return nil }
        return try decodeIntOrDouble(forKey: key)
    }
}
