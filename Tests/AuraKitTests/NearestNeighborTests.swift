import XCTest
@testable import AuraKit

/// M2 coverage for the two nearest-neighbour lookups run on every refresh: `StationObservation.nearest`
/// (the observed-temperature pick) and `RadarSite.nearest`. Both were previously untested despite a
/// wrong result silently mislabelling "the temperature near you" or the radar range rings.
final class NearestNeighborTests: XCTestCase {

    // Matches the source formatter so fint strings and `now` line up deterministically (no Date()).
    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()
    private lazy var now = fmt.date(from: "2026-08-25T12:00:00+0000")!
    private let fresh = "2026-08-25T11:30:00+0000"   // 30 min old, within the 3 h window
    private let stale = "2026-08-25T06:00:00+0000"   // 6 h old, outside it

    private func obs(_ idema: String, lat: Double?, lon: Double?, ta: Double? = 22,
                     fint: String) -> StationObservation {
        StationObservation(idema: idema, ubi: idema, lat: lat, lon: lon, ta: ta, hr: 50, fint: fint)
    }

    // Madrid city centre; distances below are relative to this.
    private let madridLat = 40.4168, madridLon = -3.7038

    private func nearestToMadrid(_ obs: [StationObservation],
                                 maxDistanceKm: Double = 35) -> StationObservation? {
        StationObservation.nearest(toLatitude: madridLat, longitude: madridLon, in: obs,
                                   now: now, maxDistanceKm: maxDistanceKm)
    }

    func testPicksNearestRecentStation() {
        let close = obs("CLOSE", lat: 40.45, lon: -3.70, fint: fresh)   // ~4 km
        let far = obs("FAR", lat: 40.60, lon: -3.70, fint: fresh)       // ~20 km
        XCTAssertEqual(nearestToMadrid([far, close])?.idema, "CLOSE")
    }

    func testExcludesStationBeyondMaxDistance() {
        let beyond = obs("BEYOND", lat: 41.10, lon: -3.70, fint: fresh) // ~76 km, past the 35 km cap
        XCTAssertNil(nearestToMadrid([beyond]))
    }

    func testExcludesStaleReading() {
        let old = obs("OLD", lat: 40.45, lon: -3.70, fint: stale)       // close but 6 h old
        XCTAssertNil(nearestToMadrid([old]))
    }

    func testDedupesSameStationKeepingLatestReading() {
        let older = obs("X", lat: 40.45, lon: -3.70, ta: 20, fint: "2026-08-25T11:00:00+0000")
        let newer = obs("X", lat: 40.45, lon: -3.70, ta: 25, fint: "2026-08-25T11:45:00+0000")
        let picked = nearestToMadrid([older, newer])
        XCTAssertEqual(picked?.idema, "X")
        XCTAssertEqual(picked?.ta, 25)   // the later of the two readings wins
    }

    func testSkipsStationsMissingCoordsOrTemperature() {
        let noCoords = obs("NOCOORDS", lat: nil, lon: nil, fint: fresh)
        let noTemp = obs("NOTEMP", lat: 40.45, lon: -3.70, ta: nil, fint: fresh)
        let valid = obs("VALID", lat: 40.46, lon: -3.71, fint: fresh)
        XCTAssertEqual(nearestToMadrid([noCoords, noTemp, valid])?.idema, "VALID")
    }

    func testReturnsNilWhenNoneQualify() {
        XCTAssertNil(nearestToMadrid([]))
    }

    // MARK: - RadarSite

    func testNearestRadarSites() {
        XCTAssertEqual(RadarSite.nearest(toLatitude: 40.42, longitude: -3.70).code, "ma")  // Madrid
        XCTAssertEqual(RadarSite.nearest(toLatitude: 41.39, longitude: 2.16).code, "ba")   // Barcelona
        XCTAssertEqual(RadarSite.nearest(toLatitude: 28.10, longitude: -15.41).code, "ca") // Las Palmas
        XCTAssertEqual(RadarSite.nearest(toLatitude: 37.39, longitude: -5.99).code, "se")  // Sevilla
    }

    func testNearestRadarNeverReturnsUnknownSite() {
        // Arbitrary far-flung coordinates still resolve to one of the known sites, never nil.
        let site = RadarSite.nearest(toLatitude: 0, longitude: 0)
        XCTAssertTrue(RadarSite.all.contains(site))
    }
}
