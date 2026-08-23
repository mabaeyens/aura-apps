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

private struct AuraCard<Content: View>: View {
    let size: AuraSize
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(size.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // A lighter frost than a full dark material: more of the sky reads through, so the cards
            // sit on the scene instead of blacking it out.
            .background(.ultraThinMaterial.opacity(0.7),
                        in: RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
    }
}

private extension View {
    /// A small uppercase section label, like Apple Weather's "HOURLY FORECAST".
    func auraSectionTitle(_ text: String, _ size: AuraSize) -> some View {
        VStack(alignment: .leading, spacing: size == .phone ? 8 : 5) {
            Text(text)
                .font(.system(size: size.titleSize, weight: .semibold))
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
            if let alert = snapshot.alert { AuraAlertCard(alert: alert, size: size) }
            // Re-anchor the strip to the real current hour: a snapshot served from cache must still
            // start at "now", not at the hour it was built.
            let upcoming = snapshot.upcomingHours(now: now)
            if !upcoming.isEmpty {
                AuraHourlyCard(hours: upcoming, size: size, scrolls: hoursScroll)
            }
            if !snapshot.days.isEmpty { AuraDailyCard(days: snapshot.days, size: size) }
            // One slot, two cards: the Sol arc while the sun is up, the Luna arc once it's dark.
            if snapshot.isNight(at: now) {
                AuraMoonArcCard(snapshot: snapshot, size: size, now: now)
            } else {
                AuraSunArcCard(snapshot: snapshot, size: size, now: now)
            }
            AuraWindCard(snapshot: snapshot, size: size)
            if let airQuality = snapshot.airQuality {
                AuraAirQualityCard(airQuality: airQuality, size: size)
            }
            if let uvIndex = snapshot.uvIndex {
                AuraUVCard(uvIndex: uvIndex, hourly: snapshot.uvHourly ?? [], now: now, size: size)
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
                .font(.system(size: size == .phone ? 14 : 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, size == .phone ? 4 : 2)
        }
        .environment(\.colorScheme, .dark)   // dark frosted materials + light text over the sky
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
                .font(.system(size: size.bodySize, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)

            Text(snapshot.heroTemp.map { "\($0)°" } ?? "—")
                .font(.system(size: size.heroTemp, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)

            Text(ForecastPhrase.headline(for: snapshot, now: now))
                .font(.system(size: size.bodySize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(ForecastPhrase.dataline(for: snapshot, now: now))
                .font(.system(size: size.bodySize - (size == .phone ? 4 : 3), weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(size == .phone ? 3 : 4).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            // An active aviso reads as its sign plus a one-word summary ("Calor", "Tormentas"), right
            // under the dataline, tinted with the warning level's colour. The full text lives in the
            // tappable aviso card below the fold; here it is a glance.
            if let alert = snapshot.alert {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(alert.shortLabel)
                }
                .font(.system(size: size.bodySize, weight: .semibold))
                .foregroundStyle(Palette.alert(alert.level))
                .padding(.top, size == .phone ? 2 : 1)
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

    /// Fixed height for the stacked rows, so the width-reading `GeometryReader` has a definite box. When
    /// there's no rain anywhere in the strip the precip row is dropped and the card shrinks to match, so
    /// a dry day doesn't reserve an empty band.
    private var contentHeight: CGFloat {
        // The row stack (hour + icon + degree) is ~71pt tall on the Watch; give it a bit more than
        // that so the temperature row breathes inside the card. The grid is centred in this box (see
        // `body`), so the extra slack splits evenly top and bottom rather than pooling at the bottom.
        let rows: CGFloat = size == .phone ? 100 : 80      // hour + icon + degree
        let precipRow: CGFloat = size == .phone ? 34 : 20
        return showPrecip ? rows + precipRow : rows
    }

    public var body: some View {
        AuraCard(size: size) {
            if scrolls {
                // Five columns fit the card width; the strip scrolls horizontally to the rest of the day.
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        // Centre the rows in the tall box so the slack in `contentHeight` sits equally
                        // above and below, keeping the card's top and bottom padding symmetric.
                        grid(columnWidth: geo.size.width / 5)
                            .frame(height: contentHeight)
                    }
                }
                .frame(height: contentHeight)
            } else {
                grid(columnWidth: nil, cap: 5)   // offline preview: the first five, spread to fill
                    .frame(height: contentHeight)
            }
        }
        .auraSectionTitle("Próximas horas".uppercased(), size)
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
                    Text("\(h.hour)h")
                        .font(.system(size: size.smallSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .colWidth(columnWidth)
                }
            }
            GridRow {
                ForEach(items) { h in
                    Image(systemName: WeatherIcon.symbol(forSky: h.sky))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: size.iconSize + 6))
                        .frame(minHeight: size.iconSize + 8)
                        .colWidth(columnWidth)
                }
            }
            GridRow {
                ForEach(items) { h in
                    Text(h.temp.map { "\($0)°" } ?? "—")
                        .font(.system(size: size.bodySize - 2, weight: .bold))
                        .foregroundStyle(Palette.temperature(h.temp))
                        .colWidth(columnWidth)
                }
            }
            if showPrecip {
                GridRow {
                    ForEach(items) { h in
                        Text(h.precipProb.map { $0 > 0 ? "\($0)%" : "" } ?? "")
                            .font(.system(size: size.smallSize - 1, weight: .semibold))
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
                            .frame(width: size == .phone ? 52 : 34, alignment: .leading)
                            .foregroundStyle(.white)
                        VStack(spacing: 1) {
                            Image(systemName: WeatherIcon.symbol(forSky: d.sky))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: size.iconSize))
                            // Always render the precip line (a blank space when there's no meaningful
                            // chance) so every day's row is exactly the same height, rain or not.
                            Text(d.probPrecip.map { $0 >= 10 ? "\($0)%" : " " } ?? " ")
                                .font(.system(size: size.smallSize - 2, weight: .semibold))
                                .foregroundStyle(auraPrecipColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: size == .phone ? 40 : 27)

                        Text(fmt(d.min)).foregroundStyle(Palette.temperature(d.min))
                            .frame(width: size == .phone ? 46 : 30, alignment: .trailing)
                        rangeBar(d)
                        Text(fmt(d.max)).fontWeight(.bold).foregroundStyle(Palette.temperature(d.max))
                            .frame(width: size == .phone ? 46 : 30, alignment: .leading)
                    }
                    .font(.system(size: size.bodySize - 1, weight: .medium))
                    .monospacedDigit()
                }
            }
        }
        .auraSectionTitle("Próximos días".uppercased(), size)
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
    private static func weekday(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "EEE"
        return f.string(from: date).capitalized
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
    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date()) {
        self.snapshot = snapshot; self.size = size; self.now = now
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
        guard let sr = sunrise, let ss = sunset, let len = Self.compact(from: sr, to: ss) else { return nil }
        var line = "\(len) de luz"
        if size == .phone, let dm = dayLengthDeltaMinutes {
            if dm > 0 { line += " · +\(dm) min que ayer" }
            else if dm < 0 { line += " · \(dm) min que ayer" }
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
        AuraCard(size: size) {
            if hasTimes {
                VStack(spacing: size == .phone ? 12 : 7) {
                    arc
                    ends
                    Text(readout)
                        .font(.system(size: size.smallSize + (size == .phone ? 1 : 0), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Solar noon (the arc's apex) and how long today's daylight runs — both from the same
                    // orto/ocaso, no new data. Noon is phone-only; the length line carries the
                    // day-over-day delta there too. Dimmer than the readout so it reads as secondary.
                    if size == .phone, let noon = solarNoon {
                        Text("Mediodía solar \(hhmm(noon))")
                            .font(.system(size: size.smallSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    if let line = dayLengthLine {
                        Text(line)
                            .font(.system(size: size.smallSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                }
            } else {
                Text("Horario solar no disponible")
                    .font(.system(size: size.bodySize - 2))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, size == .phone ? 10 : 6)
            }
        }
        .auraSectionTitle("Sol".uppercased(), size)
        // The arc is a drawn path — silent to VoiceOver. Collapse the whole card into one element and
        // speak the facts it encodes: orto, ocaso and the daylight-remaining readout.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sol")
        .accessibilityValue(a11yValue)
    }

    /// Spoken summary for VoiceOver: sunrise, sunset and the centre readout, or the unavailable notice.
    private var a11yValue: String {
        guard let sr = sunrise, let ss = sunset else { return "Horario solar no disponible" }
        var parts = ["Amanece a las \(hhmm(sr))", "anochece a las \(hhmm(ss))"]
        if let noon = solarNoon { parts.append("mediodía solar a las \(hhmm(noon))") }
        if let len = Self.compact(from: sr, to: ss) { parts.append("\(len) de luz") }
        var value = parts.joined(separator: ", ") + "."
        let r = readout
        if !r.isEmpty { value += " \(r)." }
        return value
    }

    // The arc itself: horizon line, the full day arc (faint), the travelled portion (warm), and the sun
    // glyph glowing at its live position. At night the whole arc dims and the sun rests at the horizon.
    private var arc: some View {
        let arcHeight: CGFloat = size == .phone ? 96 : 58
        let glyphR: CGFloat = size == .phone ? 12 : 7.5
        let night = !isDay
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let baseline = h - 1
            let rise = h - glyphR - 3
            let f = fraction
            let sun = CGPoint(x: f * w, y: baseline - sin(Double(f) * .pi) * Double(rise))
            ZStack {
                // Horizon.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: baseline))
                    p.addLine(to: CGPoint(x: w, y: baseline))
                }
                .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                // The full day arc, faint (dashed once the sun has passed / at night).
                Self.arcPath(w: w, baseline: baseline, rise: rise, from: 0, to: 1)
                    .stroke(.white.opacity(night ? 0.16 : 0.24),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))

                // The travelled portion, orto → now, in warm light (daytime only).
                if !night {
                    Self.arcPath(w: w, baseline: baseline, rise: rise, from: 0, to: f)
                        .stroke(
                            LinearGradient(colors: [Palette.tempOrange, Palette.tempYellow],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                // The sun: a soft glow under a solid disc. Muted and pale after dark.
                let core = night ? Color(white: 0.82) : Palette.tempYellow
                let glow = night ? Color(white: 0.6) : Palette.tempOrange
                Circle().fill(glow.opacity(night ? 0.35 : 0.6))
                    .frame(width: glyphR * 2.8, height: glyphR * 2.8)
                    .blur(radius: size == .phone ? 7 : 4)
                    .position(sun)
                Circle().fill(core)
                    .frame(width: glyphR * 2, height: glyphR * 2)
                    .position(sun)
            }
        }
        .frame(height: arcHeight)
        // Inset by the glyph radius so the sun disc sits fully inside the card at the orto/ocaso ends
        // (fraction 0 and 1) instead of half-clipping on the card edge.
        .padding(.horizontal, glyphR)
    }

    // Orto on the left, ocaso on the right, each with its icon and precise, location-based time.
    private var ends: some View {
        HStack(alignment: .top) {
            end(icon: "sunrise.fill", label: "Orto", time: sunrise)
            Spacer()
            end(icon: "sunset.fill", label: "Ocaso", time: sunset, trailing: true)
        }
    }

    private func end(icon: String, label: String, time: Date?, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: size.smallSize))
                    .foregroundStyle(Palette.tempOrange)
                Text(time.map(hhmm) ?? "—")
                    .font(.system(size: size.bodySize - (size == .phone ? 2 : 3), weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: size.smallSize - 2))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Centre line: daylight remaining while the sun is up, else the countdown to the next sunrise.
    private var readout: String {
        if isDay, let ss = sunset, let left = Self.compact(from: now, to: ss) {
            return "Quedan \(left) de luz"
        }
        // After dark: the snapshot only carries today's sunrise; sun times barely move day to day, so
        // this morning's orto stands in for tomorrow's — wrap the negative interval by 24 h.
        if let sr = sunrise, let until = Self.compact(from: now, to: sr, wrapDay: true) {
            return "Amanece en \(until)"
        }
        return ""
    }

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// A quadratic-looking arc sampled as a polyline: y follows sin(π·t) so it's flat at both horizons
    /// and highest at solar noon, matching `AuraSunPath`'s own altitude curve.
    private static func arcPath(w: CGFloat, baseline: CGFloat, rise: CGFloat,
                                from: CGFloat, to: CGFloat) -> Path {
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

    /// Compact "3 h 12" / "43 min". `wrapDay` adds 24 h to a negative span (tomorrow's sunrise).
    private static func compact(from: Date, to: Date, wrapDay: Bool = false) -> String? {
        var seconds = Int(to.timeIntervalSince(from))
        if wrapDay && seconds < 0 { seconds += 24 * 3600 }
        guard seconds > 0 else { return nil }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes)) min" : "\(minutes) min"
    }
}

// MARK: - Moon arc

/// The night twin of `AuraSunArcCard`. The moon rides from ocaso (left / east) to the next orto
/// (right / west) along the same shallow curve, sitting at its live position for the hour — mirroring the
/// dimmer moon `AuraSky` now draws after dark. Ocaso and orto anchor the two ends; the centre reads the
/// night still to come, or by day the countdown to the next ocaso while the moon rests at the horizon.
///
/// The moon's path is the night span (ocaso → next orto) — the very arc `AuraSunPath` follows after dark.
/// Like the sun card it re-anchors from `snapshot.sunrise/sunset` and the passed `now` at display time,
/// so an overnight-cached snapshot stays honest.
public struct AuraMoonArcCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    let now: Date
    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date()) {
        self.snapshot = snapshot; self.size = size; self.now = now
    }

    /// The current night's real boundaries — the ocaso that opened it and the orto that closes it —
    /// computed from the location's coordinates so the neighbouring day's 2–3 min sun-time drift is
    /// honoured: today's sunset is *not* last night's, nor tomorrow's. Falls back to the snapshot's own
    /// today times when coordinates are absent (snapshots cached before they were carried).
    private struct NightBounds { let ocaso: Date; let orto: Date }
    private var bounds: NightBounds? {
        if let lat = snapshot.latitude, let lon = snapshot.longitude {
            let today = SolarTimes(date: now, latitude: lat, longitude: lon)
            if let ss = today.sunset, let sr = today.sunrise {
                let day: TimeInterval = 24 * 3600
                if now >= ss {   // first half of the night: tonight's ocaso → tomorrow's orto
                    let orto = SolarTimes(date: now.addingTimeInterval(day), latitude: lat, longitude: lon).sunrise
                    return NightBounds(ocaso: ss, orto: orto ?? sr)
                }
                if now < sr {    // small hours: last night's ocaso → this morning's orto
                    let ocaso = SolarTimes(date: now.addingTimeInterval(-day), latitude: lat, longitude: lon).sunset
                    return NightBounds(ocaso: ocaso ?? ss, orto: sr)
                }
                return NightBounds(ocaso: ss, orto: sr)   // daytime edge (the card is night-gated)
            }
        }
        if let ss = snapshot.sunset, let sr = snapshot.sunrise { return NightBounds(ocaso: ss, orto: sr) }
        return nil
    }

    private var hasTimes: Bool { bounds != nil }
    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }

    /// 0 at ocaso → 1 at orto, clamped to the night span.
    private var fraction: CGFloat {
        guard let b = bounds, b.orto > b.ocaso else { return 0.5 }
        return clamp(CGFloat(now.timeIntervalSince(b.ocaso) / b.orto.timeIntervalSince(b.ocaso)))
    }

    public var body: some View {
        AuraCard(size: size) {
            if hasTimes {
                VStack(spacing: size == .phone ? 12 : 7) {
                    arc
                    ends
                    Text(readout)
                        .font(.system(size: size.smallSize + (size == .phone ? 1 : 0), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Text("Horario lunar no disponible")
                    .font(.system(size: size.bodySize - 2))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, size == .phone ? 10 : 6)
            }
        }
        .auraSectionTitle("Luna".uppercased(), size)
        // Same as the sun card: the drawn night arc is silent, so speak the ocaso/orto that bound the
        // night and the night-remaining readout as one collapsed element.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Luna")
        .accessibilityValue(a11yValue)
    }

    /// Spoken summary for VoiceOver: the night's opening ocaso, its closing orto and the centre readout.
    private var a11yValue: String {
        guard let b = bounds else { return "Horario lunar no disponible" }
        let r = readout
        return "Anochece a las \(hhmm(b.ocaso)), amanece a las \(hhmm(b.orto))." + (r.isEmpty ? "" : " \(r).")
    }

    // Horizon, the full night arc (faint), the travelled portion (cool moonlight, night only), and the
    // moon glyph at its live position. By day the arc dims and the moon rests at the ocaso horizon.
    private var arc: some View {
        let arcHeight: CGFloat = size == .phone ? 96 : 58
        let glyphR: CGFloat = size == .phone ? 12 : 7.5
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let baseline = h - 1
            let rise = h - glyphR - 3
            let f = fraction
            let moon = CGPoint(x: f * w, y: baseline - sin(Double(f) * .pi) * Double(rise))
            ZStack {
                // Horizon.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: baseline))
                    p.addLine(to: CGPoint(x: w, y: baseline))
                }
                .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                // The full night arc, faint.
                Self.arcPath(w: w, baseline: baseline, rise: rise, from: 0, to: 1)
                    .stroke(.white.opacity(0.24),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))

                // The travelled portion, ocaso → now, in cool moonlight.
                Self.arcPath(w: w, baseline: baseline, rise: rise, from: 0, to: f)
                    .stroke(
                        LinearGradient(colors: [Palette.tempBlue, Color(white: 0.95)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // The moon: a soft cool glow under a pale disc — dimmer and cooler than the sun.
                let core = Color(white: 0.92)
                let glow = Color(red: 0.66, green: 0.72, blue: 0.92)
                Circle().fill(glow.opacity(0.45))
                    .frame(width: glyphR * 2.8, height: glyphR * 2.8)
                    .blur(radius: size == .phone ? 7 : 4)
                    .position(moon)
                Circle().fill(core)
                    .frame(width: glyphR * 2, height: glyphR * 2)
                    .position(moon)
            }
        }
        .frame(height: arcHeight)
        // Inset by the glyph radius so the moon disc sits fully inside the card at the ocaso/orto ends.
        .padding(.horizontal, glyphR)
    }

    // Ocaso on the left (night begins), orto on the right (night ends) — each the real bounding event.
    private var ends: some View {
        HStack(alignment: .top) {
            end(icon: "sunset.fill", label: "Ocaso", time: bounds?.ocaso)
            Spacer()
            end(icon: "sunrise.fill", label: "Orto", time: bounds?.orto, trailing: true)
        }
    }

    private func end(icon: String, label: String, time: Date?, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: size.smallSize))
                    .foregroundStyle(Palette.tempBlue)
                Text(time.map(hhmm) ?? "—")
                    .font(.system(size: size.bodySize - (size == .phone ? 2 : 3), weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: size.smallSize - 2))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Centre line: the night still to come, orto (this night's end) minus now.
    private var readout: String {
        if let b = bounds, let until = Self.compact(from: now, to: b.orto) {
            return "Quedan \(until) de noche"
        }
        return ""
    }

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Same sin(π·t) polyline as the sun arc, so the moon's curve matches the sun's exactly.
    private static func arcPath(w: CGFloat, baseline: CGFloat, rise: CGFloat,
                                from: CGFloat, to: CGFloat) -> Path {
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

    /// Compact "3 h 12 min" / "43 min". `wrapDay` adds 24 h to a negative span (tomorrow's orto).
    private static func compact(from: Date, to: Date, wrapDay: Bool = false) -> String? {
        var seconds = Int(to.timeIntervalSince(from))
        if wrapDay && seconds < 0 { seconds += 24 * 3600 }
        guard seconds > 0 else { return nil }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes)) min" : "\(minutes) min"
    }
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
                        .font(.system(size: size.bodySize + (size == .phone ? 6 : 2), weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(directionText)
                        .font(.system(size: size.smallSize))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2).minimumScaleFactor(0.8)
                    if let gust = snapshot.windGust {
                        Text("Rachas \(gust) km/h")
                            .font(.system(size: size.smallSize, weight: .semibold))
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
                            .font(.system(size: size.bodySize + (size == .phone ? 3 : 0),
                                          weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: swatch, height: swatch)
                    .shadow(color: color.opacity(0.6), radius: 5)

                    VStack(alignment: .leading, spacing: size == .phone ? 3 : 1) {
                        Text(airQuality.categoryName)
                            .font(.system(size: size.bodySize - (size == .phone ? 1 : 3), weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.8)
                        Text(detail)
                            .font(.system(size: size.smallSize - 1))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    Spacer(minLength: 0)
                }

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
                .font(.system(size: size.smallSize - 2))
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
                .font(.system(size: size.smallSize - 1, weight: .medium))
                .foregroundStyle(.white.opacity(measured ? 0.7 : 0.35))
            Text(component?.valueText ?? "–")
                .font(.system(size: size.bodySize - 1, weight: .bold, design: .rounded))
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
    public init(uvIndex: UVIndex, hourly: [UVHourSlot] = [], now: Date = Date(), size: AuraSize) {
        self.uvIndex = uvIndex; self.hourly = hourly; self.now = now; self.size = size
    }

    public var body: some View {
        let color = Palette.uvIndex(uvIndex.value)
        let swatch: CGFloat = size == .phone ? 46 : 30
        // Today's daytime UV hours from CAMS — the per-hour granularity AEMET's daily-max lacks.
        let today = hourly.todaySlots(reference: now).filter { $0.uv > 0 }
        return AuraCard(size: size) {
            VStack(alignment: .leading, spacing: size == .phone ? 12 : 7) {
                HStack(spacing: size.stackSpacing) {
                    ZStack {
                        Circle().fill(color)
                        Text("\(uvIndex.value)")
                            .font(.system(size: size.bodySize + (size == .phone ? 3 : 0),
                                          weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: swatch, height: swatch)
                    .shadow(color: color.opacity(0.6), radius: 5)

                    VStack(alignment: .leading, spacing: size == .phone ? 3 : 1) {
                        HStack(spacing: 6) {
                            // The band's protection glyph — the same symbol the UV complication shows, so
                            // the card teaches what that icon means (its legend lives in the tap sheet).
                            Image(systemName: uvIndex.glyph)
                                .font(.system(size: size.bodySize - (size == .phone ? 1 : 3), weight: .semibold))
                                .foregroundStyle(color)
                            Text(uvIndex.bandName)
                                .font(.system(size: size.bodySize - (size == .phone ? 1 : 3), weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text(uvIndex.advice)
                            .font(.system(size: size.smallSize - 1))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    Spacer(minLength: 0)
                }

                // The hourly curve, only when CAMS data is present — the swatch above is AEMET's forecast
                // daily maximum, this is how the UV actually rises and falls through today, hour by hour.
                if today.count >= 3 {
                    UVHourStrip(today: today, nowSlot: hourly.current(at: now), size: size)
                }
            }
        }
        .auraDetail(size) { AuraUVSheet(uvIndex: uvIndex) }
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
                    Text("Ahora \(n.index)")
                        .foregroundStyle(.white)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                }
                if let p = peak {
                    Text("máx \(p.index) a las \(hour(p.date))h")
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: size.smallSize - (size == .phone ? 2 : 2), weight: .semibold))
            .lineLimit(1).minimumScaleFactor(0.7)

            // The actionable window from the same hourly series: when to actually protect yourself, i.e.
            // the stretch where the index sits at or above the WHO threshold of 3.
            if let w = protectionWindow {
                Text("Protégete de \(w.start)h a \(w.end)h")
                    .font(.system(size: size.smallSize - (size == .phone ? 2 : 2), weight: .semibold))
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
                        .font(.system(size: size.smallSize))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(rangeLine)
                        .font(.system(size: size.smallSize - 1))
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
            .font(.system(size: size.smallSize - 3, weight: .medium))
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
                    .font(.system(size: size.bodySize - (size == .phone ? 4 : 3), weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Text(item.source.displayName)
                        .font(.system(size: size.smallSize - 3, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Self.badgeColor(item.source), in: Capsule())
                    Text(Self.relative(from: item.date, now: now))
                        .font(.system(size: size.smallSize - 2))
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

    /// Tapped open, the card reveals the aviso's full text. Collapsed by default so the card stays a
    /// one-line glance until the user asks for more.
    @State private var expanded = false

    public var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: size == .phone ? 8 : 6) {
                HStack(spacing: size == .phone ? 9 : 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: size.iconSize))
                    Text(alert.phenomenon ?? alert.event)
                        .font(.system(size: size.bodySize - 1, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: size.bodySize - 3, weight: .semibold))
                        .opacity(0.85)
                }
                if expanded {
                    // The warning's full text: AEMET's own event title, the affected zone, and the window
                    // it is valid for. That is everything the aviso itself carries.
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alert.event)
                            .font(.system(size: size.bodySize - 2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let zone = alert.areaDesc, !zone.isEmpty {
                            Text(zone)
                                .font(.system(size: size.bodySize - 3, weight: .medium))
                                .opacity(0.9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let validity = validityText {
                            Text(validity)
                                .font(.system(size: size.bodySize - 3, weight: .medium))
                                .opacity(0.9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(size.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.alert(alert.level).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous)
            .strokeBorder(Palette.alert(alert.level).opacity(0.7), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityHint(expanded ? "Toca para contraer" : "Toca para ver el aviso completo")
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
                        .font(.system(size: size == .phone ? 18 : 14, weight: .semibold))
                        .foregroundStyle(Palette.tempOrange)
                }
                ForEach(Array(BulletinText.sentences(text).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: size == .phone ? 19 : 15))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .auraSectionTitle("Predicción".uppercased(), size)
    }
}
