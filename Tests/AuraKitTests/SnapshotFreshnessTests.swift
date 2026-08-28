import XCTest
@testable import AuraKit

/// The widget renders whatever the app last wrote to the App Group cache and, on its own, cannot yet
/// fetch (that lands in `specs/widget-self-refresh-and-staleness.md`, second pass). Until it can, a
/// day-old snapshot must at least *admit* it is old rather than showing a silent stale value. The badge
/// is driven only by `updated` vs the render `now`: fresh within the hour (no badge), a soft
/// "actualizado HH:mm" once it is older, and a hard "Desactualizado" past the ~24 h strip horizon where
/// display-time resolution can no longer keep the values correct.
final class SnapshotFreshnessTests: XCTestCase {

    private let tz = TimeZone(identifier: "Europe/Madrid")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)))
    }

    /// A snapshot carrying only an `updated` stamp — the only field the badge reads.
    private func snapshot(updated: Date) -> WeatherSnapshot {
        WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                        tempMin: nil, tempMax: nil, humedadMax: nil,
                        sunrise: nil, sunset: nil, updated: updated)
    }

    /// Under an hour old: current within the app's own stale gate, so no badge at all.
    func testFreshWithinHourHasNoBadge() throws {
        let s = snapshot(updated: try date(2026, 8, 28, 14, 30))
        let now = try date(2026, 8, 28, 15, 0) // 30 min later
        XCTAssertEqual(s.freshness(at: now), .fresh)
        XCTAssertNil(s.stalenessLabel(at: now, timeZone: tz))
    }

    /// Older than an hour but within the 24 h horizon: soft, informational "actualizado HH:mm" in the
    /// location's own time — the values are still correct, the user is just told when they were fetched.
    func testRecentShowsUpdatedTime() throws {
        let s = snapshot(updated: try date(2026, 8, 28, 14, 30))
        let now = try date(2026, 8, 28, 17, 30) // 3 h later
        XCTAssertEqual(s.freshness(at: now), .recent)
        XCTAssertEqual(s.stalenessLabel(at: now, timeZone: tz), "actualizado 14:30")
    }

    /// Exactly one hour old is the first moment it is no longer fresh.
    func testBoundaryAtOneHourIsRecent() throws {
        let s = snapshot(updated: try date(2026, 8, 28, 14, 0))
        let now = try date(2026, 8, 28, 15, 0) // exactly 1 h later
        XCTAssertEqual(s.freshness(at: now), .recent)
    }

    /// Past the ~24 h strip horizon the hero can no longer re-anchor to today, so the badge escalates from
    /// informational to an honest "Desactualizado".
    func testDayOldIsStale() throws {
        let s = snapshot(updated: try date(2026, 8, 27, 13, 0))
        let now = try date(2026, 8, 28, 15, 0) // 26 h later
        XCTAssertEqual(s.freshness(at: now), .stale)
        XCTAssertEqual(s.stalenessLabel(at: now, timeZone: tz), "Desactualizado")
    }

    /// A stamp in the future (device clock skew) must never read as stale — treat it as fresh, no badge.
    func testFutureUpdatedIsFresh() throws {
        let s = snapshot(updated: try date(2026, 8, 28, 16, 0))
        let now = try date(2026, 8, 28, 15, 0) // updated an hour "ahead" of now
        XCTAssertEqual(s.freshness(at: now), .fresh)
        XCTAssertNil(s.stalenessLabel(at: now, timeZone: tz))
    }
}
