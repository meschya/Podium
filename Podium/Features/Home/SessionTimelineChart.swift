import SwiftUI
import UIKit

struct SessionTimelineChart: View {
    var sessions: [OpenF1Session]
    var eventGmtOffset: String? = nil

    private let dateColumnWidth: CGFloat = 76
    private let lineWidth: CGFloat = 2
    private let timeColumnWidth: CGFloat = 48
    /// Высота одного часа на полосе — больше, чтобы сессии и подписи не превращались в линию.
    private let hourHeight: CGFloat = 44
    private let stripInset: CGFloat = 6
    private let outerPadding: CGFloat = 6
    private let cardSpacing: CGFloat = 12
    private static let liquidGlassCornerRadius: CGFloat = 24

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

    /// Начало календарного часа, в котором лежит `date` (в таймзоне `calendar`).
    /// Важно: нельзя делать `dateInterval(...)?.start ?? date` — при `nil` от `dateInterval` ось совпадала бы с полным временем сессии (19:30), `timeIntervalSince(rangeStartHour)` давал 0 и блок рисовался с y=0 (как старт в 19:00).
    private func startOfHour(containing date: Date, calendar: Calendar) -> Date {
        if let s = calendar.dateInterval(of: .hour, for: date)?.start {
            return s
        }
        var wall = calendar.dateComponents(in: calendar.timeZone, from: date)
        wall.minute = 0
        wall.second = 0
        wall.nanosecond = 0
        if let d = calendar.date(from: wall) { return d }
        var c = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        c.calendar = calendar
        c.timeZone = calendar.timeZone
        c.minute = 0
        c.second = 0
        c.nanosecond = 0
        return calendar.date(from: c) ?? date
    }

    /// Общая геометрия дня: один источник правды для высоты карточки и масштаба блоков.
    private func timelineMetrics(dayStart: Date, items: [SessionItem], calendar: Calendar) -> (rangeStartHour: Date, stripHeight: CGFloat, hourCount: Int) {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        let rangeStart = items.map(\.start).min() ?? dayStart
        let rangeEnd = items.map(\.end).max() ?? dayEnd
        let rangeStartHour = startOfHour(containing: rangeStart, calendar: calendar)
        let endHourFloor = startOfHour(containing: rangeEnd, calendar: calendar)
        let rangeEndHour = calendar.date(byAdding: .hour, value: 1, to: endHourFloor) ?? rangeEnd
        var span = rangeEndHour.timeIntervalSince(rangeStartHour)
        let latestEndSec = items.map { $0.end.timeIntervalSince(rangeStartHour) }.max() ?? 0
        span = max(span, latestEndSec + 30 * 60)
        span = max(span, 3600)
        let coreHours = max(1, Int(ceil(span / 3600)))
        let hourCount = coreHours + 1
        let stripHeight = CGFloat(hourCount) * hourHeight
        return (rangeStartHour, stripHeight, hourCount)
    }

    private func contentHeight(dayStart: Date, items: [SessionItem], calendar: Calendar) -> CGFloat {
        let m = timelineMetrics(dayStart: dayStart, items: items, calendar: calendar)
        return m.stripHeight + stripInset * 2 + outerPadding * 2
    }

    private static let timelineLineColor = Color(.separator)

    private func dateLineBlock(dayStart: Date, contentHeight: CGFloat, calendar: Calendar) -> some View {
        let lineHeight = contentHeight - 22
        return VStack(alignment: .center, spacing: 0) {
            Text(dayHeaderShort(dayStart, timeZone: calendar.timeZone))
                .font(Font.custom(FontWeight.outfitSemiBold.rawValue, size: 13))
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
        let m = timelineMetrics(dayStart: dayStart, items: items, calendar: calendar)
        let totalStripHeight = m.stripHeight + stripInset * 2

        return HStack(alignment: .top, spacing: 0) {
            timeLabels(from: m.rangeStartHour, hourCount: m.hourCount, calendar: calendar)
                .frame(width: timeColumnWidth, height: m.stripHeight)
                .padding(.leading, stripInset)
                .padding(.top, stripInset)
                .padding(.bottom, stripInset)

            timelineStripBlocks(
                items: items,
                rangeStartHour: m.rangeStartHour,
                stripHeight: m.stripHeight,
                hourCount: m.hourCount,
                calendar: calendar
            )
            .frame(maxWidth: .infinity)
            .frame(height: m.stripHeight)
            .padding(.trailing, stripInset)
            .padding(.top, stripInset)
            .padding(.bottom, stripInset)
            .padding(.leading, 6)
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
                    .font(Font.custom(FontWeight.outfitRegular.rawValue, size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    // Линии сетки на полосе стоят у верхнего края каждого часа (y = 0, hourHeight, …).
                    // Без .top текст по центру 44pt — визуально «время не на линии».
                    .frame(maxWidth: .infinity, minHeight: hourHeight, maxHeight: hourHeight, alignment: .topLeading)
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

    /// Сетка + карточки в **одном** UIKit-view: одна система координат (линии на y = 0, 44, 88… и блоки с тем же y). Раньше линии были SwiftUI, блоки — UIKit; в ScrollView они могли визуально расходиться с реальным временем.
    private func timelineStripBlocks(items: [SessionItem], rangeStartHour: Date, stripHeight: CGFloat, hourCount: Int, calendar: Calendar) -> some View {
        let layouts: [TimelineStripLayout] = items
            .sorted { $0.start < $1.start }
            .map { it in
                let startSec = it.start.timeIntervalSince(rangeStartHour)
                let durationSec = max(0, it.end.timeIntervalSince(it.start))
                let topSec = max(0, startSec)
                let y = min(max(0, stripHeight - 1), CGFloat(topSec / 3600.0) * hourHeight)
                let rawH = max(1, CGFloat(durationSec / 3600.0) * hourHeight)
                let h = min(rawH, max(1, stripHeight - y))
                return TimelineStripLayout(item: it, y: y, h: h)
            }

        return TimelineSessionStripUIViewRepresentable(
            layouts: layouts,
            stripHeight: stripHeight,
            hourCount: hourCount,
            hourLineHeight: hourHeight,
            timeZone: calendar.timeZone
        )
        .frame(maxWidth: .infinity, minHeight: stripHeight, maxHeight: stripHeight)
        .clipped()
    }

    private func dayHeaderShort(_ day: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "EEE d MMM"
        return f.string(from: day)
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
        if s.hasSuffix("Z"), s.count >= 20 {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let core = String(s.dropLast())
            if core.count >= 19, let d = f.date(from: String(core.prefix(19))) { return d }
        }
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

private struct TimelineStripLayout: Identifiable {
    var id: Int { item.key }
    var item: SessionItem
    var y: CGFloat
    var h: CGFloat
}

// MARK: - UIKit strip (явные CGRect, обход бага SwiftUI Layout+ForEach → один subview)

private struct TimelineSessionStripUIViewRepresentable: UIViewRepresentable {
    var layouts: [TimelineStripLayout]
    var stripHeight: CGFloat
    var hourCount: Int
    var hourLineHeight: CGFloat
    var timeZone: TimeZone

    func makeUIView(context: Context) -> TimelineSessionUIKitContainer {
        let v = TimelineSessionUIKitContainer()
        v.backgroundColor = .clear
        v.clipsToBounds = true
        return v
    }

    func updateUIView(_ uiView: TimelineSessionUIKitContainer, context: Context) {
        uiView.apply(
            layouts: layouts,
            stripHeight: stripHeight,
            hourCount: hourCount,
            hourLineHeight: hourLineHeight,
            timeZone: timeZone
        )
        uiView.setNeedsLayout()
    }
}

private final class TimelineSessionUIKitContainer: UIView {
    private var layoutRows: [TimelineStripLayout] = []
    private var stripHeightPts: CGFloat = 0
    private var hourCountStored: Int = 0
    private var hourLineHeightPts: CGFloat = 44
    private var lineViews: [UIView] = []
    private var blockViews: [TimelineUIKitBlockView] = []

    func apply(layouts: [TimelineStripLayout], stripHeight: CGFloat, hourCount: Int, hourLineHeight: CGFloat, timeZone: TimeZone) {
        layoutRows = layouts
        stripHeightPts = stripHeight
        hourCountStored = max(0, hourCount)
        hourLineHeightPts = hourLineHeight

        lineViews.forEach { $0.removeFromSuperview() }
        lineViews = []
        for _ in 0..<hourCountStored {
            let lv = UIView()
            lv.backgroundColor = UIColor.separator
            lv.isUserInteractionEnabled = false
            addSubview(lv)
            lineViews.append(lv)
        }

        while blockViews.count < layouts.count {
            let b = TimelineUIKitBlockView()
            addSubview(b)
            blockViews.append(b)
        }
        while blockViews.count > layouts.count {
            blockViews.removeLast().removeFromSuperview()
        }

        for (i, L) in layouts.enumerated() {
            blockViews[i].configure(item: L.item, timeZone: timeZone)
        }
        for b in blockViews {
            bringSubviewToFront(b)
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: stripHeightPts)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        for (i, lv) in lineViews.enumerated() {
            let y = CGFloat(i) * hourLineHeightPts
            lv.frame = CGRect(x: 0, y: y, width: w, height: 1)
        }
        for (i, b) in blockViews.enumerated() {
            guard i < layoutRows.count else { continue }
            let L = layoutRows[i]
            b.frame = CGRect(x: 0, y: L.y, width: w, height: L.h)
        }
    }
}

private final class TimelineUIKitBlockView: UIView {
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let tailSpacer = UIView()
    private let stack = UIStackView()
    private var lastItem: SessionItem?
    private var lastTimeString = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Родитель задаёт frame; не смешиваем с Auto Layout по краям (см. layoutSubviews у stack).
        translatesAutoresizingMaskIntoConstraints = true
        layer.cornerRadius = 8
        layer.masksToBounds = true
        backgroundColor = UIColor(red: 180 / 255, green: 50 / 255, blue: 50 / 255, alpha: 0.2)
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        layer.borderWidth = 1

        titleLabel.textColor = .white
        timeLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 2
        timeLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        timeLabel.lineBreakMode = .byClipping

        tailSpacer.setContentHuggingPriority(.init(1), for: .horizontal)
        tailSpacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 2
        stack.distribution = .fill
        // Только ручные frame из layoutSubviews: иначе при frame с родителя (SwiftUI/UIKit) ловим
        // NSAutoresizingMaskLayoutConstraint height/width == 0 против NSLayoutConstraint — лаг и спам в консоль.
        stack.translatesAutoresizingMaskIntoConstraints = true
        stack.autoresizingMask = []
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(tailSpacer)

        addSubview(stack)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let pad: CGFloat = 8
        let topPad: CGFloat = 4
        stack.frame = CGRect(x: pad, y: topPad, width: max(0, w - pad * 2), height: max(0, h - topPad - 4))
        applyCompactLayoutIfNeeded()
    }

    func configure(item: SessionItem, timeZone: TimeZone) {
        lastItem = item
        titleLabel.text = item.short
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        lastTimeString = "\(f.string(from: item.start))–\(f.string(from: item.end))"
        timeLabel.text = lastTimeString
        timeLabel.textColor = .secondaryLabel
        setNeedsLayout()
        applyCompactLayoutIfNeeded()
    }

    /// Нормальный блок: название сверху, время снизу (`secondaryLabel`). Если высоты мало — одна строка «название · время» слева (время не у trailing).
    private func applyCompactLayoutIfNeeded() {
        let h = bounds.height
        guard h > 0, lastItem != nil else { return }

        let sessionTitleFont = UIFont(name: FontWeight.outfitSemiBold.rawValue, size: 13)
        ?? .systemFont(ofSize: 13, weight: .semibold)
        let sessionTitleFontCompact = UIFont(name: FontWeight.outfitSemiBold.rawValue, size: 11)
            ?? .systemFont(ofSize: 11, weight: .semibold)
        let timeNormal = UIFont(name: FontWeight.outfitRegular.rawValue, size: 11) ?? .systemFont(ofSize: 11, weight: .regular)
        let timeSmall = UIFont(name: FontWeight.outfitRegular.rawValue, size: 9) ?? .systemFont(ofSize: 9, weight: .regular)

        titleLabel.isHidden = false
        timeLabel.isHidden = false
        timeLabel.text = lastTimeString
        timeLabel.textColor = .secondaryLabel

        /// Ниже ~этого две строки (заголовок + время) визуально не помещаются — склеиваем в одну слева.
        let compactHeightThreshold: CGFloat = 38

        if h >= compactHeightThreshold {
            stack.axis = .vertical
            stack.alignment = .fill
            stack.spacing = 2
            tailSpacer.isHidden = true

            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            timeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            titleLabel.font = sessionTitleFont
            titleLabel.numberOfLines = 2
            timeLabel.font = timeNormal
            titleLabel.adjustsFontSizeToFitWidth = true
            titleLabel.minimumScaleFactor = 0.85
            timeLabel.adjustsFontSizeToFitWidth = true
            timeLabel.minimumScaleFactor = 0.75
        } else {
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 6
            tailSpacer.isHidden = false

            titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            timeLabel.setContentHuggingPriority(.required, for: .horizontal)
            timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            titleLabel.numberOfLines = 1
            timeLabel.numberOfLines = 1

            if h < 22 {
                titleLabel.font = sessionTitleFontCompact
                timeLabel.font = timeSmall
                titleLabel.minimumScaleFactor = 0.7
                timeLabel.minimumScaleFactor = 0.65
            } else {
                titleLabel.font = sessionTitleFontCompact
                timeLabel.font = timeSmall
                titleLabel.minimumScaleFactor = 0.75
                timeLabel.minimumScaleFactor = 0.7
            }
            titleLabel.adjustsFontSizeToFitWidth = true
            timeLabel.adjustsFontSizeToFitWidth = true
        }
    }
}
