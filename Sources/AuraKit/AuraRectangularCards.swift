import SwiftUI

// Wide `.accessoryRectangular` cards for the Modular / Modular Ultra centre slot: the next few hours
// and the next few days, as compact coloured columns. They live in AuraKit so the watch complication
// and any iOS Lock Screen use render identical code. Colour comes through on watchOS full-colour
// faces; the iOS Lock Screen renders them vibrant/monochrome.

// MARK: - Next hours

/// `.accessoryRectangular`: up to five upcoming hours as columns — hour, condition icon, temperature.
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
                    VStack(spacing: 1) {
                        Text("\(h.hour)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Image(systemName: WeatherIcon.symbol(forSky: h.sky))
                            .symbolRenderingMode(.multicolor)
                            .font(.footnote)
                        Text(h.temp.map { "\($0)°" } ?? "—")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(Palette.temperature(h.temp))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Next days

/// `.accessoryRectangular`: up to five upcoming days as columns — weekday, high, low (both tinted).
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
                    VStack(spacing: 1) {
                        Text(Self.weekday(d.date))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(d.max.map { "\($0)°" } ?? "—")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Palette.temperature(d.max))
                        Text(d.min.map { "\($0)°" } ?? "—")
                            .font(.caption2)
                            .foregroundStyle(Palette.temperature(d.min))
                    }
                    .frame(maxWidth: .infinity)
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
