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

    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date(),
                hoursScroll: Bool = true, radar: AuraRadarInfo? = nil, news: [NewsItem] = []) {
        self.snapshot = snapshot
        self.size = size
        self.now = now
        self.hoursScroll = hoursScroll
        self.radar = radar
        self.news = news
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: size.stackSpacing) {
            AuraHeroCard(snapshot: snapshot, size: size, now: now)
            if let alert = snapshot.alert { AuraAlertCard(alert: alert, size: size) }
            // Re-anchor the strip to the real current hour: a snapshot served from cache must still
            // start at "now", not at the hour it was built.
            let upcoming = snapshot.upcomingHours(now: now)
            if !upcoming.isEmpty {
                AuraHourlyCard(hours: upcoming, size: size, scrolls: hoursScroll)
            }
            if !snapshot.days.isEmpty { AuraDailyCard(days: snapshot.days, size: size) }
            AuraSunArcCard(snapshot: snapshot, size: size, now: now)
            AuraWindCard(snapshot: snapshot, size: size)
            if let airQuality = snapshot.airQuality {
                AuraAirQualityCard(airQuality: airQuality, size: size)
            }
            if let uvIndex = snapshot.uvIndex {
                AuraUVCard(uvIndex: uvIndex, size: size)
            }
            if let radar { AuraRadarCard(radar: radar, size: size, now: now) }
            if let bulletin = snapshot.bulletin, !bulletin.isEmpty {
                AuraBulletinCard(phenomenon: snapshot.bulletinPhenomenon, text: bulletin, size: size)
            }
            if !news.isEmpty { AuraNewsCard(items: news, size: size, now: now) }
            // MITECO is credited alongside AEMET whenever the air-quality card is present (its ICA feed
            // is CC-BY 4.0, which requires attribution); AEMET alone otherwise.
            Text(snapshot.airQuality == nil ? "Elaborado con datos de AEMET"
                                            : "Elaborado con datos de AEMET y MITECO")
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

    public var body: some View {
        AuraCard(size: size) {
            VStack(alignment: .leading, spacing: size == .phone ? 12 : 6) {
                // Top: temperature + condition on the left, a big condition icon and today's range on
                // the right, so the card fills its width instead of leaving the right half blank.
                HStack(alignment: .top, spacing: size == .phone ? 12 : 6) {
                    VStack(alignment: .leading, spacing: size == .phone ? 2 : 1) {
                        Text(snapshot.localidad)
                            .font(.system(size: size.bodySize, weight: .semibold))
                            .foregroundStyle(.white).lineLimit(1)
                        Text(snapshot.heroTemp.map { "\($0)°" } ?? "—")
                            .font(.system(size: size.heroTemp, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let sky = snapshot.currentSkyText {
                            Text(sky)
                                .font(.system(size: size.bodySize, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                        }
                    }
                    .layoutPriority(1)   // the temperature keeps its width; the range column yields first
                    Spacer(minLength: 4)
                    // Icon pinned to the top, Máx/Mín pushed to the bottom, so the right column spans the
                    // full height of the tall temperature instead of clustering up top and leaving a gap.
                    VStack(alignment: .trailing, spacing: size == .phone ? 6 : 3) {
                        Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky,
                                                             isNight: snapshot.isNight(at: now)))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: size.heroIcon))
                        // On the wide phone hero, push the range to the bottom so the column spans the
                        // full height of the tall temperature. The narrow Watch keeps them clustered.
                        if size == .phone { Spacer(minLength: 8) }
                        Text("Máx \(fmt(snapshot.tempMax))").foregroundStyle(Palette.temperature(snapshot.tempMax))
                        Text("Mín \(fmt(snapshot.tempMin))").foregroundStyle(Palette.temperature(snapshot.tempMin))
                    }
                    .font(.system(size: size.bodySize + 2, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxHeight: size == .phone ? .infinity : nil, alignment: .top)
                }

                // Wind gets its own full-width row so the speed *and* direction always fit; humidity and
                // rain share the row beneath, each taking half the width so nothing crowds or truncates.
                VStack(alignment: .leading, spacing: size == .phone ? 8 : 4) {
                    if let wind = snapshot.windSpeed {
                        metric("wind", "\(wind) km/h\(snapshot.windDirection.map { " " + $0.abbreviation } ?? "")",
                               .white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: size == .phone ? 12 : 6) {
                        if let h = snapshot.currentHumidity {
                            metric("humidity.fill", "\(h)%", Palette.tempTeal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let p = snapshot.currentPrecipProb, p > 0 {
                            metric("umbrella.fill", "\(p)%", auraPrecipColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .font(.system(size: size.bodySize, weight: .semibold))
            }
        }
    }

    private func metric(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 5) { Image(systemName: icon); Text(text) }.foregroundStyle(tint)
    }
    private func fmt(_ v: Int?) -> String { v.map { "\($0)°" } ?? "—" }
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
        let rows: CGFloat = size == .phone ? 100 : 66      // hour + icon + degree
        let precipRow: CGFloat = size == .phone ? 34 : 20
        return showPrecip ? rows + precipRow : rows
    }

    public var body: some View {
        AuraCard(size: size) {
            if scrolls {
                // Five columns fit the card width; the strip scrolls horizontally to the rest of the day.
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        grid(columnWidth: geo.size.width / 5)
                    }
                }
                .frame(height: contentHeight)
            } else {
                grid(columnWidth: nil, cap: 5)   // offline preview: the first five, spread to fill
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
    let size: AuraSize
    public init(uvIndex: UVIndex, size: AuraSize) {
        self.uvIndex = uvIndex; self.size = size
    }

    public var body: some View {
        let color = Palette.uvIndex(uvIndex.value)
        let swatch: CGFloat = size == .phone ? 46 : 30
        return AuraCard(size: size) {
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
                    Text(uvIndex.bandName)
                        .font(.system(size: size.bodySize - (size == .phone ? 1 : 3), weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(uvIndex.advice)
                        .font(.system(size: size.smallSize - 1))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                Spacer(minLength: 0)
            }
        }
        .auraDetail(size) { AuraUVSheet(uvIndex: uvIndex) }
        .auraSectionTitle("Índice UV".uppercased(), size)
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
                Text(subtitle)
                    .font(.system(size: size.smallSize))
                    .foregroundStyle(.white.opacity(0.65))
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

    public var body: some View {
        HStack(spacing: size == .phone ? 9 : 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: size.iconSize))
            Text(alert.phenomenon ?? alert.event)
                .font(.system(size: size.bodySize - 1, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(size.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.alert(alert.level).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous)
            .strokeBorder(Palette.alert(alert.level).opacity(0.7), lineWidth: 0.5))
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
