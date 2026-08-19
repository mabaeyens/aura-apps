import Foundation

/// 16-point compass rose with Spanish (rosa de los vientos) abbreviations and names.
///
/// Meteorological convention: the bearing is the direction the wind blows *from*.
public enum WindDirection: Int, CaseIterable, Sendable {
    case n, nne, ne, ene, e, ese, se, sse, s, sso, so, oso, o, ono, no, nno

    private static let abbreviations = [
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO",
    ]

    private static let names = [
        "Norte", "Nornordeste", "Nordeste", "Estenordeste",
        "Este", "Estesudeste", "Sudeste", "Sursudeste",
        "Sur", "Sursudoeste", "Sudoeste", "Oessudoeste",
        "Oeste", "Oesnoroeste", "Noroeste", "Nornoroeste",
    ]

    /// Spanish abbreviation, e.g. "ONO".
    public var abbreviation: String { Self.abbreviations[rawValue] }

    /// Full Spanish name, e.g. "Oesnoroeste".
    public var spanishName: String { Self.names[rawValue] }

    /// Bearing in degrees at the centre of this sector (N = 0, E = 90, ...).
    public var degrees: Double { Double(rawValue) * 22.5 }

    /// Nearest 16-point direction for a bearing in degrees.
    public init(degrees: Double) {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let positive = wrapped < 0 ? wrapped + 360 : wrapped
        let index = Int((positive / 22.5).rounded()) % 16
        self = WindDirection(rawValue: index)!
    }
}
