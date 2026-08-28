import XCTest
@testable import AuraKit

/// Pins the observation fetch gate: `observationDue` (the fint-based TTL) and `observationDueFromMarker` (the
/// RSS-publish-marker gate with the TTL as the unreachable fallback). Same vectors as aura-android's
/// `ObservationGateTest` (unified-freshness spec): the shared vectors keep the two platforms' fetch cadence
/// identical. The RSS publish marker (~30 min past the hour) and the observation `fint` (top of the hour) are
/// two different clocks and are never compared against each other.
final class ObservationGateTests: XCTestCase {

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    // A 10:00 reading is next genuinely due at 11:30 (60 min cadence + 30 min publish-lag margin).
    private lazy var fint = date("2026-08-21T10:00:00Z")
    // The RSS publish marker sits ~30 min past the hour, a different clock from the fint above.
    private lazy var published = date("2026-08-21T10:31:00Z")

    // --- observationDue: the fint-based TTL ---

    func testForceAlwaysFetches() {
        XCTAssertTrue(AuraRefreshCore.observationDue(anchor: fint, now: fint.addingTimeInterval(60), force: true))
    }

    func testMissingAnchorFetches() {
        XCTAssertTrue(AuraRefreshCore.observationDue(anchor: nil, now: fint, force: false))
    }

    func testWithinTtlSkips() {
        XCTAssertFalse(AuraRefreshCore.observationDue(anchor: fint, now: date("2026-08-21T10:35:00Z"), force: false))
    }

    func testPastTtlFetches() {
        XCTAssertTrue(AuraRefreshCore.observationDue(anchor: fint, now: date("2026-08-21T11:31:00Z"), force: false))
    }

    func testFutureAnchorIsClampedAndStillBecomesDue() {
        let now = date("2026-08-21T10:00:00Z")
        let badFuture = now.addingTimeInterval(3600)   // 11:00, a corrupt future-dated fint
        XCTAssertFalse(AuraRefreshCore.observationDue(anchor: badFuture, now: now, force: false))
        XCTAssertTrue(AuraRefreshCore.observationDue(anchor: badFuture, now: date("2026-08-21T13:00:00Z"), force: false))
    }

    // --- observationDueFromMarker: the RSS-publish-marker gate, TTL as the unreachable fallback ---

    func testMarkerForceAlwaysFetches() {
        XCTAssertTrue(AuraRefreshCore.observationDueFromMarker(
            storedPublished: published, rssMarker: nil, storedFint: fint, now: fint, force: true))
    }

    func testMarkerAdvancedPublishTimeFetches() {
        let newer = date("2026-08-21T11:31:00Z")
        XCTAssertTrue(AuraRefreshCore.observationDueFromMarker(
            storedPublished: published, rssMarker: newer, storedFint: fint, now: newer, force: false))
    }

    func testMarkerUnchangedPublishTimeSkips() {
        let now = date("2026-08-21T10:55:00Z")
        XCTAssertFalse(AuraRefreshCore.observationDueFromMarker(
            storedPublished: published, rssMarker: published, storedFint: fint, now: now, force: false))
    }

    func testMarkerFirstEverFetchWhenNothingStored() {
        XCTAssertTrue(AuraRefreshCore.observationDueFromMarker(
            storedPublished: nil, rssMarker: published, storedFint: nil, now: published, force: false))
    }

    func testMarkerUnreachableRssFallsBackToTheFintTtl() {
        XCTAssertFalse(AuraRefreshCore.observationDueFromMarker(
            storedPublished: published, rssMarker: nil, storedFint: fint,
            now: date("2026-08-21T10:35:00Z"), force: false))
        XCTAssertTrue(AuraRefreshCore.observationDueFromMarker(
            storedPublished: published, rssMarker: nil, storedFint: fint,
            now: date("2026-08-21T11:31:00Z"), force: false))
    }
}
