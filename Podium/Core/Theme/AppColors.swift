//
//  AppColors.swift
//  Podium
//

import SwiftUI

extension Color {
    enum AppColors {
        static var accentBlue: Color = Color(UIColor(red: 88 / 255, green: 105 / 255, blue: 161 / 255, alpha: 1))

        // F1 team colors (single color for circles etc.)
        static let alpine: Color = Color(red: 0 / 255.0, green: 78 / 255.0, blue: 112 / 255.0)
        static let astonMartin: Color = Color(red: 15 / 255.0, green: 67 / 255.0, blue: 49 / 255.0)
        static let williams: Color = Color(red: 8 / 255.0, green: 33 / 255.0, blue: 69 / 255.0)
        static let audi: Color = Color(red: 117 / 255.0, green: 21 / 255.0, blue: 0 / 255.0)
        static let cadillac: Color = Color(red: 88 / 255.0, green: 88 / 255.0, blue: 91 / 255.0)
        static let ferrari: Color = Color(red: 92 / 255.0, green: 0 / 255.0, blue: 18 / 255.0)
        static let haas: Color = Color(red: 102 / 255.0, green: 113 / 255.0, blue: 117 / 255.0)
        static let mclaren: Color = Color(red: 128 / 255.0, green: 64 / 255.0, blue: 0 / 255.0)
        static let mercedes: Color = Color(red: 6 / 255.0, green: 126 / 255.0, blue: 106 / 255.0)
        static let racingBulls: Color = Color(red: 0 / 255.0, green: 56 / 255.0, blue: 194 / 255.0)
        static let redBull: Color = Color(red: 20 / 255.0, green: 41 / 255.0, blue: 72 / 255.0)

        /// Градиент команды: (start, end). Teams — слева направо, Podium — снизу вверх.
        static func teamGradient(for teamName: String) -> (start: Color, end: Color)? {
            let lower = teamName.lowercased()
            if lower.contains("red bull") && !lower.contains("racing bulls") {
                return (Color(red: 20/255, green: 41/255, blue: 72/255), Color(red: 54/255, green: 113/255, blue: 198/255))
            }
            if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" {
                return (Color(red: 0/255, green: 56/255, blue: 194/255), Color(red: 102/255, green: 146/255, blue: 255/255))
            }
            if lower.contains("ferrari") {
                return (Color(red: 92/255, green: 0/255, blue: 18/255), Color(red: 232/255, green: 0/255, blue: 45/255))
            }
            if lower.contains("mclaren") {
                return (Color(red: 128/255, green: 64/255, blue: 0/255), Color(red: 255/255, green: 128/255, blue: 0/255))
            }
            if lower.contains("mercedes") {
                return (Color(red: 6/255, green: 126/255, blue: 106/255), Color(red: 39/255, green: 244/255, blue: 210/255))
            }
            if lower.contains("aston martin") {
                return (Color(red: 15/255, green: 67/255, blue: 49/255), Color(red: 34/255, green: 153/255, blue: 113/255))
            }
            if lower.contains("alpine") {
                return (Color(red: 0/255, green: 78/255, blue: 112/255), Color(red: 0/255, green: 161/255, blue: 232/255))
            }
            if lower.contains("williams") {
                return (Color(red: 8/255, green: 33/255, blue: 69/255), Color(red: 24/255, green: 104/255, blue: 219/255))
            }
            if lower.contains("haas") || lower.contains("sauber") || lower.contains("kick") {
                return (Color(red: 102/255, green: 113/255, blue: 117/255), Color(red: 222/255, green: 225/255, blue: 226/255))
            }
            if lower.contains("audi") {
                return (Color(red: 117/255, green: 21/255, blue: 0/255), Color(red: 255/255, green: 45/255, blue: 0/255))
            }
            if lower.contains("cadillac") {
                return (Color(red: 88/255, green: 88/255, blue: 91/255), Color(red: 170/255, green: 170/255, blue: 173/255))
            }
            return nil
        }

        /// Нижний стоп градиента команды (`start` в `teamGradient`, направление снизу вверх в Podium). Без градиента — фирменный однотонный.
        static func teamGradientBottomColor(for teamName: String) -> Color {
            if let g = teamGradient(for: teamName) { return g.start }
            return teamSolidBrandColor(for: teamName)
        }

        private static func teamSolidBrandColor(for teamName: String) -> Color {
            let lower = teamName.lowercased()
            if lower.contains("red bull"), !lower.contains("racing bulls") { return redBull }
            if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return racingBulls }
            if lower.contains("ferrari") { return ferrari }
            if lower.contains("mclaren") { return mclaren }
            if lower.contains("mercedes") { return mercedes }
            if lower.contains("aston martin") { return astonMartin }
            if lower.contains("alpine") { return alpine }
            if lower.contains("williams") { return williams }
            if lower.contains("haas") || lower.contains("sauber") || lower.contains("kick") { return haas }
            if lower.contains("audi") { return audi }
            if lower.contains("cadillac") { return cadillac }
            return Color.white.opacity(0.75)
        }
    }
}
