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

    /// Сначала ISO8601 и форматы с временем — иначе `yyyy-MM-dd` «съедает» только дату и даёт полночь вместо реального старта (ломает таймер героя и окна live-сессий).
    private static func parseMeetingInstant(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
        ]
        for format in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            f.timeZone = TimeZone(identifier: "UTC")
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    var parsedDateStart: Date? {
        Self.parseMeetingInstant(dateStart)
    }

    var parsedDateEnd: Date? {
        Self.parseMeetingInstant(dateEnd)
    }

    init(
        meetingKey: Int,
        meetingName: String,
        meetingOfficialName: String?,
        location: String,
        countryName: String,
        countryCode: String,
        countryFlag: String?,
        circuitShortName: String,
        circuitType: String?,
        circuitImage: String?,
        circuitInfoUrl: String?,
        dateStart: String,
        dateEnd: String,
        year: Int,
        gmtOffset: String?
    ) {
        self.meetingKey = meetingKey
        self.meetingName = meetingName
        self.meetingOfficialName = meetingOfficialName
        self.location = location
        self.countryName = countryName
        self.countryCode = countryCode
        self.countryFlag = countryFlag
        self.circuitShortName = circuitShortName
        self.circuitType = circuitType
        self.circuitImage = circuitImage
        self.circuitInfoUrl = circuitInfoUrl
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.year = year
        self.gmtOffset = gmtOffset
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
