//
//  OpenF1Session.swift
//  Podium
//

import Foundation

struct OpenF1Session: Codable, Identifiable {
    var sessionKey: Int
    var meetingKey: Int
    var sessionName: String
    var sessionType: String?
    var dateStart: String?
    var dateEnd: String?
    var year: Int?

    var id: Int { sessionKey }

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case sessionName = "session_name"
        case sessionType = "session_type"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case year
    }
}
