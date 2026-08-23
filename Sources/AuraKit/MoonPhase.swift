import SwiftUI

/// Lunar phase from a date, by the mean synodic month. Accurate to ~a day — plenty for a night disc that
/// only has to *look* like tonight's moon and for "next new/full" countdowns. Shared by the app (the
/// `AuraSky` night disc and the moon card) and the `aura-render` tool, so there's one source of truth.
///
/// `illumination` 0 (new) → 1 (full); `waxing` true while the lit limb grows (lit on the right in the
/// northern hemisphere, which is all Aura targets); `fraction` 0…1 around the whole cycle from new moon.
public enum MoonPhaseMath {
    /// Days, new moon to new moon.
    public static let synodicMonth = 29.530588853

    /// A known new moon: 2000-01-06 18:14 UTC.
    public static let referenceNewMoon: Date = {
        var c = DateComponents()
        c.year = 2000; c.month = 1; c.day = 6; c.hour = 18; c.minute = 14
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date(timeIntervalSince1970: 0)
    }()

    /// Position in the cycle, 0 (new) … 0.5 (full) … 1 (new again).
    public static func fraction(for date: Date) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let p = days.truncatingRemainder(dividingBy: synodicMonth) / synodicMonth
        return p < 0 ? p + 1 : p
    }

    /// Illuminated fraction of the disc, 0 (new) … 1 (full).
    public static func illumination(fraction p: Double) -> Double { (1 - cos(2 * .pi * p)) / 2 }

    /// The lit limb grows (waxing) through the first half of the cycle.
    public static func waxing(fraction p: Double) -> Bool { p < 0.5 }

    /// The eight principal phases with Spanish labels, evenly around the cycle.
    public static let principalPhases: [(name: String, fraction: Double)] = [
        ("Luna nueva",       0.000),
        ("Creciente",        0.125),
        ("Cuarto creciente", 0.250),
        ("Gibosa creciente", 0.375),
        ("Luna llena",       0.500),
        ("Gibosa menguante", 0.625),
        ("Cuarto menguante", 0.750),
        ("Menguante",        0.875),
    ]

    /// The Spanish phase name for a fraction — the nearest of the eight principal phases, each owning a
    /// 1/8 window centred on its fraction (so "Luna nueva" spans 0.9375…0.0625 across the wrap).
    public static func phaseName(fraction p: Double) -> String {
        let idx = Int((p * 8).rounded()) % 8
        return principalPhases[idx].name
    }

    /// The next new moon at or after `date` (the mean-synodic estimate; ~a day's accuracy).
    public static func nextNewMoon(from date: Date) -> Date {
        let p = fraction(for: date)
        // Fraction still to run before the cycle returns to new (p = 1 ≡ 0). At exactly new, jump a whole
        // cycle so "next" is always in the future.
        let remaining = p <= 0 ? 1 : 1 - p
        return date.addingTimeInterval(remaining * synodicMonth * 86_400)
    }

    /// The next full moon at or after `date` (full is fraction 0.5).
    public static func nextFullMoon(from date: Date) -> Date {
        let p = fraction(for: date)
        let remaining = p < 0.5 ? 0.5 - p : 1.5 - p
        return date.addingTimeInterval(remaining * synodicMonth * 86_400)
    }
}

/// A moon disc drawn at the given illumination. The dark body is always present — a neutral ashen grey, so
/// a new moon reads as a dim earthshine-lit disc rather than nothing — and the lit region is painted bright
/// on top, bounded by the elliptical terminator `x = (1 − 2·illum)·√(R²−y²)`. Waning mirrors the lit limb
/// to the left. Northern-hemisphere only (Spain): waxing is always lit on the right.
public struct PhasedMoonDisc: View {
    public let illumination: Double   // 0 new … 1 full
    public let waxing: Bool           // lit limb on the right when true
    public let radius: CGFloat
    /// Optional tint for the lit limb (a night sky reads it faintly cool). Defaults to a neutral near-white.
    public var litColor: Color

    public init(illumination: Double, waxing: Bool, radius: CGFloat,
                litColor: Color = Color(white: 0.96)) {
        self.illumination = illumination; self.waxing = waxing
        self.radius = radius; self.litColor = litColor
    }

    public var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = radius
            let k = min(max(illumination, 0), 1)

            // The dark body — earthshine, a neutral grey (kept close to the real ashen tone), so a new moon
            // is a visible-but-unlit disc.
            let body = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
            ctx.fill(body, with: .color(Color(white: 0.16)))
            ctx.stroke(body, with: .color(Color(white: 0.45).opacity(0.4)),
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
            ctx.fill(lit, with: .color(litColor))
        }
        .frame(width: radius * 3, height: radius * 3)
        .scaleEffect(x: waxing ? 1 : -1, y: 1)   // mirror the lit limb for the waning half
    }
}
