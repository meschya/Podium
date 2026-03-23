//
//  TeamBolidAssetName.swift
//  Podium
//
//  Имена ассетов болидов — один источник для Home (Teams), виджета и синка.
//

import Foundation

enum TeamBolidAssetName {
    /// Имя imageset в Assets (например `mclaren_bolid`), совпадает с `WidgetBolidMapper` / Teams.
    static func resolve(_ teamName: String) -> String {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return String.AppImage.rebullracing_bolid }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return String.AppImage.racingbulls_bolid }
        if lower.contains("ferrari") { return String.AppImage.ferrari_bolid }
        if lower.contains("mclaren") { return String.AppImage.mclaren_bolid }
        if lower.contains("mercedes") { return String.AppImage.mercedes_bolid }
        if lower.contains("aston martin") { return String.AppImage.astonmartin_bolid }
        if lower.contains("alpine") { return String.AppImage.alpine_bolid }
        if lower.contains("williams") { return String.AppImage.williams_bolid }
        if lower.contains("haas") { return String.AppImage.haas_bolid }
        if lower.contains("sauber") || lower.contains("kick") { return String.AppImage.haas_bolid }
        if lower.contains("audi") { return String.AppImage.audi_bolid }
        if lower.contains("cadillac") { return String.AppImage.cadillac_bolid }
        return String.AppImage.mclaren_bolid
    }
}
