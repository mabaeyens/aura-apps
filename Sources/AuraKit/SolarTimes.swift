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
        let cosHourAngle = (sin(-0.833 * rad) - sin(phi) * sin(declination)) / (cos(phi) * cos(declination))

        guard cosHourAngle >= -1, cosHourAngle <= 1 else {
            self.sunrise = nil
            self.sunset = nil
            return
        }

        let hourAngle = acos(cosHourAngle) / rad // degrees
        self.sunrise = Self.date(fromJulian: transit - hourAngle / 360.0)
        self.sunset = Self.date(fromJulian: transit + hourAngle / 360.0)
    }

    private static func date(fromJulian jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400.0)
    }
}
