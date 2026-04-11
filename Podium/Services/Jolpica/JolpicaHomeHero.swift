//
//  JolpicaHomeHero.swift
//  Podium — герой главной: встреча + сессии из Jolpica (Ergast).
//

import Foundation

enum JolpicaHomeHero {

    static func syntheticMeetingKey(year: Int, round: Int) -> Int {
        year * 1000 + min(99, max(1, round))
    }

    static func pickNextOrCurrent(races: [JolpicaSeasonRace], now: Date) -> JolpicaSeasonRace? {
        let sorted = races.sorted { $0.date < $1.date }
        let pick = sorted.first { r in
            guard let start = utcStartDate(race: r, session: nil, useMainRaceDate: true),
                  let end = weekendEndDate(race: r) else { return false }
            return (start <= now && now <= end) || start >= now
        }
        return pick ?? sorted.last
    }

    static func sameRaceWeekend(openF1 m: OpenF1Meeting, jolpica j: JolpicaSeasonRace) -> Bool {
        let jPrefix = String(j.date.prefix(10))
        guard !jPrefix.isEmpty else { return false }
        if m.dateStart.hasPrefix(jPrefix) { return true }
        guard let start = m.parsedDateStart else { return false }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        guard let jd = f.date(from: jPrefix) else { return false }
        let days = Calendar.current.dateComponents([.day], from: start, to: jd).day ?? 99
        return abs(days) <= 3
    }

    static func openF1Meeting(from race: JolpicaSeasonRace, year: Int) -> OpenF1Meeting? {
        let mk = syntheticMeetingKey(year: year, round: race.roundInt)
        let loc = race.Circuit?.Location?.locality ?? ""
        let country = race.Circuit?.Location?.country ?? ""
        let circuitName = race.Circuit?.circuitName ?? ""
        let title = race.raceName ?? "Grand Prix"
        let dateStart = iso8601UTC(date: race.date, time: race.time) ?? race.date
        let dateEnd: String = {
            guard let end = weekendEndDate(race: race) else { return dateStart }
            return formatInstantUTC(end)
        }()
        let cc = countryCode(fromCountryName: country)
        return OpenF1Meeting(
            meetingKey: mk,
            meetingName: title,
            meetingOfficialName: nil,
            location: loc.isEmpty ? circuitName : loc,
            countryName: country,
            countryCode: cc,
            countryFlag: nil,
            circuitShortName: circuitShortLabel(circuitName: circuitName, locality: loc),
            circuitType: nil,
            circuitImage: nil,
            circuitInfoUrl: nil,
            dateStart: dateStart,
            dateEnd: dateEnd,
            year: year,
            gmtOffset: nil
        )
    }

    static func openF1Sessions(from race: JolpicaSeasonRace, meetingKey: Int) -> [OpenF1Session] {
        var pairs: [(name: String, slot: JolpicaErgastSessionTime)] = []
        if let s = race.FirstPractice { pairs.append(("Practice 1", s)) }
        if let s = race.SecondPractice { pairs.append(("Practice 2", s)) }
        if let s = race.ThirdPractice { pairs.append(("Practice 3", s)) }
        if let s = race.SprintQualifying { pairs.append(("Sprint Qualifying", s)) }
        if let s = race.Sprint { pairs.append(("Sprint", s)) }
        if let s = race.Qualifying { pairs.append(("Qualifying", s)) }
        if let s = raceSlotAsSessionTime(race) {
            pairs.append(("Race", s))
        }
        let ordered = pairs.compactMap { pair -> (String, JolpicaErgastSessionTime, Date)? in
            guard let start = utcStartDate(race: race, session: pair.slot, useMainRaceDate: false) else { return nil }
            return (pair.name, pair.slot, start)
        }.sorted { $0.2 < $1.2 }

        // Строки dateStart/dateEnd должны быть ровно тем же мгновением, что triplet.2 (utcStartDate).
        // Раньше dateStart брался из iso8601UTC(slot) — при расхождении с ISO8601DateFormatter в чарте
        // parseDate давал другой Date, чем длительность от triplet.2: подпись «19:30» и положение на шкале расходились.
        return ordered.enumerated().map { idx, triplet in
            let name = triplet.0
            let startDate = triplet.2
            let startStr = formatInstantUTC(startDate)
            let dur = sessionDurationSeconds(sessionName: name)
            let endDate = startDate.addingTimeInterval(dur)
            let endStr = formatInstantUTC(endDate)
            let sk = meetingKey * 100 + idx + 1
            return OpenF1Session(
                sessionKey: sk,
                meetingKey: meetingKey,
                sessionName: name,
                dateStart: startStr,
                dateEnd: endStr,
                year: nil
            )
        }
    }

    // MARK: - Private

    private static func raceSlotAsSessionTime(_ race: JolpicaSeasonRace) -> JolpicaErgastSessionTime? {
        JolpicaErgastSessionTime(date: String(race.date.prefix(10)), time: race.time)
    }

    private static func circuitShortLabel(circuitName: String, locality: String) -> String {
        let n = circuitName.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { return n }
        return locality.trimmingCharacters(in: .whitespaces)
    }

    private static func countryCode(fromCountryName country: String) -> String {
        let lower = country.lowercased()
        let map: [String: String] = [
            "australia": "AU", "bahrain": "BH", "china": "CN", "japan": "JP", "saudi arabia": "SA",
            "united states": "US", "italy": "IT", "monaco": "MC", "spain": "ES", "canada": "CA",
            "austria": "AT", "great britain": "GB", "united kingdom": "GB", "uk": "GB", "hungary": "HU", "belgium": "BE",
            "netherlands": "NL", "azerbaijan": "AZ", "singapore": "SG", "mexico": "MX",
            "brazil": "BR", "united arab emirates": "AE", "uae": "AE", "qatar": "QA", "usa": "US"
        ]
        if let c = map[lower] { return c }
        let u = country.uppercased()
        if u == "UK" { return "GB" }
        if u == "UAE" { return "AE" }
        return String(country.prefix(2)).uppercased()
    }

    /// Стабильная строка для парсинга в `SessionTimelineChart` / OpenF1-совместимый UI.
    private static func formatInstantUTC(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.string(from: d) + "Z"
    }

    private static func iso8601UTC(date: String, time: String?) -> String? {
        let d = String(date.prefix(10))
        guard d.count == 10 else { return nil }
        let t = (time?.isEmpty == false) ? time! : "12:00:00Z"
        let norm: String
        if t.hasSuffix("Z") {
            let core = String(t.dropLast())
            norm = core
        } else {
            norm = t
        }
        return "\(d)T\(norm)Z"
    }

    private static func utcStartDate(race: JolpicaSeasonRace, session: JolpicaErgastSessionTime?, useMainRaceDate: Bool) -> Date? {
        let iso: String?
        if useMainRaceDate {
            iso = iso8601UTC(date: race.date, time: race.time)
        } else if let s = session {
            iso = iso8601UTC(date: s.date, time: s.time)
        } else {
            iso = nil
        }
        guard let iso else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let x = fmt.date(from: iso) { return x }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: iso)
    }

    private static func weekendEndDate(race: JolpicaSeasonRace) -> Date? {
        var latest: Date?
        func bump(_ name: String, _ slot: JolpicaErgastSessionTime?) {
            guard let slot, let st = utcStartDate(race: race, session: slot, useMainRaceDate: false) else { return }
            let en = st.addingTimeInterval(sessionDurationSeconds(sessionName: name))
            if latest == nil || en > latest! { latest = en }
        }
        bump("Practice 1", race.FirstPractice)
        bump("Practice 2", race.SecondPractice)
        bump("Practice 3", race.ThirdPractice)
        bump("Sprint Qualifying", race.SprintQualifying)
        bump("Sprint", race.Sprint)
        bump("Qualifying", race.Qualifying)
        bump("Race", raceSlotAsSessionTime(race))
        return latest.map { $0.addingTimeInterval(3600) }
    }

    private static func sessionDurationSeconds(sessionName: String) -> TimeInterval {
        let l = sessionName.lowercased()
        if l.contains("sprint") && l.contains("qualifying") { return 3600 }
        if l.contains("practice") { return 1.5 * 3600 }
        if l == "sprint" { return 45 * 60 }
        if l.contains("qualifying") { return 1.25 * 3600 }
        if l.contains("race") { return 2.5 * 3600 }
        return 3600
    }
}
