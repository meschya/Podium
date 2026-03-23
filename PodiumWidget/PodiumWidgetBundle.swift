//
//  PodiumWidgetBundle.swift
//  PodiumWidget
//

import WidgetKit
import SwiftUI

@main
struct PodiumWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChampionshipWidget()
        DriverLeaderWidget()
    }
}
