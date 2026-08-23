import SwiftUI

// Lock Screen and Apple Watch accessory cards. Like the home-screen cards these live in AuraKit so
// every surface renders identical code, and they stay pure SwiftUI — the widget applies the accessory
// container background. The iOS Lock Screen renders these in a monochrome/vibrant mode, so colour is
// ignored there; on watchOS full-colour faces the temperature tints and multicolour condition icons
// come through.

// MARK: - Circular (Conditions + Temp)

/// `.accessoryCircular`: today's range as a ring, temperature-tinted, with the current temperature in
/// the middle. Falls back to icon + temp when the range is unknown.
public struct AuraAccessoryCircular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    /// Condition glyph resolved to the actual time of day — a yellow sun by day, a blue moon after
    /// sunset, a grey cloud when overcast — not a flat white sun at night.
    private var conditionIcon: some View {
        ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now))
    }

    public var body: some View {
        if let value = gaugeValue, let lo = snapshot.tempMin, let hi = snapshot.tempMax, lo < hi {
            Gauge(value: value, in: Double(lo)...Double(hi)) {
                conditionIcon.font(.callout)
            } currentValueLabel: {
                // Fill the ring's centre: a large, bold temperature reads at a glance, matching the
                // scale Carrot uses rather than the default caption-sized value label.
                Text(AccessoryFormat.temp(current))
                    .font(.title3).fontWeight(.semibold).fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
            .gaugeStyle(.accessoryCircular)
            // The track gradients across today's actual range, so a warm day reads orange-red and a
            // cold one blue-teal — not a single flat tint.
            .tint(Palette.temperatureGradient(min: lo, max: hi))
        } else {
            VStack(spacing: 1) {
                conditionIcon.font(.title2)
                Text(AccessoryFormat.temp(current))
                    .font(.title3).fontWeight(.semibold).fontDesign(.rounded)
                    .foregroundStyle(Palette.temperature(current))
            }
        }
    }

    private var current: Int? { snapshot.heroTemp }

    /// The current temperature clamped into today's range so the ring never overflows.
    private var gaugeValue: Double? {
        guard let current, let lo = snapshot.tempMin, let hi = snapshot.tempMax else { return nil }
        return Double(min(max(current, lo), hi))
    }
}

// MARK: - Rectangular

/// `.accessoryRectangular`: location + condition, the current temperature (temp-tinted), today's range.
public struct AuraAccessoryRectangular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        // iPadOS offers a far more generous rectangular Lock Screen slot than iPhone's narrow ~160pt
        // one, so branch on the real width the widget is given: the wide layout fills the iPad's ~2×2
        // space with a two-column read, while iPhone (and the Watch) keep the compact stack. The
        // threshold sits well above any iPhone rectangular slot and below the iPad's, so it degrades
        // gracefully — a smaller slot simply never takes the wide branch.
        GeometryReader { geo in
            if geo.size.width > 220 {
                wide
            } else {
                compact
            }
        }
    }

    /// The day's figures as a single line, so `minimumScaleFactor` scales them together and the last one
    /// never truncates off the narrow slot. Each icon sits snug against its value (a thin space), with a
    /// wider gap between groups. Humidity is **dropped** from this iPhone Lock Screen row: three groups
    /// (high · low · rain) leave enough room to render the line a step larger and stay legible — humidity
    /// still has its own dedicated complication. The iPad `wide` layout keeps humidity in its grid.
    private var metricsLine: Text {
        let gap = Text("   ")
        let thin = "\u{2009}"
        var line = Text(Image(systemName: "arrow.up")) + Text(thin + AccessoryFormat.temp(snapshot.tempMax))
            + gap + Text(Image(systemName: "arrow.down")) + Text(thin + AccessoryFormat.temp(snapshot.tempMin))
        if let p = snapshot.currentPrecipProb {
            line = line + gap + Text(Image(systemName: "umbrella.fill")) + Text(thin + "\(p)%")
        }
        return line
    }

    /// iPhone / Watch: a two-row compact stack sized for the short Lock Screen rectangular slot.
    private var compact: some View {
        // The Lock Screen renders accessory widgets in a desaturated "vibrant" mode, so hierarchy comes
        // from weight and grayscale, not tint (Apple HIG). The rectangular slot is short — it fits only
        // about two tall lines, so the earlier three-row stack (hero / sky word / figures) clipped its
        // bottom metric row off on-device. Two rows now: the hero on top, the day's figures below. The
        // sky WORD is dropped — the glyph already carries the condition, exactly as the iPad `wide`
        // variant does — and an active aviso keeps its signal as a triangle pinned beside the temperature.
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: condition glyph + temperature, prominent and alone on the line so nothing squeezes
            // the number. Sized one step down from .title2 so the card breathes, with a wider glyph↔temp
            // gap; an aviso triangle rides the trailing edge when a warning is active.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now), slot: 20)
                Text(AccessoryFormat.temp(snapshot.heroTemp))
                    .font(.title3).fontWeight(.semibold).fontDesign(.rounded)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if snapshot.alert != nil {
                    Spacer(minLength: 3)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            // Row 2: today's high and low, then the rain chance and humidity — one Text so the whole line
            // scales to fit (see `metricsLine`). Wind is dropped from this ~160pt-wide slot and keeps its
            // own dedicated complication instead.
            metricsLine
                // A step up from .caption2 now that humidity is gone and the row has room — the earlier
                // size read as cramped/hard on the Lock Screen. Still scales down if a slot is extra tight.
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// iPad: a richer read that fills the generous rectangular slot as a near-square — the condition,
    /// temperature and place name across the top, then the day's figures in a 2-up grid (range, then rain
    /// and humidity, then the next sun event). A level-tinted aviso triangle is pinned to the top-trailing
    /// corner when a warning is active, so it reads as a mark without stealing a metric row.
    private var wide: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now), slot: 28)
                    Text(AccessoryFormat.temp(snapshot.heroTemp))
                        .font(.system(.title, design: .rounded)).fontWeight(.semibold)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(snapshot.localidad)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.bottom, 2)
                // The day's figures, two to a row so they read as a compact grid. Each renders only when
                // its datum is known; a missing one just leaves its place empty. The condition word is
                // dropped here (the glyph already carries it) — the near-square 2×2 slot has no room for
                // it *and* all three figure rows without the last clipping off the bottom.
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 12) {
                        Label(AccessoryFormat.temp(snapshot.tempMax), systemImage: "arrow.up")
                        Label(AccessoryFormat.temp(snapshot.tempMin), systemImage: "arrow.down")
                    }
                    if snapshot.currentPrecipProb != nil || snapshot.currentHumidity != nil {
                        HStack(spacing: 12) {
                            if let p = snapshot.currentPrecipProb {
                                Label("\(p)%", systemImage: "umbrella.fill")
                            }
                            if let h = snapshot.currentHumidity {
                                Label("\(h)%", systemImage: "humidity.fill")
                            }
                        }
                    }
                    if let sun = AccessoryFormat.sun(snapshot, now: now) {
                        Label(sun.text, systemImage: sun.icon)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .labelStyle(TightLabelStyle())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let alert = snapshot.alert {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.alert(alert.level))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// A label whose icon sits snug against its title — for the compact high/low row.
private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 1) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Inline

/// `.accessoryInline`: a single line beside the clock — condition glyph, current temp, condition.
/// The system tints inline complications, so this stays plain.
public struct AuraAccessoryInline: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        Label {
            Text(AccessoryFormat.inline(snapshot))
        } icon: {
            Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
        }
    }
}

// MARK: - Corner (watchOS)

/// `.accessoryCorner` (Apple Watch): the condition icon over the hero temperature in the corner, with
/// the day's range as a temperature-gradient gauge curving along the bezel (Carrot-style) — hi/lo,
/// each in its own temperature colour, at the ends. The complication extension wraps `cornerGauge` in
/// `.widgetLabel`; when the range is unknown it falls back to `cornerLabel` (plain text).
public struct AuraAccessoryCorner: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        // Condition glyph + temperature. The complication applies `.widgetCurvesContent()` so this
        // whole row curves along the corner (watchOS 10+) — the only way the corner's main content
        // arcs like Carrot's; before that modifier it was stuck horizontal and small. The day's range
        // arcs along the outer bezel via `cornerGauge`.
        HStack(spacing: 2) {
            ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now), slot: 20)
            Text(AccessoryFormat.temp(snapshot.heroTemp))
                .fontWeight(.bold).fontDesign(.rounded)
                .lineLimit(1).minimumScaleFactor(0.6)  // scale, never clip to "…", if room is tight
        }
        .font(.title3)
        .foregroundStyle(.white)
    }

    /// Whether today's low/high are known and ordered, so the bezel gauge can be drawn.
    public var hasRange: Bool {
        guard let lo = snapshot.tempMin, let hi = snapshot.tempMax else { return false }
        return lo < hi
    }

    /// The curved bezel gauge: today's range, hero clamped inside it, temperature-gradient tinted, with
    /// the low and high as the end labels — each tinted to its own temperature. Only valid when `hasRange`.
    @ViewBuilder public var cornerGauge: some View {
        if let lo = snapshot.tempMin, let hi = snapshot.tempMax, lo < hi {
            let value = Double(min(max(snapshot.heroTemp ?? lo, lo), hi))
            Gauge(value: value, in: Double(lo)...Double(hi)) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("\(lo)°").foregroundStyle(Palette.temperature(lo))
            } maximumValueLabel: {
                Text("\(hi)°").foregroundStyle(Palette.temperature(hi))
            }
            .tint(Palette.temperatureGradient(min: lo, max: hi))
        }
    }

    /// Fallback curved label when the range is unknown — the hero temperature.
    public var cornerLabel: String { AccessoryFormat.temp(snapshot.heroTemp) }
}

// MARK: - Empty state

/// Shown before the app has cached anything.
public struct AuraAccessoryEmpty: View {
    public init() {}

    public var body: some View {
        Label("Abre Aura", systemImage: "cloud.sun")
    }
}

// MARK: - Formatting

private enum AccessoryFormat {
    static func temp(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—°" }

    static func range(_ s: WeatherSnapshot) -> String {
        "\(temp(s.tempMax)) · \(temp(s.tempMin))"
    }

    /// "12 km/h SO" — current wind speed with the direction it blows from, direction omitted if unknown.
    static func wind(_ s: WeatherSnapshot) -> String {
        let speed = s.windSpeed.map { "\($0) km/h" } ?? "—"
        if let dir = s.windDirection { return "\(speed) \(dir.abbreviation)" }
        return speed
    }

    /// "29° Despejado" — temp plus condition when known, temp alone otherwise.
    static func inline(_ s: WeatherSnapshot) -> String {
        let t = temp(s.heroTemp)
        if let text = s.currentSkyText { return "\(t) \(text)" }
        return t
    }

    /// The next sun event — its time and a rise/set glyph — for the wide rectangular layout, or nil
    /// when the sun times are unknown.
    static func sun(_ s: WeatherSnapshot, now: Date) -> (text: String, icon: String)? {
        switch s.nextSunEvent(now: now) {
        case .sunrise(let d): return (hhmm(d), "sunrise.fill")
        case .sunset(let d):  return (hhmm(d), "sunset.fill")
        case nil:             return nil
        }
    }

    static func hhmm(_ date: Date) -> String {
        return AuraTime.hhmm(date)
    }
}
