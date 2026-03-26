//
//  DriverNationality.swift
//  Podium
//
//  OpenF1 часто отдаёт `country_code: null` у drivers — тогда используем alpha-2 по известной сетке.
//

import Foundation

enum DriverNationality {
    /// Нормализует код из API (ISO2, ISO3 или пусто) и иначе берёт запасной alpha-2 по имени.
    static func resolveCountryCode(apiCode: String?, fullName: String) -> String {
        let t = apiCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let upper = t.uppercased().filter { $0.isLetter }
        if upper.count == 2 { return String(upper.prefix(2)) }
        if upper.count >= 3, let two = iso3ToAlpha2[upper] { return two }
        return fallbackAlpha2(forFullName: fullName)
    }

    private static let iso3ToAlpha2: [String: String] = [
        "NED": "NL", "GBR": "GB", "AUS": "AU", "MON": "MC", "USA": "US",
        "CAN": "CA", "MEX": "MX", "JPN": "JP", "CHN": "CN", "BRA": "BR",
        "ITA": "IT", "FRA": "FR", "GER": "DE", "DEU": "DE", "ESP": "ES",
        "AUT": "AT", "BEL": "BE", "HUN": "HU", "SIN": "SG", "UAE": "AE",
        "QAT": "QA", "AZE": "AZ", "THA": "TH", "NZL": "NZ", "ARG": "AR",
        "FIN": "FI", "KOR": "KR", "RSA": "ZA", "DEN": "DK", "SWE": "SE",
        "POL": "PL", "CHL": "CL", "COL": "CO", "IND": "IN", "PRY": "PY"
    ]

    private static func fallbackAlpha2(forFullName name: String) -> String {
        let id = String.AppImage.driverIdFromFullName(name)
        return map[id] ?? ""
    }

    /// Ключ — как `driverIdFromFullName` (snake_case).
    private static let map: [String: String] = [
        "alexander_albon": "TH",
        "arvid_lindblad": "GB",
        "carlos_sainz": "ES",
        "charles_leclerc": "MC",
        "esteban_ocon": "FR",
        "fernando_alonso": "ES",
        "franco_colapinto": "AR",
        "gabriel_bortoleto": "BR",
        "george_russell": "GB",
        "isack_hadjar": "FR",
        "kimi_antonelli": "IT",
        "lance_stroll": "CA",
        "lando_norris": "GB",
        "lewis_hamilton": "GB",
        "liam_lawson": "NZ",
        "max_verstappen": "NL",
        "nico_hulkenberg": "DE",
        "oliver_bearman": "GB",
        "oscar_piastri": "AU",
        "pierre_gasly": "FR",
        "sergio_perez": "MX",
        "valtteri_bottas": "FI"
    ]
}
