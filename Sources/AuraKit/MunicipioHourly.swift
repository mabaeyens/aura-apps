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
