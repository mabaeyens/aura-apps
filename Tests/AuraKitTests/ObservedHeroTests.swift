import XCTest
@testable import AuraKit

/// The unified-freshness hero rule (spec: aura-android/specs/unified-freshness.md): the hero shows the
/// **more recent** of the nearest station's observation and the current-hour forecast, decided at display
/// time, with a tie going to the observation. The observation leads only when its measurement time
/// (`observedAt`, AEMET's `fint`) is at least as recent as the leading forecast hour and not in the future,
/// or when there is no forecast value to compare against; otherwise the re-anchored forecast leads, then the
/// frozen scalar, then "—". No fixed freshness window — it is self-cleaning across a day change, because the
/// forecast hour keeps advancing past a stale measurement. iOS and Android must resolve identically.
final class ObservedHeroTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Madrid")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)))
    }

    private func slot(_ hour: Int, temp: Int?, at date: Date) -> HourSlot {
        HourSlot(hour: hour, temp: temp, sky: "11", precipProb: 0, date: date)
    }

    private func snapshot(currentTemp: Int?, observedTemp: Int?, observedAt: Date?,
                          hours: [HourSlot], updated: Date) -> WeatherSnapshot {
        WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                        tempMin: 15, tempMax: 30, humedadMax: 60,
                        currentTemp: currentTemp, observedTemp: observedTemp, observedAt: observedAt,
                        sunrise: nil, sunset: nil, hours: hours, updated: updated)
    }

    /// Tie to the observation: once the current hour's reading has published, its `fint` equals the forecast
    /// hour, and a real measurement of that hour beats the prediction of it.
    func testObservedLeadsWhenFintTiesForecastHour() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 24, observedAt: h9,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertTrue(snap.observedLeadsHero(now: now, timeZone: tz))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 24,
                       "an observation of the current forecast hour leads (tie to the observation)")
    }

    /// Before ~:31 the freshest published reading is still the previous hour's, older than the current
    /// forecast hour, so the forecast — already 'for now' — leads. This covers the first half of every hour.
    func testForecastLeadsBeforeHourPublishes() throws {
        let now = try date(2026, 8, 28, 9, 15)
        let h8 = try date(2026, 8, 28, 8, 0)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        // Freshest reading is the 08:00 one (25°); the 09:00 reading has not published yet.
        let snap = snapshot(currentTemp: 18, observedTemp: 25, observedAt: h8,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertFalse(snap.observedLeadsHero(now: now, timeZone: tz))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22,
                       "a last-hour reading is older than the current forecast hour: forecast leads")
    }

    /// The day-change guard, and the whole reason for 'most recent' over a fixed window: a reading cached
    /// last night is older than today's first forecast hour, so it can never pin the hero — no constant needed.
    func testStaleObservationAcrossDayChangeFallsBackToForecast() throws {
        let now = try date(2026, 8, 28, 0, 15)
        let h0 = try date(2026, 8, 28, 0, 0)
        let h1 = try date(2026, 8, 28, 1, 0)
        let lastNight = try date(2026, 8, 27, 23, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 25, observedAt: lastNight,
                            hours: [slot(0, temp: 19, at: h0), slot(1, temp: 18, at: h1)],
                            updated: lastNight)
        XCTAssertFalse(snap.observedLeadsHero(now: now, timeZone: tz))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 19,
                       "a stale overnight observation must never lead across a day change")
    }

    /// A future measurement time (clock skew) never leads.
    func testFutureFintDoesNotLead() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let future = try date(2026, 8, 28, 11, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 25, observedAt: future,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertFalse(snap.observedLeadsHero(now: now, timeZone: tz))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22,
                       "a future fint fails the not-in-the-future check: forecast leads")
    }

    /// No forecast to compare against (an empty/thin strip): a real, non-future measurement beats a blank.
    /// This keeps the hero populated on a throttled or cold device — the iPhone/Watch failure this fixes.
    func testEmptyStripWithObservationLeads() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let snap = snapshot(currentTemp: nil, observedTemp: 24, observedAt: h9, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertTrue(snap.upcomingHours(now: now, timeZone: tz).isEmpty, "sanity: the strip is empty")
        XCTAssertTrue(snap.observedLeadsHero(now: now, timeZone: tz))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 24,
                       "no forecast value: a non-future observation leads rather than blanking")
    }

    /// A timestampless observation (an old cache from before `observedAt`, or a reading with no `fint`)
    /// cannot be proven current, so it must not lead — the forecast leads until a refresh stamps a time.
    func testTimestamplessObservationDoesNotLead() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 24, observedAt: nil,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertFalse(snap.observedLeadsHero(now: now, timeZone: tz))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22,
                       "no fint: cannot verify recency, so the forecast leads")
    }

    /// With no observation, the hero resolves from the strip as before.
    func testNoObservedFallsBackToStrip() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: nil, observedAt: nil,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22)
    }

    /// The genuine "—": no observation and no forecast. Only here is a blank honest.
    func testNoObservedNoStripIsNilHero() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let snap = snapshot(currentTemp: nil, observedTemp: nil, observedAt: nil, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertNil(snap.resolved(at: now, timeZone: tz).heroTemp)
    }
}
