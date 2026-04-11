//
//  F1LiveCoordinate.swift
//  Podium — координаты на трассе для лайв-карты (OpenF1 / тайминг).
//

import Foundation

/// Координаты машины на трассе (как в OpenF1 / Position.z).
struct F1LiveCoordinate: Equatable {
    var x: Int
    var y: Int
}
