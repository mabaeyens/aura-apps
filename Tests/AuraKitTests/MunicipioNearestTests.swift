import XCTest
@testable import AuraKit

/// The current-location resolver behind the Watch's standalone fetch: a GPS coordinate must snap to the
/// true nearest municipality over the full bundled table, including a spot far from any seed city (the
/// hike-far-from-home case). Deterministic, so it runs without a device, a simulator, or an AEMET key.
final class MunicipioNearestTests: XCTestCase {

    func testTableLoadedFromBundle() {
        // The move into AuraKit means the table now loads from `Bundle.module`, not the app bundle. If that
        // regressed we would silently fall back to the ~handful of seed cities; assert the full table.
        XCTAssertGreaterThan(MunicipioDatabase.all.count, 8000,
                             "Full municipality table should load from Bundle.module, not the seed fallback")
    }

    func testResolvesRemotePyreneesCoordinateToBenasque() {
        // A point on a trail just NE of Benasque village, deep in the Huesca Pyrenees and far from every
        // seed city. Nearest town is Benasque (~3 km); the next is >5 km further, so this is unambiguous.
        let resolved = MunicipioDatabase.nearest(latitude: 42.6300, longitude: 0.5400)
        XCTAssertEqual(resolved?.nombre, "Benasque")
        XCTAssertEqual(resolved?.ine, "22054")
        XCTAssertEqual(resolved?.provincia, "Huesca")
    }

    func testResolvesCoastalCornerToFisterra() {
        // A second far corner (Costa da Morte), to prove it is not just picking a central default.
        let resolved = MunicipioDatabase.nearest(latitude: 42.9076, longitude: -9.2637)
        XCTAssertEqual(resolved?.nombre, "Fisterra")
        XCTAssertEqual(resolved?.ine, "15037")
    }
}
