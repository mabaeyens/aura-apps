import XCTest
@testable import AuraKit

/// The observation card's display-time staleness gate (spec: observed-card-staleness.md, extending
/// unified-freshness concept 3). The card is a degraded proxy — hourly, lagging ~31 min, from a station up
/// to 20 km away — so it must be honest about age. Two rules, both at display time, both shared with Android:
///
/// 1. Age gate. The card trusts a reading only while `observedAt` (AEMET's `fint`) is within
///    `StationObservation.observationMaxAge` (3 h, the same age `nearest` uses to select a station). Past it,
///    the card hides rather than showing a stale number as live — the card analogue of the hero's
///    most-recent rule (the hero falls back to forecast, the card falls back to hidden).
/// 2. Honest timestamp. A shown reading that is not from the current clock hour carries its reading time
///    ("a las HH:MM"), so a carried-forward value reads as last-known, not live.
///
/// Carry-forward stays but is bounded by the same gate: a reading past 3 h is dropped at `make()`, and — the
/// real safety net — the gate is re-checked against `now` at display, so a carried reading self-expires even
/// with no fetch (the Ciudad Universitaria stale-10 case). iOS and Android use the identical threshold,
/// stamp rule, and fallback.
final class ObservationCardStalenessTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Madrid")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)))
    }

    /// A snapshot with a resolved station and a reading stamped at `observedAt`.
    private func snapshot(observedAt: Date?) -> WeatherSnapshot {
        WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                        tempMin: 15, tempMax: 30, humedadMax: 60,
                        currentTemp: 22, observedTemp: 24,
                        observedStation: "Madrid Retiro", observedStationDistanceKm: 3,
                        observedMetrics: [.temperature],
                        observedReading: ObservedReading(temperature: 24, humidity: 50, windKmh: nil,
                                                         windDirection: nil, pressure: nil, precipMm: nil),
                        observedAt: observedAt,
                        sunrise: nil, sunset: nil, updated: Date())
    }

    // MARK: - Age gate (observationIsFresh)

    /// The threshold is one named constant, shared with `nearest`'s selection age so the two never drift.
    func testThresholdIsThreeHours() {
        XCTAssertEqual(StationObservation.observationMaxAge, 3 * 3600)
    }

    /// A current-hour reading is fresh.
    func testCurrentHourReadingIsFresh() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        XCTAssertTrue(snapshot(observedAt: h9).observationIsFresh(now: now))
    }

    /// A reading two hours old is still within the gate.
    func testTwoHourOldReadingIsFresh() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h7 = try date(2026, 8, 28, 7, 30)
        XCTAssertTrue(snapshot(observedAt: h7).observationIsFresh(now: now))
    }

    /// Exactly at the 3-hour boundary the reading is still fresh (`<=`), matching `nearest`'s inclusive edge.
    func testExactlyThreeHoursOldIsFresh() throws {
        let now = try date(2026, 8, 28, 9, 0)
        let threeHoursAgo = try date(2026, 8, 28, 6, 0)
        XCTAssertTrue(snapshot(observedAt: threeHoursAgo).observationIsFresh(now: now))
    }

    /// One minute past three hours the reading is stale — the card must hide it.
    func testJustOverThreeHoursIsStale() throws {
        let now = try date(2026, 8, 28, 9, 1)
        let old = try date(2026, 8, 28, 6, 0)
        XCTAssertFalse(snapshot(observedAt: old).observationIsFresh(now: now))
    }

    /// The Ciudad Universitaria case: a reading hours old (a sierra station carried forward) is stale.
    func testHoursOldReadingIsStale() throws {
        let now = try date(2026, 8, 28, 14, 0)
        let morning = try date(2026, 8, 28, 8, 0)
        XCTAssertFalse(snapshot(observedAt: morning).observationIsFresh(now: now))
    }

    /// A future measurement time (clock skew) is not fresh — matches the hero's not-in-the-future rule so the
    /// card never contradicts it.
    func testFutureReadingIsNotFresh() throws {
        let now = try date(2026, 8, 28, 9, 0)
        let future = try date(2026, 8, 28, 11, 0)
        XCTAssertFalse(snapshot(observedAt: future).observationIsFresh(now: now))
    }

    /// A timestampless reading (old cache from before `observedAt`) can't be proven fresh, so it hides.
    func testTimestamplessReadingIsNotFresh() throws {
        let now = try date(2026, 8, 28, 9, 35)
        XCTAssertFalse(snapshot(observedAt: nil).observationIsFresh(now: now))
    }

    // MARK: - Honest timestamp (observationDisplayTime)

    /// A reading from the current clock hour needs no stamp — it is already "now".
    func testCurrentHourNeedsNoTimestamp() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        XCTAssertNil(snapshot(observedAt: h9).observationDisplayTime(now: now, timeZone: tz))
    }

    /// A reading from an earlier hour (still within the gate) carries its reading time.
    func testEarlierHourCarriesItsTime() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h8 = try date(2026, 8, 28, 8, 0)
        XCTAssertEqual(snapshot(observedAt: h8).observationDisplayTime(now: now, timeZone: tz), h8)
    }

    /// Same clock hour but a different day (a stale overnight reading) is not "now" — it carries its time.
    func testSameHourDifferentDayCarriesItsTime() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let yesterday9 = try date(2026, 8, 27, 9, 0)
        XCTAssertEqual(snapshot(observedAt: yesterday9).observationDisplayTime(now: now, timeZone: tz), yesterday9)
    }

    /// No timestamp, no stamp.
    func testTimestamplessHasNoDisplayTime() throws {
        let now = try date(2026, 8, 28, 9, 35)
        XCTAssertNil(snapshot(observedAt: nil).observationDisplayTime(now: now, timeZone: tz))
    }

    // MARK: - Bounded carry-forward in make()

    private func dailyFixture() throws -> MunicipioForecast {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "municipio_diaria_28079", withExtension: "json",
                              subdirectory: "Fixtures"),
            "missing fixture municipio_diaria_28079.json")
        return try JSONDecoder().decode([MunicipioForecast].self, from: Data(contentsOf: url))[0]
    }

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)

    /// A previous snapshot whose reading is within the gate is carried forward on a skipped fetch.
    func testFreshPreviousIsCarriedForward() throws {
        let now = try date(2026, 8, 28, 12, 0)
        let observed = StationObservation(idema: "3195", ubi: "MADRID RETIRO",
                                          lat: 40.4114, lon: -3.6782, ta: 21.4, hr: 50,
                                          fint: "2026-08-28T10:00:00+0000")   // 12:00 Madrid, 2 h before now
        let previous = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                            observed: observed, now: now)
        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: nil, previousObserved: previous, now: now)
        XCTAssertEqual(rebuilt.observedStation, previous.observedStation)
        XCTAssertEqual(rebuilt.observedReading, previous.observedReading)
        XCTAssertNotNil(rebuilt.observedAt)
    }

    /// A previous snapshot whose reading has aged past the gate is dropped, not pinned — the carry-forward
    /// half of the Ciudad Universitaria fix. A sierra reading cached under the old radius cannot persist.
    func testStalePreviousIsDropped() throws {
        let observedNow = try date(2026, 8, 28, 8, 0)
        let observed = StationObservation(idema: "3195", ubi: "MADRID RETIRO",
                                          lat: 40.4114, lon: -3.6782, ta: 10.0, hr: 50,
                                          fint: "2026-08-28T06:00:00+0000")   // 08:00 Madrid
        let previous = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                            observed: observed, now: observedNow)
        XCTAssertNotNil(previous.observedStation, "sanity: the previous reading was recorded")

        // A skipped fetch four hours later: the carried reading is now past the 3 h gate.
        let later = try date(2026, 8, 28, 12, 1)
        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: nil, previousObserved: previous, now: later)
        XCTAssertNil(rebuilt.observedStation)
        XCTAssertNil(rebuilt.observedReading)
        XCTAssertNil(rebuilt.observedTemp)
        XCTAssertNil(rebuilt.observedAt)
        XCTAssertEqual(rebuilt.observedMetrics, [])
    }
}
