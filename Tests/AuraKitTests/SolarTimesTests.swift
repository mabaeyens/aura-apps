import XCTest
@testable import AuraKit

final class SolarTimesTests: XCTestCase {

    private func utcDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 0))!
    }

    private func utcHour(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.component(.hour, from: date)
    }

    // At the equator on the equinox the day is ~12h and sunrise is near 06:00 local solar time.
    func testEquinoxAtEquator() {
        let s = SolarTimes(date: utcDay(2024, 3, 20), latitude: 0, longitude: 0)
        let sunrise = try! XCTUnwrap(s.sunrise)
        let sunset = try! XCTUnwrap(s.sunset)
        let dayLengthHours = sunset.timeIntervalSince(sunrise) / 3600
        XCTAssertEqual(dayLengthHours, 12, accuracy: 0.3)
        XCTAssertTrue(utcHour(sunrise) == 5 || utcHour(sunrise) == 6)
    }

    // Madrid, summer solstice: sunrise before sunset, both exist.
    func testMadridOrdering() {
        let s = SolarTimes(date: utcDay(2024, 6, 21), latitude: 40.4168, longitude: -3.7038)
        let sunrise = try! XCTUnwrap(s.sunrise)
        let sunset = try! XCTUnwrap(s.sunset)
        XCTAssertLessThan(sunrise, sunset)
        // Madrid summer day is long (>14h).
        XCTAssertGreaterThan(sunset.timeIntervalSince(sunrise) / 3600, 14)
    }

    // High Arctic in December: polar night, no sunrise.
    func testPolarNight() {
        let s = SolarTimes(date: utcDay(2024, 12, 21), latitude: 89, longitude: 0)
        XCTAssertNil(s.sunrise)
        XCTAssertNil(s.sunset)
    }
}
