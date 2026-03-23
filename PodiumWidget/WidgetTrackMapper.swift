//
//  WidgetTrackMapper.swift
//  PodiumWidget
//

import Foundation

enum WidgetTrackMapper {
    /// Имя ассета трассы по названию трассы/локации (должно совпадать с Assets/Tracks).
    static func assetName(circuitName: String?) -> String? {
        guard let raw = circuitName, !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "-", with: " ")

        func has(_ sub: String) -> Bool { lower.contains(sub) }
        if has("albert park") || lower == "melbourne" { return "Albert_Park_Circuit" }
        if (has("enzo") && has("ferrari")) || lower == "imola" { return "Autodromo_Enzo_e_Dino_Ferrari" }
        if (has("hermanos") && has("rodriguez")) || has("mexico city") || lower == "mexico" { return "Autódromo_Hermanos_Rodríguez" }
        if has("jose carlos pace") || has("interlagos") || has("sao paulo") { return "Autódromo_José_Carlos_Pace" }
        if (has("nazionale") && has("monza")) || lower == "monza" { return "Autodromo_Nazionale_Monza" }
        if has("bahrain") { return "Bahrain_International_Circuit" }
        if has("baku") { return "Baku_City_Circuit" }
        if has("barcelona") || has("catalunya") { return "Circuit_de_Barcelona" }
        if has("monaco") || has("monte carlo") { return "Circuit_de_Monaco" }
        if has("spa") || has("francorchamps") { return "Circuit_de_Spa-Francorchamps" }
        if (has("gilles") && has("villeneuve")) || has("montreal") { return "Circuit_Gilles-Villeneuve" }
        if has("americas") || has("cota") || lower == "austin" { return "Circuit_of_The_Americas" }
        if has("zandvoort") { return "Circuit_Zandvoort" }
        if has("madrid") || has("madring") { return "Circuito_de_Madring" }
        if has("hungaroring") || lower == "budapest" { return "Hungaroring" }
        if has("jeddah") { return "Jeddah_Corniche_Circuit" }
        if has("lusail") || (has("qatar") && !has("yas")) { return "Lusail_International_Circuit" }
        if has("marina bay") || has("singapore") { return "Marina_Bay_Street_Circuit" }
        if has("miami") { return "Miami_International_Autodrome" }
        if has("red bull ring") || lower == "spielberg" { return "Red_Bull_Ring" }
        if has("shanghai") { return "Shanghai_International_Circuit" }
        if has("silverstone") { return "Silverstone_Circuit" }
        if has("suzuka") { return "Suzuka_International_Racing_Course" }
        if has("las vegas") || has("vegas strip") { return "The_Las_Vegas_Strip" }
        if has("yas marina") || has("abu dhabi") { return "Yas_Marina_Circuit" }
        return nil
    }
}
