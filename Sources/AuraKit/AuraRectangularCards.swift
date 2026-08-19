import SwiftUI

// Wide `.accessoryRectangular` cards for the Modular / Modular Ultra centre slot: the next few hours
// and the next few days, rendered as the *same* four-row table so they read as a matched pair —
//   row 1: header  (the hour, or the weekday short name)
//   row 2: the condition icon
//   row 3: the temperature (the hour's temp, or the day's high), temperature-tinted
//   row 4: wind, km/h, when the forecast carries it
// They live in AuraKit so the watch complication and any iOS Lock Screen render identical code.
// Colour comes through on watchOS full-colour faces; the iOS Lock Screen renders vibrant/monochrome.

/// One column of the forecast table: header, condition icon, value, wind. Both cards feed this so the
/// hours and days strips line up row-for-row.
private struct ForecastColumn: View {
    let header: String
    let sky: String?
    let value: Int?
    let wind: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text(header)
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            Image(systemName: WeatherIcon.symbol(forSky: sky))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 16))
            Text(value.map { "\($0)°" } ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.temperature(value))
            // Reserve the wind row in every column so the four rows stay aligned across the strip.
            if let wind {
                HStack(spacing: 1) {
                    Image(systemName: "wind").font(.system(size: 8))
                    Text("\(wind)").font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            } else {
                Text(" ").font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Next hours

/// `.accessoryRectangular`: up to five upcoming hours as the shared four-row table.
public struct AuraRectHours: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        let hours = Array(snapshot.hours.prefix(5))
        if hours.isEmpty {
            AuraAccessoryEmpty()
        } else {
            HStack(spacing: 0) {
                ForEach(hours) { h in
                    ForecastColumn(header: "\(h.hour)", sky: h.sky, value: h.temp, wind: h.windSpeed)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Next days

/// `.accessoryRectangular`: up to five upcoming days as the shared four-row table — the day's high
/// stands in for the hourly temperature.
public struct AuraRectDays: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        let days = Array(snapshot.days.prefix(5))
        if days.isEmpty {
            AuraAccessoryEmpty()
        } else {
            HStack(spacing: 0) {
                ForEach(days) { d in
                    ForecastColumn(header: Self.weekday(d.date), sky: d.sky, value: d.max, wind: d.windSpeed)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(3)).capitalized
    }
}
