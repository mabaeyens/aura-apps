import SwiftUI

/// Aura's shared colour system. The app and every widget/complication draw from here, so a given
/// temperature or sky condition looks the same on each surface. Kept in `AuraKit` for that reason.
public enum Palette {

    // MARK: Temperature → colour

    /// Temperature colour, blue (very cold) through purple (terribly hot). Bands tuned for mainland
    /// Spain: ≤0 deep blue · 1–8 blue · 9–15 teal · 16–21 green · 22–27 yellow · 28–33 orange ·
    /// 34–39 red · ≥40 purple.
    public static func temperature(_ celsius: Int?) -> Color {
        guard let t = celsius else { return .gray }
        switch t {
        case ..<1:    return tempDeepBlue
        case 1...8:   return tempBlue
        case 9...15:  return tempTeal
        case 16...21: return tempGreen
        case 22...27: return tempYellow
        case 28...33: return tempOrange
        case 34...39: return tempRed
        default:      return tempPurple      // ≥ 40
        }
    }

    /// The full cold→hot scale, for `Gauge` tints and range bars.
    public static let temperatureGradient = Gradient(colors: [
        tempDeepBlue, tempBlue, tempTeal, tempGreen, tempYellow, tempOrange, tempRed, tempPurple,
    ])

    public static let tempDeepBlue = Color(red: 0.16, green: 0.28, blue: 0.78)
    public static let tempBlue     = Color(red: 0.25, green: 0.52, blue: 0.93)
    public static let tempTeal     = Color(red: 0.20, green: 0.74, blue: 0.80)
    public static let tempGreen    = Color(red: 0.30, green: 0.72, blue: 0.42)
    public static let tempYellow   = Color(red: 0.96, green: 0.80, blue: 0.25)
    public static let tempOrange   = Color(red: 0.97, green: 0.58, blue: 0.18)
    public static let tempRed      = Color(red: 0.90, green: 0.29, blue: 0.24)
    public static let tempPurple   = Color(red: 0.60, green: 0.28, blue: 0.75)

    // MARK: Sky condition → gradient

    /// Coarse weather category derived from an AEMET `estadoCielo` code (night `n` suffix stripped).
    public enum Sky {
        case clear, fewClouds, clouds, overcast, rain, storm, snow, fog, unknown
    }

    /// Categorise an AEMET `estadoCielo` code; `isNight` reflects the code's trailing `n`.
    public static func sky(forCode code: String?) -> (category: Sky, isNight: Bool) {
        guard let code, !code.isEmpty else { return (.unknown, false) }
        let isNight = code.hasSuffix("n")
        let base = isNight ? String(code.dropLast()) : code
        switch Int(base) ?? -1 {
        case 11, 17:                         return (.clear, isNight)
        case 12, 13:                         return (.fewClouds, isNight)
        case 14, 15:                         return (.clouds, isNight)
        case 16:                             return (.overcast, isNight)
        case 23, 24, 25, 26, 43, 44, 45, 46: return (.rain, isNight)
        case 51, 52, 53, 54, 61, 62, 63, 64: return (.storm, isNight)
        case 33, 34, 35, 36, 71, 72, 73, 74: return (.snow, isNight)
        case 81, 82, 83:                     return (.fog, isNight)
        default:                             return (.unknown, isNight)
        }
    }

    /// A top-to-bottom background gradient for a sky code — the mood colour behind a card or the
    /// Watch app. Night variants go deep and desaturated.
    public static func skyGradient(forCode code: String?) -> LinearGradient {
        let (category, isNight) = sky(forCode: code)
        return LinearGradient(colors: skyColors(category, isNight: isNight),
                              startPoint: .top, endPoint: .bottom)
    }

    private static func skyColors(_ category: Sky, isNight: Bool) -> [Color] {
        if isNight {
            switch category {
            case .clear, .fewClouds: return [Color(red: 0.06, green: 0.10, blue: 0.28),
                                             Color(red: 0.12, green: 0.16, blue: 0.38)]
            case .clouds, .overcast: return [Color(red: 0.14, green: 0.16, blue: 0.24),
                                             Color(red: 0.20, green: 0.22, blue: 0.30)]
            case .rain, .storm:      return [Color(red: 0.10, green: 0.12, blue: 0.22),
                                             Color(red: 0.18, green: 0.18, blue: 0.30)]
            case .snow:              return [Color(red: 0.16, green: 0.20, blue: 0.30),
                                             Color(red: 0.26, green: 0.30, blue: 0.40)]
            case .fog:               return [Color(red: 0.18, green: 0.20, blue: 0.24),
                                             Color(red: 0.26, green: 0.28, blue: 0.32)]
            case .unknown:           return [Color(red: 0.10, green: 0.13, blue: 0.24),
                                             Color(red: 0.18, green: 0.20, blue: 0.30)]
            }
        }
        switch category {
        case .clear:      return [Color(red: 0.20, green: 0.52, blue: 0.92),
                                  Color(red: 0.45, green: 0.72, blue: 0.98)]
        case .fewClouds:  return [Color(red: 0.30, green: 0.56, blue: 0.90),
                                  Color(red: 0.56, green: 0.74, blue: 0.94)]
        case .clouds:     return [Color(red: 0.42, green: 0.53, blue: 0.66),
                                  Color(red: 0.60, green: 0.68, blue: 0.78)]
        case .overcast:   return [Color(red: 0.40, green: 0.46, blue: 0.54),
                                  Color(red: 0.56, green: 0.61, blue: 0.68)]
        case .rain:       return [Color(red: 0.30, green: 0.40, blue: 0.55),
                                  Color(red: 0.46, green: 0.56, blue: 0.68)]
        case .storm:      return [Color(red: 0.26, green: 0.28, blue: 0.42),
                                  Color(red: 0.40, green: 0.42, blue: 0.55)]
        case .snow:       return [Color(red: 0.60, green: 0.70, blue: 0.82),
                                  Color(red: 0.80, green: 0.86, blue: 0.94)]
        case .fog:        return [Color(red: 0.55, green: 0.59, blue: 0.63),
                                  Color(red: 0.72, green: 0.75, blue: 0.78)]
        case .unknown:    return [Color(red: 0.30, green: 0.50, blue: 0.78),
                                  Color(red: 0.50, green: 0.66, blue: 0.86)]
        }
    }

    /// An accent tint for a sky condition — the icon/foreground colour that reads on a neutral card.
    public static func skyAccent(forCode code: String?) -> Color {
        let (category, isNight) = sky(forCode: code)
        if isNight { return Color(red: 0.62, green: 0.68, blue: 0.86) }
        switch category {
        case .clear, .fewClouds: return tempYellow
        case .clouds, .overcast: return Color(red: 0.52, green: 0.58, blue: 0.66)
        case .rain:              return tempBlue
        case .storm:             return tempPurple
        case .snow:              return tempTeal
        case .fog:               return Color(red: 0.60, green: 0.63, blue: 0.66)
        case .unknown:           return tempBlue
        }
    }

    // MARK: Alert level → colour

    /// The colour for an avisos severity level (verde/amarillo/naranja/rojo).
    public static func alert(_ level: WeatherAlert.Level) -> Color {
        switch level {
        case .verde:    return tempGreen
        case .amarillo: return tempYellow
        case .naranja:  return tempOrange
        case .rojo:     return tempRed
        }
    }
}
