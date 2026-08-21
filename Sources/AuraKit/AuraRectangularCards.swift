import SwiftUI

// Wide `.accessoryRectangular` cards for the Modular / Modular Ultra centre slot: the next few hours
// and the next few days, as compact coloured columns. They live in AuraKit so the watch complication
// and any iOS Lock Screen render identical code. Colour comes through on watchOS full-colour faces;
// the iOS Lock Screen renders vibrant/monochrome.
//
//   Hours: header (hour) · icon · temperature, over a "time · humidity · rain-chance" footer.
//   Days:  header (weekday) · icon · high · low — max/min is more useful than a footer here.
//
// The icon sits in a fixed-height slot so the temperature rows line up across columns even though the
// condition symbols (sun, cloud, cloud.sun…) have different intrinsic heights.

private let iconSlotHeight: CGFloat = 20

/// One column: header, condition icon (fixed-height slot), a value, and optionally a low beneath it.
private struct StripColumn: View {
    let header: String
    let sky: String?
    let isNight: Bool
    let value: Int?
    var low: Int? = nil
    var showLow: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(header)
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            ConditionGlyph(sky: sky, isNight: isNight)
                .font(.system(size: 16))
                .frame(height: iconSlotHeight)
            Text(value.map { "\($0)°" } ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.temperature(value))
            if showLow {
                Text(low.map { "\($0)°" } ?? "—")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.temperature(low))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Next hours

/// `.accessoryRectangular`: up to five upcoming hours, each with its own day/night icon, over a footer
/// naming the location and when the data was refreshed.
public struct AuraRectHours: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        let hours = Array(snapshot.upcomingHours().prefix(5))
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
                // Footer: refresh time, plus the current humidity and rain chance — a teal drop and a
                // blue umbrella tell the two percentages apart. Replaces the old "· location" line
                // (which read as an observed-station reference) entirely.
                HStack(spacing: 8) {
                    Text("act. \(Self.hhmm(snapshot.updated))")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    pct("humidity.fill", snapshot.currentHumidity ?? 0, Palette.tempTeal)
                    pct("umbrella.fill", snapshot.currentPrecipProb ?? 0, Palette.tempBlue)
                }
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// One footer percentage: a small icon and its value in one tint.
    private func pct(_ icon: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text("\(value)%")
        }
        .foregroundStyle(tint)
    }

    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Next days

/// `.accessoryRectangular`: up to five upcoming days — daytime icon, high and low. Icons are the
/// daytime condition (a days overview shouldn't show moons).
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
                    StripColumn(header: Self.weekday(d.date),
                                sky: d.sky,
                                isNight: false,
                                value: d.max,
                                low: d.min,
                                showLow: true)
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
