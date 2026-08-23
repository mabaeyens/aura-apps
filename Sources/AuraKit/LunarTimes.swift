import Foundation

/// The Moon's true position, illuminated fraction, and today's moonrise/moonset for a location.
///
/// Uses Schlyter's abbreviated lunar theory (the main dozen perturbation terms): good to a few
/// arcminutes in position and a couple of minutes in rise/set time, which is all a "tonight's moon"
/// readout needs. Unlike `MoonPhaseMath` (the mean synodic cycle, which drives the night-sky disc), this
/// carries the *true* elongation from the Sun, so the sheet's "% iluminada" is the real figure, and the
/// real horizon crossings give honest moonrise/moonset. Angles are handled in degrees internally.
public struct LunarPosition {
    /// Geocentric apparent right ascension and declination of date, in degrees.
    public let rightAscension: Double
    public let declination: Double
    /// The Moon's equatorial horizontal parallax, in degrees (drives the rise/set target altitude).
    public let parallax: Double
    /// The Sun's mean longitude at this instant, in degrees — the reference for local sidereal time.
    public let sunMeanLongitude: Double
    /// Illuminated fraction of the disc, 0 (new) … 1 (full), from the true Sun–Moon elongation.
    public let illumination: Double
    /// True while the Moon is east of the Sun (the lit limb growing).
    public let waxing: Bool

    // Degree-based trig helpers.
    private static func rev(_ x: Double) -> Double { let r = x.truncatingRemainder(dividingBy: 360); return r < 0 ? r + 360 : r }
    private static func sind(_ d: Double) -> Double { sin(d * .pi / 180) }
    private static func cosd(_ d: Double) -> Double { cos(d * .pi / 180) }
    private static func atan2d(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }
    private static func asind(_ x: Double) -> Double { asin(min(max(x, -1), 1)) * 180 / .pi }
    private static func acosd(_ x: Double) -> Double { acos(min(max(x, -1), 1)) * 180 / .pi }

    public init(date: Date) {
        let sind = Self.sind, cosd = Self.cosd, rev = Self.rev

        // Days since Schlyter's epoch 1999-12-31 00:00 UT (JD 2451543.5), with fractional UT.
        let jd = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let d = jd - 2_451_543.5

        // --- Sun: needed for the Moon's perturbations, for the elongation, and for sidereal time. ---
        let ws = 282.9404 + 4.70935e-5 * d          // longitude of perihelion
        let Ms = rev(356.0470 + 0.9856002585 * d)    // mean anomaly
        let es = 0.016709 - 1.151e-9 * d
        let Ls = rev(ws + Ms)                         // Sun's mean longitude
        // Sun's true longitude via its equation of centre.
        let Es = Ms + es * (180 / .pi) * sind(Ms) * (1 + es * cosd(Ms))
        let xs = cosd(Es) - es
        let ys = sqrt(1 - es * es) * sind(Es)
        let vs = Self.atan2d(ys, xs)
        let lonSun = rev(vs + ws)

        // --- Moon orbital elements. ---
        let N = rev(125.1228 - 0.0529538083 * d)     // longitude of ascending node
        let i = 5.1454
        let w = rev(318.0634 + 0.1643573223 * d)     // argument of perigee
        let a = 60.2666                              // semi-major axis, in Earth radii
        let e = 0.054900
        let M = rev(115.3654 + 13.0649929509 * d)    // mean anomaly

        // Kepler, iterated (the Moon's e is small but not negligible).
        var E = M + e * (180 / .pi) * sind(M) * (1 + e * cosd(M))
        for _ in 0..<3 {
            E = E - (E - e * (180 / .pi) * sind(E) - M) / (1 - e * cosd(E))
        }
        let x = a * (cosd(E) - e)
        let y = a * sqrt(1 - e * e) * sind(E)
        let r0 = sqrt(x * x + y * y)                 // distance, Earth radii (pre-perturbation)
        let v = rev(Self.atan2d(y, x))

        // Position in the ecliptic (geocentric), from the orbital plane.
        let xeclip = r0 * (cosd(N) * cosd(v + w) - sind(N) * sind(v + w) * cosd(i))
        let yeclip = r0 * (sind(N) * cosd(v + w) + cosd(N) * sind(v + w) * cosd(i))
        let zeclip = r0 * (sind(v + w) * sind(i))
        var lon = rev(Self.atan2d(yeclip, xeclip))
        var lat = Self.atan2d(zeclip, sqrt(xeclip * xeclip + yeclip * yeclip))

        // --- Perturbations (the terms that matter at arcminute level). ---
        let Lm = rev(N + w + M)      // Moon's mean longitude
        let D = rev(Lm - Ls)         // mean elongation
        let F = rev(Lm - N)          // argument of latitude

        lon += -1.274 * sind(M - 2 * D)      // evection
              + 0.658 * sind(2 * D)          // variation
              - 0.186 * sind(Ms)             // yearly equation
              - 0.059 * sind(2 * M - 2 * D)
              - 0.057 * sind(M - 2 * D + Ms)
              + 0.053 * sind(M + 2 * D)
              + 0.046 * sind(2 * D - Ms)
              + 0.041 * sind(M - Ms)
              - 0.035 * sind(D)              // parallactic equation
              - 0.031 * sind(M + Ms)
              - 0.015 * sind(2 * F - 2 * D)
              + 0.011 * sind(M - 4 * D)
        lat += -0.173 * sind(F - 2 * D)
              - 0.055 * sind(M - F - 2 * D)
              - 0.046 * sind(M + F - 2 * D)
              + 0.033 * sind(F + 2 * D)
              + 0.017 * sind(2 * M + F)
        let r = r0 - 0.58 * cosd(M - 2 * D) - 0.46 * cosd(2 * D)   // distance, Earth radii
        lon = rev(lon)

        // --- Ecliptic → equatorial, obliquity of date. ---
        let ecl = 23.4393 - 3.563e-7 * d
        let xg = cosd(lon) * cosd(lat)
        let yg = sind(lon) * cosd(lat)
        let zg = sind(lat)
        let xe = xg
        let ye = yg * cosd(ecl) - zg * sind(ecl)
        let ze = yg * sind(ecl) + zg * cosd(ecl)
        self.rightAscension = rev(Self.atan2d(ye, xe))
        self.declination = Self.atan2d(ze, sqrt(xe * xe + ye * ye))
        self.parallax = Self.asind(1 / r)            // horizontal parallax
        self.sunMeanLongitude = Ls

        // --- Illuminated fraction, from the true elongation (Sun on the ecliptic, lat ≈ 0). ---
        let elong = Self.acosd(cosd(lon - lonSun) * cosd(lat))
        self.illumination = (1 - cosd(elong)) / 2
        // East of the Sun (0…180° of elongation ahead) → waxing.
        self.waxing = rev(lon - lonSun) < 180
    }

    /// Geocentric altitude of the Moon's centre, in degrees, seen from (`latitude`, `longitude`) — used to
    /// find the horizon crossings. Longitude is east-positive.
    func altitude(latitude: Double, longitude: Double, at date: Date) -> Double {
        let sind = Self.sind, cosd = Self.cosd
        let utHours = (date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400)) / 3_600
        let ut = utHours < 0 ? utHours + 24 : utHours
        let gmst0 = (sunMeanLongitude + 180) / 15          // sidereal time at Greenwich 0h, in hours
        let lst = gmst0 + ut + longitude / 15               // local sidereal time, hours
        let ha = Self.rev(lst * 15 - rightAscension)        // hour angle, degrees
        return Self.asind(sind(latitude) * sind(declination)
                          + cosd(latitude) * cosd(declination) * cosd(ha))
    }
}

/// Today's moonrise and moonset for a location, from `LunarPosition`. Reports the appearance the Moon is
/// currently in (or the next one): if the Moon is up now, `rise` is the crossing that began it and `set`
/// the crossing that ends it; if it's down, `rise` is the next crossing up and `set` the one after. Either
/// can be nil on the rare day the Moon doesn't cross (once a month it skips a calendar day).
public struct LunarTimes {
    public let moonrise: Date?
    public let moonset: Date?

    public init(date now: Date, latitude: Double, longitude: Double) {
        // The Moon's rise/set target altitude folds in its parallax, semidiameter and refraction (Meeus):
        // h0 = 0.7275·parallax − 34′. Recomputed per sample since the parallax drifts through the month.
        func target(_ p: LunarPosition) -> Double { 0.7275 * p.parallax - 0.5667 }

        // Scan a window bracketing `now` at a fine step and collect every upward (rise) and downward (set)
        // crossing of (altitude − target), interpolating each crossing linearly.
        let step: TimeInterval = 5 * 60
        let start = now.addingTimeInterval(-24 * 3_600)
        let count = Int((54 * 3_600) / step)              // -24 h … +30 h

        var rises: [Date] = []
        var sets: [Date] = []
        var prev = start
        var prevPos = LunarPosition(date: prev)
        var prevDiff = prevPos.altitude(latitude: latitude, longitude: longitude, at: prev) - target(prevPos)
        for k in 1...count {
            let t = start.addingTimeInterval(step * Double(k))
            let pos = LunarPosition(date: t)
            let diff = pos.altitude(latitude: latitude, longitude: longitude, at: t) - target(pos)
            if prevDiff < 0, diff >= 0 {                  // crossing up → rise
                rises.append(Self.interp(prev, prevDiff, t, diff))
            } else if prevDiff >= 0, diff < 0 {           // crossing down → set
                sets.append(Self.interp(prev, prevDiff, t, diff))
            }
            prev = t; prevDiff = diff; _ = pos
        }

        // Is the Moon up right now? Pick the coherent rise/set pair around `now`.
        let posNow = LunarPosition(date: now)
        let up = posNow.altitude(latitude: latitude, longitude: longitude, at: now) - target(posNow) >= 0
        if up {
            self.moonrise = rises.last { $0 <= now }
            self.moonset = sets.first { $0 > now }
        } else {
            let nextRise = rises.first { $0 > now }
            self.moonrise = nextRise
            self.moonset = nextRise.flatMap { r in sets.first { $0 > r } }
        }
    }

    private static func interp(_ t0: Date, _ d0: Double, _ t1: Date, _ d1: Double) -> Date {
        let f = d0 / (d0 - d1)                             // where diff hits zero between the samples
        return t0.addingTimeInterval(t1.timeIntervalSince(t0) * f)
    }
}
