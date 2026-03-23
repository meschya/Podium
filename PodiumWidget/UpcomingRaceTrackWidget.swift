//
//  UpcomingRaceTrackWidget.swift
//  PodiumWidget
//

import SwiftUI
import UIKit
import WidgetKit

struct UpcomingRaceEntry: TimelineEntry {
    let date: Date
    let city: String
    let country: String
    let dateText: String
    let eventName: String
    let trackAssetName: String?
    let circuitName: String
    let trackFilePath: String?
}

struct UpcomingRaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingRaceEntry {
        Self.fallbackEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingRaceEntry) -> Void) {
        completion(Self.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingRaceEntry>) -> Void) {
        let entry = Self.loadEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private static func loadEntry() -> UpcomingRaceEntry {
        let d = UserDefaults(suiteName: WidgetAppGroup.id)
        let city = d?.string(forKey: WidgetKeys.upcomingCity) ?? "Las Vegas"
        let country = d?.string(forKey: WidgetKeys.upcomingCountry) ?? "United States"
        let dateText = d?.string(forKey: WidgetKeys.upcomingDateText) ?? "Nov 30, 18:00 PM"
        let event = d?.string(forKey: WidgetKeys.upcomingEventName) ?? "Race"
        let circuitName = d?.string(forKey: WidgetKeys.upcomingCircuitName) ?? city
        let trackFilePath = d?.string(forKey: WidgetKeys.upcomingTrackFilePath)
        let storedTrack = d?.string(forKey: WidgetKeys.upcomingTrackAsset)
        let resolvedTrack = (storedTrack?.isEmpty == false) ? storedTrack : WidgetTrackMapper.assetName(circuitName: circuitName)
        return UpcomingRaceEntry(
            date: .now,
            city: city,
            country: country,
            dateText: dateText,
            eventName: event,
            trackAssetName: resolvedTrack,
            circuitName: circuitName,
            trackFilePath: trackFilePath
        )
    }

    private static func fallbackEntry() -> UpcomingRaceEntry {
        UpcomingRaceEntry(
            date: .now,
            city: "Las Vegas",
            country: "United States",
            dateText: "Nov 30, 18:00 PM",
            eventName: "Race",
            trackAssetName: "The_Las_Vegas_Strip",
            circuitName: "Las Vegas",
            trackFilePath: nil
        )
    }
}

struct UpcomingRaceWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: UpcomingRaceEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        case .systemMedium:
            medium
        default:
            rectangular
        }
    }

    private var rectangular: some View {
        HStack(alignment: .top, spacing: 8) {
            leftTextStack(cityFont: 11, dateFont: 9, untilFont: 9)
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack {
                Spacer(minLength: 0)
                trackView
                    .frame(width: 58, height: 40, alignment: .center)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 58, maxWidth: 58, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            leftTextStack(cityFont: 19, dateFont: 14, untilFont: 13)
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack {
                Spacer(minLength: 0)
                trackView
                    .frame(width: 160, height: 94, alignment: .center)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 160, maxWidth: 160, maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var inline: some View {
        Text("\(entry.city) · \(entry.dateText) · until \(entry.eventName)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func leftTextStack(cityFont: CGFloat, dateFont: CGFloat, untilFont: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.city)
                .font(.system(size: cityFont, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
            Text(entry.country)
                .font(.system(size: max(cityFont - 2, 9), weight: .regular, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            Text(entry.dateText)
                .font(.system(size: dateFont, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Text("until")
                    .font(.system(size: untilFont, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(entry.eventName)
                    .font(.system(size: untilFont, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var trackView: some View {
        if let path = entry.trackFilePath, let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.primary)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let name = entry.trackAssetName, !name.isEmpty {
            WidgetBundledImage.image(named: name)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.primary)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: "map")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }
}

private struct UpcomingRaceWidgetRoot: View {
    @Environment(\.widgetFamily) private var family
    var entry: UpcomingRaceEntry

    var body: some View {
        UpcomingRaceWidgetEntryView(entry: entry)
            .containerBackground(for: .widget) {
                switch family {
                case .systemMedium:
                    Color(UIColor.secondarySystemGroupedBackground)
                default:
                    if #available(iOSApplicationExtension 17.0, *) {
                        AccessoryWidgetBackground()
                    } else {
                        Color.clear
                    }
                }
            }
    }
}

struct UpcomingRaceTrackWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.EMYM.Podium.upcomingRaceTrack", provider: UpcomingRaceProvider()) { entry in
            UpcomingRaceWidgetRoot(entry: entry)
        }
        .configurationDisplayName("Podium — Next Race")
        .description("City, date, event and track map for the nearest race.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemMedium])
        .contentMarginsDisabled()
    }
}
