import Foundation

/// Subset of AEMET's daily municipality forecast, enough to prove the pipeline end to end.
/// Expanded field-by-field as later phases need hourly data, wind, sky state, etc.
public struct MunicipioForecast: Decodable, Sendable {
    public let nombre: String
    public let provincia: String
    public let prediccion: Prediccion

    public struct Prediccion: Decodable, Sendable {
        public let dia: [Dia]
    }

    public struct Dia: Decodable, Sendable {
        public let fecha: String
        public let temperatura: MinMax?
        public let humedadRelativa: MinMax?
        /// Sky state in coarse blocks (periodo like "00-24", "12-24"); `value` is the AEMET code.
        public let estadoCielo: [SkyBlock]?
        /// Wind in coarse blocks; daily `velocidad` is a plain integer (km/h), unlike the hourly feed.
        public let viento: [WindBlock]?
    }

    public struct MinMax: Decodable, Sendable {
        public let maxima: Int?
        public let minima: Int?
    }

    public struct SkyBlock: Decodable, Sendable {
        public let value: String
        public let periodo: String?
        public let descripcion: String?
    }

    public struct WindBlock: Decodable, Sendable {
        public let direccion: String?
        public let velocidad: Int?
        public let periodo: String?
    }
}
