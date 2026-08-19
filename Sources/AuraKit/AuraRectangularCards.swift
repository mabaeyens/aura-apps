import SwiftUI

// Wide `.accessoryRectangular` cards for the Modular / Modular Ultra centre slot: the next few hours
// and the next few days, rendered as the *same* table so they read as a matched pair —
//   row 1: header  (the hour, or the weekday short name)
//   row 2: the condition icon
//   row 3: the temperature (the hour's temp, or the day's high), temperature-tinted
//   footer: when the forecast was last refreshed — always present, so the card never has a dead row.
// They live in AuraKit so the watch complication and any iOS Lock Screen render identical code.
// Colour comes through on watchOS full-colour faces; the iOS Lock Screen renders vibrant/monochrome.

/// One column of the forecast table: header, condition icon, value.
private struct StripColumn: View {
    let header: String
    let sky: String?
    let isNight: Bool
    let value: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text(header)
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            ConditionGlyph(sky: sky, isNight: isNight)
                .font(.system(size: 16))
            Text(value.map { "\($0)°" } ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.temperature(value))
        }
        .frame(maxWidth: .infinity)
    }
}

/// The shared bottom line: when AEMET's forecast was last pulled. Fills the fourth row so the strip is
/// never left with a blank band, and doubles as a freshness cue.
private struct UpdatedFooter: View {
    let updated: Date

    var body: some View {
        Text("Actualizado \(Self.hhmm(updated))")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Next hours

/// `.accessoryRectangular`: up to five upcoming hours, each with its own day/night icon.
public struct AuraRectHours: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        let hours = Array(snapshot.hours.prefix(5))
        if hours.isEmpty {
            AuraAccessoryEmpty()
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(hours) { h in
                        StripColumn(header: "\(h.hour)",
                                    sky: h.sky,
                                    isNight: (h.sky ?? "").hasSuffix("n"),
                                    value: h.temp)
                    }
                }
                UpdatedFooter(updated: snapshot.updated)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Next days

/// `.accessoryRectangular`: up to five upcoming days — the day's high stands in for the hourly
/// temperature. Icons are the daytime condition (a days overview shouldn't show moons).
public struct AuraRectDays: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        let days = Array(snapshot.days.prefix(5))
        if days.isEmpty {
            AuraAccessoryEmpty()
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(days) { d in
                        StripColumn(header: Self.weekday(d.date),
                                    sky: d.sky,
                                    isNight: false,
                                    value: d.max)
                    }
                }
                UpdatedFooter(updated: snapshot.updated)
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
