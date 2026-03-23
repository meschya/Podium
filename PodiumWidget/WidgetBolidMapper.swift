//
//  WidgetBolidMapper.swift
//  PodiumWidget
//
//  Те же имена ассетов, что в приложении (String.AppImage.*_bolid).
//

import Foundation

enum WidgetBolidMapper {
    static func assetName(forTeamName teamName: String) -> String {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return "rebullracing_bolid" }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return "racingbulls_bolid" }
        if lower.contains("ferrari") { return "ferrari_bolid" }
        if lower.contains("mclaren") { return "mclaren_bolid" }
        if lower.contains("mercedes") { return "mercedes_bolid" }
        if lower.contains("aston martin") { return "astonmartin_bolid" }
        if lower.contains("alpine") { return "alpine_bolid" }
        if lower.contains("williams") { return "williams_bolid" }
        if lower.contains("haas") { return "haas_bolid" }
        if lower.contains("sauber") || lower.contains("kick") { return "haas_bolid" }
        if lower.contains("audi") { return "audi_bolid" }
        if lower.contains("cadillac") { return "cadillac_bolid" }
        return "mclaren_bolid"
    }
}
