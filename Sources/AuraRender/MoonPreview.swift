import AuraKit
import SwiftUI

// PROTOTYPE — not shipped, not wired into AuraSky yet. A phased moon disc whose shape follows the real
// lunar phase and whose brightness (disc + glow) scales with illumination: a new moon is a dim dark
// object with almost no glow, a full moon a bright white disc with a strong cool glow, and the days
// between show crescents, quarters and gibbous limbs. Rendered by `aura-render` so the idea can be
// judged as an image before touching the live sky. If it lands, the phased disc replaces the flat
// silver full-moon in `AuraSky` section 3.5.

// MARK: - Phase math

/// Lunar phase from a date, by the mean synodic month. Accurate to ~a day — plenty for a glow that only
/// has to *look* like tonight's moon. `illumination` 0 (new) → 1 (full); `waxing` true while the lit
/// limb grows (lit on the right in the northern hemisphere); `fraction` 0…1 around the whole cycle.
struct MoonPhaseMath {
    static let synodicMonth = 29.530588853   // days, new moon to new moon

    /// A known new moon: 2000-01-06 18:14 UTC.
    static let referenceNewMoon: Date = {
        var c = DateComponents()
        c.year = 2000; c.month = 1; c.day = 6; c.hour = 18; c.minute = 14
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date(timeIntervalSince1970: 0)
    }()

    static func fraction(for date: Date) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let p = (days.truncatingRemainder(dividingBy: synodicMonth)) / synodicMonth
        return p < 0 ? p + 1 : p
    }

    /// Illuminated fraction of the disc, 0 (new) … 1 (full).
    static func illumination(fraction p: Double) -> Double { (1 - cos(2 * .pi * p)) / 2 }

    /// The eight principal phases with Spanish labels (Aura is Spanish), evenly around the cycle.
    static let principalPhases: [(name: String, fraction: Double)] = [
        ("Nueva",            0.000),
        ("Creciente",        0.125),
        ("Cuarto creciente", 0.250),
        ("Gibosa crec.",     0.375),
        ("Llena",            0.500),
        ("Gibosa meng.",     0.625),
        ("Cuarto meng.",     0.750),
        ("Menguante",        0.875),
    ]
}

// MARK: - The phased disc

/// A moon disc drawn at the given illumination. The dark body is always present (a faint cool-grey, so a
/// new moon reads as a dim object rather than nothing); the lit region is painted bright on top, bounded
/// by the elliptical terminator `x = (1 − 2·illum)·√(R²−y²)`. Waning flips the lit limb to the left.
struct PhasedMoon: View {
    let illumination: Double   // 0 new … 1 full
    let waxing: Bool           // lit limb on the right when true
    let radius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = radius
            let k = min(max(illumination, 0), 1)

            // The dark body — earthshine. Dim and cool, so a new moon is a visible-but-unlit disc.
            let body = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
            ctx.fill(body, with: .color(Color(red: 0.09, green: 0.11, blue: 0.19).opacity(0.92)))
            ctx.stroke(body, with: .color(Color(red: 0.34, green: 0.40, blue: 0.60).opacity(0.45)),
                       lineWidth: max(0.5, R * 0.02))

            // The lit region: down the terminator, up the outer limb, closed.
            var lit = Path()
            let n = 72
            lit.move(to: CGPoint(x: c.x, y: c.y - R))
            for i in 0...n {                                   // terminator, top → bottom
                let y = -R + 2 * R * CGFloat(i) / CGFloat(n)
                let w = sqrt(max(R * R - y * y, 0))
                let xt = (1 - 2 * CGFloat(k)) * w
                lit.addLine(to: CGPoint(x: c.x + xt, y: c.y + y))
            }
            for i in stride(from: n, through: 0, by: -1) {     // outer limb, bottom → top
                let y = -R + 2 * R * CGFloat(i) / CGFloat(n)
                let w = sqrt(max(R * R - y * y, 0))
                lit.addLine(to: CGPoint(x: c.x + w, y: c.y + y))
            }
            lit.closeSubpath()
            ctx.fill(lit, with: .color(Color(red: 0.97, green: 0.98, blue: 1.0)))
        }
        .frame(width: radius * 3, height: radius * 3)
        .scaleEffect(x: waxing ? 1 : -1, y: 1)   // mirror the lit limb for the waning half
    }
}

/// The moon over a night sky: a cool glow whose strength tracks illumination (new ≈ dark, full ≈ bright),
/// the phased disc, and a scatter of stars. A compact stand-in for `AuraSky`'s night, just enough to
/// judge the phased disc and the "gloom vs moonlight" glow.
struct MoonNightSky: View {
    let fraction: Double
    var discRadius: CGFloat = 26
    var position: UnitPoint = .init(x: 0.5, y: 0.32)

    private var illum: Double { MoonPhaseMath.illumination(fraction: fraction) }
    private var waxing: Bool { fraction < 0.5 }

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: position.x * geo.size.width, y: position.y * geo.size.height)
            ZStack {
                LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.14),
                                        Color(red: 0.06, green: 0.09, blue: 0.20)],
                               startPoint: .top, endPoint: .bottom)

                // Stars, dimmed as the moon brightens (a full moon washes them out).
                Canvas { ctx, sz in
                    var rng: UInt64 = 0x9E3779B97F4A7C15
                    func rnd() -> Double { rng = rng &* 6364136223846793005 &+ 1442695040888963407
                                           return Double(rng >> 11) / Double(1 << 53) }
                    for _ in 0..<80 {
                        let p = CGPoint(x: rnd() * sz.width, y: rnd() * sz.height * 0.8)
                        let r = 0.5 + rnd() * 1.0
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: r, height: r)),
                                 with: .color(.white.opacity(0.5)))
                    }
                }
                .opacity(1 - illum * 0.7)

                // The cool glow — strength tracks moonlight, with a dim floor so a new moon still reads.
                RadialGradient(colors: [Color(red: 0.78, green: 0.82, blue: 0.98)
                                            .opacity(0.10 + illum * 0.5),
                                        Color(red: 0.78, green: 0.82, blue: 0.98).opacity(0)],
                               center: position, startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) * 0.6)

                PhasedMoon(illumination: illum, waxing: waxing, radius: discRadius)
                    .position(centre)
            }
        }
    }
}

// MARK: - Preview compositions (rendered from main.swift)

/// All eight principal phases in a row, each over its own night sky, labelled with phase name and %.
@MainActor
func moonPhaseChart() -> some View {
    HStack(spacing: 0) {
        ForEach(Array(MoonPhaseMath.principalPhases.enumerated()), id: \.offset) { _, ph in
            let illum = MoonPhaseMath.illumination(fraction: ph.fraction)
            VStack(spacing: 6) {
                MoonNightSky(fraction: ph.fraction, discRadius: 22)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(ph.name)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text("\(Int((illum * 100).rounded()))%")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)
        }
    }
    .padding(20)
    .background(Color(white: 0.06))
    .environment(\.colorScheme, .dark)
}

/// One phase (a waxing crescent) traversing the arc east → high → west, so the movement reads.
@MainActor
func moonTraverse(fraction: Double, positions: [UnitPoint]) -> some View {
    HStack(spacing: 10) {
        ForEach(Array(positions.enumerated()), id: \.offset) { _, pos in
            MoonNightSky(fraction: fraction, discRadius: 20, position: pos)
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    .padding(20)
    .background(Color(white: 0.06))
    .environment(\.colorScheme, .dark)
}

/// Tonight's actual moon, big, with its label.
@MainActor
func moonTonight(now: Date) -> some View {
    let f = MoonPhaseMath.fraction(for: now)
    let illum = MoonPhaseMath.illumination(fraction: f)
    return VStack(spacing: 10) {
        MoonNightSky(fraction: f, discRadius: 46)
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        Text("Esta noche · \(Int((illum * 100).rounded()))% iluminada")
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
    }
    .padding(20)
    .background(Color(white: 0.06))
    .environment(\.colorScheme, .dark)
}
