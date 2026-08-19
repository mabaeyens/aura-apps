import SwiftUI

// Extra Apple Watch complication faces, sharing AuraKit so the app can reuse them too:
// - Sunrise/Sunset, auto-picking whichever event is next (circular + corner)
// - Wind, compass rose + speed (circular)
// Colour comes through on watchOS full-colour faces; the iOS Lock Screen renders them vibrant/mono.

// MARK: - Sunrise / Sunset

/// `.accessoryCircular`: the next sun event — its icon and precise time, computed from the location's
/// own sunrise/sunset. At dawn it shows sunrise, during the day sunset, after dark the next sunrise.
public struct AuraSunCircular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        let event = snapshot.nextSunEvent(now: now)
        VStack(spacing: 2) {
            Image(systemName: SunFormat.icon(event))
                .symbolRenderingMode(.multicolor)
                .font(.title2)
            Text(SunFormat.date(event).map { SunFormat.hhmm($0) } ?? "—")
                .font(.caption).fontWeight(.semibold)
        }
    }
}

/// `.accessoryCorner` (Apple Watch): a large sun/moon icon in the corner, with the precise event time
/// as the curved bezel label. Aura's sun times are location-based, so they're more exact than a
/// generic complication.
public struct AuraSunCorner: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        // `.resizable()` makes the symbol fill the whole corner region; a plain `.font(.title)` renders
        // at a fixed, much smaller intrinsic size that leaves most of the corner empty — that's why it
        // looked tiny next to the circular complication. Palette tint keeps the rising/setting arrow
        // yellow over an orange horizon; the event time and the time remaining ride the bezel below.
        Image(systemName: SunFormat.icon(snapshot.nextSunEvent(now: now)))
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(.yellow, .orange)
    }

    /// The curved label: the event time plus how long until it, e.g. "21:06 · 2h51".
    public var cornerLabel: String {
        let event = snapshot.nextSunEvent(now: now)
        guard let date = SunFormat.date(event) else { return "—" }
        let time = SunFormat.hhmm(date)
        if let remaining = SunFormat.remaining(from: now, to: date) { return "\(time) · \(remaining)" }
        return time
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

    /// Compact time-until, e.g. "2h51" or "43m"; nil once the event has passed.
    static func remaining(from: Date, to: Date) -> String? {
        let seconds = Int(to.timeIntervalSince(from))
        guard seconds > 0 else { return nil }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))" : "\(minutes)m"
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
