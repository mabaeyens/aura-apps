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

/// `.accessoryCircular`: a compass read like a weather vane. A clean rose rings the dial — a 16-point
/// ring of grey marks with the N/E/S/O letters standing in for the cardinal marks — with the speed big
/// in the centre. A compact arrow, coloured by wind strength (Windy-style ramp), points across it: a
/// sharp arrowhead where the wind blows *to*, a swallowtail where it comes *from*. AEMET reports the
/// direction the wind comes *from*, so the arrowhead points that bearing + 180°.
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

                // The arrow, over the rose. Rotated so the arrowhead sits at the "blows toward" bearing.
                if let towards = towardsDegrees {
                    vane(diameter: d)
                        .frame(width: d, height: d)
                        .rotationEffect(.degrees(towards))
                }

                // Centre: the speed, big and white, drawn last so it stays legible over the arrow's
                // shaft. A soft dark halo lifts it off a bright arrow.
                Text(snapshot.windSpeed.map { "\($0)" } ?? "—")
                    .font(.system(size: d * 0.38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// One thin arrow in the wind-intensity colour: a sharp arrowhead where the wind blows *to*, a
    /// forked swallowtail where it comes *from*. The shape alone carries head-vs-tail, so it stays a
    /// single solid colour. It spans the dial tip to tip so the arrowhead sits *over* the mark at its
    /// bearing and the swallowtail *over* the opposite mark — the length that makes the heading read —
    /// while staying slim so it never looks like a chunky wedge.
    @ViewBuilder private func vane(diameter d: CGFloat) -> some View {
        WindArrow()
            .fill(Palette.wind(snapshot.windSpeed))
            .frame(width: d * 0.20, height: d * WindRose.markRingRadiusFactor * 2)
    }

    /// Bearing (degrees, N = 0 clockwise) the wind is blowing toward, or nil if direction is unknown.
    private var towardsDegrees: Double? {
        guard let dir = snapshot.windDirection else { return nil }
        return (dir.degrees + 180).truncatingRemainder(dividingBy: 360)
    }
}

/// The compass rose behind the arrow: a 32-point ring. The N/E/S/O letters sit ON the ring and stand in
/// for the cardinal marks (no separate tick there); the four inter-cardinals (NE/SE/SW/NW) are the
/// longest, brightest-grey marks; the eight 16-point marks are medium grey; the sixteen finest points
/// are short, dim grey. Shades of grey in a clear three-tier hierarchy. No dial ring; the marks carry it.
private struct WindRose: View {
    let diameter: CGFloat

    /// Radius, as a fraction of the diameter, of the outer tip of every mark — the ring the marks and
    /// the cardinal letters share, and the ring the arrow's tips reach.
    static let markRingRadiusFactor: CGFloat = 0.485

    var body: some View {
        let d = diameter
        ZStack {
            // The 32 compass points, every 11.25°. Skip the cardinals — there the letter is the mark.
            // Three tiers by importance: inter-cardinals (45°) longest and brightest, the 16-point marks
            // (22.5°) medium, the finest points (11.25°) short and dim.
            ForEach(Array(stride(from: 0.0, to: 360.0, by: 11.25)), id: \.self) { (deg: Double) in
                if deg.truncatingRemainder(dividingBy: 90) != 0 {
                    let tier = Self.tier(deg: deg)
                    mark(bearing: deg, length: d * tier.length, width: d * tier.width,
                         color: Color(white: tier.shade), d: d)
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

    /// The size/shade tier for a mark at `deg` (as fractions of the diameter): inter-cardinals longest
    /// and brightest, 16-point marks medium, the finest points short and dim.
    private static func tier(deg: Double) -> (length: CGFloat, width: CGFloat, shade: Double) {
        if deg.truncatingRemainder(dividingBy: 45) == 0 {
            return (0.11, 0.020, 0.85)      // inter-cardinal (NE/SE/SW/NW)
        } else if deg.truncatingRemainder(dividingBy: 22.5) == 0 {
            return (0.075, 0.016, 0.6)      // 16-point
        } else {
            return (0.05, 0.012, 0.38)      // finest
        }
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

/// A clean directional arrow pointing up (rotated to the heading): a sharp arrowhead at the top (where
/// the wind blows *to*), a thin shaft, and a forked swallowtail at the bottom (where it comes *from*).
/// Head and tail are unmistakably different shapes, so one solid fill reads directionally — no need for
/// two tones. Proportioned to stay slim and legible at complication size rather than a chunky wedge.
private struct WindArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let w = rect.width
        let h = rect.height
        let shaftHalf = w * 0.13           // thin shaft
        let headHalf = w * 0.5             // arrowhead half-width (the barbs) — reaches the frame edge
        let headH = h * 0.21               // arrowhead depth (kept a slice of the long arrow, so sharp)
        let tailHalf = w * 0.42            // swallowtail half-width
        let tailH = h * 0.17               // swallowtail depth
        let notch = h * 0.085              // how far the tail's centre V bites in

        // Arrowhead (top): a sharp triangle down to the shaft.
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + headHalf, y: rect.minY + headH))
        path.addLine(to: CGPoint(x: midX + shaftHalf, y: rect.minY + headH))
        // Right side of the shaft down to the tail.
        path.addLine(to: CGPoint(x: midX + shaftHalf, y: rect.maxY - tailH))
        // Swallowtail: right point, centre notch, left point.
        path.addLine(to: CGPoint(x: midX + tailHalf, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: midX - tailHalf, y: rect.maxY))
        // Left side of the shaft back up, and the left barb.
        path.addLine(to: CGPoint(x: midX - shaftHalf, y: rect.maxY - tailH))
        path.addLine(to: CGPoint(x: midX - shaftHalf, y: rect.minY + headH))
        path.addLine(to: CGPoint(x: midX - headHalf, y: rect.minY + headH))
        path.closeSubpath()
        return path
    }
}
