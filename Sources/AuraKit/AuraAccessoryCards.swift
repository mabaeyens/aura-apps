import SwiftUI

// Lock Screen (and, later, Apple Watch) accessory cards. Like the home-screen cards these live in
// AuraKit so every surface renders identical code, and they stay pure SwiftUI — the widget applies
// the accessory container background. The Lock Screen renders these in a monochrome/vibrant mode,
// so they rely on plain symbols and legible text rather than colour.

// MARK: - Circular

/// `.accessoryCircular`: today's range as a ring with the current temperature in the middle, so a
/// glance places "now" between the day's low and high. Falls back to icon + temp when the range is
/// unknown.
public struct AuraAccessoryCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let value = gaugeValue, let lo = snapshot.tempMin, let hi = snapshot.tempMax, lo < hi {
            Gauge(value: value, in: Double(lo)...Double(hi)) {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
            } currentValueLabel: {
                Text(AccessoryFormat.temp(current))
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            VStack(spacing: 1) {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
                    .font(.title3)
                Text(AccessoryFormat.temp(current))
                    .font(.headline)
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

/// `.accessoryRectangular`: location + condition, the current temperature, and today's range.
public struct AuraAccessoryRectangular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(snapshot.localidad).fontWeight(.semibold)
            } icon: {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
            }
            .lineLimit(1)

            HStack(spacing: 4) {
                Text(AccessoryFormat.temp(snapshot.heroTemp))
                    .font(.title3).fontWeight(.semibold)
                if let text = snapshot.currentSkyText {
                    Text(text).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Text(AccessoryFormat.range(snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Inline

/// `.accessoryInline`: a single line beside the clock — condition glyph, current temp, condition.
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

/// `.accessoryCorner` (Apple Watch): the current temperature tucked in a screen corner. The
/// complication extension pairs this with a curved `.widgetLabel` (see `cornerLabel`).
public struct AuraAccessoryCorner: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        Text(AccessoryFormat.temp(snapshot.heroTemp))
            .font(.title3).fontWeight(.semibold)
    }

    /// Text for the curved label the extension wraps this in — the condition, else today's range.
    public var cornerLabel: String {
        snapshot.currentSkyText ?? AccessoryFormat.range(snapshot)
    }
}

// MARK: - Empty state

/// Shown on the Lock Screen before the app has cached anything.
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

    /// "29° Despejado" — temp plus condition when known, temp alone otherwise.
    static func inline(_ s: WeatherSnapshot) -> String {
        let t = temp(s.heroTemp)
        if let text = s.currentSkyText { return "\(t) \(text)" }
        return t
    }
}
