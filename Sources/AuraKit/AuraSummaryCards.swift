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
    /// snapshot carries none of them, so the slot falls back to the empty state.
    private var line: Text? {
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
        if let alert = snapshot.alert {
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

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let alert = snapshot.alert {
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
