//
//  ChampionshipWidget.swift
//  PodiumWidget
//
//  Сверху по центру: позиция ● команда ● очки (кружки). Снизу — болид.
//

import SwiftUI
import UIKit
import WidgetKit

struct ChampionshipEntry: TimelineEntry {
    let date: Date
    let positionText: String
    let teamName: String
    let pointsText: String
    let accent: Color
    let bolidAssetName: String
}

struct ChampionshipProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChampionshipEntry {
        Self.makeEntry(team: "McLaren")
    }

    func getSnapshot(in context: Context, completion: @escaping (ChampionshipEntry) -> Void) {
        completion(Self.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChampionshipEntry>) -> Void) {
        let entry = Self.loadEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private static func makeEntry(team: String) -> ChampionshipEntry {
        let accent = colorFromStored(nil)
        let bolid = WidgetBolidMapper.assetName(forTeamName: team)
        return ChampionshipEntry(
            date: Date(),
            positionText: "P1",
            teamName: team,
            pointsText: "770 pts",
            accent: accent,
            bolidAssetName: bolid
        )
    }

    private static func loadEntry() -> ChampionshipEntry {
        let d = UserDefaults(suiteName: WidgetAppGroup.id)
        let pos = d?.string(forKey: WidgetKeys.position) ?? "P1"
        let team = d?.string(forKey: WidgetKeys.team) ?? "McLaren"
        let pts = d?.string(forKey: WidgetKeys.points) ?? "770 pts"
        let accent = colorFromStored(d?.string(forKey: WidgetKeys.accentHex))
        let storedBolid = d?.string(forKey: WidgetKeys.bolidAsset)
        let bolid = (storedBolid != nil && !(storedBolid ?? "").isEmpty)
            ? storedBolid!
            : WidgetBolidMapper.assetName(forTeamName: team)
        return ChampionshipEntry(
            date: Date(),
            positionText: pos,
            teamName: team,
            pointsText: pts,
            accent: accent,
            bolidAssetName: bolid
        )
    }

    private static func colorFromStored(_ hex: String?) -> Color {
        guard let hex, hex.count == 6 else {
            return Color(red: 1, green: 0.42, blue: 0.04)
        }
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

struct ChampionshipWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ChampionshipEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenCenteredTextBolideBelow
        case .accessoryInline:
            lockScreenInline
        case .systemMedium:
            homeMediumCenteredTopBolideBelow
        default:
            lockScreenCenteredTextBolideBelow
        }
    }

    /// Сверху: позиция ● команда ● очки (кружки-разделители), по центру; снизу — болид на всю оставшуюся высоту.
    private var lockScreenCenteredTextBolideBelow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text(entry.positionText)
                        .fontWeight(.heavy)
                    dot
                    Text(entry.teamName)
                        .lineLimit(1)
                    dot
                    Text(entry.pointsText)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            WidgetBundledImage.image(named: entry.bolidAssetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockScreenInline: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text(entry.positionText)
                    .fontWeight(.heavy)
                dot
                Text(entry.teamName)
                    .lineLimit(1)
                dot
                Text(entry.pointsText)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeMediumCenteredTopBolideBelow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(entry.positionText)
                        .fontWeight(.heavy)
                    dotMedium
                    Text(entry.teamName)
                        .lineLimit(1)
                    dotMedium
                    Text(entry.pointsText)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            WidgetBundledImage.image(named: entry.bolidAssetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dot: some View {
        Circle()
            .fill(.secondary.opacity(0.7))
            .frame(width: 4, height: 4)
    }

    private var dotMedium: some View {
        Circle()
            .fill(.secondary.opacity(0.7))
            .frame(width: 5, height: 5)
    }
}

private struct ChampionshipWidgetRoot: View {
    @Environment(\.widgetFamily) private var family
    var entry: ChampionshipEntry

    var body: some View {
        ChampionshipWidgetEntryView(entry: entry)
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

struct ChampionshipWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.EMYM.Podium.championship", provider: ChampionshipProvider()) { entry in
            ChampionshipWidgetRoot(entry: entry)
        }
        .configurationDisplayName("Podium — Конструкторы")
        .description("Лидер кубка и болид команды (не виджет гонщика). Данные из приложения после OpenF1.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemMedium])
        .contentMarginsDisabled()
    }
}
