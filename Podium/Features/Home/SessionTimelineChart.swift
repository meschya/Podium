import SwiftUI

struct SessionTimelineChart: View {
    var sessions: [OpenF1Session]
    var eventGmtOffset: String? = nil

    private let dateColumnWidth: CGFloat = 76
    private let lineWidth: CGFloat = 2
    private let timeColumnWidth: CGFloat = 48
    private let hourHeight: CGFloat = 36
    private let blockCornerRadius: CGFloat = 8
    private let stripInset: CGFloat = 6
    private let outerPadding: CGFloat = 6
    private let cardSpacing: CGFloat = 12
    private static let liquidGlassCornerRadius: CGFloat = 24
    private static let eventRed = Color(red: 180/255, green: 50/255, blue: 50/255)

    var body: some View {
        let eventTZ = eventTimeZone(from: eventGmtOffset)
        let displayCal = Calendar.current
        let items = sessions.compactMap { s -> SessionItem? in
            guard let start = parseDate(s.dateStart, eventTimeZone: eventTZ) else { return nil }
            let end = parseDate(s.dateEnd, eventTimeZone: eventTZ) ?? start
            return SessionItem(
                key: s.sessionKey,
                name: s.sessionName,
                short: shortName(s.sessionName),
                start: min(start, end),
                end: max(start, end)
            )
        }
        let byDay = Dictionary(grouping: items.sorted { $0.start < $1.start }) { displayCal.startOfDay(for: $0.start) }
        let sortedDays = byDay.keys.sorted()

        if sortedDays.isEmpty {
            return AnyView(EmptyView())
        }

        let dayHeights: [Date: CGFloat] = sortedDays.reduce(into: [:]) { res, dayStart in
            guard let dayItems = byDay[dayStart], !dayItems.isEmpty else { return }
            let h = contentHeight(dayStart: dayStart, items: dayItems, calendar: displayCal)
            res[dayStart] = h
        }

        return AnyView(
            VStack(alignment: .leading, spacing: cardSpacing) {
                ForEach(Array(sortedDays.enumerated()), id: \.element) { index, dayStart in
                    if let dayItems = byDay[dayStart], !dayItems.isEmpty, let h = dayHeights[dayStart] {
                        HStack(alignment: .top, spacing: 12) {
                            dateLineBlock(dayStart: dayStart, contentHeight: h, calendar: displayCal)
                            timelineBlock(dayStart: dayStart, items: dayItems, calendar: displayCal)
                        }
                    }
                }
            }
        )
    }

    private func contentHeight(dayStart: Date, items: [SessionItem], calendar: Calendar) -> CGFloat {
        let rangeStart = items.map(\.start).min() ?? dayStart
        let rangeEnd = items.map(\.end).max() ?? dayStart
        let rangeStartHour = calendar.date(bySettingHour: calendar.component(.hour, from: rangeStart), minute: 0, second: 0, of: dayStart) ?? rangeStart
        let rangeEndRounded = calendar.date(bySettingHour: calendar.component(.hour, from: rangeEnd), minute: 0, second: 0, of: dayStart) ?? rangeEnd
        let rangeEndHour = calendar.date(byAdding: .hour, value: 1, to: rangeEndRounded) ?? rangeEnd
        let span = rangeEndHour.timeIntervalSince(rangeStartHour)
        let hourCount = max(1, Int(span / 3600))
        let stripHeight = CGFloat(hourCount) * hourHeight
        return stripHeight + stripInset * 2 + outerPadding * 2
    }

    private static let timelineLineColor = Color(.separator)

    private func dateLineBlock(dayStart: Date, contentHeight: CGFloat, calendar: Calendar) -> some View {
        let lineHeight = contentHeight - 22
        return VStack(alignment: .center, spacing: 0) {
            Text(dayHeaderShort(dayStart, timeZone: calendar.timeZone))
                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Self.timelineLineColor)
                .frame(width: lineWidth, height: max(0, lineHeight))
        }
        .frame(width: dateColumnWidth, height: contentHeight, alignment: .top)
        .frame(alignment: .center)
    }

    private func timelineBlock(dayStart: Date, items: [SessionItem], calendar: Calendar) -> some View {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        let rangeStart = items.map(\.start).min() ?? dayStart
        let rangeEnd = items.map(\.end).max() ?? dayEnd
        let rangeStartHour = calendar.date(bySettingHour: calendar.component(.hour, from: rangeStart), minute: 0, second: 0, of: dayStart) ?? rangeStart
        let rangeEndRounded = calendar.date(bySettingHour: calendar.component(.hour, from: rangeEnd), minute: 0, second: 0, of: dayStart) ?? rangeEnd
        let rangeEndHour = calendar.date(byAdding: .hour, value: 1, to: rangeEndRounded) ?? rangeEnd
        let span = rangeEndHour.timeIntervalSince(rangeStartHour)
        let hourCount = max(1, Int(span / 3600))
        let stripHeight = CGFloat(hourCount) * hourHeight
        let totalStripHeight = stripHeight + stripInset * 2

        return HStack(alignment: .top, spacing: 0) {
            timeLabels(from: rangeStartHour, hourCount: hourCount, calendar: calendar)
                .frame(width: timeColumnWidth, height: stripHeight)
                .padding(.leading, stripInset)
                .padding(.top, stripInset)

            ZStack(alignment: .topLeading) {
                hourLines(hourCount: hourCount, height: stripHeight)
                timelineStripBlocks(
                    items: items,
                    rangeStartHour: rangeStartHour,
                    span: span,
                    stripHeight: stripHeight,
                    calendar: calendar
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: stripHeight)
            .padding(.trailing, stripInset)
            .padding(.top, stripInset)
            .padding(.bottom, stripInset)
            .padding(.leading, 6)
            .clipped()
        }
        .frame(height: totalStripHeight)
        .padding(outerPadding)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Self.liquidGlassCornerRadius).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }

    private func timeLabels(from start: Date, hourCount: Int, calendar: Calendar) -> some View {
        return VStack(spacing: 0) {
            ForEach(0..<hourCount, id: \.self) { i in
                let h = calendar.date(byAdding: .hour, value: i, to: start) ?? start
                Text(timeLabel(h, timeZone: calendar.timeZone))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(height: hourHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func timeLabel(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func hourLines(hourCount: Int, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<hourCount, id: \.self) { _ in
                Rectangle()
                    .fill(Self.timelineLineColor)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                    .frame(height: hourHeight)
            }
        }
    }

    private static let positionOffsetMinutes: Int = 30

    private func timelineStripBlocks(items: [SessionItem], rangeStartHour: Date, span: TimeInterval, stripHeight: CGFloat, calendar: Calendar) -> some View {
        let safeSpan = max(1.0, span)
        let offsetSec = TimeInterval(Self.positionOffsetMinutes * 60)
        let positioned: [(item: SessionItem, y: CGFloat, h: CGFloat)] = items.map { it in
            let startSec = it.start.timeIntervalSince(rangeStartHour)
            let durationSec = it.end.timeIntervalSince(it.start)
            let topSec = max(0, startSec) + offsetSec
            let durSec = max(0, durationSec)
            let y = min(stripHeight, stripHeight * CGFloat(topSec / safeSpan))
            let h = stripHeight * CGFloat(durSec / safeSpan)
            return (it, y, h)
        }.sorted { $0.y < $1.y }
        let withGap: [(item: SessionItem, gap: CGFloat, h: CGFloat)] = positioned.enumerated().map { index, p in
            let gap: CGFloat = index == 0 ? p.y : max(0, p.y - (positioned[index - 1].y + positioned[index - 1].h))
            return (p.item, gap, p.h)
        }
        return VStack(spacing: 0) {
            ForEach(Array(withGap.enumerated()), id: \.element.item.key) { _, entry in
                Spacer()
                    .frame(height: entry.gap)
                sessionBlockContent(item: entry.item, height: entry.h, timeZone: calendar.timeZone)
            }
            Spacer(minLength: 0)
        }
        .frame(height: stripHeight)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func sessionBlockContent(item: SessionItem, height: CGFloat, timeZone: TimeZone = .current) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.short)
                .font(Font.custom(FontWeight.titilliumWebSemiBold.rawValue, size: 13))
                .foregroundStyle(.white)
            Text(blockTimeRange(item.start, end: item.end, timeZone: timeZone))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(Self.eventRed.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: blockCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: blockCornerRadius)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func dayHeaderShort(_ day: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "EEE d MMM"
        return f.string(from: day)
    }

    private func blockTimeRange(_ start: Date, end: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func eventTimeZone(from gmtOffset: String?) -> TimeZone? {
        guard let s = gmtOffset?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let sign = s.hasPrefix("-") ? -1 : 1
        let cleaned = s.replacingOccurrences(of: "UTC", with: "").trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":")
        let h = Int(parts.first ?? "0") ?? 0
        let m = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return TimeZone(secondsFromGMT: sign * (abs(h) * 3600 + min(59, m) * 60))
    }

    private func parseDate(_ s: String?, eventTimeZone: TimeZone?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let hasTimezone = s.contains("Z") || s.range(of: #"[+-]\d{2}:?\d{0,2}$"#, options: .regularExpression) != nil
        if !hasTimezone, let tz = eventTimeZone ?? TimeZone(identifier: "UTC") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            if let d = f.date(from: s) { return d }
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let d = f.date(from: s) { return d }
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private func shortName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("practice") || lower.contains("fp") {
            if lower.contains("1") { return "FP1" }
            if lower.contains("2") { return "FP2" }
            if lower.contains("3") { return "FP3" }
            return "FP"
        }
        if lower.contains("qualifying") || lower.contains("quali") { return "Quali" }
        if lower.contains("race") { return "Race" }
        if lower.contains("sprint") { return "Sprint" }
        return name
    }
}

private struct SessionItem {
    var key: Int
    var name: String
    var short: String
    var start: Date
    var end: Date
}
