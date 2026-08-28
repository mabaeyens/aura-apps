import XCTest
@testable import AuraKit

/// The hero must lead with the nearest station's **measured** temperature, fall back to the hourly
/// forecast, and only show "—" when there is neither — at which point "—" genuinely means "no data at
/// all", not "the hourly strip happened to be empty". This is the reversal of the old forecast-only hero:
/// a cache with an empty hourly strip (a throttled or cold device) must still show the observed reading
/// instead of blanking, which is exactly the iPhone/Watch failure it fixes.
final class ObservedHeroTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Madrid")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)))
    }

    private func slot(_ hour: Int, temp: Int?, at date: Date) -> HourSlot {
        HourSlot(hour: hour, temp: temp, sky: "11", precipProb: 0, date: date)
    }

    private func snapshot(currentTemp: Int?, observedTemp: Int?,
                          hours: [HourSlot], updated: Date) -> WeatherSnapshot {
        WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                        tempMin: 15, tempMax: 30, humedadMax: 60,
                        currentTemp: currentTemp, observedTemp: observedTemp,
                        sunrise: nil, sunset: nil, hours: hours, updated: updated)
    }

    /// The live defect: an empty hourly strip with a frozen `currentTemp` of nil rendered "—", even though
    /// a real station reading was cached. The hero must show that reading.
    func testEmptyStripFallsBackToObservedTemp() throws {
        let now = try date(2026, 8, 28, 9, 30)
        let snap = snapshot(currentTemp: nil, observedTemp: 24, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertTrue(snap.upcomingHours(now: now, timeZone: tz).isEmpty, "sanity: the strip is empty")
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 24,
                       "an empty strip must fall back to the observed temp, not blank to nil")
    }

    /// Observed is a real measurement of *now*; it leads even when the hourly forecast for the current hour
    /// is present.
    func testObservedLeadsOverHourlyStrip() throws {
        let now = try date(2026, 8, 28, 9, 30)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 24,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertFalse(snap.upcomingHours(now: now, timeZone: tz).isEmpty, "sanity: the strip is non-empty")
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 24,
                       "observed must lead the hourly strip's current-hour temp")
    }

    /// With no observed reading, the hero still resolves from the hourly strip as before.
    func testNoObservedFallsBackToStrip() throws {
        let now = try date(2026, 8, 28, 9, 30)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: nil,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22,
                       "no observed reading: resolve the current-hour temp from the strip")
    }

    /// The genuine "bigger problem" state: no observed reading and no hourly strip. Only here is "—" honest.
    func testNoObservedNoStripIsNilHero() throws {
        let now = try date(2026, 8, 28, 9, 30)
        let snap = snapshot(currentTemp: nil, observedTemp: nil, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertNil(snap.resolved(at: now, timeZone: tz).heroTemp,
                     "no measurement and no forecast: the hero is genuinely empty")
    }
}
