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

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let value = gaugeValue, let lo = snapshot.tempMin, let hi = snapshot.tempMax, lo < hi {
            Gauge(value: value, in: Double(lo)...Double(hi)) {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
            } currentValueLabel: {
                Text(AccessoryFormat.temp(current))
                    .foregroundStyle(Palette.temperature(current))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Palette.temperature(current))
        } else {
            VStack(spacing: 1) {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                Text(AccessoryFormat.temp(current))
                    .font(.headline)
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

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(snapshot.localidad).fontWeight(.semibold)
            } icon: {
                Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
                    .symbolRenderingMode(.multicolor)
            }
            .lineLimit(1)

            HStack(spacing: 4) {
                Text(AccessoryFormat.temp(snapshot.heroTemp))
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(Palette.temperature(snapshot.heroTemp))
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

/// `.accessoryCorner` (Apple Watch): the condition icon tucked in a screen corner, with the hero
/// temperature as the curved bezel label (`cornerLabel`). The complication extension wires the label.
public struct AuraAccessoryCorner: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
            .symbolRenderingMode(.multicolor)
            .font(.title2)
    }

    /// The curved label the extension wraps this in — the hero temperature.
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

    /// "29° Despejado" — temp plus condition when known, temp alone otherwise.
    static func inline(_ s: WeatherSnapshot) -> String {
        let t = temp(s.heroTemp)
        if let text = s.currentSkyText { return "\(t) \(text)" }
        return t
    }
}
