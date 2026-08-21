import SwiftUI

/// Aura's shared colour system. The app and every widget/complication draw from here, so a given
/// temperature or sky condition looks the same on each surface. Kept in `AuraKit` for that reason.
public enum Palette {

    // MARK: Temperature → colour

    /// Temperature colour, blue (very cold) through deep red (terribly hot). Continuously interpolated
    /// between control stops, not banded — every degree gets a distinct colour and the progression reads
    /// as one smooth ramp. Tuned to the scale AEMET and TVE's "El Tiempo" use: blues and greens up to
    /// 20°, then warm tones (yellow → orange → red → near-black) above, with the green→yellow boundary at
    /// 20° and red around 30° (per RTVE/VerificaRTVE). So 20° reads green, 22° green-yellow, 27°
    /// yellow-orange, 30° orange, 33° red-orange. Stops tuned for mainland Spain.
    public static func temperature(_ celsius: Int?) -> Color {
        guard let t = celsius else { return .gray }
        return interpolatedTemperature(Double(t))
    }

    /// Control stops: (°C, red, green, blue). Between two stops the colour is linearly interpolated.
    /// The 20° green/yellow hand-off is the anchor of the TVE/AEMET scale; the hot end stays a deep
    /// legible maroon rather than the reference's literal black, which would vanish as tinted text.
    private static let tempStops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (-8, 0.40, 0.16, 0.56),   // violet — extreme cold
        (-2, 0.24, 0.28, 0.74),   // blue-violet
        ( 4, 0.20, 0.52, 0.90),   // blue
        (10, 0.24, 0.74, 0.82),   // cyan-teal
        (15, 0.34, 0.76, 0.55),   // green-teal
        (19, 0.46, 0.77, 0.37),   // green
        (22, 0.74, 0.80, 0.30),   // green-yellow (boundary at 20°)
        (25, 0.97, 0.83, 0.26),   // yellow
        (28, 0.98, 0.65, 0.20),   // amber
        (31, 0.96, 0.47, 0.18),   // orange
        (34, 0.90, 0.30, 0.20),   // red-orange
        (37, 0.80, 0.19, 0.19),   // red
        (41, 0.60, 0.11, 0.16),   // dark red
        (45, 0.40, 0.07, 0.13),   // deep maroon — the scale's "black" end, kept legible
    ]

    private static func interpolatedTemperature(_ t: Double) -> Color { lerp(t, tempStops) }

    /// Linear-interpolate a colour for `x` across `(threshold, r, g, b)` stops, clamped at both ends.
    /// Shared by the temperature and wind ramps.
    private static func lerp(_ x: Double, _ stops: [(t: Double, r: Double, g: Double, b: Double)]) -> Color {
        guard let first = stops.first, let last = stops.last else { return .gray }
        if x <= first.t { return Color(red: first.r, green: first.g, blue: first.b) }
        if x >= last.t  { return Color(red: last.r, green: last.g, blue: last.b) }
        for i in 0..<(stops.count - 1) {
            let a = stops[i], b = stops[i + 1]
            if x >= a.t && x <= b.t {
                let k = (x - a.t) / (b.t - a.t)
                return Color(red: a.r + (b.r - a.r) * k,
                             green: a.g + (b.g - a.g) * k,
                             blue: a.b + (b.b - a.b) * k)
            }
        }
        return .gray
    }

    // MARK: Wind speed → colour

    /// Wind-speed colour, calm (pale blue) through gale (red) to violent storm (violet), continuously
    /// interpolated — modelled on Windy's wind scale so a glance at the vane reads intensity. Values in
    /// km/h, the unit AEMET reports. Used by the Watch wind complications' vane.
    public static func wind(_ kmh: Int?) -> Color {
        guard let v = kmh else { return tempTeal }
        return lerp(Double(v), windStops)
    }

    private static let windStops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (  0, 0.55, 0.80, 0.92),   // calm — pale blue
        ( 12, 0.30, 0.80, 0.72),   // light — teal
        ( 22, 0.42, 0.80, 0.40),   // moderate — green
        ( 32, 0.86, 0.84, 0.28),   // fresh — yellow
        ( 45, 0.97, 0.62, 0.20),   // strong — orange
        ( 60, 0.92, 0.34, 0.22),   // very strong — red-orange
        ( 80, 0.84, 0.18, 0.28),   // gale — red
        (105, 0.66, 0.20, 0.62),   // storm — magenta
        (130, 0.52, 0.28, 0.78),   // violent — violet
    ]

    // MARK: Air quality (ICA category → colour)

    /// The official MITECO ICA colour for a 1–6 category: blue (buena) → green → yellow → red → dark red
    /// → violet (extremadamente desfavorable). Falls back to grey for an out-of-range/no-data value.
    public static func airQuality(_ category: Int) -> Color {
        switch category {
        case 1: return Color(red: 0.31, green: 0.66, blue: 0.93)   // buena — azul
        case 2: return Color(red: 0.30, green: 0.72, blue: 0.42)   // razonablemente buena — verde
        case 3: return Color(red: 0.96, green: 0.80, blue: 0.25)   // regular — amarillo
        case 4: return Color(red: 0.90, green: 0.29, blue: 0.24)   // desfavorable — rojo
        case 5: return Color(red: 0.60, green: 0.13, blue: 0.15)   // muy desfavorable — granate
        case 6: return Color(red: 0.60, green: 0.28, blue: 0.75)   // extremadamente desfavorable — violeta
        default: return Color(white: 0.55)
        }
    }

    // MARK: UV index → colour

    /// The WHO UV-index colour: green (bajo) → yellow → orange → red → violet (extremo), by band.
    public static func uvIndex(_ value: Int) -> Color {
        switch value {
        case ..<3:   return Color(red: 0.30, green: 0.72, blue: 0.42)   // bajo — verde
        case 3...5:  return Color(red: 0.96, green: 0.80, blue: 0.25)   // moderado — amarillo
        case 6...7:  return Color(red: 0.97, green: 0.58, blue: 0.18)   // alto — naranja
        case 8...10: return Color(red: 0.90, green: 0.29, blue: 0.24)   // muy alto — rojo
        default:     return Color(red: 0.60, green: 0.28, blue: 0.75)   // extremo — violeta
        }
    }

    /// The full cold→hot scale, for `Gauge` tints and range bars.
    public static let temperatureGradient = Gradient(colors: [
        tempDeepBlue, tempBlue, tempTeal, tempGreen, tempYellow, tempOrange, tempRed, tempPurple,
    ])

    /// The temperature scale sampled across just `[lo, hi]`, so a range bar shows the colours that
    /// actually apply — e.g. 24°→34° runs yellow→orange→red, not the whole blue→purple palette. One
    /// stop per degree keeps each colour aligned to its position along the bar.
    public static func temperatureGradient(min lo: Int, max hi: Int) -> Gradient {
        guard lo < hi else { return Gradient(colors: [temperature(lo)]) }
        return Gradient(colors: stride(from: lo, through: hi, by: 1).map { temperature($0) })
    }

    public static let tempDeepBlue = Color(red: 0.16, green: 0.28, blue: 0.78)
    public static let tempBlue     = Color(red: 0.25, green: 0.52, blue: 0.93)
    public static let tempTeal     = Color(red: 0.20, green: 0.74, blue: 0.80)
    public static let tempGreen    = Color(red: 0.30, green: 0.72, blue: 0.42)
    public static let tempYellow   = Color(red: 0.96, green: 0.80, blue: 0.25)
    public static let tempOrange   = Color(red: 0.97, green: 0.58, blue: 0.18)
    public static let tempRed      = Color(red: 0.90, green: 0.29, blue: 0.24)
    public static let tempPurple   = Color(red: 0.60, green: 0.28, blue: 0.75)

    /// Night moon glyph — a clear cool blue that reads on both a black face and a light complication
    /// well, rather than the flat pale white multicolour gives.
    public static let nightMoon    = Color(red: 0.42, green: 0.55, blue: 0.96)

    // MARK: Time of day → gradient

    /// A sky-coloured gradient that tracks the time of day: light blue in the morning, electric blue at
    /// midday, a darker warm-violet at dusk, deep blue at night. Interpolated between hourly anchors so
    /// it drifts smoothly. White text stays legible on every phase. Used behind the "Hoy" header card.
    public static func timeGradient(at date: Date = Date()) -> LinearGradient {
        let (top, bottom) = timeColors(at: date)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// Day-cycle anchors: (hour, topRGB, bottomRGB). The 24h anchor mirrors 0h so the loop wraps.
    private static let dayAnchors: [(h: Double,
                                     top: (Double, Double, Double),
                                     bot: (Double, Double, Double))] = [
        ( 0, (0.05, 0.07, 0.20), (0.10, 0.13, 0.30)),   // night
        ( 7, (0.24, 0.42, 0.76), (0.40, 0.60, 0.90)),   // dawn — light blue
        (13, (0.10, 0.40, 0.90), (0.26, 0.56, 0.96)),   // zenith — electric blue
        (19, (0.16, 0.20, 0.44), (0.40, 0.28, 0.46)),   // dusk — darker, warm hint
        (24, (0.05, 0.07, 0.20), (0.10, 0.13, 0.30)),   // night (wrap)
    ]

    /// The sky gradient's top and bottom colours for a given time — the base sky behind `AuraSky`,
    /// before the sun glow and scenery are layered on. Exposes the same day-cycle anchors the header
    /// card's `timeGradient` uses.
    public static func skyBaseColors(at date: Date = Date()) -> (top: Color, bottom: Color) {
        timeColors(at: date)
    }

    private static func timeColors(at date: Date) -> (Color, Color) {
        let cal = Calendar.current
        let h = Double(cal.component(.hour, from: date)) + Double(cal.component(.minute, from: date)) / 60
        for i in 0..<(dayAnchors.count - 1) {
            let a = dayAnchors[i], b = dayAnchors[i + 1]
            if h >= a.h && h <= b.h {
                let k = (h - a.h) / (b.h - a.h)
                func lerp(_ x: (Double, Double, Double), _ y: (Double, Double, Double)) -> Color {
                    Color(red: x.0 + (y.0 - x.0) * k,
                          green: x.1 + (y.1 - x.1) * k,
                          blue: x.2 + (y.2 - x.2) * k)
                }
                return (lerp(a.top, b.top), lerp(a.bot, b.bot))
            }
        }
        let n = dayAnchors[0]
        return (Color(red: n.top.0, green: n.top.1, blue: n.top.2),
                Color(red: n.bot.0, green: n.bot.1, blue: n.bot.2))
    }

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
