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
    var heroTemp: CGFloat     { self == .phone ? 74 : 42 }
    var heroIcon: CGFloat     { self == .phone ? 62 : 30 }
    var titleSize: CGFloat    { self == .phone ? 14 : 10 }
    var bodySize: CGFloat     { self == .phone ? 19 : 13 }
    var smallSize: CGFloat    { self == .phone ? 15 : 10 }
    var iconSize: CGFloat     { self == .phone ? 24 : 16 }
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: size.cardCorner, style: .continuous))
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

    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date(), hoursScroll: Bool = true) {
        self.snapshot = snapshot
        self.size = size
        self.now = now
        self.hoursScroll = hoursScroll
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: size.stackSpacing) {
            AuraHeroCard(snapshot: snapshot, size: size, now: now)
            if let alert = snapshot.alert { AuraAlertCard(alert: alert, size: size) }
            if !snapshot.hours.isEmpty {
                AuraHourlyCard(hours: snapshot.hours, size: size, scrolls: hoursScroll)
            }
            if !snapshot.days.isEmpty { AuraDailyCard(days: snapshot.days, size: size) }
            AuraSunWindCard(snapshot: snapshot, size: size, now: now)
            if let bulletin = snapshot.bulletin, !bulletin.isEmpty {
                AuraBulletinCard(phenomenon: snapshot.bulletinPhenomenon, text: bulletin, size: size)
            }
            Text("Elaborado con datos de AEMET")
                .font(.system(size: size == .phone ? 11 : 9))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
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
                        if let sky = snapshot.currentSkyText {
                            Text(sky)
                                .font(.system(size: size.bodySize, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: size == .phone ? 8 : 4) {
                        Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky,
                                                             isNight: snapshot.isNight(at: now)))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: size.heroIcon))
                        Text("Máx \(fmt(snapshot.tempMax))").foregroundStyle(Palette.temperature(snapshot.tempMax))
                        Text("Mín \(fmt(snapshot.tempMin))").foregroundStyle(Palette.temperature(snapshot.tempMin))
                    }
                    .font(.system(size: size.bodySize - 1, weight: .semibold))
                    .monospacedDigit()
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
                .font(.system(size: size.smallSize, weight: .semibold))
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

    /// Fixed height for the four stacked rows, so the width-reading `GeometryReader` has a definite box.
    private var contentHeight: CGFloat { size == .phone ? 134 : 86 }

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
                            .frame(width: size == .phone ? 46 : 30, alignment: .leading)
                            .foregroundStyle(.white)
                        VStack(spacing: 1) {
                            Image(systemName: WeatherIcon.symbol(forSky: d.sky))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: size.iconSize))
                            if let p = d.probPrecip, p >= 10 {
                                Text("\(p)%")
                                    .font(.system(size: size.smallSize - 2, weight: .semibold))
                                    .foregroundStyle(auraPrecipColor)
                            }
                        }
                        .frame(width: size == .phone ? 30 : 20)

                        Text(fmt(d.min)).foregroundStyle(Palette.temperature(d.min))
                            .frame(width: size == .phone ? 40 : 26, alignment: .trailing)
                        rangeBar(d)
                        Text(fmt(d.max)).fontWeight(.bold).foregroundStyle(Palette.temperature(d.max))
                            .frame(width: size == .phone ? 40 : 26, alignment: .leading)
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

// MARK: - Sun & wind

public struct AuraSunWindCard: View {
    let snapshot: WeatherSnapshot
    let size: AuraSize
    let now: Date
    public init(snapshot: WeatherSnapshot, size: AuraSize, now: Date = Date()) {
        self.snapshot = snapshot; self.size = size; self.now = now
    }

    public var body: some View {
        HStack(spacing: size.stackSpacing) {
            AuraCard(size: size) {
                cell(icon: "wind",
                     value: snapshot.windSpeed.map { "\($0) km/h" } ?? "—",
                     detail: snapshot.windDirection?.abbreviation,
                     tint: Palette.tempTeal)
            }
            AuraCard(size: size) {
                if let event = snapshot.nextSunEvent(now: now) {
                    switch event {
                    case .sunrise(let d):
                        cell(icon: "sunrise.fill", value: hhmm(d), detail: "Orto", tint: Palette.tempOrange)
                    case .sunset(let d):
                        cell(icon: "sunset.fill", value: hhmm(d), detail: "Ocaso", tint: Palette.tempOrange)
                    }
                } else {
                    cell(icon: "sun.max.fill", value: "—", detail: nil, tint: Palette.tempOrange)
                }
            }
        }
    }

    private func cell(icon: String, value: String, detail: String?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: size == .phone ? 4 : 2) {
            Image(systemName: icon).font(.system(size: size.iconSize)).foregroundStyle(tint)
            Text(value).font(.system(size: size.bodySize, weight: .semibold)).foregroundStyle(.white)
            if let detail {
                Text(detail).font(.system(size: size.smallSize)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "HH:mm"
        return f.string(from: date)
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
            VStack(alignment: .leading, spacing: size == .phone ? 6 : 4) {
                if let phenomenon {
                    Label(phenomenon, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: size.smallSize, weight: .medium))
                        .foregroundStyle(Palette.tempOrange)
                }
                ForEach(Array(BulletinText.sentences(text).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: size.smallSize + 0.5))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .auraSectionTitle("Predicción".uppercased(), size)
    }
}
