//
//  OpenF1Location.swift
//  Podium
//

import Foundation

struct OpenF1Location: Codable {
    var date: String
    var driverNumber: Int
    var sessionKey: Int
    var meetingKey: Int
    var x: Int
    var y: Int
    var z: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case driverNumber = "driver_number"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case x, y, z
    }
}
