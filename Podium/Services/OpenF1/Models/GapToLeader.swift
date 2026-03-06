//
//  GapToLeader.swift
//  Podium
//

import Foundation

enum GapToLeader: Codable {
    case seconds(Double)
    case lap(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { throw DecodingError.valueNotFound(GapToLeader.self, .init(codingPath: c.codingPath, debugDescription: "null")) }
        if let d = try? c.decode(Double.self) { self = .seconds(d); return }
        if let i = try? c.decode(Int.self) { self = .seconds(Double(i)); return }
        if let s = try? c.decode(String.self) { self = .lap(s); return }
        throw DecodingError.typeMismatch(GapToLeader.self, .init(codingPath: c.codingPath, debugDescription: "Expected Double, Int or String"))
    }
}

extension GapToLeader {
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .seconds(let d): try c.encode(d)
        case .lap(let s): try c.encode(s)
        }
    }

    var display: String {
        switch self {
        case .seconds(let d): return String(format: "+%.3f", d)
        case .lap(let s): return s
        }
    }

    /// Numeric seconds for ordering/sorting (nil for .lap).
    var secondsValue: Double? {
        switch self {
        case .seconds(let d): return d
        case .lap: return nil
        }
    }
}
