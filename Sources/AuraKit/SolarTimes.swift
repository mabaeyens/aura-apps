import Foundation

/// Sunrise and sunset computed with the NOAA solar equations.
///
/// Pure, offline, deterministic; reproduces the Observatorio Astronómico Nacional /
/// Real Observatorio de la Armada published orto/ocaso tables to within a minute.
/// Times are returned as absolute `Date` values (UTC instants); format them in the
/// location's time zone for display.
public struct SolarTimes: Sendable {
    /// nil during polar night/day (the sun does not cross the horizon that day).
    public let sunrise: Date?
    public let sunset: Date?

    /// Civil twilight: the moments the sun's centre is 6° below the horizon — morning first light and
    /// evening last light, the "bright enough to be out without lamps" window bracketing orto/ocaso.
    /// nil when the sun never reaches −6° that day (a high-latitude summer with no true dark).
    public let civilDawn: Date?
    public let civilDusk: Date?

    /// - Parameters:
    ///   - date: any instant on the target day.
    ///   - latitude: degrees north, positive.
    ///   - longitude: degrees east, positive (Spain is negative).
    public init(date: Date, latitude: Double, longitude: Double) {
        let rad = Double.pi / 180

        let julianDate = date.timeIntervalSince1970 / 86_400.0 + 2_440_587.5
        let n = (julianDate - 2_451_545.0 + 0.0008).rounded()

        let westLongitude = -longitude
        let meanSolarTime = n + westLongitude / 360.0

        let meanAnomaly = (357.5291 + 0.98560028 * meanSolarTime).truncatingRemainder(dividingBy: 360)
        let m = meanAnomaly * rad
        let center = 1.9148 * sin(m) + 0.0200 * sin(2 * m) + 0.0003 * sin(3 * m)
        let eclipticLongitude = (meanAnomaly + center + 180 + 102.9372).truncatingRemainder(dividingBy: 360)
        let lambda = eclipticLongitude * rad

        let transit = 2_451_545.0 + meanSolarTime + 0.0053 * sin(m) - 0.0069 * sin(2 * lambda)
        let declination = asin(sin(lambda) * sin(23.4397 * rad))
        let phi = latitude * rad

        // Sunrise/sunset take the standard −0.833° (atmospheric refraction plus the sun's radius); civil
        // twilight is the same solve at −6°. Both share the transit, declination and latitude above.
        let (sr, ss) = Self.crossings(altitudeDeg: -0.833, transit: transit, phi: phi, declination: declination)
        self.sunrise = sr
        self.sunset = ss
        let (dawn, dusk) = Self.crossings(altitudeDeg: -6, transit: transit, phi: phi, declination: declination)
        self.civilDawn = dawn
        self.civilDusk = dusk
    }

    /// The morning and evening instants the sun's centre passes `altitudeDeg`, or (nil, nil) when it never
    /// reaches that altitude on the day (polar night/day, or twilight that doesn't complete at that
    /// latitude and season). `transit` is the solar-noon Julian date; `phi`/`declination` in radians.
    private static func crossings(altitudeDeg: Double, transit: Double, phi: Double,
                                  declination: Double) -> (Date?, Date?) {
        let rad = Double.pi / 180
        let cosHourAngle = (sin(altitudeDeg * rad) - sin(phi) * sin(declination)) / (cos(phi) * cos(declination))
        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return (nil, nil) }
        let hourAngle = acos(cosHourAngle) / rad // degrees
        return (date(fromJulian: transit - hourAngle / 360.0),
                date(fromJulian: transit + hourAngle / 360.0))
    }

    private static func date(fromJulian jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400.0)
    }
}
