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

/// `.accessoryCircular`: a compass read like a weather vane. A fine rose rings the dial — bright,
/// near-white marks with the N/E/S/O letters standing in for the cardinal marks, all on one ring — with
/// the speed big in the centre. A two-tone needle, coloured by wind strength (Windy-style ramp), lies
/// over the rose and spans it tip to tip. AEMET reports the direction the wind comes *from*, so the
/// needle's bright head points that bearing + 180°.
public struct AuraWindCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                WindRose(diameter: d)

                // The needle, over the rose. Sized so its tips reach the mark ring; rotated so the
                // bright head sits at the "blows toward" bearing.
                if let towards = towardsDegrees {
                    vane(diameter: d)
                        .frame(width: d, height: d)
                        .rotationEffect(.degrees(towards))
                }

                // Centre: the speed, big and white, drawn last so it stays legible over the needle. A
                // soft dark halo lifts it off a bright needle.
                Text(snapshot.windSpeed.map { "\($0)" } ?? "—")
                    .font(.system(size: d * 0.38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The compass needle, coloured by wind strength: two slim triangles with a gap in the middle for
    /// the number — the bright half is the head (points *to*), the dim half the tail (points *from*).
    /// Tip to tip it is as long as the marker ring, so each tip meets its mark.
    @ViewBuilder private func vane(diameter d: CGFloat) -> some View {
        let head = Palette.wind(snapshot.windSpeed)
        let tail = head.opacity(0.5)
        ZStack {
            NeedleHalf(pointingUp: true).fill(head)
            NeedleHalf(pointingUp: false).fill(tail)
        }
        .frame(width: d * 0.16, height: d * WindRose.markRingRadiusFactor * 2)
    }

    /// Bearing (degrees, N = 0 clockwise) the wind is blowing toward, or nil if direction is unknown.
    private var towardsDegrees: Double? {
        guard let dir = snapshot.windDirection else { return nil }
        return (dir.degrees + 180).truncatingRemainder(dividingBy: 360)
    }
}

/// The compass rose behind the needle: a fine ring of radial marks — a tick every 9°, 40 in all — so it
/// reads as a real rose, with the inter-cardinals a touch longer. The N/E/S/O letters sit ON that same
/// ring, standing in for the cardinal marks (no separate tick). No dial ring; the marks carry it.
private struct WindRose: View {
    let diameter: CGFloat

    /// Radius, as a fraction of the diameter, of the outer tip of every mark — the ring the marks and
    /// the cardinal letters share, and the ring the needle's tips reach.
    static let markRingRadiusFactor: CGFloat = 0.485

    var body: some View {
        let d = diameter
        ZStack {
            // Marks every 9°, but NOT at the cardinals — there the letter itself is the mark. Bright,
            // nearly white (inter-cardinals full white, the rest almost); all reach the same outer ring.
            ForEach(Array(stride(from: 0, to: 360, by: 9)), id: \.self) { deg in
                if deg % 90 != 0 {
                    let inter = deg % 45 == 0
                    mark(bearing: Double(deg),
                         length: inter ? d * 0.10 : d * 0.06,
                         width: d * 0.016,
                         color: .white.opacity(inter ? 1.0 : 0.85),
                         d: d)
                }
            }
            // Cardinal letters — bright white, ON the mark ring and aligned with the rest of the marks:
            // they ARE the cardinal marks, with no tick beside them.
            letter("N", dx: 0, dy: -1, d: d)
            letter("E", dx: 1, dy: 0, d: d)
            letter("S", dx: 0, dy: 1, d: d)
            letter("O", dx: -1, dy: 0, d: d)
        }
        .frame(width: d, height: d)
    }

    /// One radial mark at `bearing` (0 = N, clockwise). Built as a capsule whose outer tip sits on the
    /// mark ring inside a d×d container, then rotated about the container (dial) centre onto its bearing.
    private func mark(bearing: Double, length: CGFloat, width: CGFloat, color: Color, d: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(color)
                .frame(width: width, height: length)
                .offset(y: -(d * Self.markRingRadiusFactor - length / 2))
        }
        .frame(width: d, height: d)
        .rotationEffect(.degrees(bearing))
    }

    /// One upright cardinal letter, centred on the mark ring (dx/dy are unit offsets, not rotated), so
    /// it reads as the cardinal mark rather than a label sitting inside the ring.
    private func letter(_ s: String, dx: CGFloat, dy: CGFloat, d: CGFloat) -> some View {
        let r = d * (Self.markRingRadiusFactor - 0.075)   // centre pulled in by ~half the glyph height
        return Text(s)
            .font(.system(size: d * 0.15, weight: .bold))
            .foregroundStyle(.white)
            .offset(x: dx * r, y: dy * r)
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
