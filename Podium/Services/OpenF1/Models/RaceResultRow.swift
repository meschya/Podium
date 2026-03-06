//
//  RaceResultRow.swift
//  Podium
//

import Foundation

struct RaceResultRow: Identifiable {
    var position: Int
    var driverNumber: Int
    var driverName: String
    var teamName: String?
    var time: String
    var points: Int
    var id: Int { driverNumber }
}
