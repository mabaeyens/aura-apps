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
                    Text(auraString("rect.updatedAbbrev", Self.hhmm(snapshot.updated)))
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
        return AuraTime.hhmm(date)
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

    private static func weekday(_ date: Date) -> String { AuraTime.shortWeekday(date) }
}

// MARK: - Sun (rectangular)

/// `.accessoryRectangular`: the day's sun as a wide card — a daylight-remaining readout, a warm bar with
/// a marker where "now" sits between orto and ocaso, and the two times at the ends. The sun combo for the
/// Modular / Modular Ultra centre slot; the same idiom as the app's `AuraSunArcCard`, flattened to a bar.
public struct AuraRectSun: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let sr = snapshot.sunrise, let ss = snapshot.sunset, ss > sr {
            VStack(alignment: .leading, spacing: 3) {
                Text(readout(sr: sr, ss: ss))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
                // The daylight bar: a faint track, a warm fill up to "now", and a dot marking the sun's
                // progress from orto (left) to ocaso (right).
                GeometryReader { geo in
                    let w = geo.size.width
                    let p = progress(sr: sr, ss: ss)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22)).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(colors: [Palette.tempOrange, Palette.tempYellow],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, w * p), height: 4)
                        Circle().fill(.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Palette.tempOrange, lineWidth: 1.5))
                            .offset(x: min(max(0, w * p - 4), w - 8))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 8)
                HStack(spacing: 4) {
                    Label(hhmm(sr), systemImage: "sunrise.fill")
                    Spacer(minLength: 2)
                    Label(hhmm(ss), systemImage: "sunset.fill")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            AuraAccessoryEmpty()
        }
    }

    /// Fraction 0…1 through the daylight span; clamped, so before orto it's 0 and after ocaso it's 1.
    private func progress(sr: Date, ss: Date) -> Double {
        let total = ss.timeIntervalSince(sr)
        guard total > 0 else { return 0 }
        return min(max(0, now.timeIntervalSince(sr) / total), 1)
    }

    /// Daylight remaining while the sun is up, else the countdown to the next sunrise (this morning's
    /// orto stands in for tomorrow's — sun times barely move day to day — so wrap a past time by 24h).
    private func readout(sr: Date, ss: Date) -> String {
        if now >= sr, now < ss, let left = Self.compact(from: now, to: ss) {
            return auraString("sun.daylightLeft", left)
        }
        if let until = Self.compact(from: now, to: sr, wrapDay: true) {
            return auraString("sun.sunriseIn", until)
        }
        return auraString("sun.title")
    }

    private func hhmm(_ date: Date) -> String {
        return AuraTime.hhmm(date)
    }

    /// Compact "2h51m" / "43m" between two times; wraps past midnight when asked, else nil for a past time.
    private static func compact(from: Date, to: Date, wrapDay: Bool = false) -> String? {
        var s = Int(to.timeIntervalSince(from))
        if s < 0 { if wrapDay { s += 24 * 3600 } else { return nil } }
        guard s > 0 else { return nil }
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h\(String(format: "%02d", m))m" : "\(m)m"
    }
}
