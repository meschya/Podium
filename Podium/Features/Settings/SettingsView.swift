//
//  SettingsView.swift
//  Podium
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("Settings")
                .font(Font.custom(FontWeight.titilliumWebRegular.rawValue, size: 20))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
