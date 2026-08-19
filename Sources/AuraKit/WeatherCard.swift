import SwiftUI

// These SwiftUI cards live in AuraKit so the app and the widget extension render from identical
// code (per the plan). They take a plain `WeatherSnapshot` and know nothing about WidgetKit; the
// extension wraps them in the widget families, and the app can preview them directly.

// MARK: - Small

/// systemSmall: location, today's high as the hero, low, and next sun event.
public struct AuraCardSmall: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.localidad)
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(WidgetFormat.temp(snapshot.tempMax))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
            Text("Mín \(WidgetFormat.temp(snapshot.tempMin))")
                .font(.caption).foregroundStyle(.secondary)

            if let event = SunEvent.next(for: snapshot) {
                Label("\(event.label) \(WidgetFormat.time(event.date))", systemImage: event.symbol)
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

/// systemMedium: hero on the left, today's details stacked on the right.
public struct AuraCardMedium: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.localidad)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(WidgetFormat.temp(snapshot.tempMax))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                Text("Mín \(WidgetFormat.temp(snapshot.tempMin))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if let humidity = snapshot.humedadMax {
                    StatRow(symbol: "humidity", tint: .blue, text: "\(humidity)%")
                }
                if let sunrise = snapshot.sunrise {
                    StatRow(symbol: "sunrise.fill", tint: .orange, text: WidgetFormat.time(sunrise))
                }
                if let sunset = snapshot.sunset {
                    StatRow(symbol: "sunset.fill", tint: .pink, text: WidgetFormat.time(sunset))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Large

/// systemLarge: header, hero row, then a multi-day list. (Avisos banner lands in Phase 2.5.)
public struct AuraCardLarge: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.localidad)
                    .font(.title3).fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text("Actualizado \(WidgetFormat.time(snapshot.updated))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 16) {
                Text(WidgetFormat.temp(snapshot.tempMax))
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 6) {
                    StatRow(symbol: "thermometer.low", tint: .secondary, text: "Mín \(WidgetFormat.temp(snapshot.tempMin))")
                    if let humidity = snapshot.humedadMax {
                        StatRow(symbol: "humidity", tint: .blue, text: "\(humidity)%")
                    }
                    if let sunrise = snapshot.sunrise {
                        StatRow(symbol: "sunrise.fill", tint: .orange, text: WidgetFormat.time(sunrise))
                    }
                    if let sunset = snapshot.sunset {
                        StatRow(symbol: "sunset.fill", tint: .pink, text: WidgetFormat.time(sunset))
                    }
                }
                Spacer(minLength: 0)
            }

            if !snapshot.days.isEmpty {
                Divider()
                VStack(spacing: 6) {
                    ForEach(snapshot.days.prefix(5)) { day in
                        HStack {
                            Text(WidgetFormat.weekday(day.date))
                                .font(.subheadline)
                                .frame(width: 64, alignment: .leading)
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

/// Next sunrise/sunset relative to now, for the small widget's single sun line.
private struct SunEvent {
    let label: String
    let symbol: String
    let date: Date

    static func next(for snapshot: WeatherSnapshot, now: Date = Date()) -> SunEvent? {
        if let sunrise = snapshot.sunrise, sunrise > now {
            return SunEvent(label: "Orto", symbol: "sunrise.fill", date: sunrise)
        }
        if let sunset = snapshot.sunset, sunset > now {
            return SunEvent(label: "Ocaso", symbol: "sunset.fill", date: sunset)
        }
        // Both already passed today: show tomorrow's implied sunrise if we have it, else sunset.
        if let sunrise = snapshot.sunrise { return SunEvent(label: "Orto", symbol: "sunrise.fill", date: sunrise) }
        if let sunset = snapshot.sunset { return SunEvent(label: "Ocaso", symbol: "sunset.fill", date: sunset) }
        return nil
    }
}

enum WidgetFormat {
    static func temp(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—" }

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
        return WeatherSnapshot(
            ine: "28079", localidad: "Madrid", provincia: "Madrid",
            tempMin: 18, tempMax: 34, humedadMax: 55,
            sunrise: cal.date(bySettingHour: 7, minute: 12, second: 0, of: base),
            sunset: cal.date(bySettingHour: 21, minute: 11, second: 0, of: base),
            days: days, updated: base
        )
    }
}
