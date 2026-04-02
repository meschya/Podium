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

    init(sessionKey: Int, meetingKey: Int, sessionName: String, dateStart: String?, dateEnd: String?, year: Int?) {
        self.sessionKey = sessionKey
        self.meetingKey = meetingKey
        self.sessionName = sessionName
        self.sessionType = nil
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.year = year
    }

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case sessionName = "session_name"
        case sessionType = "session_type"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case year
    }

    /// Воскресная гонка Гран-при. На спринт-уикенде две сессии с именем `Race` (суббота + воскресенье) — нужна **поздняя по времени** (ГП), иначе championship/очки относятся к спринту и график ломается.
    static func grandPrixRaceSession(in sessions: [OpenF1Session]) -> OpenF1Session? {
        let namedRace = sessions.filter { $0.sessionName == "Race" }
        if namedRace.count >= 2 {
            return namedRace.max(by: { ($0.dateStart ?? "") < ($1.dateStart ?? "") })
        }
        if let one = namedRace.first { return one }
        return sessions
            .filter { $0.sessionType?.lowercased().contains("race") == true }
            .max(by: { ($0.dateStart ?? "") < ($1.dateStart ?? "") })
    }

    /// Основная квалификация на уик-энд (сетка воскресной гонки), не Sprint Qualifying.
    static func grandPrixQualifyingSession(in sessions: [OpenF1Session]) -> OpenF1Session? {
        if let q = sessions.first(where: { $0.sessionName == "Qualifying" }) {
            return q
        }
        return sessions.first { s in
            let n = s.sessionName.lowercased()
            return n.contains("qualifying") && !n.contains("sprint")
        }
    }
}
