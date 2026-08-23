import SwiftUI

// Home Screen widgets (systemSmall / systemMedium / systemLarge). Unlike Aura's Lock Screen glances
// these render in full colour, so they lean on the shared Palette tints and sit over the live `AuraSky`
// the widget supplies as the container background — white text over the moving sky, matching the app's
// own cards. Every layout lives in AuraKit so the widget extension just picks one by family. The goal
// is a Home Screen glance rich enough to stand in for AEMET's own widget.

private enum HomeFormat {
    static func temp(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—°" }

    static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Short capitalised weekday, e.g. "Lun".
    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(3)).capitalized
    }
}

// MARK: - Shared pieces

/// White text with a soft shadow so it stays legible over any part of the sky (a pale noon or a dark
/// night). Applied to every value on the home cards.
private struct SkyText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
    }
}

private extension View {
    func skyText() -> some View { modifier(SkyText()) }
}

/// The current condition glyph + hero temperature + today's high/low, the block every size opens with.
/// When `location` is set the condition line reads "Localidad · condición" (with a pin and, if active,
/// an aviso pill) — the large card folds its place name in here to save a whole row.
private struct HomeConditionBlock: View {
    let snapshot: WeatherSnapshot
    let now: Date
    var tempFont: Font = .system(size: 44, weight: .semibold, design: .rounded)
    var location: String? = nil
    var alert: WeatherAlert? = nil

    /// The condition line's text — the place name folded in front of the sky word when `location` is set.
    private var conditionLine: String? {
        switch (location, snapshot.currentSkyText) {
        case let (loc?, text?): return "\(loc) · \(text)"
        case let (loc?, nil):   return loc
        case let (nil, text?):  return text
        case (nil, nil):        return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                ConditionGlyph(sky: snapshot.currentSky, isNight: snapshot.isNight(at: now))
                    .font(.title)
                Text(HomeFormat.temp(snapshot.heroTemp))
                    .font(tempFont)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .skyText()
            }
            if let conditionLine {
                HStack(spacing: 6) {
                    Label {
                        Text(conditionLine).lineLimit(1).minimumScaleFactor(0.8)
                    } icon: {
                        if location != nil { Image(systemName: "location.fill") }
                    }
                    .labelStyle(HomeTightLabel())
                    .font(.subheadline)
                    .skyText()
                    if let alert {
                        Spacer(minLength: 4)
                        AvisoPill(level: alert.level)
                    }
                }
            }
            HStack(spacing: 8) {
                Label(HomeFormat.temp(snapshot.tempMax), systemImage: "arrow.up")
                Label(HomeFormat.temp(snapshot.tempMin), systemImage: "arrow.down")
            }
            .font(.caption).fontWeight(.medium)
            .labelStyle(HomeTightLabel())
            .skyText()
        }
    }
}

/// The location name, with an aviso pill when the province has an active warning. On the tight 2×2
/// (`systemSmall`) tile, `compact` shrinks the place name a step and collapses the aviso to its bare
/// sign — the full "Aviso" pill crowded the row and pushed the location off the tile entirely.
private struct HomeLocationRow: View {
    let snapshot: WeatherSnapshot
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Label(snapshot.localidad, systemImage: "location.fill")
                .font(compact ? .caption : .footnote).fontWeight(.semibold)
                .labelStyle(HomeTightLabel())
                .lineLimit(1).minimumScaleFactor(0.8)
                .skyText()
            Spacer(minLength: 4)
            if let alert = snapshot.alert {
                AvisoPill(level: alert.level, iconOnly: compact)
            }
        }
    }
}

/// A small coloured pill flagging an active AEMET warning. `iconOnly` drops the word and the capsule for
/// the bare level-tinted sign, so the smallest tiles keep room for the place name beside it.
private struct AvisoPill: View {
    let level: WeatherAlert.Level
    var iconOnly: Bool = false

    var body: some View {
        if iconOnly {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(Palette.alert(level))
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
        } else {
            Label("Aviso", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2).fontWeight(.bold)
                .labelStyle(HomeTightLabel())
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Palette.alert(level), in: Capsule())
        }
    }
}

/// One hour of the compact strip: hour, day/night glyph, temperature.
private struct HomeHourColumn: View {
    let hour: HourSlot
    /// Bigger type and glyph for the iPad XL card, where the caption sizes read small against the estate.
    var large: Bool = false

    var body: some View {
        VStack(spacing: large ? 5 : 3) {
            Text("\(hour.hour)")
                .font(large ? .subheadline : .caption2).skyText()
            ConditionGlyph(sky: hour.sky, isNight: (hour.sky ?? "").hasSuffix("n"))
                .font(large ? .title3 : .body)
                .frame(height: large ? 26 : 20)
            Text(HomeFormat.temp(hour.temp))
                .font(large ? .body : .caption).fontWeight(.semibold).skyText()
        }
        .frame(maxWidth: .infinity)
    }
}

/// The multi-day outlook drawn as **rows** — weekday, glyph, low, a temperature band, high — the way
/// the app's own forecast list reads (and the way the widget mockups were approved). Each day's band is
/// inset to where that day's low→high sits within the whole range on show, so warmer days reach further
/// right, like Apple's own forecast.
private struct HomeDayList: View {
    let days: [DaySnapshot]
    /// Spread the rows to fill the available height (even vertical gaps) instead of stacking them tight at
    /// the top — used on the XL card's right column, which has the room to breathe.
    var fill: Bool = false
    /// Bigger type and a taller band, for the iPad XL card where the small caption sizes read cramped.
    var large: Bool = false

    /// The coolest low and warmest high across the shown days — the scale every band is drawn against.
    private var span: (min: Int, max: Int)? {
        guard let lo = days.compactMap(\.min).min(),
              let hi = days.compactMap(\.max).max(), hi > lo else { return nil }
        return (lo, hi)
    }

    var body: some View {
        if fill {
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                    HomeDayRow(day: day, span: span, large: large)
                    if idx < days.count - 1 { Spacer(minLength: 6) }
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 5) {
                ForEach(days) { HomeDayRow(day: $0, span: span, large: large) }
            }
        }
    }
}

/// One outlook row: weekday, condition glyph, low, the temperature band, high.
private struct HomeDayRow: View {
    let day: DaySnapshot
    let span: (min: Int, max: Int)?
    var large: Bool = false

    var body: some View {
        HStack(spacing: large ? 12 : 8) {
            Text(HomeFormat.weekday(day.date))
                .font(large ? .subheadline : .caption).fontWeight(.semibold)
                .frame(width: large ? 44 : 34, alignment: .leading)
                .skyText()
            ConditionGlyph(sky: day.sky, isNight: false)
                .font(large ? .body : .footnote)
                .frame(width: large ? 24 : 20)
            Text(HomeFormat.temp(day.min))
                .font(large ? .subheadline : .caption).foregroundStyle(.white.opacity(0.75))
                .frame(width: large ? 38 : 30, alignment: .trailing)
            TempBand(low: day.min, high: day.max, span: span)
                .frame(height: large ? 7 : 5)
                .frame(maxWidth: .infinity)
            Text(HomeFormat.temp(day.max))
                .font(large ? .subheadline : .caption).fontWeight(.semibold)
                .frame(width: large ? 38 : 30, alignment: .trailing)
                .skyText()
        }
    }
}

/// A day's temperature band: a capsule inset to that day's low→high on the shared weekly scale, filled
/// with that range's own colours from the same TVE/AEMET temperature scale the app's forecast card uses
/// (blue → green → yellow → orange → red), over a faint track. Falls back to a plain track when the
/// range can't be computed.
private struct TempBand: View {
    let low: Int?
    let high: Int?
    let span: (min: Int, max: Int)?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.20))
                if let span, span.max > span.min {
                    let total = CGFloat(span.max - span.min)
                    let lo = low ?? span.min, hi = high ?? span.max
                    let start = CGFloat(lo - span.min) / total
                    let end = CGFloat(hi - span.min) / total
                    Capsule()
                        .fill(LinearGradient(gradient: Palette.temperatureGradient(min: lo, max: hi),
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, w * (end - start)))
                        .offset(x: w * start)
                }
            }
        }
    }
}

/// The compact next-hours strip (up to five), or nothing when the snapshot is thin.
private struct HomeHourStrip: View {
    let snapshot: WeatherSnapshot
    var count: Int = 5

    var body: some View {
        let hours = Array(snapshot.upcomingHours().prefix(count))
        if !hours.isEmpty {
            HStack(spacing: 0) {
                ForEach(hours) { HomeHourColumn(hour: $0) }
            }
        }
    }
}

/// Amanecer / ocaso times plus a UV or air-quality chip, for the large card's footer.
private struct HomeSunFooter: View {
    let snapshot: WeatherSnapshot

    var body: some View {
        HStack(spacing: 12) {
            if let sr = snapshot.sunrise {
                Label(HomeFormat.hhmm(sr), systemImage: "sunrise.fill")
                    .labelStyle(HomeTightLabel())
            }
            if let ss = snapshot.sunset {
                Label(HomeFormat.hhmm(ss), systemImage: "sunset.fill")
                    .labelStyle(HomeTightLabel())
            }
            Spacer(minLength: 4)
            extra
        }
        .font(.caption).fontWeight(.medium)
        .skyText()
    }

    /// UV takes the slot when present (a sunny-day figure), else the air-quality index.
    @ViewBuilder private var extra: some View {
        if let uv = snapshot.uvIndex {
            Label("UV \(uv.value)", systemImage: uv.glyph)
                .labelStyle(HomeTightLabel())
        } else if let air = snapshot.airQuality {
            Label("ICA \(air.category)", systemImage: "aqi.medium")
                .labelStyle(HomeTightLabel())
        }
    }
}

/// The next celestial event on one line — its glyph and precise time. It tracks the **sun** (sunrise or
/// sunset, whichever is next), which after dark is the upcoming sunrise; moonrise/moonset would need
/// lunar ephemeris the snapshot doesn't carry yet, so the moon isn't shown. Empty when sun times are
/// unknown. Used on the XL card's hero column.
private struct HomeNextEventLine: View {
    let snapshot: WeatherSnapshot
    let now: Date

    private var event: (date: Date, icon: String)? {
        switch snapshot.nextSunEvent(now: now) {
        case .sunrise(let d): return (d, "sunrise.fill")
        case .sunset(let d):  return (d, "sunset.fill")
        case nil:             return nil
        }
    }

    var body: some View {
        if let event {
            Label(HomeFormat.hhmm(event.date), systemImage: event.icon)
                .labelStyle(HomeTightLabel())
                .font(.caption).fontWeight(.medium)
                .skyText()
        }
    }
}

/// A compact row of the current secondary metrics — precip chance, humidity, wind (and UV on the
/// larger cards). Each chip appears only when its datum is present, so a thin snapshot just shows fewer.
private struct HomeMetricsRow: View {
    let snapshot: WeatherSnapshot
    var showUV: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let precip = snapshot.currentPrecipProb {
                Label("\(precip)%", systemImage: "umbrella.fill")
                    .labelStyle(HomeTightLabel())
            }
            if let humidity = snapshot.currentHumidity {
                Label("\(humidity)%", systemImage: "humidity.fill")
                    .labelStyle(HomeTightLabel())
            }
            if let speed = snapshot.windSpeed {
                Label(wind(speed), systemImage: "wind")
                    .labelStyle(HomeTightLabel())
            }
            if showUV, let uv = snapshot.uvIndex {
                Label("UV \(uv.value)", systemImage: uv.glyph)
                    .labelStyle(HomeTightLabel())
            }
        }
        .font(.caption).fontWeight(.medium)
        .skyText()
    }

    private func wind(_ speed: Int) -> String {
        if let dir = snapshot.windDirection { return "\(speed) \(dir.abbreviation)" }
        return "\(speed)"
    }
}

/// A label whose icon sits snug against its title — the home cards' compact rows.
private struct HomeTightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Small

/// `.systemSmall`: location, current condition, hero temperature, today's high/low.
public struct AuraHomeSmall: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLocationRow(snapshot: snapshot, compact: true)
            Spacer(minLength: 0)
            HomeConditionBlock(snapshot: snapshot, now: now)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

/// `.systemMedium`: the small card's block on the left, a five-hour strip on the right.
public struct AuraHomeMedium: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLocationRow(snapshot: snapshot)
            HStack(alignment: .center, spacing: 12) {
                HomeConditionBlock(snapshot: snapshot, now: now,
                                   tempFont: .system(size: 40, weight: .semibold, design: .rounded))
                    .layoutPriority(1)
                HomeHourStrip(snapshot: snapshot)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Large

/// `.systemLarge`: the condition block and hour strip, a five-day outlook, and a sun-times footer with
/// UV or air quality — the full glance meant to replace AEMET's own Home Screen widget.
public struct AuraHomeLarge: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The place name rides the condition line here (not its own row) so the card breathes.
            HomeConditionBlock(snapshot: snapshot, now: now,
                               location: snapshot.localidad, alert: snapshot.alert)
            HomeMetricsRow(snapshot: snapshot)

            let hours = Array(snapshot.upcomingHours().prefix(5))
            if !hours.isEmpty {
                Divider().overlay(.white.opacity(0.25))
                HStack(spacing: 0) { ForEach(hours) { HomeHourColumn(hour: $0) } }
            }

            // Three day rows (not four): with the outlook drawn as full rows the large card also carries
            // the hour strip and the sun footer, and a fourth row pushed the footer off the bottom edge.
            let days = Array(snapshot.days.prefix(3))
            if !days.isEmpty {
                Divider().overlay(.white.opacity(0.25))
                HomeDayList(days: days)
            }

            Spacer(minLength: 0)
            Divider().overlay(.white.opacity(0.25))
            HomeSunFooter(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Extra Large (iPad / macOS)

/// `.systemExtraLarge` (iPad and macOS only): the hero on the left — location, condition block, a
/// one-line forecast description for the current time, and the key metrics — with próximas horas over
/// próximos días filling the right. Aura's richest glance, sized for the iPad Home Screen.
public struct AuraHomeXL: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HomeLocationRow(snapshot: snapshot)
                    Spacer(minLength: 0)
                    HomeConditionBlock(snapshot: snapshot, now: now,
                                       tempFont: .system(size: 52, weight: .semibold, design: .rounded))
                    Text(ForecastPhrase.headline(for: snapshot, now: now))
                        .font(.subheadline)
                        .lineLimit(2).minimumScaleFactor(0.85)
                        .skyText()
                    HomeMetricsRow(snapshot: snapshot, showUV: true)
                    // The next sunrise/sunset — the "when does the light change" line the hero column lacked.
                    HomeNextEventLine(snapshot: snapshot, now: now)
                }
                .frame(width: geo.size.width * 0.37, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    let hours = Array(snapshot.upcomingHours().prefix(7))
                    let days = Array(snapshot.days.prefix(4))
                    // Hours ride the top in their own larger strip; the days fill the rest of the column,
                    // spread to reach the bottom edge instead of clustering under the hours with dead space
                    // below — the XL has estate to spare on the right (the "use the room" report).
                    if !hours.isEmpty {
                        HStack(spacing: 0) { ForEach(hours) { HomeHourColumn(hour: $0, large: true) } }
                    }
                    if !days.isEmpty {
                        HomeDayList(days: days, fill: true, large: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Empty state

/// Shown on a Home Screen widget before the app has cached anything.
public struct AuraHomeEmpty: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.largeTitle)
            Text("Abre Aura")
                .font(.headline).skyText()
            Text("para ver el tiempo aquí")
                .font(.caption).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
