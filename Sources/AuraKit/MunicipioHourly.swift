import Foundation

/// AEMET's hourly municipal forecast (`prediccion/especifica/municipio/horaria/{ine}`).
///
/// Each `Dia` carries parallel hourly arrays keyed by `periodo` (the hour, "00"–"23"), except
/// `probPrecipitacion`, which AEMET reports in coarser multi-hour blocks (periodo like "0814").
/// All values arrive as strings.
public struct MunicipioHourly: Decodable, Sendable {
    public let nombre: String
    public let provincia: String
    public let prediccion: Prediccion

    public struct Prediccion: Decodable, Sendable {
        public let dia: [Dia]
    }

    public struct Dia: Decodable, Sendable {
        public let fecha: String
        public let orto: String?
        public let ocaso: String?
        public let temperatura: [HourValue]
        public let estadoCielo: [SkyValue]
        public let humedadRelativa: [HourValue]
        public let probPrecipitacion: [HourValue]
        /// Wind and peak gust, hour by hour. Mixed entries: wind entries carry `direccion`+`velocidad`
        /// (single-element string arrays), gust entries only a scalar `value`. Optional — some
        /// municipal responses omit it.
        public let vientoAndRachaMax: [WindValue]?
    }

    /// A wind reading (`direccion`+`velocidad`) or a gust (`value`) at `periodo`.
    public struct WindValue: Decodable, Sendable {
        public let periodo: String
        public let direccion: [String]?
        public let velocidad: [String]?
        public let value: String?
    }

    /// An hourly (or block) reading: the string `value` at `periodo`.
    public struct HourValue: Decodable, Sendable {
        public let value: String
        public let periodo: String
    }

    /// Sky state: a code (e.g. "11", "11n" at night) plus AEMET's Spanish description.
    public struct SkyValue: Decodable, Sendable {
        public let value: String
        public let periodo: String
        public let descripcion: String?
    }
}
