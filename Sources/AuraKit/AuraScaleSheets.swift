import SwiftUI

/// The reference scales behind the wind, air-quality and UV cards. Each card on the phone is tappable
/// (`.auraDetail`) and opens the matching sheet: the full 0–12 Beaufort table, the six-level ICA scale,
/// or the WHO UV bands — with the current reading highlighted, so the number on the card gains a scale to
/// read it against. Watch-free: the tap and sheet are attached only at `.phone` size.

// MARK: - Tap-to-open affordance

extension View {
    /// On the phone, makes a card tappable to present `detail` and stamps a small "there's more" glyph in
    /// its top-trailing corner. A no-op on the Watch (no room for a sheet), so the same card code serves
    /// both. Attach it to the frosted card *before* `auraSectionTitle`, so the glyph sits on the card.
    @ViewBuilder
    func auraDetail<Detail: View>(_ size: AuraSize,
                                  @ViewBuilder detail: @escaping () -> Detail) -> some View {
        if size == .phone {
            modifier(AuraDetailModifier(detail: detail))
        } else {
            self
        }
    }
}

private struct AuraDetailModifier<Detail: View>: ViewModifier {
    @ViewBuilder let detail: () -> Detail
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            // The affordance: a small tap glyph, no text, in the corner the cards leave empty. Non-hit-
            // testing so the tap lands on the card as a whole, not just the glyph.
            .overlay(alignment: .topTrailing) {
                Image(systemName: "hand.tap.fill")
                    .auraFont(15, relativeTo: .body)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(12)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { showing = true }
            .sheet(isPresented: $showing) {
                detail()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - Shared sheet scaffold

/// A scale sheet: a title, a one-line "where you are now" subtitle, the coloured rows, and a small
/// footnote explaining the scale and its source. Dark, over a night-sky gradient, to match the app.
private struct AuraScaleSheet<Rows: View>: View {
    let title: String
    let subtitle: String
    let footnote: String
    /// The scale as a left→low, right→high colour ramp, and where "now" sits on it (0…1, nil if unknown)
    /// with a short label for the marker. This is the signature visual — the same continuous-ramp idea as
    /// the temperature strip and the wind vane — so the rows below read as its legend, not as the scale.
    let barColors: [Color]
    let markerFraction: Double?
    let markerLabel: String
    /// An optional live cue shown under the subtitle: an SF Symbol and a short sentence, e.g. the cloud note
    /// on the UV sheet when the sky is overcast. Nil (the default) renders nothing, so other sheets are
    /// unaffected.
    var note: (icon: String, text: String)? = nil
    /// Render-only escape hatch: the offline `aura-render` tool passes `false` so the rows lay out without
    /// a `ScrollView` (which `ImageRenderer` can't render). The app always uses the default.
    var scrolls: Bool = true
    @ViewBuilder var rows: Rows
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.19),
                                    Color(red: 0.03, green: 0.04, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content
                .conditionalScroll(scrolls)
        }
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .auraFont(27, relativeTo: .title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .auraFont(25, relativeTo: .title2, weight: .bold, design: .rounded)
                    .foregroundStyle(.white)
                    .padding(.trailing, 34)   // clear of the close button
                Text(subtitle)
                    .auraFont(15, relativeTo: .body)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Label {
                        Text(note.text)
                    } icon: {
                        Image(systemName: note.icon)
                    }
                    .auraFont(14, relativeTo: .callout, weight: .medium)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                }
            }

            AuraScaleBar(colors: barColors, markerFraction: markerFraction, label: markerLabel)
                .padding(.vertical, 8)

            rows

            Text(footnote)
                .auraFont(13, relativeTo: .callout)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}

private extension View {
    /// Wrap in a vertical `ScrollView` when `scrolls`, else lay out plainly (for `ImageRenderer`).
    @ViewBuilder func conditionalScroll(_ scrolls: Bool) -> some View {
        if scrolls { ScrollView { self } } else { self }
    }
}

/// The scale itself, as a continuous colour ramp — low on the left, high on the right — with a marker
/// riding it at the current reading. Aura's own idiom: the temperature strip and the wind vane read the
/// same way, a value's meaning taken from where it falls along a colour, not from a table. The marker
/// carries a short value label above a downward pointer; it hides when there's no current reading.
private struct AuraScaleBar: View {
    let colors: [Color]
    let markerFraction: Double?
    let label: String

    private let barHeight: CGFloat = 16
    private let markerWidth: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let f = markerFraction.map { min(max($0, 0), 1) }
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: barHeight)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                    .offset(y: 40 - barHeight)

                if let f {
                    marker
                        .frame(width: markerWidth)
                        .offset(x: min(max(w * f - markerWidth / 2, 0), w - markerWidth))
                }
            }
        }
        .frame(height: 44)
    }

    /// A value bubble over a downward triangle, its tip resting on the ramp at the current fraction.
    private var marker: some View {
        VStack(spacing: 0) {
            Text(label)
                .auraFont(13, relativeTo: .callout, weight: .heavy, design: .rounded)
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            DownTriangle()
                .fill(.white)
                .frame(width: 12, height: 8)
        }
    }
}

/// A small triangle pointing down, for the scale-bar marker.
private struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// One level of a scale: a colour swatch carrying its short label, the level name (with a "current"
/// pill when it's the reading in effect), and a line of what it means. The current row is ringed and
/// lifted. `currentLabel` is the pill text — "Ahora" for live readings (wind, air), but the UV sheet
/// passes "Máx. hoy" because AEMET's UV is a daily-max forecast, not a live hourly value.
private struct AuraScaleRow: View {
    let color: Color
    let badge: String
    /// An optional SF Symbol shown beside the band name — used by the UV sheet so each row spells out the
    /// glyph the UV complication shows for that band (its legend). Nil for the wind/air-quality sheets.
    var glyph: String? = nil
    let name: String
    let detail: String
    let isCurrent: Bool
    var currentLabel: String = auraString("scale.now")

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(badge)
                .auraFont(15, relativeTo: .body, weight: .heavy, design: .rounded)
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.55)
                .frame(width: 46, height: 46)
                .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: color.opacity(0.5), radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let glyph {
                        Image(systemName: glyph)
                            .auraFont(16, relativeTo: .body, weight: .semibold)
                            .foregroundStyle(.white)
                            .frame(width: 24)
                    }
                    Text(name)
                        .auraFont(17, relativeTo: .body, weight: .semibold)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if isCurrent {
                        Text(currentLabel)
                            .auraFont(12, relativeTo: .caption, weight: .heavy)
                            .foregroundStyle(.black.opacity(0.85))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(.white, in: Capsule())
                    }
                }
                Text(detail)
                    .auraFont(14, relativeTo: .callout)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(isCurrent ? 0.10 : 0)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(color.opacity(isCurrent ? 0.9 : 0), lineWidth: 2))
    }
}

/// One pollutant on its own 1…6 ICA ramp: the label, the value (or "No medido en esta estación"), a slim
/// colour ramp with a marker where the value falls, and the band name. Unmeasured pollutants show a flat
/// grey rail with no marker — MITECO's grey-for-unavailable convention, the same as the card's chips.
private struct AirComponentScale: View {
    let token: String
    let component: AirComponent?
    let isDriver: Bool
    let now: Date
    // The value and its unit are a concatenated `Text` (Text + Text), which needs a real `Font` on
    // each half rather than the `.auraFont` view modifier — so their sizes scale via `@ScaledMetric`.
    @ScaledMetric(relativeTo: .body) private var valueSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var unitSize: CGFloat = 12

    var body: some View {
        let measured = component != nil
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AirComponent.label(for: token))
                    .auraFont(17, relativeTo: .body, weight: .bold)
                    .foregroundStyle(.white.opacity(measured ? 1 : 0.4))
                if isDriver, measured {
                    Text(auraString("aqi.dominant"))
                        .auraFont(11, relativeTo: .caption, weight: .heavy)
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white, in: Capsule())
                }
                Spacer(minLength: 0)
                if let c = component {
                    (Text(c.valueText + " ").font(.system(size: valueSize, weight: .bold, design: .rounded))
                     + Text("µg/m³").font(.system(size: unitSize, weight: .medium)))
                        .foregroundStyle(.white)
                } else {
                    Text(auraString("aqi.notMeasuredHere"))
                        .auraFont(13, relativeTo: .callout)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            ramp
            if let c = component {
                HStack(spacing: 6) {
                    Text(AirQuality.categoryName(c.icaCategory))
                        .auraFont(13, relativeTo: .callout, weight: .semibold)
                        .foregroundStyle(Palette.airQuality(c.icaCategory))
                    if let source = source(c) {
                        Text("·").foregroundStyle(.white.opacity(0.3))
                        Text(source)
                            .auraFont(13, relativeTo: .callout)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// "Retiro · a 1,7 km · hace 1 h" — the station this pollutant came from, its distance, and how fresh
    /// the reading is. Different pollutants can show different stations and times; that's the point.
    private func source(_ c: AirComponent) -> String? {
        guard let station = c.station else { return nil }
        var parts = [station]
        if let km = c.distanceKm {
            parts.append(km < 10
                ? auraString("card.station.distance", String(format: "%.1f", km).replacingOccurrences(of: ".", with: ","))
                : auraString("card.station.distance", "\(Int(km.rounded()))"))
        }
        if let when = c.measured { parts.append(AuraNewsCard.relative(from: when, now: now)) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var ramp: some View {
        if let c = component {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: (1...6).map { Palette.airQuality($0) },
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 9)
                    Circle()
                        .fill(Palette.airQuality(c.icaCategory))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.35), radius: 2)
                        .offset(x: min(max(w * c.icaFraction - 8, 0), w - 16))
                }
            }
            .frame(height: 16)
        } else {
            Capsule()
                .fill(Color(white: 0.5).opacity(0.26))
                .frame(height: 9)
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        }
    }
}

// MARK: - Beaufort (wind)

public struct AuraBeaufortSheet: View {
    let snapshot: WeatherSnapshot
    var scrolls: Bool
    public init(snapshot: WeatherSnapshot, scrolls: Bool = true) {
        self.snapshot = snapshot; self.scrolls = scrolls
    }

    public var body: some View {
        let current = Beaufort.force(forKmh: snapshot.windSpeed)
        AuraScaleSheet(
            title: auraString("beaufort.title"),
            subtitle: subtitle,
            footnote: auraString("beaufort.footnote"),
            barColors: Beaufort.scale.map { Palette.wind($0.midKmh) },
            markerFraction: current >= 0 ? Double(current) / 12 : nil,
            markerLabel: "\(snapshot.windSpeed ?? 0) km/h",
            scrolls: scrolls
        ) {
            ForEach(Beaufort.scale, id: \.force) { step in
                AuraScaleRow(color: Palette.wind(step.midKmh),
                             badge: "\(step.force)",
                             name: step.name,
                             detail: "\(step.rangeText) · \(auraString(step.effectKey))",
                             isCurrent: step.force == current)
            }
        }
    }

    private var subtitle: String {
        guard let v = snapshot.windSpeed else { return auraString("beaufort.noWind") }
        let f = Beaufort.force(forKmh: v)
        let name = Beaufort.scale.first { $0.force == f }?.name.lowercased() ?? ""
        let dir = snapshot.windDirection.map { auraString("beaufort.dirSuffix", $0.spanishName.lowercased()) } ?? ""
        return auraString("beaufort.subtitle", v, dir, f, name)
    }
}

/// The 0–12 Beaufort scale in km/h (the unit AEMET reports), with the Spanish names AEMET uses and a
/// short visible effect for each force.
enum Beaufort {
    struct Step {
        let force: Int
        let name: String
        let lo: Int
        let hi: Int?          // nil = open-ended top force
        /// Localization key for the row's short visible effect (the Spanish name stays as `name`).
        let effectKey: String

        /// The band as text: "20–28 km/h", "menos de 1 km/h" for calm, "más de 118 km/h" for the top.
        var rangeText: String {
            if force == 0 { return auraString("beaufort.range.calm") }
            if let hi { return auraString("beaufort.range.between", lo, hi) }
            return auraString("beaufort.range.above", lo)
        }
        /// A representative speed for the row's colour, on `Palette.wind`'s ramp.
        var midKmh: Int { hi.map { (lo + $0) / 2 } ?? (lo + 20) }
    }

    static let scale: [Step] = [
        Step(force: 0,  name: "Calma",              lo: 0,   hi: 0,   effectKey: "beaufort.effect.0"),
        Step(force: 1,  name: "Ventolina",          lo: 1,   hi: 5,   effectKey: "beaufort.effect.1"),
        Step(force: 2,  name: "Flojito",            lo: 6,   hi: 11,  effectKey: "beaufort.effect.2"),
        Step(force: 3,  name: "Flojo",              lo: 12,  hi: 19,  effectKey: "beaufort.effect.3"),
        Step(force: 4,  name: "Bonancible",         lo: 20,  hi: 28,  effectKey: "beaufort.effect.4"),
        Step(force: 5,  name: "Fresquito",          lo: 29,  hi: 38,  effectKey: "beaufort.effect.5"),
        Step(force: 6,  name: "Fresco",             lo: 39,  hi: 49,  effectKey: "beaufort.effect.6"),
        Step(force: 7,  name: "Frescachón",         lo: 50,  hi: 61,  effectKey: "beaufort.effect.7"),
        Step(force: 8,  name: "Temporal",           lo: 62,  hi: 74,  effectKey: "beaufort.effect.8"),
        Step(force: 9,  name: "Temporal fuerte",    lo: 75,  hi: 88,  effectKey: "beaufort.effect.9"),
        Step(force: 10, name: "Temporal duro",      lo: 89,  hi: 102, effectKey: "beaufort.effect.10"),
        Step(force: 11, name: "Temporal muy duro",  lo: 103, hi: 117, effectKey: "beaufort.effect.11"),
        Step(force: 12, name: "Temporal huracanado", lo: 118, hi: nil, effectKey: "beaufort.effect.12"),
    ]

    /// The Beaufort force for a wind speed in km/h, or -1 when there's no reading.
    static func force(forKmh kmh: Int?) -> Int {
        guard let v = kmh else { return -1 }
        for step in scale where v <= (step.hi ?? Int.max) { return step.force }
        return 12
    }
}

// MARK: - ICA (air quality)

public struct AuraAirQualitySheet: View {
    let airQuality: AirQuality
    var now: Date
    var scrolls: Bool
    public init(airQuality: AirQuality, now: Date = Date(), scrolls: Bool = true) {
        self.airQuality = airQuality; self.now = now; self.scrolls = scrolls
    }

    public var body: some View {
        AuraScaleSheet(
            title: auraString("aqi.sheetTitle"),
            subtitle: subtitle,
            footnote: auraString("aqi.footnote"),
            barColors: (1...6).map { Palette.airQuality($0) },
            markerFraction: (Double(airQuality.category) - 0.5) / 6,
            markerLabel: auraString("scale.level", airQuality.category),
            scrolls: scrolls
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(AirICA.levels, id: \.category) { level in
                    AuraScaleRow(color: Palette.airQuality(level.category),
                                 badge: "\(level.category)",
                                 name: level.name,
                                 detail: auraString(level.adviceKey),
                                 isCurrent: level.category == airQuality.category)
                }
                componentSection
            }
        }
    }

    /// The five ICA pollutants, each on its own 1…6 ramp — the ones this station measures with a value and
    /// a marker, the ones it doesn't with a greyed rail and "No medido". A richer read than the card's row
    /// of chips, for when you want to know *why* the index is where it is.
    private var componentSection: some View {
        let measured = Dictionary(airQuality.components.map { ($0.pollutant, $0) },
                                  uniquingKeysWith: { a, _ in a })
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(auraString("aqi.byPollutant"))
                    .auraFont(14, relativeTo: .callout, weight: .semibold)
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.72))
                Text(auraString("aqi.byPollutantNote"))
                    .auraFont(13, relativeTo: .callout)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 10)
            ForEach(AirComponent.order, id: \.self) { token in
                AirComponentScale(token: token,
                                  component: measured[token],
                                  isDriver: token == airQuality.pollutant,
                                  now: now)
            }
        }
    }

    private var subtitle: String {
        let by = airQuality.pollutantLabel.map { auraString("aqi.bySuffix", $0) } ?? ""
        return auraString("aqi.subtitle", airQuality.categoryName.lowercased(), airQuality.category, by, airQuality.station)
    }
}

/// The six ICA levels with their official Spanish names and a general-population recommendation.
enum AirICA {
    struct Level { let category: Int; let name: String; let adviceKey: String }
    static let levels: [Level] = [
        Level(category: 1, name: "Buena",                       adviceKey: "ica.advice.1"),
        Level(category: 2, name: "Razonablemente buena",        adviceKey: "ica.advice.2"),
        Level(category: 3, name: "Regular",                     adviceKey: "ica.advice.3"),
        Level(category: 4, name: "Desfavorable",                adviceKey: "ica.advice.4"),
        Level(category: 5, name: "Muy desfavorable",            adviceKey: "ica.advice.5"),
        Level(category: 6, name: "Extremadamente desfavorable", adviceKey: "ica.advice.6"),
    ]
}

// MARK: - UV index

public struct AuraUVSheet: View {
    let uvIndex: UVIndex
    /// The sky is currently overcast/wet enough to hold the live UV below this clear-sky maximum — shows a
    /// cloud note under the subtitle, the same cue the UV card and complication carry.
    let cloudy: Bool
    var scrolls: Bool
    public init(uvIndex: UVIndex, cloudy: Bool = false, scrolls: Bool = true) {
        self.uvIndex = uvIndex; self.cloudy = cloudy; self.scrolls = scrolls
    }

    public var body: some View {
        AuraScaleSheet(
            title: auraString("uv.sheetTitle"),
            subtitle: auraString("uv.subtitle", uvIndex.value, uvIndex.bandName.lowercased()),
            footnote: auraString("uv.footnote"),
            barColors: UVBands.bands.map { Palette.uvIndex($0.mid) },
            markerFraction: min(Double(uvIndex.value), 11) / 11,
            markerLabel: "UV \(uvIndex.value)",
            note: cloudy ? ("cloud", auraString("uv.cloudyNote")) : nil,
            scrolls: scrolls
        ) {
            ForEach(UVBands.bands, id: \.name) { band in
                AuraScaleRow(color: Palette.uvIndex(band.mid),
                             badge: band.rangeText,
                             glyph: UVIndex(value: band.mid).glyph,
                             name: band.name,
                             detail: auraString(band.adviceKey),
                             isCurrent: band.contains(uvIndex.value),
                             currentLabel: auraString("uv.maxToday"))
            }
        }
    }
}

/// The WHO UV bands, matching `UVIndex.bandName`/`Palette.uvIndex`, with a protection cue per band.
enum UVBands {
    struct Band {
        let name: String
        let lo: Int
        let hi: Int?
        let adviceKey: String

        var mid: Int { hi.map { (lo + $0) / 2 } ?? (lo + 1) }
        var rangeText: String { hi.map { lo == $0 ? "\(lo)" : "\(lo)–\($0)" } ?? "\(lo)+" }
        func contains(_ v: Int) -> Bool { v >= lo && v <= (hi ?? Int.max) }
    }

    static let bands: [Band] = [
        Band(name: "Bajo", lo: 0, hi: 2,
             adviceKey: "uv.advice.0"),
        Band(name: "Moderado", lo: 3, hi: 5,
             adviceKey: "uv.advice.3"),
        Band(name: "Alto", lo: 6, hi: 7,
             adviceKey: "uv.advice.6"),
        Band(name: "Muy alto", lo: 8, hi: 10,
             adviceKey: "uv.advice.8"),
        Band(name: "Extremadamente alto", lo: 11, hi: nil,
             adviceKey: "uv.advice.11"),
    ]
}
