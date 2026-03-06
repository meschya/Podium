//
//  OpenF1Pit.swift
//  Podium
//

import Foundation

struct OpenF1Pit: Codable {
    var date: String
    var driverNumber: Int
    var sessionKey: Int
    var meetingKey: Int
    var lapNumber: Int?
    var pitDuration: Double?
    var laneDuration: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case driverNumber = "driver_number"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case lapNumber = "lap_number"
        case pitDuration = "pit_duration"
        case laneDuration = "lane_duration"
    }
}
