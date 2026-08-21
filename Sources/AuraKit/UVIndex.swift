import Foundation

/// AEMET's forecast daily-maximum UV index for a location, under clear-sky conditions (product
/// `prediccion/especifica/uvi/{dia}`, dia 0 = today). A single integer per provincial capital, on the
/// standard WHO 0–11+ scale; the band names and protection advice follow AEMET/WHO.
public struct UVIndex: Codable, Sendable, Hashable {
    /// Clear-sky daily-max UV index (0…11+).
    public let value: Int
    public init(value: Int) { self.value = value }

    /// WHO band name in Spanish.
    public var bandName: String {
        switch value {
        case ..<3:    return "Bajo"
        case 3...5:   return "Moderado"
        case 6...7:   return "Alto"
        case 8...10:  return "Muy alto"
        default:      return "Extremadamente alto"
        }
    }

    /// A one-line protection cue for the band.
    public var advice: String {
        switch value {
        case ..<3:    return "Sin protección necesaria"
        case 3...5:   return "Gafas de sol y crema"
        case 6...7:   return "Protección recomendada"
        case 8...10:  return "Evita el sol del mediodía"
        default:      return "Evita la exposición al sol"
        }
    }
}

public extension UVIndex {
    /// The UV index for an INE municipio code, from the parsed forecast cities, or nil if the city
    /// isn't listed or its value doesn't parse. AEMET keys each city by its INE code (`id`), so this is
    /// an exact match — the same code the snapshot carries.
    static func pick(ine: String, in cities: [UVIForecast.City]) -> UVIndex? {
        guard let city = cities.first(where: { $0.id == ine }), let v = Int(city.uv) else { return nil }
        return UVIndex(value: v)
    }
}

/// The `uvi/{dia}` payload: one object (not the array most `/prediccion` products use) with an issue/
/// validity header and one entry per provincial capital.
public struct UVIForecast: Decodable, Sendable {
    public let fechaValidez: String?
    public let ciudad: [City]

    enum CodingKeys: String, CodingKey {
        case fechaValidez = "FECHA_VALIDEZ"
        case ciudad = "CIUDAD"
    }

    public struct City: Decodable, Sendable {
        /// INE municipio code, e.g. "28079" for Madrid.
        public let id: String
        /// Display name, e.g. "Madrid".
        public let valor: String?
        /// The daily-max UV index, as a string integer.
        public let uv: String
    }
}
