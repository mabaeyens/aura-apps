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
        // The Lock Screen renders accessory widgets in a desaturated "vibrant" mode, so colour is
        // largely dropped: hierarchy comes from weight and grayscale, not tint (Apple HIG). Semantic
        // font styles — not fixed point sizes — so the text scales with Dynamic Type and never
        // overflows the way a hardcoded 30pt did once the icon was added.
        VStack(alignment: .leading, spacing: 1) {
            // Line 1: condition glyph + the hero temperature. Alone on the line, so the temperature
            // can be large and never has to fight the sky word for width. Sized a touch down from
            // .title so the two text rows below have room and the wind stops truncating.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now))
                    .font(.headline)
                Text(AccessoryFormat.temp(snapshot.heroTemp))
                    .font(.title2).fontWeight(.semibold).fontDesign(.rounded)
            }
            // Line 2: the sky word, with current wind (speed + direction) filling the space on the
            // right. Same type size as the location/high-low line below it (both .caption2), so the
            // card reads as two even rows and "14 km/h SO" fits without clipping to "14 k…".
            HStack(spacing: 4) {
                if let text = snapshot.currentSkyText {
                    Text(text).lineLimit(1).minimumScaleFactor(0.7)
                }
                if snapshot.windSpeed != nil {
                    Spacer(minLength: 4)
                    Label(AccessoryFormat.wind(snapshot), systemImage: "wind")
                        .labelStyle(TightLabelStyle())
                        .lineLimit(1).minimumScaleFactor(0.9)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            // Line 3: which location this is, and today's high/low with up/down arrows.
            HStack(spacing: 6) {
                Text(snapshot.localidad).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Label(AccessoryFormat.temp(snapshot.tempMax), systemImage: "arrow.up")
                Label(AccessoryFormat.temp(snapshot.tempMin), systemImage: "arrow.down")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .labelStyle(TightLabelStyle())
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
            ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now))
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
}
