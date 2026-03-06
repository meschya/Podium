//
//  OpenF1Interval.swift
//  Podium
//

import Foundation

struct OpenF1Interval: Codable {
    var date: String
    var driverNumber: Int
    var sessionKey: Int
    var meetingKey: Int
    var gapToLeader: GapToLeader?
    var interval: GapToLeader?

    enum CodingKeys: String, CodingKey {
        case date
        case driverNumber = "driver_number"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case gapToLeader = "gap_to_leader"
        case interval
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        driverNumber = try c.decode(Int.self, forKey: .driverNumber)
        sessionKey = try c.decode(Int.self, forKey: .sessionKey)
        meetingKey = try c.decode(Int.self, forKey: .meetingKey)
        gapToLeader = try c.decodeNil(forKey: .gapToLeader) ? nil : try c.decode(GapToLeader.self, forKey: .gapToLeader)
        interval = try c.decodeNil(forKey: .interval) ? nil : try c.decode(GapToLeader.self, forKey: .interval)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(driverNumber, forKey: .driverNumber)
        try c.encode(sessionKey, forKey: .sessionKey)
        try c.encode(meetingKey, forKey: .meetingKey)
        try c.encodeIfPresent(gapToLeader, forKey: .gapToLeader)
        try c.encodeIfPresent(interval, forKey: .interval)
    }
}
