import Foundation

/// Maps AEMET's `estadoCielo` codes to SF Symbol names, honouring the night ("n"-suffixed)
/// variants. Symbols are chosen to read both in full colour (Home Screen / StandBy / Mac) and in a
/// single tint (Lock Screen / watch), per the plan's hard constraint. Refined in Phase 4.
public enum WeatherIcon {
    /// SF Symbol for a sky-state code (e.g. "11", "13n"). Falls back to a neutral cloud.
    public static func symbol(forSky code: String?) -> String {
        guard let code, !code.isEmpty else { return "cloud.fill" }
        let night = code.hasSuffix("n")
        let base = night ? String(code.dropLast()) : code

        switch base {
        case "11": return night ? "moon.stars.fill" : "sun.max.fill"
        case "12": return night ? "cloud.moon.fill" : "cloud.sun.fill"
        case "13", "17": return night ? "cloud.moon.fill" : "cloud.sun.fill"
        case "14", "15": return "cloud.fill"
        case "16": return "smoke.fill"
        case "23", "43": return night ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case "24", "44", "45": return "cloud.rain.fill"
        case "25", "26", "46": return "cloud.heavyrain.fill"
        case "33", "34", "71", "72": return "cloud.snow.fill"
        case "35", "36", "73", "74": return "snowflake"
        case "51", "52", "61", "62": return night ? "cloud.moon.bolt.fill" : "cloud.sun.bolt.fill"
        case "53", "54", "63", "64": return "cloud.bolt.rain.fill"
        default: return night ? "cloud.moon.fill" : "cloud.sun.fill"
        }
    }

    /// SF Symbol for a sky-state code, but forcing the day or night variant from a caller that knows
    /// the actual time of day (from the location's sun times) rather than the AEMET code's own suffix.
    public static func symbol(forSky code: String?, isNight: Bool) -> String {
        guard let code, !code.isEmpty else { return isNight ? "moon.stars.fill" : "sun.max.fill" }
        let base = code.hasSuffix("n") ? String(code.dropLast()) : code
        return symbol(forSky: isNight ? base + "n" : base)
    }
}
