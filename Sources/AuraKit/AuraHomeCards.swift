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
private struct HomeConditionBlock: View {
    let snapshot: WeatherSnapshot
    let now: Date
    var tempFont: Font = .system(size: 44, weight: .semibold, design: .rounded)

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
            if let text = snapshot.currentSkyText {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .skyText()
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

/// The location name, with an aviso pill when the province has an active warning.
private struct HomeLocationRow: View {
    let snapshot: WeatherSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Label(snapshot.localidad, systemImage: "location.fill")
                .font(.footnote).fontWeight(.semibold)
                .labelStyle(HomeTightLabel())
                .lineLimit(1)
                .skyText()
            Spacer(minLength: 4)
            if let alert = snapshot.alert {
                AvisoPill(level: alert.level)
            }
        }
    }
}

/// A small coloured pill flagging an active AEMET warning.
private struct AvisoPill: View {
    let level: WeatherAlert.Level

    var body: some View {
        Label("Aviso", systemImage: "exclamationmark.triangle.fill")
            .font(.caption2).fontWeight(.bold)
            .labelStyle(HomeTightLabel())
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Palette.alert(level), in: Capsule())
    }
}

/// One hour of the compact strip: hour, day/night glyph, temperature.
private struct HomeHourColumn: View {
    let hour: HourSlot

    var body: some View {
        VStack(spacing: 3) {
            Text("\(hour.hour)")
                .font(.caption2).skyText()
            ConditionGlyph(sky: hour.sky, isNight: (hour.sky ?? "").hasSuffix("n"))
                .font(.body)
                .frame(height: 20)
            Text(HomeFormat.temp(hour.temp))
                .font(.caption).fontWeight(.semibold).skyText()
        }
        .frame(maxWidth: .infinity)
    }
}

/// One day of the outlook row: weekday, daytime glyph, high over low.
private struct HomeDayColumn: View {
    let day: DaySnapshot

    var body: some View {
        VStack(spacing: 3) {
            Text(HomeFormat.weekday(day.date))
                .font(.caption2).skyText()
            ConditionGlyph(sky: day.sky, isNight: false)
                .font(.body)
                .frame(height: 20)
            Text(HomeFormat.temp(day.max))
                .font(.caption).fontWeight(.semibold).skyText()
            Text(HomeFormat.temp(day.min))
                .font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
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
            HomeLocationRow(snapshot: snapshot)
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
        VStack(alignment: .leading, spacing: 10) {
            HomeLocationRow(snapshot: snapshot)
            HomeConditionBlock(snapshot: snapshot, now: now)

            let hours = Array(snapshot.upcomingHours().prefix(5))
            if !hours.isEmpty {
                Divider().overlay(.white.opacity(0.25))
                HStack(spacing: 0) { ForEach(hours) { HomeHourColumn(hour: $0) } }
            }

            let days = Array(snapshot.days.prefix(5))
            if !days.isEmpty {
                Divider().overlay(.white.opacity(0.25))
                HStack(spacing: 0) { ForEach(days) { HomeDayColumn(day: $0) } }
            }

            Spacer(minLength: 0)
            Divider().overlay(.white.opacity(0.25))
            HomeSunFooter(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
