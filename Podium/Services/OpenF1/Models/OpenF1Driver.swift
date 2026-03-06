//
//  OpenF1Driver.swift
//  Podium
//

import Foundation

struct OpenF1Driver: Codable, Identifiable {
    var driverNumber: Int
    var fullName: String
    var firstName: String?
    var lastName: String?
    var broadcastName: String?
    var nameAcronym: String?
    var teamName: String?
    var teamColour: String?
    var headshotUrl: String?
    var sessionKey: Int?
    var meetingKey: Int?

    var id: Int { driverNumber }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case broadcastName = "broadcast_name"
        case nameAcronym = "name_acronym"
        case teamName = "team_name"
        case teamColour = "team_colour"
        case headshotUrl = "headshot_url"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
