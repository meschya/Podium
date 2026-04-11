//
//  JolpicaCalendarModels.swift
//  Podium — UI-модели календаря и раундов (данные с api.jolpi.ca).
//

import Foundation

/// Одна гонка в календаре сезона (для карточек Home / Races).
struct JolpicaCalendarRace: Hashable {
    var round: Int
    var raceName: String
    var schedule: JolpicaRaceSchedule?
    var circuit: JolpicaCircuitSummary?
}

struct JolpicaRaceSchedule: Hashable {
    var race: JolpicaRaceDay?
}

struct JolpicaRaceDay: Hashable {
    var date: String?
}

struct JolpicaCircuitSummary: Hashable {
    var circuitName: String?
    var country: String?
    var city: String?
}

struct JolpicaDriverBrief: Hashable {
    var number: Int
    var name: String
    var surname: String
}

struct JolpicaSprintStandingRow: Hashable {
    var position: Int
    var points: Int
    var driver: JolpicaDriverBrief
}

struct JolpicaQualyGridRow: Hashable {
    var gridPosition: Int
    var driver: JolpicaDriverBrief
}
