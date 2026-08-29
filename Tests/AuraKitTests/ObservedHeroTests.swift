import XCTest
@testable import AuraKit

/// The forecast-only hero rule (spec: aura-android/specs/unified-freshness.md): the hero shows the
/// current-hour forecast, decided at display time. The forecast always leads, and because it is the same
/// value the strip's first column shows, the hero and the first hourly tile can never disagree. A fresh
/// station observation fills the hero *only* when there is no forecast temperature to show at all (an empty
/// or thin strip on a throttled or cold device), gated on the same `observationIsFresh` as the observation
/// card; otherwise the frozen scalar, then "—". The observation never overrides an available forecast.
/// iOS and Android must resolve identically.
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

    /// Even when a same-hour observation has published (its `fint` ties the current forecast hour), the
    /// forecast leads. The observation no longer overrides an available forecast.
    func testForecastLeadsOverTyingObservation() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 24, observedAt: h9,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22,
                       "the current-hour forecast leads even when a same-hour observation exists")
    }

    /// Before the current hour's reading publishes, the forecast — already 'for now' — leads, same as after.
    func testForecastLeadsBeforeHourPublishes() throws {
        let now = try date(2026, 8, 28, 9, 15)
        let h8 = try date(2026, 8, 28, 8, 0)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 25, observedAt: h8,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 22,
                       "the forecast leads regardless of the observation's timing")
    }

    /// After a day change, a snapshot cached last night still resolves to today's current-hour forecast,
    /// never the stale overnight observation.
    func testForecastLeadsAcrossDayChange() throws {
        let now = try date(2026, 8, 28, 0, 15)
        let h0 = try date(2026, 8, 28, 0, 0)
        let h1 = try date(2026, 8, 28, 1, 0)
        let lastNight = try date(2026, 8, 27, 23, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 25, observedAt: lastNight,
                            hours: [slot(0, temp: 19, at: h0), slot(1, temp: 18, at: h1)],
                            updated: lastNight)
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 19,
                       "the forecast leads; a stale overnight observation never pins the hero")
    }

    /// No forecast to compare against (an empty/thin strip): a fresh, non-future observation fills the hero
    /// rather than blanking. This keeps the hero populated on a throttled or cold device.
    func testEmptyStripFallsBackToFreshObservation() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let snap = snapshot(currentTemp: nil, observedTemp: 24, observedAt: h9, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertTrue(snap.upcomingHours(now: now, timeZone: tz).isEmpty, "sanity: the strip is empty")
        XCTAssertEqual(snap.resolved(at: now, timeZone: tz).heroTemp, 24,
                       "no forecast value: a fresh observation fills the hero rather than blanking")
    }

    /// The empty-strip fallback is freshness-gated: an observation older than the observation card's window
    /// (`observationIsFresh`, 3 h) cannot fill the hero, so it honestly reads "—".
    func testEmptyStripWithStaleObservationBlanks() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let stale = try date(2026, 8, 28, 5, 0)   // > 3 h old
        let snap = snapshot(currentTemp: nil, observedTemp: 24, observedAt: stale, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertTrue(snap.upcomingHours(now: now, timeZone: tz).isEmpty, "sanity: the strip is empty")
        XCTAssertFalse(snap.observationIsFresh(now: now), "sanity: the observation is stale")
        XCTAssertNil(snap.resolved(at: now, timeZone: tz).heroTemp,
                     "a stale observation cannot fill the hero: honest —")
    }

    /// A future observation time (clock skew) fails the freshness gate and never fills.
    func testEmptyStripWithFutureObservationBlanks() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let future = try date(2026, 8, 28, 11, 0)
        let snap = snapshot(currentTemp: nil, observedTemp: 24, observedAt: future, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertNil(snap.resolved(at: now, timeZone: tz).heroTemp,
                     "a future observation time fails the freshness gate: honest —")
    }

    /// With no observation and no forecast, the hero is the genuine "—".
    func testNoObservedNoStripIsNilHero() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let snap = snapshot(currentTemp: nil, observedTemp: nil, observedAt: nil, hours: [],
                            updated: try date(2026, 8, 27, 22, 0))
        XCTAssertNil(snap.resolved(at: now, timeZone: tz).heroTemp)
    }

    /// The invariant that motivated the revert: whenever the strip is non-empty, the hero equals the first
    /// hourly tile — including when a same-hour observation exists (which used to make them disagree).
    func testHeroEqualsFirstHourlyTile() throws {
        let now = try date(2026, 8, 28, 9, 35)
        let h9 = try date(2026, 8, 28, 9, 0)
        let h10 = try date(2026, 8, 28, 10, 0)
        let snap = snapshot(currentTemp: 18, observedTemp: 24, observedAt: h9,
                            hours: [slot(9, temp: 22, at: h9), slot(10, temp: 23, at: h10)],
                            updated: try date(2026, 8, 28, 8, 0))
        let resolved = snap.resolved(at: now, timeZone: tz)
        let firstTile = snap.upcomingHours(now: now, timeZone: tz).first?.temp
        XCTAssertEqual(resolved.heroTemp, firstTile,
                       "the hero must always equal the first tile of the hours strip")
    }
}
