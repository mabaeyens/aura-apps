import SwiftUI

// Home Screen widgets (systemSmall / systemMedium / systemLarge). Unlike Aura's Lock Screen glances
// these render in full colour, so they lean on the shared Palette tints and sit over the live `AuraSky`
// the widget supplies as the container background — white text over the moving sky, matching the app's
// own cards. Every layout lives in AuraKit so the widget extension just picks one by family. The goal
// is a Home Screen glance rich enough to stand in for AEMET's own widget.

private enum HomeFormat {
    static func temp(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—°" }

    static func hhmm(_ date: Date) -> String { AuraTime.hhmm(date) }

    /// Short capitalised weekday, e.g. "Lun". Shared cached formatter (see `AuraTime`).
    static func weekday(_ date: Date) -> String { AuraTime.shortWeekday(date) }
}

// MARK: - Shared pieces

/// White text with a soft shadow so it stays legible over any part of the sky (a pale noon or a dark
/// night). Applied to every value on the home cards.
private struct SkyText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            // A firmer halo than a hairline shadow: white values have to stay legible over the palest
            // part of the sky too (a near-white noon on the XL card), not just a mid-blue. A tight halo
            // for edge definition, plus a wider soft one that builds a broader dark cushion under the
            // text on a near-white sky — the worst contrast case — without weighing it down on dark skies.
            .shadow(color: .black.opacity(0.45), radius: 2, y: 0.5)
            .shadow(color: .black.opacity(0.28), radius: 9, y: 1)
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
    /// The condition glyph's size. Shrunk on the medium card so the hero block stays narrow and the
    /// hour strip beside it keeps its room.
    var glyphFont: Font = .title
    /// How many lines the condition line may wrap to before it truncates. The medium card allows two so
    /// a long sky phrase ("Muy nuboso con lluvia escasa") reads in full instead of being cut mid-word.
    var conditionLineLimit: Int = 1
    /// Whether the block draws its own high/low row. The large card turns this off and folds the
    /// high/low into a single metrics row alongside rain/humidity/wind.
    var showHighLow: Bool = true
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
                    .font(glyphFont)
                Text(HomeFormat.temp(snapshot.heroTemp))
                    .font(tempFont)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .skyText()
            }
            if let conditionLine {
                HStack(spacing: 6) {
                    Label {
                        Text(conditionLine).lineLimit(conditionLineLimit).minimumScaleFactor(0.8)
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
            if showHighLow {
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
}

/// The location name, with an aviso pill when the province has an active warning. On the tight 2×2
/// (`systemSmall`) tile, `compact` shrinks the place name a step and collapses the aviso to its bare
/// sign — the full "Aviso" pill crowded the row and pushed the location off the tile entirely.
private struct HomeLocationRow: View {
    let snapshot: WeatherSnapshot
    var now: Date = Date()
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Label(snapshot.localidad, systemImage: "location.fill")
                .font(compact ? .caption : .footnote).fontWeight(.semibold)
                .labelStyle(HomeTightLabel())
                .lineLimit(1).minimumScaleFactor(0.8)
                .skyText()
            Spacer(minLength: 4)
            if let alert = snapshot.activeAlert(at: now) {
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
            // A fixed slot gives every condition the same point size and footprint, so a wide rain cloud
            // no longer renders taller than a sun — which was leaving the columns at unequal heights and
            // knocking the hour/temperature rows out of line across the strip.
            ConditionGlyph(sky: hour.sky, isNight: (hour.sky ?? "").hasSuffix("n"),
                           slot: large ? 20 : 15)
            Text(HomeFormat.temp(hour.temp))
                .font(large ? .body : .caption2).fontWeight(.semibold).skyText()
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
    /// Bigger type and a taller band, for the iPad XL card where the small caption sizes read cramped.
    var large: Bool = false

    /// The coolest low and warmest high across the shown days — the scale every band is drawn against.
    private var span: (min: Int, max: Int)? {
        guard let lo = days.compactMap(\.min).min(),
              let hi = days.compactMap(\.max).max(), hi > lo else { return nil }
        return (lo, hi)
    }

    var body: some View {
        // Rows breathe (a wider gap on the XL, where the small spacing read cramped) but stay a tight
        // group, so the block reads as one distinct area.
        VStack(spacing: large ? 12 : 5) {
            ForEach(days) { HomeDayRow(day: $0, span: span, large: large) }
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
            // A fixed glyph slot gives every row the same height, so a tall rain cloud no longer makes
            // its row deeper than a sun row and throws the vertical rhythm off (Lun sitting nearer Mar
            // than Mar to Mié).
            ConditionGlyph(sky: day.sky, isNight: false, slot: large ? 17 : 13)
            // Low and high share one size and weight — same font, same semibold — so the pair reads as a
            // matched set rather than a bold high beside a lighter low. The band between them carries the
            // hierarchy; the numbers don't need to.
            Text(HomeFormat.temp(day.min))
                .font(large ? .subheadline : .caption).fontWeight(.semibold).skyText()
                .frame(width: large ? 42 : 34, alignment: .trailing)
            // A trailing inset shortens the band so the high value on the right always has room to show
            // in full (a wide band was clipping "28°" to "2…").
            TempBand(low: day.min, high: day.max, span: span)
                .frame(height: large ? 7 : 5)
                .frame(maxWidth: .infinity)
                .padding(.trailing, large ? 8 : 5)
            Text(HomeFormat.temp(day.max))
                .font(large ? .subheadline : .caption).fontWeight(.semibold)
                .frame(width: large ? 42 : 34, alignment: .trailing)
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
    /// Show the UV index alongside the sun event, so the XL hero's foot reads "próximo sol · UV" on one
    /// line instead of carrying UV up in the metrics row.
    var showUV: Bool = false

    private var event: (date: Date, icon: String)? {
        switch snapshot.nextSunEvent(now: now) {
        case .sunrise(let d): return (d, "sunrise.fill")
        case .sunset(let d):  return (d, "sunset.fill")
        case nil:             return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let event {
                Label(HomeFormat.hhmm(event.date), systemImage: event.icon)
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
}

/// A compact row of the current secondary metrics — precip chance, humidity, wind (and UV on the
/// larger cards). Each chip appears only when its datum is present, so a thin snapshot just shows fewer.
private struct HomeMetricsRow: View {
    let snapshot: WeatherSnapshot
    var showUV: Bool = false
    /// Prepend today's high/low to the row so the large card carries max, min, rain, humidity and wind
    /// on a single line (no separate high/low row, no dividers between the blocks).
    var leadingHighLow: Bool = false

    var body: some View {
        HStack(spacing: leadingHighLow ? 9 : 12) {
            if leadingHighLow {
                Label(HomeFormat.temp(snapshot.tempMax), systemImage: "arrow.up")
                    .labelStyle(HomeTightLabel())
                Label(HomeFormat.temp(snapshot.tempMin), systemImage: "arrow.down")
                    .labelStyle(HomeTightLabel())
            }
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
        .lineLimit(1)
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
            HomeLocationRow(snapshot: snapshot, now: now, compact: true)
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
            HomeLocationRow(snapshot: snapshot, now: now)
            HStack(alignment: .top, spacing: 10) {
                // A smaller hero glyph and temperature keep the left block narrow, so the two-line
                // condition phrase reads in full and the hour strip beside it stops crowding.
                HomeConditionBlock(snapshot: snapshot, now: now,
                                   tempFont: .system(size: 34, weight: .semibold, design: .rounded),
                                   glyphFont: .title3,
                                   conditionLineLimit: 2)
                    .layoutPriority(1)
                // Four hours, not five: a fifth column crowds the strip on the medium width. Pinned to
                // the top (not centred) so the temperature row rides up level with the hero and doesn't
                // sit down over the condition line beside it.
                HomeHourStrip(snapshot: snapshot, count: 4)
            }
            .frame(maxHeight: .infinity)
            AuraStalenessNote(snapshot: snapshot, now: now)
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
        VStack(alignment: .leading, spacing: 10) {
            // The place name rides the condition line here (not its own row) so the card breathes. The
            // block's own high/low row is folded into the metrics line below, so max, min, rain, humidity
            // and wind all sit together on one row. The aviso is not an inline pill here — it sits as a
            // bare sign in the card's top-right corner (see the overlay below).
            HomeConditionBlock(snapshot: snapshot, now: now, showHighLow: false,
                               location: snapshot.localidad)
            HomeMetricsRow(snapshot: snapshot, leadingHighLow: true)

            // No dividers between the blocks — open spacing separates them instead.
            let hours = Array(snapshot.upcomingHours().prefix(5))
            if !hours.isEmpty {
                HStack(spacing: 0) { ForEach(hours) { HomeHourColumn(hour: $0) } }
            }

            // Three day rows (not four): with the outlook drawn as full rows the large card also carries
            // the hour strip and the sun footer, and a fourth row pushed the footer off the bottom edge.
            // Equal spacers above and below centre the outlook in the gap between the hour strip and the
            // sun/UV footer, so it sits evenly rather than crowding up under the hours.
            let days = Array(snapshot.days.prefix(3))
            Spacer(minLength: 0)
            if !days.isEmpty {
                HomeDayList(days: days)
            }
            Spacer(minLength: 0)
            HomeSunFooter(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // The aviso as a bare level-tinted sign in the top-right corner, clear of the temperature and
        // condition line, with a little padding off the edge.
        .overlay(alignment: .topTrailing) {
            if let alert = snapshot.activeAlert(at: now) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(Palette.alert(alert.level))
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                    .padding(.top, 2).padding(.trailing, 2)
            }
        }
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
                    HomeLocationRow(snapshot: snapshot, now: now)
                    Spacer(minLength: 0)
                    HomeConditionBlock(snapshot: snapshot, now: now,
                                       tempFont: .system(size: 52, weight: .semibold, design: .rounded))
                    Text(ForecastPhrase.headline(for: snapshot, now: now))
                        .font(.subheadline)
                        .lineLimit(2).minimumScaleFactor(0.85)
                        .skyText()
                    HomeMetricsRow(snapshot: snapshot)
                    // The next sunrise/sunset — the "when does the light change" line — with the day's UV
                    // index sitting alongside it rather than up in the metrics row.
                    HomeNextEventLine(snapshot: snapshot, now: now, showUV: true)
                }
                .frame(width: geo.size.width * 0.37, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    let hours = Array(snapshot.upcomingHours().prefix(7))
                    let days = Array(snapshot.days.prefix(4))
                    // Two distinct blocks — próximas horas, then próximos días — set apart by open sky, not
                    // a divider. Three equal spacers distribute the whitespace evenly, so the hours sit
                    // balanced between the top and the day block rather than crowded up under the top edge.
                    Spacer(minLength: 12)
                    if !hours.isEmpty {
                        HStack(spacing: 0) { ForEach(hours) { HomeHourColumn(hour: $0, large: true) } }
                    }
                    Spacer(minLength: 12)
                    if !days.isEmpty {
                        HomeDayList(days: days, large: true)
                    }
                    Spacer(minLength: 12)
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
