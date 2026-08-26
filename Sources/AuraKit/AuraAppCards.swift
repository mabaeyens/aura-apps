import SwiftUI

/// A brighter blue than `Palette.tempBlue` for precipitation labels, so the rain chance stays legible
/// on the dark frosted cards even over a cloudy, greyed-down sky.
let auraPrecipColor = Color(red: 0.52, green: 0.80, blue: 1.0)

/// The Aura app screen, built once and shared. The iPhone and the Apple Watch compose the **same
/// cards in the same order** over the same `AuraSky`; only `AuraSize` changes the type and padding, so
/// the two apps can't drift apart. Frosted-glass cards float over the sky; the sky shows through.
///
/// Everything here forces a dark colour scheme for its materials, so `.ultraThinMaterial` renders as a
/// dark frosted pane and white text stays legible over a bright noon sky or a deep night alike.

// MARK: - Size class

/// Phone vs. Watch metrics. Same layout, resized.
public enum AuraSize: Sendable {
    case phone, watch

    var stackSpacing: CGFloat { self == .phone ? 16 : 8 }
    var cardPadding: CGFloat  { self == .phone ? 18 : 10 }
    var cardCorner: CGFloat   { self == .phone ? 26 : 15 }
    var heroTemp: CGFloat     { self == .phone ? 78 : 44 }
    var heroIcon: CGFloat     { self == .phone ? 66 : 34 }
    var titleSize: CGFloat    { self == .phone ? 16 : 12 }
    var bodySize: CGFloat     { self == .phone ? 22 : 16 }
    var smallSize: CGFloat    { self == .phone ? 18 : 13 }
    var iconSize: CGFloat     { self == .phone ? 27 : 19 }
    var hourGap: CGFloat      { self == .phone ? 20 : 10 }
    var rowGap: CGFloat       { self == .phone ? 16 : 8 }
}

// MARK: - Frosted card

/// How dark the frosted cards' inner scrim rides, keyed to the sky behind them. Set once by
/// `AuraForecastStack` from the snapshot; every `AuraCard` reads it, so the whole stack agrees. Defaults
/// to the previous fixed values for any card rendered outside the stack.
struct AuraCardScrim: Equatable { var top: Double = 0.06; var bottom: Double = 0.24 }
private struct AuraCardScrimKey: EnvironmentKey { static let defaultValue = AuraCardScrim() }
extension EnvironmentValues {
    var auraCardScrim: AuraCardScrim {
        get { self[AuraCardScrimKey.self] }
        set { self[AuraCardScrimKey.self] = newValue }
    }
}

private struct AuraCard<Content: View>: View {
    let size: AuraSize
    @ViewBuilder var content: Content
    // The scrim adapts to the sky: bright skies get the full lift, skies already dark (night, rain,
    // storm) barely any, so the cards never darken further than the scene needs (see `Palette.cardScrim`).
    @Environment(\.auraCardScrim) private var scrim
    /// When the reader has Reduce Transparency on, the frosted material is swapped for an opaque dark
    /// fill: the white card text then keeps its contrast without depending on the blur reading through.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        content
            .padding(size.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // A lighter frost than a full dark material: more of the sky reads through, so the cards
            // sit on the scene instead of blacking it out. A bottom-weighted dark scrim rides *inside*
            // the frost (clipped to the same rounded shape): the light frost alone let the bright lower
            // sky bleed through and washed out the translucent temperature text — worst on the tall
            // Próximos días card. The gradient lifts contrast where the hero is brightest while barely
            // touching the top, so the frosted look holds and the corners stay clean.
            .background {
                let shape = RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous)
                let scrimOverlay = shape.fill(LinearGradient(
                    colors: [.black.opacity(scrim.top), .black.opacity(scrim.bottom)],
                    startPoint: .top, endPoint: .bottom))
                if reduceTransparency {
                    shape.fill(Color(white: 0.12)).overlay(scrimOverlay)
                } else {
                    shape.fill(.ultraThinMaterial.opacity(0.7)).overlay(scrimOverlay)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
    }
}

private extension View {
    /// A small uppercase section label, like Apple Weather's "HOURLY FORECAST".
    func auraSectionTitle(_ text: String, _ size: AuraSize) -> some View {
        VStack(alignment: .leading, spacing: size == .phone ? 8 : 5) {
            Text(text)
                .auraFont(size.titleSize, relativeTo: .caption, weight: .semibold)
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.72))
            self
        }
    }
}

// MARK: - The composed stack

/// The whole screen's card stack — no background, no scroll. The app wraps it in a `ScrollView` over
/// an `AuraSky`. Identical section order on phone and Watch.
public struct AuraForecastStack: View {
    private let snapshot: WeatherSnapshot
    private let size: AuraSize
    private let now: Date
    /// Render-only escape hatch: the offline `aura-render` tool passes `false` so the hourly strip lays
    /// out without a scroll view (which `ImageRenderer` can't render). The apps always use the default.
    private let hoursScroll: Bool
    /// Optional radar frame, fetched and passed by the app (kept out of the snapshot). Nil on the Watch
    /// and until the image loads, so the radar card simply doesn't appear.
    private let radar: AuraRadarInfo?
    /// Optional Noticias stream, fetched and passed by the app. Empty on the Watch and until it loads,
    /// so the news card simply doesn't appear.
    private let news: [NewsItem]
    /// When > 0, the hero is stretched to fill this height (one screen) so every forecast card falls
    /// **below the fold**: the first screen is just the clean sky, landscape and editorial text, and the
    /// cards are revealed on scroll. The apps pass their scroll viewport height; `aura-render` leaves it 0
    /// so the offline full-stack previews render as one continuous image, unchanged.
    private let heroFillHeight: CGFloat

    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date(),
                hoursScroll: Bool = true, radar: AuraRadarInfo? = nil, news: [NewsItem] = [],
                heroFillHeight: CGFloat = 0) {
        self.snapshot = snapshot
        self.size = size
        self.now = now
        self.hoursScroll = hoursScroll
        self.radar = radar
        self.news = news
        self.heroFillHeight = heroFillHeight
    }

    /// The attribution line: AEMET always, plus each third-party source actually shown, in a natural
    /// Spanish list ("AEMET", "AEMET y MITECO", "AEMET, MITECO y Copernicus", "AEMET y Copernicus").
    /// Copernicus = the CAMS UV via Open-Meteo behind the hourly curve.
    static func credit(hasAir: Bool, hasHourlyUV: Bool) -> String {
        var sources = ["AEMET"]
        if hasAir { sources.append("MITECO") }
        if hasHourlyUV { sources.append("Copernicus") }
        let list: String
        if sources.count == 1 { list = sources[0] }
        else { list = sources.dropLast().joined(separator: ", ") + " y " + sources.last! }
        return "Elaborado con datos de " + list
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: size.stackSpacing) {
            AuraHeroCard(snapshot: snapshot, size: size, now: now)
                // Push the cards below the fold: on a real screen the hero fills the first viewport so the
                // clean sky + landscape read on their own; 0 (aura-render) keeps the hero its natural height.
                .frame(minHeight: heroFillHeight > 0 ? heroFillHeight : nil, alignment: .top)
            if let alert = snapshot.activeAlert(at: now) { AuraAlertCard(alert: alert, size: size) }
            // Re-anchor the strip to the real current hour: a snapshot served from cache must still
            // start at "now", not at the hour it was built.
            let upcoming = snapshot.upcomingHours(now: now)
            if !upcoming.isEmpty {
                // The strip is five fixed columns sized to the viewport, so its type can only grow so
                // far before it collides across columns — cap it and let it scale up to that ceiling.
                AuraHourlyCard(hours: upcoming, size: size, scrolls: hoursScroll)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
            // The daily rows reflow their column widths with the text (see AuraDailyCard), but a
            // multi-column row on a phone still can't hold the very largest sizes — cap the top end.
            if !snapshot.days.isEmpty {
                AuraDailyCard(days: snapshot.days, size: size)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
            // One slot, two cards: the Sol arc while the sun is up, the Luna arc once it's dark.
            if snapshot.isNight(at: now) {
                AuraMoonArcCard(snapshot: snapshot, size: size, now: now)
            } else {
                AuraSunArcCard(snapshot: snapshot, size: size, now: now)
            }
            AuraWindCard(snapshot: snapshot, size: size)
            // Which station the observed reading comes from, and whether it reports every surface metric.
            // Phone only — the Watch keeps its stack to the essentials.
            if size == .phone, snapshot.observedStation != nil {
                AuraStationCard(snapshot: snapshot, size: size)
            }
            if let airQuality = snapshot.airQuality {
                AuraAirQualityCard(airQuality: airQuality, size: size)
            }
            if let uvIndex = snapshot.uvIndex {
                AuraUVCard(uvIndex: uvIndex, hourly: snapshot.uvHourly ?? [], now: now, size: size,
                           cloudy: UVNow.cloudy(snapshot))
            }
            if let radar { AuraRadarCard(radar: radar, size: size, now: now) }
            if let bulletin = snapshot.bulletin, !bulletin.isEmpty {
                AuraBulletinCard(phenomenon: snapshot.bulletinPhenomenon, text: bulletin, size: size)
            }
            if !news.isEmpty { AuraNewsCard(items: news, size: size, now: now) }
            // Every third-party source present is credited alongside AEMET (each is CC-BY, which requires
            // attribution): MITECO when the air-quality card shows, Copernicus (CAMS, via Open-Meteo) when
            // the hourly UV curve does.
            Text(Self.credit(hasAir: snapshot.airQuality != nil,
                             hasHourlyUV: !(snapshot.uvHourly ?? []).isEmpty))
                .auraFont(size == .phone ? 14 : 11, relativeTo: .callout, weight: .medium)
                .foregroundStyle(.white.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, size == .phone ? 4 : 2)
        }
        .environment(\.colorScheme, .dark)   // dark frosted materials + light text over the sky
        // Tune every card's scrim to the sky behind it: a bright clear day gets the full darkening so the
        // temperature colours read; a night, rainy or stormy sky is already dark, so it gets next to none.
        .environment(\.auraCardScrim, Self.cardScrim(for: snapshot, now: now))
    }

    /// The scrim for the current sky. Uses the true day/night for the hour (not just the code's `n`
    /// suffix, which a cache-built snapshot can lack) so a nightfall with no current-sky code still reads
    /// as night and skips the extra darkening.
    static func cardScrim(for snapshot: WeatherSnapshot, now: Date) -> AuraCardScrim {
        if snapshot.isNight(at: now) { return AuraCardScrim(top: 0.0, bottom: 0.08) }
        let s = Palette.cardScrim(forCode: snapshot.currentSky)
        return AuraCardScrim(top: s.top, bottom: s.bottom)
    }
}

// MARK: - Hero

public struct AuraHeroCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    let now: Date

    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date()) {
        self.snapshot = snapshot; self.size = size; self.now = now
    }

    /// The Spanish time-of-day word shown after the city ("MADRID · Atardecer"). Derived from the same
    /// sun-path bucket the hero background selector uses, so the label tracks true sunrise/sunset.
    private var momentLabel: String {
        switch HeroBackground.Time(now: now, sunrise: snapshot.sunrise, sunset: snapshot.sunset) {
        case .dawn:      return "Amanecer"
        case .morning:   return "Mañana"
        case .noon:      return "Mediodía"
        case .afternoon: return "Tarde"
        case .dusk:      return "Atardecer"
        case .night:     return "Noche"
        }
    }

    public var body: some View {
        // Dissolved hero: no frosted card. The sky — and the sun/moon disc `AuraSky` draws at the true
        // position — carries the top of the screen; over it float only the editorial temperature and two
        // lines of prose (a human headline, then Máx/Mín · viento · humedad · lluvia folded into a
        // sentence by `ForecastPhrase`). Text aligns with the cards below via the same horizontal inset.
        VStack(alignment: .leading, spacing: size == .phone ? 6 : 3) {
            Text("\(snapshot.localidad.uppercased()) · \(momentLabel)")
                .auraFont(size.bodySize, relativeTo: .title3, weight: .semibold)
                .tracking(0.5)
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)

            Text(snapshot.heroTemp.map { "\($0)°" } ?? "—")
                .auraFont(size.heroTemp, relativeTo: .largeTitle, weight: .bold, design: .rounded)
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)

            Text(ForecastPhrase.headline(for: snapshot, now: now))
                .auraFont(size.bodySize, relativeTo: .title3, weight: .semibold)
                .foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(ForecastPhrase.dataline(for: snapshot, now: now))
                .auraFont(size.bodySize - (size == .phone ? 4 : 3), relativeTo: .title3, weight: .regular)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // An active aviso reads as its sign plus a one-word summary ("Calor", "Tormentas"), right
            // under the dataline, tinted with the warning level's colour. The full text lives in the
            // tappable aviso card below the fold; here it is a glance.
            if let alert = snapshot.activeAlert(at: now) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(alert.shortLabel)
                }
                .auraFont(size.bodySize, relativeTo: .title3, weight: .semibold)
                .foregroundStyle(Palette.alert(alert.level))
                // A dark capsule behind the level-tinted label so the amarillo levels (a yellow that
                // vanishes over a pale dawn or hazy sky — the "Tormentas" case) stay legible on any sky,
                // while the deeper naranja/rojo still read as their own colour. Kept small so the hero
                // stays dissolved rather than regrowing a card.
                .padding(.horizontal, size == .phone ? 12 : 8)
                .padding(.vertical, size == .phone ? 6 : 4)
                .background(.black.opacity(0.30), in: Capsule())
                .padding(.top, size == .phone ? 4 : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.cardPadding)
        .padding(.top, size == .phone ? 6 : 3)
        // A soft dark halo behind the glyphs keeps white text legible over a bright noon sky, without
        // reintroducing a panel. Tunable; the sky's own scrim does the rest.
        .shadow(color: .black.opacity(0.35), radius: size == .phone ? 9 : 6, y: 1)
        // Read the four lines (place · moment, temperature, headline, dataline) as one flowing
        // announcement rather than four separate VoiceOver stops.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hourly

public struct AuraHourlyCard: View {
    let hours: [HourSlot]
    let size: AuraSize
    /// Horizontal scrolling. On device the strip shows five hours and scrolls to the rest of the day.
    /// Off only for the offline `aura-render` previews — `ImageRenderer` can't lay out a horizontal
    /// scroll view, so those render the first five distributed edge to edge instead.
    let scrolls: Bool
    public init(hours: [HourSlot], size: AuraSize, scrolls: Bool = true) {
        self.hours = hours; self.size = size; self.scrolls = scrolls
    }

    /// True when at least one hour carries a rain chance — otherwise the precip row is empty and dropped.
    private var showPrecip: Bool { hours.contains { ($0.precipProb ?? 0) > 0 } }

    /// The width of one of the five visible columns, measured from the strip (see `body`). Zero until the
    /// first layout pass, when the grid falls back to sizing its columns evenly on its own.
    @State private var columnWidth: CGFloat = 0

    public var body: some View {
        AuraCard(size: size) {
            if scrolls {
                // Five columns fit the card width; the strip scrolls horizontally to the rest of the day.
                // The grid sizes to its own rows — no fixed height — so a strip that's dry for the next
                // few hours (an empty precip row on the visible columns) doesn't reserve a band of empty
                // space at the card's bottom. Width is measured in the background so the reader imposes
                // no height of its own.
                ScrollView(.horizontal, showsIndicators: false) {
                    grid(columnWidth: columnWidth > 0 ? columnWidth : nil)
                }
                .frame(maxWidth: .infinity)
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { columnWidth = geo.size.width / 5 }
                        .onChange(of: geo.size.width) { newWidth in columnWidth = newWidth / 5 }
                })
            } else {
                grid(columnWidth: nil, cap: 5)   // offline preview: the first five, spread to fill
            }
        }
        .auraSectionTitle("Próximas horas".uppercased(), size)
        // The strip is a row-major grid, so VoiceOver would otherwise read a loose run of bare numbers.
        // Collapse it into one element that speaks each hour with its temperature and rain chance.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Próximas horas")
        .accessibilityValue(hoursA11yValue)
    }

    /// "18h, 22 grados, 30% de lluvia; 19h, 23 grados; …" — the strip read as one spoken summary.
    private var hoursA11yValue: String {
        hours.map { h in
            var s = AuraTime.hourLabel(hour: h.hour)
            if let t = h.temp { s += ", \(t) grados" }
            if let p = h.precipProb, p > 0 { s += ", \(p)% de lluvia" }
            return s
        }.joined(separator: "; ")
    }

    /// The aligned grid: hour, icon, degree and precip each in its own horizontal band, so the rows line
    /// up across every column regardless of how tall a given weather glyph is. A fixed `columnWidth`
    /// makes five fit the viewport (the scrolling case); `nil` lets `cap` columns share the width evenly.
    @ViewBuilder
    private func grid(columnWidth: CGFloat?, cap: Int? = nil) -> some View {
        let items = cap.map { Array(hours.prefix($0)) } ?? hours
        Grid(horizontalSpacing: 0, verticalSpacing: size == .phone ? 12 : 6) {
            GridRow {
                ForEach(items) { h in
                    Text(AuraTime.hourLabel(hour: h.hour))
                        .auraFont(size.smallSize, relativeTo: .callout, weight: .medium)
                        .foregroundStyle(.white.opacity(0.75))
                        .colWidth(columnWidth)
                }
            }
            GridRow {
                ForEach(items) { h in
                    Image(systemName: WeatherIcon.symbol(forSky: h.sky))
                        .symbolRenderingMode(.multicolor)
                        .auraFont(size.iconSize + 6, relativeTo: .title2)
                        .frame(minHeight: size.iconSize + 8)
                        .colWidth(columnWidth)
                }
            }
            GridRow {
                ForEach(items) { h in
                    Text(h.temp.map { "\($0)°" } ?? "—")
                        .auraFont(size.bodySize - 2, relativeTo: .title3, weight: .bold)
                        .foregroundStyle(Palette.temperature(h.temp))
                        .colWidth(columnWidth)
                }
            }
            if showPrecip {
                GridRow {
                    ForEach(items) { h in
                        Text(h.precipProb.map { $0 > 0 ? "\($0)%" : "" } ?? "")
                            .auraFont(size.smallSize - 1, relativeTo: .callout, weight: .semibold)
                            .foregroundStyle(auraPrecipColor)
                            .colWidth(columnWidth)
                    }
                }
            }
        }
    }
}

private extension View {
    /// A fixed column width when scrolling (so five fit the viewport), or an even share of the width
    /// when laid out without a scroll view.
    @ViewBuilder func colWidth(_ width: CGFloat?) -> some View {
        if let width { frame(width: width) } else { frame(maxWidth: .infinity) }
    }
}

// MARK: - Daily

public struct AuraDailyCard: View {
    let days: [DaySnapshot]
    let size: AuraSize
    public init(days: [DaySnapshot], size: AuraSize) { self.days = days; self.size = size }

    /// Grows from 1.0 in step with the row's `.title3` text, so the fixed weekday/temperature columns
    /// widen with the type instead of clipping it. One factor drives both phone and Watch column widths.
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1

    /// The week's overall low and high — every row's range bar is drawn on this shared scale, so a warm
    /// day's bar sits visibly to the right of a cold day's, the way Apple Weather charts a week.
    private var weekLo: Int { days.compactMap(\.min).min() ?? 0 }
    private var weekHi: Int { days.compactMap(\.max).max() ?? 1 }

    public var body: some View {
        AuraCard(size: size) {
            VStack(alignment: .leading, spacing: size.rowGap) {
                ForEach(days) { d in
                    HStack(spacing: size == .phone ? 10 : 6) {
                        Text(Self.weekday(d.date))
                            .frame(width: (size == .phone ? 52 : 34) * typeScale, alignment: .leading)
                            .foregroundStyle(.white)
                        VStack(spacing: 1) {
                            Image(systemName: WeatherIcon.symbol(forSky: d.sky))
                                .symbolRenderingMode(.multicolor)
                                .auraFont(size.iconSize, relativeTo: .title2)
                            // Always render the precip line (a blank space when there's no meaningful
                            // chance) so every day's row is exactly the same height, rain or not.
                            Text(d.probPrecip.map { $0 >= 10 ? "\($0)%" : " " } ?? " ")
                                .auraFont(size.smallSize - 2, relativeTo: .callout, weight: .semibold)
                                .foregroundStyle(auraPrecipColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: (size == .phone ? 40 : 27) * typeScale)

                        Text(fmt(d.min)).foregroundStyle(Palette.temperature(d.min))
                            .frame(width: (size == .phone ? 46 : 30) * typeScale, alignment: .trailing)
                        rangeBar(d)
                        Text(fmt(d.max)).fontWeight(.bold).foregroundStyle(Palette.temperature(d.max))
                            .frame(width: (size == .phone ? 46 : 30) * typeScale, alignment: .leading)
                    }
                    .auraFont(size.bodySize - 1, relativeTo: .title3, weight: .medium)
                    .monospacedDigit()
                    // One element per day — otherwise VoiceOver reads the weekday, both temps and the
                    // range bar as disconnected fragments.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Self.dayA11yLabel(d))
                }
            }
        }
        .auraSectionTitle("Próximos días".uppercased(), size)
    }

    /// "Lunes, mínima 10 grados, máxima 20 grados, 30% de lluvia" — one day read as a spoken row.
    private static func dayA11yLabel(_ d: DaySnapshot) -> String {
        var parts = [weekday(d.date)]
        if let lo = d.min, let hi = d.max { parts.append("mínima \(lo) grados, máxima \(hi) grados") }
        else if let hi = d.max { parts.append("máxima \(hi) grados") }
        else if let lo = d.min { parts.append("mínima \(lo) grados") }
        if let p = d.probPrecip, p >= 10 { parts.append("\(p)% de lluvia") }
        return parts.joined(separator: ", ")
    }

    /// One day's temperature range as a coloured segment inside a faint full-width track, positioned by
    /// where [min, max] falls within the week's span and filled with that range's own temperature colours.
    @ViewBuilder
    private func rangeBar(_ d: DaySnapshot) -> some View {
        let span = max(1, weekHi - weekLo)
        let lo = d.min ?? weekLo, hi = d.max ?? weekHi
        let start = CGFloat(lo - weekLo) / CGFloat(span)
        let end = CGFloat(hi - weekLo) / CGFloat(span)
        let barH: CGFloat = size == .phone ? 6 : 4
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(gradient: Palette.temperatureGradient(min: lo, max: hi),
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(barH, w * (end - start)))
                    .offset(x: w * start)
            }
        }
        .frame(height: barH)
        .frame(maxWidth: .infinity)
    }

    private func fmt(_ v: Int?) -> String { v.map { "\($0)°" } ?? "—" }
    private static func weekday(_ date: Date) -> String { AuraTime.shortWeekday(date) }
}

// MARK: - Celestial arc (shared by the sun and moon cards)

/// Shared geometry for the sun and moon arc cards. The sin(π·t) polyline, the compact duration format and
/// the arc box dimensions are identical for both, so the two cards trace the same curve and line up.
enum CelestialArc {
    static func height(_ size: AuraSize) -> CGFloat { size == .phone ? 96 : 58 }
    static func glyphRadius(_ size: AuraSize) -> CGFloat { size == .phone ? 12 : 7.5 }

    /// A quadratic-looking arc sampled as a polyline: y follows sin(π·t) so it's flat at both horizons and
    /// highest at the apex, matching `AuraSunPath`'s own altitude curve.
    static func path(w: CGFloat, baseline: CGFloat, rise: CGFloat, from: CGFloat, to: CGFloat) -> Path {
        var p = Path()
        guard to > from else { return p }
        let steps = 48
        for i in 0...steps {
            let t = from + (to - from) * CGFloat(i) / CGFloat(steps)
            let point = CGPoint(x: t * w, y: baseline - CGFloat(sin(Double(t) * .pi)) * rise)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }

    /// Compact "3 h 12 min" / "43 min". `wrapDay` adds 24 h to a negative span (tomorrow's event).
    static func compact(from: Date, to: Date, wrapDay: Bool = false) -> String? {
        var seconds = Int(to.timeIntervalSince(from))
        if wrapDay && seconds < 0 { seconds += 24 * 3600 }
        guard seconds > 0 else { return nil }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes)) min" : "\(minutes) min"
    }
}

/// The drawn arc shared by both cards: horizon line, the full day/night arc (faint), the travelled portion
/// in the body's own light (drawn only when `travelledColors` is non-nil — the sun skips it at night, the
/// moon's collapses to nothing while it is down since `fraction` is 0), and a glyph at the live position.
/// The sun supplies its disc-and-glow, the moon its phased disc, both through `glyph(point, radius)`.
struct CelestialArcView<Glyph: View>: View {
    let size: AuraSize
    let fraction: CGFloat
    let fullArcOpacity: Double
    let travelledColors: [Color]?
    @ViewBuilder let glyph: (CGPoint, CGFloat) -> Glyph

    var body: some View {
        let glyphR = CelestialArc.glyphRadius(size)
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let baseline = h - 1
            let rise = h - glyphR - 3
            let f = fraction
            let point = CGPoint(x: f * w, y: baseline - sin(Double(f) * .pi) * Double(rise))
            ZStack {
                // Horizon.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: baseline))
                    p.addLine(to: CGPoint(x: w, y: baseline))
                }
                .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                // The full arc, faint.
                CelestialArc.path(w: w, baseline: baseline, rise: rise, from: 0, to: 1)
                    .stroke(.white.opacity(fullArcOpacity),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))

                // The travelled portion, rise → now, in the body's own light.
                if let colors = travelledColors {
                    CelestialArc.path(w: w, baseline: baseline, rise: rise, from: 0, to: f)
                        .stroke(
                            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                glyph(point, glyphR)
            }
        }
        .frame(height: CelestialArc.height(size))
        // Inset by the glyph radius so the disc sits fully inside the card at the rise/set ends (fraction 0
        // and 1) instead of half-clipping on the card edge.
        .padding(.horizontal, glyphR)
    }
}

/// One end of an arc card: an icon + precise time, its label below, and an optional civil-twilight footnote
/// (the sun's first/last light, phone only). Shared by both cards; the moon passes no civil line.
struct CelestialArcEnd: View {
    let size: AuraSize
    let icon: String
    let iconColor: Color
    let label: String
    let time: Date?
    var trailing: Bool = false
    var civilLabel: String? = nil
    var civilTime: Date? = nil

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .auraFont(size.smallSize, relativeTo: .callout)
                    .foregroundStyle(iconColor)
                Text(time.map { AuraTime.hhmm($0) } ?? "—")
                    .auraFont(size.bodySize - (size == .phone ? 2 : 3), relativeTo: .title3, weight: .semibold)
                    .foregroundStyle(.white)
            }
            Text(label)
                .auraFont(size.smallSize - 2, relativeTo: .callout)
                .foregroundStyle(.white.opacity(0.6))
            if size == .phone, let civilLabel, let civilTime {
                Text("\(civilLabel) \(AuraTime.hhmm(civilTime))")
                    .auraFont(size.smallSize - 3, relativeTo: .callout)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

/// The generic sun/moon arc card. Holds the shared scaffold — an `AuraCard` with the drawn arc, the two
/// ends, the centre readout, an optional footer, plus the detail sheet and collapsed accessibility — and
/// takes only what differs from the sun and the moon: the arc's glyph and colours, the ends, the readout,
/// the footer lines and the spoken value.
struct AuraCelestialArcCard<Glyph: View, Ends: View, Footer: View, Detail: View>: View {
    let size: AuraSize
    let title: String
    let hasTimes: Bool
    let unavailableText: String
    let accessibilityValue: String
    let fraction: CGFloat
    let fullArcOpacity: Double
    let travelledColors: [Color]?
    @ViewBuilder let glyph: (CGPoint, CGFloat) -> Glyph
    @ViewBuilder let ends: () -> Ends
    let readout: String
    @ViewBuilder let footer: () -> Footer
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        AuraCard(size: size) {
            if hasTimes {
                VStack(spacing: size == .phone ? 12 : 7) {
                    CelestialArcView(size: size, fraction: fraction, fullArcOpacity: fullArcOpacity,
                                     travelledColors: travelledColors, glyph: glyph)
                    ends()
                    Text(readout)
                        .auraFont(size.smallSize + (size == .phone ? 1 : 0), relativeTo: .callout, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .center)
                    footer()
                }
            } else {
                Text(unavailableText)
                    .auraFont(size.bodySize - 2, relativeTo: .title3)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, size == .phone ? 10 : 6)
            }
        }
        .auraDetail(size, detail: detail)
        .auraSectionTitle(title.uppercased(), size)
        // The arc is a drawn path — silent to VoiceOver. Collapse the whole card into one element and speak
        // the facts it encodes: the two events and the centre readout.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }
}

// MARK: - Sun arc

/// A full-width daytime arc. The sun rides from orto (left / east) to ocaso (right / west) along a
/// shallow curve, sitting at its live position for the hour — the same east→noon→west travel the
/// `AuraSky` background paints, so the card and the sky agree. Orto and ocaso times anchor the two ends;
/// the centre reads the daylight still to come, or after dark the countdown to the next sunrise.
///
/// No baked-in "now": the arc position is recomputed from `snapshot.sunrise/sunset` and the passed
/// `now` at display time, so an overnight-cached snapshot re-anchors like the hourly strip does.
public struct AuraSunArcCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    let now: Date
    /// Civil twilight for this place and hour, solved once in init. Both `body` (the twilight arc ends)
    /// and the accessibility value read it, so a computed `solar` re-ran the SolarTimes solve several
    /// times per render — the twin AuraMoonArcCard already hoists its heavier solve the same way.
    private let civilDawn: Date?
    private let civilDusk: Date?

    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date()) {
        self.snapshot = snapshot; self.size = size; self.now = now
        if let lat = snapshot.latitude, let lon = snapshot.longitude {
            let solar = SolarTimes(date: now, latitude: lat, longitude: lon)
            self.civilDawn = solar.civilDawn
            self.civilDusk = solar.civilDusk
        } else {
            self.civilDawn = nil
            self.civilDusk = nil
        }
    }

    private var sunrise: Date? { snapshot.sunrise }
    private var sunset: Date? { snapshot.sunset }
    private var hasTimes: Bool { sunrise != nil && sunset != nil }

    /// Solar noon: the arc's apex, the midpoint between orto and ocaso.
    private var solarNoon: Date? {
        guard let sr = sunrise, let ss = sunset, ss > sr else { return nil }
        return sr.addingTimeInterval(ss.timeIntervalSince(sr) / 2)
    }

    /// Today's daylight length, orto → ocaso.
    private var dayLength: TimeInterval? {
        guard let sr = sunrise, let ss = sunset, ss > sr else { return nil }
        return ss.timeIntervalSince(sr)
    }

    /// Change in daylight length vs yesterday, whole minutes (+ lengthening, − shortening). Needs the
    /// snapshot's coordinates for a second `SolarTimes` solve; nil without them or at a polar day/night.
    private var dayLengthDeltaMinutes: Int? {
        guard let today = dayLength, let lat = snapshot.latitude, let lon = snapshot.longitude,
              let yday = Calendar.current.date(byAdding: .day, value: -1, to: now) else { return nil }
        let y = SolarTimes(date: yday, latitude: lat, longitude: lon)
        guard let ysr = y.sunrise, let yss = y.sunset, yss > ysr else { return nil }
        return Int(((today - yss.timeIntervalSince(ysr)) / 60).rounded())
    }

    /// The daylight-length line: total daylight, plus the day-over-day delta on the phone (too wide for
    /// the watch). `nil` when orto/ocaso are unavailable.
    private var dayLengthLine: String? {
        guard let sr = sunrise, let ss = sunset, let len = CelestialArc.compact(from: sr, to: ss) else { return nil }
        var line = "\(len) de luz"
        if size == .phone, let dm = dayLengthDeltaMinutes {
            if dm > 0 { line += " · \(dm) min más que ayer" }
            else if dm < 0 { line += " · \(-dm) min menos que ayer" }
            else { line += " · igual que ayer" }
        }
        return line
    }

    /// Daytime: now sits between orto and ocaso.
    private var isDay: Bool {
        guard let sr = sunrise, let ss = sunset else { return false }
        return now >= sr && now <= ss
    }

    /// 0 at orto → 1 at ocaso, clamped; pinned to the near horizon end while it's dark.
    private var fraction: CGFloat {
        guard let sr = sunrise, let ss = sunset, ss > sr else { return 0.5 }
        if now < sr { return 0 }
        if now > ss { return 1 }
        return CGFloat(now.timeIntervalSince(sr) / ss.timeIntervalSince(sr))
    }

    public var body: some View {
        let night = !isDay
        return AuraCelestialArcCard(
            size: size,
            title: "Sol",
            hasTimes: hasTimes,
            unavailableText: "Horario solar no disponible",
            accessibilityValue: a11yValue,
            fraction: fraction,
            // The full arc dims and the travelled portion drops out once the sun is down.
            fullArcOpacity: night ? 0.16 : 0.24,
            travelledColors: night ? nil : [Palette.tempOrange, Palette.tempYellow],
            glyph: { point, glyphR in
                // The sun: a soft glow under a solid disc. Muted and pale after dark.
                let core = night ? Color(white: 0.82) : Palette.tempYellow
                let glow = night ? Color(white: 0.6) : Palette.tempOrange
                ZStack {
                    Circle().fill(glow.opacity(night ? 0.35 : 0.6))
                        .frame(width: glyphR * 2.8, height: glyphR * 2.8)
                        .blur(radius: size == .phone ? 7 : 4)
                        .position(point)
                    Circle().fill(core)
                        .frame(width: glyphR * 2, height: glyphR * 2)
                        .position(point)
                }
            },
            ends: {
                // Orto on the left, ocaso on the right, each with its icon, precise location-based time and
                // (phone only) its civil-twilight line — first light before orto, last light after ocaso.
                HStack(alignment: .top) {
                    CelestialArcEnd(size: size, icon: "sunrise.fill", iconColor: Palette.tempOrange,
                                    label: "Orto", time: sunrise,
                                    civilLabel: "Primera luz", civilTime: civilDawn)
                    Spacer()
                    CelestialArcEnd(size: size, icon: "sunset.fill", iconColor: Palette.tempOrange,
                                    label: "Ocaso", time: sunset, trailing: true,
                                    civilLabel: "Última luz", civilTime: civilDusk)
                }
            },
            readout: readout,
            footer: {
                // Solar noon (the arc's apex) and how long today's daylight runs — both from the same
                // orto/ocaso, no new data. Noon is phone-only; the length line carries the day-over-day
                // delta there too. Dimmer than the readout so it reads as secondary.
                if size == .phone, let noon = solarNoon {
                    Text("Mediodía solar \(hhmm(noon))")
                        .auraFont(size.smallSize, relativeTo: .callout, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                if let line = dayLengthLine {
                    Text(line)
                        .auraFont(size.smallSize, relativeTo: .callout, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
            },
            detail: { AuraSolarSheet(snapshot: snapshot, now: now) }
        )
    }

    /// Spoken summary for VoiceOver: sunrise, sunset and the centre readout, or the unavailable notice.
    private var a11yValue: String {
        guard let sr = sunrise, let ss = sunset else { return "Horario solar no disponible" }
        var parts = ["Amanece a las \(hhmm(sr))", "anochece a las \(hhmm(ss))"]
        if let dawn = civilDawn { parts.append("primera luz a las \(hhmm(dawn))") }
        if let dusk = civilDusk { parts.append("última luz a las \(hhmm(dusk))") }
        if let noon = solarNoon { parts.append("mediodía solar a las \(hhmm(noon))") }
        if let len = CelestialArc.compact(from: sr, to: ss) { parts.append("\(len) de luz") }
        var value = parts.joined(separator: ", ") + "."
        let r = readout
        if !r.isEmpty { value += " \(r)." }
        return value
    }

    /// Centre line: daylight remaining while the sun is up, else the countdown to the next sunrise.
    private var readout: String {
        if isDay, let ss = sunset, let left = CelestialArc.compact(from: now, to: ss) {
            return "Quedan \(left) de luz"
        }
        // After dark: the snapshot only carries today's sunrise; sun times barely move day to day, so
        // this morning's orto stands in for tomorrow's — wrap the negative interval by 24 h.
        if let sr = sunrise, let until = CelestialArc.compact(from: now, to: sr, wrapDay: true) {
            return "Amanece en \(until)"
        }
        return ""
    }

    private func hhmm(_ date: Date) -> String { AuraTime.hhmm(date) }
}

// MARK: - Moon arc

/// The night twin of `AuraSunArcCard` — but tracing the moon's *own* path, not the sun's. The moon rides
/// from its real salida (moonrise, left / east) to its real puesta (moonset, right / west) along the same
/// shallow curve, sitting at its live position for the hour and wearing tonight's true phase — the very
/// disc `AuraSky` draws after dark. Salida and puesta anchor the two ends; the centre counts down to the
/// next of them. When the moon is below the horizon it rests at the eastern edge, waiting to rise.
///
/// The path is the moon's own appearance (salida → puesta from `LunarTimes`), not the night span: the moon
/// often rises before the sun sets or sets before dawn, so this no longer borrows the sun's ocaso/orto.
/// Solved once from the location's coordinates and the passed `now`, so an overnight-cached snapshot stays
/// honest. Falls back to "unavailable" when coordinates are absent (snapshots cached before they carried them).
public struct AuraMoonArcCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    let now: Date
    // The moon's real appearance and phase for this place and hour, solved once in init: the LunarTimes
    // scan is ~650 position evaluations, too heavy to repeat across the several body-side accesses below.
    private let moonrise: Date?
    private let moonset: Date?
    private let illumination: Double
    private let waxing: Bool

    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date()) {
        self.snapshot = snapshot; self.size = size; self.now = now
        if let lat = snapshot.latitude, let lon = snapshot.longitude {
            let times = LunarTimes(date: now, latitude: lat, longitude: lon)
            self.moonrise = times.moonrise
            self.moonset = times.moonset
        } else {
            self.moonrise = nil; self.moonset = nil
        }
        let pos = LunarPosition(date: now)
        self.illumination = pos.illumination
        self.waxing = pos.waxing
    }

    private var hasTimes: Bool { moonrise != nil && moonset != nil }
    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }

    /// Is the moon above the horizon right now? `LunarTimes` reports a past salida and a future puesta only
    /// while the moon is up; when it is down both times sit in the future (the next appearance).
    private var isUp: Bool {
        guard let r = moonrise, let s = moonset else { return false }
        return r <= now && s > now
    }

    /// 0 at salida → 1 at puesta while the moon is up; rests at 0 (the eastern horizon) when it is down.
    private var fraction: CGFloat {
        guard isUp, let r = moonrise, let s = moonset, s > r else { return 0 }
        return clamp(CGFloat(now.timeIntervalSince(r) / s.timeIntervalSince(r)))
    }

    public var body: some View {
        AuraCelestialArcCard(
            size: size,
            title: "Luna",
            hasTimes: hasTimes,
            unavailableText: "Horario lunar no disponible",
            accessibilityValue: a11yValue,
            fraction: fraction,
            fullArcOpacity: 0.24,
            // Drawn only while the moon is up; when it is down `fraction` is 0 and the travelled path is empty.
            travelledColors: [Palette.tempBlue, Color(white: 0.95)],
            glyph: { point, glyphR in
                // The moon: a soft cool glow — dimming toward a new moon — under tonight's real phase disc.
                let glow = Color(red: 0.66, green: 0.72, blue: 0.92)
                ZStack {
                    Circle().fill(glow.opacity(0.45 * max(illumination, 0.22)))
                        .frame(width: glyphR * 2.8, height: glyphR * 2.8)
                        .blur(radius: size == .phone ? 7 : 4)
                        .position(point)
                    PhasedMoonDisc(illumination: illumination, waxing: waxing, radius: glyphR,
                                   litColor: Color(red: 0.94, green: 0.96, blue: 1.0))
                        .position(point)
                }
            },
            ends: {
                // Salida on the left (moonrise, east), puesta on the right (moonset, west).
                HStack(alignment: .top) {
                    CelestialArcEnd(size: size, icon: "arrow.up", iconColor: Palette.tempBlue,
                                    label: "Salida", time: moonrise)
                    Spacer()
                    CelestialArcEnd(size: size, icon: "arrow.down", iconColor: Palette.tempBlue,
                                    label: "Puesta", time: moonset, trailing: true)
                }
            },
            readout: readout,
            footer: { EmptyView() },
            detail: { AuraMoonSheet(snapshot: snapshot, now: now) }
        )
    }

    /// Spoken summary for VoiceOver: the moon's salida, its puesta and the centre readout.
    private var a11yValue: String {
        guard let r = moonrise, let s = moonset else { return "Horario lunar no disponible" }
        let line = readout
        return "Sale a las \(hhmm(r)), se pone a las \(hhmm(s))." + (line.isEmpty ? "" : " \(line).")
    }

    /// Centre line: the countdown to the moon's next event — its puesta while it is up, otherwise its salida.
    private var readout: String {
        if isUp, let s = moonset, let until = CelestialArc.compact(from: now, to: s) {
            return "Se pone en \(until)"
        }
        if !isUp, let r = moonrise, let until = CelestialArc.compact(from: now, to: r) {
            return "Sale en \(until)"
        }
        return ""
    }

    private func hhmm(_ date: Date) -> String { AuraTime.hhmm(date) }
}

// MARK: - Wind

/// Full-width wind card: the same compass rose the Watch complication draws (arrow + speed in the
/// centre), with the direction spelled out beside it. Reusing `AuraWindCircular` keeps the phone, Watch
/// face and this card visually identical.
public struct AuraWindCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    public init(snapshot: WeatherSnapshot, size: AuraSize) {
        self.snapshot = snapshot; self.size = size
    }

    public var body: some View {
        let rose: CGFloat = size == .phone ? 100 : 62
        return AuraCard(size: size) {
            HStack(spacing: size.stackSpacing) {
                AuraWindCircular(snapshot: snapshot, dense: size == .phone, card: true)
                    .frame(width: rose, height: rose)
                VStack(alignment: .leading, spacing: size == .phone ? 4 : 2) {
                    Text(snapshot.windSpeed.map { "\($0) km/h" } ?? "—")
                        .auraFont(size.bodySize + (size == .phone ? 6 : 2), relativeTo: .title3, weight: .bold)
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(directionText)
                        .auraFont(size.smallSize, relativeTo: .callout)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2).minimumScaleFactor(0.8)
                    if let gust = snapshot.windGust {
                        Text("Rachas \(gust) km/h")
                            .auraFont(size.smallSize, relativeTo: .callout, weight: .semibold)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .auraDetail(size) { AuraBeaufortSheet(snapshot: snapshot) }
        .auraSectionTitle("Viento".uppercased(), size)
        // The rose is a decorative dial; the speed, direction and gusts beside it are real text. Read
        // them as one element so VoiceOver speaks "12 km/h, del Sudoeste · 225°, Rachas 40 km/h".
        .accessibilityElement(children: .combine)
    }

    /// "del Sudoeste · 225°", or "En calma" when there's no measurable direction. The full name reads
    /// clearly; the numeric bearing (the reported 16-point sector, degrees) rides beside it.
    private var directionText: String {
        guard let dir = snapshot.windDirection, (snapshot.windSpeed ?? 0) > 0 else { return "En calma" }
        return "del \(dir.spanishName) · \(Int(dir.degrees))°"
    }
}

// MARK: - Observation station

/// The nearest recent AEMET station behind this location's observed reading: its name, how far it sits,
/// and which surface metrics it actually reports — so a station that measures only some fields reads as
/// clearly as one that measures them all. Shown on the phone, only when a station resolved.
public struct AuraStationCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    public init(snapshot: WeatherSnapshot, size: AuraSize) {
        self.snapshot = snapshot; self.size = size
    }

    /// The canonical metric order: chip icon, the short label shown under the value, the full name
    /// spoken by VoiceOver, and the unit spoken with the value. Labels are kept to ≤6 glyphs ("Humed.",
    /// "Pres.") so every chip's label renders at the same size — a longer word would scale down on its
    /// own and read smaller than the rest.
    private static let metrics: [(flag: ObservedMetrics, icon: String, label: String, full: String, unit: String)] = [
        (.temperature,   "thermometer.medium", "Temp.",  "Temperatura", "grados"),
        (.wind,          "wind",               "Viento", "Viento",      "kilómetros por hora"),
        (.humidity,      "humidity.fill",      "Humed.", "Humedad",     "por ciento"),
        (.pressure,      "gauge.medium",       "Pres.",  "Presión",     "hectopascales"),
        (.precipitation, "cloud.rain.fill",    "Lluvia", "Lluvia",      "milímetros"),
    ]

    /// Full metric names for the completeness line, in the same order (lower-cased for mid-sentence use).
    private static let fullNames: [(flag: ObservedMetrics, name: String)] = [
        (.temperature, "temperatura"), (.wind, "viento"), (.humidity, "humedad"),
        (.pressure, "presión"), (.precipitation, "precipitación"),
    ]

    public var body: some View {
        let available = snapshot.observedMetrics
        let reading = snapshot.observedReading
        return AuraCard(size: size) {
            VStack(alignment: .leading, spacing: 12) {
                Text(header)
                    .auraFont(size.bodySize - 1, relativeTo: .title3, weight: .semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8)
                HStack(alignment: .top, spacing: 5) {
                    ForEach(Self.metrics, id: \.icon) { metric in
                        let on = available.contains(metric.flag)
                        metricChip(metric, value: on ? value(metric.flag, reading) : nil, on: on)
                    }
                }
                Text(completeness(available))
                    .auraFont(size.smallSize - 1, relativeTo: .callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
        }
        .auraSectionTitle("Estación de observación".uppercased(), size)
    }

    /// The station's measured value for a metric, formatted for its chip (unit implied by the label).
    /// Nil when the station doesn't report it, so the chip shows a dash. Spanish decimal comma for rain.
    private func value(_ flag: ObservedMetrics, _ reading: ObservedReading?) -> String? {
        guard let reading else { return nil }
        switch flag {
        case .temperature:   return reading.temperature.map { "\($0)°" }
        case .wind:          return reading.windKmh.map { "\($0)" }
        case .humidity:      return reading.humidity.map { "\($0)%" }
        case .pressure:      return reading.pressure.map { "\($0)" }
        case .precipitation: return reading.precipMm.map {
            String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ",")
        }
        default:             return nil
        }
    }

    /// "Madrid Retiro · a 3 km" — the station and its distance (Spanish decimal comma under 10 km).
    private var header: String {
        let name = snapshot.observedStation ?? "—"
        guard let km = snapshot.observedStationDistanceKm else { return name }
        let dist = km < 10
            ? String(format: "%.1f", km).replacingOccurrences(of: ".", with: ",")
            : "\(Int(km.rounded()))"
        return "\(name) · a \(dist) km"
    }

    /// One metric chip: icon, the station's measured value, then the short label. Greyed with a dash for
    /// the value (MITECO's grey-for-unavailable convention) when the station doesn't report it. The label
    /// sits at a fixed size (no per-chip shrink-to-fit) so all five read at the same size — the reason the
    /// labels are pre-abbreviated to a common width.
    private func metricChip(_ metric: (flag: ObservedMetrics, icon: String, label: String, full: String, unit: String),
                            value: String?, on: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: metric.icon)
                .font(.system(size: size == .phone ? 16 : 11, weight: .medium))
                .foregroundStyle(on ? .white : .white.opacity(0.3))
            Text(value ?? "—")
                .auraFont(size.bodySize - (size == .phone ? 2 : 4), relativeTo: .body, weight: .semibold, design: .rounded)
                .foregroundStyle(.white.opacity(on ? 0.95 : 0.35))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(metric.label)
                .auraFont(size.smallSize - (size == .phone ? 4 : 1), relativeTo: .callout, weight: .medium)
                .foregroundStyle(.white.opacity(on ? 0.7 : 0.35))
                .lineLimit(1).minimumScaleFactor(0.9)   // safety only; every label fits at this size
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.white.opacity(on ? 0.12 : 0.04)))
        // Read each chip as one element ("Viento 12 kilómetros por hora" / "Presión, no disponible").
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(metric, value: value, on: on))
    }

    /// "Temperatura 24 grados" when reported, "Presión, no disponible" when the station omits it. Uses the
    /// full metric name and unit word, not the abbreviated on-screen label.
    private func accessibilityText(_ metric: (flag: ObservedMetrics, icon: String, label: String, full: String, unit: String),
                                   value: String?, on: Bool) -> String {
        guard on, let value else { return "\(metric.full), no disponible" }
        // Strip the "°"/"%" glyphs from the spoken value; the unit word carries the meaning.
        let spoken = value.replacingOccurrences(of: "°", with: "").replacingOccurrences(of: "%", with: "")
        return "\(metric.full) \(spoken) \(metric.unit)"
    }

    /// "Mide todos los datos de superficie." or "No mide: presión y precipitación."
    private func completeness(_ available: ObservedMetrics) -> String {
        let missing = Self.fullNames.filter { !available.contains($0.flag) }.map(\.name)
        guard !missing.isEmpty else { return "Mide todos los datos de superficie." }
        let list = missing.count > 1
            ? missing.dropLast().joined(separator: ", ") + " y " + missing.last!
            : missing[0]
        return "No mide: \(list)."
    }
}

// MARK: - Air quality

/// Nearest-station air quality from MITECO's national ICA feed: the 1–6 category in its official colour,
/// the category name, and — small — the pollutant that drove it plus which station and how far. Shown
/// only when a reading resolved (the card is dropped otherwise), so it never displays a placeholder.
public struct AuraAirQualityCard: View {
    let airQuality: AirQuality
    let size: AuraSize
    public init(airQuality: AirQuality, size: AuraSize) {
        self.airQuality = airQuality; self.size = size
    }

    public var body: some View {
        let color = Palette.airQuality(airQuality.category)
        let swatch: CGFloat = size == .phone ? 46 : 30
        let showComponents = size == .phone && !airQuality.components.isEmpty
        return AuraCard(size: size) {
            VStack(alignment: .leading, spacing: showComponents ? 12 : 0) {
                HStack(spacing: size.stackSpacing) {
                    // The ICA colour swatch carrying the 1–6 category number.
                    ZStack {
                        Circle().fill(color)
                        Text("\(airQuality.category)")
                            .auraFont(size.bodySize + (size == .phone ? 3 : 0), relativeTo: .title3, weight: .heavy, design: .rounded)
                            .foregroundStyle(.white)
                    }
                    .frame(width: swatch, height: swatch)
                    .shadow(color: color.opacity(0.6), radius: 5)

                    VStack(alignment: .leading, spacing: size == .phone ? 3 : 1) {
                        Text(airQuality.categoryName)
                            .auraFont(size.bodySize - (size == .phone ? 1 : 3), relativeTo: .title3, weight: .semibold)
                            .foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.8)
                        Text(detail)
                            .auraFont(size.smallSize - 1, relativeTo: .callout)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    Spacer(minLength: 0)
                }
                // The swatch carries the 1–6 category by colour + number; combine it with the name and
                // detail so VoiceOver speaks one "Regular, por O₃ · Retiro · a 1,7 km" element.
                .accessibilityElement(children: .combine)

                if showComponents { componentsRow }
            }
        }
        .auraDetail(size) { AuraAirQualitySheet(airQuality: airQuality) }
        .auraSectionTitle("Calidad del aire".uppercased(), size)
    }

    /// The five ICA pollutants as an even row of colour-coded chips (label, value, band bar), each tinted
    /// by its own indicative ICA band — the same official palette as the headline swatch — so the mix reads
    /// like a compact version of the ICA per-pollutant chart. Pollutants this station doesn't measure show
    /// greyed with a dash (MITECO's grey-for-unavailable convention). The pollutant that drove the overall
    /// category is ringed. A single shared "µg/m³" caption sits beneath.
    private var componentsRow: some View {
        // Measured values keyed by MITECO token, for O(1) lookup against the canonical five.
        let measured = Dictionary(airQuality.components.map { ($0.pollutant, $0) },
                                  uniquingKeysWith: { a, _ in a })
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(AirComponent.order, id: \.self) { token in
                    componentChip(token: token,
                                  component: measured[token],
                                  isDriver: token == airQuality.pollutant)
                }
            }
            Text("µg/m³")
                .auraFont(size.smallSize - 2, relativeTo: .callout)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// One pollutant chip: its label over the value over a band bar, all in the pollutant's ICA colour
    /// (grey when the station doesn't measure it). The driver pollutant is ringed to tie it to the reason.
    @ViewBuilder
    private func componentChip(token: String, component: AirComponent?, isDriver: Bool) -> some View {
        let measured = component != nil
        let color = Palette.airQuality(component?.icaCategory ?? 0)   // 0 → grey (unmeasured)
        VStack(spacing: 4) {
            Text(AirComponent.label(for: token))
                .auraFont(size.smallSize - 1, relativeTo: .callout, weight: .medium)
                .foregroundStyle(.white.opacity(measured ? 0.7 : 0.35))
            Text(component?.valueText ?? "–")
                .auraFont(size.bodySize - 1, relativeTo: .title3, weight: .bold, design: .rounded)
                .foregroundStyle(measured ? .white : .white.opacity(0.3))
            Capsule()
                .fill(color)
                .frame(height: 4)
                .opacity(measured ? 1 : 0.45)
        }
        .frame(maxWidth: .infinity)
        .lineLimit(1).minimumScaleFactor(0.65)
        .padding(.vertical, 6)
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(measured ? 0.16 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(color.opacity(isDriver && measured ? 0.9 : 0), lineWidth: 1.5)
        )
        // Read each pollutant as one element ("O₃, 45") instead of label and value as loose fragments.
        .accessibilityElement(children: .combine)
    }

    /// "por O₃ · Retiro · a 1,7 km" — the driver pollutant, the station, and its distance (Spanish
    /// decimal comma under 10 km, whole km beyond). `partial` (index computed from fewer pollutants) is
    /// flagged with a trailing "·  parcial" so a lower-confidence category isn't shown as if it were full.
    private var detail: String {
        var parts: [String] = []
        if let pollutant = airQuality.pollutantLabel { parts.append("por \(pollutant)") }
        parts.append(airQuality.station)
        let km = airQuality.distanceKm
        parts.append(km < 10
            ? "a " + String(format: "%.1f", km).replacingOccurrences(of: ".", with: ",") + " km"
            : "a \(Int(km.rounded())) km")
        if airQuality.partial { parts.append("parcial") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - UV index

/// AEMET's forecast max UV index for today, in its WHO band colour: the value in a swatch, the band name
/// ("Muy alto"), and a one-line protection cue. Shown only when a value resolved for the location.
public struct AuraUVCard: View {
    let uvIndex: UVIndex
    let hourly: [UVHourSlot]
    let now: Date
    let size: AuraSize
    /// True when the current sky is overcast/wet enough that cloud is materially holding the live UV below
    /// its clear-sky potential. Drives the cloud cue on the "Ahora" reading and in the detail sheet — the
    /// same signal the UV complication shows on the watch/Lock Screen.
    let cloudy: Bool
    public init(uvIndex: UVIndex, hourly: [UVHourSlot] = [], now: Date = Date(), size: AuraSize,
                cloudy: Bool = false) {
        self.uvIndex = uvIndex; self.hourly = hourly; self.now = now; self.size = size; self.cloudy = cloudy
    }

    public var body: some View {
        let color = Palette.uvIndex(uvIndex.value)
        let swatch: CGFloat = size == .phone ? 46 : 30
        // Today's daytime UV hours from CAMS — the per-hour granularity AEMET's daily-max lacks.
        let today = hourly.todaySlots(reference: now).filter { $0.uv > 0 }
        return AuraCard(size: size) {
            VStack(alignment: .leading, spacing: size == .phone ? 12 : 7) {
                HStack(spacing: size.stackSpacing) {
                    // The swatch is AEMET's clear-sky daily maximum, not the current UV — labelled so on the
                    // card face, so a big "5" on a rainy afternoon reads as "today's peak", not "right now".
                    // The honest current value lives in the hourly strip below ("Ahora N") when CAMS data is present.
                    VStack(spacing: size == .phone ? 3 : 1) {
                        ZStack {
                            Circle().fill(color)
                            Text("\(uvIndex.value)")
                                .auraFont(size.bodySize + (size == .phone ? 3 : 0), relativeTo: .title3, weight: .heavy, design: .rounded)
                                .foregroundStyle(.white)
                        }
                        .frame(width: swatch, height: swatch)
                        .shadow(color: color.opacity(0.6), radius: 5)
                        Text("Máx. hoy")
                            .auraFont(size.smallSize - (size == .phone ? 2 : 3), relativeTo: .callout, weight: .semibold)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: size == .phone ? 3 : 1) {
                        HStack(spacing: 6) {
                            // The band's protection glyph — the same symbol the UV complication shows, so
                            // the card teaches what that icon means (its legend lives in the tap sheet).
                            Image(systemName: uvIndex.glyph)
                                .auraFont(size.bodySize - (size == .phone ? 1 : 3), relativeTo: .title3, weight: .semibold)
                                .foregroundStyle(color)
                            Text(uvIndex.bandName)
                                .auraFont(size.bodySize - (size == .phone ? 1 : 3), relativeTo: .title3, weight: .semibold)
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text(uvIndex.advice)
                            .auraFont(size.smallSize - 1, relativeTo: .callout)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    Spacer(minLength: 0)
                }
                // Swatch number + "Máx. hoy" + band + advice as one spoken element: "5, Máx. hoy, Muy
                // alto, …" — otherwise the daily-max number reads adrift from the band it belongs to.
                .accessibilityElement(children: .combine)

                // The hourly curve, only when CAMS data is present — the swatch above is AEMET's forecast
                // daily maximum, this is how the UV actually rises and falls through today, hour by hour.
                if today.count >= 3 {
                    UVHourStrip(today: today, nowSlot: hourly.current(at: now), size: size, cloudy: cloudy)
                }
            }
        }
        .auraDetail(size) { AuraUVSheet(uvIndex: uvIndex, cloudy: cloudy) }
        .auraSectionTitle("Índice UV".uppercased(), size)
    }
}

/// Today's UV, hour by hour, as a slim band-tinted bar strip under the daily-max swatch. Bar heights
/// track the day's own shape (scaled to today's peak so a low-UV winter day still reads); colour
/// carries the absolute WHO band. The current hour is outlined and its value called out above.
private struct UVHourStrip: View {
    let today: [UVHourSlot]
    let nowSlot: UVHourSlot?
    let size: AuraSize
    /// The current sky is holding the live UV below its clear-sky potential — show a cloud beside "Ahora".
    var cloudy: Bool = false

    private var peak: UVHourSlot? { today.max { $0.uv < $1.uv } }

    /// The span of today where the UV index reaches 3, the WHO threshold at which protection is advised
    /// (the start of the "Moderado" band). Start is the first such hour; end is the hour after the last,
    /// so it reads as "protected until". `nil` when UV never reaches 3 today (nothing to advise).
    private var protectionWindow: (start: Int, end: Int)? {
        let above = today.filter { $0.index >= 3 }
        guard let first = above.first, let last = above.last else { return nil }
        return (hour(first.date), hour(last.date) + 1)
    }

    var body: some View {
        let barsH: CGFloat = size == .phone ? 34 : 22
        let scale = max(peak?.uv ?? 1, 1)
        VStack(alignment: .leading, spacing: size == .phone ? 5 : 3) {
            // A compact readout drawn from the same series: the live value now (honest per-hour, unlike
            // the daily max) and today's peak with its hour.
            HStack(spacing: 5) {
                if let n = nowSlot, n.uv > 0 {
                    // A hollow cloud beside the live reading when overcast/wet — the same cue the UV
                    // complication shows: this "Ahora N" is the cloud-attenuated value, not the clear-sky peak.
                    if cloudy {
                        Image(systemName: "cloud")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text("Ahora \(n.index) (\(UVIndex(value: n.index).bandName.lowercased()))")
                        .foregroundStyle(.white)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                }
                if let p = peak {
                    Text("máx \(p.index) a las \(hour(p.date))h")
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            .auraFont(size.smallSize - 2, relativeTo: .callout, weight: .semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)   // the band word widens "Ahora N", so shrink before it truncates

            // The actionable window from the same hourly series: when to actually protect yourself, i.e.
            // the stretch where the index sits at or above the WHO threshold of 3.
            if let w = protectionWindow {
                Text("Protégete de \(w.start)h a \(w.end)h")
                    .auraFont(size.smallSize - 2, relativeTo: .callout, weight: .semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }

            HStack(alignment: .bottom, spacing: size == .phone ? 3 : 2) {
                ForEach(today) { slot in
                    let isNow = slot.id == nowSlot?.id
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Palette.uvIndex(slot.index))
                        .frame(height: max(barsH * CGFloat(slot.uv / scale), 3))
                        .frame(maxWidth: .infinity)
                        .opacity(isNow || nowSlot == nil ? 1 : 0.72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .strokeBorder(.white, lineWidth: isNow ? 1.5 : 0)
                        )
                }
            }
            .frame(height: barsH, alignment: .bottom)
            // Purely visual curve; the "Ahora"/"máx"/"Protégete" lines above already carry it in words.
            .accessibilityHidden(true)
        }
    }

    private func hour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}

// MARK: - Radar

/// A fetched radar frame plus the context the card shows around it. Not stored in `WeatherSnapshot` (its
/// image bytes would bloat the cached/Watch-synced snapshot) — the app fetches and passes it separately.
public struct AuraRadarInfo {
    public let image: Image
    /// Radar site name, e.g. "Madrid".
    public let siteName: String
    /// When the frame was fetched, for the freshness label.
    public let time: Date
    public init(image: Image, siteName: String, time: Date) {
        self.image = image; self.siteName = siteName; self.time = time
    }
}

/// The nearest regional radar's latest reflectivity frame — already a ~240 km circle around a nearby
/// city, so it needs no cropping. Shown large, with the site name and how fresh the frame is. iOS only
/// for now (the app doesn't ship radar images to the Watch).
public struct AuraRadarCard: View {
    let radar: AuraRadarInfo
    let size: AuraSize
    let now: Date
    public init(radar: AuraRadarInfo, size: AuraSize, now: Date = Date()) {
        self.radar = radar; self.size = size; self.now = now
    }

    public var body: some View {
        AuraCard(size: size) {
            VStack(alignment: .leading, spacing: size == .phone ? 9 : 5) {
                radar.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: max(size.cardCorner - 8, 6),
                                                style: .continuous))
                dbzLegend
                VStack(alignment: .leading, spacing: 2) {
                    Text(subtitle)
                        .auraFont(size.smallSize, relativeTo: .callout)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(rangeLine)
                        .auraFont(size.smallSize - 1, relativeTo: .callout)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .auraSectionTitle("Radar".uppercased(), size)
    }

    /// "Radar de Madrid · hace 6 min", or "· ahora" for a just-fetched frame.
    private var subtitle: String {
        let mins = Int(now.timeIntervalSince(radar.time) / 60)
        let freshness = mins <= 0 ? "ahora" : "hace \(mins) min"
        return "Radar de \(radar.siteName) · \(freshness)"
    }

    /// The regional reflectivity frame is a fixed ~240 km-radius circle centred on the radar site — a
    /// product constant, the same for every AEMET regional radar (see `RadarSite`).
    private static let rangeKm = 240

    /// Ties the dBZ legend to the image ("reflectividad") and gives "Radar de {sitio}" a real reach.
    /// Short so it never truncates on a narrow phone; the subtitle above already names the radar site.
    private var rangeLine: String {
        "Reflectividad · alcance \(Self.rangeKm) km"
    }

    /// The dBZ intensity ramp AEMET burns into the frame, spelled out: green (light) → magenta (hail), with
    /// plain-Spanish rain-intensity labels so the colours mean something without opening a manual.
    private var dbzLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.75, blue: 0.30),
                                              Color(red: 0.95, green: 0.85, blue: 0.20),
                                              Color(red: 0.95, green: 0.55, blue: 0.15),
                                              Color(red: 0.85, green: 0.20, blue: 0.20),
                                              Color(red: 0.80, green: 0.25, blue: 0.85)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: size == .phone ? 6 : 5)
            HStack(spacing: 0) {
                Text("Débil")
                Spacer(minLength: 2)
                Text("Moderada")
                Spacer(minLength: 2)
                Text("Fuerte")
                Spacer(minLength: 2)
                Text("Torrencial")
            }
            .auraFont(size.smallSize - 3, relativeTo: .callout, weight: .medium)
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Escala de intensidad")
        .accessibilityValue("De débil (verde) a torrencial o granizo (magenta)")
    }
}

// MARK: - News

/// A single "Noticias" stream — the most recent official headlines from RTVE's weather desk and AEMET,
/// round-robin merged so neither source dominates. Each row opens the article in the browser. iOS only:
/// the app doesn't pass news to the Watch, so the card renders solely when the stack is given items.
public struct AuraNewsCard: View {
    let items: [NewsItem]
    let size: AuraSize
    let now: Date
    @Environment(\.openURL) private var openURL

    public init(items: [NewsItem], size: AuraSize, now: Date = Date()) {
        self.items = items; self.size = size; self.now = now
    }

    public var body: some View {
        AuraCard(size: size) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().overlay(.white.opacity(0.12))
                            .padding(.vertical, size == .phone ? 10 : 6)
                    }
                    row(item)
                }
            }
        }
        .auraSectionTitle("Noticias".uppercased(), size)
    }

    private func row(_ item: NewsItem) -> some View {
        Button { openURL(item.link) } label: {
            VStack(alignment: .leading, spacing: size == .phone ? 5 : 3) {
                Text(item.title)
                    .auraFont(size.bodySize - (size == .phone ? 4 : 3), relativeTo: .title3, weight: .semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Text(item.source.displayName)
                        .auraFont(size.smallSize - 3, relativeTo: .callout, weight: .heavy)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Self.badgeColor(item.source), in: Capsule())
                    Text(Self.relative(from: item.date, now: now))
                        .auraFont(size.smallSize - 2, relativeTo: .callout)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A distinct badge colour per source, so the mix is scannable at a glance.
    private static func badgeColor(_ source: NewsSource) -> Color {
        switch source {
        case .rtve:      return Color(red: 0.00, green: 0.45, blue: 0.80)   // RTVE blue
        case .aemet:     return Color(red: 0.85, green: 0.38, blue: 0.10)   // AEMET orange
        case .meteored:  return Color(red: 0.11, green: 0.60, blue: 0.51)   // Meteored teal-green
        case .aemetBlog: return Color(red: 0.40, green: 0.42, blue: 0.80)   // AEMET Blog indigo
        }
    }

    /// "hace 2 h", "hace 3 d", "hace 40 min", or "ahora" within the last five minutes.
    static func relative(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        let minutes = seconds / 60, hours = minutes / 60, days = hours / 24
        if days >= 1 { return "hace \(days) d" }
        if hours >= 1 { return "hace \(hours) h" }
        if minutes >= 5 { return "hace \(minutes) min" }
        return "ahora"
    }
}

// MARK: - Alert

public struct AuraAlertCard: View {
    let alert: WeatherAlert
    let size: AuraSize
    public init(alert: WeatherAlert, size: AuraSize) { self.alert = alert; self.size = size }

    public var body: some View {
        // The aviso is always shown in full — its text is short and it matters, so it no longer hides
        // behind a tap. Header phenomenon, then AEMET's own event title (unless it's the same string),
        // the affected zone, and the window it's valid for: everything the warning carries, at a glance.
        let headerText = alert.phenomenon ?? alert.event
        return VStack(alignment: .leading, spacing: size == .phone ? 8 : 6) {
            HStack(spacing: size == .phone ? 9 : 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .auraFont(size.iconSize, relativeTo: .title2)
                Text(headerText)
                    .auraFont(size.bodySize - 1, relativeTo: .title3, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 3) {
                if alert.event != headerText {
                    Text(alert.event)
                        .auraFont(size.bodySize - 2, relativeTo: .title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let zone = alert.areaDesc, !zone.isEmpty {
                    Text(zone)
                        .auraFont(size.bodySize - 3, relativeTo: .title3, weight: .medium)
                        .opacity(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let validity = validityText {
                    Text(validity)
                        .auraFont(size.bodySize - 3, relativeTo: .title3, weight: .medium)
                        .opacity(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(size.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.alert(alert.level).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous)
            .strokeBorder(Palette.alert(alert.level).opacity(0.7), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    /// The aviso's validity window in plain Spanish, no dashes: "De {inicio} a {fin}", "Hasta {fin}",
    /// "Desde {inicio}", or nil when AEMET gave no times.
    private var validityText: String? {
        let f: (Date) -> String = { $0.formatted(.dateTime.weekday(.abbreviated).hour().minute()) }
        switch (alert.onset, alert.expires) {
        case let (start?, end?): return "De \(f(start)) a \(f(end))"
        case let (nil, end?):    return "Hasta \(f(end))"
        case let (start?, nil):  return "Desde \(f(start))"
        default:                 return nil
        }
    }
}

// MARK: - Bulletin

public struct AuraBulletinCard: View {
    let phenomenon: String?
    let text: String
    let size: AuraSize
    public init(phenomenon: String?, text: String, size: AuraSize) {
        self.phenomenon = phenomenon; self.text = text; self.size = size
    }

    public var body: some View {
        AuraCard(size: size) {
            VStack(alignment: .leading, spacing: size == .phone ? 9 : 6) {
                if let phenomenon {
                    Label(phenomenon, systemImage: "exclamationmark.triangle.fill")
                        .auraFont(size == .phone ? 18 : 14, relativeTo: .title3, weight: .semibold)
                        .foregroundStyle(Palette.tempOrange)
                }
                ForEach(Array(BulletinText.sentences(text).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .auraFont(size == .phone ? 19 : 15, relativeTo: .title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .auraSectionTitle("Predicción".uppercased(), size)
    }
}
