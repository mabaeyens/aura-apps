import SwiftUI

// Two more accessory datums the snapshot already carries but had no complication of their own:
//   • Máx/Mín del día — today's high and low, each in its own temperature colour.
//   • Calidad del aire — the MITECO ICA category (1…6) as a ring/gauge in the official ICA colour.
// Both ship in `.accessoryCircular` and `.accessoryCorner`, sharing AuraKit so the phone Lock Screen and
// the Apple Watch face render identical code. Temperature is unbounded, so Máx/Mín uses plain corner text
// (no bezel gauge); ICA is a bounded 1…6 scale, so it takes the curved bezel gauge like UV and humidity.

// MARK: - Máx / Mín del día

/// `.accessoryCircular`: today's high over today's low, each tinted to its own temperature. No ring — the
/// datum is the two endpoints, not a value moving along a scale — so a clean two-line read carries it, and
/// the arrows keep it legible when the Lock Screen desaturates the colour.
public struct AuraMinMaxCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let hi = snapshot.tempMax, let lo = snapshot.tempMin {
            VStack(spacing: 1) {
                Label("\(hi)°", systemImage: "arrow.up")
                    .foregroundStyle(Palette.temperature(hi))
                Label("\(lo)°", systemImage: "arrow.down")
                    .foregroundStyle(Palette.temperature(lo))
            }
            .font(.title3).fontWeight(.semibold).fontDesign(.rounded)
            .labelStyle(TightAccessoryLabelStyle())
            .lineLimit(1).minimumScaleFactor(0.6)
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// `.accessoryCorner` (Apple Watch): the day's high as the corner content (temperature-tinted, up arrow),
/// with the low on the curved bezel. Temperature is unbounded, so this is plain corner text and a glyph —
/// not a gauge (a Máx/Mín range has no single "current value" to plot along it).
public struct AuraMinMaxCorner: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "arrow.up")
            Text(snapshot.tempMax.map { "\($0)°" } ?? "—°")
                .fontWeight(.bold).fontDesign(.rounded)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .font(.title3)
        .foregroundStyle(snapshot.tempMax.map(Palette.temperature) ?? .white)
    }

    /// The low on the curved bezel — the down arrow keeps it distinct from the high in the corner content.
    public var cornerLabel: String { snapshot.tempMin.map { "↓\($0)°" } ?? "↓—°" }
}

// MARK: - Calidad del aire (ICA)

/// `.accessoryCircular`: the MITECO ICA category as a ring fill on the 1…6 scale, with the `aqi.medium`
/// glyph and the category number in the centre, tinted to the official ICA colour. The ring height carries
/// the level on the desaturated Lock Screen; the ICA colour comes through on full-colour watch faces.
/// Empty when the snapshot has no nearby station.
public struct AuraAirQualityCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let air = snapshot.airQuality {
            let color = Palette.airQuality(air.category)
            Gauge(value: Double(air.category), in: 1...6) {
                Image(systemName: "aqi.medium").foregroundStyle(color)
            } currentValueLabel: {
                Text("\(air.category)")
                    .fontWeight(.semibold).fontDesign(.rounded)
                    .foregroundStyle(color)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(AirQualityScale.gradient)
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// `.accessoryCorner` (Apple Watch): the ICA glyph + category number in the corner, with a curved gauge on
/// the 1…6 scale along the outer bezel, tinted to the official ICA ramp. ICA is a bounded scale, so it
/// takes the bezel gauge (like UV and humidity). Falls back to a plain bezel label when no station is near.
public struct AuraAirQualityCorner: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        let category = snapshot.airQuality?.category
        HStack(spacing: 2) {
            Image(systemName: "aqi.medium")
            Text(category.map { "\($0)" } ?? "—")
                .fontWeight(.bold).fontDesign(.rounded)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.title3)
        .foregroundStyle(category.map(Palette.airQuality) ?? .white)
    }

    /// Whether a category is known, so the bezel gauge can be drawn (else fall back to `cornerLabel`).
    public var hasValue: Bool { snapshot.airQuality != nil }

    /// The curved bezel gauge: the ICA category on the 1…6 scale, the fill grading along the official ICA
    /// colours, with 1 and 6 at the ends. No `gaugeStyle` — the `.widgetLabel` context arcs it.
    @ViewBuilder public var cornerGauge: some View {
        if let air = snapshot.airQuality {
            BezelGauge(value: Double(air.category), range: 1...6, tint: AirQualityScale.gradient) {
                Text("1")
            } maxLabel: {
                Text("6")
            }
        }
    }

    /// Fallback bezel label when the gauge is skipped — the category with its ICA prefix.
    public var cornerLabel: String { snapshot.airQuality.map { "ICA \($0.category)" } ?? "ICA —" }
}

/// `.accessoryRectangular`: the ICA category number (large, ICA-tinted) beside the category name and the
/// dominant pollutant/station line — the same two-line "headline + detail" shape as the other rectangular
/// cells. Follows `AuraAccessoryRectangular`'s `GeometryReader` width branch so the iPad's roomier slot
/// gets a step up in size rather than the iPhone's cramped one stretched thin. Empty when no station near.
public struct AuraAirQualityRectangular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let air = snapshot.airQuality {
            GeometryReader { geo in
                cell(air, wide: geo.size.width > 220)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }

    private func cell(_ air: AirQuality, wide: Bool) -> some View {
        let color = Palette.airQuality(air.category)
        return HStack(alignment: .center, spacing: wide ? 12 : 8) {
            Text("\(air.category)")
                .font(wide ? .system(.largeTitle, design: .rounded) : .system(.title, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(air.categoryName)
                    .font(wide ? .subheadline : .caption).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.7)
                detailLine(air)
                    .font(wide ? .footnote : .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// "O₃ · Retiro" — the dominant pollutant plus the reporting station, either half dropped if unknown.
    private func detailLine(_ air: AirQuality) -> Text {
        if let pollutant = air.pollutantLabel { return Text("\(pollutant) · \(air.station)") }
        return Text(air.station)
    }
}

/// `.accessoryInline`: the ICA glyph plus a short air-quality read — the category name, matching
/// `AuraAvisoInline`'s inline style. Empty when no station is near.
public struct AuraAirQualityInline: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        if let air = snapshot.airQuality {
            // "ICA 2" rather than the full category name — some ICA names ("Razonablemente buena") run
            // long enough to truncate on the inline slot's single line, same reasoning as the corner's
            // `cornerLabel` fallback, which uses the same compact form.
            Label {
                Text("ICA \(air.category)")
            } icon: {
                Image(systemName: "aqi.medium")
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// The official ICA ramp (categories 1…6) as a gradient, shared by the circular ring and the corner bezel
/// gauge so they can't disagree.
enum AirQualityScale {
    static let gradient = Gradient(colors: (1...6).map { Palette.airQuality($0) })
}

/// A label whose icon sits snug against its title — for the two-line Máx/Mín circular read.
private struct TightAccessoryLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 1) {
            configuration.icon
            configuration.title
        }
    }
}
