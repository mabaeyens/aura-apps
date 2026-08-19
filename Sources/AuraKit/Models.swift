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
    }

    public struct MinMax: Decodable, Sendable {
        public let maxima: Int?
        public let minima: Int?
    }
}
