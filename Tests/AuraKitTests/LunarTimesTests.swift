import XCTest
@testable import AuraKit

/// Pinned against timeanddate.com for Madrid (40.4168°N, 3.7038°W), 2026-08-23: the Moon is a waxing
/// gibbous 80.2% illuminated, next full 28 Aug, next new 11 Sep, and moonrise that day is 18:34 local
/// (Europe/Madrid, UTC+2 in August → 16:34 UTC).
final class LunarTimesTests: XCTestCase {

    private let madridLat = 40.4168
    private let madridLon = -3.7038

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testIlluminationMatchesReference() {
        // 2026-08-23 14:17 local = 12:17 UTC: reference says 80.2% illuminated, waxing.
        let p = LunarPosition(date: utc(2026, 8, 23, 12, 17))
        XCTAssertEqual(p.illumination, 0.802, accuracy: 0.03)
        XCTAssertTrue(p.waxing)
    }

    func testFullMoonIsFullyLit() {
        // Next full moon: 28 Aug 2026 06:18 local = 04:18 UTC.
        let p = LunarPosition(date: utc(2026, 8, 28, 4, 18))
        XCTAssertGreaterThan(p.illumination, 0.99)
    }

    func testNewMoonIsDark() {
        // Next new moon: 11 Sep 2026 05:27 local = 03:27 UTC.
        let p = LunarPosition(date: utc(2026, 9, 11, 3, 27))
        XCTAssertLessThan(p.illumination, 0.02)
    }

    func testDeclinationInRange() {
        // Sanity: the Moon's declination stays within its ~±28.6° envelope.
        let p = LunarPosition(date: utc(2026, 8, 23, 12, 17))
        XCTAssertLessThan(abs(p.declination), 28.6)
    }

    func testMoonriseMatchesReference() {
        // At 12:00 UTC the Moon is below the horizon in Madrid; the next rise is the day's moonrise,
        // reference 16:34 UTC. Allow a few minutes for the abbreviated theory.
        let t = LunarTimes(date: utc(2026, 8, 23, 12, 0), latitude: madridLat, longitude: madridLon)
        let rise = try? XCTUnwrap(t.moonrise)
        XCTAssertNotNil(rise)
        if let rise {
            let expected = utc(2026, 8, 23, 16, 34)
            XCTAssertEqual(rise.timeIntervalSince(expected), 0, accuracy: 8 * 60)
        }
    }

    func testMoonsetAfterMoonrise() {
        // A waxing-gibbous Moon rising in the evening sets after midnight: set must follow the rise.
        let t = LunarTimes(date: utc(2026, 8, 23, 12, 0), latitude: madridLat, longitude: madridLon)
        if let rise = t.moonrise, let set = t.moonset {
            XCTAssertGreaterThan(set, rise)
            // And within a reasonable window (the Moon is up ~10–11 h near full).
            XCTAssertLessThan(set.timeIntervalSince(rise), 14 * 3_600)
        } else {
            XCTFail("expected both a rise and a set")
        }
    }

    func testMoonUpReturnsPastRise() {
        // At 22:00 UTC on 23 Aug the Moon is well up (rose 16:34); the reported rise is that past crossing,
        // and the set is still ahead.
        let now = utc(2026, 8, 23, 22, 0)
        let t = LunarTimes(date: now, latitude: madridLat, longitude: madridLon)
        if let rise = t.moonrise, let set = t.moonset {
            XCTAssertLessThan(rise, now)
            XCTAssertGreaterThan(set, now)
        } else {
            XCTFail("expected a current appearance's rise and set")
        }
    }
}
