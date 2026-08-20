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
        let date = SunFormat.date(event)
        VStack(spacing: 1) {
            Image(systemName: SunFormat.icon(event))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .orange)
                .font(.title2)
            Text(date.map(SunFormat.hhmm) ?? "—")
                .font(.caption).fontWeight(.semibold)
            if let date, let remaining = SunFormat.remaining(from: now, to: date) {
                Text("· \(remaining)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
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

    /// Compact time-until, e.g. "2h51" or "43m". The snapshot only carries *today's* sun times, so
    /// after dark the "next sunrise" date is actually this morning's (already past); sun times barely
    /// move day to day, so wrap a negative interval by 24h to get tomorrow's event.
    static func remaining(from: Date, to: Date) -> String? {
        var seconds = Int(to.timeIntervalSince(from))
        if seconds < 0 { seconds += 24 * 3600 }
        guard seconds > 0 else { return nil }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))" : "\(minutes)m"
    }
}

// MARK: - Wind

/// `.accessoryCircular`: a compass, read like a weather vane. Fixed N/E/S/O letters ring the dial; a
/// long arrow spans it — the arrowhead marks where the wind is *going* (a SurOeste wind blows toward
/// the North-East), the flighted tail where it comes *from* — coloured by strength. The speed sits in
/// the centre. AEMET reports the direction the wind comes *from*, so the vane points that bearing + 180°.
public struct AuraWindCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    private static let letterRadius: CGFloat = 22

    public var body: some View {
        ZStack {
            // The dial and the four fixed cardinal letters, so the vane's heading is readable.
            Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1)
            compassLetter("N", dx: 0, dy: -1)
            compassLetter("E", dx: 1, dy: 0)
            compassLetter("S", dx: 0, dy: 1)
            compassLetter("O", dx: -1, dy: 0)

            // The vane: a slim arrow across the dial, rotated to the wind's heading. Kept narrow so it
            // reads as a direction indicator, not a chunky wedge, and doesn't crowd the centre number.
            if let towards = towardsDegrees {
                WeatherVane()
                    .fill(speedColor)
                    .frame(width: 10, height: 44)
                    .rotationEffect(.degrees(towards))
            }

            // Centre: the speed, bold and white so it reads over the vane's shaft.
            Text(snapshot.windSpeed.map { "\($0)" } ?? "—")
                .font(.system(.title3, design: .rounded)).fontWeight(.heavy)
                .foregroundStyle(.white)
        }
    }

    /// One upright cardinal letter placed on the dial (dx/dy are unit offsets, not rotated, so the
    /// glyph stays upright).
    private func compassLetter(_ s: String, dx: CGFloat, dy: CGFloat) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.primary)  // full-contrast, not the dim .secondary — the marks must read
            .offset(x: dx * Self.letterRadius, y: dy * Self.letterRadius)
    }

    /// Bearing (degrees, N = 0 clockwise) the wind is blowing toward, or nil if direction is unknown.
    private var towardsDegrees: Double? {
        guard let dir = snapshot.windDirection else { return nil }
        return (dir.degrees + 180).truncatingRemainder(dividingBy: 360)
    }

    /// Vane colour by wind speed — teal (light) through green and orange to red (gale). No pale
    /// yellow, which washes out on a black face.
    private var speedColor: Color {
        switch snapshot.windSpeed ?? 0 {
        case ..<15:    return Palette.tempTeal
        case 15..<30:  return Palette.tempGreen
        case 30..<45:  return Palette.tempOrange
        default:       return Palette.tempRed
        }
    }
}

/// A weather-vane arrow pointing up (rotated to heading): a broad arrowhead at the top, a slim shaft,
/// and a forked "swallowtail" flight at the bottom — so the whole dial reads as one directional arrow.
private struct WeatherVane: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let w = rect.width
        let h = rect.height
        let shaftHalf = w * 0.16
        let headH = h * 0.24
        let tailH = h * 0.20
        // Arrowhead (top).
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + headH))
        path.addLine(to: CGPoint(x: midX + shaftHalf, y: rect.minY + headH))
        // Shaft down to the tail.
        path.addLine(to: CGPoint(x: midX + shaftHalf, y: rect.maxY - tailH))
        // Swallowtail flight (right point, centre notch, left point).
        path.addLine(to: CGPoint(x: midX + w * 0.42, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY - tailH * 0.55))
        path.addLine(to: CGPoint(x: midX - w * 0.42, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - shaftHalf, y: rect.maxY - tailH))
        // Shaft back up and the left barb.
        path.addLine(to: CGPoint(x: midX - shaftHalf, y: rect.minY + headH))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + headH))
        path.closeSubpath()
        return path
    }
}
