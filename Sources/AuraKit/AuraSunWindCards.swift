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
        // Icon + precise time only. Three stacked lines (icon, time, remaining) overflowed the tiny
        // circular safe area, so the "time remaining" moves to the curved bezel via `.widgetLabel`
        // (see `remainingLabel`, applied by the complication). Semantic fonts + `minimumScaleFactor`
        // keep the two lines fitting instead of clipping to "…".
        let event = snapshot.nextSunEvent(now: now)
        let date = SunFormat.date(event)
        VStack(spacing: 0) {
            Image(systemName: SunFormat.icon(event))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .orange)
                .font(.title3)
            Text(date.map(SunFormat.hhmm) ?? "—")
                .font(.caption).fontWeight(.semibold)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    /// How long until the next sun event, e.g. "2h51m" or "43m" — for the curved bezel label, so the
    /// tight circular face keeps only the icon and the time. Nil when the event time is unknown.
    public var remainingLabel: String? {
        guard let date = SunFormat.date(snapshot.nextSunEvent(now: now)) else { return nil }
        return SunFormat.remaining(from: now, to: date)
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

// MARK: - Rain chance

/// `.accessoryCircular`: the precipitation probability for the current hour as a ring fill, with a
/// raindrop glyph and the percentage in the centre. Probability is encoded by the ring's fill (shape,
/// not hue) so it still reads on the desaturated Lock Screen; the blue tint comes through on
/// full-colour watch faces. Reads `currentPrecipProb` — the same field the rectangular card uses.
public struct AuraRainCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    /// Precipitation probability for the current hour, %, or nil on a thin snapshot (no hourly feed).
    private var prob: Int? { snapshot.currentPrecipProb }

    public var body: some View {
        Gauge(value: Double(prob ?? 0), in: 0...100) {
            // White keeps the drop legible and clearly distinct from the ring, which already carries
            // the probability in Palette.precip. Without it the label inherits the gauge tint, so the
            // drop turns the same blue as the ring and reads as a smudge on it.
            Image(systemName: "drop.fill").foregroundStyle(.white)
        } currentValueLabel: {
            Text(prob.map { "\($0)" } ?? "—")
                .fontWeight(.semibold).fontDesign(.rounded)
                // Deepen the blue with the probability (an Aura convention — no official POP palette
                // exists). Shows on colour faces; the Lock Screen desaturates it, ring fill unchanged.
                .foregroundStyle(Palette.precip(prob ?? 0))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Palette.precip(prob ?? 0))
    }
}

// MARK: - UV index

/// `.accessoryCircular`: the day's maximum UV index as a ring fill on the WHO 0…11 scale, with a sun
/// glyph and the index number in the centre. AEMET publishes a clear-sky *daily maximum*, not an
/// hourly value, so this is honestly the day's peak — the complication's description and the curved
/// `bandLabel` (e.g. "Muy alto") say so rather than implying "now". The band colour comes through on
/// full-colour faces; the ring fill carries the level when colour is dropped.
public struct AuraUVCircular: View {
    let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    /// The day's clear-sky maximum UV index, or nil when the UV product hasn't loaded.
    private var uv: UVIndex? { snapshot.uvIndex }

    public var body: some View {
        let bandColor = Palette.uvIndex(uv?.value ?? 0)
        return Gauge(value: Double(min(uv?.value ?? 0, 11)), in: 0...11) {
            // Per-band protection glyph (sun → sunglasses → warning → umbrella), tinted to the band.
            Image(systemName: uv?.glyph ?? "sun.max.fill")
                .foregroundStyle(bandColor)
        } currentValueLabel: {
            Text(uv.map { "\($0.value)" } ?? "—")
                .fontWeight(.semibold).fontDesign(.rounded)
                // Colour the index to its WHO band. Reads on full-colour faces; the Lock Screen
                // desaturates it while the ring fill keeps carrying the level.
                .foregroundStyle(bandColor)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(bandColor)
    }

    /// The WHO band name for the curved bezel label — honest about the value being a daily maximum.
    public var bandLabel: String? { uv?.bandName }
}

/// `.accessoryCorner` (Apple Watch): the day's max UV as the index number + band glyph in the corner,
/// with a curved 0–11 gauge along the outer bezel, tinted to the WHO band. The complication applies
/// `.widgetCurvesContent()` to the content and `.widgetLabel { cornerGauge }` for the arc.
public struct AuraUVCorner: View {
    let snapshot: WeatherSnapshot
    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    private var uv: UVIndex? { snapshot.uvIndex }

    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: uv?.glyph ?? "sun.max.fill")
            Text(uv.map { "\($0.value)" } ?? "—")
                .fontWeight(.bold).fontDesign(.rounded)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.title3)
        .foregroundStyle(Palette.uvIndex(uv?.value ?? 0))
    }

    /// Whether a UV value is known, so the bezel gauge can be drawn (else fall back to `cornerLabel`).
    public var hasValue: Bool { uv != nil }

    /// The curved bezel gauge: the index on the WHO 0–11 scale, band-tinted, with 0/11 at the ends. No
    /// `gaugeStyle` — the `.widgetLabel` context arcs it along the corner bezel.
    @ViewBuilder public var cornerGauge: some View {
        if let v = uv?.value {
            Gauge(value: Double(min(v, 11)), in: 0...11) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("11")
            }
            .tint(Palette.uvIndex(v))
        }
    }

    /// Fallback bezel label when UV is unknown.
    public var cornerLabel: String { uv.map { "UV \($0.value)" } ?? "UV —" }
}

/// `.accessoryCorner` (Apple Watch): the wind speed and the direction it comes from in the corner, with
/// a curved strength gauge (0–50 km/h, Windy-style strength ramp) along the outer bezel. Corner mate to
/// the circular `AuraWindCircular`.
public struct AuraWindCorner: View {
    let snapshot: WeatherSnapshot
    public init(snapshot: WeatherSnapshot) { self.snapshot = snapshot }

    private var speed: Int? { snapshot.windSpeed }

    public var body: some View {
        // One string so it scales as a unit rather than truncating the speed to "…" in a tight corner;
        // `.widgetCurvesContent()` gives it the full bezel arc on a real face.
        Text(label)
            .font(.title3).fontWeight(.bold).fontDesign(.rounded)
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(Palette.wind(speed))
    }

    /// "25 SO" — speed with the direction it comes from, or the speed alone when direction is unknown.
    private var label: String {
        let s = speed.map { "\($0)" } ?? "—"
        if let dir = snapshot.windDirection { return "\(s) \(dir.abbreviation)" }
        return s
    }

    /// Whether a speed is known, so the bezel gauge can be drawn (else fall back to `cornerLabel`).
    public var hasValue: Bool { speed != nil }

    /// The curved bezel gauge: the wind zoomed to the band that matters. The minimum is the floor of
    /// the Beaufort level **below** the current one (the "previous" step), the maximum is the hour's
    /// peak gust (**racha**), and the fill grades from the strength colour at that floor to the colour
    /// at the gust — so the arc reads "where the wind sits between the step below and today's gust"
    /// rather than against a flat 0–50 scale. Falls back to the current band's own ceiling when AEMET
    /// reports no gust.
    @ViewBuilder public var cornerGauge: some View {
        if let v = speed {
            let force = Beaufort.force(forKmh: v)
            let floor = Beaufort.scale[max(force - 1, 0)].lo
            let gust = snapshot.windGust
                ?? (Beaufort.scale[min(max(force, 0), Beaufort.scale.count - 1)].hi ?? v + 10)
            let hi = max(gust, v)                       // racha is always ≥ the sustained speed
            let lo = min(floor, hi - 1)                 // keep the range non-empty
            Gauge(value: Double(v), in: Double(lo)...Double(hi)) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("\(lo)")
            } maximumValueLabel: {
                Text("\(hi)")
            }
            .tint(Gradient(colors: [Palette.wind(lo), Palette.wind(hi)]))
        }
    }

    /// Fallback bezel label when the gauge is skipped — the speed with units.
    public var cornerLabel: String { speed.map { "\($0) km/h" } ?? "—" }
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
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))m" : "\(minutes)m"
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
    /// Denser, graduated 48-point rose (the phone card's nautical look) vs the plain 32-point ring —
    /// fewer marks, cheaper, and legible when desaturated. The Watch keeps the plain ring at both sizes.
    let dense: Bool
    /// A *card* spells the speed and direction out beside the rose, so the dial itself stays clean: a
    /// single needle read like a weather-vane, no number in the centre. A bare *complication* has no
    /// label beside it, so it keeps the speed big in the centre with two detached tips framing it. The
    /// phone and watch app cards are both cards; only the watch-face complication is not.
    let card: Bool

    public init(snapshot: WeatherSnapshot, dense: Bool = false, card: Bool = false) {
        self.snapshot = snapshot
        self.dense = dense
        self.card = card
    }

    public var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                WindRose(diameter: d, detailed: dense)

                // The arrow, over the rose. Rotated so the arrowhead sits at the "blows toward" bearing.
                if let towards = towardsDegrees {
                    vane(diameter: d)
                        .frame(width: d, height: d)
                        .rotationEffect(.degrees(towards))
                }

                // Centre. On the plain Watch dial (no speed shown beside it) the speed sits big and white
                // on the bare dial. The app card prints the speed and direction beside the rose, so there
                // the centre stays clear — just the arrow over a clean dial.
                centre(diameter: d)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The heading, in the wind-intensity colour. On a `card` it's a single slender needle through the
    /// whole dial — a long tapered half in full strength colour aimed where the wind blows *to*, an
    /// identically-shaped back half in the same colour dimmed for where it comes *from* — so it reads as
    /// one weather-vane, like a compass needle. The complication (which frames a centre number, so a full
    /// needle won't fit) keeps two detached tips: an arrowhead and a swallowtail. Drawn pointing up here;
    /// the caller rotates it to the "blows toward" bearing.
    @ViewBuilder private func vane(diameter d: CGFloat) -> some View {
        let color = Palette.wind(snapshot.windSpeed)
        ZStack {
            if card {
                WindNeedleHalf().fill(color)
                WindNeedleHalf().fill(color.opacity(0.34)).rotationEffect(.degrees(180))
            } else {
                WindHead().fill(color)
                WindTail().fill(color).rotationEffect(.degrees(180))
            }
        }
        .frame(width: d, height: d)
    }

    /// The dial centre. On a `card` the speed *and* the direction are already spelled out beside the rose
    /// ("25 km/h", "del Sudoeste"), so the centre stays clear — just the needle reads across a clean dial.
    /// On the Watch complication (no number beside it) the speed stays big and white here.
    @ViewBuilder private func centre(diameter d: CGFloat) -> some View {
        if !card {
            Text(snapshot.windSpeed.map { "\($0)" } ?? "—")
                .font(.system(size: d * 0.38, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 1)
        }
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
    /// Detailed mode halves the base grid to 7.5° (a 48-point ring), for the app card's nautical look.
    var detailed: Bool = false

    /// Radius, as a fraction of the diameter, of the outer tip of every mark — the ring the marks and
    /// the cardinal letters share, and the ring the arrow's tips reach.
    static let markRingRadiusFactor: CGFloat = 0.485

    var body: some View {
        let d = diameter
        let step = detailed ? 7.5 : 11.25
        ZStack {
            // Compass points every `step`°. Skip the cardinals — there the letter is the mark. Three tiers
            // by importance: inter-cardinals (45°) longest and brightest, the 16-point marks (22.5°)
            // medium, the finer points short and light. Detailed mode adds the 7.5° graduations.
            ForEach(Array(stride(from: 0.0, to: 360.0, by: step)), id: \.self) { (deg: Double) in
                if deg.truncatingRemainder(dividingBy: 90) != 0 {
                    let tier = Self.tier(deg: deg)
                    mark(bearing: deg, length: d * tier.length, width: d * tier.width,
                         color: Color(white: tier.shade), d: d)
                }
            }
            // Cardinal letters — bright white, ON the mark ring and vertically middle-aligned with the
            // marks that surround them (they ARE the cardinal marks, no tick beside them). E and O sit a
            // touch further out than N and S so they stay readable when the arrow lies over them.
            letter("N", dx: 0, dy: -1, rf: 0.45, d: d)
            letter("E", dx: 1, dy: 0, rf: 0.47, d: d)
            letter("S", dx: 0, dy: 1, rf: 0.43, d: d)
            letter("O", dx: -1, dy: 0, rf: 0.45, d: d)
        }
        .frame(width: d, height: d)
    }

    /// The size/shade tier for a mark at `deg` (as fractions of the diameter): inter-cardinals longest
    /// and brightest, 16-point marks medium, the finest points short and dim.
    private static func tier(deg: Double) -> (length: CGFloat, width: CGFloat, shade: Double) {
        if deg.truncatingRemainder(dividingBy: 45) == 0 {
            return (0.11, 0.020, 0.95)      // inter-cardinal (NE/SE/SW/NW)
        } else if deg.truncatingRemainder(dividingBy: 22.5) == 0 {
            return (0.075, 0.016, 0.80)     // 16-point
        } else {
            return (0.05, 0.012, 0.62)      // finer points — was 0.38, too dark on the sky
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

    /// One upright cardinal letter at radius `rf`·d (dx/dy are unit offsets, not rotated). A fixed
    /// square frame centres the glyph so N/E/S/O share one baseline and sit in the middle of the marks
    /// around them, instead of each drifting by its own line-box metrics.
    private func letter(_ s: String, dx: CGFloat, dy: CGFloat, rf: CGFloat, d: CGFloat) -> some View {
        let r = d * rf
        return Text(s)
            .font(.system(size: d * 0.14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: d * 0.16, height: d * 0.16)
            .offset(x: dx * r, y: dy * r)
    }
}

/// The arrowhead mark alone: a solid triangle pointing up, its tip on the mark ring and its base a short
/// way in. Drawn in a d×d square; the caller rotates it to the "blows toward" bearing. No shaft — it is
/// one of the two detached tips.
private struct WindHead: Shape {
    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        let cx = rect.midX, cy = rect.midY
        let r = d * WindRose.markRingRadiusFactor      // tip sits on the mark ring
        let depth = d * 0.20                           // how far the head reaches inward
        let half = d * 0.11                            // barb half-width
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - r))
        path.addLine(to: CGPoint(x: cx + half, y: cy - (r - depth)))
        path.addLine(to: CGPoint(x: cx - half, y: cy - (r - depth)))
        path.closeSubpath()
        return path
    }
}

/// The swallowtail mark alone: a forked fishtail pointing up, its two outer points on the mark ring with
/// a centre V notch, narrowing to a small base a short way in. Drawn in a d×d square; the caller rotates
/// it to the "comes from" bearing. No shaft — the other detached tip.
private struct WindTail: Shape {
    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        let cx = rect.midX, cy = rect.midY
        let r = d * WindRose.markRingRadiusFactor      // outer points sit on the mark ring
        let depth = d * 0.17                           // how far the tail reaches inward
        let half = d * 0.11                            // fork half-width
        let baseHalf = d * 0.03                        // narrow inner base
        let notch = d * 0.085                          // how far the centre V bites in
        var path = Path()
        path.move(to: CGPoint(x: cx - half, y: cy - r))
        path.addLine(to: CGPoint(x: cx, y: cy - (r - notch)))
        path.addLine(to: CGPoint(x: cx + half, y: cy - r))
        path.addLine(to: CGPoint(x: cx + baseHalf, y: cy - (r - depth)))
        path.addLine(to: CGPoint(x: cx - baseHalf, y: cy - (r - depth)))
        path.closeSubpath()
        return path
    }
}

/// One half of the app card's needle: a long slender triangle from a small base at the dial centre to a
/// point on the mark ring. Drawn pointing up; the caller fills it (full colour for the "blows toward"
/// half, dimmed for the "comes from" half rotated 180°) so the two halves share the centre base and read
/// as a single continuous needle, widest through the middle and tapering to a point at each rim.
private struct WindNeedleHalf: Shape {
    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        let cx = rect.midX, cy = rect.midY
        let r = d * WindRose.markRingRadiusFactor      // tip sits on the mark ring
        let halfW = d * 0.05                           // half-width at the centre (widest point)
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - r))       // tip at the rim
        path.addLine(to: CGPoint(x: cx + halfW, y: cy))// base, right of centre
        path.addLine(to: CGPoint(x: cx - halfW, y: cy))// base, left of centre
        path.closeSubpath()
        return path
    }
}
