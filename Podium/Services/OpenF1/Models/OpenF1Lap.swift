//
//  OpenF1Lap.swift
//  Podium
//

import Foundation

struct OpenF1Lap: Codable {
    var sessionKey: Int?
    var meetingKey: Int?
    var driverNumber: Int?
    var lapNumber: Int?
    var lapDuration: Double?
    var durationSector1: Double?
    var durationSector2: Double?
    var durationSector3: Double?

    /// Total lap time in seconds: lap_duration if present, else sum of sectors.
    var effectiveLapDuration: Double? {
        if let d = lapDuration, d > 0 { return d }
        guard let s1 = durationSector1, let s2 = durationSector2, let s3 = durationSector3,
              s1 > 0, s2 > 0, s3 > 0 else { return nil }
        return s1 + s2 + s3
    }

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case lapDuration = "lap_duration"
        case durationSector1 = "duration_sector_1"
        case durationSector2 = "duration_sector_2"
        case durationSector3 = "duration_sector_3"
    }
}
