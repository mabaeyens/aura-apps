import SwiftUI

// These SwiftUI cards live in AuraKit so the app and the widget extension render from identical
// code (per the plan). They take a plain `WeatherSnapshot` and know nothing about WidgetKit; the
// extension wraps them in the widget families, and the app can preview them directly.

// MARK: - Small

/// systemSmall: location + condition, the current temperature as the hero, and today's range.
public struct AuraCardSmall: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text(snapshot.localidad)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let alert = snapshot.alert { AlertBadge(level: alert.level) }
                ConditionIcon(sky: snapshot.currentSky).font(.title3)
            }

            Spacer(minLength: 0)

            Text(WidgetFormat.heroTemp(snapshot))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
            Text(WidgetFormat.range(snapshot))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

/// systemMedium: hero + condition on top, the hourly strip filling the bottom.
public struct AuraCardMedium: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if let alert = snapshot.alert { AlertBadge(level: alert.level) }
                        Text(snapshot.localidad)
                            .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                    }
                    Text(WidgetFormat.heroTemp(snapshot))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.7)
                    Text(WidgetFormat.range(snapshot))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    ConditionIcon(sky: snapshot.currentSky).font(.largeTitle)
                    if let text = snapshot.currentSkyText {
                        Text(text).font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }

            if !snapshot.hours.isEmpty {
                Spacer(minLength: 0)
                HourlyStrip(hours: Array(snapshot.hours.prefix(5)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Large

/// systemLarge: header, hero row, hourly strip, then the multi-day list. (Avisos: Phase 2.5.)
public struct AuraCardLarge: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.localidad)
                    .font(.title3).fontWeight(.semibold).lineLimit(1)
                Spacer()
                Text("Actualizado \(WidgetFormat.time(snapshot.updated))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if let alert = snapshot.alert {
                AlertBanner(alert: alert)
            }

            HStack(alignment: .center, spacing: 14) {
                ConditionIcon(sky: snapshot.currentSky)
                    .font(.system(size: 46))
                Text(WidgetFormat.heroTemp(snapshot))
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 5) {
                    if let text = snapshot.currentSkyText {
                        Text(text).font(.subheadline).lineLimit(1)
                    }
                    if snapshot.heroIsObserved, let station = snapshot.observedStation {
                        StatRow(symbol: "sensor.fill", tint: .secondary, text: "Obs. \(station)")
                    }
                    StatRow(symbol: "thermometer.medium", tint: .secondary, text: WidgetFormat.range(snapshot))
                    if let humidity = snapshot.humedadMax {
                        StatRow(symbol: "humidity", tint: .blue, text: "\(humidity)%")
                    }
                    if let sunset = snapshot.sunset {
                        StatRow(symbol: "sunset.fill", tint: .pink, text: WidgetFormat.time(sunset))
                    }
                }
                Spacer(minLength: 0)
            }

            if !snapshot.hours.isEmpty {
                HourlyStrip(hours: Array(snapshot.hours.prefix(6)))
            }

            if !snapshot.days.isEmpty {
                Divider()
                VStack(spacing: 5) {
                    ForEach(snapshot.days.prefix(5)) { day in
                        HStack {
                            Text(WidgetFormat.weekday(day.date))
                                .font(.subheadline)
                                .frame(width: 72, alignment: .leading)
                            Spacer()
                            Text("\(WidgetFormat.temp(day.min)) / \(WidgetFormat.temp(day.max))")
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            Text("Elaborado con datos de AEMET")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Empty state

/// Shown before the app has cached anything.
public struct AuraCardEmpty: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.sun")
                .font(.title).foregroundStyle(.secondary)
            Text("Abre Aura para cargar la predicción.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Building blocks

/// The next few hours: hour, condition icon, temperature, and precipitation probability when > 0.
private struct HourlyStrip: View {
    let hours: [HourSlot]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(hours) { hour in
                VStack(spacing: 3) {
                    Text("\(hour.hour)h")
                        .font(.caption2).foregroundStyle(.secondary)
                    ConditionIcon(sky: hour.sky).font(.body)
                    Text(WidgetFormat.temp(hour.temp))
                        .font(.caption).fontWeight(.medium)
                    if let prob = hour.precipProb, prob > 0 {
                        Text("\(prob)%").font(.caption2).foregroundStyle(.blue)
                    } else {
                        Text(" ").font(.caption2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The large card's warning banner: a tinted row naming the phenomenon and level.
private struct AlertBanner: View {
    let alert: WeatherAlert

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AlertStyle.color(alert.level))
            VStack(alignment: .leading, spacing: 1) {
                Text(alert.phenomenon ?? "Aviso")
                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                Text("Aviso \(alert.level.rawValue)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(AlertStyle.color(alert.level).opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 10))
    }
}

/// A compact warning triangle for the small/medium cards, tinted by level.
private struct AlertBadge: View {
    let level: WeatherAlert.Level
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(AlertStyle.color(level))
    }
}

private enum AlertStyle {
    static func color(_ level: WeatherAlert.Level) -> Color {
        switch level {
        case .verde: return .green
        case .amarillo: return .yellow
        case .naranja: return .orange
        case .rojo: return .red
        }
    }
}

/// A condition glyph, coloured where the surface allows and single-tint where it doesn't.
private struct ConditionIcon: View {
    let sky: String?
    var body: some View {
        Image(systemName: WeatherIcon.symbol(forSky: sky))
            .symbolRenderingMode(.multicolor)
    }
}

private struct StatRow: View {
    let symbol: String
    let tint: Color
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(tint == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
            .labelStyle(.titleAndIcon)
    }
}

enum WidgetFormat {
    static func temp(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—" }

    /// The card's "now" hero: observed reading if available, else current-hour forecast, else high.
    static func heroTemp(_ s: WeatherSnapshot) -> String { temp(s.heroTemp) }

    /// "Máx 34° · Mín 18°".
    static func range(_ s: WeatherSnapshot) -> String {
        "Máx \(temp(s.tempMax)) · Mín \(temp(s.tempMin))"
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Hoy" }
        if Calendar.current.isDateInTomorrow(date) { return "Mañana" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE"
        return f.string(from: date).capitalized
    }
}

public extension WeatherSnapshot {
    /// Sample data for previews and the placeholder.
    static var preview: WeatherSnapshot {
        let cal = Calendar(identifier: .gregorian)
        let base = Date()
        let days = (0..<5).compactMap { offset -> DaySnapshot? in
            guard let date = cal.date(byAdding: .day, value: offset, to: base) else { return nil }
            return DaySnapshot(date: date, min: 17 + offset, max: 33 - offset)
        }
        let startHour = cal.component(.hour, from: base)
        let skies = ["11", "11", "12", "13", "13n", "14"]
        let hours = (0..<6).map { i in
            HourSlot(hour: (startHour + i) % 24, temp: 29 - i, sky: skies[i], precipProb: i >= 4 ? 15 : 0)
        }
        return WeatherSnapshot(
            ine: "28079", localidad: "Madrid", provincia: "Madrid",
            tempMin: 18, tempMax: 34, humedadMax: 55,
            currentTemp: 29, observedTemp: 30, observedStation: "Madrid Retiro",
            currentSky: "11", currentSkyText: "Despejado",
            windSpeed: 25, windDirection: .so,
            sunrise: cal.date(bySettingHour: 7, minute: 12, second: 0, of: base),
            sunset: cal.date(bySettingHour: 21, minute: 11, second: 0, of: base),
            days: days, hours: hours,
            alert: WeatherAlert(level: .naranja,
                                event: "Aviso de temperaturas máximas de nivel naranja",
                                phenomenon: "Temperatura máxima", zona: "280401",
                                areaDesc: "Metropolitana", onset: base,
                                expires: base.addingTimeInterval(3 * 3600)),
            updated: base
        )
    }
}
