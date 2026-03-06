//
//  BottomDarkeningOverlay.swift
//  Podium
//
//  Отдельный view: плавное затемнение снизу (накладывается поверх героя/сплэша).
//

import SwiftUI

struct BottomDarkeningOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.3),
                Color.black.opacity(0.75),
                Color.black.opacity(0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}
