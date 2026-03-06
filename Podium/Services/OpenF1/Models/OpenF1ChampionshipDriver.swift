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
    var pointsCurrent: Int
    var pointsStart: Int?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case positionCurrent = "position_current"
        case positionStart = "position_start"
        case pointsCurrent = "points_current"
        case pointsStart = "points_start"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        driverNumber = try c.decode(Int.self, forKey: .driverNumber)
        sessionKey = try c.decode(Int.self, forKey: .sessionKey)
        meetingKey = try c.decode(Int.self, forKey: .meetingKey)
        positionCurrent = try c.decodeIntOrDouble(forKey: .positionCurrent)
        positionStart = try c.decodeIntOrDoubleIfPresent(forKey: .positionStart)
        pointsCurrent = try c.decodeIntOrDouble(forKey: .pointsCurrent)
        pointsStart = try c.decodeIntOrDoubleIfPresent(forKey: .pointsStart)
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
