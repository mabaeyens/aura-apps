import SwiftUI

// Extra Apple Watch complication faces, sharing AuraKit so the app can reuse them too:
// - Sunrise/Sunset, auto-picking whichever event is next (circular + corner)
// - Wind, compass rose + speed (circular)
// Colour comes through on watchOS full-colour faces; the iOS Lock Screen renders them vibrant/mono.

// MARK: - Sunrise / Sunset

/// `.accessoryCircular`: a ring that depletes toward the next sun event — full at the start of the
/// current daylight (or night) period, empty at its end — the sun/moon icon in the middle. Warm
/// amber by day, cool indigo overnight. Falls back to icon + time when sun times are unknown.
public struct AuraSunCircular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        let event = snapshot.nextSunEvent(now: now)
        if let progress = snapshot.sunProgress(now: now) {
            Gauge(value: progress.fractionRemaining) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: SunFormat.icon(event))
                    .symbolRenderingMode(.multicolor)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Palette.sunGauge(isDaytime: progress.isDaytime))
        } else {
            VStack(spacing: 1) {
                Image(systemName: SunFormat.icon(event))
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                Text(SunFormat.date(event).map { SunFormat.hhmm($0) } ?? "—")
                    .font(.caption).fontWeight(.semibold)
            }
        }
    }
}

/// `.accessoryCorner` (Apple Watch): the sun/moon icon in the corner, with a bezel gauge that
/// depletes toward the next event (warm by day, cool by night). Falls back to the event time as a
/// plain curved label when sun times are unknown.
public struct AuraSunCorner: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        Image(systemName: SunFormat.icon(snapshot.nextSunEvent(now: now)))
            .symbolRenderingMode(.multicolor)
            .font(.title2)
    }

    /// Whether the depleting bezel gauge can be drawn (sun times known).
    public var hasProgress: Bool { snapshot.sunProgress(now: now) != nil }

    /// The bezel gauge: fraction of the current period remaining, day/night tinted. Only valid when
    /// `hasProgress`.
    @ViewBuilder public var cornerGauge: some View {
        if let progress = snapshot.sunProgress(now: now) {
            Gauge(value: progress.fractionRemaining) { EmptyView() }
                .tint(Palette.sunGauge(isDaytime: progress.isDaytime))
        }
    }

    /// Fallback curved label: the event time, e.g. "21:06".
    public var cornerLabel: String {
        SunFormat.date(snapshot.nextSunEvent(now: now)).map(SunFormat.hhmm) ?? "—"
    }
}

private enum SunFormat {
    static func icon(_ event: WeatherSnapshot.SunEvent?) -> String {
        switch event {
        case .sunrise: return "sunrise.fill"
        case .sunset:  return "sunset.fill"
        case nil:      return "sun.max.fill"
        }
    }

    static func date(_ event: WeatherSnapshot.SunEvent?) -> Date? {
        switch event {
        case .sunrise(let d), .sunset(let d): return d
        case nil: return nil
        }
    }

    static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Wind

/// `.accessoryCircular`: wind speed as a ring (0–60 km/h), a compass arrow pointing the way the wind
/// comes from, and the speed in the middle.
public struct AuraWindCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    private static let fullScale = 60.0

    public var body: some View {
        if let speed = snapshot.windSpeed {
            Gauge(value: min(Double(speed), Self.fullScale), in: 0...Self.fullScale) {
                arrow
            } currentValueLabel: {
                Text("\(speed)")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [Palette.tempTeal, Palette.tempGreen, Palette.tempYellow, Palette.tempOrange]))
        } else {
            VStack(spacing: 1) {
                Image(systemName: "wind")
                Text("—").font(.headline)
            }
        }
    }

    /// A north-referenced arrow rotated to the direction the wind blows *from* (meteorological).
    @ViewBuilder private var arrow: some View {
        if let dir = snapshot.windDirection {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(dir.degrees))
        } else {
            Image(systemName: "wind")
        }
    }
}
