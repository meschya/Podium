//
//  AppImage.swift
//  Podium
//

import SwiftUI
import UIKit

extension String {
    enum AppImage {
        static let aston_martin_splash: String = "aston_martin_splash"
        static let f1_logo: String = "f1_logo"

        // Teams logos
        static let alpine_logo: String = "alpine_logo"
        static let astonmartin_logo: String = "astonmartin_logo"
        static let audi_logo: String = "audi_logo"
        static let cadillac_logo: String = "cadillac_logo"
        static let ferrari_logo: String = "ferrari_logo"
        static let haas_logo: String = "haas_logo"
        static let mclaren_logo: String = "mclaren_logo"
        static let mercedes_logo: String = "mercedes_logo"
        static let racingbulls_logo: String = "racingbulls_logo"
        static let redbullracing_logo: String = "redbullracing_logo"
        static let williams_logo: String = "williams_logo"

        // Bolids (F1 car images)
        static let alpine_bolid: String = "alpine_bolid"
        static let astonmartin_bolid: String = "astonmartin_bolid"
        static let audi_bolid: String = "audi_bolid"
        static let cadillac_bolid: String = "cadillac_bolid"
        static let ferrari_bolid: String = "ferrari_bolid"
        static let haas_bolid: String = "haas_bolid"
        static let mclaren_bolid: String = "mclaren_bolid"
        static let mercedes_bolid: String = "mercedes_bolid"
        static let racingbulls_bolid: String = "racingbulls_bolid"
        static let rebullracing_bolid: String = "rebullracing_bolid"
        static let williams_bolid: String = "williams_bolid"
        
        
        static let background_element: String = "background_element"
        static let background_drivers: String = "background_drivers"
        static let bolid_icon: String = "bolid_icon"

        // Flags (флаги стран из Assets.xcassets/Flags)
        static let flag_australia: String = "australia"
        static let flag_austria: String = "austria"
        static let flag_azerbaijan: String = "azerbaijan"
        static let flag_argentina: String = "argentina"
        static let flag_bahrain: String = "bahrain"
        static let flag_belgium: String = "belgium"
        static let flag_brazil: String = "brazil"
        static let flag_canada: String = "canada"
        static let flag_china: String = "china"
        static let flag_finland: String = "finland"
        static let flag_france: String = "france"
        static let flag_germany: String = "germany"
        static let flag_hungary: String = "hungary"
        static let flag_italy: String = "italy"
        static let flag_japan: String = "japan"
        static let flag_mexico: String = "mexico"
        static let flag_monaco: String = "monaco"
        static let flag_netherlands: String = "netherlands"
        static let flag_new_zealand: String = "new_zealand"
        static let flag_qatar: String = "qatar"
        static let flag_saudi_arabia: String = "saudi_arabia"
        static let flag_singapore: String = "singapore"
        static let flag_thailand: String = "thailand"
        static let flag_spain: String = "spain"
        static let flag_united_arab_emirates: String = "united_arab_emirates"
        static let flag_united_kingdom: String = "united_kingdom"
        static let flag_united_states: String = "united_states"

        /// Имя ассета флага по 2-буквенному коду страны (ISO 3166-1 alpha-2). Возвращает nil, если флага нет.
        static func flagImage(countryCode: String) -> String? {
            let code = countryCode.uppercased()
            switch code {
            case "AU": return flag_australia
            case "AT": return flag_austria
            case "AZ": return flag_azerbaijan
            case "AR": return flag_argentina
            case "BH": return flag_bahrain
            case "BE": return flag_belgium
            case "BR": return flag_brazil
            case "CA": return flag_canada
            case "CN": return flag_china
            case "DE": return flag_germany
            case "FI": return flag_finland
            case "FR": return flag_france
            case "HU": return flag_hungary
            case "IT": return flag_italy
            case "JP": return flag_japan
            case "MX": return flag_mexico
            case "MC": return flag_monaco
            case "NL": return flag_netherlands
            case "NZ": return flag_new_zealand
            case "QA": return flag_qatar
            case "SA": return flag_saudi_arabia
            case "SG": return flag_singapore
            case "ES": return flag_spain
            case "TH": return flag_thailand
            case "AE": return flag_united_arab_emirates
            case "GB": return flag_united_kingdom
            case "US": return flag_united_states
            default: return nil
            }
        }

        // Tracks (схемы трасс из Assets.xcassets/Tracks)
        static let track_albert_park: String = "Albert_Park_Circuit"
        static let track_autodromo_enzo_ferrari: String = "Autodromo_Enzo_e_Dino_Ferrari"
        static let track_hermanos_rodriguez: String = "Autódromo_Hermanos_Rodríguez"
        static let track_jose_carlos_pace: String = "Autódromo_José_Carlos_Pace"
        static let track_monza: String = "Autodromo_Nazionale_Monza"
        static let track_bahrain: String = "Bahrain_International_Circuit"
        static let track_baku: String = "Baku_City_Circuit"
        static let track_barcelona: String = "Circuit_de_Barcelona"
        static let track_monaco: String = "Circuit_de_Monaco"
        static let track_spa: String = "Circuit_de_Spa-Francorchamps"
        static let track_gilles_villeneuve: String = "Circuit_Gilles-Villeneuve"
        static let track_cota: String = "Circuit_of_The_Americas"
        static let track_zandvoort: String = "Circuit_Zandvoort"
        static let track_madrid: String = "Circuito_de_Madring"
        static let track_hungaroring: String = "Hungaroring"
        static let track_jeddah: String = "Jeddah_Corniche_Circuit"
        static let track_lusail: String = "Lusail_International_Circuit"
        static let track_marina_bay: String = "Marina_Bay_Street_Circuit"
        static let track_miami: String = "Miami_International_Autodrome"
        static let track_red_bull_ring: String = "Red_Bull_Ring"
        static let track_shanghai: String = "Shanghai_International_Circuit"
        static let track_silverstone: String = "Silverstone_Circuit"
        static let track_suzuka: String = "Suzuka_International_Racing_Course"
        static let track_las_vegas: String = "The_Las_Vegas_Strip"
        static let track_yas_marina: String = "Yas_Marina_Circuit"

        /// Имя ассета трассы по названию трассы из API (circuitName или location). Возвращает nil, если ассета нет.
        static func trackImage(circuitName: String?) -> String? {
            guard let raw = circuitName, !raw.isEmpty else { return nil }
            let lower = raw.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
                .replacingOccurrences(of: "-", with: " ")
            func has(_ sub: String) -> Bool { lower.contains(sub) }
            func isName(_ s: String) -> Bool { lower == s || lower.hasPrefix(s + " ") || lower.hasSuffix(" " + s) }
            if has("albert park") || lower == "melbourne" { return track_albert_park }
            if has("enzo") && has("ferrari") || lower == "imola" { return track_autodromo_enzo_ferrari }
            if has("hermanos") && has("rodriguez") || has("mexico city") || lower == "mexico" { return track_hermanos_rodriguez }
            if has("josé carlos pace") || has("jose carlos pace") || has("interlagos") || has("são paulo") || has("sao paulo") { return track_jose_carlos_pace }
            if has("nazionale") && has("monza") || lower == "monza" { return track_monza }
            if has("bahrain") { return track_bahrain }
            if has("baku") { return track_baku }
            if has("barcelona") || has("catalunya") { return track_barcelona }
            if has("monaco") || has("monte carlo") { return track_monaco }
            if has("spa") || has("francorchamps") { return track_spa }
            if has("gilles") && has("villeneuve") || has("montreal") { return track_gilles_villeneuve }
            if has("americas") || has("cota") || lower == "austin" { return track_cota }
            if has("zandvoort") { return track_zandvoort }
            if has("madrid") || has("madring") { return track_madrid }
            if has("hungaroring") || lower == "budapest" { return track_hungaroring }
            if has("jeddah") { return track_jeddah }
            if has("lusail") || (has("qatar") && !has("yas")) { return track_lusail }
            if has("marina bay") || has("singapore") { return track_marina_bay }
            if has("miami") { return track_miami }
            if has("red bull ring") || lower == "spielberg" || (has("austria") && has("spielberg")) { return track_red_bull_ring }
            if has("shanghai") { return track_shanghai }
            if has("silverstone") { return track_silverstone }
            if has("suzuka") { return track_suzuka }
            if has("las vegas") || has("vegas strip") { return track_las_vegas }
            if has("yas marina") || has("abu dhabi") { return track_yas_marina }
            return nil
        }

        // Drivers (фото гонщиков из Assets.xcassets/Drivers)
        static let driver_alexander_albon: String = "alexander_albon"
        static let driver_arvid_lindblad: String = "arvid_lindblad"
        static let driver_carlos_sainz: String = "carlos_sainz"
        static let driver_charles_leclerc: String = "charles_leclerc"
        static let driver_esteban_ocon: String = "esteban_ocon"
        static let driver_fernando_alonso: String = "fernando_alonso"
        static let driver_franco_colapinto: String = "franco_colapinto"
        static let driver_gabriel_bortoleto: String = "gabriel_bortoleto"
        static let driver_george_russell: String = "george_russell"
        static let driver_isack_hadjar: String = "isack_hadjar"
        static let driver_kimi_antonelli: String = "kimi_antonelli"
        static let driver_lance_stroll: String = "lance_stroll"
        static let driver_lewis_hamilton: String = "lewis _hamilton"
        static let driver_liam_lawson: String = "liam_lawson"
        static let driver_max_verstappen: String = "max_verstappen"
        static let driver_nico_hulkenberg: String = "nico_hulkenberg"
        static let driver_oliver_bearman: String = "oliver_bearman"
        static let driver_oscar_piastri: String = "oscar_piastri"
        static let driver_pierre_gasly: String = "pierre_gasly"
        static let driver_sergio_perez: String = "sergio_perez"
        static let driver_valtteri_bottas: String = "valtteri_bottas"
        static let driver_lando_norris: String = "lando_norris"
        /// Имя ассета фото гонщика по driver_id (например из API: "max_verstappen").
        static func driverPhoto(driverId: String) -> String? {
            let id = driverId.lowercased().replacingOccurrences(of: " ", with: "_")
            let map: [String: String] = [
                "alexander_albon": driver_alexander_albon,
                "arvid_lindblad": driver_arvid_lindblad,
                "carlos_sainz": driver_carlos_sainz,
                "charles_leclerc": driver_charles_leclerc,
                "esteban_ocon": driver_esteban_ocon,
                "fernando_alonso": driver_fernando_alonso,
                "franco_colapinto": driver_franco_colapinto,
                "gabriel_bortoleto": driver_gabriel_bortoleto,
                "george_russell": driver_george_russell,
                "isack_hadjar": driver_isack_hadjar,
                "kimi_antonelli": driver_kimi_antonelli,
                "lance_stroll": driver_lance_stroll,
                "lewis_hamilton": driver_lewis_hamilton,
                "liam_lawson": driver_liam_lawson,
                "max_verstappen": driver_max_verstappen,
                "nico_hulkenberg": driver_nico_hulkenberg,
                "oliver_bearman": driver_oliver_bearman,
                "oscar_piastri": driver_oscar_piastri,
                "pierre_gasly": driver_pierre_gasly,
                "sergio_perez": driver_sergio_perez,
                "valtteri_bottas": driver_valtteri_bottas,
                "lando_norris": driver_lando_norris,
            ]
            return map[id]
        }

        /// Ключ вида `max_verstappen` из полного имени (как в Races / подиум).
        static func driverIdFromFullName(_ name: String) -> String {
            name.lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "é", with: "e")
                .replacingOccurrences(of: "ö", with: "o")
        }

        /// Имя imageset в `Assets.xcassets/Drivers` для виджета и карточек.
        static func driverPhotoAsset(forFullName name: String) -> String {
            let id = driverIdFromFullName(name)
            return driverPhoto(driverId: id) ?? "max_verstappen"
        }

        // Номера гонщиков (стилизованные изображения из Numbers)
        private static let driverNumberAssetNames: Set<Int> = [1, 3, 5, 6, 10, 11, 12, 14, 16, 18, 23, 27, 30, 31, 41, 43, 44, 55, 63, 77, 81, 87]
        /// Имя ассета для номера гонщика (driver_number). Возвращает nil, если изображения для этого номера нет.
        static func driverNumber(_ number: Int) -> String? {
            driverNumberAssetNames.contains(number) ? "\(number)" : nil
        }
    }
}
