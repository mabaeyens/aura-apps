import XCTest
@testable import AuraKit

/// The one rule the widget must honour when it starts fetching on its own: hit the network only when the
/// cached snapshot is actually stale. `AuraRefreshCore.isStale` is the pure form of the gate the app has
/// always used inline; pinning its boundaries here keeps app and widget from diverging — a gate that says
/// "fresh" too readily leaves the widget showing old data, one that says "stale" too readily burns through
/// AEMET's rate limit.
final class RefreshGateTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Madrid")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)))
    }

    /// A complete snapshot carries an hourly strip; the default gives it one so the "not stale" cases model
    /// a real snapshot. Pass `hours: []` to model a thin one (the failed-hourly-fetch case).
    private func snapshot(updated: Date, days: [DaySnapshot] = [],
                          hours: [HourSlot] = [HourSlot(hour: 12, temp: 20, sky: "11", precipProb: 0)]) -> WeatherSnapshot {
        WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                        tempMin: nil, tempMax: nil, humedadMax: nil,
                        sunrise: nil, sunset: nil, days: days, hours: hours, updated: updated)
    }

    /// No cache at all (a location just added, or pruned) always needs a fetch.
    func testAbsentSnapshotIsStale() {
        XCTAssertTrue(AuraRefreshCore.isStale(nil))
    }

    /// Younger than the one-hour window: lead with the cache, no network.
    func testFreshWithinWindowIsNotStale() throws {
        let s = snapshot(updated: try date(2026, 8, 28, 14, 30))
        let now = try date(2026, 8, 28, 15, 0) // 30 min later
        XCTAssertFalse(AuraRefreshCore.isStale(s, now: now))
    }

    /// Exactly one hour is the first moment it is stale (the gate is `>=`, matching the app's original).
    func testBoundaryAtOneHourIsStale() throws {
        let s = snapshot(updated: try date(2026, 8, 28, 14, 0))
        let now = try date(2026, 8, 28, 15, 0)
        XCTAssertTrue(AuraRefreshCore.isStale(s, now: now))
    }

    /// Comfortably past the window: stale.
    func testDayOldIsStale() throws {
        let s = snapshot(updated: try date(2026, 8, 27, 14, 0))
        let now = try date(2026, 8, 28, 14, 0)
        XCTAssertTrue(AuraRefreshCore.isStale(s, now: now))
    }

    /// A thin snapshot — one whose hourly fetch failed, leaving an empty strip — must refetch even while
    /// fresh. Without this the one-hour age gate froze a once-thin Madrid at "—": passive loads and location
    /// switches judged it "fresh" and never refetched, so only a manual pull-to-refresh could recover it.
    func testFreshButThinEmptyHoursIsStale() throws {
        let updated = try date(2026, 8, 28, 14, 30)
        let now = try date(2026, 8, 28, 15, 0) // still within the hour
        let day = DaySnapshot(date: updated, min: 12, max: 24, sky: "11") // daily is fine; only hourly is gone
        XCTAssertTrue(AuraRefreshCore.isStale(snapshot(updated: updated, days: [day], hours: []), now: now))
    }

    /// A cache written by a build before the daily sky field existed (every day decodes `sky == nil`) must
    /// refetch even while fresh, or every day renders as a generic cloud until the next natural refresh.
    func testFreshButLegacySkylessDaysIsStale() throws {
        let updated = try date(2026, 8, 28, 14, 30)
        let now = try date(2026, 8, 28, 15, 0) // still within the hour
        let skyless = [DaySnapshot(date: updated, min: 12, max: 24, sky: nil),
                       DaySnapshot(date: updated, min: 13, max: 25, sky: nil)]
        XCTAssertTrue(AuraRefreshCore.isStale(snapshot(updated: updated, days: skyless), now: now))
    }

    /// The same fresh cache but with real sky codes is a modern, complete snapshot: no fetch.
    func testFreshWithSkyDaysIsNotStale() throws {
        let updated = try date(2026, 8, 28, 14, 30)
        let now = try date(2026, 8, 28, 15, 0)
        let withSky = [DaySnapshot(date: updated, min: 12, max: 24, sky: "11"),
                       DaySnapshot(date: updated, min: 13, max: 25, sky: nil)]
        XCTAssertFalse(AuraRefreshCore.isStale(snapshot(updated: updated, days: withSky), now: now))
    }
}
