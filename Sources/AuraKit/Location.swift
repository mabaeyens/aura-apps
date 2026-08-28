import Foundation

/// A place Aura can show weather for: a Spanish municipality identified by its INE code,
/// with the coordinates needed for on-device sun times.
///
/// AEMET forecasts are keyed by the 5-digit INE municipality code; the official text
/// bulletins are keyed by the 2-digit province code, which is simply the first two digits
/// of the INE code — so no separate province table is needed.
public struct Location: Codable, Identifiable, Hashable, Sendable {
    public var id: String { ine }

    /// 5-digit INE municipality code, e.g. "28079" (Madrid).
    public let ine: String
    /// Municipality name, e.g. "Madrid".
    public let nombre: String
    /// Province name, e.g. "Madrid" or "A Coruña".
    public let provincia: String
    public let latitude: Double
    public let longitude: Double

    public init(ine: String, nombre: String, provincia: String, latitude: Double, longitude: Double) {
        self.ine = ine
        self.nombre = nombre
        self.provincia = provincia
        self.latitude = latitude
        self.longitude = longitude
    }

    /// 2-digit INE province code, derived from the municipality code (e.g. "28" from "28079").
    public var provinciaCode: String { String(ine.prefix(2)) }

    /// The location's civil time zone. The Canary Islands (INE provinces 35 and 38) run one
    /// hour behind mainland Spain; everywhere else uses Europe/Madrid. Lives here rather than in the
    /// app target because the widget's refresh core resolves snapshots and needs the same zone.
    public var timeZone: TimeZone {
        switch provinciaCode {
        case "35", "38": return TimeZone(identifier: "Atlantic/Canary") ?? .current
        default: return TimeZone(identifier: "Europe/Madrid") ?? .current
        }
    }
}
