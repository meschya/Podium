//
//  PodiumWidgetDataSync.swift
//  Podium
//
//  Данные виджета конструкторов из App Group после загрузки `championshipTeams` (OpenF1).
//

import Foundation
import SwiftUI
import UIKit
import WidgetKit

enum WidgetTeamAccent {
    static func color(for teamName: String) -> Color {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return Color.AppColors.redBull }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return Color.AppColors.racingBulls }
        if lower.contains("ferrari") { return Color.AppColors.ferrari }
        if lower.contains("mclaren") { return Color.AppColors.mclaren }
        if lower.contains("mercedes") { return Color.AppColors.mercedes }
        if lower.contains("aston martin") { return Color.AppColors.astonMartin }
        if lower.contains("alpine") { return Color.AppColors.alpine }
        if lower.contains("williams") { return Color.AppColors.williams }
        if lower.contains("haas") { return Color.AppColors.haas }
        if lower.contains("sauber") || lower.contains("kick") { return Color.AppColors.haas }
        if lower.contains("audi") { return Color.AppColors.audi }
        if lower.contains("cadillac") { return Color.AppColors.cadillac }
        return Color.AppColors.mclaren
    }
}

enum PodiumWidgetDataSync {
    private static let suite = "group.com.EMYM.Podium"

    private enum Keys {
        static let position = "widget.constructor.position"
        static let team = "widget.constructor.team"
        static let points = "widget.constructor.points"
        static let accentHex = "widget.constructor.accentHex"
        static let bolidAsset = "widget.constructor.bolidAsset"
        static let upcomingCity = "widget.upcoming.city"
        static let upcomingCountry = "widget.upcoming.country"
        static let upcomingDateText = "widget.upcoming.dateText"
        static let upcomingEventName = "widget.upcoming.eventName"
        static let upcomingTrackAsset = "widget.upcoming.trackAsset"
        static let upcomingCircuitName = "widget.upcoming.circuitName"
        static let upcomingTrackFilePath = "widget.upcoming.trackFilePath"
    }

    static func pushConstructorLeader(position: Int, teamName: String, points: Int, accentColor: Color?) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defaults.set("P\(position)", forKey: Keys.position)
        defaults.set(teamName, forKey: Keys.team)
        defaults.set("\(points) pts", forKey: Keys.points)
        defaults.set(TeamBolidAssetName.resolve(teamName), forKey: Keys.bolidAsset)
        if let accentColor {
            defaults.set(hexString(from: accentColor), forKey: Keys.accentHex)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "com.EMYM.Podium.championship")
        // Тот же билд — обновить снапшот виджета гонщика (портрет), иначе iOS может долго держать старый кэш.
        WidgetCenter.shared.reloadTimelines(ofKind: "com.EMYM.Podium.driverLeader.faceCropV4TallPortrait")
    }

    static func pushDriverLeader(fullName: String, points: Int, teamName: String, photoAssetName: String) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defaults.set(fullName, forKey: "widget.driver.fullName")
        defaults.set("\(points) pts", forKey: "widget.driver.points")
        defaults.set(teamName, forKey: "widget.driver.team")
        defaults.set(photoAssetName, forKey: "widget.driver.photoAsset")
        WidgetCenter.shared.reloadTimelines(ofKind: "com.EMYM.Podium.driverLeader.faceCropV4TallPortrait")
    }

    static func pushUpcomingRace(city: String, country: String, eventDate: Date, eventName: String, circuitNameOrLocation: String?) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "MMM d, HH:mm a"

        defaults.set(city, forKey: Keys.upcomingCity)
        defaults.set(country, forKey: Keys.upcomingCountry)
        defaults.set(f.string(from: eventDate), forKey: Keys.upcomingDateText)
        defaults.set(eventName, forKey: Keys.upcomingEventName)
        let trackAssetName = String.AppImage.trackImage(circuitName: circuitNameOrLocation)
        defaults.set(trackAssetName, forKey: Keys.upcomingTrackAsset)
        defaults.set(circuitNameOrLocation, forKey: Keys.upcomingCircuitName)

        // В виджете нет каталога Tracks, поэтому публикуем PNG в App Group и показываем его оттуда.
        if let trackAssetName,
           let image = UIImage(named: trackAssetName),
           let data = image.pngData(),
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
            let fileURL = container.appendingPathComponent("upcoming_track_map.png")
            do {
                try data.write(to: fileURL, options: .atomic)
                defaults.set(fileURL.path, forKey: Keys.upcomingTrackFilePath)
            } catch {
                defaults.removeObject(forKey: Keys.upcomingTrackFilePath)
            }
        } else {
            defaults.removeObject(forKey: Keys.upcomingTrackFilePath)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "com.EMYM.Podium.upcomingRaceTrack")
    }

    private static func hexString(from color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        return String(format: "%02X%02X%02X", ri, gi, bi)
    }
}
