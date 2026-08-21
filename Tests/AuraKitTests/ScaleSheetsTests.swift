import XCTest
@testable import AuraKit

/// The tap-through scale sheets read a current value against a fixed table, so the band boundaries are
/// the thing that can silently drift. These lock the Beaufort force mapping (km/h → 0…12) and the WHO
/// UV band membership at their edges.
final class ScaleSheetsTests: XCTestCase {

    func testBeaufortForceAtBandEdges() {
        // Calm is strictly under 1 km/h; 1 already climbs to force 1.
        XCTAssertEqual(Beaufort.force(forKmh: 0), 0)
        XCTAssertEqual(Beaufort.force(forKmh: 1), 1)
        XCTAssertEqual(Beaufort.force(forKmh: 5), 1)
        XCTAssertEqual(Beaufort.force(forKmh: 6), 2)
        // The card's own sample: 25 km/h is force 4 (bonancible, 20–28).
        XCTAssertEqual(Beaufort.force(forKmh: 25), 4)
        XCTAssertEqual(Beaufort.force(forKmh: 28), 4)
        XCTAssertEqual(Beaufort.force(forKmh: 29), 5)
        // The open-ended top force has no upper bound.
        XCTAssertEqual(Beaufort.force(forKmh: 118), 12)
        XCTAssertEqual(Beaufort.force(forKmh: 300), 12)
        // No reading → sentinel, which the sheet turns into a hidden marker.
        XCTAssertEqual(Beaufort.force(forKmh: nil), -1)
    }

    func testBeaufortTableIsContiguousAndComplete() {
        XCTAssertEqual(Beaufort.scale.map(\.force), Array(0...12), "one row per force, in order")
        // Every consecutive pair of bounded rows meets with no gap or overlap (next.lo == prev.hi + 1).
        for pair in zip(Beaufort.scale, Beaufort.scale.dropFirst()) {
            guard let hi = pair.0.hi else { XCTFail("only force 12 is open-ended"); continue }
            XCTAssertEqual(pair.1.lo, hi + 1, "force \(pair.1.force) starts right after force \(pair.0.force)")
        }
        XCTAssertNil(Beaufort.scale.last?.hi, "force 12 is open-ended")
    }

    func testAirComponentScaleFractionStaysInBoundsAndTracksCategory() {
        for token in AirComponent.order {
            let bands = AirComponent.bands(for: token)!
            // A value in each category lands in that category's sixth of the 0…1 ramp, rising monotonically.
            var last = -1.0
            let samples: [Double] = [0, bands[0], bands[1], bands[2], bands[3], bands[4], bands[4] * 3]
            for v in samples {
                let f = AirComponent(pollutant: token, value: v).icaFraction
                XCTAssertGreaterThanOrEqual(f, 0, "\(token) at \(v): fraction ≥ 0")
                XCTAssertLessThanOrEqual(f, 1, "\(token) at \(v): fraction ≤ 1")
                XCTAssertGreaterThanOrEqual(f, last, "\(token): fraction rises with value")
                last = f
            }
        }
        // An unknown token has no scale, so it pins to the low end (rendered grey).
        XCTAssertEqual(AirComponent(pollutant: "CO", value: 999).icaFraction, 0)
    }

    func testUVBandMembershipAtEdges() {
        func band(_ v: Int) -> String? { UVBands.bands.first { $0.contains(v) }?.name }
        XCTAssertEqual(band(0), "Bajo")
        XCTAssertEqual(band(2), "Bajo")
        XCTAssertEqual(band(3), "Moderado")
        XCTAssertEqual(band(5), "Moderado")
        XCTAssertEqual(band(7), "Alto")
        XCTAssertEqual(band(8), "Muy alto")
        XCTAssertEqual(band(10), "Muy alto")
        XCTAssertEqual(band(11), "Extremadamente alto")
        XCTAssertEqual(band(15), "Extremadamente alto", "the top band is open-ended")
        // Every UV value lands in exactly one band — no gaps between the WHO bands.
        for v in 0...20 {
            XCTAssertEqual(UVBands.bands.filter { $0.contains(v) }.count, 1, "UV \(v) is in exactly one band")
        }
    }
}
