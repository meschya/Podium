//
//  WidgetAppGroup.swift
//  PodiumWidget
//
//  Тот же идентификатор нужно добавить в Signing & Capabilities → App Groups у приложения и виджета.
//

import Foundation

enum WidgetAppGroup {
    static let id = "group.com.EMYM.Podium"
}

enum WidgetKeys {
    static let position = "widget.constructor.position"
    static let team = "widget.constructor.team"
    static let points = "widget.constructor.points"
    static let accentHex = "widget.constructor.accentHex"
    static let bolidAsset = "widget.constructor.bolidAsset"

    static let driverFullName = "widget.driver.fullName"
    static let driverPoints = "widget.driver.points"
    static let driverTeam = "widget.driver.team"
    static let driverPhotoAsset = "widget.driver.photoAsset"

    static let upcomingCity = "widget.upcoming.city"
    static let upcomingCountry = "widget.upcoming.country"
    static let upcomingDateText = "widget.upcoming.dateText"
    static let upcomingEventName = "widget.upcoming.eventName"
    static let upcomingTrackAsset = "widget.upcoming.trackAsset"
    static let upcomingCircuitName = "widget.upcoming.circuitName"
    static let upcomingTrackFilePath = "widget.upcoming.trackFilePath"
}
