//
//  DriverLeaderWidget.swift
//  PodiumWidget
//
//  Только SwiftUI + WidgetBundledImage (как болид в ChampionshipWidget).
//  UIViewRepresentable в виджетах даёт пустой снапшот — не использовать.
//

import SwiftUI
import UIKit
import WidgetKit

/// В entry для превью; в UI — `widget_max_face_lockscreen` (кроп лица) через `maxVerstappenPortrait()`.
private let kMaxDriverPhotoAsset = "widget_max_face_lockscreen"

struct DriverLeaderEntry: TimelineEntry {
    let date: Date
    let fullName: String
    let pointsText: String
    let teamName: String
    let photoAssetName: String
}

struct DriverLeaderProvider: TimelineProvider {
    func placeholder(in context: Context) -> DriverLeaderEntry {
        Self.makeEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (DriverLeaderEntry) -> Void) {
        completion(Self.makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DriverLeaderEntry>) -> Void) {
        let entry = Self.makeEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private static func makeEntry() -> DriverLeaderEntry {
        DriverLeaderEntry(
            date: Date(),
            fullName: "Max Verstappen",
            pointsText: "23 pts",
            teamName: "Red Bull",
            photoAssetName: kMaxDriverPhotoAsset
        )
    }
}

struct DriverLeaderWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DriverLeaderEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenAccessory
        case .accessoryInline:
            inline
        case .systemMedium:
            homeMedium
        default:
            lockScreenAccessory
        }
    }

    private var lockScreenAccessory: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fullName)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.leading)
                Text(entry.pointsText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                Text(entry.teamName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            WidgetBundledImage.maxVerstappenPortrait()
                .resizable()
                .renderingMode(.original)
                .scaledToFill()
                .frame(width: 52, height: 40)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var homeMedium: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.fullName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(entry.pointsText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(entry.teamName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            WidgetBundledImage.maxVerstappenPortrait()
                .resizable()
                .renderingMode(.original)
                .scaledToFill()
                .frame(width: 118, height: 130)
                .clipped()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var inline: some View {
        Text("\(entry.fullName) · \(entry.pointsText) · \(entry.teamName)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DriverLeaderWidgetRoot: View {
    @Environment(\.widgetFamily) private var family
    var entry: DriverLeaderEntry

    var body: some View {
        DriverLeaderWidgetEntryView(entry: entry)
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

struct DriverLeaderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.EMYM.Podium.driverLeader.faceCrop", provider: DriverLeaderProvider()) { entry in
            DriverLeaderWidgetRoot(entry: entry)
        }
        .configurationDisplayName("Podium — Макс")
        .description("Портрет Max Verstappen (не болид). Статичные имя и очки.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .accessoryRectangular) {
    DriverLeaderWidget()
} timeline: {
    DriverLeaderEntry(
        date: .now,
        fullName: "Max Verstappen",
        pointsText: "23 pts",
        teamName: "Red Bull",
        photoAssetName: kMaxDriverPhotoAsset
    )
}

#Preview(as: .accessoryInline) {
    DriverLeaderWidget()
} timeline: {
    DriverLeaderEntry(
        date: .now,
        fullName: "Max Verstappen",
        pointsText: "23 pts",
        teamName: "Red Bull",
        photoAssetName: kMaxDriverPhotoAsset
    )
}

#Preview(as: .systemMedium) {
    DriverLeaderWidget()
} timeline: {
    DriverLeaderEntry(
        date: .now,
        fullName: "Max Verstappen",
        pointsText: "23 pts",
        teamName: "Red Bull",
        photoAssetName: kMaxDriverPhotoAsset
    )
}
