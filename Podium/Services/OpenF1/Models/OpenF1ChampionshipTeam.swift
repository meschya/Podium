import Foundation

struct OpenF1ChampionshipTeam: Codable {
    var teamName: String
    var sessionKey: Int
    var meetingKey: Int
    var positionCurrent: Int
    var positionStart: Int?
    var pointsCurrent: Int
    var pointsStart: Int?

    enum CodingKeys: String, CodingKey {
        case teamName = "team_name"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case positionCurrent = "position_current"
        case positionStart = "position_start"
        case pointsCurrent = "points_current"
        case pointsStart = "points_start"
    }
}
