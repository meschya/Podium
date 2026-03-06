//
//  OpenF1Position.swift
//  Podium
//

import Foundation

struct OpenF1Position: Codable {
    var date: String
    var sessionKey: Int
    var meetingKey: Int
    var driverNumber: Int
    var position: Int

    enum CodingKeys: String, CodingKey {
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case driverNumber = "driver_number"
        case position
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        sessionKey = try c.decode(Int.self, forKey: .sessionKey)
        meetingKey = try c.decode(Int.self, forKey: .meetingKey)
        driverNumber = try c.decode(Int.self, forKey: .driverNumber)
        if let p = try? c.decode(Int.self, forKey: .position) {
            position = p
        } else if let s = try? c.decode(String.self, forKey: .position), let p = Int(s) {
            position = p
        } else {
            position = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(sessionKey, forKey: .sessionKey)
        try c.encode(meetingKey, forKey: .meetingKey)
        try c.encode(driverNumber, forKey: .driverNumber)
        try c.encode(position, forKey: .position)
    }
}
