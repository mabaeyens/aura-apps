import SwiftUI

// Lock Screen / watch glances that summarise the current conditions in the date-row and circular slots,
// beyond the existing rain/UV/sun faces:
//   • Resumen — one inline line of temp · lluvia · humedad, an alternative to Sol y Luna for the date slot.
//   • Humedad — the current relative humidity as a ring fill.
//   • Aviso   — a severe-weather mark, circular or inline, that disappears when nothing is active.
// All share AuraKit so the iPhone Lock Screen and the Apple Watch face render identical code; colour
// comes through on full-colour watch faces while the Lock Screen desaturates to weight + ring fill.

// MARK: - Resumen (inline)

/// `.accessoryInline`: the current conditions as one compact line — the condition glyph plus
/// `temp · lluvia · humedad`, each part dropped when its datum is missing so a thin snapshot still reads.
public struct AuraSummaryInline: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    /// The non-nil facts, each **prefixed by its own symbol** so the two percentages (rain, humidity) can
    /// never be mistaken for one another on a thin single line: 🌡 temp, ☂ rain, 💧 humidity. Built as a
    /// `Text` (not a joined string) because inline complications render embedded SF Symbols. Nil when the
    /// snapshot carries none of them, so the slot falls back to the empty state. Shared with
    /// `AuraSummaryRectangular` via `AuraSummaryFormat.line` so the two surfaces can't drift apart.
    private var line: Text? { AuraSummaryFormat.line(snapshot) }

    public var body: some View {
        if let line {
            Label {
                line
            } icon: {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky,
                                                     isNight: snapshot.isNight(at: now)))
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// `.accessoryCircular`: the condition glyph centred with the current temperature — the summary's
/// circular face, matching `AuraAirQualityCircular`'s centred framing. No ring (there's no bounded scale
/// for "current conditions"), so a clean icon-over-value read carries it, temperature-tinted like the
/// other circular temperature reads.
public struct AuraSummaryCircular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let temp = snapshot.heroTemp {
            VStack(spacing: 1) {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky, isNight: snapshot.isNight(at: now)))
                    .font(.title2)
                Text("\(temp)°")
                    .font(.title3).fontWeight(.semibold).fontDesign(.rounded)
                    .foregroundStyle(Palette.temperature(temp))
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// `.accessoryCorner` (Apple Watch): the condition glyph alone in the corner, with the current
/// temperature on the curved bezel. Current conditions are a state, not a bounded value, so this is
/// plain corner content + a `cornerLabel`, never a gauge — the same idiom as `AuraAvisoCorner`.
public struct AuraSummaryCorner: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky, isNight: snapshot.isNight(at: now)))
            .font(.title3)
    }

    /// The curved bezel label: the current temperature.
    public var cornerLabel: String { snapshot.heroTemp.map { "\($0)°" } ?? "—°" }
}

/// `.accessoryRectangular`: the condition icon beside the `temp · lluvia · humedad` line — the
/// rectangular mate to `AuraSummaryInline`, following the same `GeometryReader` width branch, per-datum
/// nil-drops and whole-line `Text` concatenation as `AuraAccessoryRectangular`.
public struct AuraSummaryRectangular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let line = AuraSummaryFormat.line(snapshot) {
            GeometryReader { geo in
                let wide = geo.size.width > 220
                HStack(alignment: .center, spacing: wide ? 12 : 8) {
                    Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky, isNight: snapshot.isNight(at: now)))
                        .font(wide ? .title : .title2)
                    line
                        .font(wide ? .subheadline : .caption)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// Shared `temp · lluvia · humedad` line-building for `AuraSummaryInline` and `AuraSummaryRectangular`,
/// so the two surfaces render the same facts and can't drift apart. See `AuraSummaryInline` for the
/// design rationale (nil-drop per datum, symbol-prefixed Text so the two percentages read unambiguously).
private enum AuraSummaryFormat {
    static func line(_ snapshot: WeatherSnapshot) -> Text? {
        let sp = "\u{2009}"           // thin space, symbol snug to its number
        let gap = Text("  ")
        var parts: [Text] = []
        if let t = snapshot.heroTemp {
            parts.append(Text(Image(systemName: "thermometer.medium")) + Text(sp + "\(t)°"))
        }
        if let p = snapshot.currentPrecipProb {
            parts.append(Text(Image(systemName: "umbrella.fill")) + Text(sp + "\(p)%"))
        }
        if let h = snapshot.currentHumidity {
            parts.append(Text(Image(systemName: "humidity.fill")) + Text(sp + "\(h)%"))
        }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + gap + $1 }
    }
}

// MARK: - Humedad (circular)

/// `.accessoryCircular`: the current relative humidity as a ring fill on 0…100%, with a drop glyph and
/// the percentage in the centre. The value is encoded by the ring (shape, not hue) so it still reads on
/// the desaturated Lock Screen; the blue tint comes through on full-colour watch faces.
public struct AuraHumidityCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    /// Current relative humidity, %, or nil on a thin snapshot (no hourly feed).
    private var humidity: Int? { snapshot.currentHumidity }

    public var body: some View {
        if let humidity {
            Gauge(value: Double(humidity), in: 0...100) {
                Image(systemName: "humidity.fill")
            } currentValueLabel: {
                Text("\(humidity)")
                    .fontWeight(.semibold).fontDesign(.rounded)
                    .foregroundStyle(.teal)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.teal)
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// `.accessoryCorner` (Apple Watch): the current relative humidity as the drop glyph + percentage in the
/// corner, with a curved 0…100 % gauge along the outer bezel. Humidity is a bounded scale, so it takes the
/// bezel gauge (like UV and ICA). Corner mate to `AuraHumidityCircular`.
public struct AuraHumidityCorner: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    private var humidity: Int? { snapshot.currentHumidity }

    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "humidity.fill")
            Text(humidity.map { "\($0)" } ?? "—")
                .fontWeight(.bold).fontDesign(.rounded)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.title3)
        .foregroundStyle(.teal)
    }

    /// Whether humidity is known, so the bezel gauge can be drawn (else fall back to `cornerLabel`).
    public var hasValue: Bool { humidity != nil }

    /// The curved bezel gauge: the current humidity on a 0…100 % scale, tinted teal, 0 and 100 at the ends.
    @ViewBuilder public var cornerGauge: some View {
        if let humidity {
            Gauge(value: Double(humidity), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
            }
            .tint(.teal)
        }
    }

    /// Fallback bezel label when the gauge is skipped — the percentage.
    public var cornerLabel: String { humidity.map { "\($0)%" } ?? "—" }
}

// MARK: - Aviso

/// `.accessoryCircular`: a severe-weather aviso mark — a warning triangle over "Aviso", tinted to the
/// AEMET level (amarillo/naranja/rojo). The empty state when no warning is active for the location, so
/// the face simply reads "Abre Aura" rather than a stale or blank ring.
public struct AuraAvisoCircular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let alert = snapshot.activeAlert(at: now) {
            VStack(spacing: 1) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.alert(alert.level))
                Text("Aviso")
                    .font(.caption2).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        } else {
            // Calm state: the warning sign struck through, in grey — the data is present, there's simply
            // no active aviso. No text ("Sin avisos" clips in the circular slot), and NOT the
            // snapshot-missing "Abre Aura" state. There's no stock slashed-triangle symbol, so overlay a
            // diagonal line over the triangle.
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
                .overlay {
                    Image(systemName: "line.diagonal")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

/// `.accessoryInline`: the active aviso as one line — a warning triangle plus the phenomenon
/// ("Tormentas", "Lluvia"…) or just "Aviso" when the feed names no phenomenon. Empty when none is active.
public struct AuraAvisoInline: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let alert = snapshot.activeAlert(at: now) {
            Label {
                Text(alert.phenomenon ?? "Aviso")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        } else {
            // Calm state, not missing data — see AuraAvisoCircular. Struck-through warning sign, grey.
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .overlay {
                    Image(systemName: "line.diagonal")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

/// `.accessoryCorner` (Apple Watch): the active aviso as a level-tinted triangle in the corner, with the
/// phenomenon on the curved bezel. An aviso is a state, not a bounded value, so this is plain corner text +
/// glyph, never a gauge. When nothing is active it shows the same struck-through calm mark as the circular.
public struct AuraAvisoCorner: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let alert = snapshot.activeAlert(at: now) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Palette.alert(alert.level))
        } else {
            // Calm state, not missing data — the warning sign struck through, in grey.
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .overlay {
                    Image(systemName: "line.diagonal")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    /// The curved bezel label: the phenomenon when an aviso is active, else the calm "Sin avisos".
    public var cornerLabel: String {
        if let alert = snapshot.activeAlert(at: now) { return alert.phenomenon ?? "Aviso" }
        return "Sin avisos"
    }
}

/// `.accessoryRectangular`: the aviso as a level-tinted triangle beside the phenomenon and its level —
/// the rectangular mate to `AuraAvisoCircular`/`AuraAvisoCorner`, following the same `GeometryReader`
/// width branch as `AuraAccessoryRectangular`. Calm state mirrors the circular/corner faces: the
/// struck-through triangle in grey, "Sin avisos" — data is present, there's simply nothing active.
public struct AuraAvisoRectangular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 220
            if let alert = snapshot.activeAlert(at: now) {
                active(alert, wide: wide)
            } else {
                calm(wide: wide)
            }
        }
    }

    private func active(_ alert: WeatherAlert, wide: Bool) -> some View {
        HStack(alignment: .center, spacing: wide ? 12 : 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(wide ? .title : .title2)
                .foregroundStyle(Palette.alert(alert.level))
            VStack(alignment: .leading, spacing: 1) {
                Text(alert.phenomenon ?? "Aviso")
                    .font(wide ? .subheadline : .caption).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("Nivel \(alert.level.rawValue)")
                    .font(wide ? .footnote : .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func calm(wide: Bool) -> some View {
        Label {
            Text("Sin avisos")
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .overlay {
                    Image(systemName: "line.diagonal")
                }
        }
        .font(wide ? .subheadline : .caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
