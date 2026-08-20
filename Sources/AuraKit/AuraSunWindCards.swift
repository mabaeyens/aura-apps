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

/// Which vane shape the wind complication draws over its compass rose.
public enum WindVaneStyle: Sendable {
    /// One tapered arrow — arrowhead = where the wind blows *to*, swallowtail = where it comes *from*.
    case arrow
    /// A two-tone compass needle — the bright half points *to*, the dim half points *from*.
    case needle
}

/// `.accessoryCircular`: a compass read like a weather vane. A clear rose rings the dial — white
/// cardinal letters and marks, grey inter-cardinal marks — with the speed big in the centre. A vane,
/// coloured by wind strength (Windy-style ramp), spans the dial and covers the marks at its head and
/// tail so the heading reads at a glance. AEMET reports the direction the wind comes *from*, so the
/// vane's head points that bearing + 180°. Two shapes to choose from, `.arrow` and `.needle`.
public struct AuraWindCircular: View {
    let snapshot: WeatherSnapshot
    let style: WindVaneStyle

    public init(snapshot: WeatherSnapshot, style: WindVaneStyle = .arrow) {
        self.snapshot = snapshot
        self.style = style
    }

    public var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                WindRose(diameter: d)

                // The vane, over the rose so it covers the marks at head and tail. Sized nearly the full
                // diameter so both ends reach the rim; rotated so the head sits at the "blows toward"
                // bearing.
                if let towards = towardsDegrees {
                    vane(diameter: d)
                        .frame(width: d, height: d)
                        .rotationEffect(.degrees(towards))
                }

                // Centre: the speed, big and white, drawn last so it stays legible over the vane. A soft
                // dark halo lifts it off a bright vane.
                Text(snapshot.windSpeed.map { "\($0)" } ?? "—")
                    .font(.system(size: d * 0.38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The vane view for the chosen style, coloured by wind strength. The head (points *to*) takes the
    /// full intensity colour; the tail (points *from*) a dimmer shade of it, so the two sections read.
    /// Kept slim — a thin arrow / needle over a legible rose, not a chunky wedge that hides the dial.
    @ViewBuilder private func vane(diameter d: CGFloat) -> some View {
        let head = Palette.wind(snapshot.windSpeed)
        let tail = head.opacity(0.5)
        switch style {
        case .arrow:
            // One thin arrow: a sharp arrowhead (points *to*), a slim shaft, a swallowtail (comes
            // *from*). The shape alone carries head-vs-tail, so it stays a single intensity colour.
            WindArrow()
                .fill(head)
                .frame(width: d * 0.30, height: d * 0.78)
        case .needle:
            // Two slim triangles with a gap in the middle for the number — bright half the head, dim
            // half the tail.
            ZStack {
                NeedleHalf(pointingUp: true).fill(head)
                NeedleHalf(pointingUp: false).fill(tail)
            }
            .frame(width: d * 0.16, height: d * 0.78)
        }
    }

    /// Bearing (degrees, N = 0 clockwise) the wind is blowing toward, or nil if direction is unknown.
    private var towardsDegrees: Double? {
        guard let dir = snapshot.windDirection else { return nil }
        return (dir.degrees + 180).truncatingRemainder(dividingBy: 360)
    }
}

/// The compass rose behind the vane: a fine ring of radial marks — a tick every 15° — so it reads as a
/// real rose, with the cardinals a touch longer and brighter and understated N/E/S/O letters just
/// inside. No dial ring; the marks alone carry it. Sized to `diameter`.
private struct WindRose: View {
    let diameter: CGFloat

    var body: some View {
        let d = diameter
        ZStack {
            // 24 marks, every 15°. Cardinals (90°) longest/brightest, inter-cardinals (45°) medium, the
            // rest short and dim — subtle, so the number can be big and the rose still reads.
            ForEach(Array(stride(from: 0, to: 360, by: 15)), id: \.self) { deg in
                let cardinal = deg % 90 == 0
                let inter = deg % 45 == 0
                mark(bearing: Double(deg),
                     length: cardinal ? d * 0.09 : (inter ? d * 0.07 : d * 0.05),
                     width: d * 0.016,
                     color: .white.opacity(cardinal ? 0.55 : (inter ? 0.36 : 0.22)),
                     d: d)
            }
            // Cardinal letters, small and understated — orientation without shouting over the number.
            letter("N", dx: 0, dy: -1, d: d)
            letter("E", dx: 1, dy: 0, d: d)
            letter("S", dx: 0, dy: 1, d: d)
            letter("O", dx: -1, dy: 0, d: d)
        }
        .frame(width: d, height: d)
    }

    /// One radial mark at `bearing` (0 = N, clockwise). Built as a capsule offset to the top of a
    /// d×d container, then the container is rotated about its centre — the dial centre — so the mark
    /// lands on its bearing, oriented radially.
    private func mark(bearing: Double, length: CGFloat, width: CGFloat, color: Color, d: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(color)
                .frame(width: width, height: length)
                .offset(y: -(d / 2 - length / 2 - d * 0.015))
        }
        .frame(width: d, height: d)
        .rotationEffect(.degrees(bearing))
    }

    /// One upright cardinal letter placed inside the marks (dx/dy are unit offsets, not rotated).
    private func letter(_ s: String, dx: CGFloat, dy: CGFloat, d: CGFloat) -> some View {
        Text(s)
            .font(.system(size: d * 0.12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .offset(x: dx * d * 0.30, y: dy * d * 0.30)
    }
}

/// A slim weather-vane arrow pointing up (rotated to heading): a sharp arrowhead at the top, a thin
/// shaft, and a forked "swallowtail" flight at the bottom — so it reads as one clean directional arrow
/// without hiding the rose behind it.
private struct WindArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let w = rect.width
        let h = rect.height
        let shaftHalf = w * 0.11
        let barb = w * 0.5
        let headH = h * 0.26
        let tailH = h * 0.20
        // Arrowhead (top): a sharp triangle.
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + barb, y: rect.minY + headH))
        path.addLine(to: CGPoint(x: midX + shaftHalf, y: rect.minY + headH))
        // Shaft down to the tail.
        path.addLine(to: CGPoint(x: midX + shaftHalf, y: rect.maxY - tailH))
        // Swallowtail flight (right point, centre notch, left point).
        path.addLine(to: CGPoint(x: midX + barb, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY - tailH * 0.5))
        path.addLine(to: CGPoint(x: midX - barb, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - shaftHalf, y: rect.maxY - tailH))
        // Shaft back up and the left barb.
        path.addLine(to: CGPoint(x: midX - shaftHalf, y: rect.minY + headH))
        path.addLine(to: CGPoint(x: midX - barb, y: rect.minY + headH))
        path.closeSubpath()
        return path
    }
}

/// One half of a compass needle — a long slim triangle from the rim to a gap near the centre (leaving
/// room for the number). `pointingUp` is the head half (tip at top), otherwise the tail (tip at bottom).
private struct NeedleHalf: Shape {
    let pointingUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let halfW = rect.width / 2
        let gap = rect.height * 0.10          // clear space around the centre number
        let baseY = rect.midY + (pointingUp ? -gap : gap)
        let tipY = pointingUp ? rect.minY : rect.maxY
        path.move(to: CGPoint(x: midX, y: tipY))
        path.addLine(to: CGPoint(x: midX + halfW, y: baseY))
        path.addLine(to: CGPoint(x: midX - halfW, y: baseY))
        path.closeSubpath()
        return path
    }
}
