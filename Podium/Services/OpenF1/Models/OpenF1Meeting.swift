//
//  OpenF1Meeting.swift
//  Podium
//

import Foundation

struct OpenF1Meeting: Codable, Identifiable, Hashable {
    var meetingKey: Int
    var meetingName: String
    var meetingOfficialName: String?
    var location: String
    var countryName: String
    var countryCode: String
    var countryFlag: String?
    var circuitShortName: String
    var circuitType: String?
    var circuitImage: String?
    var circuitInfoUrl: String?
    var dateStart: String
    var dateEnd: String
    var year: Int
    var gmtOffset: String?

    var id: Int { meetingKey }

    private static let dateParsers: [DateFormatter] = {
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
        return formats.map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }
    }()

    var parsedDateStart: Date? {
        Self.dateParsers.lazy.compactMap { $0.date(from: dateStart) }.first
    }

    var parsedDateEnd: Date? {
        Self.dateParsers.lazy.compactMap { $0.date(from: dateEnd) }.first
    }

    enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case meetingOfficialName = "meeting_official_name"
        case location
        case countryName = "country_name"
        case countryCode = "country_code"
        case countryFlag = "country_flag"
        case circuitShortName = "circuit_short_name"
        case circuitType = "circuit_type"
        case circuitImage = "circuit_image"
        case circuitInfoUrl = "circuit_info_url"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case year
        case gmtOffset = "gmt_offset"
    }
}
